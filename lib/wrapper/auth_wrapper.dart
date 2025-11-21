import 'package:flutter/material.dart';
import '../services/shared_prefs_service.dart';
import '../pages/login_page.dart';
import '../pages/home_page.dart';

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
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == true
            ? const HomePage()
            : const LoginPage();
      },
    );
  }
}
