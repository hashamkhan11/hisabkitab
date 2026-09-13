import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/user_repository.dart';
import '../services/local_cache.dart';

/// Single cached source for the logged-in user's `/me` profile, so screens
/// that just need the avatar/username (e.g. the home app bar) don't each
/// issue their own `getMe()` request on every rebuild.
class CurrentUserProvider extends ChangeNotifier {
  static const _cacheKey = 'current_user';

  Map<String, dynamic>? _user;
  bool _isLoading = false;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    if (_user != null || _isLoading) return;

    final cached = await LocalCache.getJson(_cacheKey);
    if (cached != null) {
      _user = cached as Map<String, dynamic>;
      notifyListeners();
    }

    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await UserRepository.getMe();
      unawaited(LocalCache.putJson(_cacheKey, _user));
    } catch (_) {
      // Offline or the server didn't respond in time - keep whatever was
      // already loaded (live or cached) rather than clearing it.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _user = null;
    notifyListeners();
  }
}
