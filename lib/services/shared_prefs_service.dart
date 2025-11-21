import 'package:shared_preferences/shared_preferences.dart';

const String _kTokenKey = 'authToken';

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
