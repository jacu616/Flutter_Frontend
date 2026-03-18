import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_app/config/config.dart';

const String _base = AppConfig.baseUrl;

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onAuthorTap;

  const PostCard({Key? key, required this.post, this.onAuthorTap})
      : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late bool _isSaved;
  late int  _likeCount;
  bool _likeLoading = false;
  bool _saveLoading = false;

  late AnimationController _heartController;
  late Animation<double>   _heartScale;

  @override
  void initState() {
    super.initState();
    _isLiked   = widget.post['is_liked']   ?? false;
    _isSaved   = widget.post['is_saved']   ?? false;
    _likeCount = widget.post['like_count'] ?? 0;

    _heartController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 200),
    );
    _heartScale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _toggleLike() async {
    if (_likeLoading) return;
    setState(() {
      _likeLoading = true;
      _isLiked     = !_isLiked;
      _likeCount  += _isLiked ? 1 : -1;
    });
    _heartController.forward().then((_) => _heartController.reverse());

    try {
      final token = await _getToken();
      final res   = await http.post(
        Uri.parse('$_base/api/posts/${widget.post['id']}/like/'),
        headers: {'Authorization': 'Token $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _isLiked   = data['liked'];
          _likeCount = data['like_count'];
        });
      } else {
        setState(() {
          _isLiked   = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    } catch (_) {
      setState(() {
        _isLiked   = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
    } finally {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  Future<void> _toggleSave() async {
    if (_saveLoading) return;
    setState(() {
      _saveLoading = true;
      _isSaved     = !_isSaved;
    });
    try {
      final token = await _getToken();
      final res   = await http.post(
        Uri.parse('$_base/api/posts/${widget.post['id']}/save/'),
        headers: {'Authorization': 'Token $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _isSaved = data['saved']);
      } else {
        setState(() => _isSaved = !_isSaved);
      }
    } catch (_) {
      setState(() => _isSaved = !_isSaved);
    } finally {
      if (mounted) setState(() => _saveLoading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt   = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final images     = List<Map<String, dynamic>>.from(widget.post['images'] ?? []);
    final authorPic  = widget.post['author_picture'] as String?;
    final authorName = widget.post['author_name']    ?? 'Unknown';
    final location   = widget.post['location']       ?? '';
    final caption    = widget.post['caption']        ?? '';
    final createdAt  = widget.post['created_at']     as String?;

    // First image URL
    final imageUrl = images.isNotEmpty ? (images[0]['image_url'] ?? '') : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onAuthorTap,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.indigo.shade100,
                    backgroundImage: (authorPic != null && authorPic.isNotEmpty)
                        ? NetworkImage(authorPic)
                        : null,
                    child: (authorPic == null || authorPic.isEmpty)
                        ? Text(authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onAuthorTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(authorName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        if (location.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 11, color: Colors.grey),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                              ),
                            ],
                          )
                        else
                          Text(_formatTime(createdAt),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                if (location.isNotEmpty)
                  Text(_formatTime(createdAt),
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(width: 8),
                // Save icon
                GestureDetector(
                  onTap: _toggleSave,
                  child: Icon(
                    _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: _isSaved ? Colors.black : Colors.grey,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),

          // ── Photo + Like/Share overlay ─────────────────────────────────
          if (imageUrl.isNotEmpty)
            Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Image carousel or single image ───────────────────────
                images.length > 1
                    ? _ImageCarousel(images: images)
                    : Container(
                        height: 350,
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: Icon(Icons.broken_image,
                                    size: 48, color: Colors.grey),
                              ),
                            ),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: Colors.grey[100],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.black, strokeWidth: 2),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                // ── Like Pill ─────────────────────────────────────────────
                Positioned(
                  bottom: -15,
                  left: 28,
                  child: GestureDetector(
                    onTap: _toggleLike,
                    child: ScaleTransition(
                      scale: _heartScale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isLiked ? Icons.favorite : Icons.favorite_border,
                              color: _isLiked ? Colors.pink : Colors.pink,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _likeCount > 0 ? '$_likeCount' : 'Like',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Tilted Share Button ───────────────────────────────────
                Positioned(
                  bottom: -15,
                  right: 28,
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4))
                      ],
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle: -math.pi / 6,
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // ── Caption ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caption.isNotEmpty)
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          color: Colors.black, fontSize: 14, height: 1.4),
                      children: [
                        TextSpan(
                          text: '$authorName ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: caption),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image Carousel ────────────────────────────────────────────────────────────

class _ImageCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  const _ImageCarousel({required this.images});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _current = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          height: 350,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: PageView.builder(
              controller:    _pageController,
              itemCount:     images.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder:   (context, i) {
                final url = images[i]['image_url'] ?? '';
                return Image.network(
                  url,
                  fit:   BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[100],
                    child: const Center(
                      child: Icon(Icons.broken_image,
                          size: 48, color: Colors.grey),
                    ),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey[100],
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        // Dot indicators
        if (images.length > 1)
          Positioned(
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width:  _current == i ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _current == i
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}