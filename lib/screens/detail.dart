import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisabshare/screens/add_contact.dart';
import 'package:hisabshare/screens/contact_detail.dart';
import 'package:hisabshare/widgets/shareduser_infopage.dart';
import 'package:hisabshare/screens/list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hisabshare/repositories/contact_repository.dart';
import 'dart:async';

class DetailPage extends StatefulWidget {
  final String categoryId; 
  final String categoryName;
 
  const DetailPage({required this.categoryId,required this.categoryName,
  Key? key}) : super(key: key);
 
    @override
    State<DetailPage> createState() => _DetailPageState();
  }

  Map<String, String> contact =  Map<String, String>();
  
  class _DetailPageState extends State<DetailPage> {
    late String userId;
    TextEditingController searchController = TextEditingController();
    
    List<Map<String, dynamic>> persons = [];
    List<Map<String, dynamic>> filteredPersons = [];
    double totalSend = 0.0;
    double totalReceive = 0.0;
    List<StreamSubscription> _contactSubscriptions = [];
    double _fabOffsetX = 0.0;

  void dispose() {
      for (var sub in _contactSubscriptions) {
        sub.cancel();
      }
      super.dispose();
    }

  @override
  void initState() {
    super.initState();
    searchController.addListener(_filterPersons);
    _loadContacts();
    _handleInitialDynamicLink();
    _listenToDynamicLinks();
    _listenToContactTransactions();
  userId = FirebaseAuth.instance.currentUser?.uid ?? '';
WidgetsBinding.instance.addPostFrameCallback((_) {
    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      _fabOffsetX = screenWidth * 0.8; // You can tweak 0.8 to 0.75 or 0.7
    });
});

  }
 void _handleInitialDynamicLink() async {
  final PendingDynamicLinkData? initialLink =
      await FirebaseDynamicLinks.instance.getInitialLink();
 
  if (initialLink?.link != null) {
    _navigateFromSharedLink(initialLink!.link);
  }
}
 
void _listenToDynamicLinks() {
  FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) {
    _navigateFromSharedLink(dynamicLinkData.link);
  }).onError((error) {
  });
}
 
void _navigateFromSharedLink(Uri uri) {
  if (uri.pathSegments.length >= 3 && uri.pathSegments[0] == 'contact') {
    final contactId = uri.pathSegments[1];
    final contactName = Uri.decodeComponent(uri.pathSegments[2]);
    final senderUserId = uri.queryParameters['senderId'] ?? '';
 
    // Navigate using GoRouter instead of Navigator
    GoRouter.of(context).go(
      '/contact/$contactId/${Uri.encodeComponent(contactName)}?senderId=$senderUserId',
    );
  }
}
 Widget _buildSummaryCard(String title, double amount) {
  final isReceive = title == 'Receive';

  return Container(
    height: 80,
    width: MediaQuery.of(context).size.width * 0.42,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: isReceive ? Colors.green.shade100 : Colors.red.shade100,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Rs. ${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 13),
        ),
      ],
    ),
  );
}
void _listenToContactTransactions() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  // Cancel previous listeners
  for (var sub in _contactSubscriptions) {
    await sub.cancel();
  }
  _contactSubscriptions.clear();

  final contactsSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('categories')
      .doc(widget.categoryId)
      .collection('contacts')
      .get();

  for (var contactDoc in contactsSnapshot.docs) {
    final contactId = contactDoc.id;

    final sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(widget.categoryId)
        .collection('contacts')
        .doc(contactId)
        .collection('transactions')
        .snapshots()
        .listen((snapshot) {
      double send = 0.0;
      double receive = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['credit'] ?? 0).toDouble();
        final type = data['type'];

        if (type == 'Send') {
          send += amount;
        } else if (type == 'Receive') {
          receive += amount;
        }
      }

      //Instead of replacing, re-calculate everything
      _recalculateAllTransactions();
    });

    _contactSubscriptions.add(sub);
  }
}
void _recalculateAllTransactions() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  double newSend = 0.0;
  double newReceive = 0.0;

  final contactsSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('categories')
      .doc(widget.categoryId)
      .collection('contacts')
      .get();

  for (var contactDoc in contactsSnapshot.docs) {
    final contactId = contactDoc.id;

    final txnsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(widget.categoryId)
        .collection('contacts')
        .doc(contactId)
        .collection('transactions')
        .get();

    for (var doc in txnsSnapshot.docs) {
      final data = doc.data();
      final amount = (data['credit'] ?? 0).toDouble();
      final type = data['type'];

      if (type == 'Send') {
        newSend += amount;
      } else if (type == 'Receive') {
        newReceive += amount;
      }
    }
  }

  setState(() {
    totalSend = newSend;
    totalReceive = newReceive;
  });
}

  void _filterPersons() {
    setState(() {
      filteredPersons = persons
          .where((person) => person['name']
              .toLowerCase()
              .contains(searchController.text.toLowerCase()))
          .toList();
    });
  }
 
  Color _getRandomCardColor() {
    final random = Random();
    return Color.fromARGB(
      255,
      150 + random.nextInt(106),
      100 + random.nextInt(156),
      100 + random.nextInt(156),
    );
  }

