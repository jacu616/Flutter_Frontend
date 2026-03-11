import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../routes.dart';
import 'package:flutter_app/config/config.dart';

const String baseUrl = AppConfig.baseUrl;

class UserProfile extends StatefulWidget {
  const UserProfile({Key? key}) : super(key: key);

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String username       = 'Loading...';
  String email          = 'Loading...';
  String bio            = 'Loading...';
  int    postCount      = 0;
  int    tripCount      = 0;
  int    followerCount  = 0;
  int    followingCount = 0;
  List   posts          = [];
  List   trips          = [];
  bool   _isLoading     = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAuthStatus();
    fetchProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── AUTH & DATA ───────────────────────────────────────────────────────────

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null && mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.login, (route) => false);
    }
  }

  Future<void> fetchProfileData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    try {
      // ── 1. Basic profile ─────────────────────────────────────────────────
      final profileRes = await http.get(
        Uri.parse('$baseUrl/api/profile/'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (profileRes.statusCode == 200) {
        final data = jsonDecode(profileRes.body);
        final userId = data['id'];

        // ── 2. Other profile endpoint gives followers/following/posts/trips ─
        final otherRes = await http.get(
          Uri.parse('$baseUrl/api/profile/$userId/'),
          headers: {
            'Content-Type':  'application/json',
            'Authorization': 'Token $token',
          },
        );

        if (otherRes.statusCode == 200) {
          final other = jsonDecode(otherRes.body);
          setState(() {
            username       = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
            if (username.isEmpty) username = 'Unknown';
            email          = data['email']            ?? 'No email';
            bio            = data['bio']              ?? '';
            postCount      = other['post_count']      ?? 0;
            tripCount      = other['trip_count']      ?? 0;
            followerCount  = other['follower_count']  ?? 0;
            followingCount = other['following_count'] ?? 0;
            posts          = other['posts']           ?? [];
            trips          = other['trips']           ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.login, (route) => false);
    }
  }

  // ── DIALOGS ───────────────────────────────────────────────────────────────

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _logout(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Logout'),
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
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            _bottomItem(Icons.settings,    'Settings'),
            _bottomItem(Icons.tune,        'Account Preferences'),
            _bottomItem(Icons.lock_outline,'Privacy'),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(context); _showLogoutDialog(); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {},
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Center(
                          child: Text('Profile',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
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

                  // Avatar + name + email + bio
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(username,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(email,
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.grey)),
                              if (bio.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(bio,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87)),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 3),
                          ),
                          child: const CircleAvatar(
                            radius: 45,
                            backgroundColor: Color(0xFFF5F5F5),
                            child: Icon(Icons.person,
                                size: 40, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Edit profile button
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Edit Profile',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Stats — all real from backend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(postCount.toString(),      'Posts'),
                      _StatItem(tripCount.toString(),      'Trips'),
                      _StatItem(followerCount.toString(),  'Followers'),
                      _StatItem(followingCount.toString(), 'Following'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Tabs
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.black,
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: 'Trips'),
                      Tab(text: 'Posts'),
                    ],
                  ),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // ── Trips tab ──────────────────────────────────────
                        trips.isEmpty
                            ? _emptyState(Icons.luggage, 'No trips yet')
                            : ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: trips.length,
                                itemBuilder: (context, index) {
                                  final trip = trips[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(15)),
                                    child: ListTile(
                                      leading: const CircleAvatar(
                                        backgroundColor: Colors.black,
                                        child: Icon(Icons.location_on,
                                            color: Colors.white, size: 18),
                                      ),
                                      title: Text(
                                        trip['destination'] ?? 'Unknown',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                          trip['start_date']?.toString() ?? ''),
                                    ),
                                  );
                                },
                              ),

                        // ── Posts tab ──────────────────────────────────────
                        posts.isEmpty
                            ? _emptyState(Icons.photo_library, 'No posts yet')
                            : GridView.builder(
                                padding: const EdgeInsets.all(10),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:  3,
                                  crossAxisSpacing: 5,
                                  mainAxisSpacing:  5,
                                ),
                                itemCount: posts.length,
                                itemBuilder: (context, index) {
                                  final post = posts[index];
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      post['image_url'] ?? '',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.broken_image,
                                            color: Colors.grey),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}

// ── HELPER WIDGETS ────────────────────────────────────────────────────────────

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
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _CompassSettingsIcon extends StatelessWidget {
  const _CompassSettingsIcon();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.settings,   size: 26, color: Colors.black),
        Icon(Icons.navigation, size: 14, color: Colors.black),
      ],
    );
  }
}

class TripCard extends StatelessWidget {
  final String title;
  final String status;
  const TripCard({Key? key, required this.title, required this.status})
      : super(key: key);

  Color _statusColor() {
    switch (status) {
      case 'Ongoing':   return Colors.orange;
      case 'Upcoming':  return Colors.blue;
      case 'Completed': return Colors.green;
      default:          return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: const Icon(Icons.location_on, color: Colors.black),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor().withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(status,
              style: TextStyle(
                  color: _statusColor(), fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}