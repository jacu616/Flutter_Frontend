import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../routes.dart';
import 'package:flutter_app/config/config.dart';

const String baseUrl = AppConfig.baseUrl;
final _supabase = Supabase.instance.client;
const String _oauthRedirectUrl = 'io.supabase.tqmrytzypqsuxjwdrihh://login-callback';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscurePassword       = true;
  bool _isLoading             = false;
  bool _googleCallbackHandled = false;  // prevents duplicate calls

  @override
  void initState() {
    super.initState();
    _googleCallbackHandled = false;
  }

  Future<void> _handleDjangoLoginResponse(http.Response response) async {
    if (response.statusCode == 200) {
      final data  = jsonDecode(response.body);
      final token = data['key'];
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        if (data['user_id'] != null) await prefs.setInt('user_id', data['user_id']);
        if (data['first_name'] != null) await prefs.setString('first_name', data['first_name']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login Successful!')),
          );
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No token received')),
        );
      }
    } else {
      throw Exception('Login Failed: ${response.body}');
    }
  }

  Future<void> _postToDjango(String accessToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'access_token': accessToken}),
    );
    await _handleDjangoLoginResponse(response);
  }

  // ── EMAIL LOGIN ───────────────────────────────────────────────────────────
  Future<void> loginUser() async {
    final email    = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email:    email,
        password: password,
      );

      if (res.session == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please verify your email before logging in.')),
        );
        return;
      }

      await _postToDjango(res.session!.accessToken);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auth error: ${e.message}')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── GOOGLE LOGIN ──────────────────────────────────────────────────────────
  Future<void> loginWithGoogle() async {
    setState(() {
      _isLoading             = true;
      _googleCallbackHandled = false;
    });

    try {
      // 1. Listener BEFORE opening browser
      final sub = _supabase.auth.onAuthStateChange.listen((data) async {
        if (data.event == AuthChangeEvent.signedIn &&
            data.session != null &&
            !_googleCallbackHandled) {
          _googleCallbackHandled = true;
          await _postToDjango(data.session!.accessToken);
        }
      });
      Future.delayed(const Duration(minutes: 3), sub.cancel);

      // 2. Open Google — force account picker every time
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo:   _oauthRedirectUrl,
        queryParams: {'prompt': 'select_account'},
      );
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google error: ${e.message}')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── FORGOT PASSWORD ───────────────────────────────────────────────────────
  Future<void> _forgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email above first.')),
      );
      return;
    }
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 280, width: double.infinity,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE88B60), Color(0xFFD96548)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30),
                ),
              ),
              child: Stack(
                children: [
                  const Positioned(top: -40, left: -40,
                    child: CircleAvatar(radius: 90, backgroundColor: Color(0xFFDCC169))),
                  const Positioned(bottom: -30, right: -30,
                    child: CircleAvatar(radius: 70, backgroundColor: Color(0xFF8AD3B5))),
                  const SafeArea(
                    child: Center(
                      child: Text('Login Here',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                            color: Colors.white, height: 1.2)),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
              child: Column(
                children: [
                  OutlinedButton(
                    onPressed: _isLoading ? null : loginWithGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      side: const BorderSide(color: Colors.grey, width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/google.webp', height: 24, width: 24),
                        const SizedBox(width: 8),
                        const Text('Sign in with Google',
                            style: TextStyle(color: Colors.black87, fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),
                  const Row(children: [
                    Expanded(child: Divider()),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('or', style: TextStyle(color: Colors.grey))),
                    Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 25),

                  _buildTextField(emailController, 'Email'),
                  const SizedBox(height: 15),

                  TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Password', filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined, color: Colors.grey),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : loginUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Log In',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _forgotPassword,
                    child: const Text('Request a New Password',
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline)),
                  ),
                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('New here? '),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, AppRoutes.signup),
                        child: const Text('Create an account',
                            style: TextStyle(fontWeight: FontWeight.bold,
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

  static Widget _buildTextField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label, filled: true, fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}