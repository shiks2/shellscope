import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shellscope/services/networking/dio_client.dart';
import 'package:get_it/get_it.dart';
import 'package:shellscope/services/logger_service.dart';

class UpdateService {
  final DioClient _dioClient = DioClient.instance;

  // Replace strictly with your username/repo if you want this to work for real.
  static const String _releaseUrl =
      "https://api.github.com/repos/YOUR_USERNAME/shell_scope/releases/latest";

  Future<String?> checkForUpdates() async {
    try {
      final currentPackageInfo = await PackageInfo.fromPlatform();
      final currentVersion = Version.parse(currentPackageInfo.version);

      final response = await _dioClient.get(_releaseUrl);
      if (response != null && response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        String tagName = data['tag_name'] as String;
        final htmlUrl = data['html_url'] as String;

        if (tagName.startsWith('v')) {
          tagName = tagName.substring(1);
        }

        final remoteVersion = Version.parse(tagName);

        if (remoteVersion > currentVersion) {
          return htmlUrl;
        }
      }
    } catch (e) {
      // In production we might not want to log minor update failures, or use logger
      GetIt.instance<MyLogger>().logInfo("Update check failed: $e");
    }
    return null;
  }
}
