import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shellscope/main.dart';
import 'package:shellscope/services/database_service.dart';
import 'package:shellscope/services/license_service.dart';
import 'package:shellscope/model/log_entry.dart';
import 'package:shellscope/services/monitor_service.dart';

// Mocks
class MockDatabaseService implements DatabaseService {
  final _controller = StreamController<List<LogEntry>>.broadcast();

  @override
  Stream<List<LogEntry>> get logStream => _controller.stream;

  @override
  Future<List<LogEntry>> getLogs({int limit = 50, int offset = 0}) async => [];

  @override
  Future<void> init() async {}

  @override
  void processRealTimeLog(Map<String, dynamic> payload) {}

  @override
  Future<void> pruneOldLogs(int daysToKeep) async {}

  @override
  Future<void> stop() async {}
}

class MockLicenseService implements LicenseService {
  @override
  Future<bool> isPro() async => false;

  @override
  Future<void> saveKey(String key) async {}

  @override
  Future<void> removeKey() async {}

  @override
  bool validateKey(String key) => true;
}

class MockMonitorService implements MonitorService {
  @override
  ValueNotifier<bool> isRunning = ValueNotifier(true);

  @override
  void start() {}

  @override
  void stop() {}
}

void main() {
  setUp(() {
    GetIt.instance.registerSingleton<DatabaseService>(MockDatabaseService());
    GetIt.instance.registerSingleton<LicenseService>(MockLicenseService());
    GetIt.instance.registerSingleton<MonitorService>(MockMonitorService());
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: MonitorScreen()));

    // Verify that the title is present
    expect(find.text('ShellScope'), findsOneWidget);

    // Verify waiting message
    expect(find.text('Waiting for activity...'), findsOneWidget);
  });
}
