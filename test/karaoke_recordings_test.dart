import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:threeduo_learning/services/karaoke_recordings.dart';

import 'test_helpers.dart';

late Directory docs;

const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');

Handler ok([int status = 200, Object? body]) =>
    (_) async => jsonResponse(body ?? <String, Object?>{}, status);

/// Lets the background upload / delete the service starts finish.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 300));

Future<String?> stringOf(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

Future<bool> flagOf(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(key) ?? false;
}

const String uploadFlag = 'karaoke_upload_pending_s1_user_1';
const String deleteFlag = 'karaoke_delete_pending_s1_user_1';
const String recordKey = 'karaoke_latest_s1_user_1';

/// A take of song s1 on the phone: a real file plus its record.
Future<String> putLocalTake({
  String song = 's1',
  int seconds = 12,
  required DateTime savedAt,
  String name = 'local.m4a',
  Map<String, Object> extra = const <String, Object>{},
}) async {
  final file = File('${docs.path}/$name');
  await file.writeAsBytes(List<int>.filled(20, 7));
  signIn(<String, Object>{
    'karaoke_latest_${song}_user_1':
        '${file.path}|$seconds|${savedAt.millisecondsSinceEpoch}',
    ...extra,
  });
  return file.path;
}

List<int> audio() => List<int>.filled(20, 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    docs = Directory.systemTemp.createTempSync('karaoke_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => docs.path);
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    docs.deleteSync(recursive: true);
  });

  setUp(() {
    signIn();
    for (final entity in docs.listSync()) {
      entity.deleteSync(recursive: true);
    }
  });

  group('files and records', () {
    test('a new take gets a path inside the child\'s folder', () async {
      final path = await KaraokeRecordings.newRecordingPath('s1');

      expect(path, contains('/karaoke/1/'));
      expect(path, matches(RegExp(r's1_\d+\.m4a$')));
      expect(Directory('${docs.path}/karaoke/1').existsSync(), isTrue);
    });

    test('signed out takes go in a guest folder', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final path = await KaraokeRecordings.newRecordingPath('s1');

      expect(path, contains('/karaoke/guest/'));
    });

    test('there is no latest take at first', () async {
      expect(await KaraokeRecordings.latest('s1'), isNull);
    });

    test('the latest take is read back with its length and time', () async {
      final saved = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final path = await putLocalTake(savedAt: saved, seconds: 42);

      final take = await KaraokeRecordings.latest('s1');

      expect(take!.path, path);
      expect(take.seconds, 42);
      expect(take.savedAt.millisecondsSinceEpoch, saved.millisecondsSinceEpoch);
    });

    test('a record with bad numbers still opens', () async {
      final file = File('${docs.path}/x.m4a')..writeAsBytesSync(<int>[1]);
      signIn(<String, Object>{recordKey: '${file.path}|x|y'});

      final take = await KaraokeRecordings.latest('s1');

      expect(take!.seconds, 0);
      expect(take.savedAt.millisecondsSinceEpoch, 0);
    });

    test('a damaged record is ignored', () async {
      signIn(<String, Object>{recordKey: 'only|two'});
      expect(await KaraokeRecordings.latest('s1'), isNull);
    });

    test('a record whose file has gone is forgotten', () async {
      signIn(<String, Object>{recordKey: '${docs.path}/gone.m4a|5|1000'});

      expect(await KaraokeRecordings.latest('s1'), isNull);
      expect(await stringOf(recordKey), isNull);
    });

    test('songsWithRecordings lists only songs that have a take', () async {
      await putLocalTake(savedAt: DateTime.utc(2026));

      expect(
        await KaraokeRecordings.songsWithRecordings(<String>['s1', 's2']),
        <String>{'s1'},
      );
    });

    test('deleteFile removes a file and ignores a missing one', () async {
      final file = File('${docs.path}/a.m4a')..writeAsBytesSync(<int>[1]);

      await KaraokeRecordings.deleteFile(file.path);
      await KaraokeRecordings.deleteFile(file.path);

      expect(file.existsSync(), isFalse);
    });

    test('old files from earlier versions are cleaned up once', () async {
      File('${docs.path}/sing_a.m4a').writeAsBytesSync(<int>[1]);
      File('${docs.path}/sing_b.txt').writeAsBytesSync(<int>[1]);
      File('${docs.path}/other.m4a').writeAsBytesSync(<int>[1]);

      await KaraokeRecordings.cleanUpOldVersionFiles();
      File('${docs.path}/sing_c.m4a').writeAsBytesSync(<int>[1]);
      await KaraokeRecordings.cleanUpOldVersionFiles();

      expect(File('${docs.path}/sing_a.m4a').existsSync(), isFalse);
      expect(File('${docs.path}/sing_b.txt').existsSync(), isTrue);
      expect(File('${docs.path}/other.m4a').existsSync(), isTrue);
      expect(File('${docs.path}/sing_c.m4a').existsSync(), isTrue);
    });
  });

  group('saving and deleting', () {
    test('a new take replaces the old one and is backed up', () async {
      final oldPath = await putLocalTake(
        savedAt: DateTime.utc(2026),
        name: 'old.m4a',
      );
      final newFile = File('${docs.path}/new.m4a')
        ..writeAsBytesSync(<int>[9, 9, 9]);
      http.Request? sent;

      await withServer(() async {
        await KaraokeRecordings.saveLatest('s1', newFile.path, 2000);
        await settle();
      }, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{});
      });

      final take = await KaraokeRecordings.latest('s1');
      expect(take!.path, newFile.path);
      expect(take.seconds, 2000);
      expect(File(oldPath).existsSync(), isFalse);
      expect(sent!.method, 'PUT');
      expect(sent!.url.path, '/api/karaoke/recordings/s1');
      expect(sent!.headers['content-type'], startsWith('audio/mp4'));
      expect(sent!.headers['x-recording-seconds'], '900');
      expect(sent!.headers['x-recorded-at'], isNotEmpty);
      expect(sent!.bodyBytes, <int>[9, 9, 9]);
      expect(await flagOf(uploadFlag), isFalse);
    });

    test('saving the same file again keeps it', () async {
      final path = await putLocalTake(savedAt: DateTime.utc(2026));

      await withServer(() async {
        await KaraokeRecordings.saveLatest('s1', path, 5);
        await settle();
      }, ok());

      expect(File(path).existsSync(), isTrue);
    });

    test('a backup that could not be sent is marked to send later', () async {
      for (final handler in <Handler>[offline, ok(500)]) {
        final path = await putLocalTake(savedAt: DateTime.utc(2026));

        await withServer(() async {
          await KaraokeRecordings.saveLatest('s1', path, 5);
          await settle();
        }, handler);

        expect(await flagOf(uploadFlag), isTrue);
      }
    });

    test('a backup the server will never take is not retried', () async {
      for (final status in <int>[400, 404, 413]) {
        final path = await putLocalTake(savedAt: DateTime.utc(2026));

        await withServer(() async {
          await KaraokeRecordings.saveLatest('s1', path, 5);
          await settle();
        }, ok(status));

        expect(await flagOf(uploadFlag), isFalse, reason: '$status');
      }
    });

    test('signed out: nothing is sent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final file = File('${docs.path}/g.m4a')..writeAsBytesSync(<int>[1]);
      var called = false;

      await withServer(() async {
        await KaraokeRecordings.saveLatest('s1', file.path, 5);
        await settle();
      }, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(called, isFalse);
    });

    test('deleting removes the take and tells the server', () async {
      final path = await putLocalTake(
        savedAt: DateTime.utc(2026),
        extra: <String, Object>{uploadFlag: true},
      );
      http.Request? sent;

      await withServer(() async {
        await KaraokeRecordings.deleteLatest('s1');
        await settle();
      }, (request) async {
        sent = request;
        return jsonResponse(<String, Object?>{});
      });

      expect(await KaraokeRecordings.latest('s1'), isNull);
      expect(File(path).existsSync(), isFalse);
      expect(sent!.method, 'DELETE');
      expect(sent!.url.path, '/api/karaoke/recordings/s1');
      expect(sent!.url.queryParameters['deletedAt'], isNotEmpty);
      expect(await flagOf(uploadFlag), isFalse);
      expect(await flagOf(deleteFlag), isFalse);
    });

    test('a delete the server did not get is marked to send later', () async {
      for (final handler in <Handler>[offline, ok(500)]) {
        await putLocalTake(savedAt: DateTime.utc(2026));

        await withServer(() async {
          await KaraokeRecordings.deleteLatest('s1');
          await settle();
        }, handler);

        expect(await flagOf(deleteFlag), isTrue);
      }
    });

    test('a take the server never had counts as deleted', () async {
      await putLocalTake(savedAt: DateTime.utc(2026));

      await withServer(() async {
        await KaraokeRecordings.deleteLatest('s1');
        await settle();
      }, ok(404));

      expect(await flagOf(deleteFlag), isFalse);
    });

    test('deleting when there is nothing saved does no harm', () async {
      await withServer(() async {
        await KaraokeRecordings.deleteLatest('s1');
        await settle();
      }, ok());

      expect(await KaraokeRecordings.latest('s1'), isNull);
    });
  });

  group('syncWithServer', () {
    final long = DateTime.utc(2020);
    final recent = DateTime.utc(2030);

    Map<String, Object?> remote({
      String song = 's1',
      int seconds = 30,
      DateTime? recordedAt,
    }) => <String, Object?>{
      'songId': song,
      'seconds': seconds,
      'recordedAt': (recordedAt ?? recent).toIso8601String(),
    };

    Map<String, Object?> remoteDeleted({DateTime? at}) => <String, Object?>{
      'songId': 's1',
      'deleted': true,
      'deletedAt': (at ?? recent).toIso8601String(),
    };

    /// Answers the list, a single take download, and uploads/deletes.
    Handler server(
      Object? list, {
      List<http.Request>? log,
      http.Response? download,
      int listStatus = 200,
    }) => (request) async {
      log?.add(request);
      if (request.method == 'PUT' || request.method == 'DELETE') {
        return jsonResponse(<String, Object?>{});
      }
      if (request.url.path == '/api/karaoke/recordings') {
        return jsonResponse(list, listStatus);
      }
      return download ?? http.Response.bytes(audio(), 200);
    };

    Object recordings(List<Object?> items) => <String, Object?>{
      'recordings': items,
    };

    Future<bool> sync([List<String> songs = const <String>['s1']]) =>
        KaraokeRecordings.syncWithServer(songs);

    test('signed out: no request is made', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var called = false;

      final changed = await withServer(sync, (_) async {
        called = true;
        return jsonResponse(<String, Object?>{});
      });

      expect(changed, isFalse);
      expect(called, isFalse);
    });

    test('downloads a take this phone does not have', () async {
      final changed = await withServer(
        sync,
        server(recordings(<Object?>[remote(seconds: 33)])),
      );

      expect(changed, isTrue);
      final take = await KaraokeRecordings.latest('s1');
      expect(take!.seconds, 33);
      expect(take.savedAt.millisecondsSinceEpoch, recent.millisecondsSinceEpoch);
      expect(File(take.path).readAsBytesSync(), audio());
    });

    test('a download that is too small or fails is ignored', () async {
      for (final download in <http.Response>[
        http.Response.bytes(<int>[1, 2], 200),
        http.Response.bytes(audio(), 500),
      ]) {
        signIn();
        final changed = await withServer(
          sync,
          server(recordings(<Object?>[remote()]), download: download),
        );

        expect(changed, isFalse);
        expect(await KaraokeRecordings.latest('s1'), isNull);
      }
    });

    test('a newer take on the server replaces an older one here', () async {
      final oldPath = await putLocalTake(savedAt: long);

      final changed = await withServer(
        sync,
        server(recordings(<Object?>[remote()])),
      );

      expect(changed, isTrue);
      expect(File(oldPath).existsSync(), isFalse);
      final take = await KaraokeRecordings.latest('s1');
      expect(take!.path, isNot(oldPath));
    });

    test('a newer take here is sent to the server', () async {
      await putLocalTake(savedAt: recent);
      final log = <http.Request>[];

      final changed = await withServer(
        sync,
        server(recordings(<Object?>[remote(recordedAt: long)]), log: log),
      );

      expect(changed, isFalse);
      expect(log.where((r) => r.method == 'PUT'), hasLength(1));
    });

    test('a take the server does not have is sent', () async {
      await putLocalTake(savedAt: long);
      final log = <http.Request>[];

      await withServer(sync, server(recordings(<Object?>[]), log: log));

      expect(log.where((r) => r.method == 'PUT'), hasLength(1));
    });

    test('takes that agree are left alone', () async {
      await putLocalTake(savedAt: recent);
      final log = <http.Request>[];

      final changed = await withServer(
        sync,
        server(recordings(<Object?>[remote()]), log: log),
      );

      expect(changed, isFalse);
      expect(log.where((r) => r.method != 'GET'), isEmpty);
    });

    test('a backup still waiting is sent even when the times agree', () async {
      await putLocalTake(
        savedAt: recent,
        extra: <String, Object>{uploadFlag: true},
      );
      final log = <http.Request>[];

      await withServer(
        sync,
        server(recordings(<Object?>[remote()]), log: log),
      );

      expect(log.where((r) => r.method == 'PUT'), hasLength(1));
    });

    test('a take deleted on another phone is removed here', () async {
      final path = await putLocalTake(savedAt: long);

      final changed = await withServer(
        sync,
        server(recordings(<Object?>[remoteDeleted()])),
      );

      expect(changed, isTrue);
      expect(File(path).existsSync(), isFalse);
      expect(await KaraokeRecordings.latest('s1'), isNull);
    });

    test('a take recorded after the delete is kept and sent', () async {
      final path = await putLocalTake(savedAt: recent);
      final log = <http.Request>[];

      final changed = await withServer(
        sync,
        server(
          recordings(<Object?>[remoteDeleted(at: long)]),
          log: log,
        ),
      );

      expect(changed, isFalse);
      expect(File(path).existsSync(), isTrue);
      expect(log.where((r) => r.method == 'PUT'), hasLength(1));
    });

    test('a delete made offline is finished first', () async {
      await putLocalTake(
        savedAt: long,
        extra: <String, Object>{deleteFlag: true},
      );
      final log = <http.Request>[];

      await withServer(sync, server(recordings(<Object?>[remote()]), log: log));

      expect(log.first.method, 'DELETE');
      expect(await flagOf(deleteFlag), isFalse);
      expect(log.where((r) => r.method == 'PUT'), isEmpty);
    });

    test('entries it cannot use are skipped', () async {
      final changed = await withServer(
        sync,
        server(recordings(<Object?>[
          'x',
          <String, Object?>{'songId': 5},
          <String, Object?>{'songId': 's1', 'seconds': 'x'},
          <String, Object?>{'songId': 's1', 'seconds': 5, 'recordedAt': 'never'},
          <String, Object?>{'songId': 's1', 'deleted': true, 'deletedAt': 'never'},
        ])),
      );

      expect(changed, isFalse);
      expect(await KaraokeRecordings.latest('s1'), isNull);
    });

    test('a server that cannot answer changes nothing', () async {
      for (final handler in <Handler>[
        server(<String, Object?>{}, listStatus: 500),
        offline,
        server(<int>[1]),
        server(<String, Object?>{'recordings': 'x'}),
      ]) {
        expect(await withServer(sync, handler), isFalse);
      }
    });
  });
}
