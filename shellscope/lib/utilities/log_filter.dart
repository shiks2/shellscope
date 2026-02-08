import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class MyLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // Allow logs in both Debug and Release mode based on logic
    if (kReleaseMode) {
      return event.level.index >=
          Level.warning.index; // Only allow warning and above in release mode
    } else {
      return true; // Allow all logs in debug mode
    }
  }
}
