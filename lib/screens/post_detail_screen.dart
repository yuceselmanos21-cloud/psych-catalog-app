import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  final TextEditingController _commentCtrl = TextEditingController();

  bool _sendingComment = false;
  bool _initialLikeLoaded = false;
  bool _hasLiked = false;
  bool _likeBusy = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadLikeState();
  }

  Future<void> _loadLikeState() async {
    final user = _user;
    if (user == null) return;

    try {
      final likeDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('likes')
          .doc(user.uid)
          .get();

      if (!mounted) return;
      setState(() {
        _hasLiked = likeDoc.exists;
        _initialLikeLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initialLikeLoaded = true;
      });
    }
  }

  Future<void> _toggleLike(
      DocumentReference<Map<String, dynamic>> postRef) async {
    final user = _user;
    if (user == null || _likeBusy) return;

    setState(() {
      _likeBusy = true;
    });

    final likeRef = postRef.collection('likes').doc(user.uid);
    final newLiked = !_hasLiked;

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final postSnap = await tx.get(postRef);
        final data = postSnap.data() ?? <String, dynamic>{};
        final currentCount = (data['likeCount'] as int?) ?? 0;

        if (newLiked) {
          tx.set(likeRef, {
            'userId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.update(postRef, {
            'likeCount': currentCount + 1,
          });
        } else {
          tx.delete(likeRef);
          tx.update(postRef, {
            'likeCount': currentCount > 0 ? currentCount - 1 : 0,
          });
        }
      });

      if (mounted) {
        setState(() {
          _hasLiked = newLiked;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Beğeni güncellenemedi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _likeBusy = false;
        });
      }
    }
  }

  Future<void> _sendComment(
      DocumentReference<Map<String, dynamic>> postRef) async {
    final user = _user;
    if (user == null) return;

    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _sendingComment = true;
    });

    try {
      final commentsCol = postRef.collection('comments');

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final postSnap = await tx.get(postRef);
        final data = postSnap.data() ?? <String, dynamic>{};
        final currentCount = (data['commentCount'] as int?) ?? 0;

        tx.set(commentsCol.doc(), {
          'userId': user.uid,
          'userName': user.displayName ?? 'Kullanıcı',
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.update(postRef, {
          'commentCount': currentCount + 1,
        });
      });

      _commentCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yorum gönderilemedi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingComment = false;
        });
      }
    }
  }

  Future<void> _deletePost(
      DocumentReference<Map<String, dynamic>> postRef) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gönderiyi sil'),
        content: const Text(
          'Bu gönderiyi silmek istediğinden emin misin? İşlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Sil',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await postRef.delete();
      if (mounted) {
        Navigator.of(context).pop(); // Feed'e geri dön
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gönderi silinemedi: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postRef =
    FirebaseFirestore.instance.collection('posts').doc(widget.postId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paylaşım'),
      ),
      body: Column(
        children: [
          // Üstte: gönderi + yorum listesi (scrollable)
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: postRef.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || !snap.data!.exists) {
                  return const Center(child: Text('Gönderi bulunamadı.'));
                }

                final data = snap.data!.data() ?? <String, dynamic>{};
                final text = data['text']?.toString() ?? '';
                final authorName =
                    data['authorName']?.toString() ?? 'Kullanıcı';
                final authorRole =
                    data['authorRole']?.toString() ?? 'client';
                final authorId = data['authorId']?.toString();
                final createdTs = data['createdAt'] as Timestamp?;
                final created = createdTs?.toDate();
                final likeCount = (data['likeCount'] as int?) ?? 0;
                final commentCount = (data['commentCount'] as int?) ?? 0;

                final isExpert = authorRole == 'expert';
                final isMine = _user != null && authorId == _user!.uid;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // --- Gönderi kartı ---
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Üst satır: avatar + isim + tarih + (sil butonu)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  child: Text(
                                    authorName.isNotEmpty
                                        ? authorName[0].toUpperCase()
                                        : '?',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: isExpert && authorId != null
                                            ? () {
                                          Navigator.pushNamed(
                                            context,
                                            '/publicExpertProfile',
                                            arguments: authorId,
                                          );
                                        }
                                            : null,
                                        child: Text(
                                          authorName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isExpert
                                                ? Colors.deepPurple
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        isExpert ? 'Uzman' : 'Danışan',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isExpert
                                              ? Colors.deepPurple
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (created != null)
                                  Text(
                                    _formatDateTime(created),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                if (isMine)
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deletePost(postRef);
                                      }
                                    },
                                    itemBuilder: (ctx) => const [
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Gönderiyi sil'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            if (text.isNotEmpty)
                              Text(
                                text,
                                style: const TextStyle(fontSize: 15),
                              ),

                            const SizedBox(height: 12),

                            // Beğeni & yorum sayısı + beğen butonu
                            Row(
                              children: [
                                IconButton(
                                  onPressed: (!_initialLikeLoaded || _likeBusy)
                                      ? null
                                      : () => _toggleLike(postRef),
                                  icon: Icon(
                                    _hasLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: _hasLiked
                                        ? Colors.red
                                        : Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  '$likeCount',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.mode_comment_outlined,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$commentCount',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Yorumlar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // --- Yorumlar listesi ---
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: postRef
                          .collection('comments')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, commentSnap) {
                        if (commentSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (!commentSnap.hasData ||
                            commentSnap.data!.docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Henüz yorum yok. İlk yorumu sen yaz!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        final docs = commentSnap.data!.docs;

                        return Column(
                          children: docs.map((d) {
                            final cData = d.data();
                            final cText =
                                cData['text']?.toString() ?? '';
                            final cUserName =
                                cData['userName']?.toString() ??
                                    'Kullanıcı';
                            final cTs =
                            cData['createdAt'] as Timestamp?;
                            final cDate = cTs?.toDate();

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                child: Text(
                                  cUserName.isNotEmpty
                                      ? cUserName[0].toUpperCase()
                                      : '?',
                                ),
                              ),
                              title: Text(
                                cUserName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(cText),
                                  if (cDate != null)
                                    Text(
                                      _formatDateTime(cDate),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),

          // Alt kısım: yorum yazma alanı
          SafeArea(
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: const Border(
                  top: BorderSide(color: Colors.black12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Yorum yaz...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendingComment
                        ? null
                        : () => _sendComment(postRef),
                    icon: _sendingComment
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }
}
