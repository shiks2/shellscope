import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../utilities/log_filter.dart'; // Ensure relative import is correct

class MyLogger {
  final Logger _logger = Logger(
    level: Level.debug,
    printer: SimplePrinter(),
    filter: MyLogFilter(),
  );

  void logDebug(String message) {
    if (!kReleaseMode) {
      _logger.d(message);
    }
  }

  void logInfo(String message) {
    if (!kReleaseMode) {
      _logger.i(message);
    }
  }

  void logWarning(String message) {
    _logger.w(message);
  }

  void logError(String message) {
    _logger.e(message);
  }

  void logFatal(String message) {
    _logger.f(message);
  }
}
