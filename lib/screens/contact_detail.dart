import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hisabshare/repositories/contact_repository.dart';
import 'package:hisabshare/screens/select_category.dart';
import 'package:hisabshare/services/statement_export_service.dart';
import 'package:hisabshare/services/transaction_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

class ContactDetailPage extends StatefulWidget {
  final String categoryId;
  final String contactId;
  final String contactName;
  final bool isSharedView;
  // Non-null/non-empty ONLY for an unaccepted deep-link share (contactId is
  // then the sender's own contact id, not yet the receiver's copy).
  final String? sharedUserId;

  const ContactDetailPage({
    required this.categoryId,
    required this.contactId,
    required this.contactName,
    this.isSharedView = false,
    this.sharedUserId,
    super.key,
  });

  @override
  State<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _latestTxns = [];
  Offset fabPosition = const Offset(300, 700);

  TextEditingController searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime? selectedDate;
  bool allowReceiverToAdd = true;

  Stream<List<Map<String, dynamic>>>? transactionStream;

  // The contact actually holding the ledger being viewed. Equal to
  // widget.contactId except right after accepting a pending deep-link share,
  // when it's swapped for the receiver's own copy.
  late String _contactId;

  @override
  void initState() {
    super.initState();

    _contactId = widget.contactId;

    searchController.addListener(_onSearchChanged);

    if (widget.isSharedView && widget.sharedUserId != null && widget.sharedUserId!.isNotEmpty) {
      _resolvePendingShare();
    } else {
      if (widget.isSharedView) {
        _loadSharePermission();
      }
      transactionStream = _getTransactionStream();
    }
  }

