import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

import '../repositories/firestore_follow_repository.dart';
import '../repositories/firestore_post_repository.dart';
import '../repositories/firestore_test_repository.dart';
import '../repositories/firestore_user_repository.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';

// ✅ Admin Panel ekranı (yeni)
import 'admin/admin_dashboard_screen.dart';
import 'users_list_screen.dart';
import 'ai_consultations_screen.dart';

// ✅ Cache helper class for admin status
class _CachedAdminStatus {
  final bool isAdmin;
  final DateTime timestamp;
  _CachedAdminStatus(this.isAdmin, this.timestamp);
  static const _cacheTTL = Duration(minutes: 5);
  bool get isValid => DateTime.now().difference(timestamp) < _cacheTTL;
}

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

  bool _adminChecked = false;
  bool _isAdmin = false;
  
  // ✅ Admin cache (UID bazlı)
  static final Map<String, _CachedAdminStatus> _adminCache = {};

  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _specialtiesCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _educationCtrl = TextEditingController();

  // ✅ Fotoğraf yükleme için
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _uploadingPhoto = false;
  bool _uploadingCover = false;

  final FirestorePostRepository _postRepo = FirestorePostRepository.instance;
  final FirestoreTestRepository _testRepo = FirestoreTestRepository();
  final FirestoreUserRepository _userRepo = FirestoreUserRepository();
  final FirestoreFollowRepository _followRepo = FirestoreFollowRepository();
  
  // ✅ PostCard için gerekli veriler
  List<String> _myFollowingIds = [];
  String? _currentUserRole;
  
  // ✅ Input sanitization helper
  String _sanitizeInput(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '') // HTML tag'lerini kaldır
        .trim();
  }

  final List<String> _professionOptions = const [
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

  Future<void> _loadFollowingIds() async {
    if (_uid == null) return;
    try {
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid!)
          .collection('following')
          .get();
      if (mounted) {
        setState(() {
          _myFollowingIds = followingSnapshot.docs.map((doc) => doc.id).toList();
        });
      }
    } catch (_) {
      // Hata durumunda boş liste
      if (mounted) {
        setState(() => _myFollowingIds = []);
      }
    }
  }

  Future<void> _checkAdmin(String uid) async {
    try {
      // ✅ Cache kontrolü
      final cached = _adminCache[uid];
      if (cached != null && cached.isValid) {
        if (!mounted) return;
        setState(() {
          _isAdmin = cached.isAdmin;
          _adminChecked = true;
        });
        return;
      }
      
      // Önce users koleksiyonundan role kontrolü yap
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userRole = userDoc.data()?['role'] as String?;
      
      // Sonra admins koleksiyonunu kontrol et
      final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
      if (!mounted) return;
      
      final isAdmin = adminDoc.exists || userRole == 'admin';
      
      // Cache'e kaydet
      _adminCache[uid] = _CachedAdminStatus(isAdmin, DateTime.now());
      
      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
        _adminChecked = true;
      });
    } catch (e) {
      // Admin doc okunamazsa (rules/bağlantı vs), admin sayma.
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _adminChecked = true;
      });
    }
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
        _currentUserRole = data['role'] as String?;
        _loading = false;
      });

      _fillControllersFromData(data);

      // ✅ Admin kontrolü (profil ekranından admin panel butonu için)
      await _checkAdmin(user.uid);
      // ✅ Following listesini yükle
      await _loadFollowingIds();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil yüklenemedi: $e')),
      );
    }
  }

  void _fillControllersFromData(Map<String, dynamic> data) {
    _nameCtrl.text = data['name']?.toString() ?? '';
    _usernameCtrl.text = data['username']?.toString() ?? '';
    _cityCtrl.text = data['city']?.toString() ?? '';
    _specialtiesCtrl.text = data['specialties']?.toString() ?? '';
    _aboutCtrl.text = data['about']?.toString() ?? '';
    _educationCtrl.text = data['education']?.toString() ?? '';
    _selectedProfession = data['profession']?.toString();
  }

  Future<void> _saveProfile() async {
    if (_uid == null) return;

    // ✅ Input validation ve sanitization
    final name = _sanitizeInput(_nameCtrl.text);
    final username = _sanitizeInput(_usernameCtrl.text);
    final city = _sanitizeInput(_cityCtrl.text);
    final specialties = _sanitizeInput(_specialtiesCtrl.text);
    final about = _sanitizeInput(_aboutCtrl.text);
    final education = _sanitizeInput(_educationCtrl.text);
    
    // ✅ Validation
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad soyad boş olamaz.')),
      );
      return;
    }
    
    if (name.length > 100) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad soyad 100 karakterden uzun olamaz.')),
      );
      return;
    }
    
    if (username.isNotEmpty && username.length < 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı adı en az 3 karakter olmalıdır.')),
      );
      return;
    }
    
    if (username.length > 30) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı adı 30 karakterden uzun olamaz.')),
      );
      return;
    }
    
    if (username.isNotEmpty && !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı adı sadece harf, rakam ve alt çizgi içerebilir.')),
      );
      return;
    }
    
    if (city.length > 50) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şehir adı 50 karakterden uzun olamaz.')),
      );
      return;
    }
    
    if (specialties.length > 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uzmanlık alanları 200 karakterden uzun olamaz.')),
      );
      return;
    }
    
    if (about.length > 500) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hakkımda bölümü 500 karakterden uzun olamaz.')),
      );
      return;
    }
    
    if (education.length > 500) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eğitim ve Sertifikalar 500 karakterden uzun olamaz.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _userRepo.updateUserProfile(
        uid: _uid!,
        name: name,
        username: username.isNotEmpty ? username : null,
        city: city,
        specialties: specialties,
        about: about,
        profession: _selectedProfession,
        education: education,
      );

      await _loadUser();
      if (!mounted) return;

      setState(() => _editing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil güncellendi.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil güncellenemedi: ${errorMessage.length > 60 ? errorMessage.substring(0, 60) + "..." : errorMessage}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  // ✅ Fotoğraf yükleme fonksiyonları
  Future<void> _pickAndUploadProfilePhoto() async {
    if (_uid == null || _uploadingPhoto) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: false,
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final ext = path.extension(file.path).toLowerCase();

      // ✅ Resmi sıkıştır
      File? compressedFile;
      if (['.jpg', '.jpeg', '.png', '.heic', '.webp'].contains(ext)) {
        final compressed = await FlutterImageCompress.compressAndGetFile(
          file.path,
          file.path.replaceFirst(ext, '_compressed.jpg'),
          quality: 80,
          minWidth: 512,
        );
        compressedFile = compressed != null ? File(compressed.path) : file;
      } else {
        compressedFile = file;
      }

      if (!mounted) return;
      setState(() => _uploadingPhoto = true);

      // ✅ Storage'a yükle
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('profile_photos/$_uid/$fileName');
      await ref.putFile(compressedFile);
      final photoUrl = await ref.getDownloadURL();

      // ✅ Firestore'u güncelle
      await _userRepo.updatePhotoUrl(uid: _uid!, photoUrl: photoUrl);

      // ✅ Kullanıcı verilerini yeniden yükle
      await _loadUser();

      if (!mounted) return;
      setState(() => _uploadingPhoto = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil fotoğrafı güncellendi.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf yüklenemedi: ${e.toString().length > 60 ? e.toString().substring(0, 60) + "..." : e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pickAndUploadCoverPhoto() async {
    if (_uid == null || _uploadingCover) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: false,
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final ext = path.extension(file.path).toLowerCase();

      // ✅ Resmi sıkıştır (kapak fotoğrafı için daha büyük boyut)
      File? compressedFile;
      if (['.jpg', '.jpeg', '.png', '.heic', '.webp'].contains(ext)) {
        final compressed = await FlutterImageCompress.compressAndGetFile(
          file.path,
          file.path.replaceFirst(ext, '_compressed.jpg'),
          quality: 85,
          minWidth: 1280,
        );
        compressedFile = compressed != null ? File(compressed.path) : file;
      } else {
        compressedFile = file;
      }

      if (!mounted) return;
      setState(() => _uploadingCover = true);

      // ✅ Storage'a yükle
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('cover_photos/$_uid/$fileName');
      await ref.putFile(compressedFile);
      final coverUrl = await ref.getDownloadURL();

      // ✅ Firestore'u güncelle
      await _userRepo.updateCoverPhotoUrl(uid: _uid!, coverPhotoUrl: coverUrl);

      // ✅ Kullanıcı verilerini yeniden yükle
      await _loadUser();

      if (!mounted) return;
      setState(() => _uploadingCover = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kapak fotoğrafı güncellendi.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingCover = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kapak fotoğrafı yüklenemedi: ${e.toString().length > 60 ? e.toString().substring(0, 60) + "..." : e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _cityCtrl.dispose();
    _specialtiesCtrl.dispose();
    _aboutCtrl.dispose();
    _educationCtrl.dispose();
    super.dispose();
  }

  // ---------- UI/UX HELPER METODLAR ----------
  
  /// ✅ Profesyonel loading state (skeleton loader)
  Widget _buildLoadingState({String? message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 2.5,
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// ✅ Profesyonel empty state
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColor ?? Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// ✅ Profesyonel error state (retry butonlu)
  Widget _buildErrorState({
    required String message,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Yeniden Dene'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- AKTİVİTELER: TESTLER & POSTLAR ----------

  Widget _buildMyCreatedTests() {
    if (_uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _testRepo.watchTestsByCreator(_uid!),
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildErrorState(
            message: 'Testler yüklenirken hata oluştu.',
            onRetry: () => setState(() {}),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(message: 'Testler yükleniyor...');
        }

        final docs = snap.data?.docs.toList() ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.quiz_outlined,
            title: 'Henüz test oluşturmadın',
            subtitle: 'İlk testini oluşturarak başla!',
            iconColor: Colors.deepPurple.shade300,
          );
        }

        docs.sort((a, b) {
          final aTs = a.data()['createdAt'] as Timestamp?;
          final bTs = b.data()['createdAt'] as Timestamp?;
          final aTime = aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();

            final title = data['title']?.toString() ?? 'Adsız test';
            final desc = data['description']?.toString() ?? '';

            final testMap = {
              'id': doc.id,
              ...data,
            };

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.quiz_outlined,
                    color: Colors.deepPurple.shade700,
                    size: 24,
                  ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: desc.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                ),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/solveTest',
                    arguments: testMap,
                  );
                },
              ),
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
          return _buildErrorState(
            message: 'Çözdüğün testler yüklenirken hata oluştu.',
            onRetry: () => setState(() {}),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(message: 'Testler yükleniyor...');
        }

        final docs = snap.data?.docs.toList() ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Henüz test çözmedin',
            subtitle: 'Testleri çözerek kendini değerlendir!',
            iconColor: Colors.blue.shade300,
          );
        }

        // ✅ Tarihe göre sırala (en yeni önce)
        docs.sort((a, b) {
          final aTs = a.data()['createdAt'] as Timestamp?;
          final bTs = b.data()['createdAt'] as Timestamp?;
          final aTime = aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();

            final title = data['testTitle']?.toString() ?? 'Test sonucu';
            final ts = data['createdAt'] as Timestamp?;
            final dt = ts?.toDate();

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.assignment_turned_in_outlined,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: dt == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _formatDateTime(dt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                ),
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
              ),
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

  Widget _buildAboutTab(String specialties, String about, String education, String? cvUrl, bool isExpert) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hakkımda
          if (about.isNotEmpty) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Hakkımda',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      about,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Uzmanlık Alanı (sadece expert için)
          if (isExpert && specialties.isNotEmpty && specialties != 'Belirtilmemiş') ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.work_outline, size: 20, color: Colors.purple.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Uzmanlık Alanı',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      specialties,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Eğitim ve Sertifikalar
          if (education.isNotEmpty) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school_outlined, size: 20, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Eğitim ve Sertifikalar',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      education,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // CV
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: cvUrl != null && cvUrl.isNotEmpty
                ? InkWell(
                    onTap: () {
                      // CV'yi açmak için URL'yi kullan
                      // TODO: PDF viewer veya browser açılabilir
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.picture_as_pdf, size: 28, color: Colors.red.shade700),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CV',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'CV belgenizi görüntülemek için tıklayın',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.picture_as_pdf, size: 28, color: Colors.grey.shade400),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CV',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'CV eklenmedi',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    if (_uid == null) return const SizedBox.shrink();

    // ✅ Kullanıcının orijinal postları, repost'ları ve quote'larını göster
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _postRepo.watchUserPostsAndReposts(_uid!, limit: 50),
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildErrorState(
            message: 'Paylaşımlar yüklenirken hata oluştu.',
            onRetry: () => setState(() {}),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(message: 'Paylaşımlar yükleniyor...');
        }

        final allDocs = snap.data?.docs ?? const [];
        
        // ✅ OPTIMIZE: Client-side filtreleme (authorId veya repostedByUserId eşit olanları göster)
        // ✅ PERFORMANCE: Önce hızlı kontroller, sonra string karşılaştırmaları
        final filteredDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          // ✅ Hızlı kontroller önce
          if (data['isComment'] == true || data['deleted'] == true) return false;
          
          // ✅ String karşılaştırmaları
          final authorId = data['authorId'] as String?;
          final repostedByUserId = data['repostedByUserId'] as String?;
          
          // Kullanıcının orijinal postları, repost'ları veya quote'ları
          return authorId == _uid || repostedByUserId == _uid;
        }).toList();
        
        // ✅ OPTIMIZE: Tarihe göre sırala (en yeni önce)
        filteredDocs.sort((a, b) {
          final aTs = a.data()['createdAt'] as Timestamp?;
          final bTs = b.data()['createdAt'] as Timestamp?;
          final aTime = aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        
        // ✅ Limit uygula (performans için)
        const int displayLimit = 30;
        final limitedDocs = filteredDocs.take(displayLimit).toList();
        
        if (limitedDocs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.forum_outlined,
            title: 'Henüz paylaşım yapmadın',
            subtitle: 'İlk paylaşımını yaparak başla!',
            iconColor: Colors.deepPurple.shade300,
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Column içinde scroll yapmaması için
          itemCount: limitedDocs.length,
          itemBuilder: (context, index) {
            try {
              final post = Post.fromFirestore(limitedDocs[index]);
              return PostCard(
                post: post,
                myFollowingIds: _myFollowingIds,
                currentUserRole: _currentUserRole,
              );
            } catch (e) {
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  Widget _buildCommentsTab() {
    if (_uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _postRepo.watchCommentsByAuthor(_uid!, limit: 50),
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildErrorState(
            message: 'Yorumlar yüklenirken hata oluştu.',
            onRetry: () => setState(() {}),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(message: 'Yorumlar yükleniyor...');
        }

        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.comment_outlined,
            title: 'Henüz yorum yapmadın',
            subtitle: 'İlk yorumunu yaparak başla!',
            iconColor: Colors.orange.shade300,
          );
        }

        // ✅ Performance: ListView.builder kullan (Column.map yerine)
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            try {
              final post = Post.fromFirestore(docs[index]);
              return PostCard(
                post: post,
                myFollowingIds: _myFollowingIds,
                currentUserRole: _currentUserRole,
              );
            } catch (e) {
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  Widget _buildLikedPostsTab() {
    if (_uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(_uid!).snapshots(),
      builder: (context, userSnap) {
        final hideLikes = (userSnap.data?.data()?['hideLikes'] as bool?) ?? false;

        return Column(
          children: [
            // ✅ Beğenileri Gizle/Göster Toggle
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 0.5,
                child: SwitchListTile(
                  title: const Text('Beğenilerimi Gizle'),
                  subtitle: Text(
                    hideLikes
                        ? 'Beğenileriniz diğer kullanıcılara gösterilmiyor.'
                        : 'Beğenileriniz herkese açık.',
                  ),
                  value: hideLikes,
                  onChanged: (value) async {
                    try {
                      await _userRepo.updateHideLikes(uid: _uid!, hideLikes: value);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ayar güncellenemedi: ${e.toString()}'),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),

            // ✅ Beğeniler Listesi
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _postRepo.watchLikedPostsByUser(_uid!, limit: 50),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _buildErrorState(
                    message: 'Beğeniler yüklenirken hata oluştu.',
                    onRetry: () => setState(() {}),
                  );
                }

                if (snap.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState(message: 'Beğeniler yükleniyor...');
                }

                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.favorite_border,
                    title: 'Henüz beğenin yok',
                    subtitle: 'Beğendiğin içerikler burada görünecek',
                    iconColor: Colors.pink.shade300,
                  );
                }

                // ✅ Performance: ListView.builder kullan
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    try {
                      final post = Post.fromFirestore(docs[index]);
                      return PostCard(
                        post: post,
                        myFollowingIds: _myFollowingIds,
                        currentUserRole: _currentUserRole,
                      );
                    } catch (e) {
                      return const SizedBox.shrink();
                    }
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAIConsultationsTab() {
    if (_uid == null) return const SizedBox.shrink();
    
    return const AIConsultationsScreen(hideAppBar: true);
  }

  Widget _buildSavedPostsTab() {
    if (_uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _postRepo.watchSavedPostsByUser(_uid!, limit: 50),
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildErrorState(
            message: 'Kaydedilenler yüklenirken hata oluştu.',
            onRetry: () => setState(() {}),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(message: 'Kaydedilenler yükleniyor...');
        }

        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.bookmark_border,
            title: 'Henüz kaydettiğin içerik yok',
            subtitle: 'Beğendiğin içerikleri kaydet ve kolayca bul!',
            iconColor: Colors.amber.shade300,
          );
        }

        // ✅ Performance: ListView.builder kullan
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            try {
              final post = Post.fromFirestore(docs[index]);
              return PostCard(
                post: post,
                myFollowingIds: _myFollowingIds,
                currentUserRole: _currentUserRole,
              );
            } catch (e) {
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
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

        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Text(
            'Henüz paylaşım yapmadın.',
            style: TextStyle(color: Colors.grey),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            try {
              final post = Post.fromFirestore(doc);
              return PostCard(
                post: post,
                myFollowingIds: _myFollowingIds,
                currentUserRole: _currentUserRole,
              );
            } catch (e) {
              return const SizedBox.shrink();
            }
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

  Widget _statMini(String label, int value, {String? userId, bool isFollowers = false}) {
    return GestureDetector(
      onTap: userId != null
        ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UsersListScreen(
                  userId: userId,
                  isFollowersList: isFollowers,
                ),
              ),
            );
          }
        : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

  Widget _statMiniStream(String label, Stream<int> stream, {String? userId, bool isFollowers = false}) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snap) {
        final value = snap.data ?? 0;
        return GestureDetector(
          onTap: userId != null
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UsersListScreen(
                        userId: userId,
                        isFollowersList: isFollowers,
                      ),
                    ),
                  );
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
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
      },
    );
  }

  Widget _buildEditField({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildReadOnlyField(String text, {bool isEmpty = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: isEmpty ? Colors.grey.shade500 : Colors.black87,
          fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
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
          child: Text(value, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  // ✅ Profil header (kapak fotoğrafı ve profil bilgileri)
  Widget _buildProfileHeader(
    String name,
    String? photoUrl,
    String? coverUrl,
    String role,
    String profession,
    String city,
    bool isExpert,
    int followersFallback,
    int followingFallback,
    String? username,
  ) {
    return Column(
      children: [
        // ✅ Kapak fotoğrafı (sadece fotoğraf, üstünde hiçbir şey yok)
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            image: coverUrl != null && coverUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(coverUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: coverUrl == null || coverUrl.isEmpty
              ? Center(
                  child: Icon(
                    Icons.wallpaper_rounded,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                )
              : null,
        ),
        
        // ✅ Profil bilgileri (kapak fotoğrafının altında)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol taraf: Profil fotoğrafı ve bilgiler
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Profil fotoğrafı
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      backgroundColor: Colors.grey.shade200,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 28),
                            )
                          : null,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Bilgiler (meslek, isim+username, şehir)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Meslek + Admin
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            profession,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (role == 'admin') ...[
                            const SizedBox(width: 6),
                            Text(
                              'admin',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.purple.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      // İsim + Username
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (username != null && username.trim().isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '@$username',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.purple,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Şehir
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.purple.shade400),
                          const SizedBox(width: 4),
                          Text(
                            city,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.purple.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Sağ taraf: İstatistikler (ortalanmış)
              _uid != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _statMiniStream(
                          'Takipçi',
                          _followRepo.watchFollowersCount(_uid!),
                          userId: _uid!,
                          isFollowers: true,
                        ),
                        const SizedBox(width: 16),
                        _statMiniStream(
                          'Takip',
                          _followRepo.watchFollowingCount(_uid!),
                          userId: _uid!,
                          isFollowers: false,
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _statMini('Takipçi', followersFallback),
                        const SizedBox(width: 16),
                        _statMini('Takip', followingFallback),
                      ],
                    ),
            ],
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
    final username = data['username']?.toString();
    final role = (data['role'] ?? 'client').toString();
    final isExpert = role == 'expert';

    final city = data['city']?.toString() ?? 'Belirtilmemiş';
    final profession = data['profession']?.toString() ?? 'Belirtilmemiş';
    final specialties = data['specialties']?.toString() ?? 'Belirtilmemiş';
    final education = data['education']?.toString() ?? '';
    final about =
        data['about']?.toString() ?? 'Henüz kendin hakkında bilgi eklemedin.';

    final photoUrl = data['photoUrl']?.toString();
    final coverUrl = data['coverUrl']?.toString();
    final cvUrl = data['cvUrl']?.toString();

    final followersFallback = _asInt(data['followersCount']);
    final followingFallback = _asInt(data['followingCount']);

    // ✅ Tab sayısı: Bio, Paylaşımlar, Yorumlar, Yayınladığı Testler (sadece expert/admin), Çözdüğü Testler, AI Danışmalarım, Beğeniler, Kaydedilenler
    final tabCount = isExpert || role == 'admin' ? 8 : 7;
    
    return DefaultTabController(
      length: tabCount,
      animationDuration: const Duration(milliseconds: 200), // Daha hızlı geçiş
      child: PopScope(
        canPop: !_editing, // Düzenleme modundaysa geri butonunu engelle
        onPopInvoked: (didPop) {
          if (!didPop && _editing) {
            // Düzenleme modundaysa sadece düzenlemeyi kapat
            if (!mounted) return;
            setState(() {
              _editing = false;
              _fillControllersFromData(data);
            });
          }
        },
        child: Scaffold(
        appBar: AppBar(
          title: const Text('Profilim'),
          actions: [
            if (_editing)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Düzenlemeyi iptal et',
                onPressed: () {
                  if (!mounted) return;
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
                  if (!mounted) return;
                  setState(() {
                    _editing = true;
                    _fillControllersFromData(data);
                  });
                },
              ),
          ],
        ),
        body: _editing 
            ? _buildEditBody(data, name, role, isExpert, city, profession, specialties, about, photoUrl, coverUrl, cvUrl, education, followersFallback, followingFallback, username) 
            : Column(
                children: [
                  _buildProfileHeader(name, photoUrl, coverUrl, role, profession, city, isExpert, followersFallback, followingFallback, username),
                  
                  // ✅ Tab bar (diğer profillerle aynı yerde)
                  TabBar(
                    isScrollable: true,
                    tabs: [
                      const Tab(text: 'Bio', icon: Icon(Icons.person_outline)),
                      const Tab(text: 'Paylaşımlar', icon: Icon(Icons.forum_outlined)),
                      const Tab(text: 'Yorumlar', icon: Icon(Icons.comment_outlined)),
                      if (isExpert || role == 'admin')
                        const Tab(text: 'Oluşturduğum Testler', icon: Icon(Icons.quiz_outlined)),
                      const Tab(text: 'Çözdüğü Testler', icon: Icon(Icons.assignment_turned_in_outlined)),
                      const Tab(text: 'AI\'a Danıştıklarım', icon: Icon(Icons.psychology_outlined)),
                      const Tab(text: 'Beğeniler', icon: Icon(Icons.favorite_outline)),
                      const Tab(text: 'Kaydedilenler', icon: Icon(Icons.bookmark_outline)),
                    ],
                  ),
                  
                  // ✅ Tab bar içeriği
                  Expanded(
                    child: TabBarView(
                      physics: const BouncingScrollPhysics(), // Daha smooth scroll
                      children: [
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: _buildAboutTab(specialties, about, education, cvUrl, isExpert),
                        ),
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: _buildPostsTab(),
                        ),
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: _buildCommentsTab(),
                        ),
                        if (isExpert || role == 'admin')
                          SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: _buildMyCreatedTests(),
                          ),
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: _buildMySolvedTests(),
                        ),
                        _buildAIConsultationsTab(),
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: _buildLikedPostsTab(),
                        ),
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: _buildSavedPostsTab(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildEditBody(Map<String, dynamic> data, String name, String role, bool isExpert, String city, String profession, String specialties, String about, String? photoUrl, String? coverUrl, String? cvUrl, String education, int followersFallback, int followingFallback, String? username) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------- HEADER --------
            // ✅ Kapak fotoğrafı
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                image: coverUrl != null && coverUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(coverUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (coverUrl == null || coverUrl.isEmpty)
                    Center(
                      child: Icon(
                        Icons.wallpaper_rounded,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: ElevatedButton.icon(
                      onPressed: _uploadingCover ? null : _pickAndUploadCoverPhoto,
                      icon: _uploadingCover
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt, size: 18),
                      label: Text(_uploadingCover ? 'Yükleniyor...' : 'Kapak Fotoğrafı'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // ✅ Profil fotoğrafı
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                    backgroundColor: Colors.grey.shade300,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 36),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: IconButton(
                        onPressed: _uploadingPhoto ? null : _pickAndUploadProfilePhoto,
                        icon: _uploadingPhoto
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Column(
                children: [
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
                      if (role == 'admin') ...[
                        const SizedBox(width: 6),
                        Text(
                          'admin',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16),
                          const SizedBox(width: 4),
                          Text(city),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ✅ ADMIN PANEL BUTONU (her zaman görünür, tıklanınca kontrol yapılır)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _adminChecked && _isAdmin
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminDashboardScreen(),
                          ),
                        );
                      }
                    : _adminChecked
                        ? null // Admin değilse disabled
                        : () async {
                            // Henüz kontrol edilmediyse kontrol et
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await _checkAdmin(user.uid);
                              if (_isAdmin && mounted) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AdminDashboardScreen(),
                                  ),
                                );
                              }
                            }
                          },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _adminChecked && _isAdmin 
                      ? Colors.red 
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Icon(
                  Icons.admin_panel_settings,
                  color: _adminChecked && _isAdmin ? Colors.white : Colors.grey.shade400,
                ),
                label: Text(
                  _adminChecked 
                      ? (_isAdmin ? 'Admin Paneli' : 'Admin Değilsiniz')
                      : 'Admin Kontrolü...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _adminChecked && _isAdmin ? Colors.white : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // -------- FOLLOW STATS --------
            if (_uid != null)
              Row(
                children: [
                  _statMiniStream(
                    'Takipçi',
                    _followRepo.watchFollowersCount(_uid!),
                    userId: _uid!,
                    isFollowers: true,
                  ),
                  const SizedBox(width: 8),
                  _statMiniStream(
                    'Takip',
                    _followRepo.watchFollowingCount(_uid!),
                    userId: _uid!,
                    isFollowers: false,
                  ),
                ],
              )
            else
              Row(
                children: [
                  _statMini('Takipçi', followersFallback),
                  const SizedBox(width: 8),
                  _statMini('Takip', followingFallback),
                ],
              ),

            const SizedBox(height: 16),

            // -------- DÜZENLENEBİLİR BİLGİLER --------
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Profil Bilgileri',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Ad Soyad
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Ad Soyad',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _editing
                              ? TextField(
                                  controller: _nameCtrl,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    hintText: 'Adınız ve soyadınız',
                                  ),
                                )
                              : Text(
                                  name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Username
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Kullanıcı Adı',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _editing
                              ? TextField(
                                  controller: _usernameCtrl,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    hintText: 'Kullanıcı adınız (isteğe bağlı)',
                                    prefixText: '@',
                                  ),
                                )
                              : Text(
                                  username != null && username.isNotEmpty ? '@$username' : 'Belirtilmemiş',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: username != null && username.isNotEmpty ? Colors.purple : Colors.grey,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Meslek (sadece expert için)
                    if (isExpert) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              'Meslek',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _editing
                                ? DropdownButtonFormField<String>(
                                    value: _selectedProfession?.isNotEmpty == true
                                        ? _selectedProfession
                                        : null,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    items: _professionOptions
                                        .map((p) => DropdownMenuItem<String>(
                                              value: p,
                                              child: Text(p),
                                            ))
                                        .toList(),
                                    onChanged: (val) => setState(() => _selectedProfession = val),
                                  )
                                : Text(
                                    profession,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Şehir
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Şehir',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _editing
                              ? TextField(
                                  controller: _cityCtrl,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                )
                              : Text(
                                  city,
                                  style: const TextStyle(fontSize: 14),
                                ),
                        ),
                      ],
                    ),
                    
                    // Uzmanlık Alanı (sadece expert için)
                    if (isExpert) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              'Uzmanlık Alanı',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _editing
                                ? TextField(
                                    controller: _specialtiesCtrl,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    maxLines: 2,
                                  )
                                : Text(
                                    specialties,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Hakkımda
                    const SizedBox(height: 20),
                    _buildEditField(
                      label: 'Hakkımda',
                      icon: Icons.person_outline,
                      child: _editing
                          ? TextField(
                              controller: _aboutCtrl,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              maxLines: 4,
                            )
                          : _buildReadOnlyField(about),
                    ),
                    
                    // Eğitim ve Sertifikalar
                    const SizedBox(height: 20),
                    _buildEditField(
                      label: 'Eğitim ve Sertifikalar',
                      icon: Icons.school_outlined,
                      child: _editing
                          ? TextField(
                              controller: _educationCtrl,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                hintText: 'Aldığınız eğitimler ve sertifikalar',
                              ),
                              maxLines: 4,
                            )
                          : _buildReadOnlyField(
                              education.isNotEmpty ? education : 'Henüz eklenmemiş',
                              isEmpty: education.isEmpty,
                            ),
                    ),
                    
                    // CV
                    if (cvUrl != null && cvUrl.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildEditField(
                        label: 'CV',
                        icon: Icons.picture_as_pdf,
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf, size: 20, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'CV belgeniz yüklü',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Kaydet butonu (düzenleme modunda)
            if (_editing) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: Text(
                    _saving ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
