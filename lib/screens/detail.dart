import 'dart:math';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisabshare/screens/add_contact.dart';
import 'package:hisabshare/screens/contact_detail.dart';
import 'package:hisabshare/widgets/shareduser_infopage.dart';
import 'package:hisabshare/screens/list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hisabshare/repositories/contact_repository.dart';

class DetailPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const DetailPage({required this.categoryId, required this.categoryName,
  Key? key}) : super(key: key);

    @override
    State<DetailPage> createState() => _DetailPageState();
  }

  class _DetailPageState extends State<DetailPage> {
    late String userId;
    TextEditingController searchController = TextEditingController();

    List<Map<String, dynamic>> persons = [];
    List<Map<String, dynamic>> filteredPersons = [];
    double totalSend = 0.0;
    double totalReceive = 0.0;
    double _fabOffsetX = 0.0;

  @override
  void initState() {
    super.initState();
    searchController.addListener(_filterPersons);
    _loadContacts();
    _handleInitialDynamicLink();
    _listenToDynamicLinks();
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

  /// Loads contacts (with server-computed `balance`/`total_receive`/`total_send`
  /// per contact - see ContactController::index) and derives the category-wide
  /// Send/Receive summary cards by summing across the list, replacing the old
  /// per-contact realtime-listener recalculation.
  Future<void> _loadContacts() async {
  final List<Map<String, dynamic>> loaded = [];

  final contacts = await ContactRepository.listContacts(widget.categoryId);

  for (final data in contacts) {
    final contactId = data['id'] as String;
    final name = data['name'] as String?;
    if (name == null) continue;

    final isSharedView = data['is_shared_view'] == true;

    //  Avatar for sender side: who this (non-shared) contact has been shared with.
    Map<String, dynamic>? sharedUser;
    if (!isSharedView) {
      final shares = await ContactRepository.shares(contactId);
      if (shares.isNotEmpty) {
        final sharedWithUser = shares.first['shared_with_user'] as Map<String, dynamic>?;
        if (sharedWithUser != null) {
          sharedUser = {
            'uid': sharedWithUser['id'],
            'username': sharedWithUser['username'] ?? '',
            'email': sharedWithUser['email'] ?? '',
            'imageUrl': sharedWithUser['image_url'] ?? '',
            'mobileNo': sharedWithUser['mobile_no'] ?? '',
          };
        }
      }
    }

    loaded.add({
      'id': contactId,
      'name': name,
      'amount': (data['balance'] as num?)?.toDouble() ?? 0.0,
      'totalReceive': (data['total_receive'] as num?)?.toDouble() ?? 0.0,
      'totalSend': (data['total_send'] as num?)?.toDouble() ?? 0.0,
      'color': _getRandomCardColor(),
      'mobileNo': data['mobile_no'] ?? '',
      'email': data['email'] ?? '',
      'address': data['address'] ?? '',
      'isSharedView': isSharedView,
      if (sharedUser != null) 'sharedUser': sharedUser,
    });
  }

  setState(() {
    persons = loaded;
    filteredPersons = List.from(loaded);
    totalReceive = loaded.fold(0.0, (sum, p) => sum + (p['totalReceive'] as double));
    totalSend = loaded.fold(0.0, (sum, p) => sum + (p['totalSend'] as double));
  });
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
              await ContactRepository.deleteContact(contactId);

              final removed = persons.firstWhere(
                (p) => p['id'] == contactId,
                orElse: () => <String, dynamic>{},
              );

              setState(() {
                persons.removeWhere((p) => p['id'] == contactId);
                filteredPersons.removeWhere((p) => p['id'] == contactId);
                totalReceive -= (removed['totalReceive'] as double?) ?? 0.0;
                totalSend -= (removed['totalSend'] as double?) ?? 0.0;
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

   @override
  Widget build(BuildContext context) {
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
            Padding(
             padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GestureDetector(
    onTap: () async {
      final isSharedView = person['isSharedView'] == true;
      final contactId = person['id'];

      if (contactId != null && person['name'] != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContactDetailPage(
              categoryId: widget.categoryId,
              contactId: contactId,
              contactName: person['name'],
              isSharedView: isSharedView,
            ),
          ),
        );

        // Balances are server-computed now, so a full reload after returning
        // keeps this contact's (and the summary cards') totals in sync.
        _loadContacts();
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
      final result = await showDialog(
  context: context,
  builder: (context) => SharedUserInfoBottomSheet(
    contactId: person['id'],
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
