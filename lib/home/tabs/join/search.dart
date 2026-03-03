import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/config.dart'; 
import '../../../routes.dart';

class SearchGrid extends StatefulWidget {
  const SearchGrid({super.key});

  @override
  State<SearchGrid> createState() => _SearchGridState();
}

class _SearchGridState extends State<SearchGrid> {
  List<Map<String, dynamic>> trips = [];
  List<Map<String, dynamic>> filteredTrips = [];
  bool isLoading = true;
  String? errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchTrips();
  }

  Future<void> fetchTrips() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = "Please login to view trips";
        });
        return;
      }

      // --- FIX: Added '/api/' to the URL ---
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}/api/trips/search/"), 
        headers: {
          "Authorization": "Token $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Map<String, dynamic>> loadedTrips = List<Map<String, dynamic>>.from(data);

        setState(() {
          trips = loadedTrips;
          filteredTrips = loadedTrips;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Failed to load trips (Status: ${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Connection error: $e";
      });
    }
  }

  void _filterTrips(String query) {
    if (query.isEmpty) {
      setState(() => filteredTrips = trips);
    } else {
      setState(() {
        filteredTrips = trips.where((trip) {
          final dest = trip['destination'].toString().toLowerCase();
          final vehicle = trip['vehicle'].toString().toLowerCase();
          final from = trip['from'].toString().toLowerCase();
          final input = query.toLowerCase();
          return dest.contains(input) || vehicle.contains(input) || from.contains(input);
        }).toList();
      });
    }
  }

  Future<void> _refreshTrips() async {
    _searchController.clear();
    await fetchTrips();
  }

  // --- UI HELPERS (Fixed Logic for Bikes/Small Vehicles) ---

  Color _getBadgeColor(int peopleNeeded, int maxCapacity) {
    if (peopleNeeded == 0) return Colors.grey;
    
    // If fully empty (e.g. Bike 1/1), show Green
    if (peopleNeeded == maxCapacity) return Colors.green.shade700;

    // Only show red/orange if seats are actually filling up
    if (peopleNeeded == 1) return Colors.red.shade700; // Critical (Last Seat)
    if (peopleNeeded <= 2) return Colors.orange.shade800; // Urgent
    
    return Colors.black; // Standard
  }

  String _getBadgeText(int peopleNeeded, int maxCapacity) {
    if (peopleNeeded == 0) return "Full";

    // If the trip hasn't been booked yet, it is "Open" (even for a bike)
    if (peopleNeeded == maxCapacity) return "Open";

    if (peopleNeeded == 1) return "Last Seat";
    if (peopleNeeded <= 2) return "Urgent";
    
    return "Available";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterTrips,
                  decoration: InputDecoration(
                    hintText: "Search destination...",
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(CupertinoIcons.search, color: Colors.black),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.grey),
                      onPressed: _refreshTrips,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ),

            /// Stats Bar or Error Message
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
              )
            else if (!isLoading && filteredTrips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      "${filteredTrips.length} trips available",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.filter_list, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      "Filter",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

            /// Loading Indicator
            if (isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              ),

            /// Empty State
            if (!isLoading && filteredTrips.isEmpty && errorMessage == null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        "No trips found",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ),

            /// Trip List
            if (!isLoading && filteredTrips.isNotEmpty)
              Expanded(
                child: RefreshIndicator(
                  color: Colors.black,
                  onRefresh: _refreshTrips,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredTrips.length,
                    itemBuilder: (context, index) {
                      final trip = filteredTrips[index];
                      return _buildTripCard(trip);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final destination = trip['destination'] ?? "Unknown";
    final startDate = trip['start_date'] ?? "N/A";
    final vehicle = trip['vehicle'] ?? "Car";
    
    // Ensure values are integers
    int peopleNeeded = trip['people_needed'] is int ? trip['people_needed'] : 0;
    int maxCapacity = trip['max_capacity'] is int ? trip['max_capacity'] : 0;
    int peopleAlready = trip['people_already'] is int ? trip['people_already'] : 0;
    String price = trip['price'] ?? "₹0";

    Color badgeColor = _getBadgeColor(peopleNeeded, maxCapacity);
    String badgeText = _getBadgeText(peopleNeeded, maxCapacity);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.tripJoin,
              arguments: trip,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                /// Header: Destination & Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destination,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              vehicle,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// Info Row: Date & Price
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      startDate,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// Progress Bar Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "SEATS LEFT",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[400],
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    "$peopleNeeded",
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: badgeColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "seats",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.people, color: Colors.grey[400]),
                          )
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Progress Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: maxCapacity > 0 ? peopleAlready / maxCapacity : 0,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "$peopleAlready / $maxCapacity filled",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                /// Footer: View Details
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      "View Details",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward, size: 10, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}