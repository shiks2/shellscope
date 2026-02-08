import 'package:shellscope/constants/app_constants.dart';

class LogEntry {
  final int? id;
  final int pid;
  final String date;
  final String time;
  final String child;
  final String parent;
  final String args;
  final int suspicious;
  final String status;
  final bool isRunning;
  final String duration;

  LogEntry({
    this.id,
    required this.pid,
    required this.date,
    required this.time,
    required this.child,
    required this.parent,
    required this.args,
    required this.suspicious,
    required this.status,
    required this.isRunning,
    required this.duration,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      pid: json['pid'] ?? 0,
      date:
          json['date'] ??
          '', // JSON might not send date, but usually used for live events
      time: json['time'] ?? '',
      child: json['child'] ?? 'Unknown',
      parent: json['parent'] ?? 'Unknown',
      args: json['args'] ?? '',
      suspicious: json['suspicious'] == true ? 1 : 0,
      status: json['status'] ?? AppConstants.statusNew,
      isRunning:
          json['isRunning'] ??
          true, // JSON usually implies live/new, so running
      duration: json['duration'] ?? 'Running',
    );
  }

  factory LogEntry.fromSql(Map<String, dynamic> json) {
    final isRunningVal = json['is_running'] == 1;
    String durationStr = "Running";

    if (!isRunningVal) {
      final double? dur = json['duration'];
      if (dur != null) {
        durationStr = "${dur.toStringAsFixed(2)}s";
      } else {
        durationStr = "Unknown";
      }
    }

    return LogEntry(
      id: json['id'],
      pid: json['pid'] ?? 0,
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      child: json['child'] ?? '',
      parent: json['parent'] ?? '',
      args: json['args'] ?? '',
      suspicious: json['suspicious'] ?? 0,
      status: json['status'] ?? AppConstants.statusNew,
      isRunning: isRunningVal,
      duration: durationStr,
    );
  }
}
