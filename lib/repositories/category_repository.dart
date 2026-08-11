import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../Models/model.dart';

/// Centralizes Firestore access for `users/{uid}/categories`.
/// Behavior ported as-is from the old `Category` class in Models/category.dart.
class CategoryRepository {
  static List<CategoryModel> generateCategories() {
    final uuid = Uuid();
    return [
      CategoryModel(
        id: uuid.v4(),
        title: 'Customers',
        iconData: CupertinoIcons.person_2,
        bgColor: Colors.green,
        iconColor: Colors.white,
        desc: [],
        completed: [],
        position: 0,
        isDefault: true,
      ),
      CategoryModel(
        id: uuid.v4(),
        title: 'Suppliers',
        iconData: CupertinoIcons.person_2,
        bgColor: Colors.blue,
        iconColor: Colors.white,
        desc: [],
        completed: [],
        position: 1,
        isDefault: true,
      ),
      CategoryModel(
        id: uuid.v4(),
        title: 'Family',
        iconData: CupertinoIcons.person_2,
        bgColor: Colors.yellow,
        iconColor: Colors.white,
        desc: [],
        completed: [],
        position: 2,
        isDefault: true,
      ),
      CategoryModel(
        id: uuid.v4(),
        title: 'Friends',
        iconData: CupertinoIcons.person_2,
        bgColor: Colors.red,
        iconColor: Colors.white,
        desc: [],
        completed: [],
        position: 3,
        isDefault: true,
      ),
    ];
  }

  static CategoryModel getAddCategoryBox() {
    return CategoryModel(
      id: 'add',
      title: '+ Add',
      isLast: true,
    );
  }

  static Future<void> storeCategoriesToFirestore(List<CategoryModel> categories) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');

    final collectionRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('categories');
    final batch = FirebaseFirestore.instance.batch();

    for (var category in categories.where((c) => !c.isLast)) {
      final docRef = collectionRef.doc(category.id);
      batch.set(docRef, category.toMap());
    }
    await batch.commit();
  }

  static Future<List<CategoryModel>> loadCategoriesFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');

    final querySnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).collection('categories').get();

    final categories = querySnapshot.docs.map((doc) => CategoryModel.fromMap(doc.data(), doc.id)).toList();

    final defaults = categories.where((c) => c.isDefault).toList();
    final custom = categories.where((c) => !c.isDefault && !c.isLast).toList();

    defaults.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
    custom.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));

    return [...defaults, ...custom, getAddCategoryBox()];
  }

  static Future<void> updateCustomCategoryPositions(List<CategoryModel> customCategories) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');

    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance.collection('users').doc(uid).collection('categories');

    for (int i = 0; i < customCategories.length; i++) {
      final category = customCategories[i];
      final docRef = collection.doc(category.id);
      batch.update(docRef, {'position': i});
    }
    await batch.commit();
  }

  static Future<List<CategoryModel>> loadOrInitializeCategories() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');

    final collectionRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('categories');

    final snapshot = await collectionRef.get();

    if (snapshot.docs.isEmpty) {
      final defaultCategories = generateCategories();
      await storeCategoriesToFirestore(defaultCategories);
      return [...defaultCategories, getAddCategoryBox()];
    }
    final loaded = await loadCategoriesFromFirestore();
    loaded.sort((a, b) {
      if (a.isLast) return 1;
      if (b.isLast) return -1;
      if (a.createdAt != null && b.createdAt != null) {
        return a.createdAt!.compareTo(b.createdAt!);
      }
      return 0;
    });
    return [...loaded, getAddCategoryBox()];
  }

  static Future<void> deleteCategory(String categoryId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('categories').doc(categoryId).delete();
  }
}
