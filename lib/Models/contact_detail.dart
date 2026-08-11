import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hisabshare/Models/select_category.dart';
import 'package:hisabshare/services/notification_service.dart';
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
  final String? sharedUserId;
  final String? sharedCategoryId;
  final String? receiverContactId;
  final String? originalContactId;
 //final String currentUserName;
  final String? transactionId;
  final String? receiverCategoryId;

 const ContactDetailPage({
    required this.categoryId,
    required this.contactId,
    required this.contactName,
    this.isSharedView = false,
    this.sharedUserId,
    this.sharedCategoryId,
   this.receiverContactId,
   this.originalContactId,
  //this.currentUserName = '',
   this.transactionId,
   this.receiverCategoryId,

    Key? key,
  }) :  assert(!isSharedView || (sharedUserId != null && sharedUserId != '')),
      super(key: key); 

  @override
  _ContactDetailPageState createState() => _ContactDetailPageState();
}
class _ContactDetailPageState extends State<ContactDetailPage> {
  String? receiverContactId;
 // final userId = FirebaseAuth.instance.currentUser!.uid;
late String userId;
final GlobalKey _screenshotKey = GlobalKey();
final ScreenshotController _screenshotController = ScreenshotController();
  final ScrollController _scrollController = ScrollController();  // speed

  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> filteredTransactions = [];
  List<Map<String, dynamic>> _latestTxns = [];
  Offset fabPosition = const Offset(300, 700);

  TextEditingController searchController = TextEditingController();
  TextEditingController _noteController = TextEditingController();

  DateTime? selectedDate;
  String currentUserName = '';
  bool isLoading = false;

 Stream<List<Map<String, dynamic>>>? transactionStream;
  String? receiverCategoryId;
  String? sharedCategoryId;
 bool allowReceiverToAdd = true;

  List<Map<String, dynamic>> allTransactions = [];   //speed
  DocumentSnapshot? lastDocument;
  bool isLoadingMore = false;
  bool hasMore = true;

 // late final Stream<List<Map<String, dynamic>>> transactionStream;
@override
void initState() {
  super.initState();

  userId = FirebaseAuth.instance.currentUser!.uid;
  receiverContactId = widget.contactId;
  sharedCategoryId = widget.sharedCategoryId;
  receiverCategoryId = widget.receiverCategoryId;

  searchController.addListener(_filterTransactions);

  _scrollController.addListener(() {      // speed
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // last ke 200px pe pohanch gaye → load more
    }
  });

