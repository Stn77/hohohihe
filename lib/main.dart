// PENTING: Pastikan Anda telah menambahkan 'http', 'shared_preferences', 'intl'
// DAN 'flutter_localizations' di file pubspec.yaml Anda sebelum menjalankan kode ini.

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
// Import tambahan untuk mengatasi LocalDataException
import 'package:intl/date_symbol_data_local.dart';
// Import BARU untuk mengatasi error No MaterialLocalizations found
import 'package:flutter_localizations/flutter_localizations.dart';

// --- KONSTANTA DAN KONFIGURASI APLIKASI ---
// PENTING: Ganti BASE_URL sesuai lingkungan Anda.
// IP 10.189.24.152:8001 adalah IP host/docker Anda (Baik untuk Chrome/Linux/iOS)
// Jika menggunakan Android Emulator, ubah menjadi 'http://10.0.2.2:8001/api'
const String _kBaseUrl = 'http://192.168.9.75:8001/api'; 
const String _kTokenKey = 'authToken';

Future<void> main() async {
  // Wajib dipanggil sebelum runApp()
  WidgetsFlutterBinding.ensureInitialized();
  
  // Mengatasi LocalDataException dengan menginisialisasi data locale Indonesia
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    // Menangani error jika inisialisasi gagal, biasanya aman diabaikan jika gagal
    print("Gagal menginisialisasi locale data: $e");
  }

  runApp(const MyApp());
}

// --- SERVICE LOKAL (SharedPreferences) ---
class SharedPreferencesService {
  static late SharedPreferences _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> setToken(String token) async {
    await _prefs.setString(_kTokenKey, token);
  }

  static String? getToken() {
    return _prefs.getString(_kTokenKey);
  }

  static Future<void> clearToken() async {
    await _prefs.remove(_kTokenKey);
  }
}

// --- SERVICE API (Koneksi ke Laravel) ---
class ApiService {
  final String baseUrl = _kBaseUrl;

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/absen/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Asumsi 'token' ada di body response
        final token = responseBody['token'] as String?;
        if (token != null) {
          await SharedPreferencesService.setToken(token);
        }
        return responseBody;
      } else {
        return {'error': responseBody['message'] ?? 'Login Gagal. Silakan cek kredensial.'};
      }
    } catch (e) {
      return {'error': 'Gagal terhubung ke server. Pastikan Laravel berjalan di $baseUrl. Error: $e'};
    }
  }

  Future<Map<String, dynamic>?> logout() async {
    final token = SharedPreferencesService.getToken();
    final url = Uri.parse('$baseUrl/absen/logout');

    if (token == null) {
      await SharedPreferencesService.clearToken();
      return {'message': 'Token tidak ada. Logout sukses (lokal).'};
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      await SharedPreferencesService.clearToken();

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseBody;
      } else {
        // Walaupun gagal di sisi server, kita tetap hapus token lokal
        return {'message': responseBody['message'] ?? 'Logout berhasil (tetapi ada error server sebelumnya).'};
      }
    } catch (e) {
      // Jika terjadi error koneksi, tetap hapus token lokal
      await SharedPreferencesService.clearToken();
      return {'message': 'Gagal terhubung ke server saat logout. Token dihapus (lokal).'};
    }
  }

  Future<Map<String, dynamic>?> submitAbsen({
    required String latitude,
    required String longitude,
  }) async {
    final token = SharedPreferencesService.getToken();
    if (token == null) {
      return {'error': 'Tidak ada sesi. Silakan Login ulang.'};
    }

    // Mendapatkan data waktu saat ini
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm:ss').format(now);
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    // Menggunakan bahasa Inggris untuk hari sesuai permintaan API Laravel
    final dayStr = DateFormat('EEEE', 'en_US').format(now); 

    final url = Uri.parse('$baseUrl/absen/submit');

    final body = jsonEncode({
      'latitude': latitude,
      'longitude': longitude,
      'time': timeStr,
      'hari': dayStr,
      'tanggal': dateStr,
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseBody;
      } else {
        // Coba tangkap error 401 Unauthorized dari Laravel (jika token kadaluarsa)
        if (response.statusCode == 401) {
            return {'error': 'Akses tidak sah. Silakan Login ulang. Pesan server: ${responseBody['message'] ?? responseBody.toString()}'};
        }
        return {'error': responseBody['message'] ?? 'Absen Gagal. Status Code: ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': 'Gagal koneksi saat Absen. Error: $e'};
    }
  }
}

