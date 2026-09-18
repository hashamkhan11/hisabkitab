import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisabshare/repositories/contact_repository.dart';
import 'package:hisabshare/screens/select_category.dart';
import 'package:hisabshare/services/api_client.dart';
import 'package:hisabshare/services/statement_export_service.dart';
import 'package:hisabshare/services/transaction_service.dart';
import 'package:hisabshare/theme/app_theme.dart';
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
        if (mounted) _leaveShareFlow();
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
              duration: Duration(seconds: 4),
            ),
          );
        }
        _startStream();
      } else if (mounted) {
        _leaveShareFlow();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this ledger invite. It may have expired.')),
        );
        _leaveShareFlow();
      }
    }
  }

  /// Backs out of the pending-share flow. Reached both from a normal push
  /// (something to pop back to) and from a cold-start deep link where this
  /// page is the only thing on the stack - in that case popping would do
  /// nothing and leave a blank screen, so fall back to the app's home route.
  void _leaveShareFlow() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add transaction: $e')),
        );
      }
    }
  }

  Future<void> _shareCsv() async {
    await StatementExportService.shareCsv(context, _latestTxns, widget.contactName);
  }

  Future<String?> _promptEmail(String title, String confirmLabel) {
    final emailController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Recipient email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, emailController.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _emailInvite() async {
    final email = await _promptEmail('Email ledger invite', 'Send');
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await ContactRepository.sendInviteEmail(_contactId, email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite sent to $email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send invite: $e')),
        );
      }
    }
  }

  Future<void> _emailStatement() async {
    final email = await _promptEmail('Email statement', 'Send');
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await StatementExportService.emailStatement(_latestTxns, widget.contactName, email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statement sent to $email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send statement: $e')),
        );
      }
    }
  }

  void _showAddTransactionDialog() {
    final c = context.appColors;
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
                    contentPadding: EdgeInsets.zero,
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
                        onSelected: (_) => setStateDialog(() => selectedType = "Send"),
                        selectedColor: c.dangerSoft,
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("Receive"),
                        selected: selectedType == "Receive",
                        onSelected: (_) => setStateDialog(() => selectedType = "Receive"),
                        selectedColor: c.accentSoft,
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _addTransaction({
                      'date': selectedTxDate,
                      'type': selectedType,
                      'credit': double.tryParse(creditController.text) ?? 0.0,
                    });
                    _noteController.clear();
                    setState(() {});
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNoteDialog(Map<String, dynamic> tx) {
    final transactionId = tx['id'];
    String existingNote = (tx['note'] as String?) ?? '';
    _noteController.text = existingNote;
    String noteText = existingNote;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Note"),
          content: TextField(
            controller: _noteController,
            maxLines: 5,
            decoration: const InputDecoration(hintText: "Write your note here..."),
            onChanged: (txt) => noteText = txt.trim(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
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
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Failed to save note: $e')),
                      );
                    }
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Save"),
            )
          ],
        );
      },
    );
  }

  Future<void> _shareScreenshot() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) return;
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/screenshot.png';
      final imageFile = await File(path).create();
      await imageFile.writeAsBytes(image);

      final xFile = XFile(path);
      final senderId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final encodedName = Uri.encodeComponent(widget.contactName);
      final encodedCategoryId = Uri.encodeComponent(widget.categoryId);

      final shareableLink =
          '${ApiClient.shareLinkBaseUrl}/contact/${widget.contactId}/$encodedName?senderId=$senderId&categoryId=$encodedCategoryId&isShared=true';

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text:
              'Check out this contact\'s transactions: $shareableLink\n\nDownload our app: https://play.google.com/store/apps/details?id=com.ranksol.hisabshare',
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Screenshot(
      controller: _screenshotController,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export PDF',
              onPressed: () => StatementExportService.generateAndSavePdf(context, _latestTxns, widget.contactName),
            ),
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Export CSV',
              onPressed: _shareCsv,
            ),
            if (!widget.isSharedView)
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share',
                onPressed: _shareScreenshot,
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.email_outlined),
              tooltip: 'Email',
              onSelected: (value) {
                if (value == 'invite') {
                  _emailInvite();
                } else if (value == 'statement') {
                  _emailStatement();
                }
              },
              itemBuilder: (context) => [
                if (!widget.isSharedView)
                  const PopupMenuItem(value: 'invite', child: Text('Email ledger invite')),
                const PopupMenuItem(value: 'statement', child: Text('Email statement')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.contactName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
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
                final positive = balance >= 0;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c.accent, c.accentStrong],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL BALANCE',
                            style: TextStyle(
                              color: c.onAccent.withValues(alpha: .85),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rs ${balance.abs().toStringAsFixed(0)}',
                            style: TextStyle(color: c.onAccent, fontSize: 24, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.onAccent.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          positive ? "They'll pay you" : "You owe them",
                          style: TextStyle(color: c.onAccent, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 15),
                    label: Text(
                      selectedDate != null
                          ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                          : "Date",
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                  if (selectedDate != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => selectedDate = null),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: "Search by type",
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                  if (snapshot.data!.isEmpty) {
                    return Center(
                      child: Text('No transactions yet', style: TextStyle(color: c.textMuted)),
                    );
                  }
                  _latestTxns = snapshot.data!;

                  // Compute a running balance in chronological order so the
                  // most recent (top-of-list) row's balance matches the header.
                  final chronological = List<Map<String, dynamic>>.from(_latestTxns)
                    ..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
                  double running = 0.0;
                  final withBalance = <Map<String, dynamic>>[];
                  for (final tx in chronological) {
                    final amount = (tx['credit'] as num).toDouble();
                    running += tx['type'] == 'Receive' ? amount : -amount;
                    withBalance.add({...tx, '_runningBalance': running});
                  }
                  var txns = withBalance.reversed.toList();

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
                      final creditMatch = txn['credit'].toString().toLowerCase().contains(query);
                      return type.contains(query) || creditMatch;
                    }).toList();
                  }

                  if (txns.isEmpty) {
                    return Center(
                      child: Text('No matching transactions', style: TextStyle(color: c.textMuted)),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshManually,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                      itemCount: txns.length,
                      itemBuilder: (context, index) {
                        final tx = txns[index];
                        final txDate = tx['date'] as DateTime;
                        final showDateHeader = index == 0 ||
                            !_sameDay(txDate, txns[index - 1]['date'] as DateTime);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDateHeader) ...[
                              if (index != 0) const SizedBox(height: 12),
                              Text(
                                _formatDateHeader(txDate),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: c.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            _TransactionRow(tx: tx, onNoteTap: () => _showNoteDialog(tx)),
                          ],
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
            : FloatingActionButton(
                onPressed: _showAddTransactionDialog,
                child: const Icon(Icons.add),
              ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  final VoidCallback onNoteTap;

  const _TransactionRow({required this.tx, required this.onNoteTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isReceive = tx['type'] == 'Receive';
    final isRejected = tx['status'] == 'rejected';
    final amount = (tx['credit'] as num).toDouble();
    final hasNote = ((tx['note'] as String?) ?? '').isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRejected ? c.dangerSoft : c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isReceive ? c.accentSoft : c.dangerSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isReceive ? Icons.call_received_rounded : Icons.call_made_rounded,
              color: isReceive ? c.accentStrong : c.danger,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(isReceive ? 'Receive' : 'Send', style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (isRejected) ...[
                      const SizedBox(width: 6),
                      Text('· rejected', style: TextStyle(color: c.danger, fontSize: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isReceive ? '+' : '-'}Rs ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isReceive ? c.accentStrong : c.danger,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onNoteTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                hasNote ? Icons.sticky_note_2_rounded : Icons.sticky_note_2_outlined,
                size: 18,
                color: hasNote ? c.accentStrong : c.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