//void _loadContacts() async {
  Future<void> _loadContacts() async {
  final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserUid == null) return;

  final List<Map<String, dynamic>> loaded = [];

  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUserUid)
      .collection('categories')
      .doc(widget.categoryId)
      .collection('contacts')
      .get();

  final docs = snapshot.docs;

  //  Fast balance fetch in parallel
  final balances = await Future.wait(docs.map((doc) async {
    return await _fetchBalance(currentUserUid, doc.id);
  }));

  for (int i = 0; i < docs.length; i++) {
    final doc = docs[i];
    final data = doc.data();
    final contactId = doc.id;
    final name = data['name'] as String?;
    if (name == null) continue;

    final balance = balances[i];

    //  Reversed Shared Contact (Receiver Side)
    if (data['isSharedView'] == true &&
        data['sharedUserId'] != null &&
        data['sharedCategoryId'] != null) {
      loaded.add({
        'id': contactId,
        'name': name,
        'amount': balance,
        'color': _getRandomCardColor(),
        'mobileNo': data['mobileNo'] ?? '',
        'email': data['email'] ?? '',
        'address': data['address'] ?? '',
        'isSharedView': true,
        'sharedUserId': data['sharedUserId'],
        'sharedCategoryId': data['sharedCategoryId'],
        'originalContactId': data['originalContactId'],
        'sharedBy': data['sharedBy'] ?? {},
      });
    } else {
      //  Normal Contact (Sender Side)
      Map<String, dynamic>? sharedUser;

      //  Safer check (default true if field missing)
      if (data['hasSharedWith'] ?? true) {
        final sharedSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserUid)
            .collection('categories')
            .doc(widget.categoryId)
            .collection('contacts')
            .doc(contactId)
            .collection('sharedWith')
            .get();

        if (sharedSnapshot.docs.isNotEmpty) {
          final firstShared = sharedSnapshot.docs.first;
          final sharedData = firstShared.data();
          sharedUser = {
            'uid': sharedData['uid'],
            'username': sharedData['name'] ?? '',
            'email': sharedData['email'] ?? '',
            'imageUrl': sharedData['imageUrl'] ?? '',
            'mobileNo': sharedData['mobileNo'] ?? '',
          };
        }else {
}
      }
     
      loaded.add({
        'id': contactId,
        'name': name,
        'amount': balance,
        'color': _getRandomCardColor(),
        'mobileNo': data['mobileNo'] ?? '',
        'email': data['email'] ?? '',
        'address': data['address'] ?? '',
        'isSharedView': false,
        'sharedUserId': null,
        if (sharedUser != null) 'sharedUser': sharedUser, //  Avatar for sender side
      });
    }
  }
  // Update state
  setState(() {
    persons = loaded;
    filteredPersons = List.from(loaded);
  });
}

  void _addContact(Map<String, dynamic> newContact) async {
    final generatedId = await ContactRepository.addContact(
      categoryId: widget.categoryId,
      categoryName: widget.categoryName,
      newContact: newContact,
    );

    if (generatedId != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final balance = await _fetchBalance(uid, generatedId);

      final newPerson = {
        'id': generatedId,
        'name': newContact['name'],
        'amount': balance,
        'color': _getRandomCardColor(),
        'mobileNo': newContact['mobileNo'] ?? '',
        'email': newContact['email'] ?? '',
        'address': newContact['address'] ?? '',
      };
 
      setState(() {
        persons.add(newPerson);
        filteredPersons = List.from(persons);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid contact data.')),
      );
    }
  }
  void _deleteContact(String contactId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Contact"),
        content: const Text("Are you sure you want to delete this contact?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await ContactRepository.deleteContact(
                categoryId: widget.categoryId,
                contactId: contactId,
              );
              setState(() {
                persons.removeWhere((p) => p['id'] == contactId);
                filteredPersons.removeWhere((p) => p['id'] == contactId);
              });
 
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Contact deleted")),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
 
  Future<double> _fetchBalance(String uid, String contactId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(widget.categoryId)
        .collection('contacts')
        .doc(contactId)
        .collection('transactions')
        .get();
 
    double balance = 0.0;
    for (var doc in snapshot.docs) {
      final data = doc.data(); 
      final credit = (data['credit'] ?? 0).toDouble();
      final type = data['type'];
 
      if (type == 'Receive') {
        balance += credit;
      } else if (type == 'Send') {
        balance -= credit;
      }
    }
    return balance;
  }
   @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
  return Scaffold(

      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Color(0xFF89BE4F),
        foregroundColor: Colors.black,
        title: Text(widget.categoryName),
        leading: const BackButton(),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ListPage(
                    categoryName: widget.categoryName,
                    contacts: persons,
                  ),
                ),
              );
            },
            child: const Text("Contact List", style: TextStyle(color: Colors.black)),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1),
        ),
      ),
      body: Builder( //  wrap entire body in Builder to get correct scaffoldContext
       builder: (scaffoldContext) => Padding(
      //body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    _buildSummaryCard('Receive', totalReceive),
    _buildSummaryCard('Send', totalSend),
  ],
),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(30),
              ),
              
               child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: "Search",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const Icon(Icons.search),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Contacts",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
          child: RefreshIndicator(
    onRefresh: _loadContacts,    
  child: ListView.builder(
    itemCount: filteredPersons.length,
    itemBuilder: (context, index) {
      final person = filteredPersons[index];
      final isPositive = (person['amount'] ?? 0) >= 0;
      final sharedUser = person['sharedUser']; 
      return GestureDetector(
        onLongPress: () => _deleteContact(person['id']),
        child: Stack(
          children: [
            if (filteredPersons.isNotEmpty)
              /*Positioned(
                left: 25,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  height: 80,
                  color: Colors.black,
                ),
              ),*/
            Padding(
             //  padding: const EdgeInsets.only(left: 40, bottom: 16),
             padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Remove dot from cards
                 /* Container(
                    margin: const EdgeInsets.only(right: 12, top: 8),
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                  ),*/
                  
                  Expanded(
                    child: GestureDetector(
    onTap: () async {
      final isSharedView = person['isSharedView'] == true;
      final sharedUserId = person['sharedUserId'] ?? '';
      final sharedCategoryId = person['sharedCategoryId'];
      final correctCategoryId = isSharedView ? sharedCategoryId : widget.categoryId;

      final contactId = person['id'];

      String? receiverCategoryId;
      if (isSharedView && sharedUserId.isNotEmpty && sharedCategoryId != null) {
        final snap = await FirebaseFirestore.instance
            .collection("users")
            .doc(sharedUserId) // sender user
            .collection("categories")
            .doc(sharedCategoryId) // sender category
            .collection("contacts")
            .doc(person['originalContactId']) // original sender ka contact
            .collection("sharedWith")
            .doc(FirebaseAuth.instance.currentUser!.uid) // current receiver
            .get();

        if (snap.exists) {
          receiverCategoryId = snap.data()?['categoryId'];
        } else {
        }
      }

      if (contactId != null && person['name'] != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContactDetailPage(
              categoryId: correctCategoryId,
              contactId: contactId,
              contactName: person['name'],
              isSharedView: isSharedView,
              sharedUserId: sharedUserId,
              sharedCategoryId: sharedCategoryId,
              receiverContactId: contactId,
              originalContactId: person['originalContactId'],
              receiverCategoryId: receiverCategoryId,
             // currentUserName: person['currentUserName'],
            ),
          ),
        );
 
                          if (uid != null) {
                            final updatedBalance =
                                await _fetchBalance(uid, person['id']);
                            setState(() {
                              person['amount'] = updatedBalance;
                            });
                          }
                        } else {
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: person['color'] ?? Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Name
                            Text(
                              person['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    //
                                  /*  const Text(
                                      'Balance',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ), */
                                    //
                                    Text(
                                      person['amount']
                                          .toStringAsFixed(2),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isPositive
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
 const SizedBox(width: 10),
if (sharedUser != null)
  GestureDetector(
    onTap: () async {
      if (sharedUser['contactId'] == null) {
      } else {
      }

/*showDialog(
      context: context,
      builder: (context) => SharedUserInfoBottomSheet(
        contactId: person['id'],
        categoryId: widget.categoryId,
        sharedUser: sharedUser,
       // scaffoldContext: context,
        
      ),);*/
      final result = await showDialog(
  context: context,
  builder: (context) => SharedUserInfoBottomSheet(
    contactId: person['id'],
    categoryId: widget.categoryId,
    sharedUser: sharedUser,
  ),
);
if (result == "removed") {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text(" Access removed successfully.")),
  );
} else if (result == "failed") {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text(" Failed to remove access.")),
  );
}
    },
  child: CircleAvatar(
  radius: 16,
  backgroundColor: Colors.grey.shade600,
  backgroundImage: (sharedUser['imageUrl'] != null &&
                    sharedUser['imageUrl'].toString().isNotEmpty)
      ? NetworkImage(sharedUser['imageUrl'] as String)
      : null,
  child: (sharedUser['imageUrl'] == null ||
          sharedUser['imageUrl'].toString().isEmpty)
      ? const Icon(Icons.person, size: 16, color: Colors.white)
      : null,
),
  ),
  if (person['isSharedView'] == true && person['sharedBy'] != null)
      GestureDetector(
        onTap: () {
          final sharedBy = person['sharedBy'];
          showDialog(
  context: context,
  builder: (BuildContext dialogContext) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Shared By'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('👤 Name: ${sharedBy['name'] ?? 'N/A'}'),
          Text('📧 Email: ${sharedBy['email'] ?? 'N/A'}'),
          Text('📞 Phone: ${sharedBy['mobileNo'] ?? 'N/A'}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext), //  Use dialogContext
          child: const Text('Close'),
        ),
      ],
    );
  },
);
        },
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey.shade600,
          backgroundImage: (person['sharedBy']['imageUrl'] != null &&
                  person['sharedBy']['imageUrl'].toString().isNotEmpty)
              ? NetworkImage(person['sharedBy']['imageUrl'] as String)
              : null,
          child: (person['sharedBy']['imageUrl'] == null ||
                  person['sharedBy']['imageUrl'].toString().isEmpty)
              ? const Icon(Icons.person, size: 16, color: Colors.white)
              : null,
        ),
      ),

                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  ),
          ),
)

          ],
        ),
      ),
      ),
     /*floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightGreen,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddContactPage(categoryId: widget.categoryId, categoryName: widget.categoryName,),
            ),
          );
          if (result != null && result is Map<String, dynamic> && result['name'] != null) {
          //  _addContact(result);
            _loadContacts();
          } else {
            debugPrint("Invalid contact data: $result");
          }
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),*/

floatingActionButton: Align(
  alignment: Alignment.bottomLeft,
  child: GestureDetector(
    onHorizontalDragUpdate: (details) {
      setState(() {
        _fabOffsetX += details.delta.dx;

        // Clamp it to screen width
        final maxOffset = MediaQuery.of(context).size.width - 72; // FAB width
        _fabOffsetX = _fabOffsetX.clamp(0.0, maxOffset);
      });
    },

    child: Container(
      margin: EdgeInsets.only(left: _fabOffsetX, bottom: 50),
      child: FloatingActionButton(
        backgroundColor: Color(0xFF89BE4F),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddContactPage(
                categoryId: widget.categoryId,
                categoryName: widget.categoryName,
              ),
            ),
          );
          if (result != null && result['name'] != null) {
            _loadContacts();
          }
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    ),
  ),
),

   );
  }
}