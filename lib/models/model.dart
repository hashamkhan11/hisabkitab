import 'package:flutter/material.dart';

class CategoryModel {
  String id;
  IconData? iconData;
  String title;
  Color? bgColor;
  Color? iconColor;
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
    this.isLast = false,
    this.createdAt,
    this.position,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'icon_codepoint': iconData?.codePoint,
      'icon_font_family': iconData?.fontFamily,
      'icon_font_package': iconData?.fontPackage,
      'bg_color': bgColor?.toARGB32(),
      'icon_color': iconColor?.toARGB32(),
      'position': position,
      'is_default': isDefault,
    };
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      title: json['title'] ?? 'Untitled',
      iconData: IconData(
        json['icon_codepoint'] ?? Icons.category.codePoint,
        fontFamily: json['icon_font_family'] ?? 'CupertinoIcons',
        fontPackage: json['icon_font_package'],
      ),
      bgColor: json['bg_color'] != null ? Color(json['bg_color']) : Colors.grey,
      iconColor: json['icon_color'] != null ? Color(json['icon_color']) : Colors.white,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      position: json['position'],
      isDefault: json['is_default'] == true,
    );
  }
}
