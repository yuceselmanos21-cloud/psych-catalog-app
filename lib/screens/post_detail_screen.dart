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
  bool _reposting = false;

  final _postRepo = FirestorePostRepository();

  String _currentUserName = 'Kullanıcı';
  String _currentUserRole = 'client';

  final Set<String> _expandedReplyIds = {};

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
    } catch (_) {}
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
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
      FocusScope.of(context).unfocus();
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

  Future<void> _handleRepost({
    required String text,
    required String type,
  }) async {
    final user = _currentUser;
    if (user == null) return;

    if (_reposting) return;

    setState(() => _reposting = true);

    try {
      await _postRepo.repostPost(
        originalPostId: widget.postId,
        text: text,
        type: type,
        authorId: user.uid,
        authorName: _currentUserName,
        authorRole: _currentUserRole,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Repost yapıldı.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Repost yapılamadı: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _reposting = false);
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

  // ---------- SAHTE MEDYA ----------
  Widget _buildFakeImageBox() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.image, size: 56, color: Colors.black54),
      ),
    );
  }

  Widget _buildFakeVideoBox() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white),
      ),
    );
  }

  Widget _buildFakeAudioBox() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: const Row(
        children: [
          Icon(Icons.graphic_eq, color: Colors.deepPurple),
          SizedBox(width: 8),
          Text('Ses kaydı (örnek alan)'),
          Spacer(),
          Icon(Icons.play_arrow),
        ],
      ),
    );
  }

  // ---------- REPLY -> REPLY DIALOG ----------
  Future<void> _showReplyToReplyDialog(String parentReplyId) async {
    final ctrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yoruma Yanıt'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Yanıtını yaz...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final user = _currentUser;
    if (user == null) return;

    final text = ctrl.text.trim();
    if (text.isEmpty) return;

    try {
      await _postRepo.addChildReply(
        postId: widget.postId,
        parentReplyId: parentReplyId,
        text: text,
        authorId: user.uid,
        authorName: _currentUserName,
      );

      if (!mounted) return;
      setState(() {
        _expandedReplyIds.add(parentReplyId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yanıt eklenemedi: $e')),
      );
    }
  }

  // ---------- REPLY TILE ----------
  Widget _buildReplyCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final replyId = doc.id;
    final text = data['text']?.toString() ?? '';
    final authorName = data['authorName']?.toString() ?? 'Kullanıcı';
    final authorId = data['authorId']?.toString();

    final ts = data['createdAt'] as Timestamp?;
    final createdAt = ts?.toDate();

    final likeCount = _asInt(data['likeCount']);
    final dislikeCount = _asInt(data['dislikeCount']);
    final childCount = _asInt(data['replyCount']);

    final likedByRaw = data['likedBy'];
    final dislikedByRaw = data['dislikedBy'];

    final likedBy = likedByRaw is List
        ? likedByRaw.map((e) => e.toString()).toList()
        : <String>[];

    final dislikedBy = dislikedByRaw is List
        ? dislikedByRaw.map((e) => e.toString()).toList()
        : <String>[];

    final currentUserId = _currentUser?.uid;
    final isLiked = currentUserId != null && likedBy.contains(currentUserId);
    final isDisliked =
        currentUserId != null && dislikedBy.contains(currentUserId);

    final expanded = _expandedReplyIds.contains(replyId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    authorName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (createdAt != null)
                  Text(
                    _formatDateTime(createdAt),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (text.isNotEmpty) Text(text),

            const SizedBox(height: 8),

            // actions
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showReplyToReplyDialog(replyId),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text(
                    'Yanıtla',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),

                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: currentUserId == null
                      ? null
                      : () => _postRepo.toggleReplyLike(
                    postId: widget.postId,
                    replyId: replyId,
                    userId: currentUserId,
                  ),
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.thumb_up_alt_outlined,
                          size: 16,
                          color: isLiked ? Colors.green : Colors.grey[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          likeCount.toString(),
                          style:
                          const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: currentUserId == null
                      ? null
                      : () => _postRepo.toggleReplyDislike(
                    postId: widget.postId,
                    replyId: replyId,
                    userId: currentUserId,
                  ),
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.thumb_down_alt_outlined,
                          size: 16,
                          color: isDisliked ? Colors.red : Colors.grey[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dislikeCount.toString(),
                          style:
                          const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                if (childCount > 0)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (expanded) {
                          _expandedReplyIds.remove(replyId);
                        } else {
                          _expandedReplyIds.add(replyId);
                        }
                      });
                    },
                    child: Text(
                      expanded
                          ? 'Yanıtları gizle'
                          : 'Yanıtları gör ($childCount)',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),

            if (expanded) ...[
              const SizedBox(height: 6),
              _buildChildReplies(replyId),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChildReplies(String parentReplyId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _postRepo.watchChildReplies(
        widget.postId,
        parentReplyId,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 6),
            child: Text(
              'Henüz yanıt yok.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, i) => _buildChildReplyTile(
            parentReplyId,
            docs[i],
          ),
        );
      },
    );
  }

  Widget _buildChildReplyTile(
      String parentReplyId,
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();

    final text = data['text']?.toString() ?? '';
    final authorName = data['authorName']?.toString() ?? 'Kullanıcı';

    final ts = data['createdAt'] as Timestamp?;
    final createdAt = ts?.toDate();

    final likeCount = _asInt(data['likeCount']);
    final dislikeCount = _asInt(data['dislikeCount']);

    final likedByRaw = data['likedBy'];
    final dislikedByRaw = data['dislikedBy'];

    final likedBy = likedByRaw is List
        ? likedByRaw.map((e) => e.toString()).toList()
        : <String>[];

    final dislikedBy = dislikedByRaw is List
        ? dislikedByRaw.map((e) => e.toString()).toList()
        : <String>[];

    final currentUserId = _currentUser?.uid;
    final isLiked = currentUserId != null && likedBy.contains(currentUserId);
    final isDisliked =
        currentUserId != null && dislikedBy.contains(currentUserId);

    return Container(
      margin: const EdgeInsets.only(left: 18, bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                child: Text(
                  authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  authorName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (createdAt != null)
                Text(
                  _formatDateTime(createdAt),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (text.isNotEmpty)
            Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: currentUserId == null
                    ? null
                    : () => _postRepo.toggleChildReplyLike(
                  postId: widget.postId,
                  parentReplyId: parentReplyId,
                  replyId: doc.id,
                  userId: currentUserId,
                ),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.thumb_up_alt_outlined,
                        size: 14,
                        color: isLiked ? Colors.green : Colors.grey[700],
                      ),
                      const SizedBox(width: 3),
                      Text(
                        likeCount.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: currentUserId == null
                    ? null
                    : () => _postRepo.toggleChildReplyDislike(
                  postId: widget.postId,
                  parentReplyId: parentReplyId,
                  replyId: doc.id,
                  userId: currentUserId,
                ),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.thumb_down_alt_outlined,
                        size: 14,
                        color: isDisliked ? Colors.red : Colors.grey[700],
                      ),
                      const SizedBox(width: 3),
                      Text(
                        dislikeCount.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
          final postType = data['type']?.toString() ?? 'text';

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
                      // -------- Ana Post Kartı --------
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
                                            widget.postId,
                                            text,
                                          );
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

                              if (text.isNotEmpty)
                                Text(
                                  text,
                                  style: const TextStyle(fontSize: 16),
                                ),

                              if (text.isNotEmpty) const SizedBox(height: 12),

                              if (postType == 'image') _buildFakeImageBox(),
                              if (postType == 'video') _buildFakeVideoBox(),
                              if (postType == 'audio') _buildFakeAudioBox(),

                              if (postType != 'text')
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

                              // Sayılar
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

                              // Aksiyonlar
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.mode_comment_outlined),
                                    onPressed: () {},
                                  ),
                                  IconButton(
                                    icon: _reposting
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                        : const Icon(Icons.repeat),
                                    onPressed: _reposting
                                        ? null
                                        : () => _handleRepost(
                                      text: text,
                                      type: postType,
                                    ),
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
                        'Yorumlar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // -------- Top-level Replies --------
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
                                'Henüz yorum yok. İlk yorumu sen yaz.',
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
                              return _buildReplyCard(replies[index]);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // -------- Alt Reply Composer --------
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
                            hintText: 'Yorum yaz...',
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
                          child:
                          CircularProgressIndicator(strokeWidth: 2),
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
