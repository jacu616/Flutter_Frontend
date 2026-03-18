import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_app/config/config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app/routes.dart';

const String baseUrl = AppConfig.baseUrl;

class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> with WidgetsBindingObserver {
  List trips = [];
  bool loading = true;
  int? expandedTripId;
  Map<int, List<String>> tripImages = {};
  Map<int, TextEditingController> tripCaptions = {};
  final picker = ImagePicker();
  DateTime currentDeviceDate = DateTime.now();
  Map<int, bool> uploadingImages = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    currentDeviceDate = DateTime.now();
    fetchTrips();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var controller in tripCaptions.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDeviceDateChange();
    }
  }

  Future<void> _checkDeviceDateChange() async {
    final DateTime now = DateTime.now();
    if (now.year != currentDeviceDate.year ||
        now.month != currentDeviceDate.month ||
        now.day != currentDeviceDate.day) {
      setState(() => currentDeviceDate = now);
      fetchTrips();
    }
  }

  Future<void> fetchTrips() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/trips/completed/"),
        headers: {
          "Authorization": "Token $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List filteredTrips = [];
        for (var trip in data) {
          DateTime endDate = DateTime.parse(trip["end_date"]);
          if (endDate.isBefore(currentDeviceDate) ||
              (endDate.year == currentDeviceDate.year &&
                  endDate.month == currentDeviceDate.month &&
                  endDate.day == currentDeviceDate.day)) {
            filteredTrips.add(trip);
            final id = trip["trip_id"] as int;
            tripCaptions.putIfAbsent(id, () => TextEditingController());
          }
        }
        setState(() {
          trips = filteredTrips;
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("FETCH ERROR: $e");
      setState(() => loading = false);
    }
  }

  Future<String?> uploadImageToSupabase(File imageFile, int tripId) async {
    try {
      final supabase = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null) return null;

      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$tripId.$fileExt';
      final filePath = '$userId/$fileName';

      await supabase.storage.from('post-image').upload(
        filePath,
        imageFile,
        fileOptions: const FileOptions(cacheControl: '3600'),
      );

      return supabase.storage.from('post-image').getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Error uploading to Supabase: $e');
      return null;
    }
  }

  Future<void> pickImage(int tripId) async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => uploadingImages[tripId] = true);

    try {
      final file = File(picked.path);
      final imageUrl = await uploadImageToSupabase(file, tripId);

      if (imageUrl != null && mounted) {
        setState(() {
          tripImages.putIfAbsent(tripId, () => []);
          tripImages[tripId]!.add(imageUrl);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Image uploaded successfully")),
        );
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading image: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => uploadingImages[tripId] = false);
    }
  }

  Future<void> createPost(int tripId) async {
    if (tripImages[tripId] == null || tripImages[tripId]!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one image")),
      );
      return;
    }

    setState(() => uploadingImages[tripId] = true);

    final prefs  = await SharedPreferences.getInstance();
    final token  = prefs.getString("auth_token");
    final trip   = trips.firstWhere((t) => t["trip_id"] == tripId);
    final caption = tripCaptions[tripId]?.text.trim() ?? '';

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/posts/create/"),
        headers: {
          "Content-Type":  "application/json",
          "Authorization": "Token $token",
        },
        body: jsonEncode({
          "trip_id":     tripId,
          "image_urls":  tripImages[tripId],
          "caption":     caption,
          "destination": trip["destination"],
          "location":    trip["destination"],
        }),
      );

      if (response.statusCode == 201 && mounted) {
        setState(() {
          tripImages.remove(tripId);
          tripCaptions[tripId]?.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Post created successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.profile,
          (route) => false,
        );
      } else {
        throw Exception('Failed to create post');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating post: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => uploadingImages[tripId] = false);
    }
  }

  void removeImage(int tripId, int imageIndex) {
    setState(() {
      if (tripImages[tripId] != null &&
          imageIndex < tripImages[tripId]!.length) {
        tripImages[tripId]!.removeAt(imageIndex);
        if (tripImages[tripId]!.isEmpty) {
          tripImages.remove(tripId);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Create Post",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF2B2B2B),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Loading your trips...",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : trips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.card_travel,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "No completed trips found",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          "Trips that have ended will appear here. Complete a trip to share your memories!",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[500],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final trip          = trips[index];
                    final tripId        = trip["trip_id"] as int;
                    final isExpanded    = expandedTripId == tripId;
                    final isUploading   = uploadingImages[tripId] ?? false;
                    final tripImageList = tripImages[tripId] ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ── Trip Header ──────────────────────────────────
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(() =>
                                  expandedTripId = isExpanded ? null : tripId),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20)),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF2B2B2B),
                                            Colors.grey[800]!,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: const Icon(Icons.place,
                                          color: Colors.white, size: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            trip["destination"] ??
                                                'Unknown Destination',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today,
                                                  size: 14,
                                                  color: Colors.grey[500]),
                                              const SizedBox(width: 4),
                                              Text(
                                                "${trip["start_date"]} → ${trip["end_date"]}",
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: Colors.grey[800],
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ── Expanded Content ─────────────────────────────
                          if (isExpanded)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                      color: Colors.grey[200]!, width: 1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── Image Section Header ─────────────────
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2B2B2B)
                                                  .withOpacity(0.05),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                                Icons.photo_library,
                                                size: 18,
                                                color: Color(0xFF2B2B2B)),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            "Trip Images",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                          if (tripImageList.isNotEmpty)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  left: 8),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2B2B2B),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${tripImageList.length}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (!isUploading)
                                        Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2B2B2B),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: IconButton(
                                            onPressed: () => pickImage(tripId),
                                            icon: const Icon(Icons.add_a_photo),
                                            color: Colors.white,
                                            iconSize: 20,
                                            padding: const EdgeInsets.all(10),
                                            constraints: const BoxConstraints(),
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFF2B2B2B),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // ── Image Grid ───────────────────────────
                                  if (tripImageList.isNotEmpty)
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8,
                                        childAspectRatio: 1,
                                      ),
                                      itemCount: tripImageList.length,
                                      itemBuilder: (context, i) {
                                        return Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.network(
                                                tripImageList[i],
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  color: Colors.grey[100],
                                                  child: const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey,
                                                      size: 24),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap: () =>
                                                    removeImage(tripId, i),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black26,
                                                        blurRadius: 4,
                                                        offset: Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                      Icons.close,
                                                      size: 12,
                                                      color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    )
                                  else
                                    Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        border: Border.all(
                                            color: Colors.grey[200]!,
                                            width: 2),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                                size: 30,
                                                color: Colors.grey[400]),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Tap + to add images',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  const SizedBox(height: 16),

                                  // ── Caption Field ────────────────────────
                                  TextField(
                                    controller: tripCaptions[tripId],
                                    maxLines: 3,
                                    maxLength: 300,
                                    decoration: InputDecoration(
                                      hintText:
                                          'Write a caption for your trip...',
                                      hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 14),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                            color: Colors.grey[200]!),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                            color: Colors.grey[200]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF2B2B2B)),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.all(14),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // ── Post Button ──────────────────────────
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 56,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            gradient: (isUploading ||
                                                    tripImageList.isEmpty)
                                                ? null
                                                : const LinearGradient(
                                                    colors: [
                                                      Color(0xFF2B2B2B),
                                                      Color(0xFF4A4A4A),
                                                    ],
                                                  ),
                                            color: (isUploading ||
                                                    tripImageList.isEmpty)
                                                ? Colors.grey[200]
                                                : null,
                                          ),
                                          child: ElevatedButton.icon(
                                            onPressed: isUploading ||
                                                    tripImageList.isEmpty
                                                ? null
                                                : () => createPost(tripId),
                                            icon: Icon(
                                              Icons.send,
                                              color: (isUploading ||
                                                      tripImageList.isEmpty)
                                                  ? Colors.grey[500]
                                                  : Colors.white,
                                              size: 20,
                                            ),
                                            label: Text(
                                              isUploading
                                                  ? 'Posting...'
                                                  : 'Share Memories',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                color: (isUploading ||
                                                        tripImageList.isEmpty)
                                                    ? Colors.grey[500]
                                                    : Colors.white,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}