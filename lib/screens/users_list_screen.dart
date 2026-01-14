import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../repositories/firestore_follow_repository.dart';
import '../repositories/firestore_user_repository.dart';

class UsersListScreen extends StatefulWidget {
  final String userId;
  final bool isFollowersList; // true = takipçiler, false = takip edilenler

  const UsersListScreen({
    super.key,
    required this.userId,
    required this.isFollowersList,
  });

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final _followRepo = FirestoreFollowRepository();
  final _userRepo = FirestoreUserRepository();
  final _me = FirebaseAuth.instance.currentUser;

  Stream<QuerySnapshot<Map<String, dynamic>>> _getUsersStream() {
    if (widget.isFollowersList) {
      // Takipçiler: /users/{userId}/followers/{followerId}
      return FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('followers')
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      // Takip edilenler: /users/{userId}/following/{followingId}
      return FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('following')
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  String _extractUserId(DocumentSnapshot doc) {
    if (widget.isFollowersList) {
      // followers collection'da document ID = followerId
      return doc.id;
    } else {
      // following collection'da document ID = targetId
      return doc.id;
    }
  }

  Future<void> _toggleFollow(String targetUserId) async {
    final currentUserId = _me?.uid;
    if (currentUserId == null || currentUserId == targetUserId) return;

    try {
      await _followRepo.toggleFollow(
        currentUserId: currentUserId,
        expertId: targetUserId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _isFollowing(String targetUserId) async {
    final currentUserId = _me?.uid;
    if (currentUserId == null) return false;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .get();
      return snap.exists;
    } catch (e) {
      return false;
    }
  }

  void _navigateToProfile(String userId, Map<String, dynamic> userData) {
    final role = userData['role']?.toString() ?? 'client';
    if (role == 'expert') {
      Navigator.pushNamed(
        context,
        '/publicExpertProfile',
        arguments: userId,
      );
    } else {
      Navigator.pushNamed(
        context,
        '/publicClientProfile',
        arguments: userId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFollowersList ? 'Takipçiler' : 'Takip Edilenler'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getUsersStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Liste yüklenirken hata oluştu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isFollowersList ? Icons.people_outline : Icons.person_add_outlined,
                      size: 48,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.isFollowersList
                          ? 'Henüz takipçin yok.'
                          : 'Henüz kimseyi takip etmiyorsun.',
                      style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final userId = _extractUserId(doc);

              return FutureBuilder<Map<String, dynamic>>(
                future: _userRepo.getUser(userId),
                builder: (context, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: CircularProgressIndicator(strokeWidth: 2),
                      title: Text('Yükleniyor...'),
                    );
                  }

                  if (!userSnap.hasData) {
                    return const ListTile(
                      title: Text('Kullanıcı bulunamadı'),
                    );
                  }

                  final userData = userSnap.data!;
                  final name = userData['name']?.toString() ?? 'Kullanıcı';
                  final username = userData['username']?.toString() ?? '';
                  final photoUrl = userData['photoUrl']?.toString();
                  final role = userData['role']?.toString() ?? 'client';
                  final isExpert = role == 'expert';
                  final profession = userData['profession']?.toString() ?? '';
                  final city = userData['city']?.toString() ?? '';

                  final isMe = _me?.uid == userId;
                  final canFollow = !isMe && _me != null;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (isExpert)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Uzman',
                              style: TextStyle(fontSize: 10, color: Colors.blue),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (username.isNotEmpty) Text('@$username'),
                        if (profession.isNotEmpty) Text(profession),
                        if (city.isNotEmpty) Text(city),
                      ],
                    ),
                    trailing: canFollow
                        ? FutureBuilder<bool>(
                            future: _isFollowing(userId),
                            builder: (context, followSnap) {
                              if (followSnap.connectionState == ConnectionState.waiting) {
                                return const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                );
                              }
                              final isFollowing = followSnap.data ?? false;
                              return TextButton(
                                onPressed: () => _toggleFollow(userId),
                                child: Text(isFollowing ? 'Takiptesin' : 'Takip Et'),
                              );
                            },
                          )
                        : null,
                    onTap: () => _navigateToProfile(userId, userData),
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

