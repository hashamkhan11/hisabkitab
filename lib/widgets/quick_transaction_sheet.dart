import 'package:flutter/material.dart';
import 'package:hisabshare/models/model.dart';
import 'package:hisabshare/services/transaction_service.dart';
import 'package:hisabshare/theme/app_theme.dart';

/// Two-step "quick transaction" flow opened from the home FAB: pick a
/// contact (across every category), then fill in the transaction itself.
/// Only ever shown once at least one category has at least one contact -
/// the caller (home.dart) handles the zero-category/zero-contact guidance.
class QuickTransactionSheet extends StatefulWidget {
  final List<CategoryModel> categories;
  final Map<String, List<Map<String, dynamic>>> contactsByCategory;

  const QuickTransactionSheet({
    required this.categories,
    required this.contactsByCategory,
    super.key,
  });

  @override
  State<QuickTransactionSheet> createState() => _QuickTransactionSheetState();
}

class _QuickTransactionSheetState extends State<QuickTransactionSheet> {
  final TextEditingController _searchController = TextEditingController();

  CategoryModel? _selectedCategory;
  Map<String, dynamic>? _selectedContact;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _type = 'Receive';
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final contactId = _selectedContact?['id'] as String?;
    if (contactId == null) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await TransactionService.addTransaction(
        contactId: contactId,
        date: _date,
        type: _type,
        credit: amount,
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction added')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add transaction: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final sheetHeight = MediaQuery.of(context).size.height * 0.82;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: (sheetHeight - viewInsets).clamp(0.0, sheetHeight),
          child: _selectedContact == null ? _buildContactPicker() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildContactPicker() {
    final c = context.appColors;
    final query = _searchController.text.trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Quick transaction', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('Who is this transaction with?', style: TextStyle(color: c.textMuted, fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search contacts',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              for (final category in widget.categories) ...() {
                final contacts = (widget.contactsByCategory[category.id] ?? [])
                    .where((p) => query.isEmpty || (p['name'] as String? ?? '').toLowerCase().contains(query))
                    .toList();
                if (contacts.isEmpty) return <Widget>[];
                return <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Text(
                      category.title,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: c.textMuted),
                    ),
                  ),
                  for (final contact in contacts)
                    _ContactPickerTile(
                      contact: contact,
                      onTap: () => setState(() {
                        _selectedCategory = category;
                        _selectedContact = contact;
                      }),
                    ),
                ];
              }(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final c = context.appColors;
    final contactName = _selectedContact?['name'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() {
                  _selectedContact = null;
                  _selectedCategory = null;
                }),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contactName, style: Theme.of(context).textTheme.titleMedium),
                    if (_selectedCategory != null)
                      Text(_selectedCategory!.title, style: TextStyle(color: c.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TypeChoice(
                  label: 'Receive',
                  icon: Icons.south_west_rounded,
                  selected: _type == 'Receive',
                  color: c.accentStrong,
                  bg: c.accentSoft,
                  onTap: () => setState(() => _type = 'Receive'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TypeChoice(
                  label: 'Send',
                  icon: Icons.north_east_rounded,
                  selected: _type == 'Send',
                  color: c.danger,
                  bg: c.dangerSoft,
                  onTap: () => setState(() => _type = 'Send'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Amount', style: TextStyle(fontWeight: FontWeight.w600, color: c.textColor)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0',
              prefixText: 'Rs ',
            ),
          ),
          const SizedBox(height: 16),
          Text('Date', style: TextStyle(fontWeight: FontWeight.w600, color: c.textColor)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2015),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18, color: c.textMuted),
                  const SizedBox(width: 10),
                  Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Note (optional)', style: TextStyle(fontWeight: FontWeight.w600, color: c.textColor)),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(hintText: 'Add a note'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onAccent),
                    )
                  : const Text('Save transaction'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactPickerTile extends StatelessWidget {
  final Map<String, dynamic> contact;
  final VoidCallback onTap;

  const _ContactPickerTile({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final name = contact['name'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: c.accentSoft,
              child: Text(initial, style: TextStyle(fontWeight: FontWeight.w700, color: c.accentStrong)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5))),
            Icon(Icons.chevron_right_rounded, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _TypeChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _TypeChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? bg : c.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : c.border, width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : c.textMuted),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : c.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
