import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/cupertino.dart';

class CategoryItem {
  final String title;
  final Category category;
  final String time;
  bool isDone;

  CategoryItem({
    required this.title,
    required this.category,
    required this.time,
    this.isDone = false,
  });
}
class Category {
  String id;
  IconData? iconData;
  String title;
  Color? bgColor;
  Color? iconColor;
  List<Map<String, dynamic>>? desc;
  List<Map<String, dynamic>>? completed;
  bool isLast;
  DateTime? createdAt;
  final int? position; // 
  final bool isDefault;

  Category({
  required this.id,
  this.iconData,
  required this.title,
  this.bgColor,
  this.iconColor,
  this.desc,
  this.completed,
  this.isLast = false,
  this.createdAt,
  this.position,
  this.isDefault = false,
});

Map<String, dynamic> toMap() {
  return {
    'title': title,
    'icon': iconData?.codePoint ?? 0,
    'iconFontFamily': iconData?.fontFamily ?? 'CupertinoIcons',
    'iconFontPackage': iconData?.fontPackage ?? 'cupertino_icons',
    'bgColor': bgColor?.value ?? 0,
    'iconColor': iconColor?.value ?? 0,
    'desc': desc ?? [],
    'completed': completed ?? [],
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    'position': position,
    'isDefault': isDefault,
  };
}
factory Category.fromMap(Map<String, dynamic> map, String docId) {
  return Category(
    id: docId,
    title: map['title'] ?? map['name'] ?? 'Untitled',
     iconData: IconData(
      map['icon'] ?? Icons.category.codePoint,
      fontFamily: map['iconFontFamily'] ?? 'CupertinoIcons',
      fontPackage: map['iconFontPackage'],
    ),
/*    iconData: const IconData(
    0xe5c3, // category icon code point
    fontFamily: 'CupertinoIcons',
),*/

    bgColor: map['bgColor'] != null ? Color(map['bgColor']) : (map['color'] != null ? Color(map['color']) : Colors.grey),
    // bgColor: map['bgColor'] != null ? Color(map['bgColor']) : Colors.grey,
    iconColor: map['iconColor'] != null ? Color(map['iconColor']) : Colors.white,
    desc: List<Map<String, dynamic>>.from(map['desc'] ?? []),
    completed: List<Map<String, dynamic>>.from(map['completed'] ?? []),
    createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    position: map['position'],
    isDefault: map['isDefault'] ?? false,
  );
}

 static List<Category> generateCategories() {
  final uuid = Uuid();
  return [
    Category(
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
    Category(
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
    Category(
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
    Category(
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
  static Category getAddCategoryBox() {
    return Category(
      id: 'add',
      title: '+ Add',
      isLast: true,
    );
  }
  // Save to Firestore
  static Future<void> storeCategoriesToFirestore(List<Category> categories) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw Exception('User not logged in');

  final collectionRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('categories');
  final batch = FirebaseFirestore.instance.batch();

  for (var category in categories.where((c) => !c.isLast)) {
    final docRef = collectionRef.doc(category.id); //
    batch.set(docRef, category.toMap());
  }
  await batch.commit();
}
  // Load from Firestore
  static Future<List<Category>> loadCategoriesFromFirestore() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw Exception('User not logged in');

  final querySnapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('categories')
      .get();

  final categories = querySnapshot.docs
      .map((doc) => Category.fromMap(doc.data(), doc.id))
      .toList();

  final defaults = categories.where((c) => c.isDefault).toList();
  final custom = categories.where((c) => !c.isDefault && !c.isLast).toList();

  defaults.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
  custom.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));

  return [...defaults, ...custom, Category.getAddCategoryBox()];
}
Future<void> updateCustomCategoryPositions(List<Category> customCategories) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw Exception('User not logged in');

  final batch = FirebaseFirestore.instance.batch();
  final collection = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('categories');

  for (int i = 0; i < customCategories.length; i++) {
    final category = customCategories[i];
    final docRef = collection.doc(category.id);
    batch.update(docRef, {'position': i});
  }
  await batch.commit();
}
  // Load or initialize default
 static Future<List<Category>> loadOrInitializeCategories() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw Exception('User not logged in');

  final collectionRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('categories');

  final snapshot = await collectionRef.get();

  if (snapshot.docs.isEmpty) {
    final defaultCategories = generateCategories();
    await storeCategoriesToFirestore(defaultCategories);
    return [...defaultCategories, getAddCategoryBox()];
  }
  final loaded = await loadCategoriesFromFirestore();
  // Sort by createdAt, put "Add" last
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
}
 