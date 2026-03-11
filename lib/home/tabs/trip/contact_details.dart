import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/config/config.dart';
import '../../../routes.dart';

class ContactDetailsPage extends StatefulWidget {
  const ContactDetailsPage({super.key});

  @override
  State<ContactDetailsPage> createState() => _ContactDetailsPageState();
}

class _ContactDetailsPageState extends State<ContactDetailsPage> {
  int? _tripId;

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
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) _tripId = args['tripId'];
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

  // ── Phone — auto verified (no SMS) ───────────────────────────────────────
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

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _onSlideComplete() async {
    setState(() => _isSubmitting = true);
    try {
      final token = await _getToken();
      if (_tripId == null) {
        _showError('Error: Trip ID missing.');
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/savetrip/contact/'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'trip_id':           _tripId,
          'phone':             _phoneController.text,
          'email':             _emailController.text.trim(),
          'is_phone_verified': _isPhoneVerified,
          'is_email_verified': _isEmailVerified,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        _showSuccess('Trip published successfully!');
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.home, (route) => false);
      } else {
        _showError('Server Error: ${response.body}');
      }
    } catch (e) {
      _showError('Connection failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green));

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canFinalize = _isPhoneVerified && _isEmailVerified && !_isSubmitting;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Contact Details'),
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
              const Text('Verify Contact Info',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 5),
              const Text('We need to verify your details to publish the trip.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 30),

              // ── Phone ─────────────────────────────────────────────────────
              _buildSectionHeader(Icons.phone_android, 'Phone Number'),
              const SizedBox(height: 15),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 18),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(15)),
                    child: const Text('+91',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !_isPhoneVerified,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Enter 10 digit number',
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _isPhoneVerified
                      ? const Icon(Icons.check_circle,
                          color: Colors.green, size: 32)
                      : ElevatedButton(
                          onPressed: _verifyPhone,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                          ),
                          child: const Text('Confirm',
                              style: TextStyle(color: Colors.white)),
                        ),
                ],
              ),

              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 20),

              // ── Email ─────────────────────────────────────────────────────
              _buildSectionHeader(Icons.email_outlined, 'Email Address'),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isEmailVerified,
                      decoration: InputDecoration(
                        hintText: 'Enter email address',
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _isEmailVerified
                      ? const Icon(Icons.check_circle,
                          color: Colors.green, size: 32)
                      : ElevatedButton(
                          onPressed: (_isEmailSent || _isEmailSending)
                              ? null
                              : _sendEmailOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                          ),
                          child: _isEmailSending
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Send OTP',
                                  style: TextStyle(color: Colors.white)),
                        ),
                ],
              ),

              if (_isEmailSent && !_isEmailVerified) ...[
                const SizedBox(height: 15),
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
                        decoration: InputDecoration(
                          hintText: 'Enter 6-digit OTP',
                          filled: true,
                          fillColor: const Color(0xFFFFF8E1),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _isEmailVerifying
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2))
                        : TextButton(
                            onPressed: _verifyEmailOtp,
                            child: const Text('Confirm OTP',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                          ),
                  ],
                ),
              ],

              const SizedBox(height: 50),

              Center(
                child: SlideAction(
                  isActive: canFinalize,
                  onSubmit: _onSlideComplete,
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
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 16)),
      ],
    );
  }
}

// ── Slide to Confirm Widget ───────────────────────────────────────────────────

class SlideAction extends StatefulWidget {
  final bool isActive;
  final VoidCallback onSubmit;
  const SlideAction(
      {super.key, required this.isActive, required this.onSubmit});

  @override
  State<SlideAction> createState() => _SlideActionState();
}

class _SlideActionState extends State<SlideAction> {
  double _dragValue      = 0.0;
  final double _maxWidth = 300.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: widget.isActive
          ? (details) => setState(() => _dragValue =
              (_dragValue + details.delta.dx).clamp(0.0, _maxWidth - 50))
          : null,
      onHorizontalDragEnd: widget.isActive
          ? (details) {
              if (_dragValue > (_maxWidth - 60)) {
                setState(() => _dragValue = _maxWidth - 50);
                widget.onSubmit();
              } else {
                setState(() => _dragValue = 0.0);
              }
            }
          : null,
      child: Container(
        width: _maxWidth,
        height: 60,
        decoration: BoxDecoration(
          color: widget.isActive ? Colors.black : Colors.grey[300],
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                widget.isActive
                    ? 'Slide to Publish Trip'
                    : 'Verify Details First',
                style: TextStyle(
                    color: widget.isActive ? Colors.white : Colors.grey[500],
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            Positioned(
              left: _dragValue,
              top: 5,
              bottom: 5,
              child: Container(
                width: 50,
                margin: const EdgeInsets.only(left: 5),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.arrow_forward,
                    color: widget.isActive ? Colors.black : Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}