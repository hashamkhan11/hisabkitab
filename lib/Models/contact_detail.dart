import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hisabshare/Models/select_category.dart';
import 'package:hisabshare/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:screenshot/screenshot.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

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
  _loadInitialTransactions();

  userId = FirebaseAuth.instance.currentUser!.uid;
  receiverContactId = widget.contactId;
  sharedCategoryId = widget.sharedCategoryId;
  receiverCategoryId = widget.receiverCategoryId;

  print('@@@ isSharedView: ${widget.isSharedView}');
  print('@@@ sharedUserId: ${widget.sharedUserId}');
  print('@@@ userId: $userId');
  print('@@@ contactId: ${widget.contactId}');
  print('@@@ categoryId: ${widget.categoryId}');
  print('@@@ receiverCategoryId: ${widget.receiverCategoryId}');

  searchController.addListener(_filterTransactions);

  _scrollController.addListener(() {      // speed
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // last ke 200px pe pohanch gaye → load more
      _loadMoreTransactions();
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
    print("////// LoadShared With Users: ${widget.contactId}");

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
    print(" SharedWith Users Loaded:");
    for (var user in sharedWithUsers) {
      print(" ${user['username']} - Avatar: ${user['imageUrl']}");
    }
  } catch (e) {
    print(' Error loading sharedWith users: $e');
  }
} 
Future<bool> _loadSharedCategoryId() async {
  print("////// Load Category using originalContactId: ${widget.originalContactId}");

  final sharedUid = widget.sharedUserId;
  final originalContactId = widget.originalContactId;

  if (sharedUid == null || sharedUid.isEmpty || originalContactId == null || originalContactId.isEmpty) {
    print(" Invalid sharedUserId or originalContactId");
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

        print(" Shared Category Found: $sharedCategoryId");
         print(" originalContactId to use: ${widget.originalContactId}");
        return true;
      }
    }

    print("⚠ Contact not found in any category of shared user.");
    return false;

  } catch (e) {
    print(" Error loading shared category ID: $e");
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
      print(" Cannot share contact with yourself.");
      return;
    }
    // Get receiver user data
    final receiverDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(receiverUid)
        .get();
    final receiverData = receiverDoc.data();
    if (receiverData == null) {
      print(" Receiver user data not found.");
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
 
    print(" Contact shared successfully with $receiverUid in sender’s sharedWith.");
  } catch (e) {
    print(" Error sharing contact: $e");
  }
}
Future<void> _loadAddTransactionPermission() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    if (!widget.isSharedView || widget.sharedUserId == null || widget.originalContactId == null) {
      print(" Not in shared view or missing info.");
      return;
    }

    final senderUserId = widget.sharedUserId!;
    final originalContactId = widget.originalContactId!;

    print("👁 Fetching receiver category from sharedWith: users/$senderUserId/categories/${widget.sharedCategoryId}/contacts/$originalContactId/sharedWith/$currentUserId");

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
          print(" Receiver saved in category: $fetchedReceiverCategoryId");

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

            print(" allowReceiverToAdd: $allow");
          }
        }
      }
    } catch (e) {
      print(" Error fetching shared contact permission: $e");
    }
  }
  Future<void> _fetchSenderNameAndPrompt() async {
 // if (_hasPrompted) return; ///// 5
 // _hasPrompted = true;   ////// 6
  try {
    print(' Fetching sender name for UID: ${widget.sharedUserId}');
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.sharedUserId)
        .get();
 
    final data = snapshot.data();
    print(' Fetched Firestore data: $data');
 
    final senderName = data != null && data['username'] != null
        ? data['username']
        : 'Someone';
    print(' Sender name resolved to: $senderName');
 
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
      print(' User accepted ledger from $senderName');
 
      final receiverUid = FirebaseAuth.instance.currentUser!.uid;
      final senderUid = widget.sharedUserId!;
 
      //  ONLY create sharedWith doc in sender’s Firestore
      print("////sharewith doc in senderFirestore: ${widget.contactId}");

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
      print(' User declined the ledger.');
    }
  } catch (e) {
    print(' Error fetching sender name or showing prompt: $e');
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
      print("/////ChooseCategory BottomSheet: ${widget.contactId}");

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

    print("///// navigate to choosecat: ${widget.contactId}");
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
  print("Result from bottom sheet: $result");
  setState(() {
    this.receiverContactId = result['receiverContactId'];
    this.sharedCategoryId = result['sharedCategoryId'];
  });

  print(" Contact accepted, reverse contact ID: $receiverContactId");
  print(" Saved under shared category: $sharedCategoryId");

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
  } catch (e) {
    print("Error fetching contact data: $e");
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
  print("Filtered Transactions: ${filteredTransactions.length}");
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

    print(" ///// load Transaction: ${widget.contactId}");

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
  } catch (e) {
    print("Error loading transactions: $e");
    setState(() {
      isLoading = false;
    });
  }
}
 Widget _buildTransactionSection() {
  if (widget.isSharedView && sharedCategoryId == null) {
    return const Center(
      child: Text("⚠ Accept the ledger to view transactions."),
    );
  }

  return Expanded(
    child: StreamBuilder<List<Map<String, dynamic>>>(
      stream: transactionStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text(" Error loading transactions"));
        }

        final txns = snapshot.data ?? [];

        if (txns.isEmpty) {
          return const Center(child: Text("No transactions yet"));
        }

        final displayedTxns = widget.isSharedView
            ? reverseTransactions(txns)
            : txns;
        final balance = calculateBalance(displayedTxns);

        return RefreshIndicator(
          onRefresh: _refreshManually, //  refresh logic here
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: displayedTxns.length + 1, // +1 for balance section
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance: Rs. ${balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }
////
              final txn = displayedTxns[index - 1];
              return ListTile(
                title: Text(txn['type']),
                subtitle: Text(txn['date'].toString()),
                trailing: Text("Rs. ${txn['credit']}"),
              );
            },
          ),
        );
      },
    ),
  );
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

    print("### Loading initial transactions...");
   // print("### actualUserId=$actualUserId");
    print("###userId=$uid");
    print("### actualCategoryId=$actualCategoryId");
    print("### contactId=$contactId");
    print("### isSharedView=${widget.isSharedView}");

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

      print("### Snapshot docs count: ${snapshot.docs.length}");

      if (snapshot.docs.isNotEmpty) {
        lastDocument = snapshot.docs.last;
      } else {
        print("### No transactions found for this contact!");
      }

      setState(() {
        allTransactions = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          print("### Tx loaded => ${doc.id} | ${data['credit']} | ${data['type']}");

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
    } catch (e, st) {
      print("Error loading initial transactions: $e");
      print(st);
    }
  }
  Future<void> _loadMoreTransactions() async {

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final actualCategoryId = widget.isSharedView ? widget.receiverCategoryId : widget.categoryId ?? '';
    final contactId = widget.contactId;
    if (isLoadingMore || !hasMore) return;

    print("Loading more transactions...");
    print("---userId=$uid");
    print("---actualCategoryId=$actualCategoryId");
    print("---contactId=$contactId");

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
      print(" Starting after last doc: ${lastDocument!.id}");
      query = query.startAfterDocument(lastDocument!);
    }

    final snapshot = await query.get();
    print(" More docs fetched: ${snapshot.docs.length}");

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        allTransactions.addAll(snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          print(" Appended transaction: ${doc.id} → ${data['note']}");
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
      print(" No more transactions found.");
      hasMore = false;
    }

    setState(() => isLoadingMore = false);
  }
  /*Stream<List<Map<String, dynamic>>> _getTransactionStream() {
    //  Always current logged-in user
    final String uid = userId;
    late final String categoryId;
    late final String contactId;

    if (!widget.isSharedView) {
      categoryId = widget.categoryId;
      contactId = widget.contactId;
    } else {
      print('~~~~~~~~~~~${widget.receiverCategoryId}');

      categoryId = widget.receiverCategoryId ?? widget.receiverCategoryId ?? '';
      contactId = receiverContactId ?? widget.originalContactId ?? '';
    }

    if (widget.isSharedView && (categoryId.isEmpty || contactId.isEmpty)) {
      print(" Cannot build stream — required info missing");
      return const Stream.empty();
    }

    final String collectionName;
    if (!widget.isSharedView) {
      collectionName = 'transactions';
    } else {
      if (widget.receiverCategoryId == null) {
        collectionName = 'pendingTransactions';
      } else {
        collectionName = 'transactions';
      }
    }

    print("   Building stream with:");
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
        .orderBy('date', descending: true)
        .limit(20)
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
          'status': data['status'] ?? '',
        };
      }).toList();
    });
  }*/
  Stream<List<Map<String, dynamic>>> _getTransactionStream() {
    print("Transaction called ");
    final String uid = userId;
    late final String categoryId;
    late final String contactId;

    if (!widget.isSharedView) {
      categoryId = widget.categoryId;
      contactId = widget.contactId;
    } else {
      print('~~~~~~~~~~~${widget.receiverCategoryId}');
      categoryId = widget.receiverCategoryId ?? '';
      contactId = receiverContactId ?? widget.originalContactId ?? '';
    }

    if (widget.isSharedView && (categoryId.isEmpty || contactId.isEmpty)) {
      print(" Cannot build stream — required info missing");
      return const Stream.empty();
    }

    print("   Building stream with:");
    print("   UID: $uid");
    print("   Category ID: $categoryId");
    print("   Contact ID: $contactId");

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(categoryId)
        .collection('contacts')
        .doc(contactId)
        .collection('transactions');

    if (widget.isSharedView) {
      print("query");
      query = query.where('status', isEqualTo: 'accepted');
    }
    return query
        .orderBy('date', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        print("   Doc Fetched: ${doc.id} → $data");

        String finalType = data['type'] ?? '';
        if (widget.isSharedView) {
          if (finalType == "Send") {
            finalType = "Receive";
          } else if (finalType == "Receive") {
            finalType = "Send";
          }
        }
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
  }

  Future<void> _addTransaction(Map<String, dynamic> transaction) async {
    print(" Transaction Map Before Add: $transaction");

    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      // final safeNote = (transaction['note'] ?? "").toString();
      print("Adding transaction by sender: $currentUserId");
      final senderSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      final senderName = senderSnap.data()?['name'] ?? 'Unknown';
      print(" Adding transaction for:");
      print("User: $currentUserId");
      print("Category: ${widget.categoryId}");
      print("Contact: ${widget.contactId}");
      print(" Note : ${transaction['note']}");
      // Add to Sender’s Transactions
      final senderTxnRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('categories')
          .doc(widget.categoryId)
          .collection('contacts')
          .doc(widget.contactId)
          .collection('transactions')
          .add({
        'date': transaction['date'],
        'type': transaction['type'],
        'credit': transaction['credit'],
        'note': transaction['note'] ?? "",
        'timestamp': FieldValue.serverTimestamp(),

        // Sender info
        'transactionId': '',
        'userId': currentUserId,
        'senderId': currentUserId,
        'senderCategoryId': widget.categoryId,
        'senderContactId': widget.contactId,

        // Receiver info
        'receiverUserId': widget.sharedUserId,
        'receiverCategoryId': sharedCategoryId,
        'receiverContactId': receiverContactId,

        // Shared structure
        'sharedUserId': null,
        'sharedCategoryId': widget.categoryId,
        'status': 'pending',
      });
//  for Sender’s Transaction
      print(" Note added: ${transaction['note']}");
      print(" Sender Transaction Created");
      print("transactionId       : ()");
      print("senderUserId        : $currentUserId");
      print("senderCategoryId    : ${widget.categoryId}");
      print("senderContactId     : ${widget.contactId}");
      print("receiverUserId      : ${widget.sharedUserId}");
      print("receiverCategoryId  : ${sharedCategoryId}");
      print("receiverContactId   : ${receiverContactId}");

      //  transactionId update
      await senderTxnRef.update({'transactionId': senderTxnRef.id});
      _noteController.clear();

      print(" Sender transaction added: ${transaction['type']} Rs.${transaction['credit']}");

      //  Loop over all shared users → Add to PENDING + Notification
      final sharedWithSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('categories')
          .doc(widget.categoryId)
          .collection('contacts')
          .doc(widget.contactId)
          .collection('sharedWith')
          .get();

      // helper function to reverse type
      String reversedType(String type) {
        return type == 'Send' ? 'Receive' : 'Send';
      }

      for (var doc in sharedWithSnapshot.docs) {
        final sharedUserId = doc['uid'];
         final sharedCategoryId = doc['categoryId'];   //accept k lye
        //  final sharedCategoryId = widget.categoryId;  //Rejection k lye
        final receiverContactId = doc['receiverContactId'];
        print(" Sharing request with $sharedUserId in category $sharedCategoryId");
        print(" Sender Note: ${transaction['note']}");
        //  Add to PENDING (receiver side)
        // Make a doc with ID first
        final pendingRef = FirebaseFirestore.instance
            .collection('users')
            .doc(sharedUserId)
            .collection('categories')
            .doc(sharedCategoryId)
            .collection('contacts')
            .doc(receiverContactId)
            .collection('transactions')
            .doc();

// Create transaction data
        final pendingData = {
          'transactionId': pendingRef.id,  //  already available
          'date': transaction['date'],
          'type': reversedType(transaction['type']),
          'typeOriginal': transaction['type'],
          'credit': transaction['credit'],
          'userId': sharedUserId,
          'senderId': currentUserId,
          'sharedCategoryId': sharedCategoryId,
          'receiverContactId': receiverContactId,
          'receiverCategoryId': sharedCategoryId,
          'sharedUserId': sharedUserId,
          'status': 'pending',
          'senderTransactionId': senderTxnRef.id,
          'senderCategoryId': widget.categoryId,
          'senderContactId': widget.contactId,
        };
        await pendingRef.set(pendingData);
        print(" Pending transaction created: ${pendingRef.id}");

        /* final pendingRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(sharedUserId)
            .collection('categories')
            .doc(sharedCategoryId)   // accpt or reject both working on it
           // .doc(receiverCategoryId) // receiver k ledger mai accept k lye
            .collection('contacts')
            .doc(receiverContactId)
           // .collection('pendingTransactions')
        .collection('transactions')
            .add({
          'date': transaction['date'],
          'type': reversedType(transaction['type']),
          'typeOriginal': transaction['type'],
          'credit': transaction['credit'],
          //'note': transaction['note'] ?? "",
         // 'note': safeNote.isNotEmpty ? safeNote : "No Note",
          'userId': sharedUserId,
          'senderId': currentUserId,
          'sharedCategoryId': sharedCategoryId,
          'receiverContactId': receiverContactId,
          'receiverCategoryId': sharedCategoryId,
          'sharedUserId': sharedUserId,
          'status': 'pending',

          'senderTransactionId': senderTxnRef.id,
          'senderCategoryId': widget.categoryId,
          'senderContactId': widget.contactId,
        });
        */
        /* final receiverTxnRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(sharedUserId)
            .collection('categories')
            .doc(sharedCategoryId)
            .collection('contacts')
            .doc(receiverContactId)
            .collection('transactions')
            .add({
          'date': transaction['date'],
          'type': reversedType(transaction['type']),
          'typeOriginal': transaction['type'],
          'credit': transaction['credit'],
          'note': transaction['note'] ?? "",
          'userId': sharedUserId,
          'senderId': currentUserId,
          'sharedCategoryId': sharedCategoryId,
          'receiverContactId': receiverContactId,
          'receiverCategoryId': sharedCategoryId,
          'sharedUserId': sharedUserId,
          'senderTransactionId': senderTxnRef.id,
          'senderCategoryId': widget.categoryId,
          'senderContactId': widget.contactId,
          'status': 'pending',
        });

          // save transactionId inside doc
        await receiverTxnRef.update({'transactionId': receiverTxnRef.id}); */

        //  Debug Print for Pending Transaction
       // print("Note being saved in PendingTransaction: '$safeNote'");
        print("Note being saved in PendingTransaction: ${transaction['note']}");
        print("Pending Transaction Created for Receiver");
        print("transactionId       : ${pendingRef.id}");
        print("senderUserId        : $currentUserId");
        print("sharedUserId        : $sharedUserId");
        print("sharedCategoryId    : $sharedCategoryId");
        print("receiverContactId   : $receiverContactId");
        print("receiverCategoryId  : $sharedCategoryId");
        print("note                : ${transaction['note']}");

        await pendingRef.update({'transactionId': pendingRef.id});
        print(" Pending transaction created: ${pendingRef.id}");

        //  Add Notification (receiver side, senderName)
        String notificationBody;

        if (transaction['type'].toString().toLowerCase() == 'send') {
          notificationBody = 'You received Rs.${transaction['credit']} from $senderName.';
        } else if (transaction['type'].toString().toLowerCase() == 'receive') {
          notificationBody = 'You sent Rs.${transaction['credit']} to $senderName.';
        } else {
          notificationBody = 'Transaction of Rs.${transaction['credit']} with $senderName.';
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(sharedUserId)
            .collection('notifications')
            .add({
          'title': 'Payment Request',
          //'body': 'You received Rs.${transaction['credit']} from $senderName.',
          'body': notificationBody,
          'timestamp': Timestamp.now(),
          'isRead': false,
          'type': 'transaction_request',
          'transactionId': pendingRef.id,
          'pendingTransactionId': pendingRef.id,
          'sharedCategoryId': sharedCategoryId,
          'receiverContactId': receiverContactId,
          'senderId': currentUserId,
          'senderName': senderName,
          'senderTransactionId': senderTxnRef.id,
          'senderCategoryId': widget.categoryId,
          'senderContactId': widget.contactId,
          'receiverCategoryId': sharedCategoryId,
        });
        print(" Notification created with ID: ${pendingRef.id}");
        print(" Notification sent to $sharedUserId");
      }

      //  Local notification (agar Receive hua to)
      if (transaction['type'] == 'Receive') {
        await NotificationService().showNotification(
          title: 'Payment Received',
          body: 'You received Rs.${transaction['credit']} from ${widget.contactName}.',
        );
      }

      //  Refresh transaction stream
      setState(() {
        transactionStream = _getTransactionStream();
      });

      print(" Transaction process completed successfully.");
    } catch (e) {
      print(" Error adding transaction: $e");
    }
  }
/*  Future<void> _addTransaction(Map<String, dynamic> transaction) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      print("Adding transaction by sender: $currentUserId");

      print("👉 Adding transaction for:");
      print("User: $currentUserId");
      print("Category: ${widget.categoryId}");
      print("Contact: ${widget.contactId}");

      //  Add to Sender’s Transactions
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('categories')
          .doc(widget.categoryId)
          .collection('contacts')
          .doc(widget.contactId)
        .collection('transactions')
          .add({
        'date': transaction['date'],
        'type': transaction['type'],
        'credit': transaction['credit'],
        'userId': currentUserId,
        'note': transaction['note'] ?? "",
        'timestamp': FieldValue.serverTimestamp(),
      });

      print("✅ Transaction added for $currentUserId → ${transaction['type']} Rs.${transaction['credit']}");
      print(" Sender transaction added: ${transaction['type']} Rs.${transaction['credit']}");

      //  Loop over all shared users → Add to PENDING + Notification only
      final sharedWithSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('categories')
          .doc(widget.categoryId)
          .collection('contacts')
          .doc(widget.contactId)
          .collection('sharedWith')
          .get();

      final reversedType = transaction['type'] == 'Send' ? 'Receive' : 'Send';

        for (var doc in sharedWithSnapshot.docs) {
        final sharedUserId = doc['uid'];
        final sharedCategoryId = doc['categoryId'];
        final receiverContactId = doc['receiverContactId'];

        print("➡ Sharing request with $sharedUserId in category $sharedCategoryId");

        print("👉 Adding transaction for:");
        print("User: $sharedUserId");
        print("Category: $sharedCategoryId");
        print("Contact: $receiverContactId");

        // Add to PENDING (receiver side)
        final pendingRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(sharedUserId)
            .collection('categories')
            .doc(sharedCategoryId)
            .collection('contacts')
            .doc(receiverContactId)
            .collection('pendingTransactions')
            .add({

          'date': transaction['date'],
          'type': reversedType,
          'typeOriginal': transaction['type'], // original bhi save karo  //2
          'credit': transaction['credit'],
          'note': transaction['note'] ?? "",
          'userId': sharedUserId,
          'senderId': currentUserId,
          'sharedCategoryId': sharedCategoryId,
          'receiverContactId': receiverContactId,
          'status': 'pending',
        });
         await pendingRef.update({'transactionId': pendingRef.id});  //1
        print(" Pending transaction created: ${pendingRef.id}");

        //  Add Notification (receiver side)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(sharedUserId)
            .collection('notifications')
            .add({
          'title': 'Payment Request',
          'body': 'You received Rs.${transaction['credit']} from ${widget.contactName}.',
          'timestamp': Timestamp.now(),
          'isRead': false,
          'type': 'transaction_request',
          'pendingTransactionId': pendingRef.id, // link to pending txn
          'sharedCategoryId': sharedCategoryId,
          'receiverContactId': receiverContactId,
          'senderId': currentUserId,
        });

        print(" Notification sent to $sharedUserId");
      }

      //  (Optional) Local notification for sender if they received money
      if (transaction['type'] == 'Receive') {
        await NotificationService().showNotification(
          title: 'Payment Received',
          body: 'You received Rs.${transaction['credit']} from ${widget.contactName}.',
        );
      }

      setState(() {
        transactionStream = _getTransactionStream();
      });

      print(" Transaction process completed successfully.");
    } catch (e) {
      print(" Error adding transaction: $e");
    }
  } */
  /* Future<void> _addTransaction(Map<String, dynamic> transaction) async {
    print("Adding transaction into RECEIVER TRANSACTIONS...");
  try {
    print("/-/-/-/-/-/Add Transaction - 1: ${widget.contactId}");
    
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    print(" Adding transaction by sender: $currentUserId");

    // 1️ Add to Sender's Firestore Path
    print("Adding transaction into RECEIVER TRANSACTIONS...");
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('categories')
        .doc(widget.categoryId)
        .collection('contacts')
        .doc(widget.contactId)
        .collection('transactions')
        .add({
      'date': transaction['date'],
      'type': transaction['type'],
      'credit': transaction['credit'],
      'userId': currentUserId,

    });
print(" Sender transaction added: ${transaction['type']} Rs.${transaction['credit']}");

    // 2️ Loop over all shared users and write to their paths
  
    print("///// loop over all shared path: ${widget.contactId}");

    final sharedWithSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('categories')
        .doc(widget.categoryId)
        .collection('contacts')
        .doc(widget.contactId)
        .collection('sharedWith')
        .get();

    final reversedType = transaction['type'] == 'Send' ? 'Receive' : 'Send';

   for (var doc in sharedWithSnapshot.docs) {
  final sharedUserId = doc['uid'];
  final sharedCategoryId = doc['categoryId'];
   // FIX: get correct receiver category
  print(" Sharing transaction with: $sharedUserId into category $sharedCategoryId");

final receiverContactId = doc['receiverContactId'];

  print(" ///// Add reverse Transaction: ${widget.contactId}");
 /* await FirebaseFirestore.instance
      .collection('users')
      .doc(sharedUserId)
      .collection('categories')
      .doc(sharedCategoryId) // Use correct shared category
      .collection('contacts')
     // .doc(widget.contactId)
      .doc(receiverContactId)
      .collection('transactions')
      .add({
    'date': transaction['date'],
    'type': reversedType,
    'credit': transaction['credit'],
    'userId': sharedUserId,
  });*/
 final reversedType = transaction['type'] == 'Send' ? 'Receive' : 'Send';

  // 1️ Save to PENDING transactions (receiver side)
 final pendingRef = await FirebaseFirestore.instance
      .collection('users')
      .doc(sharedUserId)
      .collection('pendingTransactions')
      .add({
    'date': transaction['date'],
    'type': reversedType,
    'credit': transaction['credit'],
    'userId': sharedUserId,
    'senderId': currentUserId,
    'sharedCategoryId': sharedCategoryId,
    'receiverContactId': receiverContactId,
    'status': 'pending',
  });

  print("Adding transaction into PENDING TRANSACTIONS (receiver side)...");

  await FirebaseFirestore.instance
      .collection('users')
      .doc(sharedUserId) // Receiver’s ID
      .collection('notifications')
      .add({
    'title': 'Payment Request',
    'body': 'You received Rs.${transaction['credit']} from ${widget.contactName}.',
    'timestamp': Timestamp.now(),
    'isRead': false,
    'type': 'transaction_request',
    'transactionId': transaction['transactionId'] ?? '',
    'sharedCategoryId': sharedCategoryId,
    'receiverContactId': receiverContactId,
    'senderId': FirebaseAuth.instance.currentUser!.uid,
  });

  print(" Transaction added to shared user ($sharedUserId): $reversedType Rs.${transaction['credit']}");
}
    // Optional: Show Notification
    if (transaction['type'] == 'Receive') {
      print(" Sending notification for received transaction...");
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'Payment Received',
        'message':
            'You received Rs${transaction['credit']} from ${widget.contactName}.',
        'date': Timestamp.now(),
        'isRead': false,
      });

      await NotificationService().showNotification(
        title: 'Payment Received',
        body:
            'You received Rs${transaction['credit']} from ${widget.contactName}.',
      );
      setState(() {
      transactionStream = _getTransactionStream(); //  Refresh live stream
});
       print(" Notification sent");
    }
  print(" Transaction process completed successfully.");
  } catch (e) {
    print(" Error adding transaction: $e");
  }
} */
  /*Future<void> _deleteTransaction(String id) async {
    try {

      print("//// Delete TRANSACTION : ${widget.contactId}");
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('categories')
         .doc(widget.categoryId)
          .collection('contacts')
          .doc(widget.contactId)
          .collection('transactions')
          .doc(id)
          .delete();

      setState(() {
        transactions.removeWhere((tx) => tx['id'] == id);
        _filterTransactions();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Transaction deleted successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting transaction: $e")),
      );
    }
  }*/
  Future<void> _generateAndSavePdf(List<Map<String, dynamic>> transactions, contactName) async {
  print(" PDF called with ${transactions.length} transactions");

  if (transactions.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⚠ No transactions found to export.")),
    );
    return;
  }

  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
         pw.Text('Transactions for $contactName', style: pw.TextStyle(fontSize: 24)),

          pw.SizedBox(height: 20),
          ...transactions.map((tx) {
            final rawDate = tx['date'];
            final date = rawDate is Timestamp ? rawDate.toDate() : rawDate as DateTime;

            final type = tx['type'];
            final amount = (tx['credit'] as num).toStringAsFixed(2);
            return pw.Text("${date.day}/${date.month}/${date.year} | $type | Rs$amount");
          }),
        ],
      ),
    ),
  );
  // Request permission
  final status = await Permission.storage.request();
  if (!status.isGranted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(" Storage permission denied.")),
    );
    return;
  }
  // Save to Downloads
  final downloadsDir = Directory('/storage/emulated/0/Download');
  final filename = 'transactions_${DateTime.now().millisecondsSinceEpoch}.pdf';
  final file = File('${downloadsDir.path}/$filename');

  await file.writeAsBytes(await pdf.save());

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(" PDF saved to Downloads:\n$filename")),
  );
}
void _handlePay(BuildContext context, Map<String, dynamic> txn) async {
  // Show Bottom Sheet and wait for user's selection
  final result = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext bottomSheetContext) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Choose Payment Method",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text("Easypaisa"),
              onTap: () {
                print(" easypaisa tapped — txn: $txn");
                Navigator.of(bottomSheetContext).pop("easypaisa");
              },
            ),

            ListTile(
              leading: const Icon(Icons.mobile_friendly),
              title: const Text("JazzCash"),
              onTap: () {
                print(" JazzCash tapped — txn: $txn");
                Navigator.of(bottomSheetContext).pop("jazzcash");
              },
            ),

           /* ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text("Visa / MasterCard"),
              onTap: () {
                Navigator.of(bottomSheetContext).pop("visa");
              },
            ),*/
          ],
        ),
      );
    },
  );

  //  After bottom sheet closes
  if (result == "jazzcash") {
    print(" Launching JazzCash payment...");
    _payViaJazzCash(context, txn);
  } else if (result == "easypaisa") {
    print(" Launching Easypaisa payment...");
    _payViaEasypaisa(context, txn);
  } else if (result == "visa") {
  print(" Launching Visa/MasterCard via Stripe...");
 // _payViaStripe(context, txn);
} else {
  print(" No payment method selected or bottom sheet dismissed");
}
}
void _payViaJazzCash(BuildContext context, Map<String, dynamic> txn) async {
   print(" Inside _payViaJazzCash — txn: $txn");

  final amount = txn['credit'];
  final orderRef = "T${DateTime.now().millisecondsSinceEpoch}";

  // Get current Firebase user
final uid = FirebaseAuth.instance.currentUser?.uid;
final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
final data = userDoc.data();

final email = data?['email'];
final mobileNo = data?['mobileNo'];

  if (email == null || email.isEmpty || mobileNo == null || mobileNo.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Your email or mobile number is missing.")),
    );
    return;
  }
    final uri = Uri.parse('https://us-central1-hisabkitab-b66b5.cloudfunctions.net/api/jazzcash/generateJazzCashLink');
 // final uri = Uri.parse('https://us-central1-hisabkitab-b66b5.cloudfunctions.net/api/generateJazzCashLink');
