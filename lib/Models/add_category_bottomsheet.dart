import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddCategoryBottomSheet extends StatefulWidget {
  const AddCategoryBottomSheet({Key? key}) : super(key: key);

  @override
  State<AddCategoryBottomSheet> createState() => _AddCategoryBottomSheetState();
}

class _AddCategoryBottomSheetState extends State<AddCategoryBottomSheet> {
  final TextEditingController titleController = TextEditingController();

  void _saveCategory() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final title = titleController.text.trim();

    if (title.isEmpty) return;

    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('categories')
        .add({'title': title});

    Navigator.pop(context, {
      'id': docRef.id,
      'title': title,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Add New Category"),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Category Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saveCategory,
              child: const Text("Create"),
            )
          ],
        ),
      ),
    );
  }
}
