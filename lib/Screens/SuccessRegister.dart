import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:safe_spend/navigation.dart';
 // adjust path if needed

class SuccessRegister extends StatefulWidget {
  const SuccessRegister({super.key});

  @override
  State<SuccessRegister> createState() => _SuccessRegisterState();
}

class _SuccessRegisterState extends State<SuccessRegister> {
  @override
  void initState() {
    super.initState();
    // Navigate to BottomNavScreen after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) =>  BottomNavScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- Lottie Animation ---
                Lottie.asset(
                  'assets/Success.json',
                  repeat: false,
                ),
                const SizedBox(height: 40),
                const Text(
                  'Registration Successful!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
