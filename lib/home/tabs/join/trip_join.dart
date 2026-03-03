import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../routes.dart';

class TripJoinPage extends StatefulWidget {
  final Map<String, dynamic>? trip;

  const TripJoinPage({super.key, this.trip});

  @override
  State<TripJoinPage> createState() => _TripJoinPageState();
}

class _TripJoinPageState extends State<TripJoinPage> {
  late Map<String, dynamic> _tripData;
  bool isLoading = true;
  bool isJoining = false;
  bool hasUserJoined = false;
  
  int _peopleNeeded = 0;
  int _maxCapacity = 0;
  int _peopleAlready = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    Map<String, dynamic>? data = widget.trip;
    
    if (data == null) {
      await Future.delayed(Duration.zero);
      if (!mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        data = args;
      }
    }

    _tripData = data ?? {
      'id': 0,
      'destination': 'Unknown Destination',
      'start_date': 'Date not set',
      'vehicle': 'Unknown Vehicle',
      'price': '0',
      'people_needed': 0,
      'max_capacity': 0,
      'people_already': 0,
      'driver_name': 'Unknown Driver',
      'user_id': 0, 
      'is_joined': false, 
      'members_list': [], // Safely handle if members array is passed
    };

    // --- CHECK LOCAL USER IDENTITY ---
    final prefs = await SharedPreferences.getInstance();
    var storedId = prefs.get('user_id');
    int myId = 0;
    if (storedId is int) myId = storedId;
    else if (storedId is String) myId = int.tryParse(storedId) ?? 0;

    // --- ROBUST CHECK: IS USER ALREADY REGISTERED? ---
    // 1. Are they the host?
    bool isHost = _tripData['user_id'].toString() == myId.toString();
    
    // 2. Did the backend explicitly say they joined?
    bool isBackendFlagTrue = _tripData['is_joined'] == true;
    
    // 3. Is their ID inside the members_list array? (Bulletproof fallback)
    List<dynamic> members = _tripData['members_list'] ?? _tripData['registered_users'] ?? [];
    bool isInMembersList = members.any((id) => id.toString() == myId.toString());

    bool isAlreadyJoined = isHost || isBackendFlagTrue || isInMembersList;

    // Simulate short loading
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (mounted) {
      setState(() {
        hasUserJoined = isAlreadyJoined;
        
        _peopleNeeded = int.tryParse(_tripData['people_needed'].toString()) ?? 2;
        _maxCapacity = int.tryParse(_tripData['max_capacity'].toString()) ?? 4;
        _peopleAlready = int.tryParse(_tripData['people_already'].toString()) ?? 2;
        
        isLoading = false;
      });
    }
  }

  Future<void> _handleJoinTrip() async {
    // Prevent joining if already joined, full, or already processing
    if (isJoining || hasUserJoined || (_peopleAlready >= _maxCapacity)) return;

    setState(() => isJoining = true);

    try {
      final result = await Navigator.pushNamed(
        context, 
        AppRoutes.joinVerification,
        arguments: _tripData 
      );

      if (result == true && mounted) {
        setState(() {
          hasUserJoined = true;
          _peopleAlready += 1;
          _peopleNeeded = (_peopleNeeded - 1).clamp(0, _maxCapacity);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Successfully joined!", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Color(0xFFFFD54F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("Navigation Error: $e");
    } finally {
      if (mounted) {
        setState(() => isJoining = false);
      }
    }
  }

  IconData _getVehicleIcon(String? vehicle) {
    String v = (vehicle ?? "").toLowerCase();
    if (v.contains('bike')) return Icons.two_wheeler;
    if (v.contains('bus')) return Icons.directions_bus;
    return Icons.directions_car;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    final destination = _tripData['destination'];
    final startDate = _tripData['start_date'];
    final vehicle = _tripData['vehicle'];
    final price = _tripData['price']?.toString().replaceAll('₹', '') ?? "0";
    final driverName = _tripData['driver_name'] ?? "John Doe";
    final fromLocation = _tripData['from'] ?? "Current Location";

    // --- GATEKEEPER LOGIC ---
    bool isTripFull = _peopleAlready >= _maxCapacity;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Trip Details",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- Header ---
                  Text(
                    destination.toString().toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          startDate,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "₹$price",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // --- Host Card ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.black,
                          child: Text(
                            driverName.isNotEmpty ? driverName[0] : "D", 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Hosted by",
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                              Text(
                                driverName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.chat_bubble_fill, size: 18, color: Colors.black),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- Details ---
                  _buildInfoRow(_getVehicleIcon(vehicle), "Vehicle", vehicle),
                  const SizedBox(height: 20),
                  _buildInfoRow(Icons.location_on_outlined, "Start Location", fromLocation),
                  
                  const SizedBox(height: 30),
                  const Divider(color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 20),
                  
                  // --- Progress Section ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Capacity Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        isTripFull ? "Full" : "$_peopleNeeded seats left",
                        style: TextStyle(
                          color: isTripFull ? Colors.grey : const Color(0xFFD32F2F), 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // --- Rounded Progress Bar ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      double progress = (_maxCapacity > 0) ? (_peopleAlready / _maxCapacity) : 0;
                      if (progress > 1.0) progress = 1.0;

                      return Stack(
                        children: [
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: 12,
                            width: constraints.maxWidth * progress,
                            decoration: BoxDecoration(
                              color: isTripFull ? Colors.green : const Color(0xFFFFD54F), // Turns green when full
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      );
                    }
                  ),
                  
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "$_peopleAlready / $_maxCapacity joined",
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Bottom Action Bar (Smart Button) ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: _buildBottomButton(isTripFull),
          ),
        ],
      ),
    );
  }

  // --- SMART BUTTON BUILDER ---
  Widget _buildBottomButton(bool isTripFull) {
    // 1. If user is already in the trip (or is the host)
    if (hasUserJoined) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text(
                "Already Joined",
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    } 
    
    // 2. If the user hasn't joined, but the trip is completely full
    else if (isTripFull) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.not_interested, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                "Trip is Full",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    } 
    
    // 3. Normal State: Trip has space and user is not in it
    else {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () {
            if (!isJoining) _handleJoinTrip();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: isJoining
              ? const SizedBox(
                  height: 24, width: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : const Text(
                  "Request to Join",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      );
    }
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: Colors.black),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            Text(
              value, 
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black),
            ),
          ],
        ),
      ],
    );
  }
}