print(" Attempting to POST to: $uri");
  print(" Request body: ${{
    "amount": amount.toString(),
    "orderRef": orderRef,
    "email": email,
    "mobileNo": mobileNo,
  }}");
  try {
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
      //  "amount": amount.toString(),
        "amount": (amount * 100).toInt().toString(), 
        "orderRef": orderRef,
        "email": email,
        "mobileNo": mobileNo,
      }),
    );

    print(" JazzCash API responded with status: ${response.statusCode}");
    print(" Response body: ${response.body}");


    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final paymentUrl = data['paymentUrl'];

       print(" Launching payment URL: $paymentUrl");

      if (await canLaunchUrl(Uri.parse(paymentUrl))) {
        await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch JazzCash payment page")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("JazzCash request failed: ${response.statusCode}")),
      );
    }
  } catch (e) {
    print(" Error while sending request: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  }
}
void _payViaEasypaisa(BuildContext context, Map<String, dynamic> txn) async {
  print(" Inside _payViaEasypaisa — txn: $txn");

  final amount = txn['credit'];
  final orderRef = "EP${DateTime.now().millisecondsSinceEpoch}";

  // Get current Firebase user
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final data = userDoc.data();

  final email = data?['email'];
  final mobileNo = data?['mobileNo'];

  if (email == null || email.isEmpty || mobileNo == null || mobileNo.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Your email or mobile number is missing.")),
    );
    return;
  }

  final uri = Uri.parse('https://us-central1-hisabkitab-b66b5.cloudfunctions.net/api/easypaisa/generateEasypaisaLink');
  print(" Attempting to POST to: $uri");
  print(" Request body: ${{
    "amount": amount.toString(),
    "orderRef": orderRef,
    "email": email,
    "mobileNo": mobileNo,
  }}");

  try {
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        "amount": amount.toString(),
        "orderRef": orderRef,
        "email": email,
        "mobileNo": mobileNo,
      }),
    );

    print(" Easypaisa API responded with status: ${response.statusCode}");
    print(" Response body: ${response.body}");

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final paymentUrl = data['paymentUrl'];

      print(" Launching Easypaisa payment URL: $paymentUrl");

      if (await canLaunchUrl(Uri.parse(paymentUrl))) {
        await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch Easypaisa payment page")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Easypaisa request failed: ${response.statusCode}")),
      );
    }
  } catch (e) {
    print(" Error while sending Easypaisa request: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  }
}
/*void _payViaStripe(BuildContext context, Map<String, dynamic> txn) async {
  print(" Inside _payViaStripe — txn: $txn");

  final amount = txn['credit'];
  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (uid == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User not logged in.")),
    );
    return;
  }

  // Fetch user data
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final data = userDoc.data();
  final email = data?['email'];

  if (email == null || email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Your email is missing.")),
    );
    return;
  }

  final uri = Uri.parse(
    'https://us-central1-hisabkitab-b66b5.cloudfunctions.net/api/stripe/createCheckoutSession',
  );

  print(" Attempting to POST to Stripe endpoint: $uri");
  print(" Request body: { amount: $amount, email: $email }");

  try {
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        "amount": amount.toString(),
        "email": email,
      }),
    );

    print(" Stripe API responded with status: ${response.statusCode}");
    print(" Response body: ${response.body}");
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final checkoutUrl = data['checkoutUrl'];

      if (await canLaunchUrl(Uri.parse(checkoutUrl))) {
        print(" Launching Stripe checkout URL: $checkoutUrl");
        await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open Stripe payment page")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Stripe request failed: ${response.statusCode}")),
      );
    }
  } catch (e) {
    print(" Error while sending request to Stripe: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Stripe error: $e")),
    );
  }
}*/
void _showCustomAmountDialog(BuildContext context) {
  final amountController = TextEditingController();

  showDialog(
    context: context,
    // builder: context {
   builder: (BuildContext dialogContext) {

      return AlertDialog(
        title: const Text("Enter Amount"),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: "Enter amount in PKR",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final enteredAmount = amountController.text.trim();
              if (enteredAmount.isEmpty || double.tryParse(enteredAmount) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid amount")),
                );
                return;
              } 

              final txn = {
                'credit': double.parse(enteredAmount),
                'type': 'Custom',
              };
             //final safeContext = context;
            // Navigator.pop(context);
              Navigator.pop(dialogContext); 
              WidgetsBinding.instance.addPostFrameCallback((_) {
                 _handlePay(context, txn); //  Use the safe wrapper we made earlier
    });
              //_showPaymentOptions(context, txn); //  <== This is where it's called
            },
            child: const Text("Continue"),
          ),
        ],
      );
    },
  );
}
Future<void> verifyJazzCashTxn(String txnRefNo) async {
  final url = Uri.parse('https://us-central1-hisabkitab-b66b5.cloudfunctions.net/api/inquiry');

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'orderRef': txnRefNo}),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final inquiryData = data['response'];

    print(" Inquiry Result: $inquiryData");

    if (inquiryData['pp_ResponseCode'] == '000') {
      //  Payment Successful
      print(" Payment confirmed");
    } else if (inquiryData['pp_ResponseCode'] == '124') {
      //  Payment Failed
      print(" Payment failed");
    } else {
      //  Pending or unknown
      print(" Payment status: ${inquiryData['pp_ResponseMessage']}");
    }
  } else {
    print(" HTTP Error: ${response.statusCode} - ${response.body}");
  }
}
  Future<void> _shareCsv() async {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to share.')),
      );
      return;
    }
    List<List<dynamic>> csvData = [
      ['Date', 'Type', 'Credit'], // Header
      ...transactions.map((txn) => [
            DateFormat('dd/MM/yyyy').format(txn['date']),
            txn['type'],
            txn['credit'].toString(),
          ])
    ];
    String csv = const ListToCsvConverter().convert(csvData);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${widget.contactName}_transactions.csv';
    final file = File(path);
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)],
        text: 'Transaction CSV for ${widget.contactName}');
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
  double calculateBalance(List<Map<String, dynamic>> txns) {
    double balance = 0.0;
    for (var tx in txns) {
      double amount = tx['credit'] ?? 0.0;
      if (tx['type'] == 'Receive') {
        balance += amount;
      } else if (tx['type'] == 'Send') {
        balance -= amount;
      }
    }
    return balance;
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
  print(" PDF button clicked");

  final displayName = widget.isSharedView && currentUserName.isNotEmpty
      ? getReversedContactName(widget.contactName, currentUserName)
      : widget.contactName;

  _generateAndSavePdf(_latestTxns, displayName);
}
          ),
       if (!widget.isSharedView) ...[   
          IconButton(
      icon: const Icon(Icons.share),
      onPressed: () async {
        try {
          final image = await _screenshotController.capture();
          if (image == null) {
            print("️ Screenshot is null.");
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
        } catch (e) {
          print("Share failed: $e");
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
      const SizedBox(width: 8),
      //  Pay Button
    /*  Expanded(
  flex: 2,
  child: ElevatedButton.icon(
    onPressed: () {
      _showCustomAmountDialog(context); 
    },
    icon: const Icon(Icons.payment, size: 16),
    label: const Text("Pay", style: TextStyle(fontSize: 14)),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.green.shade100,
      foregroundColor: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
    ),
  ),
),*/
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
        /*  Expanded(flex: 3, child: Text("Credit", style: TextStyle(fontWeight: FontWeight.bold))), */
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
          /*if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }*/
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
/*return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text("${txDate.day}/${txDate.month}/${txDate.year}")),
                    Expanded(child: Text(isReceive ? 'Receive' : 'Send')),
                    Expanded(
                      child: Text(
                        "$arrow Rs${(tx['credit'] as num).toStringAsFixed(2)}",
                        style: TextStyle(color: color, fontWeight: FontWeight.bold),
                      ),
                    )
                  ]
                )
);*/
              print("TX STATUS: ${tx['status']}");
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
      // Credit
    /*  Expanded(
        flex: 3,
        child: Text(
          "$arrow Rs.${(tx['credit'] as num).toStringAsFixed(0)}",
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),*/
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

            print("DEBUG START ----------------");
            print("currentUserId      : $currentUserId");
            print("categoryId         : ${widget.categoryId}");
            print("contactId          : ${widget.contactId}");
            print("transactionId      : $transactionId");
            print("--------------------------------");

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
                        print("Note when saving: $noteText");

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

                          print("Note saved ");
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
      /*Expanded(
        flex: 1,
        child: GestureDetector(
            onTap: () async {
              final currentUserId = FirebaseAuth.instance.currentUser!.uid;
              final fetchUserId = widget.isSharedView ? widget.sharedUserId! : currentUserId;

              print("DEBUG START ----------------");
              print("currentUserId      : $currentUserId");
              print("sharedUserId       : ${widget.sharedUserId}");
              print("fetchUserId        : $fetchUserId");
              print("categoryId         : ${widget.categoryId}");
              print("contactId          : ${widget.contactId}");
              print("originalContactId  : ${widget.originalContactId}");
              print("transactionId      : $transactionId");
              print("receiverContactId  : ${widget.receiverContactId}");
              print("sharedCategoryId   : ${widget.sharedCategoryId}");
              print("isSharedView       : ${widget.isSharedView}");
              print("receiverCategoryId : $receiverCategoryId");
              print("--------------------------------");

              String existingNote = "";

              if (transactionId != null) {
                final noteDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(fetchUserId)
                    .collection('categories')
                    .doc(widget.categoryId)
                    .collection('contacts')
                    .doc(widget.originalContactId ?? widget.contactId)
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
             // if (!context.mounted) return; //A
////////////////
              // Show Dialog
              showDialog(
                context: context,
                builder: (context) {

                  if (widget.isSharedView) {
                    return AlertDialog(
                      title: Text("Note"),
                      content: Text(
                        existingNote.isNotEmpty ? existingNote : "No note available",
                        style: TextStyle(fontSize: 16),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Close", style: TextStyle(color: Colors.black)),
                        ),
                      ],
                    );
                  }

                  String noteText = '';

                 // final TextEditingController noteController = TextEditingController(text: existingNote);


                  // Sender → editable
                  return AlertDialog(
                    title: Text("Note"),
                    content: TextField(
                    controller: _noteController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: "Write your note here...",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (txt){
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

                          print("Note when sending: $noteText");

                          if (noteText.isNotEmpty) {
                            //  Sender
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

                            //  Receiver ki side bhi agar available ho to
                            if (widget.sharedUserId != null &&
                                widget.receiverCategoryId != null &&
                                widget.receiverContactId != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(widget.sharedUserId)
                                  .collection('categories')
                                  .doc(widget.receiverCategoryId)
                                  .collection('contacts')
                                  .doc(widget.receiverContactId)
                                  .collection('transactions')
                                  .doc(transactionId)
                                  .set({
                                "note": noteText,
                                "updatedAt": FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                            }
                          }
                         // if (!context.mounted) return;

                          Navigator.pop(context);
                          setState(() {});
                        },
                        child: Text("Save", style: TextStyle(color: Colors.black)),
                      )
                    ],
                  );
                },
              );

              ////////////////
            },
            /*onTap: () async {
            final currentUserId = FirebaseAuth.instance.currentUser!.uid;

            final fetchUserId = widget.isSharedView ? widget.sharedUserId! : currentUserId;

            print(" DEBUG START ----------------");
            print("currentUserId      : $currentUserId");
            print("sharedUserId       : ${widget.sharedUserId}");
            print("fetchUserId        : $fetchUserId");
            print("categoryId         : ${widget.categoryId}");
            print("contactId          : ${widget.contactId}");
            print("originalContactId  : ${widget.originalContactId}");
            print("transactionId      : $transactionId");
            print("receiverContactId  : ${widget.receiverContactId}");
            print("sharedCategoryId   : ${widget.sharedCategoryId}");
            print("isSharedView       : ${widget.isSharedView}");
            print("receiverCategoryId : $receiverCategoryId");
            print("--------------------------------");

            // Fetch existing note
            final noteDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(fetchUserId)
                .collection('categories')
                .doc(widget.categoryId)
                .collection('contacts')
                .doc(widget.originalContactId ?? widget.contactId)
                .collection('transactions')
                .doc(transactionId)
                .get();

            if (noteDoc.exists && noteDoc.data()!.containsKey("note")) {
              print(" Existing Note Found: '${noteDoc['note']}'");
              _noteController.text = noteDoc['note'];

              print("Controller Text: ${_noteController.text}");

            } else {
              print(" No note found for this transaction in Firestore");
            }

            String existingNote = "";
            if (noteDoc.exists && noteDoc.data()!.containsKey("note")) {
              existingNote = noteDoc['note'];
              _noteController.text = existingNote;
            }
            // Show Dialog
            showDialog(
              context: context,
              builder: (context) {
                // Agar sharedView (receiver) hai → sirf view
                if (widget.isSharedView) {
                  return AlertDialog(
                    title: Text("Note"),
                    content: Text(
                      existingNote.isNotEmpty ? existingNote : "No note available",
                      style: TextStyle(fontSize: 16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Close", style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  );
                }
                // Sender → editable
              //  _noteController.text = "";
                return AlertDialog(
                  title: Text("Note"),
                  content: TextField(
                    controller: _noteController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: "Write your note here...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel", style: TextStyle(color: Colors.black)),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        String noteText = _noteController.text.trim();

                        print("Note when sending: $noteText");

                        if (noteText.isNotEmpty) {
                          final currentUserId = FirebaseAuth.instance.currentUser!.uid;

                          print(" Saving Note...");
                          print("transactionId        : $transactionId");
                          print("senderUserId         : $currentUserId");
                          print("senderCategoryId     : ${widget.categoryId}");
                          print("senderContactId      : ${widget.contactId}");
                          print("receiverUserId       : ${widget.sharedUserId}");
                          print("receiverCategoryId   : $receiverCategoryId");
                          print("receiverContactId    : ${widget.receiverContactId}");
                          print("Note Content         : $noteText");

                          // Save note in SENDER side
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

                          print(" Note saved in sender side");

                          if (widget.sharedUserId != null &&
                              widget.receiverCategoryId != null &&
                              widget.receiverContactId != null) {
                            print("Saving note to receiver side...");
                            print("receiverUserId      : ${widget.sharedUserId}");
                            print("receiverCategoryId  : ${widget.receiverCategoryId}");
                            print("receiverContactId   : ${widget.receiverContactId}");
                            print("transactionId       : $transactionId");
                            print("noteText            : $noteText");

                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.sharedUserId)               //  receiverUserId
                                .collection('categories')
                                .doc(widget.receiverCategoryId)         //  receiverCategoryId
                                .collection('contacts')
                                .doc(widget.receiverContactId)          //  receiverContactId
                                .collection('transactions')
                                .doc(transactionId)
                                .set({
                              "note": noteText,
                              "updatedAt": FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            print(" Note also saved to Receiver's database.");
                          } else {
                            print(" Receiver info not available, note not saved on receiver side.");
                          }
                        }
                        Navigator.pop(context);
                      },
                      child: Text("Save", style: TextStyle(color: Colors.black)),
                    )
                  ],
                );
              },
            );
          }, */
          child: Icon(Icons.book_sharp, color: Colors.green),
        ),
      ) */
      /* Expanded(
        flex: 1,
        child: GestureDetector(
          onTap: () async {
            final currentUserId = FirebaseAuth.instance.currentUser!.uid;
            final TextEditingController _noteController = TextEditingController();

//  Agar sharedView hai to sender ka userId use karna hai
            final fetchUserId = widget.isSharedView ? widget.sharedUserId! : currentUserId;

            print(" DEBUG INFO");
            print("   currentUserId   : $currentUserId");
            print("   sharedUserId    : ${widget.sharedUserId}");
            print("   fetchUserId     : $fetchUserId");
            print("   categoryId      : ${widget.categoryId}");
            print("   contactId       : ${widget.contactId}");
            print("   transactionId   : $transactionId");

// Fetch existing note
            final noteDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(fetchUserId)
                .collection('categories')
                .doc(widget.categoryId)
                .collection('contacts')
               // .doc(widget.contactId)
                .doc(widget.originalContactId ?? widget.contactId)
                .collection('transactions')
                .doc(transactionId)
                .get();

            if (noteDoc.exists && noteDoc.data()!.containsKey("note")) {
              _noteController.text = noteDoc['note'];
            } else {
              print("No note found for this transaction in Firestore");
            }

            String existingNote = "";
            if (noteDoc.exists && noteDoc.data()!.containsKey("note")) {
              existingNote = noteDoc['note'];
              _noteController.text = existingNote;
            }

            // Show Dialog
            showDialog(
              context: context,
              builder: (context) {
                // Agar sharedView (receiver) hai → sirf view
                if (widget.isSharedView) {
                  return AlertDialog(
                    title: Text("Note"),
                    content: Text(
                      existingNote.isNotEmpty ? existingNote : "No note available",
                      style: TextStyle(fontSize: 16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Close", style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  );
                }

                // Sender → editable
                return AlertDialog(
                  title: Text("Note"),
                  content: TextField(
                    controller: _noteController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: "Write your note here...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel", style: TextStyle(color: Colors.black)),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        String noteText = _noteController.text.trim();
                        if (noteText.isNotEmpty) {
                          final currentUserId = FirebaseAuth.instance.currentUser!.uid;

                          print(" Saving Note...");
                          print("   transactionId     : $transactionId");
                          print("   senderUserId      : $currentUserId");
                          print("   senderCategoryId  : ${widget.categoryId}");
                          print("   senderContactId   : ${widget.contactId}");
                          print("   receiverUserId    : ${widget.sharedUserId}");
                          print("   receiverCategoryId: ${widget.sharedCategoryId}");
                          print("   receiverContactId : ${widget.receiverContactId}");

                          //  Save note in SENDER side
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

                          //  Also save note in RECEIVER side (if shared info is available)
                          if (widget.sharedUserId != null &&
                              widget.sharedCategoryId != null &&
                              widget.receiverContactId != null) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.sharedUserId) // receiver user
                                .collection('categories')
                                .doc(widget.sharedCategoryId) // receiver category
                                .collection('contacts')
                                .doc(widget.receiverContactId) // receiver contactId
                                .collection('transactions')
                                .doc(transactionId)
                                .set({
                              "note": noteText,
                              "updatedAt": FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            print("✅ Note also saved to Receiver's database.");
                          } else {
                            print("⚠️ Receiver info not available, note not saved on receiver side.");
                          }
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
      ) */
     /* Expanded(
  flex: 2,
  child: isReceive
      ? const SizedBox() // no button on receive
      : ElevatedButton.icon(
  icon: const Icon(Icons.payment, size: 16),
  label: const Text("Pay", style: TextStyle(fontSize: 12)),
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    backgroundColor: Colors.green.shade100,
    foregroundColor: Colors.black,
    minimumSize: const Size(10, 30),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    elevation: 0,
  ),
  onPressed: () {
    _showPaymentOptions(context, tx);
  },
),
),*/
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

