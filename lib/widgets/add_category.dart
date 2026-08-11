import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  void _addCategory() async {
  final title = _titleController.text.trim();
  if (title.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter a category title')),
    );
    return;
  }

  final uid = FirebaseAuth.instance.currentUser!.uid;
  final categoryRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('categories')
      .doc();

  await categoryRef.set({
    'name': title,
    'title': title,
    'color': _selectedColor.value,
    'icon': _selectedIcon.codePoint,
    'iconFontFamily': _selectedIcon.fontFamily,
    'iconFontPackage': _selectedIcon.fontPackage,
    'createdAt': FieldValue.serverTimestamp(),
  });
 // Navigator.pop(context, 'success');
 Navigator.pop(context, {
  'id': categoryRef.id,
  'title': title,
  'color': _selectedColor.value,
  'icon': _selectedIcon.codePoint,
  'iconFontFamily': _selectedIcon.fontFamily,
  'iconFontPackage': _selectedIcon.fontPackage,
});
}
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets, // Handle keyboard overlap
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Title', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter category title',
              ),
            ),
            const SizedBox(height: 20),
            const Text('Color', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Text('Icon', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: availableIcons.map((icon) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedIcon == icon ? Colors.black : Colors.grey,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 30),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF89BE4F),
                ),
                child: const Text("Create", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
