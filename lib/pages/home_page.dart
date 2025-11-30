import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  bool _isAbsenLoading = false;

  // Dummy koordinat
  final String _dummyLatitude = "-6.200000";
  final String _dummyLongitude = "106.816666";

  // SnackBar untuk error
  void _showSnackBar(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // Dialog sukses auto-close
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.blue),
              const SizedBox(height: 12),
              Text(
                "Berhasil!",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    });
  }

  // Proses absen
  Future<void> _handleAbsen() async {
    setState(() => _isAbsenLoading = true);

    final result = await _apiService.submitAbsen(
      latitude: _dummyLatitude,
      longitude: _dummyLongitude,
    );

    setState(() => _isAbsenLoading = false);

    if (result != null && result.containsKey('status') && result['status'] == '200') {
      final data = result['data'];
      final isLate = data['is_late'] as String?;
      final jenis = isLate == 'Terlambat' ? 'Terlambat' : 'Tepat Waktu';

      _showSuccessDialog(
        '${result['message']}\nWaktu: ${data['waktu_absen']} ($jenis)',
      );
    } else {
      _showSnackBar(result?['error'] ?? 'Absen gagal.');
    }
  }

  // Logout
  Future<void> _handleLogout() async {
    await _apiService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateDisplay = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
    final timeDisplay = DateFormat('HH:mm:ss').format(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Halaman Absensi'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _isAbsenLoading ? null : _handleLogout,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Kartu Informasi Waktu
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('Waktu Saat Ini', style: TextStyle(fontSize: 18, color: Colors.blue)),
                      const SizedBox(height: 8),
                      Text(dateDisplay, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        timeDisplay,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                "Tekan tombol di bawah untuk melakukan Absensi (Masuk atau Pulang).",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),

              const SizedBox(height: 20),

              // Tombol Absen
              _isAbsenLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleAbsen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        "ABSEN SEKARANG",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),

              const SizedBox(height: 40),

              // Debug lokasi
              Text(
                'Lokasi Dummy:\nLat: $_dummyLatitude\nLong: $_dummyLongitude',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
