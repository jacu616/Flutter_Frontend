import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/config/config.dart';
import '../../../routes.dart';

class JoinVerificationPage extends StatefulWidget {
  const JoinVerificationPage({super.key});

  @override
  State<JoinVerificationPage> createState() => _JoinVerificationPageState();
}

class _JoinVerificationPageState extends State<JoinVerificationPage> {
  final Color _themeYellow = const Color(0xFFFFD54F);

  Map<String, dynamic>? _tripData;

  final TextEditingController _phoneController    = TextEditingController();
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _emailOtpController = TextEditingController();

  bool _isPhoneVerified  = false;
  bool _isEmailSending   = false;
  bool _isEmailSent      = false;
  bool _isEmailVerifying = false;
  bool _isEmailVerified  = false;
  bool _isSubmitting     = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) _tripData = args;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _emailOtpController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // ── Phone — auto verified ─────────────────────────────────────────────────
  void _verifyPhone() {
    if (_phoneController.text.length != 10) {
      _showError('Please enter a valid 10-digit number.');
      return;
    }
    setState(() => _isPhoneVerified = true);
    _showSuccess('Phone number saved ✓');
  }

  // ── Email OTP ─────────────────────────────────────────────────────────────
  Future<void> _sendEmailOtp() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      _showError('Please enter a valid email.');
      return;
    }
    setState(() => _isEmailSending = true);
    try {
      final token    = await _getToken();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/otp/send/'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200) {
        setState(() => _isEmailSent = true);
        _showSuccess('OTP sent to $email');
      } else {
        _showError('Failed to send OTP. Try again.');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isEmailSending = false);
    }
  }

  Future<void> _verifyEmailOtp() async {
    final email = _emailController.text.trim();
    final otp   = _emailOtpController.text.trim();
    if (otp.length != 6) {
      _showError('Enter the 6-digit OTP.');
      return;
    }
    setState(() => _isEmailVerifying = true);
    try {
      final token    = await _getToken();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/otp/verify/'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({'email': email, 'otp': otp}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['verified'] == true) {
        setState(() => _isEmailVerified = true);
        _showSuccess('Email verified ✓');
      } else {
        _showError(data['error'] ?? 'Incorrect OTP.');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isEmailVerifying = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (_tripData == null) {
      _showError('Error: Trip data missing.');
      return;
    }
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.joinPayment,
        arguments: _tripData,
      );
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFFFFD54F)));

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canSubmit = _isPhoneVerified && _isEmailVerified;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verify Contact',
            style:
                TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('One Last Step',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      height: 1.1)),
              const SizedBox(height: 8),
              Text('Verify your contact details to proceed to payment.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 40),

              // ── Phone ─────────────────────────────────────────────────────
              _buildSectionHeader(Icons.phone_iphone, 'Phone Number'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: const Text('+91',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !_isPhoneVerified,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: '10-digit number',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFFF9F9F9),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFEEEEEE))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Colors.black)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _isPhoneVerified
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                              color: Colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 20))
                      : InkWell(
                          onTap: _verifyPhone,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                            decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(16)),
                            child: const Text('Confirm',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Divider(color: Color(0xFFEEEEEE), thickness: 1),
              ),

              // ── Email ─────────────────────────────────────────────────────
              _buildSectionHeader(Icons.email_outlined, 'Email Address'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isEmailVerified,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Enter email address',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFFF9F9F9),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFEEEEEE))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Colors.black)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _isEmailVerified
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                              color: Colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 20))
                      : InkWell(
                          onTap: (_isEmailSent || _isEmailSending)
                              ? null
                              : _sendEmailOtp,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                            decoration: BoxDecoration(
                              color: (_isEmailSent || _isEmailSending)
                                  ? Colors.grey[300]
                                  : Colors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: _isEmailSending
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('Send OTP',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                ],
              ),

              if (_isEmailSent && !_isEmailVerified) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailOtpController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 4),
                        decoration: InputDecoration(
                          hintText: 'OTP',
                          hintStyle: TextStyle(
                              color: Colors.grey[400], letterSpacing: 0),
                          filled: true,
                          fillColor: _themeYellow.withOpacity(0.1),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: _themeYellow.withOpacity(0.5))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: _themeYellow, width: 2)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _isEmailVerifying
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2))
                        : TextButton(
                            onPressed: _verifyEmailOtp,
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16)),
                            child: const Text('Verify',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration:
                                        TextDecoration.underline)),
                          ),
                  ],
                ),
              ],

              const SizedBox(height: 50),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: canSubmit ? _handleSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canSubmit ? Colors.black : Colors.grey[300],
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Verify & Continue',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: _themeYellow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 20, color: Colors.black),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black)),
      ],
    );
  }
}