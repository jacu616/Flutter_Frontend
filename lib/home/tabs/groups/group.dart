import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../config/config.dart';

class GroupPage extends StatefulWidget {
  const GroupPage({super.key});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  // Theme Colors
  final Color _themeYellow = const Color(0xFFFFD54F);
  final Color _lightYellow = const Color(0xFFFFF9C4);

  // Group Info
  String groupName = "Group Chat";
  String groupId = ""; 
  int adminId = 0; 

  // User Info
  int currentUserId = 0;
  String currentUserName = "Me";
  bool _isLoadingUser = true;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (args != null) {
      setState(() {
        // Safely parse Group Name
        groupName = args['group_name']?.toString() ?? args['groupName']?.toString() ?? "Group Chat";
        
        // Safely parse Group ID
        var rawId = args['group_id'] ?? args['groupId'] ?? args['id'];
        if (rawId != null && rawId.toString().trim().isNotEmpty) {
          groupId = rawId.toString();
        } else {
          groupId = groupName.replaceAll(" ", "_").toLowerCase();
        }
        
        // --- CRITICAL FIX: Safely parse Admin ID to guarantee it's an int ---
        var rawAdmin = args['admin_id'] ?? args['adminId'];
        adminId = int.tryParse(rawAdmin?.toString() ?? '0') ?? 0;
        
        print("🛠️ LOADED CHAT: GroupID=$groupId | AdminID=$adminId");
      });
    }
  }

  // --- ROBUST USER LOADING ---
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    
    var id = prefs.get('user_id');
    int finalId = 0;
    if (id is int) finalId = id;
    else if (id is String) finalId = int.tryParse(id) ?? 0;

    if (finalId == 0) {
      print("⚠️ User ID missing locally. Fetching from Backend...");
      await _fetchProfileFromBackend(prefs);
    } else {
      setState(() {
        currentUserId = finalId;
        currentUserName = prefs.getString('first_name') ?? "User";
        _isLoadingUser = false;
      });
      print("✅ User Loaded Locally: ID=$currentUserId, Name=$currentUserName");
    }
  }

  Future<void> _fetchProfileFromBackend(SharedPreferences prefs) async {
    try {
      final token = prefs.getString('auth_token');
      if (token == null) {
        setState(() => _isLoadingUser = false);
        return;
      }

      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}/api/profile/"),
        headers: {
          "Authorization": "Token $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        int fetchedId = data['id'];
        String fetchedName = data['first_name'] ?? "User";

        await prefs.setInt('user_id', fetchedId);
        await prefs.setString('first_name', fetchedName);

        setState(() {
          currentUserId = fetchedId;
          currentUserName = fetchedName;
          _isLoadingUser = false;
        });
        print("✅ User Loaded from API: ID=$currentUserId");
      } else {
        setState(() => _isLoadingUser = false);
      }
    } catch (e) {
      setState(() => _isLoadingUser = false);
    }
  }

  // --- MESSAGING ---
  void _sendMessage({String type = 'text', String? fileUrl, String? text}) {
    if ((text == null || text.trim().isEmpty) && fileUrl == null) return;
    if (groupId.isEmpty) return;

    if (currentUserId == 0) {
      _loadUserInfo();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Identifying user... Try again in a second.")),
      );
      return;
    }

    FirebaseFirestore.instance
        .collection('chats')
        .doc(groupId)
        .collection('messages')
        .add({
      'senderId': currentUserId, 
      'senderName': currentUserName,
      'text': text ?? "",
      'type': type, 
      'fileUrl': fileUrl ?? "",
      'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  // --- UPLOADS ---
  Future<void> _pickAndUpload(String type) async {
    File? file;
    try {
      if (type == 'image') {
        final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
        if (picked != null) file = File(picked.path);
      } else if (type == 'video') {
        final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
        if (picked != null) file = File(picked.path);
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null) file = File(result.files.single.path!);
      }

      if (file != null) {
        setState(() => _isUploading = true);
        String fileName = "${DateTime.now().millisecondsSinceEpoch}_$type";
        Reference ref = FirebaseStorage.instance.ref().child('chat_files/$groupId/$fileName');
        UploadTask uploadTask = ref.putFile(file);
        
        final snapshot = await uploadTask.whenComplete(() {});
        final url = await snapshot.ref.getDownloadURL();

        _sendMessage(type: type, fileUrl: url, text: type == 'doc' ? file.path.split('/').last : null);
        setState(() => _isUploading = false);
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
      setState(() => _isUploading = false);
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildAttachIcon(Icons.image, Colors.purple, "Photo", () => _pickAndUpload('image')),
            _buildAttachIcon(Icons.videocam, Colors.pink, "Video", () => _pickAndUpload('video')),
            _buildAttachIcon(Icons.insert_drive_file, Colors.blue, "File", () => _pickAndUpload('doc')),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachIcon(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 28, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              groupName, 
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isUploading)
            LinearProgressIndicator(color: _themeYellow, backgroundColor: Colors.black),

          // --- MESSAGES AREA ---
          Expanded(
            child: (_isLoadingUser || groupId.isEmpty)
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(groupId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text("Error loading chats"));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.black));
                    
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)),
                          child: const Text("Start the conversation!", style: TextStyle(color: Colors.grey)),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        
                        // Convert BOTH to String to ensure strict matching
                        String msgSenderId = data['senderId'].toString();
                        String myId = currentUserId.toString();
                        String formattedAdminId = adminId.toString();

                        bool isMe = msgSenderId == myId;
                        bool isAdmin = msgSenderId == formattedAdminId;

                        return MessageBubble(
                          sender: data['senderName'] ?? "Unknown",
                          text: data['text'],
                          type: data['type'],
                          fileUrl: data['fileUrl'],
                          timestamp: data['timestamp'],
                          isMe: isMe,
                          isAdmin: isAdmin,
                          themeYellow: _themeYellow,
                          lightYellow: _lightYellow,
                        );
                      },
                    );
                  },
                ),
          ),

          // --- INPUT BOX ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.black, size: 28),
                    onPressed: _showAttachmentSheet,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(30)),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(hintText: "Message...", border: InputBorder.none),
                        minLines: 1, maxLines: 5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _sendMessage(text: _messageController.text),
                    child: CircleAvatar(
                      backgroundColor: Colors.black,
                      radius: 22,
                      child: Icon(Icons.send, color: _themeYellow, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- BUBBLE WIDGET ---

class MessageBubble extends StatelessWidget {
  final String sender;
  final String text;
  final String type;
  final String fileUrl;
  final Timestamp? timestamp;
  final bool isMe;
  final bool isAdmin;
  final Color themeYellow;
  final Color lightYellow;

  const MessageBubble({
    super.key,
    required this.sender,
    required this.text,
    required this.type,
    required this.fileUrl,
    required this.timestamp,
    required this.isMe,
    required this.isAdmin,
    required this.themeYellow,
    required this.lightYellow,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = timestamp != null 
        ? DateFormat('hh:mm a').format(timestamp!.toDate()) 
        : "...";

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            
            // SENDER NAME
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isMe ? "You" : sender,
                    style: TextStyle(
                      fontSize: 11, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.grey[700]
                    ),
                  ),
                  if (isAdmin) 
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                      child: const Text("ADMIN", style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),

            // BUBBLE
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? themeYellow : lightYellow,
                border: isAdmin ? Border.all(color: Colors.black, width: 1.5) : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMediaContent(),
                  if (text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(text, style: const TextStyle(fontSize: 15, color: Colors.black87)),
                    ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(timeStr, style: TextStyle(fontSize: 10, color: Colors.black.withOpacity(0.5), fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    if (type == 'text') return const SizedBox.shrink();

    if (type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          fileUrl,
          loadingBuilder: (ctx, child, p) => p == null ? child : Container(height: 150, width: 200, color: Colors.white.withOpacity(0.5)),
          errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file, color: Colors.black),
          const SizedBox(width: 8),
          Text(type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}