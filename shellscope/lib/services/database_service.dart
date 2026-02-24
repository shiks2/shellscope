import 'dart:async';
import 'dart:io';
import 'package:shellscope/model/log_entry.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:get_it/get_it.dart';
import 'package:shellscope/services/logger_service.dart';
import 'package:shellscope/constants/app_constants.dart';
import 'package:path/path.dart' as p;

class DatabaseService {
  Database? _db;
  Timer? _pollingTimer;

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
    );

    // Prune old logs async
    pruneOldLogs(7);

    // Initial fetch
    await getLogs();
  }

  Future<void> pruneOldLogs(int daysToKeep) async {
    if (_db == null) return;
    try {
      final now = DateTime.now();
      final cutoff = now.subtract(Duration(days: daysToKeep)).toIso8601String();

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
  Future<List<LogEntry>> getLogs({int limit = 50, int offset = 0}) async {
    if (_db == null) return [];

    final List<Map<String, dynamic>> maps = await _db!.query(
      AppConstants.logTable,
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );

    if (offset == 0) {
        _currentLogs = maps.map((e) => LogEntry.fromSql(e)).toList();
        // Emit initial state
        _controller.add(List.from(_currentLogs));
        return _currentLogs;
    } else {
        return maps.map((e) => LogEntry.fromSql(e)).toList();
    }
  }

  /// Process valid JSON from Python Monitor
  void processRealTimeLog(Map<String, dynamic> payload) {
    try {
      final newLog = LogEntry.fromJson(payload);
      bool found = false;

      for (int i = 0; i < _currentLogs.length; i++) {
        if (_currentLogs[i].pid == newLog.pid) {
          // Found matching PID.
          // If we receive CLOSED, we look for the running entry with same PID.
          if (!newLog.isRunning && _currentLogs[i].isRunning) {
            // Update the existing entry with duration and status, keeping other info
            final old = _currentLogs[i];
            _currentLogs[i] = LogEntry(
                id: old.id,
                pid: old.pid,
                date: old.date,
                time: old.time,
                child: old.child,
                parent: old.parent,
                args: old.args,
                suspicious: old.suspicious,
                status: newLog.status,
                isRunning: newLog.isRunning,
                duration: newLog.duration
            );
            found = true;
          } else if (newLog.isRunning) {
             // Duplicate NEW or update? Assume duplicate or same instance update.
             found = true;
          }
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

  // New stop method to clean up resources
  Future<void> stop() async {
    _pollingTimer?.cancel();
    await _db?.close();
    await _controller.close();
    GetIt.instance<MyLogger>().logInfo("🛑 DatabaseService stopped");
  }
}
