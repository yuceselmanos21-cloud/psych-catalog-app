import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  // Gönderi tipi: text / image / video / audio
  String _selectedType = 'text';

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
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data();
      if (!mounted) return;

      setState(() {
        _role = data?['role'] ?? 'client';
        _name = data?['name'] ?? 'Kullanıcı';
        _loading = false;
      });
    } catch (e) {
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

  // ---------- ROL BUTONLARI (Test, AI vs.) ----------
  Widget _buildRoleActions(bool isExpert) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // ORTAK BUTONLAR (UZMAN + DANIŞAN)
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, '/tests');
          },
          icon: const Icon(Icons.playlist_add_check),
          label: const Text('Test Çöz'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, '/solvedTests');
          },
          icon: const Icon(Icons.history),
          label: const Text('Çözdüğüm Testler'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, '/analysis');
          },
          icon: const Icon(Icons.psychology),
          label: const Text('AI Analiz'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, '/experts');
          },
          icon: const Icon(Icons.groups),
          label: const Text('Uzmanları Keşfet'),
        ),

        // SADECE UZMANLAR
        if (isExpert) ...[
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/createTest');
            },
            icon: const Icon(Icons.note_add),
            label: const Text('Test Oluştur'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/expertTests');
            },
            icon: const Icon(Icons.list_alt),
            label: const Text('Oluşturduğum Testler'),
          ),
        ],
      ],
    );
  }

  // ---------- YENİ GÖNDERİ OLUŞTURMA (SADECE UZMAN) ----------
  Widget _buildPostComposer() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yeni Gönderi',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Gönderi tipi
            Row(
              children: [
                _buildTypeChip('text', Icons.text_fields, 'Metin'),
                const SizedBox(width: 8),
                _buildTypeChip('image', Icons.image, 'Fotoğraf'),
                const SizedBox(width: 8),
                _buildTypeChip('video', Icons.videocam, 'Video'),
                const SizedBox(width: 8),
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

            const SizedBox(height: 6),

            // Şimdilik medya yok, ama varmış gibi his verelim
            if (_selectedType != 'text')
              Row(
                children: [
                  Icon(
                    _selectedType == 'image'
                        ? Icons.image_outlined
                        : _selectedType == 'video'
                        ? Icons.videocam_outlined
                        : Icons.audiotrack_outlined,
                    size: 18,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedType == 'image'
                        ? 'Fotoğraf eklenecek (ileride).'
                        : _selectedType == 'video'
                        ? 'Video eklenecek (ileride).'
                        : 'Ses kaydı eklenecek (ileride).',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),

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

  Widget _buildTypeChip(String value, IconData icon, String label) {
    final isSelected = _selectedType == value;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selectedColor: Colors.deepPurple,
      onSelected: (_) {
        setState(() {
          _selectedType = value;
        });
      },
    );
  }

  Future<void> _submitPost() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty) return;

    final user = _currentUser;
    if (user == null) return;

    setState(() {
      _posting = true;
    });

    try {
      await FirebaseFirestore.instance.collection('posts').add({
        'text': text,
        'authorId': user.uid,
        'authorName': _name ?? 'Kullanıcı',
        'authorRole': _role ?? 'expert',
        'type': _selectedType,
        'createdAt': FieldValue.serverTimestamp(),

        // Twitter-vari alanlar (başlangıç değerleri)
        'likeCount': 0,
        'replyCount': 0,
        'repostCount': 0,
        'quoteCount': 0,
        'likedBy': <String>[],
        'repostOfPostId': null,
        'editedAt': null,
      });

      _postCtrl.clear();
      setState(() {
        _selectedType = 'text';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım yapılamadı: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _posting = false;
      });
    }
  }

  // ---------- FEED LİSTESİ ----------
  Widget _buildFeedList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('Henüz hiç paylaşım yok.'),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            return _buildPostCard(doc);
          },
        );
      },
    );
  }

  // ---------- TEK BİR GÖNDERİ KARTI (Twitter tarzı) ----------
  Widget _buildPostCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    final text = data['text']?.toString() ?? '';
    final authorName = data['authorName']?.toString() ?? 'Kullanıcı';
    final authorId = data['authorId']?.toString();
    final role = data['authorRole']?.toString() ?? 'client';
    final ts = data['createdAt'] as Timestamp?;
    final createdAt = ts?.toDate();
    final postType = data['type']?.toString() ?? 'text';

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

    final editedTs = data['editedAt'] as Timestamp?;
    final editedAt = editedTs?.toDate();

    return InkWell(
      onTap: () {
        // Gönderi detay sayfasına git
        Navigator.pushNamed(
          context,
          '/postDetail',
          arguments: doc.id,
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst satır: avatar + isim + rol + tarih
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      _openAuthorProfile(authorId, role);
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
                      onTap: () {
                        _openAuthorProfile(authorId, role);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isExpertPost ? 'Uzman' : 'Danışan',
                            style: TextStyle(
                              fontSize: 12,
                              color: isExpertPost
                                  ? Colors.deepPurple
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (createdAt != null)
                    Text(
                      _formatDateTime(createdAt) +
                          (editedAt != null ? ' · düzenlendi' : ''),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  if (isOwner)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditPostDialog(doc.id, text);
                        } else if (value == 'delete') {
                          _confirmDeletePost(doc.id);
                        }
                      },
                      itemBuilder: (context) => [
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

              const SizedBox(height: 8),

              // Metin
              if (text.isNotEmpty) Text(text),

              const SizedBox(height: 8),

              // Gönderi tipine göre sahte medya alanları
              if (postType == 'image') _buildFakeImageBox(),
              if (postType == 'video') _buildFakeVideoBox(),
              if (postType == 'audio') _buildFakeAudioBox(),

              const SizedBox(height: 8),

              // Aksiyon butonları (yorum / repost / beğeni)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildActionButton(
                    icon: Icons.mode_comment_outlined,
                    label: replyCount > 0 ? replyCount.toString() : '',
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/postDetail',
                        arguments: doc.id,
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.repeat,
                    label: repostCount > 0 ? repostCount.toString() : '',
                    onTap: () {
                      _repostPost(doc.id, data);
                    },
                  ),
                  _buildActionButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    label: likeCount > 0 ? likeCount.toString() : '',
                    iconColor: isLiked ? Colors.red : Colors.grey[700],
                    onTap: () {
                      if (currentUserId != null) {
                        _toggleLike(doc.id, currentUserId, isLiked);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- AKSİYON BUTONU WIDGET ----------
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

  // ---------- LIKE / REPOST / PROFİL AÇMA ----------

  Future<void> _toggleLike(
      String postId, String userId, bool currentlyLiked) async {
    final ref = FirebaseFirestore.instance.collection('posts').doc(postId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>? ?? {};
      final raw = data['likedBy'];
      final likedBy = raw is List
          ? raw.map((e) => e.toString()).toList()
          : <String>[];

      int likeCount = _asInt(data['likeCount'] ?? likedBy.length);

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
        likeCount = likeCount > 0 ? likeCount - 1 : 0;
      } else {
        likedBy.add(userId);
        likeCount = likeCount + 1;
      }

      tx.update(ref, {
        'likedBy': likedBy,
        'likeCount': likeCount,
      });
    });
  }

  Future<void> _repostPost(
      String originalPostId, Map<String, dynamic> originalData) async {
    final user = _currentUser;
    if (user == null) return;

    try {
      // Orijinal gönderinin repostCount'unu arttır
      final originalRef =
      FirebaseFirestore.instance.collection('posts').doc(originalPostId);
      await originalRef.update({
        'repostCount': FieldValue.increment(1),
      });

      // Kullanıcı kendi feed'ine repost olarak yeni bir kayıt eklesin
      await FirebaseFirestore.instance.collection('posts').add({
        'text': originalData['text']?.toString() ?? '',
        'authorId': user.uid,
        'authorName': _name ?? 'Kullanıcı',
        'authorRole': _role ?? 'client',
        'type': originalData['type'] ?? 'text',
        'createdAt': FieldValue.serverTimestamp(),
        'repostOfPostId': originalPostId,

        'likeCount': 0,
        'replyCount': 0,
        'repostCount': 0,
        'quoteCount': 0,
        'likedBy': <String>[],
        'editedAt': null,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Repost yapılamadı: $e')),
      );
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
      // Kendi profili
      Navigator.pushNamed(context, '/profile');
    } else {
      // Şimdilik başka client profili yok, dokunma
    }
  }

  // ---------- DÜZENLE / SİL ----------
  void _showEditPostDialog(String postId, String currentText) {
    final controller = TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
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
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newText = controller.text.trim();
                if (newText.isEmpty) return;

                try {
                  await FirebaseFirestore.instance
                      .collection('posts')
                      .doc(postId)
                      .update({
                    'text': newText,
                    'editedAt': FieldValue.serverTimestamp(),
                  });
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
        );
      },
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
                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .delete();
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

  // ---------- SAHTE MEDYA BOX'LAR ----------
  Widget _buildFakeImageBox() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(
          Icons.image,
          size: 48,
          color: Colors.black54,
        ),
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
        child: Icon(
          Icons.play_circle_fill,
          size: 56,
          color: Colors.white,
        ),
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
      child: Row(
        children: const [
          Icon(Icons.graphic_eq, color: Colors.deepPurple),
          SizedBox(width: 8),
          Text('Ses kaydı (örnek alan)'),
          Spacer(),
          Icon(Icons.play_arrow),
        ],
      ),
    );
  }

  // ---------- YARDIMCI FONKSİYONLAR ----------
  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  String _formatDateTime(DateTime dt) {
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
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
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

            if (isExpert) _buildPostComposer(),
            if (isExpert) const SizedBox(height: 16),

            const Text(
              'Sosyal Akış',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _buildFeedList(),
            ),
          ],
        ),
      ),
    );
  }
}
