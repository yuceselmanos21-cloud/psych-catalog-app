import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_post_repository.dart';
import '../repositories/firestore_user_repository.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String? _role; // 'expert' / 'client'
  String? _name;
  bool _loading = true;

  final TextEditingController _postCtrl = TextEditingController();
  bool _posting = false;

  String _selectedType = 'text';

  final FirestorePostRepository _postRepo = FirestorePostRepository();
  final FirestoreUserRepository _userRepo = FirestoreUserRepository();

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    try {
      final data = await _userRepo.getUser(user.uid);

      if (!mounted) return;
      setState(() {
        _role = (data['role'] ?? 'client').toString();
        _name = (data['name'] ?? 'Kullanıcı').toString();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _role = 'client';
        _name = 'Kullanıcı';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  // ---------- ROL BUTONLARI ----------
  Widget _buildRoleActions(bool isExpert) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/tests'),
          icon: const Icon(Icons.playlist_add_check),
          label: const Text('Test Çöz'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/solvedTests'),
          icon: const Icon(Icons.history),
          label: const Text('Çözdüğüm Testler'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/analysis'),
          icon: const Icon(Icons.psychology),
          label: const Text('AI Analiz'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/experts'),
          icon: const Icon(Icons.groups),
          label: const Text('Uzmanları Keşfet'),
        ),
        if (isExpert) ...[
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/createTest'),
            icon: const Icon(Icons.note_add),
            label: const Text('Test Oluştur'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/expertTests'),
            icon: const Icon(Icons.list_alt),
            label: const Text('Oluşturduğum Testler'),
          ),
        ],
      ],
    );
  }

  // ---------- POST COMPOSER (UZMAN) ----------
  Widget _buildPostComposer() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yeni Gönderi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTypeChip('text', Icons.text_fields, 'Metin'),
                _buildTypeChip('image', Icons.image, 'Fotoğraf'),
                _buildTypeChip('video', Icons.videocam, 'Video'),
                _buildTypeChip('audio', Icons.graphic_eq, 'Ses'),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _postCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _selectedType == 'text'
                    ? 'Danışanlara veya diğer uzmanlara yönelik bir paylaşım yaz...'
                    : 'Paylaşım için açıklama / not yaz...',
                border: const OutlineInputBorder(),
              ),
            ),
            if (_selectedType != 'text') ...[
              const SizedBox(height: 6),
              _buildComingSoonRow(_selectedType),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _posting ? null : _submitPost,
                icon: _posting
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.send),
                label: Text(_posting ? 'Gönderiliyor...' : 'Paylaş'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComingSoonRow(String type) {
    IconData icon;
    String text;
    switch (type) {
      case 'image':
        icon = Icons.image_outlined;
        text = 'Fotoğraf eklenecek (ileride).';
        break;
      case 'video':
        icon = Icons.videocam_outlined;
        text = 'Video eklenecek (ileride).';
        break;
      default:
        icon = Icons.audiotrack_outlined;
        text = 'Ses eklenecek (ileride).';
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String value, IconData icon, String label) {
    final isSelected = _selectedType == value;
    final fg = isSelected ? Colors.white : Colors.grey[700];

    return ChoiceChip(
      selected: isSelected,
      selectedColor: Colors.deepPurple,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: fg),
          ),
        ],
      ),
      onSelected: (_) => setState(() => _selectedType = value),
    );
  }

  // ✅ REPO
  Future<void> _submitPost() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty) return;

    final user = _currentUser;
    if (user == null) return;

    setState(() => _posting = true);

    try {
      await _postRepo.sendPost(
        text,
        authorId: user.uid,
        authorName: _name ?? 'Kullanıcı',
        authorRole: _role ?? 'client',
        type: _selectedType,
      );

      _postCtrl.clear();
      if (mounted) {
        setState(() => _selectedType = 'text');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım yapılamadı: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _posting = false);
    }
  }

  // ---------- FEED LİSTESİ ----------
  Widget _buildFeedList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _postRepo.watchFeed(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Akış yüklenirken bir hata oluştu.'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Center(child: Text('Henüz hiç paylaşım yok.'));
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildPostCard(docs[index]),
        );
      },
    );
  }

  // ---------- POST CARD ----------
  Widget _buildPostCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    final text = data['text']?.toString() ?? '';
    final authorName = data['authorName']?.toString() ?? 'Kullanıcı';
    final authorId = data['authorId']?.toString();
    final role = data['authorRole']?.toString() ?? 'client';
    final postType = data['type']?.toString() ?? 'text';

    final ts = data['createdAt'] as Timestamp?;
    final createdAt = ts?.toDate();

    final editedTs = data['editedAt'] as Timestamp?;
    final editedAt = editedTs?.toDate();

    final likedByRaw = data['likedBy'];
    final List<String> likedBy = likedByRaw is List
        ? likedByRaw.map((e) => e.toString()).toList()
        : <String>[];

    final likeCount = _asInt(data['likeCount'] ?? likedBy.length);
    final replyCount = _asInt(data['replyCount'] ?? 0);
    final repostCount = _asInt(data['repostCount'] ?? 0);

    final isExpertPost = role == 'expert';
    final currentUserId = _currentUser?.uid;
    final isLiked = currentUserId != null && likedBy.contains(currentUserId);
    final isOwner = currentUserId != null && currentUserId == authorId;

    return InkWell(
      onTap: () => _openPostDetail(doc.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPostHeader(
                authorName: authorName,
                authorId: authorId,
                isExpertPost: isExpertPost,
                createdAt: createdAt,
                editedAt: editedAt,
                isOwner: isOwner,
                postId: doc.id,
                text: text,
              ),
              const SizedBox(height: 8),
              if (text.isNotEmpty) Text(text),
              const SizedBox(height: 8),
              if (postType == 'image') _buildFakeImageBox(),
              if (postType == 'video') _buildFakeVideoBox(),
              if (postType == 'audio') _buildFakeAudioBox(),
              const SizedBox(height: 8),
              _buildPostActions(
                postId: doc.id,
                text: text,
                type: postType,
                replyCount: replyCount,
                repostCount: repostCount,
                likeCount: likeCount,
                isLiked: isLiked,
                currentUserId: currentUserId,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostHeader({
    required String authorName,
    required String? authorId,
    required bool isExpertPost,
    required DateTime? createdAt,
    required DateTime? editedAt,
    required bool isOwner,
    required String postId,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _openAuthorProfile(authorId, isExpertPost ? 'expert' : 'client'),
          child: CircleAvatar(
            child: Text(
              authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => _openAuthorProfile(authorId, isExpertPost ? 'expert' : 'client'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authorName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  isExpertPost ? 'Uzman' : 'Danışan',
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpertPost ? Colors.deepPurple : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (createdAt != null)
          Text(
            _formatDate(createdAt) + (editedAt != null ? ' · düzenlendi' : ''),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        if (isOwner)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditPostDialog(postId, text);
              } else if (value == 'delete') {
                _confirmDeletePost(postId);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Düzenle')),
              PopupMenuItem(value: 'delete', child: Text('Sil')),
            ],
          ),
      ],
    );
  }

  Widget _buildPostActions({
    required String postId,
    required String text,
    required String type,
    required int replyCount,
    required int repostCount,
    required int likeCount,
    required bool isLiked,
    required String? currentUserId,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionButton(
          icon: Icons.mode_comment_outlined,
          label: replyCount > 0 ? replyCount.toString() : '',
          onTap: () => _openPostDetail(postId),
        ),
        _buildActionButton(
          icon: Icons.repeat,
          label: repostCount > 0 ? repostCount.toString() : '',
          onTap: () => _handleRepost(
            originalPostId: postId,
            text: text,
            type: type,
          ),
        ),
        _buildActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: likeCount > 0 ? likeCount.toString() : '',
          iconColor: isLiked ? Colors.red : Colors.grey[700],
          onTap: () async {
            if (currentUserId == null) return;
            try {
              await _postRepo.toggleLike(
                postId: postId,
                userId: currentUserId,
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Beğeni güncellenemedi: $e')),
              );
            }
          },
        ),
      ],
    );
  }

  Future<void> _handleRepost({
    required String originalPostId,
    required String text,
    required String type,
  }) async {
    final user = _currentUser;
    if (user == null) return;

    try {
      await _postRepo.repostPost(
        originalPostId: originalPostId,
        text: text,
        type: type,
        authorId: user.uid,
        authorName: _name ?? 'Kullanıcı',
        authorRole: _role ?? 'client',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Repost yapılamadı: $e')),
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    String label = '',
    Color? iconColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? Colors.grey[700]),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openPostDetail(String postId) {
    Navigator.pushNamed(
      context,
      '/postDetail',
      arguments: postId,
    );
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
          decoration: const InputDecoration(border: OutlineInputBorder()),
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
                if (mounted) Navigator.pop(ctx);
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

  void _openAuthorProfile(String? authorId, String role) {
    if (authorId == null) return;
    final currentUserId = _currentUser?.uid;

    if (role == 'expert') {
      Navigator.pushNamed(
        context,
        '/publicExpertProfile',
        arguments: authorId,
      );
      return;
    }

    if (currentUserId != null && currentUserId == authorId) {
      Navigator.pushNamed(context, '/profile');
    }
  }

  // ---------- SAHTE MEDYA ----------
  Widget _buildFakeImageBox() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.image, size: 48, color: Colors.black54),
      ),
    );
  }

  Widget _buildFakeVideoBox() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_fill, size: 56, color: Colors.white),
      ),
    );
  }

  Widget _buildFakeAudioBox() {
    return Container(
      height: 64,
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

  // ---------- HELPERS ----------
  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }

  @override
  void dispose() {
    _postCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isExpert = _role == 'expert';

    return Scaffold(
      appBar: AppBar(
        title: Text('Hoş geldin, ${_name ?? ''}'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/profile'),
            icon: const Icon(Icons.person),
            tooltip: 'Profilim',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış yap',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rolün: ${isExpert ? 'Uzman' : 'Danışan'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildRoleActions(isExpert),
            const SizedBox(height: 16),
            if (isExpert) ...[
              _buildPostComposer(),
              const SizedBox(height: 16),
            ],
            const Text(
              'Sosyal Akış',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildFeedList()),
          ],
        ),
      ),
    );
  }
}