// --- WIDGET UTAMA (App dan Wrapper) ---

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Absensi Flutter',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      // --- PENAMBAHAN UNTUK FIX LOKALISASI START ---
      // Delegasi yang memuat terjemahan string standar Material dan Widget
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, // Opsional: untuk komponen iOS
      ],
      // --- PENAMBAHAN UNTUK FIX LOKALISASI END ---
      
      // Atur locale default ke Indonesia
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('id', 'ID'),
      ],
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<bool> _checkAuthStatus() async {
    await SharedPreferencesService.initialize();
    return SharedPreferencesService.getToken() != null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAuthStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return const HomePage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

// --- HALAMAN LOGIN ---

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.teal,
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Email dan Password harus diisi.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _apiService.login(
      _emailController.text,
      _passwordController.text,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result != null && result.containsKey('token')) {
        _showSnackBar('Login Berhasil!');
        // Navigasi ke HomePage dan hapus semua rute sebelumnya
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (Route<dynamic> route) => false,
        );
      } else if (result != null && result.containsKey('error')) {
        _showSnackBar(result['error']!, isError: true);
      } else {
        _showSnackBar('Login Gagal. Terjadi kesalahan tak terduga.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi App - Login'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Icon(
                Icons.fingerprint,
                size: 80,
                color: Colors.teal,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'MASUK',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
              const SizedBox(height: 20),
              const Text(
                'Gunakan kredensial yang terdaftar di Laravel Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- HALAMAN UTAMA (ABSENSI) ---

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  bool _isAbsenLoading = false;

  // Data Absensi Dummy (Karena diminta diisi manual)
  final String _dummyLatitude = "-6.200000";
  final String _dummyLongitude = "106.816666"; // Contoh Lokasi Jakarta

  void _showSnackBar(String message, {Color color = Colors.teal}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleAbsen() async {
    setState(() {
      _isAbsenLoading = true;
    });

    final result = await _apiService.submitAbsen(
      latitude: _dummyLatitude,
      longitude: _dummyLongitude,
    );

    if (mounted) {
      setState(() {
        _isAbsenLoading = false;
      });

      if (result != null && result.containsKey('status') && result['status'] == '200') {
        final data = result['data'];
        // Pastikan cek untuk 'is_late' null sebelum mengaksesnya
        final isLate = data['is_late'] as String?;
        final jenisAbsen = isLate == 'Terlambat' ? 'Terlambat' : 'Tepat Waktu';
        final message =
            '${result['message']}\nWaktu: ${data['waktu_absen']} (${jenisAbsen})';

        // Tentukan warna SnackBar berdasarkan status terlambat
        Color color = Colors.teal.shade700;
        if (isLate == 'Terlambat') {
          color = Colors.orange.shade700;
        } else if (isLate == 'Tepat Waktu') {
          color = Colors.green.shade700;
        }

        _showSnackBar(message, color: color);
      } else if (result != null && result.containsKey('error')) {
        _showSnackBar(result['error']!, color: Colors.red.shade700);
      } else {
        _showSnackBar('Absen Gagal. Kesalahan tak terduga.', color: Colors.red.shade700);
      }
    }
  }

  Future<void> _handleLogout() async {
    setState(() {
      _isAbsenLoading = true;
    });

    final result = await _apiService.logout();

    if (mounted) {
      setState(() {
        _isAbsenLoading = false;
      });

      if (result != null) {
        _showSnackBar('Logout Berhasil: ${result['message']}', color: Colors.blueGrey);
      }
      // Navigasi ke LoginPage dan hapus semua rute sebelumnya
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Menampilkan hari dan tanggal saat ini
    final now = DateTime.now();
    // Menggunakan locale id_ID yang sudah diinisialisasi di main
    final dateDisplay = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
    final timeDisplay = DateFormat('HH:mm:ss').format(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Halaman Absensi'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _isAbsenLoading ? null : _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text(
                        'Waktu Saat Ini',
                        style: TextStyle(fontSize: 18, color: Colors.teal),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dateDisplay,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeDisplay, // Ini akan statis, Anda bisa membuatnya dinamis dengan Timer jika perlu
                        style: const TextStyle(
                            fontSize: 36, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Tekan tombol di bawah untuk melakukan Absensi (Masuk atau Pulang).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              _isAbsenLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleAbsen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        'ABSEN SEKARANG',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
              const SizedBox(height: 40),
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
