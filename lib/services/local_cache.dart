import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny on-disk "last known good" cache for API responses, keyed per signed-in
/// user so switching accounts on the same device never shows one user's
/// cached data to another.
///
/// Used to implement stale-while-revalidate: show what we had last time
/// immediately, then let a fresh network fetch replace it - so there's
/// something to show the moment the app is offline or on a very slow
/// connection, instead of an empty/loading screen.
class LocalCache {
  LocalCache._();

  static String _scopedKey(String key) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    return 'cache_${uid}_$key';
  }

  static Future<void> putJson(String key, Object? value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(key), jsonEncode(value));
  }

  /// Returns the decoded JSON value for [key], or null if nothing is cached
  /// (or the cached entry can't be decoded).
  static Future<dynamic> getJson(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scopedKey(key));
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
