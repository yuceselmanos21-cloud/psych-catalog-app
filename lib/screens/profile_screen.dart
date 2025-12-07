import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_post_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  String? _uid;
  Map<String, dynamic>? _userData;

  final _cityCtrl = TextEditingController();
  final _specialtiesCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();

  final _postRepo = FirestorePostRepository();

  final List<String> _professionOptions = [
    'Psikolog',
    'Klinik Psikolog',
    'Nöropsikolog',
    'Psikiyatr',
    'Psikolojik Danışman (PDR)',
    'Sosyal Hizmet Uzmanı',
    'Aile Danışmanı',
  ];
  String? _selectedProfession;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _uid = user.uid;
        _userData = data;
        _loading = false;
      });

      _fillControllersFromData(data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil yüklenemedi: $e')),
      );
    }
  }

  void _fillControllersFromData(Map<String, dynamic> data) {
    _cityCtrl.text = data['city']?.toString() ?? '';
    _specialtiesCtrl.text = data['specialties']?.toString() ?? '';
    _aboutCtrl.text = data['about']?.toString() ?? '';
    _selectedProfession = data['profession']?.toString();
  }

  Future<void> _saveProfile() async {
    if (_uid == null) return;

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'city': _cityCtrl.text.trim(),
        'specialties': _specialtiesCtrl.text.trim(),
        'about': _aboutCtrl.text.trim(),
        if (_selectedProfession != null && _selectedProfession!.isNotEmpty)
          'profession': _selectedProfession,
      });

      await _loadUser();
      if (!mounted) return;

      setState(() => _editing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil güncellendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil güncellenemedi: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _specialtiesCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  // ---------- AKTİVİTELER: TESTLER & POSTLAR ----------

  Widget _buildMyCreatedTests() {
    if (_uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tests')
          .where('createdBy', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Testler yüklenirken hata: ${snap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Text(
            'Henüz oluşturduğun test yok.',
            style: TextStyle(color: Colors.grey),
          );
        }

        final docs = snap.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final title = data['title']?.toString() ?? 'Adsız test';
            final desc = data['description']?.toString() ?? '';

            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title),
              subtitle: Text(
                desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/solveTest',
                  arguments: docs[index],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMySolvedTests() {
    if (_uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('solvedTests')
          .where('userId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Çözdüğün testler yüklenirken hata: ${snap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Text(
            'Henüz çözdüğün test yok.',
            style: TextStyle(color: Colors.grey),
          );
        }

        final docs = snap.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final title = data['testTitle']?.toString() ?? 'Test sonucu';
            final ts = data['createdAt'] as Timestamp?;
            final dt = ts?.toDate();

            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title),
              subtitle: dt == null
                  ? null
                  : Text(
                _formatDateTime(dt),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/resultDetail',
                  arguments: {
                    'testTitle': data['testTitle'],
                    'answers':
                    List<dynamic>.from(data['answers'] ?? <dynamic>[]),
                    'questions':
                    List<dynamic>.from(data['questions'] ?? <dynamic>[]),
                    'createdAt': data['createdAt'],
                    'aiAnalysis': data['aiAnalysis'] ?? '',
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ✅ ARTIK REPO
  Future<void> _deletePost(String postId) async {
    try {
      await _postRepo.deletePost(postId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paylaşım silindi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım silinemedi: $e')),
      );
    }
  }

  // ✅ ARTIK REPO
  Widget _buildMyPosts() {
    if (_uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _postRepo.watchPostsByAuthor(_uid!, limit: 10),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Paylaşımlar yüklenirken hata: ${snap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Text(
            'Henüz paylaşım yapmadın.',
            style: TextStyle(color: Colors.grey),
          );
        }

        final docs = snap.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final text = data['text']?.toString() ?? '';
            final ts = data['createdAt'] as Timestamp?;
            final dt = ts?.toDate();

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/postDetail',
                    arguments: docs[index].id,
                  );
                },
                title: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: dt == null
                    ? null
                    : Text(
                  _formatDateTime(dt),
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Paylaşımı sil'),
                        content: const Text(
                            'Bu paylaşımı silmek istediğine emin misin?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Vazgeç'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Sil'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await _deletePost(docs[index].id);
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = _userData ?? <String, dynamic>{};
    final name = data['name']?.toString() ?? 'Kullanıcı';
    final role = (data['role'] ?? 'client').toString();
    final isExpert = role == 'expert';
    final city = data['city']?.toString() ?? 'Belirtilmemiş';
    final profession = data['profession']?.toString() ?? 'Belirtilmemiş';
    final specialties = data['specialties']?.toString() ?? 'Belirtilmemiş';
    final about =
        data['about']?.toString() ?? 'Henüz kendin hakkında bilgi eklemedin.';
    final photoUrl = data['photoUrl']?.toString();
    final cvUrl = data['cvUrl']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          if (_editing)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Düzenlemeyi iptal et',
              onPressed: () {
                setState(() {
                  _editing = false;
                  _fillControllersFromData(data);
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Profili düzenle',
              onPressed: () {
                setState(() {
                  _editing = true;
                  _fillControllersFromData(data);
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ÜST PROFİL BİLGİSİ
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 32),
                    )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isExpert ? 'Uzman' : 'Danışan',
                    style: TextStyle(
                      fontSize: 14,
                      color: isExpert ? Colors.deepPurple : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 4),
                      Text(city),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // GENEL BİLGİLER
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Genel Bilgiler',
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Rol',
                      isExpert ? 'Uzman' : 'Danışan',
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 110,
                          child: Text(
                            'Meslek',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _editing && isExpert
                              ? DropdownButtonFormField<String>(
                            value: _selectedProfession?.isNotEmpty == true
                                ? _selectedProfession
                                : null,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding:
                              EdgeInsets.symmetric(horizontal: 8),
                            ),
                            items: _professionOptions
                                .map(
                                  (p) => DropdownMenuItem<String>(
                                value: p,
                                child: Text(p),
                              ),
                            )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedProfession = val;
                              });
                            },
                          )
                              : Text(
                            profession,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // UZMAN BİLGİLERİ
            if (isExpert)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Uzman Bilgileri',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 110,
                            child: Text(
                              'Şehir',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _editing
                                ? TextField(
                              controller: _cityCtrl,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            )
                                : Text(
                              city,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Uzmanlık Alanı',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _editing
                          ? TextField(
                        controller: _specialtiesCtrl,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      )
                          : Text(specialties),

                      const SizedBox(height: 8),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Hakkımda',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _editing
                          ? TextField(
                        controller: _aboutCtrl,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      )
                          : Text(about),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // CV KARTI
            if (cvUrl != null && cvUrl.isNotEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('CV'),
                  subtitle: const Text('CV belgen yüklü.'),
                ),
              ),

            if (_editing) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: _saving
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.save),
                  label: Text(
                      _saving ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet'),
                ),
              ),
            ],

            const SizedBox(height: 24),

            const Text(
              'Aktivitelerim',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (isExpert) ...[
              const Text(
                'Oluşturduğum Testler',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              _buildMyCreatedTests(),
              const SizedBox(height: 16),
            ],

            const Text(
              'Çözdüğüm Testlerim',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            _buildMySolvedTests(),
            const SizedBox(height: 16),

            if (isExpert) ...[
              const Text(
                'Paylaşımlarım',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              _buildMyPosts(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
