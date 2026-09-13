import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hisabshare/screens/contact_detail.dart';
import 'package:hisabshare/services/transaction_service.dart';
import 'package:hisabshare/theme/app_theme.dart';

/// "View all" destination for the dashboard's Recent Transactions section:
/// merges and sorts transactions across every contact in every category
/// client-side (no backend aggregate endpoint exists).
class AllTransactionsPage extends StatefulWidget {
  final List<Map<String, String>> contacts;

  const AllTransactionsPage({required this.contacts, super.key});

  @override
  State<AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<AllTransactionsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = TransactionService.recentAcrossContacts(widget.contacts, limit: 200);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      appBar: AppBar(title: const Text('All Transactions')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final txns = snapshot.data ?? [];
          if (txns.isEmpty) {
            return Center(
              child: Text('No transactions yet', style: TextStyle(color: c.textMuted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: txns.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final txn = txns[index];
              return _TxnCard(
                txn: txn,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactDetailPage(
                      categoryId: txn['categoryId'] as String? ?? '',
                      contactId: txn['contactId'] as String,
                      contactName: txn['contactName'] as String,
                      isSharedView: false,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TxnCard extends StatelessWidget {
  final Map<String, dynamic> txn;
  final VoidCallback onTap;

  const _TxnCard({required this.txn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isReceive = txn['type'] == 'Receive';
    final amount = (txn['credit'] as num?)?.toDouble() ?? 0.0;
    final date = txn['date'] as DateTime;
    final contactName = txn['contactName'] as String? ?? '';
    final note = txn['note'] as String? ?? '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isReceive ? c.accentSoft : c.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isReceive ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 16,
                color: isReceive ? c.accentStrong : c.danger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contactName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(
                    note.isNotEmpty
                        ? '${DateFormat('MMM d, yyyy').format(date)} · $note'
                        : DateFormat('MMM d, yyyy').format(date),
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              'Rs ${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: isReceive ? c.accentStrong : c.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
