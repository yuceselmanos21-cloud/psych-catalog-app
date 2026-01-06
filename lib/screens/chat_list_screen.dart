import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../repositories/firestore_chat_repository.dart';
import '../repositories/firestore_user_repository.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      return const Scaffold(
        body: Center(child: Text("Giriş yapın")),
      );
    }

    final repo = FirestoreChatRepository();
    final userRepo = FirestoreUserRepository();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mesajlar"),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: repo.watchMyChats(myUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          
          if (docs.isEmpty) {
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
                    'Henüz mesajın yok',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Uzmanlarla sohbet etmeye başla!',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final chatId = doc.id;
              final lastMsg = data['lastMessage']?.toString() ?? '';
              final lastMessageAt = data['lastMessageAt'] as Timestamp?;
              final lastSenderId = data['lastSenderId']?.toString();
              final participants = List<String>.from(data['participants'] ?? []);
              final otherId = participants.firstWhere((id) => id != myUid, orElse: () => '');
              final isMeLastSender = lastSenderId == myUid;

              return FutureBuilder<Map<String, dynamic>?>(
                future: userRepo.getUserById(otherId),
                builder: (context, userSnapshot) {
                  final userName = userSnapshot.data?['name']?.toString() ?? 'Kullanıcı';
                  final photoUrl = userSnapshot.data?['photoUrl']?.toString();
                  final role = userSnapshot.data?['role']?.toString() ?? 'client';
                  final profession = userSnapshot.data?['profession']?.toString();

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    elevation: 0,
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        child: photoUrl == null || photoUrl.isEmpty
                            ? Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              userName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (lastMessageAt != null)
                            Text(
                              _formatTime(lastMessageAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (profession != null && profession.isNotEmpty && role == 'expert')
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                profession,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastMsg.isEmpty
                                      ? 'Henüz mesaj yok'
                                      : (isMeLastSender ? 'Sen: $lastMsg' : lastMsg),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: chatId,
                              otherUserId: otherId,
                              otherUserName: userName,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}