  if (widget.isSharedView && widget.sharedUserId != null) {
    _loadAddTransactionPermission();

    // Load the category of the sender's original contact
    _loadSharedCategoryId().then((success) {
      if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
         // const SnackBar(content: Text(" Shared ledger not found.")),
        const SnackBar(content: Text("Preparing Shared Ledger")),
        );
      } else {
        // Once shared category is known, assign the transaction stream
        if (mounted) {
          setState(() {
            transactionStream = _getTransactionStream();
          });
        }
      }
    });

    // Prompt to accept the ledger (only if not already accepted)
    if (widget.sharedCategoryId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // await Future.delayed(const Duration(milliseconds: 100));
        _fetchSenderNameAndPrompt();
      });
    }
  } else {
    //  Normal contact — fetch local info only
    _fetchCurrentUserName();
    _loadSharedWithUsers();

    // Real-time stream for normal contact
  transactionStream = _getTransactionStream();
  }
}
List<Map<String, dynamic>> sharedWithUsers = [];
Future<void> _loadSharedWithUsers() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('categories')
        .doc(widget.categoryId)
        .collection('contacts')
        .doc(widget.contactId)
        .collection('sharedWith')
        .get();

    // List of shared UIDs
    final sharedDocs = snapshot.docs;
    List<Map<String, dynamic>> enrichedUsers = [];

    for (var doc in sharedDocs) {
      final sharedUid = doc['uid']; // 
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(sharedUid).get();

      if (userDoc.exists) {
        final data = userDoc.data();
        enrichedUsers.add({
          'uid': sharedUid,
          'username': data?['username'] ?? 'No Name',
          'email': data?['email'] ?? '',
          'imageUrl': data?['imageUrl'] ?? '', 
        });
      }
    }
    setState(() {
      sharedWithUsers = enrichedUsers;
    });
  } catch (_) {
  }
}
Future<bool> _loadSharedCategoryId() async {
  final sharedUid = widget.sharedUserId;
  final originalContactId = widget.originalContactId;

  if (sharedUid == null || sharedUid.isEmpty || originalContactId == null || originalContactId.isEmpty) {
    return false;
  }
  try {
    final categoriesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(sharedUid)
        .collection('categories')
        .get();


    for (final category in categoriesSnapshot.docs) {
      final contactRef = FirebaseFirestore.instance
          .collection('users')
          .doc(sharedUid)
          .collection('categories')
          .doc(category.id)
          .collection('contacts')
          .doc(originalContactId); // FIXED

      final contactDoc = await contactRef.get();

      if (contactDoc.exists) {
        setState(() {
          sharedCategoryId = category.id;
        });

        return true;
      }
    }

    return false;

  } catch (_) {
    return false;
  }
}
Future<void> _shareContactWithUser({
  required String senderUid,
  required String receiverUid,
  required String categoryId,
  required String contactId,
}) async {
  try {
    if (receiverUid == senderUid) {
      return;
    }
    // Get receiver user data
    final receiverDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(receiverUid)
        .get();
    final receiverData = receiverDoc.data();
    if (receiverData == null) {
      return;
    }
    final sharedWithRef = FirebaseFirestore.instance
        .collection('users')
        .doc(senderUid)
        .collection('categories')
        .doc(categoryId)
        .collection('contacts')
        .doc(contactId)
        .collection('sharedWith')
        .doc(receiverUid);
 
    await sharedWithRef.set({
      'uid': receiverUid,
      'name': receiverData['username'] ?? '',
      'email': receiverData['email'] ?? '',
      'mobileNo': receiverData['mobileNo'] ?? '',
      'imageUrl': receiverData['imageUrl'] ?? '',
      'sharedAt': FieldValue.serverTimestamp(),
      'categoryId': categoryId,
      'contactId': contactId,
    }, SetOptions(merge: true));
  } catch (_) {
  }
}
Future<void> _loadAddTransactionPermission() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    if (!widget.isSharedView || widget.sharedUserId == null || widget.originalContactId == null) {
      return;
    }

    final senderUserId = widget.sharedUserId!;
    final originalContactId = widget.originalContactId!;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderUserId)
          .collection('categories')
          .doc(widget.sharedCategoryId)   // sender ka categoryId
          .collection('contacts')
          .doc(originalContactId)         // sender ka original contactId
          .collection('sharedWith')
          .doc(currentUserId)             // current receiver ka record
          .get();

      if (doc.exists) {
        final data = doc.data();
        final fetchedReceiverCategoryId = data?['categoryId'];
        final fetchedReceiverContactId = data?['receiverContactId'];

        if (fetchedReceiverCategoryId != null && fetchedReceiverContactId != null) {
          final contactDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('categories')
              .doc(fetchedReceiverCategoryId)
              .collection('contacts')
              .doc(fetchedReceiverContactId)
              .get();

          if (contactDoc.exists) {
            final allow = contactDoc.data()?['allowReceiverToAddTransactions'] ?? true;

            setState(() {
              allowReceiverToAdd = allow;
              receiverCategoryId = fetchedReceiverCategoryId;  //
              receiverContactId = fetchedReceiverContactId;    //
            });
          }
        }
      }
    } catch (_) {
    }
  }
  Future<void> _fetchSenderNameAndPrompt() async {
 // if (_hasPrompted) return; ///// 5
 // _hasPrompted = true;   ////// 6
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.sharedUserId)
        .get();

    final data = snapshot.data();

    final senderName = data != null && data['username'] != null
        ? data['username']
        : 'Someone';

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
    if (shouldAccept == true) {
      final receiverUid = FirebaseAuth.instance.currentUser!.uid;
      final senderUid = widget.sharedUserId!;

      //  ONLY create sharedWith doc in sender’s Firestore
      await _shareContactWithUser(
        senderUid: senderUid,
        receiverUid: receiverUid,
        categoryId: widget.categoryId,
        contactId: widget.contactId,
      );
 
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showChooseCategoryBottomSheet(senderName);
      });
    } else {
    }
  } catch (_) {
  }
}
Future<void> _showChooseCategoryBottomSheet(String senderName) async {
  try {
    //  Find matchedCatId
    String? matchedCatId;
    final categoriesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.sharedUserId)
        .collection('categories')
        .get();

    for (var cat in categoriesSnapshot.docs) {
      final contactDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sharedUserId)
          .collection('categories')
          .doc(cat.id)
          .collection('contacts')
          .doc(widget.contactId)
          .get();

      if (contactDoc.exists) {
        matchedCatId = cat.id;
        break;
      }
    }
    if (matchedCatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contact not found.")),
      );
      return;
    }

    //  Fetch sender’s email and mobileNo from user doc
    final senderDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.sharedUserId)
        .get();

    final senderData = senderDoc.data();
    if (senderData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sender details not found.")),
      );
      return;
    }
    final senderEmail = senderData['email'] ?? '';
    final senderMobileNo = senderData['mobileNo'] ?? '';
    final senderImageUrl = senderData['imageUrl'] ?? '';

    //  Show bottom sheet

  final receiverContactId = DateTime.now().millisecondsSinceEpoch.toString();

  //showModalBottomSheet(
  final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
     
      builder: (_) => ChooseCategoryPage(
        contactId: widget.contactId,
        contactName: widget.contactName,
        sharedUserId: widget.sharedUserId!,
        senderName: senderName,
        senderEmail: senderEmail,
        senderMobileNo: senderMobileNo,
        receiverContactId: receiverContactId,
        senderImageUrl: senderData['imageUrl'] ?? '',
      ),
    );
   if (result != null) {
  setState(() {
    this.receiverContactId = result['receiverContactId'];
    this.sharedCategoryId = result['sharedCategoryId'];
  });

  if (result['ledgerSaved'] == true) {

    // Show success SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Ledger saved successfully, login to your app to see the details."),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

/*
final senderUid = widget.sharedUserId!;
final currentUser = FirebaseAuth.instance.currentUser!;
final currentUserDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(currentUser.uid)
    .get();
final currentUserName = currentUserDoc['username'] ?? '';
print(" Navigating to ContactDetailPage with:");
print("  sharedUserId: $senderUid");
print("  sharedCategoryId: $sharedCategoryId");
print("  receiverContactId: $receiverContactId");
print("  originalContactId: ${widget.contactId}");

GoRouter.of(context).go('/home'); // or your contacts list screen
Future.delayed(Duration(milliseconds: 300), () {
GoRouter.of(context).go('/contact-detail', extra: {
  'isSharedView': true,
  'sharedUserId': senderUid,
  'sharedCategoryId': sharedCategoryId,
  'originalContactId': widget.contactId,
  'contactId': receiverContactId,
  'contactName': widget.contactName,
  'categoryId': sharedCategoryId,
  'currentUserName': currentUserName, 
});
   }); */
}
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error fetching contact data.")),
    );
  }
}
/*Future<String> _fetchSenderName() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.sharedUserId)
        .get();
    final data = snapshot.data();
    if (data != null && data['name'] != null) {
      return data['name'];
    }
  } catch (e) {
    print('⚠ Error fetching sender name: $e');
  }
  return 'Someone';
}*/
 /* Future<void> _loadCurrentUsername() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    currentUserName = userDoc.data()?['name'] ?? '';
    setState(() {}); // Important to refresh UI
  }
}*/
Future<void> _refreshManually() async {
  setState(() {
    // StreamBuilder will rebuild and re-run Firestore query
  });
}
 Future<void> _fetchCurrentUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          currentUserName = doc['username'] ?? 'You';
          //  currentUserName = data.containsKey('name') ? data['name'] : 'You';
        });
      }
    }
  }
 /* String getReversedContactName(String contactName, String currentUserName) {
    return currentUserName;
  }*/
  String getReversedContactName(String originalName, String sharedFromName) {
  return sharedFromName; // or "$sharedFromName (shared)"
}
  List<Map<String, dynamic>> reverseTransactions(List<Map<String, dynamic>> transactions) {
    return transactions.map((tx) {
      final reversedType = tx['type'] == 'Send' ? 'Receive' : 'Send';
      return {
        ...tx,
        'type': reversedType,
      };
    }).toList();
  }
  void _filterTransactions() {
  String query = searchController.text.toLowerCase();
  setState(() {
    filteredTransactions = transactions.where((item) {
      final matchDate = selectedDate == null ||
          (item['date'].year == selectedDate!.year &&
              item['date'].month == selectedDate!.month &&
              item['date'].day == selectedDate!.day);

      final typeMatch = item['type'].toLowerCase().contains(query);
      final creditMatch = item['credit'].toString().toLowerCase().contains(query);

      final matchSearch = typeMatch || creditMatch;

      return matchDate && matchSearch;
    }).toList();
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
        _filterTransactions();
      });
    }
  }
