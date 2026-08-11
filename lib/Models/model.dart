import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CategoryModel {
  String id;
  IconData? iconData;
  String title;
  Color? bgColor;
  Color? iconColor;
  List<Map<String, dynamic>>? desc;
  List<Map<String, dynamic>>? completed;
  bool isLast;
  DateTime? createdAt;
  final int? position;
  final bool isDefault;

  CategoryModel({
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

  factory CategoryModel.fromMap(Map<String, dynamic> map, String docId) {
    return CategoryModel(
      id: docId,
      title: map['title'] ?? map['name'] ?? 'Untitled',
      iconData: IconData(
        map['icon'] ?? Icons.category.codePoint,
        fontFamily: map['iconFontFamily'] ?? 'CupertinoIcons',
        fontPackage: map['iconFontPackage'],
      ),
      bgColor: map['bgColor'] != null ? Color(map['bgColor']) : (map['color'] != null ? Color(map['color']) : Colors.grey),
      iconColor: map['iconColor'] != null ? Color(map['iconColor']) : Colors.white,
      desc: List<Map<String, dynamic>>.from(map['desc'] ?? []),
      completed: List<Map<String, dynamic>>.from(map['completed'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      position: map['position'],
      isDefault: map['isDefault'] ?? false,
    );
  }
}
