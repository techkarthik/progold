/// Centralized App Version & Build Metadata for ProGold ERP.
/// This file is automatically updated on each release build.
class AppVersion {
  static const String appName = "ProGold";
  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '2.5.0',
  );
  static const String buildDate = String.fromEnvironment(
    'BUILD_DATE',
    defaultValue: '13-Sep-2026 19:24 IST',
  );
  static const String channel = "Cloud Active";

  /// Format: "ProGold v2.5.0 • Build: 13-Sep-2026 19:24 IST"
  static String get drawerVersion => "$appName v$version • Build: $buildDate";

  /// Format: "ProGold v2.5.0 • Build: 13-Sep-2026 19:24 IST • Cloud Active"
  static String get badgeVersion => "$appName v$version • Build: $buildDate • $channel";

  /// Full title: "ProGold v2.5.0 (13-Sep-2026 19:24 IST)"
  static String get fullTitle => "$appName v$version ($buildDate)";
}
