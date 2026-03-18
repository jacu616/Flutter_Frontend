import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/config/config.dart';
import '../../../routes.dart';

const String baseUrl = AppConfig.baseUrl;

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  List<dynamic> _myTrips   = [];
  bool          _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyTrips();
  }

  Future<void> _fetchMyTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/api/savetrip/my-trips/'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> fetched = jsonDecode(response.body);
        setState(() {
          _myTrips  = fetched.reversed.toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching trips: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── Cancel trip ───────────────────────────────────────────────────────────

  Future<void> _cancelTrip(Map<String, dynamic> trip) async {
    final tripId      = trip['trip_id'] ?? trip['id'];
    final destination = trip['destination'] ?? 'this trip';
    final isAdmin     = trip['is_admin'] == true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isAdmin ? 'Cancel Trip for Everyone?' : 'Leave Trip?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isAdmin
              ? 'This will cancel the trip to $destination for all members. '
                'Everyone will receive a cancellation and refund email. '
                'This action cannot be undone.'
              : 'You will be removed from the trip to $destination and '
                'will receive a refund email. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, go back',
                style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAdmin ? 'Cancel Trip' : 'Leave Trip'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await http.post(
        Uri.parse('$baseUrl/api/trips/$tripId/cancel/'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Cancelled successfully.'),
            backgroundColor: Colors.black,
          ),
        );
        _fetchMyTrips(); // refresh list
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Cancellation failed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns true if cancellation is still allowed (deadline not passed).
  bool _canCancel(Map<String, dynamic> trip) {
    final tripStatus = trip['status'] ?? 'upcoming';
    if (tripStatus == 'completed' || tripStatus == 'ongoing') return false;

    final deadlineStr = trip['cancel_deadline'] as String?;
    if (deadlineStr == null) return true; // no deadline set — allow cancel

    try {
      final deadline = DateTime.parse(deadlineStr);
      return DateTime.now().isBefore(deadline);
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'My Journeys',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black, size: 24),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.black))
            : RefreshIndicator(
                onRefresh: _fetchMyTrips,
                color: Colors.black,
                child: _myTrips.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 10),
                        itemCount: _myTrips.length,
                        itemBuilder: (context, index) {
                          final trip = _myTrips[index];
                          return GroupTile(
                            trip:      trip,
                            canCancel: _canCancel(trip),
                            onCancel:  () => _cancelTrip(trip),
                          );
                        },
                      ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.travel_explore, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              'No journeys yet',
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              'Create a trip to get started!',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Group Tile ────────────────────────────────────────────────────────────────

class GroupTile extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool                 canCancel;
  final VoidCallback         onCancel;

  const GroupTile({
    super.key,
    required this.trip,
    required this.canCancel,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final name    = trip['group_name']?.toString() ?? 'Unknown Group';
    final groupId = trip['group_id'];
    final adminId = trip['admin_id'] is int
        ? trip['admin_id'] as int
        : int.tryParse(trip['admin_id']?.toString() ?? '') ?? 0;
    final message = trip['last_message']?.toString() ?? '';
    final time    = trip['time']?.toString() ?? '';
    final isAdmin = trip['is_admin'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main row: avatar + info + time ────────────────────────────
          GestureDetector(
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.groupChat,
              arguments: {
                'group_name': name,
                'group_id':   groupId,
                'admin_id':   adminId,
              },
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.black,
                  child: Icon(Icons.group, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(time,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Cancel button (only if cancellation window is open) ───────
          if (canCancel) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined,
                    size: 16, color: Colors.red),
                label: Text(
                  isAdmin ? 'Cancel Trip for Everyone' : 'Leave Trip',
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}