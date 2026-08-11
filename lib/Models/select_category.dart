import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hisabshare/Models/add_category.dart';
import 'package:hisabshare/Models/add_category_bottomsheet.dart';

class ChooseCategoryPage extends StatefulWidget {
  final String contactId;
  final String contactName;
  final String? sharedUserId;
  final String senderName;
  final String senderEmail;
  final String senderMobileNo;
  final String senderImageUrl;
  final String? receiverContactId;

  const ChooseCategoryPage({
    required this.contactId,
    required this.contactName,
    required this.sharedUserId,
    required this.senderName,
    required this.senderEmail,
  required this.senderMobileNo,
  required this.senderImageUrl,
  required this.receiverContactId,

    Key? key,
  }) : super(key: key);

  @override
  State<ChooseCategoryPage> createState() => _ChooseCategoryPageState();
}
class _ChooseCategoryPageState extends State<ChooseCategoryPage> {
  String? selectedCategoryId;
  List<Map<String, dynamic>> categories = [];
  bool isLoading = true;

  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

 Future<void> _loadCategories() async {
  try {
    if (currentUserId == null || currentUserId!.isEmpty) {
      print('currentUserId is null or empty');
      return;
    }

    // Try cache first
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('categories')
          .get(const GetOptions(source: Source.cache));
    } catch (_) {
      // Fallback to server if cache fails
      snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('categories')
          .get();
    }

    final loaded = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'title': data['title'] ?? 'Untitled',
      };
    }).toList();

    setState(() {
      categories = loaded;
      isLoading = false;
    });
  } catch (e, stack) {
    print('Error loading categories: $e');
    print(stack);
  }
}

  void _openAddCategorySheet() async {
    final newCategory = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddCategorySheet(),
    );
  /*
  if (result == 'success') {
  // Refresh categories list or re-open dropdown
  _loadCategoriesAgain();
  _openCategoryDropdown(); // optional bad mai add karun gi 
}
  */
    if (newCategory != null) {
      setState(() {
        categories.add(newCategory);
        selectedCategoryId = newCategory['id'];
      });
    }
  }
  void _saveSharedContact() async {
  if (selectedCategoryId == null) return;

  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId == null) return;

  try {
    //  Step 1: Find matchedCatId (slow loop, should be indexed in future)
    final senderCategoriesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.sharedUserId)
        .collection('categories')
        .get();

    String? matchedCatId;

    // You should replace this with an indexed approach later!
    for (var cat in senderCategoriesSnapshot.docs) {
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
        const SnackBar(content: Text(" Contact not found in sender's data.")),
      );
      return;
    }

    // Step 2: Parallel reads
    final contactRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.sharedUserId)
        .collection('categories')
        .doc(matchedCatId)
        .collection('contacts')
        .doc(widget.contactId);

    final senderDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.sharedUserId);

    final txRef = contactRef.collection('transactions').orderBy('date');

    final contactSnapshotFuture = contactRef.get();
    final senderDocFuture = senderDocRef.get();
    final txSnapshotFuture = txRef.get();
    final receiverSnapshotFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();

    final results = await Future.wait([
      contactSnapshotFuture,
      senderDocFuture,
      txSnapshotFuture,
      receiverSnapshotFuture,
    ]);

    final contactSnapshot = results[0] as DocumentSnapshot;
    final senderDoc = results[1] as DocumentSnapshot;
    final txSnapshot = results[2] as QuerySnapshot;
    final receiverSnapshot = results[3] as DocumentSnapshot;

    final contactData = contactSnapshot.data() as Map<String, dynamic>?;
    final senderData = senderDoc.data() as Map<String, dynamic>? ?? {};
    final receiverData = receiverSnapshot.data() as Map<String, dynamic>? ?? {};

    if (contactData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠ Failed to fetch contact data.")),
      );
      return;
    }

    //  Prepare new contact for receiver
    final newContactRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('categories')
        .doc(selectedCategoryId)
        .collection('contacts')
        .doc(widget.receiverContactId);

    final bool isOriginalShared = contactData['shared'] ?? false;

    final newContactData = {
      'name': widget.senderName,
      'mobileNo': widget.senderMobileNo,
      'email': widget.senderEmail,
      'category': selectedCategoryId,
      'createdAt': FieldValue.serverTimestamp(),
      'isSharedView': true,
      'sharedUserId': widget.sharedUserId,
      'sharedCategoryId': matchedCatId,
      'originalContactId': widget.contactId,
      'allowReceiverToAddTransactions': false,
      'sharedBy': {
        'name': widget.senderName,
        'email': widget.senderEmail,
        'mobileNo': widget.senderMobileNo,
        'imageUrl': widget.senderImageUrl ?? '',
      },
    };

    if (!isOriginalShared) {
      newContactData['address'] = contactData['address'] ?? '';
    }

    await newContactRef.set(newContactData);

    // Step 3: Reverse transactions
    final txDocs = txSnapshot.docs;

  final reversedTxs = txDocs.map((tx) {
  final Map<String, dynamic> txData = tx.data() as Map<String, dynamic>;

  return {
    'date': txData['date'],
    'type': txData['type'] == 'Send' ? 'Receive' : 'Send',
    'credit': txData['credit'],
    'note': txData['note'] ?? '',
    'createdAt': FieldValue.serverTimestamp(),
  };
}).toList();

    /* for (var tx in reversedTxs) {
      await newContactRef.collection('pendingTransactions').add(tx);
    } */
    // OLD transactions -> Directly in "transactions" (reverse type)
    for (var tx in reversedTxs) {
      await newContactRef.collection('transactions').add(tx);
    }

    //  Step 4: Save receiver info in sender's sharedWith
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.sharedUserId)
        .collection('categories')
        .doc(matchedCatId)
        .collection('contacts')
        .doc(widget.contactId)
        .collection('sharedWith')
        .doc(currentUserId)
        .set({
      'uid': currentUserId,
      'name': receiverData['username'] ?? '',
      'email': receiverData['email'] ?? '',
      'mobileNo': receiverData['mobileNo'] ?? '',
      'categoryId': selectedCategoryId,
      'receiverContactId': widget.receiverContactId,
      'sharedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    //  Done
    Navigator.pop(context, {
      'receiverContactId': widget.receiverContactId,
      'sharedCategoryId': selectedCategoryId,
      'ledgerSaved': true,
    });
  } catch (e) {
    print(" Error saving shared contact: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Something went wrong: $e")),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
               // Text("Choose a category to save contact from ${widget.senderName}"),
                Text(
  "Choose a category to save contact from ${widget.senderName}",
  style: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    //color: Colors.grey[800],
  ),
  textAlign: TextAlign.center,
),

                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategoryId,
                  items: [
                    ...categories.map((cat) => DropdownMenuItem(
                          value: cat['id'],
                          child: Text(cat['title']),
                        )),
                    const DropdownMenuItem(
                      value: 'add_new',
                      child: Text('+ Add New Category'),
                    )
                  ],
                  onChanged: (value) {
                    if (value == 'add_new') {
                      _openAddCategorySheet();
                    } else {
                      setState(() {
                        selectedCategoryId = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: "Category",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveSharedContact,
                  child: const Text("Save"),
                )
              ],
            ),
          );
  }
}
