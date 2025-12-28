import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

import '../helper and module/Api-Service.dart';
import '../Screens/SuccessRegister.dart';
import '../helper and module/AppColor.dart';// import your ApiService

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  bool _obscureText = true;
  bool _isLoading = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // ApiService instance
  final ApiService _apiService = ApiService();

  void _register() async {
    // Name validation
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your name")),
      );
      return;
    }

    // Email validation
    String email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email")),
      );
      return;
    }
    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email")),
      );
      return;
    }

    // Password validation
    String password = _passwordController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your password")),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    // API call
    setState(() {
      _isLoading = true;
    });

    final result = await _apiService.register(
      name: _nameController.text.trim(),
      email: email,
      password: password,
    );

    setState(() {
      _isLoading = false;
    });

    if (result["success"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful!")),
      );
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>SuccessRegister())); // go back to login
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Registration failed")),
      );
    }
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
                SizedBox(height: 60,),
                Lottie.asset("assets/zpunet icon.json",fit: BoxFit.contain,height: 200,width: 200),
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.68,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Create Account",
                              style: TextStyle(fontSize: 25),
                            ),
                          ),
            
                          // -------- Name --------
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5.0),
                              child: Text(
                                "Name",
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          Container(
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
                              controller: _nameController,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Enter your name',
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                          ),
            
                          // -------- Email --------
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5.0),
                              child: Text(
                                "Email",
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          Container(
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
                              controller: _emailController,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Enter your email',
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ),
            
                          // -------- Password --------
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5.0),
                              child: Text(
                                "Password",
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          Container(
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
                              controller: _passwordController,
                              obscureText: _obscureText,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Enter password',
                                contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureText
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureText = !_obscureText;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter password';
                                }
                                if (value.trim().length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                          ),
            
                          const SizedBox(height: 30),
            
                          // -------- Sign Up Button --------
                          GestureDetector(
                            onTap: _isLoading ? null : _register,
                            child: Container(
                              alignment: Alignment.center,
                              height: 50,
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                  color: Colors.deepPurpleAccent.shade100,
                                  width: 1.5,
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                                  : const Text(
                                "Register",
                                style:
                                TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
            
                          const SizedBox(height: 20),
            
                          // -------- Back to Login --------
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4.0, horizontal: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Already have an account?",
                                  style: TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    " Sign In",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF7C4DFF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
}
