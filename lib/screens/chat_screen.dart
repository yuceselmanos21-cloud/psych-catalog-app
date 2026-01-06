import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../repositories/firestore_chat_repository.dart';
import '../repositories/firestore_user_repository.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String? otherUserName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    this.otherUserName
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _repo = FirestoreChatRepository();
  final _userRepo = FirestoreUserRepository();
  final _myUid = FirebaseAuth.instance.currentUser?.uid;
  final ScrollController _scrollController = ScrollController();

  String? _otherUserPhotoUrl;
  String? _myPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserPhotos();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPhotos() async {
    if (_myUid == null) return;
    
    try {
      // Load other user photo
      final otherUser = await _userRepo.getUserById(widget.otherUserId);
      if (otherUser != null && mounted) {
        setState(() => _otherUserPhotoUrl = otherUser['photoUrl']?.toString());
      }

      // Load my photo
      final myUser = await _userRepo.getUserById(_myUid!);
      if (myUser != null && mounted) {
        setState(() => _myPhotoUrl = myUser['photoUrl']?.toString());
      }
    } catch (e) {
      debugPrint('Error loading user photos: $e');
    }
  }

  void _send() {
    if (_textCtrl.text.trim().isEmpty || _myUid == null) return;
    _repo.sendMessage(chatId: widget.chatId, senderId: _myUid!, text: _textCtrl.text.trim());
    _textCtrl.clear();
    
    // Scroll to bottom after sending
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      // Today: show time
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Dün ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${date.day}.${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe, bool isDark) {
    final text = data['text']?.toString() ?? '';
    final timestamp = data['createdAt'] as Timestamp?;
    final timeStr = _formatTime(timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: _otherUserPhotoUrl != null && _otherUserPhotoUrl!.isNotEmpty
                  ? NetworkImage(_otherUserPhotoUrl!)
                  : null,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              child: _otherUserPhotoUrl == null || _otherUserPhotoUrl!.isEmpty
                  ? Icon(Icons.person, size: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? (isDark ? Colors.deepPurple.shade700 : Colors.deepPurple)
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    text,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white70
                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundImage: _myPhotoUrl != null && _myPhotoUrl!.isNotEmpty
                  ? NetworkImage(_myPhotoUrl!)
                  : null,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              child: _myPhotoUrl == null || _myPhotoUrl!.isEmpty
                  ? Icon(Icons.person, size: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : Colors.grey.shade50;
    final inputBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName ?? "Sohbet"),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _repo.watchMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz mesaj yok',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'İlk mesajı sen gönder!',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs.toList();
                // Sort by timestamp (oldest first for reverse ListView)
                docs.sort((a, b) {
                  final aTs = a.data() as Map<String, dynamic>;
                  final bTs = b.data() as Map<String, dynamic>;
                  final aTime = (aTs['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
                  final bTime = (bTs['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
                  return bTime.compareTo(aTime); // Reverse order for reverse ListView
                });

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _myUid;
                    return _buildMessageBubble(data, isMe, isDark);
                  },
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: inputBg,
              border: Border(top: BorderSide(color: borderColor, width: 1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: "Mesaj yaz...",
                        hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                        filled: true,
                        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _send,
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      backgroundColor: scaffoldBg,
    );
  }
}