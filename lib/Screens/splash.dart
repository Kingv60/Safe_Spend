import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../Auth/login.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this);

    // Navigate to Login after 5 seconds (you can keep or adjust)
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset(
          'assets/startupanimation.json',
          controller: _controller,
          repeat: false,
          onLoaded: (composition) {
            // ✅ Play animation at 0.5x duration (twice as fast)
            _controller
              ..duration = composition.duration * 0.5
              ..forward();
          },
        ),
      ),
    );
  }
}
