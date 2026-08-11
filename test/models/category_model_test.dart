import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisabshare/models/model.dart';

void main() {
  group('CategoryModel.fromMap', () {
    test('parses a fully-populated Firestore document map', () {
      final createdAt = DateTime(2026, 1, 1);
      final map = {
        'title': 'Groceries',
        'icon': Icons.shopping_cart.codePoint,
        'iconFontFamily': 'MaterialIcons',
        'bgColor': Colors.blue.toARGB32(),
        'iconColor': Colors.white.toARGB32(),
        'desc': [
          {'note': 'weekly'}
        ],
        'completed': [
          {'id': '1'}
        ],
        'createdAt': Timestamp.fromDate(createdAt),
        'position': 2,
        'isDefault': true,
      };

      final category = CategoryModel.fromMap(map, 'cat123');

      expect(category.id, 'cat123');
      expect(category.title, 'Groceries');
      expect(category.position, 2);
      expect(category.isDefault, true);
      expect(category.createdAt, createdAt);
      expect(category.desc, [
        {'note': 'weekly'}
      ]);
      expect(category.completed, [
        {'id': '1'}
      ]);
    });

    test('falls back to defaults when optional fields are missing', () {
      final category = CategoryModel.fromMap({}, 'cat456');

      expect(category.id, 'cat456');
      expect(category.title, 'Untitled');
      expect(category.isDefault, false);
      expect(category.position, null);
      expect(category.createdAt, null);
      expect(category.desc, []);
      expect(category.completed, []);
    });

    test('falls back to the legacy "name" field when "title" is absent', () {
      final category = CategoryModel.fromMap({'name': 'Legacy Category'}, 'cat789');
      expect(category.title, 'Legacy Category');
    });
  });

  group('CategoryModel.toMap', () {
    test('serializes an explicit createdAt as a Firestore Timestamp', () {
      final createdAt = DateTime(2026, 3, 5);
      final category = CategoryModel(
        id: 'cat1',
        title: 'Rent',
        createdAt: createdAt,
        position: 1,
        isDefault: false,
      );

      final map = category.toMap();

      expect(map['title'], 'Rent');
      expect(map['position'], 1);
      expect(map['isDefault'], false);
      expect(map['createdAt'], Timestamp.fromDate(createdAt));
    });

    test('round-trips through fromMap when createdAt is explicit', () {
      final createdAt = DateTime(2026, 3, 5);
      final original = CategoryModel(
        id: 'cat1',
        title: 'Rent',
        createdAt: createdAt,
        position: 1,
        isDefault: true,
      );

      final restored = CategoryModel.fromMap(original.toMap(), original.id);

      expect(restored.title, original.title);
      expect(restored.position, original.position);
      expect(restored.isDefault, original.isDefault);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
