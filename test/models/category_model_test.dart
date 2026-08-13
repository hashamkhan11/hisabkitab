import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisabshare/models/model.dart';

void main() {
  group('CategoryModel.fromJson', () {
    test('parses a fully-populated API response', () {
      final createdAt = DateTime(2026, 1, 1);
      final json = {
        'id': 'cat123',
        'title': 'Groceries',
        'icon_codepoint': Icons.shopping_cart.codePoint,
        'icon_font_family': 'MaterialIcons',
        'icon_font_package': null,
        'bg_color': Colors.blue.toARGB32(),
        'icon_color': Colors.white.toARGB32(),
        'created_at': createdAt.toIso8601String(),
        'position': 2,
        'is_default': true,
      };

      final category = CategoryModel.fromJson(json);

      expect(category.id, 'cat123');
      expect(category.title, 'Groceries');
      expect(category.position, 2);
      expect(category.isDefault, true);
      expect(category.createdAt, createdAt);
      expect(category.bgColor?.toARGB32(), Colors.blue.toARGB32());
      expect(category.iconColor?.toARGB32(), Colors.white.toARGB32());
    });

    test('falls back to defaults when optional fields are missing', () {
      final category = CategoryModel.fromJson({'id': 'cat456'});

      expect(category.id, 'cat456');
      expect(category.title, 'Untitled');
      expect(category.isDefault, false);
      expect(category.position, null);
      expect(category.createdAt, null);
      expect(category.bgColor, Colors.grey);
      expect(category.iconColor, Colors.white);
    });
  });

  group('CategoryModel.toJson', () {
    test('serializes the canonical snake_case fields', () {
      final category = CategoryModel(
        id: 'cat1',
        title: 'Rent',
        bgColor: Colors.blue,
        iconColor: Colors.white,
        position: 1,
        isDefault: false,
      );

      final json = category.toJson();

      expect(json['title'], 'Rent');
      expect(json['position'], 1);
      expect(json['is_default'], false);
      expect(json['bg_color'], Colors.blue.toARGB32());
      expect(json['icon_color'], Colors.white.toARGB32());
    });

    test('round-trips through fromJson', () {
      final original = CategoryModel(
        id: 'cat1',
        title: 'Rent',
        bgColor: Colors.blue,
        iconColor: Colors.white,
        position: 1,
        isDefault: true,
      );

      final json = original.toJson();
      json['id'] = original.id;
      final restored = CategoryModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.position, original.position);
      expect(restored.isDefault, original.isDefault);
      expect(restored.bgColor?.toARGB32(), original.bgColor?.toARGB32());
      expect(restored.iconColor?.toARGB32(), original.iconColor?.toARGB32());
    });
  });
}
