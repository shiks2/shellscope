import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  static const String _licenseKey = 'license_key';

  // Simple in-memory cache to avoid async delays in UI if needed,
  // but shared_preferences is fast enough for most cases.
  // We'll stick to async pattern for correctness.

  Future<bool> isPro() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_licenseKey);
    return key != null && key.isNotEmpty;
  }

  bool validateKey(String key) {
    // Dummy validation logic
    return key.trim().toUpperCase().startsWith("PRO-");
  }

  Future<void> saveKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_licenseKey, key.trim());
  }

  Future<void> removeKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseKey);
  }
}
