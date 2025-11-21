import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'shared_prefs_service.dart';

// GANTI sesuai server kamu
const String _kBaseUrl = 'http://192.168.9.75:8001/api';

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
        final token = responseBody['token'] as String?;
        if (token != null) {
          await SharedPreferencesService.setToken(token);
        }
        return responseBody;
      }

      return {'error': responseBody['message'] ?? 'Login gagal.'};
    } catch (e) {
      return {'error': 'Gagal terhubung ke server: $e'};
    }
  }

  Future<Map<String, dynamic>?> submitAbsen({
    required String latitude,
    required String longitude,
  }) async {
    final token = SharedPreferencesService.getToken();
    if (token == null) return {'error': 'Silakan login ulang.'};

    final now = DateTime.now();
    final url = Uri.parse('$baseUrl/absen/submit');

    final body = jsonEncode({
      'latitude': latitude,
      'longitude': longitude,
      'time': DateFormat('HH:mm:ss').format(now),
      'tanggal': DateFormat('yyyy-MM-dd').format(now),
      'hari': DateFormat('EEEE', 'en_US').format(now),
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

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Gagal koneksi: $e'};
    }
  }

  Future<Map<String, dynamic>?> logout() async {
    final token = SharedPreferencesService.getToken();
    await SharedPreferencesService.clearToken();
    if (token == null) return {'message': 'Token tidak ada.'};

    final url = Uri.parse('$baseUrl/absen/logout');

    try {
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'message': 'Logout lokal, server tidak terhubung.'};
    }
  }
}
