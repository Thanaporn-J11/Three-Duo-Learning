/// Where the app finds the ThreeDuo backend. Change it in ONE place.
///
/// Default `10.0.2.2` is how the Android emulator reaches the computer it runs
/// on. For a real phone or a deployed server, pass the address when building
/// instead of editing code:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000
///   flutter build apk --dart-define=API_BASE_URL=https://api.example.com
class ApiConfig {
  ApiConfig._();

  /// Server root, without a trailing slash.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// REST API root, e.g. `${ApiConfig.api}/profile`.
  static const String api = '$baseUrl/api';
}
