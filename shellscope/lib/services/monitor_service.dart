import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:shellscope/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shellscope/constants/app_constants.dart';
import 'package:get_it/get_it.dart';
import 'package:shellscope/services/logger_service.dart';

class MonitorService {
  final ValueNotifier<bool> isRunning = ValueNotifier(false);
  Process? _process;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  Timer? _retryTimer;

  bool _manualStop = false;

  void start() async {
    if (isRunning.value) return;
    _manualStop = false;
    _retryCount = 0;
    _spawnProcess();
  }

  void _spawnProcess() async {
    try {
      GetIt.instance<MyLogger>().logInfo(
        "Starting backend process: python ${AppConstants.pythonScriptPath}",
      );

      // Run python script directly for dev/real-time updates
      // Using 'python' as default. Ensure python is in PATH.
      String pythonCommand = 'python';

      _process = await Process.start(pythonCommand, [AppConstants.pythonScriptPath]);

      isRunning.value = true;
      GetIt.instance<MyLogger>().logInfo(
        "Backend started with PID: ${_process!.pid}",
      );

      // Listen to stdout for real-time events with correct line splitting
      _process!.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {

        line = line.trim();
        if (line.isEmpty) return;

        // Log everything from python for debugging (except raw JSON maybe)
        if (!line.startsWith("LOG::")) {
             GetIt.instance<MyLogger>().logInfo("PYTHON: $line");
        }

        if (line.startsWith("LOG::")) {
          try {
            final jsonStr = line.substring(5);
            final payload = jsonDecode(jsonStr) as Map<String, dynamic>;
            GetIt.instance<DatabaseService>().processRealTimeLog(payload);
          } catch (e) {
            GetIt.instance<MyLogger>().logError("Failed to parse log: $e\nLine: $line");
          }
        }
      }, onError: (e) {
          GetIt.instance<MyLogger>().logError("Stdout error: $e");
      });

      // Listen to stderr for errors
      _process!.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.isNotEmpty) {
             GetIt.instance<MyLogger>().logError("PYTHON_ERR: $line");
        }
      });

      // Listen for exit
      _process!.exitCode.then((code) {
        isRunning.value = false;
        GetIt.instance<MyLogger>().logWarning(
          "Backend exited with code: $code",
        );

        if (!_manualStop && code != 0) {
          _handleCrash();
        }
      });
    } catch (e) {
      GetIt.instance<MyLogger>().logError("Failed to start backend: $e");
      isRunning.value = false;
      _handleCrash();
    }
  }

  void _handleCrash() {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      GetIt.instance<MyLogger>().logWarning(
        "Retrying backend start in 2s... (Attempt $_retryCount/$_maxRetries)",
      );
      _retryTimer = Timer(const Duration(seconds: 2), () {
        _spawnProcess();
      });
    } else {
      GetIt.instance<MyLogger>().logError(
        "Backend crashed too many times. Giving up.",
      );
    }
  }

  void stop() {
    _manualStop = true;
    _retryTimer?.cancel();
    _process?.kill();
    isRunning.value = false;
  }
}
