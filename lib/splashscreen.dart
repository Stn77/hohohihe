import 'package:flutter/material.dart';
import '../pages/login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        /// 👇 Warna RGB Biru
        color: const Color.fromARGB(255, 0, 183, 255),

        child: Center(
          child: Image.asset(
            "assets/images/logo.png",
            width: 170,
            height: 170,
          ),
        ),
      ),
    );
  }
}
