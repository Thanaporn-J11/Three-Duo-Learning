import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'device_api_service.dart';

/// Resolves the stable account ID from the backend-issued access token.
/// The backend remains responsible for validating the JWT on every request.
class UserAccountPreferences {
  UserAccountPreferences._();

  static final Set<void Function()> _memoryResetters = <void Function()>{};

  static void registerMemoryResetter(void Function() resetter) {
    _memoryResetters.add(resetter);
  }

  static final Set<Future<void> Function()> _logoutHooks =
      <Future<void> Function()>{};

  /// Async clean-up to run on logout (e.g. cancelling scheduled notifications
  /// that belong to the account that is signing out).
  static void registerLogoutHook(Future<void> Function() hook) {
    _logoutHooks.add(hook);
  }

  /// Ends the local authenticated session without touching account data.
  static Future<void> logout() async {
    // Revoke this session on the server first, while the token still exists.
    // Best effort: being offline must not stop the user from logging out.
    try {
      await DeviceApiService.logoutCurrentSession().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {}
    await clearLocalSession();
  }

  /// After the server deleted the account: signs out and also erases what
  /// this phone kept for that account (settings, progress caches, PIN).
  static Future<void> clearDeletedAccount() async {
    final userId = await currentUserId();
    await clearLocalSession();
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final suffix = '_user_$userId';
    for (final key in prefs.getKeys().toList()) {
      if (key.endsWith(suffix)) await prefs.remove(key);
    }
  }

  /// Forgets the sign-in on this phone only (no server call). Used when the
  /// server says the session has ended (expired, or logged out elsewhere).
  static Future<void> clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    for (final reset in _memoryResetters.toList()) {
      reset();
    }
    for (final hook in _logoutHooks.toList()) {
      try {
        await hook();
      } catch (_) {
        // A failing clean-up step must not block logging out.
      }
    }
  }

  static Future<String?> currentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return null;
      final segments = token.split('.');
      if (segments.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      if (payload is! Map<String, dynamic>) return null;
      final id = payload['userId'];
      if (id is int && id > 0) return id.toString();
      if (id is String && id.trim().isNotEmpty) return id.trim();
    } catch (_) {
      // Missing or malformed tokens must never fall back to a global profile.
    }
    return null;
  }

  static String keyFor(String key, String userId) => '${key}_user_$userId';

  /// Assigns old global data to at most the first authenticated account that
  /// reaches migration. The original keys are deliberately retained.
  static Future<bool> claimLegacyData(String markerKey, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString(markerKey);
    if (owner != null) return owner == userId;
    await prefs.setString(markerKey, userId);
    return true;
  }
}
