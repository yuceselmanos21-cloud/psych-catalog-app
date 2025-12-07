import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_post_repository.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({
    super.key,
    required this.postId,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _replyCtrl = TextEditingController();
  bool _sendingReply = false;

  final _postRepo = FirestorePostRepository();

  String _currentUserName = 'Kullanıcı';
  String _currentUserRole = 'client';

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
  }

  Future<void> _loadCurrentUserProfile() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data();
      if (!mounted) return;

      setState(() {
        _currentUserName = (data?['name'] ?? 'Kullanıcı').toString();
        _currentUserRole = (data?['role'] ?? 'client').toString();
      });
    } catch (_) {
      // sessiz geç
    }
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;

    final user = _currentUser;
    if (user == null) return;

    setState(() => _sendingReply = true);

    try {
      await _postRepo.addReply(
        postId: widget.postId,
        text: text,
        authorId: user.uid,
        authorName: _currentUserName,
      );

      _replyCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yorum eklenemedi: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _sendingReply = false);
    }
  }

  void _openAuthorProfile(String? authorId, String role) {
    if (authorId == null) return;
    final currentUserId = _currentUser?.uid;

    if (role == 'expert') {
      Navigator.pushNamed(
        context,
        '/publicExpertProfile',
        arguments: authorId,
      );
    } else if (currentUserId != null && currentUserId == authorId) {
      Navigator.pushNamed(context, '/profile');
    }
  }

  void _showEditPostDialog(String postId, String currentText) {
    final controller = TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gönderiyi Düzenle'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isEmpty) return;

              try {
                await _postRepo.updatePostText(
                  postId: postId,
                  newText: newText,
                );
                if (mounted) Navigator.pop(ctx);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Düzenlenemedi: $e')),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePost(String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gönderiyi sil'),
        content: const Text('Bu gönderiyi silmek istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _postRepo.deletePost(postId);
                if (mounted) {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Silinemedi: $e')),
                );
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gönderi'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _postRepo.watchPost(widget.postId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Gönderi bulunamadı.'));
          }

          final data = snap.data!.data() ?? <String, dynamic>{};

          final text = data['text']?.toString() ?? '';
          final authorName = data['authorName']?.toString() ?? 'Kullanıcı';
          final authorId = data['authorId']?.toString();
          final role = data['authorRole']?.toString() ?? 'client';

          final ts = data['createdAt'] as Timestamp?;
          final createdAt = ts?.toDate();

          final likedByRaw = data['likedBy'];
          final likedBy = likedByRaw is List
              ? likedByRaw.map((e) => e.toString()).toList()
              : <String>[];

          final likeCount = _asInt(data['likeCount'] ?? likedBy.length);
          final replyCount = _asInt(data['replyCount'] ?? 0);
          final repostCount = _asInt(data['repostCount'] ?? 0);

          final editedTs = data['editedAt'] as Timestamp?;
          final editedAt = editedTs?.toDate();

          final isOwner = currentUserId != null && currentUserId == authorId;
          final isLiked =
              currentUserId != null && likedBy.contains(currentUserId);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () =>
                                        _openAuthorProfile(authorId, role),
                                    child: CircleAvatar(
                                      child: Text(
                                        authorName.isNotEmpty
                                            ? authorName[0].toUpperCase()
                                            : '?',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          _openAuthorProfile(authorId, role),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            authorName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            role == 'expert'
                                                ? 'Uzman'
                                                : 'Danışan',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: role == 'expert'
                                                  ? Colors.deepPurple
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isOwner)
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showEditPostDialog(
                                              widget.postId, text);
                                        } else if (value == 'delete') {
                                          _confirmDeletePost(widget.postId);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Düzenle'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Sil'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                text,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 12),
                              if (createdAt != null)
                                Text(
                                  _formatDateTime(createdAt) +
                                      (editedAt != null
                                          ? ' · düzenlendi'
                                          : ''),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Text(
                                    '$replyCount Yanıt',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    '$repostCount Repost',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    '$likeCount Beğeni',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.mode_comment_outlined,
                                    ),
                                    onPressed: () {},
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.repeat),
                                    onPressed: () {
                                      // Şimdilik boş bırakıyoruz.
                                      // İstersen bir sonraki adımda repost’u da repo’ya ekleriz.
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isLiked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isLiked ? Colors.red : null,
                                    ),
                                    onPressed: () {
                                      if (currentUserId != null) {
                                        _postRepo.toggleLike(
                                          postId: widget.postId,
                                          userId: currentUserId,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Yanıtlar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),

                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _postRepo.watchReplies(widget.postId),
                        builder: (context, replySnap) {
                          if (replySnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (!replySnap.hasData ||
                              replySnap.data!.docs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Henüz yanıt yok. İlk yorumu sen yaz.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          final replies = replySnap.data!.docs;

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: replies.length,
                            itemBuilder: (context, index) {
                              final rData =
                                  replies[index].data() ?? <String, dynamic>{};
                              final rText = rData['text']?.toString() ?? '';
                              final rAuthor =
                                  rData['authorName']?.toString() ??
                                      'Kullanıcı';
                              final rTs = rData['createdAt'] as Timestamp?;
                              final rDate = rTs?.toDate();

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  child: Text(
                                    rAuthor.isNotEmpty
                                        ? rAuthor[0].toUpperCase()
                                        : '?',
                                  ),
                                ),
                                title: Text(rAuthor),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(rText),
                                    if (rDate != null)
                                      Text(
                                        _formatDateTime(rDate),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              SafeArea(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: const Border(
                      top: BorderSide(color: Colors.grey),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyCtrl,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Yanıt yaz...',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: _sendingReply
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.send),
                        onPressed: _sendingReply ? null : _sendReply,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
