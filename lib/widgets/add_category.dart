import 'package:flutter/material.dart';

import '../repositories/category_repository.dart';
import '../theme/app_theme.dart';

class AddCategorySheet extends StatefulWidget {
  const AddCategorySheet({super.key});

  @override
  State<AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<AddCategorySheet> {
  final TextEditingController _titleController = TextEditingController();

  final List<Color> availableColors = [
    Colors.green,
    Colors.red,
    Colors.amber,
    Colors.blue,
    Colors.pink,
    Colors.lightBlueAccent,
  ];

  final List<IconData> availableIcons = [
    Icons.groups,
    Icons.group,
    Icons.group_outlined,
  ];

  Color _selectedColor = Colors.red;
  IconData _selectedIcon = Icons.work;
  bool _isSaving = false;

  void _addCategory() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category title')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final category = await CategoryRepository.createCategory(
        title: title,
        bgColor: _selectedColor,
        iconData: _selectedIcon,
      );
      if (mounted) Navigator.pop(context, category);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create category: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: MediaQuery.of(context).viewInsets, // Handle keyboard overlap
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
            Text('New category', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 18),
            Text('Title', style: TextStyle(fontWeight: FontWeight.w600, color: c.textColor)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Enter category title',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),
            const SizedBox(height: 20),
            Text('Color', style: TextStyle(fontWeight: FontWeight.w600, color: c.textColor)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: availableColors.map((color) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: CircleAvatar(
                    backgroundColor: color,
                    radius: 20,
                    child: _selectedColor == color
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Icon', style: TextStyle(fontWeight: FontWeight.w600, color: c.textColor)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: availableIcons.map((icon) {
                final isSelected = _selectedIcon == icon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? c.accentSoft : null,
                      border: Border.all(
                        color: isSelected ? c.accentStrong : c.border,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 30, color: isSelected ? c.accentStrong : c.textMuted),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _addCategory,
                child: _isSaving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onAccent),
                      )
                    : const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
