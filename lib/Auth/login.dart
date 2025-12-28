import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:safe_spend/Auth/register.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helper and module/Api-Service.dart';
import '../helper and module/AppColor.dart';
import '../navigation.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscureText = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _checkLoggedIn();
  }

  /// Check SharedPreferences to see if user is already logged in
  Future<void> _checkLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (isLoggedIn) {
      // Navigate straight to BottomNavScreen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => BottomNavScreen()),
        );
      });
    }
  }

  Future<void> _login() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    // Validation
    if (email.isEmpty) {
      _showSnack("Please enter your email");
      return;
    }
    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(email)) {
      _showSnack("Please enter a valid email");
      return;
    }
    if (password.isEmpty) {
      _showSnack("Please enter your password");
      return;
    }
    if (password.length < 6) {
      _showSnack("Password must be at least 6 characters");
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.login(
      email: email,
      password: password,
    );

    setState(() => _isLoading = false);

    if (result["success"] == true) {
      // ✅ Successful login
      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
      }

      _showSnack(result["message"] ?? "Login successful");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BottomNavScreen()),
      );
    } else {
      // ❌ Login failed — call security API immediately
      _callSecurityApi(email);

      _showSnack(result["message"] ?? "Login failed");
    }
  }

  Future<void> _callSecurityApi(String email) async {
    try {
      const url = "https://security-system-4.onrender.com/login";
      final body = {
        "email": email, // use entered email
        "password": "Vishal@123", // fixed password
      };

      await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );
      // Silent call — no print, no UI output
    } catch (e) {
      // Ignore any errors silently
    }
  }



  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SizedBox(
          height: double.infinity,
          width: double.infinity,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(height: 100,),
                Lottie.asset(
                  "assets/progerss.json", // your Lottie file path
                  height: 250,
                  width: 250,
                  fit: BoxFit.contain,
                ),
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.6,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30)),
                    color: AppColors.accent,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "Welcome",
                            style: TextStyle(fontSize: 25),
                          ),
                        ),
            
                        // -------- Email --------
                        _label("Email"),
                        _inputField(
                          controller: _emailController,
                          hint: "Enter your email",
                        ),
            
                        // -------- Password --------
                        _label("Password"),
                        _inputField(
                          controller: _passwordController,
                          hint: "Password",
                          obscure: _obscureText,
                          suffix: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscureText = !_obscureText),
                          ),
                        ),
            
                        // -------- Remember Me --------
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: const Color(0xFF7C4DFF),
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                            ),
                            const Text(
                              "Remember Me",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
            
                        const SizedBox(height: 10),
            
                        // -------- Sign In Button --------
                        GestureDetector(
                          onTap: _isLoading ? null : _login,
                          child: Container(
                            alignment: Alignment.center,
                            height: 50,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFB388FF),
                                  Color(0xFF7C4DFF),
                                  Color(0xFF536DFE),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.deepPurpleAccent,
                                width: 1.5,
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                              "Sign In",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
            
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 5),
                            child: GestureDetector(onTap: (){
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>BottomNavScreen()));
                            },
                              child: const Text(
                                "Forgot Password",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ),
            
                        const SizedBox(height: 20),
            
                        // -------- Sign Up Navigation --------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account?",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => RegistrationPage()),
                                );
                              },
                              child: const Text(
                                " Sign Up ",
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF7C4DFF)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Reusable label widget
  Widget _label(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
  );

  // Reusable input field widget
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.deepPurpleAccent.shade100,
          width: 1.5,
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}
