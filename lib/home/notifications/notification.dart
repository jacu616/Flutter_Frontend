// lib/home/notifications/notification.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_app/config/config.dart';
import 'package:flutter_app/routes.dart';
import 'notify.dart';

const String _base = AppConfig.baseUrl;

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification> _notifications  = [];
  Set<int>              _followingIds   = {};
  bool                  _isLoading      = true;
  String?               _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await _token();
      if (token == null) return;

      // Fetch notifications
      final res = await http.get(
        Uri.parse('$_base/api/notifications/'),
        headers: {'Authorization': 'Token $token'},
      );

      if (res.statusCode != 200) {
        setState(() => _error = 'Failed to load notifications.');
        return;
      }

      final List<dynamic> raw   = jsonDecode(res.body);
      final notifications       = raw.map((j) => AppNotification.fromJson(j)).toList();

      // Mark all as read immediately
      http.post(
        Uri.parse('$_base/api/notifications/read-all/'),
        headers: {'Authorization': 'Token $token'},
      );

      // For follow notifications, check which actors we already follow
      final followActorIds = notifications
          .where((n) => n.verb == 'started following you')
          .map((n) => n.actorId)
          .toSet();

      final Set<int> followingIds = {};
      if (followActorIds.isNotEmpty) {
        await Future.wait(followActorIds.map((id) async {
          try {
            final r = await http.get(
              Uri.parse('$_base/api/profile/$id/'),
              headers: {'Authorization': 'Token $token'},
            );
            if (r.statusCode == 200) {
              final data = jsonDecode(r.body);
              if (data['is_following'] == true) followingIds.add(id);
            }
          } catch (_) {}
        }));
      }

      setState(() {
        _notifications = notifications;
        _followingIds  = followingIds;
      });
    } catch (e) {
      setState(() => _error = 'Something went wrong. Pull to retry.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _followUser(int actorId) async {
    try {
      final token = await _token();
      final res   = await http.post(
        Uri.parse('$_base/api/follow/$actorId/'),
        headers: {'Authorization': 'Token $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['following'] == true) {
          setState(() => _followingIds.add(actorId));
        }
      }
    } catch (_) {}
  }

  // ── Tap action per verb ───────────────────────────────────────────────────

  void _onTap(AppNotification n) {
    switch (n.verb) {
      // → liker's profile
      case 'liked your post':
        Navigator.pushNamed(context, AppRoutes.otherProfile, arguments: {
          'user_id':   n.actorId,
          'user_name': n.actorName,
        });
        break;

      // → follower's profile (follow-back handled by button, not tap)
      case 'started following you':
        Navigator.pushNamed(context, AppRoutes.otherProfile, arguments: {
          'user_id':   n.actorId,
          'user_name': n.actorName,
        });
        break;

      // → joiner's profile
      case 'joined your trip':
        Navigator.pushNamed(context, AppRoutes.otherProfile, arguments: {
          'user_id':   n.actorId,
          'user_name': n.actorName,
        });
        break;

      // → otp_verify for this trip (admin)
      case 'started the trip':
        if (n.targetId != null) {
          Navigator.pushNamed(context, AppRoutes.otpVerify, arguments: {
            'trip_id':   n.targetId,
            'trip_name': n.targetDetails?['destination'] ?? 'Trip',
          });
        }
        break;

      // → otp_show for this trip (member)
      case 'your trip has started':
        if (n.targetId != null) {
          Navigator.pushNamed(context, AppRoutes.otpShow, arguments: {
            'trip_id':   n.targetId,
            'trip_name': n.targetDetails?['destination'] ?? 'Trip',
          });
        }
        break;

      // → poster's profile
      case 'posted in your trip':
        Navigator.pushNamed(context, AppRoutes.otherProfile, arguments: {
          'user_id':   n.actorId,
          'user_name': n.actorName,
        });
        break;

      // → leaver's profile
      case 'left the trip':
        Navigator.pushNamed(context, AppRoutes.otherProfile, arguments: {
          'user_id':   n.actorId,
          'user_name': n.actorName,
        });
        break;

      // Trip was cancelled — trip is gone, no navigation
      case 'cancelled the trip':
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No notifications yet',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color:     Colors.black,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          return _NotifCard(
                            notif:          n,
                            isFollowing:    _followingIds.contains(n.actorId),
                            onTap:          () => _onTap(n),
                            onFollowBack:   () => _followUser(n.actorId),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ── Notification Card ─────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final bool            isFollowing;
  final VoidCallback    onTap;
  final VoidCallback    onFollowBack;

  const _NotifCard({
    required this.notif,
    required this.isFollowing,
    required this.onTap,
    required this.onFollowBack,
  });

  _NotifStyle _style() {
    switch (notif.verb) {
      case 'liked your post':
        return _NotifStyle(icon: Icons.favorite_rounded,       color: Colors.red);
      case 'started following you':
        return _NotifStyle(icon: Icons.person_add_rounded,     color: Colors.indigo);
      case 'joined your trip':
        return _NotifStyle(icon: Icons.directions_car_rounded, color: Colors.teal);
      case 'started the trip':
        return _NotifStyle(icon: Icons.qr_code_scanner,        color: Colors.amber.shade700);
      case 'your trip has started':
        return _NotifStyle(icon: Icons.confirmation_number,    color: Colors.amber.shade700);
      case 'posted in your trip':
        return _NotifStyle(icon: Icons.photo_rounded,          color: Colors.orange);
      case 'cancelled the trip':
        return _NotifStyle(icon: Icons.cancel_rounded,         color: Colors.red);
      case 'left the trip':
        return _NotifStyle(icon: Icons.exit_to_app_rounded,    color: Colors.grey);
      default:
        return _NotifStyle(icon: Icons.notifications_rounded,  color: Colors.grey);
    }
  }

  String? _subtitle() {
    final d = notif.targetDetails;
    if (d == null) return null;

    if (notif.targetType == 'trip') {
      final dest = d['destination'];
      final date = d['start_date'];
      if (dest != null && date != null) return 'Trip to $dest · $date';
      if (dest != null)                 return 'Trip to $dest';
    }
    if (notif.targetType == 'post') {
      final caption = d['caption']?.toString() ?? '';
      if (caption.isNotEmpty) return '"$caption"';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final style         = _style();
    final subtitle      = _subtitle();
    final isFollowNotif = notif.verb == 'started following you';
    final isOtpNotif    = notif.verb == 'started the trip' ||
                          notif.verb == 'your trip has started';
    final isTappable    = notif.verb != 'cancelled the trip';

    return GestureDetector(
      onTap: isTappable ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.read ? Colors.white : const Color(0xFFEEF0FF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset:     const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar with type badge ────────────────────────────────
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: style.color.withOpacity(0.15),
                  backgroundImage: notif.actorAvatar != null &&
                          notif.actorAvatar!.isNotEmpty
                      ? NetworkImage(notif.actorAvatar!)
                      : null,
                  child: notif.actorAvatar == null || notif.actorAvatar!.isEmpty
                      ? Text(
                          notif.actorName.isNotEmpty
                              ? notif.actorName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:      style.color),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color:  style.color,
                      shape:  BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(style.icon, size: 9, color: Colors.white),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 12),

            // ── Text ──────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          color: Colors.black, fontSize: 14),
                      children: [
                        TextSpan(
                          text: '${notif.actorName} ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: notif.verb),
                      ],
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            color:      style.color,
                            fontSize:   12,
                            fontWeight: FontWeight.w500)),
                  ],
                  const SizedBox(height: 3),
                  Text(notif.timeAgo,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Right action ──────────────────────────────────────────
            if (isFollowNotif)
              GestureDetector(
                onTap: isFollowing ? null : onFollowBack,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isFollowing
                        ? Colors.grey.shade200
                        : Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: TextStyle(
                      color: isFollowing
                          ? Colors.grey.shade600
                          : Colors.white,
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else if (isOtpNotif)
              // Arrow hint for OTP-redirect notifications
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: style.color)
            else if (!notif.read)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: style.color, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotifStyle {
  final IconData icon;
  final Color    color;
  const _NotifStyle({required this.icon, required this.color});
}