import 'package:flutter/material.dart';

import '../models/model.dart';
import '../repositories/category_repository.dart';
import '../repositories/contact_repository.dart';
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
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Choose a category to save contact from ${widget.senderName}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategoryId,
                  items: [
                    ...categories.map((cat) => DropdownMenuItem(
                          value: cat.id,
                          child: Text(cat.title),
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
                  onPressed: isSaving ? null : _saveSharedContact,
                  child: const Text("Save"),
                )
              ],
            ),
          );
  }
}
