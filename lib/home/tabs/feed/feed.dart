import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_app/config/config.dart';
import 'package:flutter_app/routes.dart';
import 'package:flutter_app/home/tabs/feed/post_card.dart';

const String _base = AppConfig.baseUrl;

class HomeFeed extends StatefulWidget {
  const HomeFeed({Key? key}) : super(key: key);

  @override
  State<HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<HomeFeed> {
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _posts        = [];
  int     _page          = 1;
  bool    _hasMore       = true;
  bool    _isLoading     = true;
  bool    _isFetching    = false;
  String? _error;
  int     _unreadCount   = 0;

  @override
  void initState() {
    super.initState();
    _loadFeed(reset: true);
    _fetchUnreadCount();
    _scrollController.addListener(() {
      final pos        = _scrollController.position;
      final nearBottom = pos.pixels >= pos.maxScrollExtent - 200;
      if (nearBottom && _hasMore && !_isFetching && !_isLoading) {
        _loadFeed();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error     = null;
        _page      = 1;
        _hasMore   = true;
      });
    } else {
      if (_isFetching || !_hasMore) return;
      setState(() => _isFetching = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        setState(() => _isLoading = false);
        return;
      }

      final uri = Uri.parse('$_base/api/feed/').replace(
        queryParameters: {'page': '$_page', 'per_page': '10'},
      );
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Token $token'},
      );

      if (res.statusCode == 200) {
        final data  = jsonDecode(res.body);
        final posts = List<Map<String, dynamic>>.from(data['posts']);
        setState(() {
          if (reset) {
            _posts = posts;
          } else {
            _posts.addAll(posts);
          }
          _hasMore = data['has_more'] ?? false;
          _page++;
          _error = null;
        });
      } else {
        setState(() => _error = 'Failed to load feed. Please try again.');
      }
    } catch (e) {
      setState(() => _error = 'Network error. Pull down to retry.');
    } finally {
      if (mounted) setState(() {
        _isLoading  = false;
        _isFetching = false;
      });
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final res = await http.get(
        Uri.parse('$_base/api/notifications/unread-count/'),
        headers: {'Authorization': 'Token $token'},
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() => _unreadCount = data['count'] ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _onRefresh() async {
    await _loadFeed(reset: true);
    await _fetchUnreadCount();
  }

  void _onAuthorTap(Map<String, dynamic> post) {
    final authorId   = post['author_id'];
    final authorName = post['author_name']?.toString() ?? 'User';
    Navigator.pushNamed(
      context,
      AppRoutes.otherProfile,
      arguments: {
        'user_id':   authorId,
        'user_name': authorName,
      },
    );
  }

  void _openNotifications() {
    Navigator.pushNamed(context, AppRoutes.notifications).then((_) {
      // Refresh badge count when returning from notifications
      _fetchUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // ── Initial loading ───────────────────────────────────────────────
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    // ── Error with no posts ───────────────────────────────────────────
    if (_error != null && _posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 52, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 15)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _loadFeed(reset: true),
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
        ),
      );
    }

    // ── Main feed with collapsing app bar ─────────────────────────────
    return RefreshIndicator(
      color:     Colors.black,
      onRefresh: _onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics:    const AlwaysScrollableScrollPhysics(),
        slivers: [

          // ── Collapsing App Bar ──────────────────────────────────────
          SliverAppBar(
            expandedHeight:            100,
            collapsedHeight:           60,
            pinned:                    true,
            floating:                  false,
            elevation:                 0,
            backgroundColor:           const Color(0xFFF8F9FA),
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                color:   const Color(0xFFF8F9FA),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add,
                          color: Colors.black, size: 26),
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.post),
                    ),
                    Expanded(
                      child: Center(
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    // ── Bell with unread badge ──────────────────────
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none,
                              color: Colors.black, size: 26),
                          onPressed: _openNotifications,
                        ),
                        if (_unreadCount > 0)
                          Positioned(
                            top:   6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                  minWidth: 16, minHeight: 16),
                              child: Text(
                                _unreadCount > 99
                                    ? '99+'
                                    : '$_unreadCount',
                                style: const TextStyle(
                                  color:      Colors.white,
                                  fontSize:   9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Empty state ─────────────────────────────────────────────
          if (_posts.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.explore_outlined,
                        size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No posts yet',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                    SizedBox(height: 8),
                    Text('Follow people to see their travel posts here',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ),
            )

          // ── Posts list ──────────────────────────────────────────────
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == _posts.length) {
                    if (_isFetching) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2),
                        ),
                      );
                    }
                    if (!_hasMore) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text("You're all caught up! ✈️",
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }

                  final post = _posts[index];
                  return PostCard(
                    post:        post,
                    onAuthorTap: () => _onAuthorTap(post),
                  );
                },
                childCount: _posts.length + 1,
              ),
            ),
        ],
      ),
    );
  }
}