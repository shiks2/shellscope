import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shellscope/constants/app_constants.dart';
import 'package:shellscope/services/database_service.dart';
import 'package:shellscope/services/logger_service.dart';
import 'package:shellscope/services/startup_service.dart';
import 'package:shellscope/services/monitor_service.dart';
import 'package:shellscope/services/license_service.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

class AppInit {
  static Future<void> initialize() async {
    // 1. Core Binding
    WidgetsFlutterBinding.ensureInitialized();

    // 2. Dependency Injection
    _setUpLocator();
    final logger = GetIt.instance<MyLogger>();
    logger.logInfo("Initializing App...");

    // 3. Window Manager
    await windowManager.ensureInitialized();

    // Single Instance Check
    await WindowsSingleInstance.ensureSingleInstance(
      [], // args not processed yet
      "shell_scope_unique_id",
      onSecondWindow: (args) {
        windowManager.show();
        windowManager.focus();
      },
    );

    WindowOptions windowOptions = const WindowOptions(
      size: Size(900, 600),
      minimumSize: Size(600, 400),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: AppConstants.appTitle,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // 4. Services
    // Database Logic
    final dbService = GetIt.instance<DatabaseService>();
    // We can init it here so it's ready for the UI
    // Note: init() is async, so we await it.
    await dbService.init();

    // Startup Service
    await GetIt.instance<StartupService>().init();

    logger.logInfo("App Initialization Completed.");
  }

  static void _setUpLocator() {
    final getIt = GetIt.instance;
    getIt.registerSingleton<MyLogger>(MyLogger());
    getIt.registerSingleton<StartupService>(StartupService());
    getIt.registerSingleton<DatabaseService>(DatabaseService());
    getIt.registerSingleton<MonitorService>(MonitorService());
    getIt.registerSingleton<LicenseService>(LicenseService());
    // Register other services if needed as singletons
  }
}
