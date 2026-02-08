import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shellscope/services/startup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shellscope/services/license_service.dart';
import 'package:shellscope/ui/screens/upgrade_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StartupService _startupService = GetIt.instance<StartupService>();
  bool _isRunOnStartup = false;
  bool _isLoading = true;
  int _retentionDays = 7;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final isOn = await _startupService.isOn();
    final prefs = await SharedPreferences.getInstance();
    final retention = prefs.getInt('retention_days') ?? 7;

    if (mounted) {
      setState(() {
        _isRunOnStartup = isOn;
        _retentionDays = retention;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleStartup(bool value) async {
    setState(() => _isLoading = true);
    if (value) {
      await _startupService.enable();
    } else {
      await _startupService.disable();
    }
    await _loadState();
  }

  Future<void> _updateRetention(int? newValue) async {
    if (newValue == null) return;
    setState(() => _retentionDays = newValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('retention_days', newValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Settings",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "General",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: Text(
                    "Run on Startup",
                    style: GoogleFonts.inter(fontSize: 16),
                  ),
                  subtitle: Text(
                    "Automatically start ShellScope when you log in.",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  value: _isRunOnStartup,
                  onChanged: _toggleStartup,
                  activeTrackColor: Theme.of(context).primaryColor,
                ),
                const Divider(),
                ListTile(
                  title: Text(
                    "Data Retention",
                    style: GoogleFonts.inter(fontSize: 16),
                  ),
                  subtitle: Text(
                    "Automatically delete logs older than...",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  trailing: DropdownButton<int>(
                    value: _retentionDays,
                    dropdownColor: const Color(0xFF252526),
                    style: GoogleFonts.inter(color: Colors.white),
                    underline: Container(),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text("3 Days")),
                      DropdownMenuItem(value: 7, child: Text("7 Days")),
                      DropdownMenuItem(value: 30, child: Text("30 Days")),
                      DropdownMenuItem(value: 365, child: Text("Forever")),
                    ],
                    onChanged: _updateRetention,
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: Row(
                    children: [
                      Text(
                        "Cloud Sync",
                        style: GoogleFonts.inter(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      // We can check license status here too or simpler:
                      // Show Lock icon if not enabled?
                      // For now, prompt asked for specific logic in onChanged.
                      // Let's add a visual cue anyway.
                      const Icon(Icons.lock, size: 14, color: Colors.grey),
                    ],
                  ),
                  subtitle: Text(
                    "Sync your logs across devices.",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  value: false, // Always false for now
                  onChanged: (value) async {
                    // Check Pro Status
                    final isPro = await GetIt.instance<LicenseService>()
                        .isPro();
                    if (!isPro && context.mounted) {
                      final success = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UpgradeScreen(),
                        ),
                      );
                      if (success == true) {
                        // Refresh state if upgraded
                        _loadState();
                      }
                      return;
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Cloud Sync Coming Soon!"),
                        ),
                      );
                    }
                  },
                  activeTrackColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
    );
  }
}
