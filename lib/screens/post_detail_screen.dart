import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId; // 👈 main.dart'tan gelen id

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
  bool _deleting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  /// Beğeni (like) aç / kapa
  Future<void> _toggleLike(
      DocumentSnapshot<Map<String, dynamic>> doc,
      String userId,
      ) async {
    final ref = doc.reference;
    final data = doc.data() ?? <String, dynamic>{};

    final List<dynamic> currentLikesRaw = data['likes'] ?? [];
    final likes = currentLikesRaw.map((e) => e.toString()).toList();
    final hasLiked = likes.contains(userId);

    await ref.update({
      'likes': hasLiked
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
      'likeCount': FieldValue.increment(hasLiked ? -1 : 1),
    });
  }

  /// Yorum gönder
  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final user = _currentUser;
    if (user == null) return;

    setState(() {
      _sendingComment = true;
    });

    try {
      // Kullanıcı adını çek
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final uData = userSnap.data() ?? <String, dynamic>{};
      final authorName = uData['name']?.toString() ?? 'Kullanıcı';

      final postRef =
      FirebaseFirestore.instance.collection('posts').doc(widget.postId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(postRef);
        if (!snap.exists) return;

        final commentsRef = postRef.collection('comments').doc();
        tx.set(commentsRef, {
          'text': text,
          'authorId': user.uid,
          'authorName': authorName,
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.update(postRef, {
          'commentCount': FieldValue.increment(1),
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

  /// Gönderiyi sil (sadece kendi gönderisi ise)
  Future<void> _deletePost() async {
    if (_currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gönderiyi sil'),
        content: const Text(
            'Bu gönderiyi silmek istediğine emin misin? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _deleting = true;
    });

    try {
      final postRef =
      FirebaseFirestore.instance.collection('posts').doc(widget.postId);

      await postRef.delete();
      if (mounted) {
        Navigator.pop(context); // Detay ekranından çık
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gönderi silinemedi: $e')),
        );
      }
    }
  }

  /// Gönderi metnini düzenleme
  Future<void> _editPost(String currentText) async {
    final postRef =
    FirebaseFirestore.instance.collection('posts').doc(widget.postId);

    final TextEditingController editCtrl =
    TextEditingController(text: currentText);

    final newText = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Gönderiyi düzenle'),
          content: TextField(
            controller: editCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, editCtrl.text.trim()),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    editCtrl.dispose();

    if (newText == null || newText.isEmpty) return;

    try {
      await postRef.update({
        'text': newText,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Güncellenemedi: $e')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final postDocStream = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gönderi'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: postDocStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Gönderi yüklenirken hata oluştu: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Gönderi bulunamadı.'));
          }

          final doc = snapshot.data!;
          final data = doc.data() ?? <String, dynamic>{};

          final text = data['text']?.toString() ?? '';
          final authorId = data['authorId']?.toString() ?? '';
          final authorName = data['authorName']?.toString() ?? 'Kullanıcı';
          final authorRole = data['authorRole']?.toString() ?? 'client';
          final ts = data['createdAt'] as Timestamp?;
          final createdAt = ts?.toDate();
          final List<dynamic> likesRaw = data['likes'] ?? [];
          final likes = likesRaw.map((e) => e.toString()).toList();
          final likeCount = data['likeCount'] is int ? data['likeCount'] as int : likes.length;
          final commentCount = data['commentCount'] is int
              ? data['commentCount'] as int
              : 0;
          final user = _currentUser;
          final isOwner = user != null && user.uid == authorId;
          final hasLiked = user != null && likes.contains(user.uid);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ÜST SATIR: avatar + isim + rol + menü
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: authorId.isEmpty
                                ? null
                                : () {
                              // Uzman profilini aç
                              Navigator.pushNamed(
                                context,
                                '/publicExpertProfile',
                                arguments: authorId,
                              );
                            },
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
                              onTap: authorId.isEmpty
                                  ? null
                                  : () {
                                Navigator.pushNamed(
                                  context,
                                  '/publicExpertProfile',
                                  arguments: authorId,
                                );
                              },
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
                                    authorRole == 'expert'
                                        ? 'Uzman'
                                        : 'Danışan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: authorRole == 'expert'
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
                                  _editPost(text);
                                } else if (value == 'delete') {
                                  _deletePost();
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Düzenle'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Sil'),
                                ),
                              ],
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // GÖNDERİ METNİ
                      Text(
                        text,
                        style: const TextStyle(fontSize: 16),
                      ),

                      const SizedBox(height: 12),

                      if (createdAt != null)
                        Text(
                          _formatDateTime(createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),

                      const Divider(height: 24),

                      // LIKE / COMMENT SAYILARI
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 18,
                            color: likeCount > 0
                                ? Colors.red
                                : Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text('$likeCount beğeni'),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.mode_comment_outlined,
                            size: 18,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text('$commentCount yorum'),
                        ],
                      ),

                      const Divider(height: 24),

                      // YORUM LİSTESİ
                      const Text(
                        'Yorumlar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .doc(widget.postId)
                            .collection('comments')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, commentSnap) {
                          if (commentSnap.hasError) {
                            return Padding(
                              padding:
                              const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Yorumlar yüklenirken hata: ${commentSnap.error}',
                                style:
                                const TextStyle(color: Colors.red),
                              ),
                            );
                          }

                          if (commentSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding:
                              EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (!commentSnap.hasData ||
                              commentSnap.data!.docs.isEmpty) {
                            return const Padding(
                              padding:
                              EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Henüz yorum yok. İlk yorumu sen yaz.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          final cDocs = commentSnap.data!.docs;

                          return ListView.builder(
                            shrinkWrap: true,
                            physics:
                            const NeverScrollableScrollPhysics(),
                            itemCount: cDocs.length,
                            itemBuilder: (context, index) {
                              final cData = cDocs[index].data();
                              final cText =
                                  cData['text']?.toString() ?? '';
                              final cAuthor =
                                  cData['authorName']?.toString() ??
                                      'Kullanıcı';
                              final cTs =
                              cData['createdAt'] as Timestamp?;
                              final cDate = cTs?.toDate();

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  cAuthor,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
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
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ALTTA LIKE + YORUM YAZMA ALANI
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: const Border(
                    top: BorderSide(color: Colors.grey),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: (_currentUser == null || _deleting)
                          ? null
                          : () => _toggleLike(
                        snapshot.data!,
                        _currentUser!.uid,
                      ),
                      icon: Icon(
                        hasLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color:
                        hasLiked ? Colors.red : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        enabled:
                        _currentUser != null && !_sendingComment,
                        decoration: InputDecoration(
                          hintText: _currentUser == null
                              ? 'Yorum yapmak için giriş yapın'
                              : 'Yanıt yaz...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: (_currentUser == null ||
                          _sendingComment ||
                          _deleting)
                          ? null
                          : _sendComment,
                      icon: _sendingComment
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
