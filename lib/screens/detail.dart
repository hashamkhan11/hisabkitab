import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:hisabshare/screens/add_contact.dart';
import 'package:hisabshare/screens/contact_detail.dart';
import 'package:hisabshare/widgets/shareduser_infopage.dart';
import 'package:hisabshare/screens/list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hisabshare/providers/contacts_provider.dart';
import 'package:hisabshare/theme/app_theme.dart';
import 'package:hisabshare/widgets/header_icon_button.dart';

class DetailPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const DetailPage({required this.categoryId, required this.categoryName, super.key});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late String userId;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    searchController.addListener(_filterPersons);
    userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadContacts();
  }

  void _filterPersons() {
    // Contacts themselves live in ContactsProvider now; this just triggers a
    // rebuild so build() re-derives filteredPersons from the latest search text.
    setState(() {});
  }

  Future<void> _loadContacts() => context.read<ContactsProvider>().loadContacts(widget.categoryId);

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
              await context.read<ContactsProvider>().deleteContact(widget.categoryId, contactId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Contact deleted")),
                );
              }
            },
            child: Text("Delete", style: TextStyle(color: context.appColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final persons = context.watch<ContactsProvider>().contactsFor(widget.categoryId);
    final searchText = searchController.text.toLowerCase();
    final filteredPersons = searchText.isEmpty
        ? persons
        : persons.where((person) => (person['name'] as String).toLowerCase().contains(searchText)).toList();
    final totalReceive = persons.fold(0.0, (sum, p) => sum + (p['totalReceive'] as double));
    final totalSend = persons.fold(0.0, (sum, p) => sum + (p['totalSend'] as double));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        centerTitle: false,
        actions: [
          HeaderIconButton(
            tooltip: 'Contact list / export',
            icon: Icons.list_alt_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ListPage(
                    categoryName: widget.categoryName,
                    categoryId: widget.categoryId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _SummaryChip(label: 'Apko Milenge', amount: totalReceive, positive: true)),
                const SizedBox(width: 12),
                Expanded(child: _SummaryChip(label: 'Apko Dene Hain', amount: totalSend, positive: false)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Search contacts',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filteredPersons.isEmpty
                  ? _EmptyState(hasQuery: searchText.isNotEmpty)
                  : RefreshIndicator(
                      onRefresh: _loadContacts,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 96),
                        itemCount: filteredPersons.length,
                        itemBuilder: (context, index) {
                          final person = filteredPersons[index];
                          return _ContactRow(
                            person: person,
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
                                // Balances are server-computed now, so a full
                                // reload after returning keeps totals in sync.
                                _loadContacts();
                              }
                            },
                            onLongPress: () => _deleteContact(person['id']),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
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
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final bool positive;

  const _SummaryChip({required this.label, required this.amount, required this.positive});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final color = positive ? c.accentStrong : c.danger;
    final bg = positive ? c.accentSoft : c.dangerSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color.withValues(alpha: .85), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Rs ${amount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded, size: 42, color: c.textMuted),
          const SizedBox(height: 10),
          Text(
            hasQuery ? 'No contacts match your search' : 'No contacts yet',
            style: TextStyle(color: c.textMuted),
          ),
          if (!hasQuery) ...[
            const SizedBox(height: 4),
            Text(
              'Tap + to add your first contact',
              style: TextStyle(color: c.textMuted, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final Map<String, dynamic> person;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ContactRow({required this.person, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final amount = (person['amount'] ?? 0) as num;
    final isPositive = amount >= 0;
    final sharedUser = person['sharedUser'];
    final name = person['name'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarColor = person['color'] as Color? ?? c.accentSoft;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(radius: 22, backgroundColor: avatarColor, child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w700))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                      const SizedBox(height: 2),
                      Text(
                        isPositive ? 'Apko Milenge' : 'Apko Dene Hain',
                        style: TextStyle(fontSize: 12.5, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                if (sharedUser != null) ...[
                  GestureDetector(
                    onTap: () async {
                      final result = await showDialog(
                        context: context,
                        builder: (context) => SharedUserInfoBottomSheet(
                          contactId: person['id'],
                          sharedUser: sharedUser,
                        ),
                      );
                      if (!context.mounted) return;
                      if (result == "removed") {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Access removed successfully.")),
                        );
                      } else if (result == "failed") {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Failed to remove access.")),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: c.surfaceAlt,
                      backgroundImage: (sharedUser['imageUrl'] != null && sharedUser['imageUrl'].toString().isNotEmpty)
                          ? CachedNetworkImageProvider(sharedUser['imageUrl'] as String)
                          : null,
                      child: (sharedUser['imageUrl'] == null || sharedUser['imageUrl'].toString().isEmpty)
                          ? Icon(Icons.person, size: 14, color: c.textMuted)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  'Rs ${amount.abs().toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isPositive ? c.accentStrong : c.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
