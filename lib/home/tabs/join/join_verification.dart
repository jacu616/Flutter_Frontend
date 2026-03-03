import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../routes.dart';

class JoinVerificationPage extends StatefulWidget {
  const JoinVerificationPage({super.key});

  @override
  State<JoinVerificationPage> createState() => _JoinVerificationPageState();
}

class _JoinVerificationPageState extends State<JoinVerificationPage> {
  // Theme Color
  final Color _themeYellow = const Color(0xFFFFD54F);

  // Data to pass forward
  Map<String, dynamic>? _tripData;

  // Controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _phoneOtpController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _emailOtpController = TextEditingController();

  // Verification Flags
  bool _isPhoneSent = false;
  bool _isPhoneVerified = false;
  bool _isEmailSent = false;
  bool _isEmailVerified = false;
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Retrieve the data passed from TripJoinPage
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _tripData = args;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneOtpController.dispose();
    _emailController.dispose();
    _emailOtpController.dispose();
    super.dispose();
  }

  // --- Logic Methods ---

  void _sendPhoneOtp() {
    if (_phoneController.text.length != 10) {
      _showError("Please enter a valid 10-digit number.");
      return;
    }
    setState(() => _isPhoneSent = true);
    _showSuccess("OTP sent to +91 ${_phoneController.text}");
  }

  void _verifyPhoneOtp() {
    if (_phoneOtpController.text.length != 4) {
      _showError("Enter valid 4-digit OTP");
      return;
    }
    setState(() => _isPhoneVerified = true);
    _showSuccess("Phone verified successfully!");
  }

  void _sendEmailOtp() {
    if (!_emailController.text.contains('@')) {
      _showError("Please enter a valid email.");
      return;
    }
    setState(() => _isEmailSent = true);
    _showSuccess("OTP sent to ${_emailController.text}");
  }

  void _verifyEmailOtp() {
    if (_emailOtpController.text.length != 4) {
      _showError("Enter valid 4-digit OTP");
      return;
    }
    setState(() => _isEmailVerified = true);
    _showSuccess("Email verified successfully!");
  }

  Future<void> _handleSubmit() async {
    if (!_isPhoneVerified || !_isEmailVerified) {
      _showError("Please verify both phone and email first");
      return;
    }

    if (_tripData == null) {
      _showError("Error: Trip data missing. Please try again.");
      return;
    }

    setState(() => _isSubmitting = true);

    // Simulate API call processing
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      // We pass the ENTIRE _tripData map forward, so JoinPaymentPage has details
      Navigator.pushReplacementNamed(
        context, 
        AppRoutes.joinPayment,
        arguments: _tripData 
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), 
        backgroundColor: _themeYellow,
      ),
    );
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    bool canSubmit = _isPhoneVerified && _isEmailVerified;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Verify Contact",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "One Last Step",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Verify your contact details to proceed to payment.",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              
              const SizedBox(height: 40),

              /// Phone Section
              _buildSectionHeader(Icons.phone_iphone, "Phone Number"),
              const SizedBox(height: 16),
              _buildPhoneInput(),
              
              if (_isPhoneSent && !_isPhoneVerified) ...[
                const SizedBox(height: 16),
                _buildOtpInput(_phoneOtpController, _verifyPhoneOtp),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Divider(color: Color(0xFFEEEEEE), thickness: 1),
              ),

              /// Email Section
              _buildSectionHeader(Icons.email_outlined, "Email Address"),
              const SizedBox(height: 16),
              _buildEmailInput(),

              if (_isEmailSent && !_isEmailVerified) ...[
                const SizedBox(height: 16),
                _buildOtpInput(_emailOtpController, _verifyEmailOtp),
              ],

              const SizedBox(height: 50),

              /// Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: canSubmit ? _handleSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSubmit ? Colors.black : Colors.grey[300],
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          "Verify & Continue",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
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
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.black),
        ),
        const SizedBox(width: 12),
        Text(
          title, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildPhoneInput() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: const Text(
            "+91", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
          ),
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
              hintText: "10-digit number",
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: const Color(0xFFF9F9F9),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.black),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        if (_isPhoneVerified)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          )
        else
          InkWell(
            onTap: _isPhoneSent ? null : _sendPhoneOtp,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                "Send",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmailInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isEmailVerified,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: "Enter email address",
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: const Color(0xFFF9F9F9),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.black),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        if (_isEmailVerified)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          )
        else
          InkWell(
            onTap: _isEmailSent ? null : _sendEmailOtp,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                "Send",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOtpInput(TextEditingController controller, VoidCallback onVerify) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 4),
            decoration: InputDecoration(
              hintText: "OTP",
              hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 0),
              filled: true,
              fillColor: _themeYellow.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _themeYellow),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _themeYellow.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _themeYellow, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: onVerify,
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          child: const Text(
            "Verify",
            style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }
}