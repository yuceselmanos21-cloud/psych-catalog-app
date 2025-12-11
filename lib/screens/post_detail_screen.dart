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

  final FirestorePostRepository _postRepo = FirestorePostRepository();

  String _currentUserName = 'Kullanıcı';
  String _currentUserRole = 'client';

  final Set<String> _expandedReplyIds = {};

  // Web rebuild kaynaklı listen/unlisten riskini azaltmak için stream cache
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _postStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _allRepliesStream;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _postStream = _postRepo.watchPost(widget.postId);
    _allRepliesStream = _postRepo.watchAllRepliesForPost(widget.postId);
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

  // ---------------- SAFE DIALOG CLOSE ----------------
  void _closeDialogIfOpen() {
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }

  // ---------------- HELPERS ----------------
  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  DateTime _tsToDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Map<String?, List<QueryDocumentSnapshot<Map<String, dynamic>>>> _groupByParent(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final map = <String?, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    for (final d in docs) {
      final data = d.data();
      final parent = data['parentReplyId'];
      final parentId = parent == null ? null : parent.toString();

      map.putIfAbsent(parentId, () => []);
      map[parentId]!.add(d);
    }

    // createdAt desc
    for (final entry in map.entries) {
      entry.value.sort((a, b) {
        final ad = _tsToDate(a.data()['createdAt']);
        final bd = _tsToDate(b.data()['createdAt']);
        return bd.compareTo(ad);
      });
    }

    return map;
  }

  // ---------------- POST ACTIONS ----------------
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
      if (mounted) FocusScope.of(context).unfocus();
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
    if (user == null || _reposting) return;

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

  void _showEditPostDialog(String postId, String currentText) {
    final controller = TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
            onPressed: _closeDialogIfOpen,
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isEmpty) return;

              // await öncesi kapat
              _closeDialogIfOpen();

              try {
                await _postRepo.updatePostText(
                  postId: postId,
                  newText: newText,
                );
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
      builder: (_) => AlertDialog(
        title: const Text('Gönderiyi sil'),
        content: const Text('Bu gönderiyi silmek istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: _closeDialogIfOpen,
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              _closeDialogIfOpen();

              try {
                await _postRepo.deletePost(postId);
                if (!mounted) return;
                Navigator.of(context).pop(); // detail ekranını kapat
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

  // ---------------- REPLY ACTIONS ----------------
  void _confirmDeleteReply({
    required String replyId,
    required bool hasChildren,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yorumu sil'),
        content: Text(
          hasChildren
              ? 'Bu yorumun yanıtları var. Silersen yorum içeriği kaldırılır, yanıtlar korunur.'
              : 'Bu yorumu silmek istediğine emin misin?',
        ),
        actions: [
          TextButton(
            onPressed: _closeDialogIfOpen,
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = _currentUser?.uid;
              if (userId == null) return;

              // await öncesi kapat
              _closeDialogIfOpen();

              try {
                await _postRepo.deleteReply(
                  postId: widget.postId,
                  replyId: replyId,
                  userId: userId,
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Yorum silinemedi: $e')),
                );
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReplyToReplyDialog(String parentReplyId) async {
    final ctrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(true),
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

  // ---------------- SAHTE MEDYA ----------------
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

  // ---------------- REPLY CARD (recursive) ----------------
  Widget _buildReplyCard(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      Map<String?, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped, {
        int depth = 0,
      }) {
    final data = doc.data();
    final replyId = doc.id;

    final text = data['text']?.toString() ?? '';
    final authorName = data['authorName']?.toString() ?? 'Kullanıcı';
    final authorId = data['authorId']?.toString();

    final createdAt = _tsToDate(data['createdAt']);

    final likeCount = _asInt(data['likeCount']);
    final dislikeCount = _asInt(data['dislikeCount']);
    final childCount = _asInt(data['replyCount']);

    final likedByRaw = data['likedBy'];
    final dislikedByRaw = data['dislikedBy'];

    final List<String> likedBy =
    likedByRaw is List ? likedByRaw.map((e) => e.toString()).toList() : [];

    final List<String> dislikedBy = dislikedByRaw is List
        ? dislikedByRaw.map((e) => e.toString()).toList()
        : [];

    final currentUserId = _currentUser?.uid;
    final isLiked = currentUserId != null && likedBy.contains(currentUserId);
    final isDisliked =
        currentUserId != null && dislikedBy.contains(currentUserId);

    final isOwner = currentUserId != null && authorId == currentUserId;

    final expanded = _expandedReplyIds.contains(replyId);
    final leftPad = 8.0 + (depth * 14.0);

    final children = grouped[replyId] ?? const [];
    final hasChildren = children.isNotEmpty || childCount > 0;

    final bool isDeleted = data['deleted'] == true || text == '[Silindi]';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.only(left: leftPad),
        child: Card(
          elevation: 0.4,
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
                        authorName.isNotEmpty
                            ? authorName[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authorName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      _formatDateTime(createdAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    if (isOwner)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == 'delete') {
                            _confirmDeleteReply(
                              replyId: replyId,
                              hasChildren: hasChildren,
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Sil'),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (text.isNotEmpty)
                  Text(
                    text,
                    style: isDeleted
                        ? const TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    )
                        : null,
                  ),

                const SizedBox(height: 8),

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
                          : () async {
                        try {
                          await _postRepo.toggleReplyLike(
                            postId: widget.postId,
                            replyId: replyId,
                            userId: currentUserId,
                          );
                        } catch (_) {}
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
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
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
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
                          : () async {
                        try {
                          await _postRepo.toggleReplyDislike(
                            postId: widget.postId,
                            replyId: replyId,
                            userId: currentUserId,
                          );
                        } catch (_) {}
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.thumb_down_alt_outlined,
                              size: 16,
                              color:
                              isDisliked ? Colors.red : Colors.grey[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dislikeCount.toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    if (hasChildren)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            expanded
                                ? _expandedReplyIds.remove(replyId)
                                : _expandedReplyIds.add(replyId);
                          });
                        },
                        child: Text(
                          expanded
                              ? 'Yanıtları gizle'
                              : 'Yanıtları gör (${children.length})',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),

                if (expanded) ...[
                  const SizedBox(height: 6),
                  if (children.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(left: 6, bottom: 4),
                      child: Text(
                        'Henüz yanıt yok.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    )
                  else
                    Column(
                      children: children
                          .map((c) => _buildReplyCard(
                        c,
                        grouped,
                        depth: depth + 1,
                      ))
                          .toList(),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gönderi'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _postStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return const Center(child: Text('Gönderi yüklenirken hata oluştu.'));
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

          final createdAt = data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : null;

          final editedAt = (data['editedAt'] as Timestamp?)?.toDate();

          final likedByRaw = data['likedBy'];
          final List<String> likedBy = likedByRaw is List
              ? likedByRaw.map((e) => e.toString()).toList()
              : [];

          final likeCount = _asInt(data['likeCount'] ?? likedBy.length);
          final replyCount = _asInt(data['replyCount'] ?? 0);
          final repostCount = _asInt(data['repostCount'] ?? 0);

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
                                        Text(
                                          authorName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          role == 'expert' ? 'Uzman' : 'Danışan',
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
                                        Icons.mode_comment_outlined),
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
                                    onPressed: currentUserId == null
                                        ? null
                                        : () async {
                                      try {
                                        await _postRepo.toggleLike(
                                          postId: widget.postId,
                                          userId: currentUserId,
                                        );
                                      } catch (_) {}
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

                      // -------- Replies Tree (single stream) --------
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _allRepliesStream,
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

                          if (replySnap.hasError) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Yorumlar yüklenirken hata oluştu.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          final allReplies = replySnap.data?.docs ?? [];
                          if (allReplies.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Henüz yorum yok. İlk yorumu sen yaz.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          final grouped = _groupByParent(allReplies);
                          final topLevel = grouped[null] ?? const [];

                          return Column(
                            children: topLevel
                                .map((r) => _buildReplyCard(
                              r,
                              grouped,
                              depth: 0,
                            ))
                                .toList(),
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
