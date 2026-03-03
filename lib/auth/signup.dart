import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Added this
import '../routes.dart';
import 'package:flutter_app/config/config.dart';

const String baseUrl = AppConfig.baseUrl;

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  bool _obscurePassword = true; 
  bool _isLoading = false;

  // --- HELPER TO HANDLE SUCCESSFUL DJANGO RESPONSE ---
  Future<void> _handleDjangoSignupResponse(http.Response response) async {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);

      if (data.containsKey('key') && data['key'] != null) {
         final prefs = await SharedPreferences.getInstance();
         await prefs.setString('auth_token', data['key']);
         
         if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Account Created & Logged In!"))
           );
           Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
         }
      } else {
         if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Account Created! Please Log In."))
           );
           Navigator.pushNamed(context, AppRoutes.login);
         }
      }
    } else {
      throw Exception("Signup Failed: ${response.body}");
    }
  }

  // --- EMAIL SIGNUP LOGIC ---
  Future<void> sendData() async {
    setState(() => _isLoading = true);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await userCredential.user!.updateDisplayName(
        "${firstNameController.text.trim()} ${lastNameController.text.trim()}",
      );

      String? idToken = await userCredential.user!.getIdToken();

      final response = await http.post(
        Uri.parse("$baseUrl/api/signup/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id_token": idToken,
          "first_name": firstNameController.text.trim(),
          "last_name": lastNameController.text.trim(),
        }),
      );

      await _handleDjangoSignupResponse(response);
    } catch (e) {
      debugPrint("Error: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // --- GOOGLE SIGNUP LOGIC ---
  Future<void> signupWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; 
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      String? idToken = await userCredential.user!.getIdToken();

      // Extract first and last name from Google Profile safely
      List<String> names = (googleUser.displayName ?? "").trim().split(" ");
      String firstName = names.isNotEmpty ? names.first : "Google";
      String lastName = names.length > 1 ? names.sublist(1).join(" ") : "User";

      final response = await http.post(
        Uri.parse("$baseUrl/api/signup/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id_token": idToken,
          "first_name": firstName,
          "last_name": lastName,
        }),
      );

      await _handleDjangoSignupResponse(response);
    } catch (e) {
      debugPrint("Google Signup Error: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Google Signup Error: $e")));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
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
              height: 180,
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
                    top: -40, left: -40,
                    child: const CircleAvatar(radius: 90, backgroundColor: Color(0xFFDCC169)),
                  ),
                  Positioned(
                    bottom: -30, right: -30,
                    child: const CircleAvatar(radius: 70, backgroundColor: Color(0xFF8AD3B5)),
                  ),
                  const SafeArea(
                    child: Center(
                      child: Text(
                        "Create an\naccount",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// FORM BODY
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
              child: Column(
                children: [

                  /// GOOGLE BUTTON
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
                        const Text(
                          "Sign in with Google",
                          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
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

                  Row(
                    children: [
                      Expanded(child: _buildTextField(firstNameController, "First Name")),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(lastNameController, "Last Name")),
                    ],
                  ),

                  const SizedBox(height: 15),

                  _buildTextField(emailController, "Email"),

                  const SizedBox(height: 15),

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
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// CREATE ACCOUNT BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : sendData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const SizedBox(
                            height: 20, width: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : const Text("Create account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Signing up means you agree to the Privacy Policy and Terms of Service.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.login);
                        },
                        child: const Text("Log in here", style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
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

  static Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}