Future<void> _loadTransactions() async {
  try {
    setState(() {
      isLoading = true;
    });

    final contactRef = widget.isSharedView
        ? FirebaseFirestore.instance
            .collection('users')
            .doc(widget.sharedUserId)
            .collection('categories')
            .doc(widget.sharedCategoryId)
            .collection('contacts')
            .doc(widget.originalContactId)
        : FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('categories')
            .doc(widget.categoryId)
            .collection('contacts')
            .doc(widget.contactId);

    final snapshot = await contactRef           ///1
        .collection('pendingTransactions')
        .orderBy('date', descending: true)
        .limit(20) // Speed up first load
        .get();

    List<Map<String, dynamic>> loaded = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'date': (data['date'] as Timestamp).toDate(),
        'type': data['type'],
        'credit': data['credit'],
        'note': data['note'] ?? '',
      //  'status': data['status'] ?? 'approved',
      };
    }).toList();

    if (widget.isSharedView) {
      loaded = reverseTransactions(loaded);
    }

    setState(() {
      transactions = loaded;
      isLoading = false;
      _filterTransactions();
    });
  } catch (_) {
    setState(() {
      isLoading = false;
    });
  }
}
 /* Stream<List<Map<String, dynamic>>> _getTransactionStream() {
  final String uid = widget.isSharedView ? widget.sharedUserId! : userId;
  final String categoryId = widget.isSharedView ? sharedCategoryId ?? '' : widget.categoryId;
  final String contactId = widget.isSharedView ? widget.originalContactId ?? '' : widget.contactId;

  if (widget.isSharedView && (sharedCategoryId == null || contactId.isEmpty)) {
    print(" Cannot build stream — required info missing");
    return const Stream.empty();
  }
 /* final collectionName = widget.isSharedView && widget.sharedCategoryId == null
      ? 'pendingTransactions'
      : 'transactions';*/

  final collectionName;

   if (!widget.isSharedView) {
    //  Normal (sender’s own ledger)
    collectionName = 'transactions';
  } else {
    //  Shared view
    if (widget.sharedCategoryId == null) {
      // Receiver has NOT accepted yet → show pending
      collectionName = 'pendingTransactions';
    } else {
      // Receiver accepted → show real transactions
      collectionName = 'transactions';
    }
  }

  print("📌 Building stream with:");
  print("   UID: $uid");
  print("   Category ID: $categoryId");
  print("   Contact ID: $contactId");
  print("   Collection: $collectionName");

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('categories')
      .doc(categoryId)
      .collection('contacts')
      .doc(contactId)
      .collection(collectionName)
     // .collection('transactions')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          print("   Doc Fetched: ${doc.id} → $data");
          return {
            'id': doc.id,
            'date': (data['date'] as Timestamp).toDate(),
            'type': data['type'],
            'credit': data['credit'] ?? 0,
            'note': data['note'] ?? '',
          };
        }).toList();
      });
} */
  Future<void> _loadInitialTransactions() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
     // final actualUserId = widget.isSharedView ? widget.sharedUserId : uid;
    final actualCategoryId = widget.isSharedView ? widget.receiverCategoryId : widget.categoryId ?? '';
    final contactId = widget.contactId;

    try {
      Query query = FirebaseFirestore.instance
          .collection('users')
          //.doc(actualUserId)
          .doc(uid)
          .collection('categories')
          .doc(actualCategoryId)
          .collection('contacts')
          .doc(contactId)
          .collection('transactions')
          .orderBy('date', descending: true)
          .limit(20);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        lastDocument = snapshot.docs.last;
      } else {
      }

      setState(() {
        allTransactions = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;

          return {
            'id': doc.id,
            'date': (data['date'] as Timestamp).toDate(),
            'type': data['type'],
            'credit': data['credit'] ?? 0,
            'note': data['note'] ?? '',
            'status': data['status'] ?? '',
          };
        }).toList();
      });
    } catch (_) {
    }
  }
  Future<void> _loadMoreTransactions() async {

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final actualCategoryId = widget.isSharedView ? widget.receiverCategoryId : widget.categoryId ?? '';
    final contactId = widget.contactId;
    if (isLoadingMore || !hasMore) return;

    setState(() => isLoadingMore = true);

    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(actualCategoryId)
        .collection('contacts')
        .doc(contactId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .limit(20);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        allTransactions.addAll(snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'date': (data['date'] as Timestamp).toDate(),
            'type': data['type'],
            'credit': data['credit'] ?? 0,
            'note': data['note'] ?? '',
          };
        }).toList());
        lastDocument = snapshot.docs.last;
      });
    } else {
      hasMore = false;
    }

    setState(() => isLoadingMore = false);
  }
  Stream<List<Map<String, dynamic>>> _getTransactionStream() {
    final String uid = userId;
    late final String categoryId;
    late final String contactId;

    if (!widget.isSharedView) {
      categoryId = widget.categoryId;
      contactId = widget.contactId;
    } else {
      categoryId = widget.receiverCategoryId ?? '';
      contactId = receiverContactId ?? widget.originalContactId ?? '';
    }

    if (widget.isSharedView && (categoryId.isEmpty || contactId.isEmpty)) {
      return const Stream.empty();
    }

    return TransactionService.transactionStream(
      uid: uid,
      categoryId: categoryId,
      contactId: contactId,
      filterAccepted: widget.isSharedView,
    );
  }

  Future<void> _addTransaction(Map<String, dynamic> transaction) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final senderTxnRef = await TransactionService.createSenderTransaction(
        currentUserId: currentUserId,
        categoryId: widget.categoryId,
        contactId: widget.contactId,
        sharedUserId: widget.sharedUserId,
        sharedCategoryId: sharedCategoryId,
        receiverContactId: receiverContactId,
        transaction: transaction,
      );
      _noteController.clear();
      await TransactionService.fanOutToSharedUsers(
        currentUserId: currentUserId,
        categoryId: widget.categoryId,
        contactId: widget.contactId,
        senderTxnRef: senderTxnRef,
        transaction: transaction,
      );

      if (transaction['type'] == 'Receive') {
        await NotificationService().showNotification(
          title: 'Payment Received',
          body: 'You received Rs.${transaction['credit']} from ${widget.contactName}.',
        );
      }

      setState(() {
        transactionStream = _getTransactionStream();
      });
    } catch (_) {
    }
  }
  Future<void> _shareCsv() async {
    await StatementExportService.shareCsv(context, transactions, widget.contactName);
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
                   // final TextEditingController localNoteController = TextEditingController();
                    Navigator.pop(context);
                    _addTransaction({
                      'date': selectedTxDate,
                      'type': selectedType,
                      'credit':
                          double.tryParse(creditController.text) ?? 0.0,
                      //'note': localNoteController.text.trim(),
                     // 'note': _noteController.text.trim(),
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
  double totalBalance = 0.0;
 return Screenshot(
    controller: _screenshotController,
    child: Scaffold(
      appBar: AppBar(
        title: Text( widget.isSharedView && currentUserName.isNotEmpty
      ? getReversedContactName(widget.contactName, currentUserName)
      : widget.contactName,),
        backgroundColor: Color(0xFF89BE4F),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
          // onPressed: _generatePdfOnly,
         onPressed: () {
  final displayName = widget.isSharedView && currentUserName.isNotEmpty
      ? getReversedContactName(widget.contactName, currentUserName)
      : widget.contactName;

  StatementExportService.generateAndSavePdf(context, _latestTxns, displayName);
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
              'https://hisabshare.com/contact/${widget.contactId}/${encodedName}?senderId=${senderId}&categoryId=$encodedCategoryId&isShared=true';

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
       // bottom: TabBar(tabs: [Tab(text: 'Own',), Tab(text: 'Received',)]),
      ),
   body: Column(
  children: [
    // 1️ Total Balance under AppBar
    StreamBuilder<List<Map<String, dynamic>>>(
//stream: _getTransactionStream(),
      stream: transactionStream,
      builder: (context, snapshot) {
        double balance = 0.0;
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          for (var tx in snapshot.data!) {
            final amount = (tx['credit'] as num).toDouble();   //Double to Int
            if (widget.isSharedView) {
              balance += tx['type'] == 'Send' ? amount : -amount;
            } else {
              balance += tx['type'] == 'Receive' ? amount : -amount;
            }
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
              //  "Rs${balance.abs().toStringAsFixed(2)}",
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
              children: const [
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
   //     stream: _getTransactionStream(),
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
          //List<Map<String, dynamic>> txns = snapshot.data!;
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
    //  Flip type if shared view
    String type = txn['type'].toLowerCase();
    if (widget.isSharedView) {
      if (type == 'send') type = 'receive';
      else if (type == 'receive') type = 'send';
    }
    final typeMatch = type.contains(query);
    final creditMatch = txn['credit'].toString().toLowerCase().contains(query);

    return typeMatch || creditMatch;
  }).toList();
}
        return RefreshIndicator(
  onRefresh: _refreshManually,
  child: ListView.builder(
         // return ListView.builder(
    controller: _scrollController,  // speed 1
    itemCount: txns.length + (isLoadingMore ? 1 : 0), //speed 2
          //  itemCount: txns.length,
            itemBuilder: (context, index) {
              if (index >= txns.length) {   //speed 3
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final tx = txns[index];
              final transactionId = tx['id'];
              final txDate = tx['date'] as DateTime;
              final isReceive = widget.isSharedView
                  ? tx['type'] == 'Send'
                  : tx['type'] == 'Receive';

              final arrow = isReceive ? '⬇️' : '⬆️';
              final color = isReceive ? Colors.green : Colors.red;
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
                  //  ? "⬆️ Rs.${(tx['credit'] as num).toStringAsFixed(0)}"
                    ? "Rs.${(tx['credit'] as num).toStringAsFixed(0)}"
                    : "-", //
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            // Receive Column
            Expanded(
              child: Text(
                tx['type'] == 'Receive'
                 //   ? "⬇️ Rs.${(tx['credit'] as num).toStringAsFixed(0)}"
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
            final currentUserId = FirebaseAuth.instance.currentUser!.uid;

           String existingNote = "";
            if (transactionId != null) {
              final noteDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId) //
                  .collection('categories')
                  .doc(widget.categoryId)
                  .collection('contacts')
                  .doc(widget.contactId)
                  .collection('transactions')
                  .doc(transactionId)
                  .get();

              if (noteDoc.exists && noteDoc.data()!.containsKey("note")) {
                existingNote = noteDoc['note'];
              }
            }
            if (existingNote.isNotEmpty) {
              _noteController.text = existingNote;
            } else {
              _noteController.clear();
            }
             /*String existingNote = tx['note'] ?? '';
            _noteController.text = existingNote; */
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
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUserId)
                              .collection('categories')
                              .doc(widget.categoryId)
                              .collection('contacts')
                              .doc(widget.contactId)
                              .collection('transactions')
                              .doc(transactionId)
                              .set({
                            "note": noteText,
                            "updatedAt": FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                        }
                        Navigator.pop(context);
                        setState(() {});
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

