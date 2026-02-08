import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_it/get_it.dart';
import 'package:shellscope/services/license_service.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  final TextEditingController _controller = TextEditingController();
  final LicenseService _licenseService = GetIt.instance<LicenseService>();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final key = _controller.text;
    if (_licenseService.validateKey(key)) {
      await _licenseService.saveKey(key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("License Activated Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } else {
      setState(() {
        _isLoading = false;
        _error = "Invalid License Key. Must start with 'PRO-'";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF1E1E1E), elevation: 0),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.diamond, size: 80, color: Color(0xFF00E5FF)),
              const SizedBox(height: 24),
              Text(
                "Unlock the Full Power\nof ShellScope",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 48),
              _buildFeatureRow("☁️ Cloud Sync (Coming Soon)"),
              _buildFeatureRow("🧠 AI Command Analysis"),
              _buildFeatureRow("♾️ Unlimited History"),
              const SizedBox(height: 48),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: GoogleFonts.inter(color: Colors.red),
                  ),
                ),
              TextField(
                controller: _controller,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "License Key",
                  hintText: "Enter your PRO-xxxx key",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF252526),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _activate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          "Activate License",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.inter(fontSize: 16)),
        ],
      ),
    );
  }
}
