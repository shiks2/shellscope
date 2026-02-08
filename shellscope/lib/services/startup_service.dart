import 'dart:io';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:shellscope/services/logger_service.dart';

class StartupService {
  Future<void> init() async {
    final logger = GetIt.instance<MyLogger>();

    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      LaunchAtStartup.instance.setup(
        appName: packageInfo.appName.isNotEmpty
            ? packageInfo.appName
            : 'ShellScope',
        appPath: Platform.resolvedExecutable,
      );

      logger.logInfo("StartupService initialized for ${packageInfo.appName}");
    } catch (e) {
      logger.logError("Failed to init StartupService: $e");
    }
  }

  Future<void> enable() async {
    await LaunchAtStartup.instance.enable();
    GetIt.instance<MyLogger>().logInfo("Run on Startup ENABLED");
  }

  Future<void> disable() async {
    await LaunchAtStartup.instance.disable();
    GetIt.instance<MyLogger>().logInfo("Run on Startup DISABLED");
  }

  Future<bool> isOn() async {
    return await LaunchAtStartup.instance.isEnabled();
  }
}
