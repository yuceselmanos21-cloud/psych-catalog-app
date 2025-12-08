import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_post_repository.dart';
import '../repositories/firestore_test_repository.dart';
import '../repositories/firestore_user_repository.dart';

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
  final _testRepo = FirestoreTestRepository();
  final _userRepo = FirestoreUserRepository();

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
      final data = await _userRepo.getUser(user.uid);

      if (!mounted) return;
      setState(() {
        _uid = user.uid;
        _userData = data;
        _loading = false;
      });

      _fillControllersFromData(data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
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
      await _userRepo.updateUserProfile(
        uid: _uid!,
        city: _cityCtrl.text,
        specialties: _specialtiesCtrl.text,
        about: _aboutCtrl.text,
        profession: _selectedProfession,
      );

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
      stream: _testRepo.watchTestsByCreator(_uid!),
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

        final docs = snap.data!.docs.toList();

        docs.sort((a, b) {
          final aTs = a.data()['createdAt'] as Timestamp?;
          final bTs = b.data()['createdAt'] as Timestamp?;
          final aTime =
              aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        final limited = docs.take(5).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: limited.length,
          itemBuilder: (context, index) {
            final doc = limited[index];
            final data = doc.data();

            final title = data['title']?.toString() ?? 'Adsız test';
            final desc = data['description']?.toString() ?? '';

            final testMap = {
              'id': doc.id,
              ...data,
            };

            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title),
              subtitle: desc.isEmpty
                  ? null
                  : Text(
                desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/solveTest',
                  arguments: testMap,
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
      stream: _testRepo.watchSolvedTestsByUser(_uid!),
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

        final docs = snap.data!.docs.toList();
        final limited = docs.take(5).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: limited.length,
          itemBuilder: (context, index) {
            final data = limited[index].data();

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
                          'Bu paylaşımı silmek istediğine emin misin?',
                        ),
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

  // ---------- UI Helpers ----------

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Widget _statMini(String label, int value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(bool isExpert) {
    final bg = isExpert ? Colors.deepPurple.shade50 : Colors.blueGrey.shade50;
    final fg = isExpert ? Colors.deepPurple : Colors.blueGrey;

    return Chip(
      avatar: Icon(
        isExpert ? Icons.verified : Icons.person_outline,
        size: 16,
        color: fg,
      ),
      label: Text(
        isExpert ? 'Uzman' : 'Danışan',
        style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600),
      ),
      backgroundColor: bg,
      side: BorderSide(color: fg.withOpacity(0.35)),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: Colors.deepPurple),
                  const SizedBox(width: 6),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            child,
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

  // ---------- BUILD ----------

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

    final followersCount = _asInt(data['followersCount']);
    final followingCount = _asInt(data['followingCount']);

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
            // -------- HEADER --------
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
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
                  const SizedBox(height: 10),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRoleChip(isExpert),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16),
                          const SizedBox(width: 4),
                          Text(city),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ✅ MINI FOLLOW STATS
            Row(
              children: [
                _statMini('Takipçi', followersCount),
                const SizedBox(width: 8),
                _statMini('Takip', followingCount),
              ],
            ),

            const SizedBox(height: 16),

            // -------- GENEL BİLGİLER --------
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
                    _buildInfoRow('Rol', isExpert ? 'Uzman' : 'Danışan'),
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

            // -------- UZMAN BİLGİLERİ --------
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
                  label:
                  Text(_saving ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet'),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // -------- AKTİVİTELER --------
            _sectionCard(
              title: 'Aktivitelerim',
              icon: Icons.auto_awesome,
              child: const SizedBox.shrink(),
            ),

            const SizedBox(height: 8),

            if (isExpert) ...[
              _sectionCard(
                title: 'Oluşturduğum Testler',
                icon: Icons.note_add,
                child: _buildMyCreatedTests(),
              ),
              const SizedBox(height: 10),
            ],

            _sectionCard(
              title: 'Çözdüğüm Testlerim',
              icon: Icons.fact_check_outlined,
              child: _buildMySolvedTests(),
            ),

            const SizedBox(height: 10),

            if (isExpert)
              _sectionCard(
                title: 'Paylaşımlarım',
                icon: Icons.forum_outlined,
                child: _buildMyPosts(),
              ),
          ],
        ),
      ),
    );
  }
}
