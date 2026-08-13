import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/model.dart';
import '../services/api_client.dart';

/// Centralizes category access against the Laravel API (`/api/categories`).
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
        position: 0,
        isDefault: true,
      ),
      CategoryModel(
        id: uuid.v4(),
        title: 'Suppliers',
        iconData: CupertinoIcons.person_2,
        bgColor: Colors.blue,
        iconColor: Colors.white,
        position: 1,
        isDefault: true,
      ),
      CategoryModel(
        id: uuid.v4(),
        title: 'Family',
        iconData: CupertinoIcons.person_2,
        bgColor: Colors.yellow,
        iconColor: Colors.white,
        position: 2,
        isDefault: true,
      ),
      CategoryModel(
        id: uuid.v4(),
        title: 'Friends',
        iconData: CupertinoIcons.person_2,
        bgColor: Colors.red,
        iconColor: Colors.white,
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

  /// Loads the user's categories, seeding the default set on first run
  /// (mirrors the old Firestore "seed if empty" behavior). The API already
  /// orders results `is_default desc, position asc`, so no client-side
  /// re-sort is needed.
  static Future<List<CategoryModel>> loadOrInitializeCategories() async {
    var categories = await _fetchCategories();

    if (categories.isEmpty) {
      await ApiClient.instance.post('/categories/batch', body: {
        'categories': generateCategories().map((c) => c.toJson()).toList(),
      });
      categories = await _fetchCategories();
    }

    return [...categories, getAddCategoryBox()];
  }

  static Future<List<CategoryModel>> _fetchCategories() async {
    final data = await ApiClient.instance.get('/categories') as List<dynamic>;
    return data.map((json) => CategoryModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  static Future<CategoryModel> createCategory({
    required String title,
    Color? bgColor,
    IconData? iconData,
  }) async {
    final data = await ApiClient.instance.post('/categories', body: {
      'title': title,
      'bg_color': bgColor?.toARGB32(),
      'icon_codepoint': iconData?.codePoint,
      'icon_font_family': iconData?.fontFamily,
      'icon_font_package': iconData?.fontPackage,
    });
    return CategoryModel.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteCategory(String categoryId) async {
    await ApiClient.instance.delete('/categories/$categoryId');
  }
}
