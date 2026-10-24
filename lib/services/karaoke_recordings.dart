import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'user_account_preferences.dart';

class KaraokeRecording {
  const KaraokeRecording({
    required this.path,
    required this.seconds,
    required this.savedAt,
  });

  final String path;
  final int seconds;
  final DateTime savedAt;
}

/// Keeps ONE recording per song per account (the latest). Older takes are
/// deleted so recordings don't pile up on the phone. Files live in
/// `<app documents>/karaoke/<account>/`, and a copy is backed up to the
/// account on the server (/api/karaoke/recordings), so takes come back after
/// reinstalling the app or on another phone.
class KaraokeRecordings {
  KaraokeRecordings._();

  static Future<String> _account() async =>
      await UserAccountPreferences.currentUserId() ?? 'guest';

  static Future<String> _key(String songId) async {
    final base = 'karaoke_latest_$songId';
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null ? base : UserAccountPreferences.keyFor(base, userId);
  }

  static Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/karaoke/${await _account()}');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// A fresh file path for a new take of [songId].
  static Future<String> newRecordingPath(String songId) async {
    final dir = await _dir();
    return '${dir.path}/${songId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  /// The latest saved take, or null (also null if its file has gone).
  static Future<KaraokeRecording?> latest(String songId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _key(songId);
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final parts = raw.split('|');
      if (parts.length != 3) return null;
      final path = parts[0];
      if (!await File(path).exists()) {
        await prefs.remove(key);
        return null;
      }
      return KaraokeRecording(
        path: path,
        seconds: int.tryParse(parts[1]) ?? 0,
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(parts[2]) ?? 0,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Makes [path] the latest take of [songId] and deletes the previous one.
  static Future<void> saveLatest(String songId, String path, int seconds) async {
    try {
      final previous = await latest(songId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        await _key(songId),
        '$path|$seconds|${DateTime.now().millisecondsSinceEpoch}',
      );
      if (previous != null && previous.path != path) {
        await deleteFile(previous.path);
      }
      await _setFlag(songId, _pendingDelete, false);
    } catch (_) {}
    unawaited(_upload(songId)); // backup copy on the server
  }

  /// Deletes the saved take of [songId] (file and record).
  static Future<void> deleteLatest(String songId) async {
    try {
      final current = await latest(songId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(await _key(songId));
      if (current != null) await deleteFile(current.path);
      // When it was deleted, for the server (sent later if offline).
      final atKey = await _flagKey(songId, _deletedAtKey);
      if (atKey != null) await prefs.setInt(atKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
    unawaited(_deleteRemote(songId)); // and the server copy
  }

  /// Song ids (from [songIds]) that have a saved take.
  static Future<Set<String>> songsWithRecordings(List<String> songIds) async {
    final result = <String>{};
    for (final id in songIds) {
      if (await latest(id) != null) result.add(id);
    }
    return result;
  }

  static Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// One-time clean-up of takes saved by older versions of the app
  /// (`sing_*.m4a` in the documents folder), which nothing could open again.
  static Future<void> cleanUpOldVersionFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('karaoke_old_files_cleaned') ?? false) return;
      final docs = await getApplicationDocumentsDirectory();
      await for (final entity in docs.list()) {
        final name = entity.uri.pathSegments.last;
        if (entity is File && name.startsWith('sing_') && name.endsWith('.m4a')) {
          await deleteFile(entity.path);
        }
      }
      await prefs.setBool('karaoke_old_files_cleaned', true);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // Server backup
  // ---------------------------------------------------------------------

  static const Duration _timeout = Duration(seconds: 30);
  static const String _pendingUpload = 'karaoke_upload_pending';
  static const String _pendingDelete = 'karaoke_delete_pending';
  static const String _deletedAtKey = 'karaoke_deleted_at';

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return token == null || token.isEmpty ? null : token;
  }

  /// "Still to send" marks, per account and song.
  static Future<String?> _flagKey(String songId, String kind) async {
    final userId = await UserAccountPreferences.currentUserId();
    return userId == null
        ? null
        : UserAccountPreferences.keyFor('${kind}_$songId', userId);
  }

  static Future<bool> _flag(String songId, String kind) async {
    final key = await _flagKey(songId, kind);
    if (key == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  static Future<void> _setFlag(String songId, String kind, bool on) async {
    final key = await _flagKey(songId, kind);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (on) {
      await prefs.setBool(key, true);
    } else {
      await prefs.remove(key);
    }
  }

  static Uri _uri(String songId) => Uri.parse(
    '${ApiConfig.api}/karaoke/recordings/${Uri.encodeComponent(songId)}',
  );

  /// Sends the latest take of [songId] to the server (kept "to send" if offline).
  static Future<void> _upload(String songId) async {
    try {
      final recording = await latest(songId);
      final token = await _token();
      if (recording == null || token == null) return;
      await _setFlag(songId, _pendingUpload, true);
      final bytes = await File(recording.path).readAsBytes();
      final response = await http
          .put(
            _uri(songId),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'audio/mp4',
              'Authorization': 'Bearer $token',
              'X-Recording-Seconds': '${recording.seconds.clamp(0, 900)}',
              'X-Recorded-At': recording.savedAt.toUtc().toIso8601String(),
            },
            body: bytes,
          )
          .timeout(_timeout);
      // 400/404: the server will never take this file, don't retry forever.
      if (response.statusCode == 200 ||
          response.statusCode == 400 ||
          response.statusCode == 404 ||
          response.statusCode == 413) {
        await _setFlag(songId, _pendingUpload, false);
      }
    } catch (_) {
      // Offline: sent again by [syncWithServer].
    }
  }

  static Future<void> _deleteRemote(String songId) async {
    try {
      final token = await _token();
      if (token == null) return;
      await _setFlag(songId, _pendingUpload, false);
      await _setFlag(songId, _pendingDelete, true);
      final prefs = await SharedPreferences.getInstance();
      final atKey = await _flagKey(songId, _deletedAtKey);
      final atMs = atKey == null ? null : prefs.getInt(atKey);
      final at = atMs == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(atMs);
      final uri = _uri(songId).replace(
        queryParameters: {'deletedAt': at.toUtc().toIso8601String()},
      );
      final response = await http
          .delete(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout);
      if (response.statusCode == 200 || response.statusCode == 404) {
        await _setFlag(songId, _pendingDelete, false);
      }
    } catch (_) {}
  }

  /// Saves the server's take of [songId] on this phone as the latest one.
  static Future<bool> _download(String songId, int seconds, DateTime recordedAt) async {
    try {
      final token = await _token();
      if (token == null) return false;
      final response = await http
          .get(_uri(songId), headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout);
      if (response.statusCode != 200 || response.bodyBytes.length < 12) return false;
      final path = await newRecordingPath(songId);
      await File(path).writeAsBytes(response.bodyBytes, flush: true);
      final previous = await latest(songId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        await _key(songId),
        '$path|$seconds|${recordedAt.millisecondsSinceEpoch}',
      );
      if (previous != null && previous.path != path) await deleteFile(previous.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes this phone's take of [songId] without telling the server.
  static Future<void> _deleteLocalOnly(String songId) async {
    try {
      final current = await latest(songId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(await _key(songId));
      if (current != null) await deleteFile(current.path);
      await _setFlag(songId, _pendingUpload, false);
    } catch (_) {}
  }

  /// Makes this phone and the server agree (newest take wins): sends takes
  /// the server doesn't have (or older ones), downloads takes this phone
  /// doesn't have (e.g. after reinstalling the app), removes takes deleted
  /// on another phone, and finishes deletes made offline. Returns true when
  /// the takes on this phone changed.
  static Future<bool> syncWithServer(List<String> songIds) async {
    try {
      final token = await _token();
      if (token == null || await UserAccountPreferences.currentUserId() == null) {
        return false;
      }
      for (final id in songIds) {
        if (await _flag(id, _pendingDelete)) await _deleteRemote(id);
      }
      final response = await http
          .get(
            Uri.parse('${ApiConfig.api}/karaoke/recordings'),
            headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return false;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final list = body is Map ? body['recordings'] : null;
      if (list is! List) return false;
      final server = <String, ({int seconds, DateTime recordedAt})>{};
      final deleted = <String, DateTime>{}; // deleted on the server (any phone)
      for (final e in list) {
        if (e is! Map || e['songId'] is! String) continue;
        final songId = e['songId'] as String;
        if (e['deleted'] == true) {
          final at = DateTime.tryParse(e['deletedAt']?.toString() ?? '');
          if (at != null) deleted[songId] = at;
          continue;
        }
        if (e['seconds'] is! int) continue;
        final at = DateTime.tryParse(e['recordedAt']?.toString() ?? '');
        if (at != null) server[songId] = (seconds: e['seconds'] as int, recordedAt: at);
      }

      var downloaded = false;
      const slack = Duration(seconds: 2);
      for (final id in songIds) {
        if (await _flag(id, _pendingDelete)) continue; // deleted here, not sent yet
        final local = await latest(id);
        final remote = server[id];
        final deletedAt = deleted[id];
        if (deletedAt != null) {
          // Deleted on another phone: delete this copy too, unless it is a
          // newer take (recorded after the delete), which is sent instead.
          if (local != null) {
            if (local.savedAt.isAfter(deletedAt.add(slack))) {
              await _upload(id);
            } else {
              await _deleteLocalOnly(id);
              downloaded = true; // the list on screen changed
            }
          }
        } else if (remote == null) {
          if (local != null) await _upload(id); // e.g. recorded before the backup existed
        } else if (local == null || remote.recordedAt.isAfter(local.savedAt.add(slack))) {
          if (await _download(id, remote.seconds, remote.recordedAt)) downloaded = true;
        } else if (local.savedAt.isAfter(remote.recordedAt.add(slack)) ||
            await _flag(id, _pendingUpload)) {
          await _upload(id);
        }
      }
      return downloaded;
    } catch (_) {
      return false;
    }
  }
}
