import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shellscope/constants/app_constants.dart';
import 'package:shellscope/model/log_entry.dart';
import 'package:url_launcher/url_launcher.dart';

class LogTile extends StatelessWidget {
  final LogEntry log;
  const LogTile({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    // Color Logic
    Color indicatorColor = const Color(0xFF4CAF50); // Safe/Success
    if (log.suspicious == 1) {
      indicatorColor = const Color(0xFFFF5252); // Error/Suspicious
    } else if (log.status == AppConstants.statusExisting) {
      indicatorColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(left: BorderSide(color: indicatorColor, width: 4)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (log.isRunning)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50), // Green for Running
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x664CAF50),
                                blurRadius: 4,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      Text(
                        log.isRunning ? "Running" : log.duration,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: log.isRunning
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: log.isRunning
                              ? const Color(0xFF4CAF50)
                              : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    log.time,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                log.child,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                log.args,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            AppConstants.defaultPadding,
            0,
            AppConstants.defaultPadding,
            AppConstants.defaultPadding,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow("Parent Process", log.parent),
            const SizedBox(height: 8),
            _buildDetailRow("Child Process", log.child),
            const SizedBox(height: 16),
            Text("Arguments:", style: GoogleFonts.inter(color: Colors.white70)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                log.args,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  color: const Color(0xFF00E5FF),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: log.args));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Arguments copied to clipboard"),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text("Copy Arguments"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF252526),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () => _searchOnline(context),
                  icon: const Icon(
                    Icons.search,
                    size: 18,
                    color: Color(0xFF00E5FF),
                  ),
                  label: Text(
                    "Search Online",
                    style: GoogleFonts.inter(color: const Color(0xFF00E5FF)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _searchOnline(BuildContext context) async {
    final query = log.args.isEmpty
        ? "what is windows process ${log.child}"
        : "is command ${log.child} ${log.args} safe";

    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse("https://www.google.com/search?q=$encodedQuery");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not launch browser")),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text("$label: ", style: GoogleFonts.inter(color: Colors.white70)),
        Text(value, style: GoogleFonts.jetBrainsMono(color: Colors.white)),
      ],
    );
  }
}
