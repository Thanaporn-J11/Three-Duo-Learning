import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_settings_sync.dart';

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

  static Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    // One-time migration from the old plain-text PIN.
    final legacy = prefs.getString(_kLegacyPlain);
    if (legacy != null) {
      if ((prefs.getString(_kHash) ?? '').isEmpty && isValidFormat(legacy)) {
        await _store(prefs, legacy);
      }
      await prefs.remove(_kLegacyPlain);
    }
    return prefs;
  }

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static Future<void> _store(SharedPreferences prefs, String pin) async {
    final random = Random.secure();
    final salt = base64UrlEncode(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    await prefs.setString(_kSalt, salt);
    await prefs.setString(_kHash, _hash(salt, pin));
    await prefs.remove(_kFailures);
    await prefs.remove(_kLockedUntil);
  }

  static Future<bool> hasPin() async =>
      ((await _prefs()).getString(_kHash) ?? '').isNotEmpty;

  static Future<void> setPin(String pin) async {
    if (!isValidFormat(pin)) {
      throw ArgumentError('PIN must be exactly 4 digits');
    }
    await _store(await _prefs(), pin);
    unawaited(AccountSettingsSync.pushPin());
  }

  /// Removes the PIN (used after the parent proved who they are with the
  /// account password). The next visit to the parent zone sets a new one.
  static Future<void> clear() async {
    final prefs = await _prefs();
    await prefs.remove(_kHash);
    await prefs.remove(_kSalt);
    await prefs.remove(_kFailures);
    await prefs.remove(_kLockedUntil);
    unawaited(AccountSettingsSync.pushPin());
  }

  /// The saved hash + salt (to back up on the server), or null if no PIN.
  static Future<({String hash, String salt})?> storedHash() async {
    final prefs = await _prefs();
    final hash = prefs.getString(_kHash);
    final salt = prefs.getString(_kSalt);
    if (hash == null || hash.isEmpty || salt == null || salt.isEmpty) return null;
    return (hash: hash, salt: salt);
  }

  /// Takes the PIN saved with the account (null = the account has no PIN).
  /// Does not send anything back to the server.
  static Future<void> applyFromServer(String? hash, String? salt) async {
    final prefs = await _prefs();
    if (hash == null || salt == null) {
      if (prefs.getString(_kHash) == null) return;
      await prefs.remove(_kHash);
      await prefs.remove(_kSalt);
    } else {
      if (prefs.getString(_kHash) == hash && prefs.getString(_kSalt) == salt) return;
      await prefs.setString(_kSalt, salt);
      await prefs.setString(_kHash, hash);
    }
    await prefs.remove(_kFailures);
    await prefs.remove(_kLockedUntil);
  }

  /// How long the PIN is still locked after too many wrong tries.
  static Future<Duration?> lockedFor() async {
    final prefs = await _prefs();
    final until = prefs.getInt(_kLockedUntil);
    if (until == null) return null;
    final left = DateTime.fromMillisecondsSinceEpoch(
      until,
    ).difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  static Future<PinCheck> verify(String pin) async {
    final prefs = await _prefs();
    if (await lockedFor() != null) return PinCheck.locked;
    final hash = prefs.getString(_kHash);
    final salt = prefs.getString(_kSalt);
    if (hash == null || salt == null) return PinCheck.wrong;

    if (_hash(salt, pin) == hash) {
      await prefs.remove(_kFailures);
      await prefs.remove(_kLockedUntil);
      return PinCheck.ok;
    }

    final failures = (prefs.getInt(_kFailures) ?? 0) + 1;
    if (failures >= maxFailures) {
      await prefs.setInt(
        _kLockedUntil,
        DateTime.now().add(lockDuration).millisecondsSinceEpoch,
      );
      await prefs.remove(_kFailures);
      return PinCheck.locked;
    }
    await prefs.setInt(_kFailures, failures);
    return PinCheck.wrong;
  }
}
