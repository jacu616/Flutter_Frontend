import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Added this
import '../routes.dart';
import 'package:flutter_app/config/config.dart';

const String baseUrl = AppConfig.baseUrl;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  // --- HELPER TO HANDLE SUCCESSFUL DJANGO RESPONSE ---
  Future<void> _handleDjangoLoginResponse(http.Response response) async {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String? token = data['key'];

      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Login Successful!")),
          );
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.home, (route) => false);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Error: No token received")));
        }
      }
    } else {
      throw Exception("Login Failed: ${response.body}");
    }
  }

  // --- EMAIL LOGIN LOGIC ---
  Future<void> loginUser() async {
    setState(() => _isLoading = true);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String? idToken = await userCredential.user!.getIdToken();

      final response = await http.post(
        Uri.parse("$baseUrl/api/login/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id_token": idToken}),
      );

      await _handleDjangoLoginResponse(response);
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- GOOGLE LOGIN LOGIC ---
  Future<void> loginWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled the sign-in flow
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      String? idToken = await userCredential.user!.getIdToken();

      final response = await http.post(
        Uri.parse("$baseUrl/api/login/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id_token": idToken}),
      );

      await _handleDjangoLoginResponse(response);
    } catch (e) {
      debugPrint("Google Login Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Google Login Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            /// HEADER
            Container(
              height: 280,
              width: double.infinity,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE88B60), Color(0xFFD96548)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    left: -40,
                    child: CircleAvatar(
                        radius: 90, backgroundColor: const Color(0xFFDCC169)),
                  ),
                  Positioned(
                    bottom: -30,
                    right: -30,
                    child: CircleAvatar(
                        radius: 70, backgroundColor: const Color(0xFF8AD3B5)),
                  ),
                  const SafeArea(
                    child: Center(
                      child: Text(
                        "Login Here",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// FORM BODY
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
              child: Column(
                children: [
                  /// GOOGLE LOGIN BUTTON
                  OutlinedButton(
                    onPressed: _isLoading ? null : loginWithGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      side: const BorderSide(color: Colors.grey, width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/google.webp', height: 24, width: 24),
                        const SizedBox(width: 8),
                        const Text(
                          "Sign in with Google",
                          style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text("or", style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 25),

                  /// EMAIL INPUT
                  _buildTextField(emailController, "Email"),

                  const SizedBox(height: 15),

                  /// PASSWORD INPUT
                  TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: "Password",
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : loginUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text("Log In",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Links
                  GestureDetector(
                    onTap: () {}, // Forgot password logic
                    child: const Text("Request a New Password",
                        style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline)),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("New here? "),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.signup),
                        child: const Text("Create an account",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildTextField(
      TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}