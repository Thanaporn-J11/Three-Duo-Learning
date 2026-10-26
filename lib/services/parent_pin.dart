import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_settings_sync.dart';
import 'user_account_preferences.dart';

enum PinCheck { ok, wrong, locked }

/// Parent PIN (4 digits) for the parent zone and for unlocking the rest
/// screen. Only a salted SHA-256 hash is stored, never the PIN itself.
/// After [maxFailures] wrong tries the PIN is locked for [lockDuration].
///
/// Note: a 4-digit PIN has only 10,000 combinations, so the hash keeps the
/// PIN from being read in plain text; the lockout is what slows guessing.
///
/// The hash and salt are also kept with the account on the server (never
/// the PIN), so the PIN stays the same after reinstalling or on another phone.
///
/// The PIN belongs to the account: it is saved on the phone under the signed
/// in account's id, so another account signing in on the same phone does not
/// get (or upload) this account's PIN.
class ParentPin {
  ParentPin._();

  static const String _kHash = 'parent_pin_hash';
  static const String _kSalt = 'parent_pin_salt';
  static const String _kLegacyPlain = 'parent_pin_code'; // old plain-text key
  static const String _kFailures = 'parent_pin_failures';
  static const String _kLockedUntil = 'parent_pin_locked_until';

  static const int maxFailures = 5;
  static const Duration lockDuration = Duration(minutes: 1);

  static bool isValidFormat(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

  /// Where this phone keeps the signed in account's PIN data (without an
  /// account, the plain keys are used).
  static Future<_Keys> _keys() async {
    final userId = await UserAccountPreferences.currentUserId();
    String key(String base) =>
        userId == null ? base : UserAccountPreferences.keyFor(base, userId);
    return _Keys(
      hash: key(_kHash),
      salt: key(_kSalt),
      failures: key(_kFailures),
      lockedUntil: key(_kLockedUntil),
      signedIn: userId != null,
    );
  }

  static Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _keys();
    // One-time migration: before PINs were kept per account, one PIN was
    // saved for the whole phone. The account signed in now takes it.
    if (keys.signedIn) {
      final oldHash = prefs.getString(_kHash);
      final oldSalt = prefs.getString(_kSalt);
      if (oldHash != null && oldSalt != null) {
        if ((prefs.getString(keys.hash) ?? '').isEmpty && oldHash.isNotEmpty) {
          await prefs.setString(keys.hash, oldHash);
          await prefs.setString(keys.salt, oldSalt);
        }
      }
      for (final old in <String>[
        _kHash,
        _kSalt,
        _kFailures,
        _kLockedUntil,
      ]) {
        await prefs.remove(old);
      }
    }
    // One-time migration from the old plain-text PIN.
    final legacy = prefs.getString(_kLegacyPlain);
    if (legacy != null) {
      if ((prefs.getString(keys.hash) ?? '').isEmpty && isValidFormat(legacy)) {
        await _store(prefs, legacy, keys);
      }
      await prefs.remove(_kLegacyPlain);
    }
    return prefs;
  }

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static Future<void> _store(
    SharedPreferences prefs,
    String pin,
    _Keys keys,
  ) async {
    final random = Random.secure();
    final salt = base64UrlEncode(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    await prefs.setString(keys.salt, salt);
    await prefs.setString(keys.hash, _hash(salt, pin));
    await prefs.remove(keys.failures);
    await prefs.remove(keys.lockedUntil);
  }

  static Future<bool> hasPin() async {
    final prefs = await _prefs();
    return (prefs.getString((await _keys()).hash) ?? '').isNotEmpty;
  }

  static Future<void> setPin(String pin) async {
    if (!isValidFormat(pin)) {
      throw ArgumentError('PIN must be exactly 4 digits');
    }
    final prefs = await _prefs();
    await _store(prefs, pin, await _keys());
    unawaited(AccountSettingsSync.pushPin());
  }

  /// Removes the PIN (used after the parent proved who they are with the
  /// account password). The next visit to the parent zone sets a new one.
  static Future<void> clear() async {
    final prefs = await _prefs();
    final keys = await _keys();
    await prefs.remove(keys.hash);
    await prefs.remove(keys.salt);
    await prefs.remove(keys.failures);
    await prefs.remove(keys.lockedUntil);
    unawaited(AccountSettingsSync.pushPin());
  }

  /// The saved hash + salt (to back up on the server), or null if no PIN.
  static Future<({String hash, String salt})?> storedHash() async {
    final prefs = await _prefs();
    final keys = await _keys();
    final hash = prefs.getString(keys.hash);
    final salt = prefs.getString(keys.salt);
    if (hash == null || hash.isEmpty || salt == null || salt.isEmpty) return null;
    return (hash: hash, salt: salt);
  }

  /// Takes the PIN saved with the account (null = the account has no PIN).
  /// Does not send anything back to the server.
  static Future<void> applyFromServer(String? hash, String? salt) async {
    final prefs = await _prefs();
    final keys = await _keys();
    if (hash == null || salt == null) {
      if (prefs.getString(keys.hash) == null) return;
      await prefs.remove(keys.hash);
      await prefs.remove(keys.salt);
    } else {
      if (prefs.getString(keys.hash) == hash &&
          prefs.getString(keys.salt) == salt) {
        return;
      }
      await prefs.setString(keys.salt, salt);
      await prefs.setString(keys.hash, hash);
    }
    await prefs.remove(keys.failures);
    await prefs.remove(keys.lockedUntil);
  }

  /// How long the PIN is still locked after too many wrong tries.
  static Future<Duration?> lockedFor() async {
    final prefs = await _prefs();
    final until = prefs.getInt((await _keys()).lockedUntil);
    if (until == null) return null;
    final left = DateTime.fromMillisecondsSinceEpoch(
      until,
    ).difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  static Future<PinCheck> verify(String pin) async {
    final prefs = await _prefs();
    final keys = await _keys();
    if (await lockedFor() != null) return PinCheck.locked;
    final hash = prefs.getString(keys.hash);
    final salt = prefs.getString(keys.salt);
    if (hash == null || salt == null) return PinCheck.wrong;

    if (_hash(salt, pin) == hash) {
      await prefs.remove(keys.failures);
      await prefs.remove(keys.lockedUntil);
      return PinCheck.ok;
    }

    final failures = (prefs.getInt(keys.failures) ?? 0) + 1;
    if (failures >= maxFailures) {
      await prefs.setInt(
        keys.lockedUntil,
        DateTime.now().add(lockDuration).millisecondsSinceEpoch,
      );
      await prefs.remove(keys.failures);
      return PinCheck.locked;
    }
    await prefs.setInt(keys.failures, failures);
    return PinCheck.wrong;
  }
}

/// Storage keys of one account's PIN data.
class _Keys {
  const _Keys({
    required this.hash,
    required this.salt,
    required this.failures,
    required this.lockedUntil,
    required this.signedIn,
  });

  final String hash;
  final String salt;
  final String failures;
  final String lockedUntil;
  final bool signedIn;
}
