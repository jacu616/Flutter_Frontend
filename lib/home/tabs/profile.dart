import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../routes.dart';
import 'package:flutter_app/config/config.dart';

// Ensure this matches your computer's current IP
const String baseUrl = AppConfig.baseUrl;

class UserProfile extends StatefulWidget {
  const UserProfile({Key? key}) : super(key: key);

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Variables to hold API profile data
  String username = "Loading...";
  String email = "Loading..."; 
  String bio = "Loading...";
  String postCountStr = "-";
  int _parsedPostCount = 0; // Used for the GridView itemCount

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAuthStatus();
    fetchProfileData();
  }

  // --- AUTH & DATA FUNCTIONS ---

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');

    if (token == null) {
      if (mounted) {
        // Redirect to login if no token
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
      }
    }
  }

  Future<void> fetchProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');

    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/profile/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Token $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // Parse data from server
          username = "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".trim();
          if (username.isEmpty) username = "Unknown";
          
          email = data['email'] ?? "No email";
          bio = data['bio'] ?? "No bio yet.";
          
          postCountStr = data['post_count']?.toString() ?? "0";
          _parsedPostCount = int.tryParse(postCountStr) ?? 0;
        });
      }
    } catch (e) {
      print("Error fetching profile: $e");
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token'); // Clear the key
    
    if (mounted) {
      // Navigate to Login and remove all previous routes
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
    }
  }

  // --- UI DIALOGS ---

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: _logout, // Calls the updated logout logic
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              _bottomItem(Icons.settings, "Settings"),
              _bottomItem(Icons.tune, "Account Preferences"),
              _bottomItem(Icons.lock_outline, "Privacy"),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Logout",
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {},
    );
  }

  // --- MAIN BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Center(
                    child: Text(
                      "Profile",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _showSettingsMenu,
                      child: const _CompassSettingsIcon(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            /// NAME + BIO + PROFILE PIC
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username, // Dynamically fetched
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email, // Dynamically fetched
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bio, // Dynamically fetched
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87, // Slightly darker for readability vs email
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(
                              "https://images.unsplash.com/photo-1500648767791-00dcc994a43e",
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 3),
                      ),
                      child: const CircleAvatar(
                        radius: 45,
                        backgroundImage: NetworkImage(
                            "https://images.unsplash.com/photo-1500648767791-00dcc994a43e"),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            /// EDIT PROFILE BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text(
                    "Edit Profile",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            /// STATS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(postCountStr, "Posts"), // Dynamically fetched
                const _StatItem("24", "Trips"),
                const _StatItem("1.2k", "Followers"),
              ],
            ),

            const SizedBox(height: 20),

            /// TABS
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.black,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: "Trips"),
                Tab(text: "Posts"),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  /// TRIPS
                  ListView(
                    children: const [
                      TripCard(title: "Manali Adventure", status: "Ongoing"),
                      TripCard(title: "Goa Beach Escape", status: "Upcoming"),
                      TripCard(title: "Ladakh Ride", status: "Completed"),
                    ],
                  ),

                  /// POSTS
                  GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 5,
                    ),
                    itemCount: _parsedPostCount, // Matches the API post count
                    itemBuilder: (context, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        "https://picsum.photos/300/300?random=$index",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class TripCard extends StatelessWidget {
  final String title;
  final String status;

  const TripCard({Key? key, required this.title, required this.status}) : super(key: key);

  Color _statusColor() {
    switch (status) {
      case "Ongoing":
        return Colors.orange;
      case "Upcoming":
        return Colors.blue;
      case "Completed":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: const Icon(Icons.location_on, color: Colors.black),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor().withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: TextStyle(
                color: _statusColor(), fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _CompassSettingsIcon extends StatelessWidget {
  const _CompassSettingsIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: const [
        Icon(Icons.settings, size: 26, color: Colors.black),
        Icon(Icons.navigation, size: 14, color: Colors.black),
      ],
    );
  }
}