import 'package:package_info_plus/package_info_plus.dart';

/// The app's real version, read from the installed build (pubspec.yaml
/// `version: 1.2.3+45` → version "1.2.3", build "45"). Change the version
/// there instead of typing it into screens.
class AppVersion {
  AppVersion._();

  static Future<PackageInfo>? _info;

  static Future<PackageInfo> _load() => _info ??= PackageInfo.fromPlatform();

  /// e.g. "1.0.0"
  static Future<String> number() async => (await _load()).version;

  /// e.g. "1.0.0 (บิลด์ 1)"
  static Future<String> label() async {
    final info = await _load();
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version} (บิลด์ ${info.buildNumber})';
  }
}
