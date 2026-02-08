import 'package:flutter/material.dart';
import 'package:shellscope/services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get_it/get_it.dart';
import 'package:shellscope/app_init.dart';
import 'package:shellscope/constants/app_constants.dart';
import 'package:shellscope/model/log_entry.dart';
import 'package:shellscope/services/database_service.dart';
import 'package:shellscope/ui/widgets/log_tile.dart';
import 'package:shellscope/ui/screens/settings_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shellscope/services/monitor_service.dart';
import 'package:shellscope/services/license_service.dart';
import 'package:shellscope/ui/screens/upgrade_screen.dart';
import 'dart:async';

void main() async {
  await AppInit.initialize();
  // Start the background monitor service
  GetIt.instance<MonitorService>().start();
  runApp(const ShellScopeApp());
}

class ShellScopeApp extends StatelessWidget {
  const ShellScopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        cardColor: const Color(0xFF252526),
        primaryColor: const Color(0xFF00E5FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          error: Color(0xFFFF5252),
          secondary: Color(0xFF4CAF50),
          surface: Color(0xFF252526),
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      home: const MonitorScreen(),
    );
  }
}

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  List<LogEntry> _logs = [];
  StreamSubscription<List<LogEntry>>? _logSubscription;
  Timer? _timer;
  String? _updateUrl;

  @override
  void initState() {
    super.initState();
    // 1. Backend is started in main() via MonitorService
    // 2. Start Monitoring and checking for updates
    _startMonitoring();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    final url = await UpdateService().checkForUpdates();
    if (url != null && mounted) {
      setState(() {
        _updateUrl = url;
      });
    }
  }

  void _startMonitoring() {
    final dbService = GetIt.instance<DatabaseService>();

    // Initial fetch to populate UI immediately
    _refreshLogs();

    // Subscribe to real-time updates from MonitorService -> DatabaseService
    _logSubscription = dbService.logStream.listen((logs) {
      if (mounted) {
        setState(() {
          _logs = logs;
        });
      }
    });

    // Keep polling as backup (e.g. if python script crashes or for deep history refresh)
    // but maybe less frequent? keeping 2s for now is fine.
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _refreshLogs();
    });
  }

  // Helper to launch update
  void _launchUpdate() async {
    if (_updateUrl != null) {
      final uri = Uri.parse(_updateUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> _refreshLogs() async {
    final dbService = GetIt.instance<DatabaseService>();
    final logs = await dbService.getLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _logSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appTitle),
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        actions: [
          FutureBuilder<bool>(
            future: GetIt.instance<LicenseService>().isPro(),
            builder: (context, snapshot) {
              final isPro = snapshot.data ?? false;
              if (isPro) {
                return const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Icon(Icons.star, color: Color(0xFFFFD700)),
                );
              } else {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: OutlinedButton(
                    onPressed: () async {
                      final success = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UpgradeScreen(),
                        ),
                      );
                      if (success == true) {
                        setState(() {
                          // Trigger rebuild to update UI
                        });
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFD700),
                      side: const BorderSide(color: Color(0xFFFFD700)),
                    ),
                    child: const Text("Go Pro"),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_updateUrl != null)
            MaterialBanner(
              padding: const EdgeInsets.all(16),
              content: const Text('A new version of ShellScope is available.'),
              leading: const Icon(
                Icons.system_update,
                color: Color(0xFF00E5FF),
              ),
              backgroundColor: const Color(0xFF252526),
              contentTextStyle: const TextStyle(color: Colors.white),
              actions: [
                TextButton(
                  onPressed: _launchUpdate,
                  child: const Text(
                    'Download',
                    style: TextStyle(color: Color(0xFF00E5FF)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _updateUrl = null;
                    });
                  },
                  child: const Text(
                    'Dismiss',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          Expanded(
            child: _logs.isEmpty
                ? const Center(child: Text("Waiting for activity..."))
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return LogTile(log: _logs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
