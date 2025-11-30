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

  // Yeni paylaşım için controller
  final TextEditingController _postCtrl = TextEditingController();
  bool _posting = false;

  // Gönderi tipi: text / image / video / audio
  String _selectedType = 'text';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
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
      setState(() {
        _role = data?['role'] ?? 'client';
        _name = data?['name'] ?? 'Kullanıcı';
        _loading = false;
      });
    } catch (e) {
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

  // 🔹 Uzman / Danışan için üstteki kısayol butonları
  Widget _buildRoleActions(bool isExpert) {
    if (isExpert) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
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
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/analysis');
            },
            icon: const Icon(Icons.psychology),
            label: const Text('AI Analiz'),
          ),
        ],
      );
    } else {
      // Danışan aksiyonları
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
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
        ],
      );
    }
  }

  // 🔹 Uzmanın yeni paylaşım oluşturma alanı
  Widget _buildPostComposer() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yeni Paylaşım',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Gönderi tipi seçim butonları
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

            // Şimdilik media yok ama "varmış gibi" his
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

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _posting = true;
    });

    try {
      await FirebaseFirestore.instance.collection('posts').add({
        'text': text,
        'authorId': user.uid,
        'authorName': _name ?? 'Uzman',
        'authorRole': _role ?? 'expert',
        'type': _selectedType, // 🔥 gönderi tipi kaydediliyor
        'createdAt': FieldValue.serverTimestamp(),
      });

      _postCtrl.clear();
      setState(() {
        _selectedType = 'text';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım yapılamadı: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _posting = false;
        });
      }
    }
  }

  // 🔹 Tüm kullanıcıların gördüğü sosyal akış
  Widget _buildFeedList() {
    return StreamBuilder<QuerySnapshot>(
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
            final data = doc.data() as Map<String, dynamic>? ?? {};

            final text = data['text']?.toString() ?? '';
            final authorName = data['authorName']?.toString() ?? 'Kullanıcı';
            final role = data['authorRole']?.toString() ?? 'client';
            final ts = data['createdAt'] as Timestamp?;
            final createdAt = ts?.toDate();
            final postType = data['type']?.toString() ?? 'text';

            final isExpertPost = role == 'expert';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üstte profil bilgisi
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
                        if (createdAt != null)
                          Text(
                            _formatDateTime(createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Açıklama / metin kısmı
                    if (text.isNotEmpty) Text(text),

                    const SizedBox(height: 8),

                    // Gönderi tipine göre sahte medya alanları
                    if (postType == 'image') _buildFakeImageBox(),
                    if (postType == 'video') _buildFakeVideoBox(),
                    if (postType == 'audio') _buildFakeAudioBox(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

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
            // Rol bilgisi
            Text(
              'Rolün: ${isExpert ? 'Uzman' : 'Danışan'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),

            // Uzman/Danışan kısa yolları
            _buildRoleActions(isExpert),
            const SizedBox(height: 16),

            // Uzman ise paylaşım kutusu
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

            // Akış
            Expanded(
              child: _buildFeedList(),
            ),
          ],
        ),
      ),
    );
  }
}
