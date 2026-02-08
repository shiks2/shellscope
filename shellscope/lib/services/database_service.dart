import 'dart:async';
import 'dart:io';
import 'package:shellscope/model/log_entry.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:get_it/get_it.dart';
import 'package:shellscope/services/logger_service.dart';
import 'package:shellscope/constants/app_constants.dart';
import 'package:path/path.dart' as p;

class DatabaseService {
  Database?
  _db; // Fixed: internal DB instance should be Database, not DatabaseService
  // _lastKnownId field removed as internal polling is disabled
  Timer? _pollingTimer; // To keep track of the timer

  // Stream to update UI
  final _controller = StreamController<List<LogEntry>>.broadcast();
  Stream<List<LogEntry>> get logStream => _controller.stream;

  Future<void> init() async {
    // Initialize FFI for Windows
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Connect to the SAME file Python is writing to
    final dbPath = p.join(Directory.current.path, AppConstants.dbName);

    GetIt.instance<MyLogger>().logInfo("📂 Connecting to DB at: $dbPath");

    _db = await openDatabase(
      dbPath,
      readOnly: false,
    ); // Needs write access for pruning

    // Prune old logs (Default 7 days, later configurable)
    await pruneOldLogs(7);

    // Start Polling
    _startPolling();
  }

  Future<void> pruneOldLogs(int daysToKeep) async {
    if (_db == null) return;
    try {
      final now = DateTime.now();
      final cutoff = now.subtract(Duration(days: daysToKeep)).toIso8601String();

      // Assuming 'timestamp' column exists and is comparable string or we rely on SQLite date function
      // If table uses standard timestamp:
      // await _db!.rawDelete("DELETE FROM ${AppConstants.logTable} WHERE time < datetime('now', '-$daysToKeep days')");
      // But since we might be using custom schema, let's look at schema if possible or assume date('now',...) works.
      // Based on prompt: DELETE FROM logs WHERE date < date('now', '-$daysToKeep days')

      await _db!.rawDelete(
        "DELETE FROM ${AppConstants.logTable} WHERE date < ?",
        [cutoff],
      );

      GetIt.instance<MyLogger>().logInfo(
        "Pruned logs older than $daysToKeep days.",
      );
    } catch (e) {
      GetIt.instance<MyLogger>().logError("Failed to prune logs: $e");
    }
  }

  // Internal cache to keep UI snappy without re-fetching from DB constantly for every event
  List<LogEntry> _currentLogs = [];

  // Fetch logs for UI polling
  Future<List<LogEntry>> getLogs() async {
    if (_db == null) return [];

    // Fetch latest 50 logs directly
    final List<Map<String, dynamic>> maps = await _db!.query(
      AppConstants.logTable,
      orderBy: 'id DESC',
      limit: 50,
    );

    _currentLogs = maps.map((e) => LogEntry.fromSql(e)).toList();
    return _currentLogs;
  }

  /// Process valid JSON from Python Monitor
  void processRealTimeLog(Map<String, dynamic> payload) {
    try {
      // 1. Convert JSON to LogEntry
      // Note: usage of 'fromSql' or 'fromJson' depends on your model.
      // The Python script sends "isRunning" (bool) and "pid" (int).
      // LogEntry.fromJson handles these.
      final newLog = LogEntry.fromJson(payload);

      // 2. Logic:
      // If Status == NEW/Suspicious -> Add to top
      // If Status == CLOSED -> Find existing PID in list and update it

      bool found = false;

      // We iterate to find if we already have this PID showing "Running"
      for (int i = 0; i < _currentLogs.length; i++) {
        if (_currentLogs[i].pid == newLog.pid) {
          // If we found it, update the specific entry
          // But wait, if it's "CLOSED", we want to update the entry to show duration
          if (!newLog.isRunning) {
            _currentLogs[i] = newLog; // Replace with the 'Closed' version
            found = true;
          }
          // If it's a duplicate "NEW" event (rare), ignore or update
          break;
        }
      }

      if (!found && newLog.isRunning) {
        // Add to top if it's a new process and not found
        _currentLogs.insert(0, newLog);
        // Keep list size manageable
        if (_currentLogs.length > 50) {
          _currentLogs = _currentLogs.sublist(0, 50);
        }
      }

      // 3. Emit updated list
      _controller.add(List.from(_currentLogs));
    } catch (e) {
      GetIt.instance<MyLogger>().logError("Error processing real-time log: $e");
    }
  }

  void _startPolling() {
    // Internal polling disabled in favor of UI polling for now
    // or keep it if we want stream updates later.
    // For this refactor, I'll comment it out to avoid double polling overhead
    // since main.dart is driving the refresh.
  }

  // New stop method to clean up resources
  Future<void> stop() async {
    _pollingTimer?.cancel();
    await _db?.close();
    await _controller.close();
    GetIt.instance<MyLogger>().logInfo("🛑 DatabaseService stopped");
  }
}
