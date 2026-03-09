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

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController emailController     = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController  = TextEditingController();
  final TextEditingController passwordController  = TextEditingController();

  bool _obscurePassword       = true;
  bool _isLoading             = false;
  bool _googleCallbackHandled = false;  // prevents duplicate calls

  @override
  void initState() {
    super.initState();
    _googleCallbackHandled = false;
  }

  Future<void> _registerWithDjango({
    required String accessToken,
    required String firstName,
    required String lastName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/signup/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'access_token': accessToken,
        'first_name':   firstName,
        'last_name':    lastName,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data.containsKey('key') && data['key'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['key']);
        if (data['user_id'] != null) await prefs.setInt('user_id', data['user_id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created & logged in!')),
          );
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
        }
      } else {
        if (mounted) Navigator.pushNamed(context, AppRoutes.login);
      }
    } else {
      throw Exception('Django error: ${response.body}');
    }
  }

  void _showEmailVerificationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_unread_outlined, color: Color(0xFFD96548)),
            SizedBox(width: 8),
            Text('Verify your email'),
          ],
        ),
        content: Text(
          'We sent a confirmation link to:\n\n$email\n\n'
          'Click the link in that email, then come back and log in.',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await _supabase.auth.resend(type: OtpType.signup, email: email);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Verification email resent!')),
                );
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not resend: $e')),
                );
              }
            },
            child: const Text('Resend email'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.login);
            },
            child: const Text('Go to login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── EMAIL SIGNUP ──────────────────────────────────────────────────────────
  Future<void> sendData() async {
    final email     = emailController.text.trim();
    final password  = passwordController.text.trim();
    final firstName = firstNameController.text.trim();
    final lastName  = lastNameController.text.trim();

    if (email.isEmpty || password.isEmpty || firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final AuthResponse res = await _supabase.auth.signUp(
        email:    email,
        password: password,
        data: {'first_name': firstName, 'last_name': lastName},
      );

      if (res.session == null) {
        if (mounted) _showEmailVerificationDialog(email);
        return;
      }

      await _registerWithDjango(
        accessToken: res.session!.accessToken,
        firstName:   firstName,
        lastName:    lastName,
      );
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

  // ── GOOGLE SIGNUP ─────────────────────────────────────────────────────────
  Future<void> signupWithGoogle() async {
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
          final meta      = _supabase.auth.currentUser?.userMetadata ?? {};
          final fullName  = (meta['full_name'] ?? meta['name'] ?? '') as String;
          final parts     = fullName.trim().split(' ');
          final firstName = parts.isNotEmpty ? parts.first : 'Google';
          final lastName  = parts.length > 1  ? parts.sublist(1).join(' ') : 'User';

          await _registerWithDjango(
            accessToken: data.session!.accessToken,
            firstName:   firstName,
            lastName:    lastName,
          );
        }
      });
      Future.delayed(const Duration(minutes: 3), sub.cancel);

      // 2. Open Google — force account picker every time
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo:  _oauthRedirectUrl,
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

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 180, width: double.infinity,
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
                      child: Text('Create an\naccount',
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
                    onPressed: _isLoading ? null : signupWithGoogle,
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

                  Row(
                    children: [
                      Expanded(child: _buildTextField(firstNameController, 'First Name')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(lastNameController, 'Last Name')),
                    ],
                  ),
                  const SizedBox(height: 15),
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
                      onPressed: _isLoading ? null : sendData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Create account',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Signing up means you agree to the Privacy Policy and Terms of Service.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Have an account? '),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, AppRoutes.login),
                        child: const Text('Log in here',
                            style: TextStyle(fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
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