import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../repositories/contact_repository.dart';
import '../services/local_cache.dart';

/// Single source of truth for a category's contact list, shared between
/// DetailPage and ListPage. Previously each screen fetched (or was handed a
/// point-in-time snapshot of) contacts independently, so a delete made on one
/// screen didn't reach the other - e.g. deleting a contact from ListPage left
/// it still showing on DetailPage until the category was closed and reopened.
class ContactsProvider extends ChangeNotifier {
  final Map<String, List<Map<String, dynamic>>> _byCategory = {};
  final Set<String> _loading = {};
  final Random _random = Random();

  List<Map<String, dynamic>> contactsFor(String categoryId) =>
      _byCategory[categoryId] ?? const [];

  bool isLoading(String categoryId) => _loading.contains(categoryId);

  Color _randomCardColor() => Color.fromARGB(
        255,
        150 + _random.nextInt(106),
        100 + _random.nextInt(156),
        100 + _random.nextInt(156),
      );

  /// Loads contacts (with server-computed `balance`/`total_receive`/`total_send`
  /// per contact) and hydrates each with its shared-with-user avatar info, same
  /// transformation DetailPage used to do locally.
  Future<void> loadContacts(String categoryId) async {
    if (!_byCategory.containsKey(categoryId)) {
      final cached = await _cachedContacts(categoryId);
      if (cached != null) {
        _byCategory[categoryId] = cached;
        notifyListeners();
      }
    }

    _loading.add(categoryId);
    notifyListeners();

    try {
      final contacts = await ContactRepository.listContacts(categoryId);
      final loaded = <Map<String, dynamic>>[];

      for (final data in contacts) {
        final contactId = data['id'] as String;
        final name = data['name'] as String?;
        if (name == null) continue;

        final isSharedView = data['is_shared_view'] == true;

        Map<String, dynamic>? sharedUser;
        if (!isSharedView) {
          final shares = await ContactRepository.shares(contactId);
          if (shares.isNotEmpty) {
            final sharedWithUser = shares.first['shared_with_user'] as Map<String, dynamic>?;
            if (sharedWithUser != null) {
              sharedUser = {
                'uid': sharedWithUser['id'],
                'username': sharedWithUser['username'] ?? '',
                'email': sharedWithUser['email'] ?? '',
                'imageUrl': sharedWithUser['image_url'] ?? '',
                'mobileNo': sharedWithUser['mobile_no'] ?? '',
              };
            }
          }
        }

        loaded.add({
          'id': contactId,
          'name': name,
          'amount': (data['balance'] as num?)?.toDouble() ?? 0.0,
          'totalReceive': (data['total_receive'] as num?)?.toDouble() ?? 0.0,
          'totalSend': (data['total_send'] as num?)?.toDouble() ?? 0.0,
          'color': _randomCardColor(),
          'mobileNo': data['mobile_no'] ?? '',
          'email': data['email'] ?? '',
          'address': data['address'] ?? '',
          'isSharedView': isSharedView,
          if (sharedUser != null) 'sharedUser': sharedUser,
        });
      }

      _byCategory[categoryId] = loaded;
      unawaited(_cacheContacts(categoryId, loaded));
    } catch (_) {
      // Offline or the server didn't respond in time - keep whatever was
      // already showing (live or cached) instead of clearing the list.
    } finally {
      _loading.remove(categoryId);
      notifyListeners();
    }
  }

  static String _cacheKey(String categoryId) => 'contacts_$categoryId';

  Future<void> _cacheContacts(String categoryId, List<Map<String, dynamic>> loaded) async {
    // `color` is a Color object (assigned freshly per load, not server data),
    // so it isn't JSON-encodable - strip it and regenerate it on the way back
    // out of the cache instead.
    final cacheable = loaded.map((c) {
      final copy = Map<String, dynamic>.from(c)..remove('color');
      return copy;
    }).toList();
    await LocalCache.putJson(_cacheKey(categoryId), cacheable);
  }

  Future<List<Map<String, dynamic>>?> _cachedContacts(String categoryId) async {
    final cached = await LocalCache.getJson(_cacheKey(categoryId));
    if (cached == null) return null;
    return (cached as List<dynamic>).cast<Map<String, dynamic>>().map((c) {
      return {...c, 'color': _randomCardColor()};
    }).toList();
  }

  Future<void> deleteContact(String categoryId, String contactId) async {
    await ContactRepository.deleteContact(contactId);
    _byCategory[categoryId]?.removeWhere((c) => c['id'] == contactId);
    notifyListeners();
  }
}
