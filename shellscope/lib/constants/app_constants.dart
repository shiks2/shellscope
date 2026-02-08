class AppConstants {
  // Prevent instantiation
  AppConstants._();

  // Python / Backend Config
  static const String pythonScriptPath = 'backend/monitor.py';
  static const String monitorExePath = 'assets/monitor.exe';

  // Database Config
  static const String dbName = 'backend/shellscope.db';
  static const String logTable = 'logs';

  // UI Config
  static const String appTitle = 'ShellScope';
  static const double defaultPadding = 16.0;

  // Status Strings
  static const String statusExisting = 'EXISTING';
  static const String statusNew = 'NEW';
}
