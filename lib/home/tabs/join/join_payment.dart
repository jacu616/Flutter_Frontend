import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/config.dart';
import '../../../routes.dart';

class JoinPaymentPage extends StatefulWidget {
  const JoinPaymentPage({super.key});

  @override
  State<JoinPaymentPage> createState() => _JoinPaymentPageState();
}

class _JoinPaymentPageState extends State<JoinPaymentPage> {
  // Theme Color
  final Color _themeYellow = const Color(0xFFFFD54F);
  
  Map<String, dynamic>? _tripData;
  bool _isLoadingData = true;
  bool _isProcessing = false;
  String _paymentMethod = "upi";

  // Controllers
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tripData == null) {
      _loadArguments();
    }
  }

  void _loadArguments() {
    // We expect the arguments to be the Trip Map (id, price, destination, etc.)
    final args = ModalRoute.of(context)?.settings.arguments;
    
    if (args is Map<String, dynamic>) {
      setState(() {
        _tripData = args;
        _isLoadingData = false;
      });
    } else {
      // Fallback if something went wrong in previous screens
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _handlePayAndJoin() async {
    if (_tripData == null) return;

    setState(() => _isProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      // Ensure we have the ID. 'id' is standard, but check 'trip_id' just in case.
      final tripId = _tripData!['id'] ?? _tripData!['trip_id'];

      // --- API CALL TO BACKEND ---
      final response = await http.post(
        Uri.parse("${AppConfig.baseUrl}/api/trips/join/confirm/"),
        headers: {
          "Authorization": "Token $token",
          "Content-Type": "application/json",
        },
        body: json.encode({
          "trip_id": tripId,
          "payment_method": _paymentMethod,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (mounted) {
          // --- REDIRECT TO SUCCESS PAGE ---
          // We pass 'next_route' and 'route_args' so SuccessPage knows where to go next.
          Navigator.pushNamed(
            context, 
            AppRoutes.success, 
            arguments: {
              'next_route': AppRoutes.groupChat,
              'route_args': {
                'group_id': data['group_id'],     // From Backend Response
                'group_name': data['group_name'], // From Backend Response
                'trip_destination': data['destination'],
                // Pass admin_id if available in _tripData for the border logic in chat
                'admin_id': _tripData!['user_id'] ?? 0 
              }
            }
          );
        }
      } else {
        final error = json.decode(response.body);
        _showError(error['error'] ?? "Failed to join trip");
      }
    } catch (e) {
      _showError("Connection error: $e");
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    if (_tripData == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text("Error: Trip details missing")),
      );
    }

    // Safely extract data for display
    final destination = _tripData!['destination'] ?? "Trip";
    final startTime = _tripData!['start_date'] ?? "Soon";
    final rawPrice = _tripData!['price']?.toString().replaceAll('₹', '') ?? "0";
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Confirm Payment", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    // --- 1. Trip Recap Card ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destination,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time_filled, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                startTime,
                                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildWarningBadge(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // --- 2. Amount Display ---
                    Center(
                      child: Column(
                        children: [
                          const Text("Total Payable", style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            "₹$rawPrice",
                            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.black),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // --- 3. Payment Method Tabs ---
                    const Text("Select Payment Method", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          _buildTabButton("UPI", "upi"),
                          _buildTabButton("Card", "card"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- 4. Dynamic Inputs ---
                    if (_paymentMethod == 'upi') _buildUpiSection()
                    else _buildCardSection(),

                  ],
                ),
              ),
            ),

            // --- 5. Pay Button ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _handlePayAndJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isProcessing
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          "Pay ₹$rawPrice",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildWarningBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Text(
            "Cancellation closes soon", 
            style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12)
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, String value) {
    bool isSelected = _paymentMethod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _customTextField(
          label: "Enter UPI ID", 
          hint: "e.g. mobile@upi", 
          controller: _upiController,
          icon: Icons.qr_code
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _themeYellow.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: Colors.black54),
              SizedBox(width: 8),
              Expanded(child: Text("Verification will happen instantly.", style: TextStyle(fontSize: 12, color: Colors.black54))),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildCardSection() {
    return Column(
      children: [
        _customTextField(
          label: "Card Number", 
          hint: "XXXX XXXX XXXX XXXX", 
          controller: _cardNumberController,
          icon: Icons.credit_card,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16)],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _customTextField(
                label: "Expiry Date", 
                hint: "MM/YY", 
                controller: _expiryController,
                inputFormatters: [LengthLimitingTextInputFormatter(5)],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _customTextField(
                label: "CVV", 
                hint: "123", 
                controller: _cvvController,
                icon: Icons.lock_outline,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _customTextField({
    required String label, 
    required String hint, 
    required TextEditingController controller,
    IconData? icon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            suffixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}