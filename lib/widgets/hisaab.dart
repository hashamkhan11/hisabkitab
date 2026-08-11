import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:hisabshare/Models/add_category.dart';
import 'package:hisabshare/screens/detail.dart';
import 'package:hisabshare/Models/category.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Categories extends StatelessWidget {
  final List<Category> categoryList;
  final void Function(Category) onAddCategory;
  final void Function(Category) onDeleteCategory; //

  const Categories({
    required this.categoryList,
    required this.onAddCategory,
    required this.onDeleteCategory,
    super.key,
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: GridView.builder(
        itemCount: categoryList.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          final category = categoryList[index];
          return category.isLast
              ? _buildAddCategory(context)
              : _buildCategory(context, category);
        },
      ),
    );
  }

  Widget _buildAddCategory(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final newCategory = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          builder: (_) => const AddCategorySheet(),
        );
        if (newCategory != null && newCategory is Category) {
          onAddCategory(newCategory);
        }
      },
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(20),
        dashPattern: const [10, 10],
        color: Colors.grey,
        strokeWidth: 2,
        child: const Center(
          child: Text(
            '+ Add',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildCategory(BuildContext context, Category category) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailPage(
              categoryId: category.id,
              categoryName: category.title,
      
            ),
          ),
        );
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete Category'),
            content: Text('Delete "${category.title}"?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();

                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('categories')
                        .doc(category.id)
                        .delete();
                  }

                  onDeleteCategory(category); //  Pass category instead of index
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: category.bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Icon(
                category.iconData ?? Icons.category,
                color: Colors.white,
                size: 80,
              ),
            ),
            Text(
              category.title ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
