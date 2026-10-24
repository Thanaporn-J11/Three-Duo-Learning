import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Handler = Future<http.Response> Function(http.Request request);

/// A JWT-shaped string whose payload is [payload]. The app only reads the
/// payload; the backend checks the signature.
String fakeJwt(Object payload) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc(<String, String>{'alg': 'none'})}.${enc(payload)}.sig';
}

/// Fake phone storage with a signed-in child (account 1) plus [extra] values.
void signIn([Map<String, Object> extra = const <String, Object>{}]) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'jwt_token': fakeJwt(<String, Object>{'userId': 1}),
    ...extra,
  });
}

/// Runs [body] with every `package:http` call answered by [handler].
Future<T> withServer<T>(Future<T> Function() body, Handler handler) {
  return http.runWithClient(body, () => MockClient(handler));
}

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

/// Answers every call with a network failure.
Future<http.Response> offline(http.Request request) async =>
    throw http.ClientException('offline');