  /// Entry point for an unaccepted deep-link share: widget.contactId is the
  /// sender's own contact, so this contact isn't ours to view yet. Checks
  /// whether we've already accepted it (pendingShare), and if not, prompts
  /// and - on acceptance - opens category selection to create our own copy
  /// (ContactRepository.shareContact, which atomically copies the reversed
  /// transactions server-side).
  Future<void> _resolvePendingShare() async {
    try {
      final pending = await ContactRepository.pendingShare(widget.contactId);

      if (pending['accepted'] == true) {
        _contactId = pending['receiver_contact_id'] as String;
        _startStream();
        return;
      }

      final senderName = pending['sender_name'] as String? ?? 'Someone';
      if (!mounted) return;

      final shouldAccept = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text('Ledger from $senderName'),
          content: const Text('Are you sure you want to accept this ledger?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Decline'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Accept'),
            ),
          ],
        ),
      );

      if (shouldAccept != true) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      if (!mounted) return;
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => ChooseCategoryPage(
          contactId: widget.contactId,
          contactName: widget.contactName,
          senderName: senderName,
        ),
      );

      if (result != null && result['contact'] != null) {
        final contact = result['contact'] as Map<String, dynamic>;
        _contactId = contact['id'] as String;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ledger saved successfully, login to your app to see the details."),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
        _startStream();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _startStream() {
    if (!mounted) return;
    setState(() {
      transactionStream = _getTransactionStream();
    });
  }

  /// Reads `allow_receiver_to_add_transactions` straight off our own
  /// (receiver-side) contact row - replaces the old multi-hop cross-account
  /// Firestore lookup this required before.
  Future<void> _loadSharePermission() async {
    try {
      final allow = await ContactRepository.sharePermission(widget.contactId);
      if (mounted) setState(() => allowReceiverToAdd = allow);
    } catch (_) {}
  }

  void _onSearchChanged() {
    // The actual filtering runs inline against _latestTxns inside the
    // transaction-list StreamBuilder below; this setState is what makes that
    // filter re-run on every keystroke.
    setState(() {});
  }

  Future<void> _refreshManually() async {
    setState(() {
      // StreamBuilder rebuild; the next poll tick refreshes the data.
    });
  }

  Future<void> _pickDate() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        selectedDate = date;
      });
    }
  }

  Stream<List<Map<String, dynamic>>> _getTransactionStream() {
    return TransactionService.transactionStream(contactId: _contactId);
  }

  Future<void> _addTransaction(Map<String, dynamic> transaction) async {
    try {
      await TransactionService.addTransaction(
        contactId: _contactId,
        date: transaction['date'] as DateTime,
        type: transaction['type'] as String,
        credit: (transaction['credit'] as num).toDouble(),
      );
      _startStream();
    } catch (_) {
    }
  }

  Future<void> _shareCsv() async {
    // Preserves a pre-existing, already-flagged bug (Phase 2 decision, not
    // fixed here): CSV export has always produced an empty file, since the
    // transactions list it was called with was only ever populated by a
    // method nothing invoked. That dead field is gone now, so this passes an
    // explicit empty list to keep the exact same (broken) behavior.
    await StatementExportService.shareCsv(context, const [], widget.contactName);
  }

  void _showAddTransactionDialog() {
    DateTime selectedTxDate = DateTime.now();
    String selectedType = 'Send';
    final creditController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Add Transaction"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                        "Date: ${selectedTxDate.day}/${selectedTxDate.month}/${selectedTxDate.year}"),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedTxDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setStateDialog(() {
                          selectedTxDate = picked;
                        });
                      }
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text("Send"),
                        selected: selectedType == "Send",
                        onSelected: (_) =>
                            setStateDialog(() => selectedType = "Send"),
                        selectedColor: Colors.red.shade100,
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("Receive"),
                        selected: selectedType == "Receive",
                        onSelected: (_) =>
                            setStateDialog(() => selectedType = "Receive"),
                        selectedColor: Colors.green.shade100,
                      ),
                    ],
                  ),
                  TextField(
                    controller: creditController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Credit"),
                  )
                ],
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _addTransaction({
                      'date': selectedTxDate,
                      'type': selectedType,
                      'credit':
                          double.tryParse(creditController.text) ?? 0.0,
                    });
                    _noteController.clear();
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black, //
                    backgroundColor: Color(0xFF89BE4F), //
                    elevation: 0, // optional: flat style
                  ),
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
  return Screenshot(
    controller: _screenshotController,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.contactName),
        backgroundColor: Color(0xFF89BE4F),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
         onPressed: () {
  StatementExportService.generateAndSavePdf(context, _latestTxns, widget.contactName);
}
          ),
       if (!widget.isSharedView) ...[
          IconButton(
      icon: const Icon(Icons.share),
      onPressed: () async {
        try {
          final image = await _screenshotController.capture();
          if (image == null) {
            return;
          }
          final directory = await getApplicationDocumentsDirectory();
          final path = '${directory.path}/screenshot.png';
          final imageFile = await File(path).create();
          await imageFile.writeAsBytes(image);

          final xFile = XFile(path);
          final senderId = FirebaseAuth.instance.currentUser?.uid ?? '';
          final encodedName = Uri.encodeComponent(widget.contactName);
          final encodedCategoryId = Uri.encodeComponent(widget.categoryId);

          final shareableLink =
              'https://hisabshare.com/contact/${widget.contactId}/$encodedName?senderId=$senderId&categoryId=$encodedCategoryId&isShared=true';

          await Share.shareXFiles(
            [xFile],
            text:
                'Check out this contact\'s transactions: $shareableLink\n\nDownload our app: https://play.google.com/store/apps/details?id=com.ranksol.hisabshare',
          );
        } catch (_) {
        }
      },
    ),
       ],
        ],
      ),
   body: Column(
  children: [
    // 1️ Total Balance under AppBar
    StreamBuilder<List<Map<String, dynamic>>>(
      stream: transactionStream,
      builder: (context, snapshot) {
        double balance = 0.0;
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          for (var tx in snapshot.data!) {
            final amount = (tx['credit'] as num).toDouble();
            balance += tx['type'] == 'Receive' ? amount : -amount;
          }
        }
        return Container(
          width: double.infinity,
          color: Colors.green.shade100,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                "Total Balance: ",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
               "${balance < 0 ? '-' : '+'}Rs${balance.abs().toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: balance < 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        );
      },
    ),
    // 2️ Filters
    Padding(
  padding: const EdgeInsets.all(16.0),
  child: Row(
    children: [
      //  Pick Date Button
      Expanded(
        flex: 3,
        child: ElevatedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(
            selectedDate != null
                ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                : "Date",
            style: const TextStyle(fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),

      const SizedBox(width: 8),
      //  Search Field
      Expanded(
        flex: 4,
        child: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: "Search by type",
            prefixIcon: const Icon(Icons.search),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
    ],
  ),
),
    // 3️ Table Header
    Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey.shade300,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Expanded(flex: 2, child: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text("Type", style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            flex: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text("Send", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text("Receive", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          Expanded(flex: 1, child: Text("Note", style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    ),
    const SizedBox(height: 10),
    // 4️ Transactions List

    Expanded(
      child: StreamBuilder<List<Map<String, dynamic>>>(
         stream: transactionStream,
        initialData: null,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading transactions"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No transactions found."));
          }
          _latestTxns = snapshot.data!;
          List<Map<String, dynamic>> txns = List.from(_latestTxns);

          //  Apply filters
          if (selectedDate != null) {
            txns = txns.where((txn) {
              final txnDate = txn['date'] as DateTime;
              return txnDate.year == selectedDate!.year &&
                     txnDate.month == selectedDate!.month &&
                     txnDate.day == selectedDate!.day;
            }).toList();
          }

        if (searchController.text.isNotEmpty) {
  final query = searchController.text.toLowerCase();
  txns = txns.where((txn) {
    final type = (txn['type'] as String).toLowerCase();
    final typeMatch = type.contains(query);
    final creditMatch = txn['credit'].toString().toLowerCase().contains(query);

    return typeMatch || creditMatch;
  }).toList();
}
        return RefreshIndicator(
  onRefresh: _refreshManually,
  child: ListView.builder(
    controller: _scrollController,
    itemCount: txns.length,
            itemBuilder: (context, index) {
              final tx = txns[index];
              final transactionId = tx['id'];
              final txDate = tx['date'] as DateTime;
              final isReceive = tx['type'] == 'Receive';

             return Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  decoration:  BoxDecoration(

    color: tx['status'] == 'rejected'
        ? Colors.red.withOpacity(0.2)
        : Colors.transparent,
    border: const Border(bottom: BorderSide(color: Colors.grey)),
  ),
  child: Row(
    children: [
      // Date
      Expanded(
        flex: 2,
        child: Text("${txDate.day}/${txDate.month}/${txDate.year}"),
      ),
      // Type
      Expanded(
        flex: 2,
        child: Text(isReceive ? 'Receive' : 'Send'),
      ),
      // Credit Column
      Expanded(
        flex: 5,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Send Column
            Expanded(
              child: Text(
                tx['type'] == 'Send'
                    ? "Rs.${(tx['credit'] as num).toStringAsFixed(0)}"
                    : "-", //
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            // Receive Column
            Expanded(
              child: Text(
                tx['type'] == 'Receive'
                    ? " Rs.${(tx['credit'] as num).toStringAsFixed(0)}"
                    : "-",//
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),

      Expanded(
        flex: 1,
        child: GestureDetector(
          onTap: () async {
            String existingNote = (tx['note'] as String?) ?? '';
            _noteController.text = existingNote;

            // Show Dialog
            showDialog(
              context: context,
              builder: (context) {
                String noteText = existingNote;

                return AlertDialog(
                  title: Text("Note"),
                  content: TextField(
                    controller: _noteController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: "Write your note here...",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (txt) {
                      noteText = txt.trim();
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel", style: TextStyle(color: Colors.black)),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (noteText.isNotEmpty && transactionId != null) {
                          try {
                            await TransactionService.updateNote(
                              transactionId: transactionId as String,
                              note: noteText,
                            );
                            _startStream();
                          } catch (_) {}
                        }
                        Navigator.pop(context);
                      },
                      child: Text("Save", style: TextStyle(color: Colors.black)),
                    )
                  ],
                );
              },
            );
          },
          child: Icon(Icons.book_sharp, color: Colors.green),
        ),
      )
    ],
  ),
);
            },
          ),
        );
        },
      ),
    ),
  ],
),
floatingActionButton: (widget.isSharedView && !allowReceiverToAdd)
    ? null
    : Stack(
        children: [
          Positioned(
            left: fabPosition.dx,
            top: fabPosition.dy,
            child: Draggable(
              feedback: FloatingActionButton(
                onPressed: _showAddTransactionDialog,
                backgroundColor: Colors.green.shade200,
                child: const Icon(Icons.add, color: Colors.black),
              ),
              childWhenDragging: Container(), // hide original when dragging
              onDraggableCanceled: (velocity, offset) {
                setState(() {
                  fabPosition = offset;
                });
              },
              child: FloatingActionButton(
                onPressed: _showAddTransactionDialog,
                backgroundColor: Color(0xFF89BE4F),
                child: const Icon(Icons.add, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    ),
      );
}

}
