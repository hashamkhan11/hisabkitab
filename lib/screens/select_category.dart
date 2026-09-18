import 'package:flutter/material.dart';

import '../models/model.dart';
import '../repositories/category_repository.dart';
import '../repositories/contact_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/add_category.dart';

class ChooseCategoryPage extends StatefulWidget {
  final String contactId;
  final String contactName;
  final String senderName;

  const ChooseCategoryPage({
    required this.contactId,
    required this.contactName,
    required this.senderName,
    super.key,
  });

  @override
  State<ChooseCategoryPage> createState() => _ChooseCategoryPageState();
}

class _ChooseCategoryPageState extends State<ChooseCategoryPage> {
  String? selectedCategoryId;
  List<CategoryModel> categories = [];
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final loaded = await CategoryRepository.loadOrInitializeCategories();
      setState(() {
        categories = loaded.where((c) => !c.isLast).toList();
        isLoading = false;
      });
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  void _openAddCategorySheet() async {
    final newCategory = await showModalBottomSheet<CategoryModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddCategorySheet(),
    );

    if (newCategory != null) {
      setState(() {
        categories.add(newCategory);
        selectedCategoryId = newCategory.id;
      });
    }
  }

  void _saveSharedContact() async {
    if (selectedCategoryId == null || isSaving) return;

    setState(() => isSaving = true);
    try {
      final result = await ContactRepository.shareContact(
        contactId: widget.contactId,
        categoryId: selectedCategoryId!,
      );
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Something went wrong: $e")),
        );
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Save shared ledger', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Choose a category to save the contact from ${widget.senderName}',
                style: TextStyle(color: c.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                ...categories.map((cat) {
                  final isSelected = selectedCategoryId == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => selectedCategoryId = cat.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? c.accentSoft : c.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isSelected ? c.accentStrong : c.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: isSelected ? c.accentStrong : c.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cat.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? c.accentStrong : c.textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _openAddCategorySheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border, style: BorderStyle.solid),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded, color: c.accentStrong, size: 20),
                        const SizedBox(width: 12),
                        Text('Add new category', style: TextStyle(fontWeight: FontWeight.w600, color: c.accentStrong)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _saveSharedContact,
                  child: isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onAccent),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
