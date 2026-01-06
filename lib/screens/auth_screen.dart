import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

enum AuthInitialTab { login, signup }

class AuthScreen extends StatefulWidget {
  final AuthInitialTab initialTab;

  const AuthScreen({
    super.key,
    this.initialTab = AuthInitialTab.login,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // ---- login controllers
  final _loginIdCtrl = TextEditingController(); // email OR username
  final _loginPassCtrl = TextEditingController();

  // ---- signup controllers
  final _fullNameCtrl = TextEditingController(); // isim soyisim
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController(); // şifre tekrar
  final _cityCtrl = TextEditingController();
  final _specialtiesCtrl = TextEditingController();
  final _educationCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController(); // Doğum tarihi için controller

  /// UI seçimidir:
  /// - client: normal kullanıcı
  /// - expert: uzman başvurusu (onay bekler)
  String _roleChoice = 'client';

  String? _selectedProfession;
  DateTime? _birthDate; // Doğum tarihi

  bool _loading = false;
  String? _error;
  
  // ✅ UX: Password visibility toggles
  bool _loginPasswordVisible = false;
  bool _signupPasswordVisible = false;
  bool _signupPassword2Visible = false;

  // profile / cover / cv selections (önizleme için)
  Uint8List? _profileBytes;
  String? _profileFileName;

  Uint8List? _coverBytes;
  String? _coverFileName;

  Uint8List? _cvBytes;
  String? _cvFileName;

  final List<String> _professionOptions = const [
    'Psikolog',
    'Klinik Psikolog',
    'Nöropsikolog',
    'Psikiyatr',
    'Psikolojik Danışman (PDR)',
    'Sosyal Hizmet Uzmanı',
    'Aile Danışmanı',
  ];

  // Lacivert (navy)
  static const Color _brandNavy = Color(0xFF0D1B3D);

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == AuthInitialTab.login ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();

    _loginIdCtrl.dispose();
    _loginPassCtrl.dispose();

    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    _cityCtrl.dispose();
    _specialtiesCtrl.dispose();
    _educationCtrl.dispose();
    _aboutCtrl.dispose();
    _birthDateCtrl.dispose();

    super.dispose();
  }

  // ---------------- helpers ----------------

  void _setError(String? msg) {
    if (!mounted) return;
    setState(() => _error = msg);
  }

  InputDecoration _dec(
      String label, {
        String? hint,
        Widget? prefixIcon,
        Widget? suffixIcon,
        String? helperText,
      }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      helperText: helperText,
      helperMaxLines: 2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _errorBox() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.25)),
        ),
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.deepPurple.withOpacity(0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  String _normalizeUsername(String raw) => raw.trim().toLowerCase();

  bool _isValidUsername(String u) {
    final s = _normalizeUsername(u);
    if (s.length < 3 || s.length > 20) return false;
    final re = RegExp(r'^[a-z0-9._]+$');
    return re.hasMatch(s);
  }

  // ✅ GÜVENLİK: Email validation - RFC 5322 uyumlu basit versiyonu
  bool _isValidEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return false;
    
    // Basit ama etkili email regex (RFC 5322 uyumlu basit versiyonu)
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(trimmed);
  }

  // ✅ GÜVENLİK: Input sanitization - XSS koruması için HTML tag'lerini kaldır
  String _sanitizeInput(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '') // HTML tag'lerini kaldır
        .trim();
  }

  String _sanitizeUsernameCandidate(String raw) {
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[^a-z0-9._]'), '_');
    s = s.replaceAll(RegExp(r'_{2,}'), '_');
    s = s.replaceAll(RegExp(r'^[._]+'), '');
    s = s.replaceAll(RegExp(r'[._]+$'), '');
    if (s.length > 20) s = s.substring(0, 20);
    if (s.length < 3) {
      s = s.padRight(3, '0');
    }
    return s;
  }

  String _suggestUsernameFromEmail(String email, String uid) {
    if (email.trim().isEmpty || !email.contains('@')) {
      return _sanitizeUsernameCandidate('user_${uid.substring(0, 8)}');
    }
    final local = email.split('@').first;
    var base = _sanitizeUsernameCandidate(local);
    if (!_isValidUsername(base)) {
      base = _sanitizeUsernameCandidate('user_${uid.substring(0, 8)}');
    }
    return base;
  }

  Future<PlatformFile?> _pickPlatformFile({
    required FileType type,
    List<String>? allowedExtensions,
  }) async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: type,
      allowedExtensions: allowedExtensions,
    );
    if (res == null || res.files.isEmpty) return null;
    return res.files.single;
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final f = await _pickPlatformFile(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (f == null || f.bytes == null || f.bytes!.isEmpty) return;
      setState(() {
        _profileBytes = f.bytes!;
        _profileFileName = f.name;
      });
    } catch (e) {
      _setError('Fotoğraf seçilemedi: $e');
    }
  }

  Future<void> _pickCoverPhoto() async {
    try {
      final f = await _pickPlatformFile(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (f == null || f.bytes == null || f.bytes!.isEmpty) return;
      setState(() {
        _coverBytes = f.bytes!;
        _coverFileName = f.name;
      });
    } catch (e) {
      _setError('Kapak fotoğrafı seçilemedi: $e');
    }
  }

  Future<void> _pickCvFile() async {
    try {
      final f = await _pickPlatformFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx'],
      );
      if (f == null || f.bytes == null || f.bytes!.isEmpty) return;
      setState(() {
        _cvBytes = f.bytes!;
        _cvFileName = f.name;
      });
    } catch (e) {
      _setError('CV seçilemedi: $e');
    }
  }

  // ---------------- username map ----------------
  // usernames/{usernameLower} => { uid, email, username, usernameLower, createdAt }

  Future<String?> _resolveEmailFromLoginId(String loginId) async {
    final v = loginId.trim();
    if (v.isEmpty) return null;

    // email ise direkt
    if (v.contains('@')) return v;

    final uname = _normalizeUsername(v);

    final snap = await _db.collection('usernames').doc(uname).get();
    if (!snap.exists) return null;

    final data = snap.data() ?? <String, dynamic>{};
    final email = (data['email'] ?? '').toString().trim();
    return email.isEmpty ? null : email;
  }

  Future<bool> _usernameAvailable(String usernameLower) async {
    final snap = await _db.collection('usernames').doc(usernameLower).get();
    return !snap.exists;
  }

  Future<void> _repairUserRecordsIfNeeded(User user) async {
    // Login sonrası self-heal:
    // - users/{uid} yoksa oluştur (role=client)
    // - usernames/{usernameLower} yoksa oluştur (mümkünse)
    final uid = user.uid;
    final email = (user.email ?? '').trim();
    final userRef = _db.collection('users').doc(uid);

    final userSnap = await userRef.get();
    if (userSnap.exists) {
      final data = userSnap.data() ?? <String, dynamic>{};
      final usernameLower = (data['usernameLower'] ?? '').toString().trim().toLowerCase();
      final username = (data['username'] ?? '').toString().trim();

      if (usernameLower.isNotEmpty && username.isNotEmpty && email.isNotEmpty) {
        final unameRef = _db.collection('usernames').doc(usernameLower);
        final unameSnap = await unameRef.get();
        if (!unameSnap.exists) {
          // çakışma kontrolü
          final ok = await _usernameAvailable(usernameLower);
          if (ok) {
            await unameRef.set({
              'uid': uid,
              'email': email,
              'username': username,
              'usernameLower': usernameLower,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
      return;
    }

    // users/{uid} yoksa: username üret, usernames + users birlikte yaz
    String base = _suggestUsernameFromEmail(email, uid);
    String candidate = base;

    // 5 deneme
    for (int i = 0; i < 5; i++) {
      final lower = candidate.toLowerCase();
      final ok = await _usernameAvailable(lower);
      if (ok) break;

      final suffix = uid.substring(0, (i + 1).clamp(1, 8));
      // uzunluğu aşmadan ekle
      final maxBase = 20 - (suffix.length + 1);
      final trimmedBase = base.length > maxBase ? base.substring(0, maxBase) : base;
      candidate = _sanitizeUsernameCandidate('${trimmedBase}_$suffix');
    }

    final usernameLower = candidate.toLowerCase();
    final unameRef = _db.collection('usernames').doc(usernameLower);

    await _db.runTransaction((tx) async {
      final uSnap = await tx.get(userRef);
      if (uSnap.exists) return;

      final mSnap = await tx.get(unameRef);
      if (mSnap.exists) {
        // mapping çakıştıysa: user doc’u yine de username’siz oluşturmayalım.
        // Bu durumda login olur ama username-login çalışmaz; kullanıcıyı profil tamamlamaya yönlendirirsin.
        // Burada en güvenlisi: transaction fail.
        throw StateError('USERNAME_TAKEN_ON_REPAIR');
      }

      tx.set(unameRef, {
        'uid': uid,
        'email': email,
        'username': candidate,
        'usernameLower': usernameLower,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(userRef, {
        'name': (user.displayName ?? 'Kullanıcı').toString(),
        'username': candidate,
        'usernameLower': usernameLower,
        'email': email,

        'role': 'client',
        'banned': false,

        'city': '',
        'profession': '',
        'specialties': '',
        'about': '',
        'education': '',
        'birthDate': null,

        'photoUrl': '',
        'coverUrl': '',
        'cvUrl': '',

        'photoFileName': '',
        'coverFileName': '',
        'cvFileName': '',

        'followersCount': 0,
        'followingCount': 0,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ---------------- actions ----------------

  Future<void> _login() async {
    _setError(null);

    final loginId = _loginIdCtrl.text.trim();
    final pass = _loginPassCtrl.text.trim();

    if (loginId.isEmpty || pass.isEmpty) {
      _setError('Email/kullanıcı adı ve şifre gerekli.');
      return;
    }

    setState(() => _loading = true);
    try {
      final email = await _resolveEmailFromLoginId(loginId);
      if (email == null) {
        _setError('Email veya kullanıcı adı bulunamadı.');
        return;
      }

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final user = cred.user;
      if (user != null) {
        // ✅ GÜVENLİK: Banned user kontrolü
        final userDoc = await _db.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() ?? <String, dynamic>{};
          final banned = userData['banned'] == true;
          if (banned) {
            await FirebaseAuth.instance.signOut();
            _setError('Hesabınız yasaklanmış. Lütfen destek ekibi ile iletişime geçin.');
            return;
          }
        }
        
        await _repairUserRecordsIfNeeded(user);
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/feed');
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Giriş başarısız.';
      if (e.code == 'user-disabled') msg = 'Hesabınız devre dışı bırakılmış.';
      if (e.code == 'user-not-found') msg = 'Kullanıcı bulunamadı.';
      if (e.code == 'wrong-password') msg = 'Şifre yanlış.';
      if (e.code == 'invalid-email') msg = 'Geçersiz e-posta adresi.';
      _setError(msg);
    } on StateError catch (e) {
      _setError('Giriş sonrası kullanıcı kaydı tamamlanamadı: ${e.message}');
    } catch (e) {
      _setError('Giriş başarısız: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool _validateSignup() {
    final fullName = _sanitizeInput(_fullNameCtrl.text);
    final username = _sanitizeInput(_usernameCtrl.text);
    final email = _sanitizeInput(_emailCtrl.text);
    final pass = _passCtrl.text.trim();
    final pass2 = _pass2Ctrl.text.trim();
    final city = _sanitizeInput(_cityCtrl.text);
    final about = _sanitizeInput(_aboutCtrl.text);
    final education = _sanitizeInput(_educationCtrl.text);
    final specialties = _sanitizeInput(_specialtiesCtrl.text);

    final wantsExpert = _roleChoice == 'expert';

    // ✅ VALIDATION: İsim Soyisim - uzunluk kontrolü
    if (fullName.isEmpty) {
      _error = 'İsim Soyisim gerekli.';
      return false;
    }
    if (fullName.length < 2) {
      _error = 'İsim Soyisim en az 2 karakter olmalı.';
      return false;
    }
    if (fullName.length > 100) {
      _error = 'İsim Soyisim en fazla 100 karakter olabilir.';
      return false;
    }

    // ✅ VALIDATION: Username
    if (!_isValidUsername(username)) {
      _error = 'Kullanıcı adı 3-20 karakter olmalı ve sadece harf/rakam/./_ içermeli.';
      return false;
    }

    // ✅ GÜVENLİK: Email validation - güçlü regex
    if (!_isValidEmail(email)) {
      _error = 'Geçerli bir email adresi girin.';
      return false;
    }

    // ✅ VALIDATION: Şifre
    if (pass.length < 6) {
      _error = 'Şifre en az 6 karakter olmalı.';
      return false;
    }
    if (pass.length > 128) {
      _error = 'Şifre en fazla 128 karakter olabilir.';
      return false;
    }

    if (pass2 != pass) {
      _error = 'Şifre tekrar eşleşmiyor.';
      return false;
    }

    // ✅ VALIDATION: Şehir - uzunluk kontrolü
    if (city.isEmpty) {
      _error = 'Şehir gerekli.';
      return false;
    }
    if (city.length > 50) {
      _error = 'Şehir en fazla 50 karakter olabilir.';
      return false;
    }

    // ✅ VALIDATION: Doğum tarihi
    if (_birthDate == null) {
      _error = 'Doğum tarihi gerekli.';
      return false;
    }
    final now = DateTime.now();
    final age = now.year - _birthDate!.year;
    if (now.month < _birthDate!.month || (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
      // Henüz doğum günü gelmemiş
      if (age < 13) {
        _error = 'Kayıt olmak için en az 13 yaşında olmalısınız.';
        return false;
      }
    } else {
      if (age < 13) {
        _error = 'Kayıt olmak için en az 13 yaşında olmalısınız.';
        return false;
      }
    }
    if (_birthDate!.isAfter(now)) {
      _error = 'Doğum tarihi gelecekte olamaz.';
      return false;
    }

    // ✅ VALIDATION: Hakkımda - uzunluk kontrolü
    if (about.length > 500) {
      _error = 'Hakkımda en fazla 500 karakter olabilir.';
      return false;
    }

    // ✅ VALIDATION: Eğitim - uzunluk kontrolü
    if (education.length > 500) {
      _error = 'Eğitim ve Sertifikalar en fazla 500 karakter olabilir.';
      return false;
    }

    if (wantsExpert) {
      if ((_selectedProfession ?? '').trim().isEmpty) {
        _error = 'Uzman başvurusu için meslek seçmelisin.';
        return false;
      }

      // ✅ VALIDATION: Uzmanlık Alanı - uzunluk kontrolü
      if (specialties.length > 200) {
        _error = 'Uzmanlık Alanı en fazla 200 karakter olabilir.';
        return false;
      }
    }

    _error = null;
    return true;
  }

  Future<void> _signup() async {
    _setError(null);

    if (!_validateSignup()) {
      if (!mounted) return;
      setState(() {});
      return;
    }

    final fullName = _sanitizeInput(_fullNameCtrl.text);
    final usernameLower = _normalizeUsername(_usernameCtrl.text);
    final usernameDisplay = _sanitizeInput(_usernameCtrl.text);
    final email = _sanitizeInput(_emailCtrl.text);
    final pass = _passCtrl.text.trim();
    final city = _sanitizeInput(_cityCtrl.text);
    final about = _sanitizeInput(_aboutCtrl.text);
    final education = _sanitizeInput(_educationCtrl.text);
    final specialties = _sanitizeInput(_specialtiesCtrl.text);

    final wantsExpert = _roleChoice == 'expert';

    setState(() => _loading = true);

    UserCredential? cred;

    try {
      final ok = await _usernameAvailable(usernameLower);
      if (!ok) {
        _setError('Bu kullanıcı adı zaten kullanımda.');
        return;
      }

      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
      final uid = cred.user!.uid;

      await cred.user!.updateDisplayName(fullName);

      final usernamesRef = _db.collection('usernames').doc(usernameLower);
      final userRef = _db.collection('users').doc(uid);

      // USERNAME + USER DOC transaction
      await _db.runTransaction((tx) async {
        final uSnap = await tx.get(usernamesRef);
        if (uSnap.exists) {
          throw StateError('USERNAME_TAKEN');
        }

        tx.set(usernamesRef, {
          'uid': uid,
          'email': email,
          'username': usernameDisplay,
          'usernameLower': usernameLower,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // RULES UYUMLULUĞU:
        // client için requestedRole/expertStatus alanlarını HİÇ yazmıyoruz.
        final Map<String, dynamic> userData = {
          'name': fullName,
          'username': usernameDisplay,
          'usernameLower': usernameLower,
          'email': email,

          'role': 'client',
          'banned': false,

          'city': city,

          'profession': wantsExpert ? (_selectedProfession ?? '') : '',
          'specialties': wantsExpert ? specialties : '',

          'about': about,
          'education': education,
          'birthDate': _birthDate != null ? Timestamp.fromDate(_birthDate!) : null,

          'photoUrl': '',
          'coverUrl': '',
          'cvUrl': '',

          'photoFileName': _profileFileName ?? '',
          'coverFileName': _coverFileName ?? '',
          'cvFileName': wantsExpert ? (_cvFileName ?? '') : '',

          'followersCount': 0,
          'followingCount': 0,

          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (wantsExpert) {
          userData['requestedRole'] = 'expert';
          userData['expertStatus'] = 'pending';
          userData['expertAppliedAt'] = FieldValue.serverTimestamp();
          userData['expertReviewedAt'] = null;
          userData['expertReviewedBy'] = '';
        }

        tx.set(userRef, userData);
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/feed');
    } on StateError catch (e) {
      if (e.message == 'USERNAME_TAKEN') {
        _setError('Bu kullanıcı adı zaten kullanımda.');
      } else {
        _setError('Kayıt başarısız: $e');
      }

      try {
        if (cred?.user != null) {
          await cred!.user!.delete();
        }
      } catch (_) {}
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Kayıt başarısız.';
      if (e.code == 'email-already-in-use') msg = 'Bu e-posta zaten kullanımda.';
      if (e.code == 'weak-password') msg = 'Şifre çok zayıf.';
      if (e.code == 'invalid-email') msg = 'Geçersiz e-posta.';
      _setError(msg);
    } catch (e) {
      _setError('Kayıt başarısız: $e');
      try {
        if (cred?.user != null) {
          await cred!.user!.delete();
        }
      } catch (_) {}
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ---------------- UI ----------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          SizedBox(
            height: 34,
            width: 34,
            child: Image.asset(
              'assets/images/psych_catalog_logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Psych Catalog',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: _brandNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPicker() {
    final border = Colors.deepPurple.withOpacity(0.22);

    return GestureDetector(
      onTap: _loading ? null : _pickCoverPhoto,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          color: Colors.deepPurple.withOpacity(0.08),
          image: _coverBytes != null
              ? DecorationImage(
            image: MemoryImage(_coverBytes!),
            fit: BoxFit.cover,
          )
              : null,
        ),
        child: Stack(
          children: [
            if (_coverBytes != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.15),
                        Colors.black.withOpacity(0.35),
                      ],
                    ),
                  ),
                ),
              ),
            if (_coverBytes == null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wallpaper_rounded,
                      size: 30,
                      color: Colors.deepPurple.withOpacity(0.85),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kapak fotoğrafı seç',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.deepPurple.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '(opsiyonel)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.deepPurple.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            if (_coverBytes != null) ...[
              const Positioned(
                left: 12,
                bottom: 10,
                child: Row(
                  children: [
                    Icon(Icons.wallpaper_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Kapak fotoğrafı',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: IconButton(
                  tooltip: 'Kaldır',
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                    _coverBytes = null;
                    _coverFileName = null;
                  }),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePickerRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: _loading ? null : _pickProfilePhoto,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.deepPurple.withOpacity(0.14),
                backgroundImage: _profileBytes != null ? MemoryImage(_profileBytes!) : null,
                child: _profileBytes == null
                    ? Icon(
                  Icons.person,
                  color: Colors.deepPurple.withOpacity(0.8),
                )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _pickProfilePhoto,
            icon: const Icon(Icons.photo),
            label: Text(
              _profileFileName == null ? 'Profil fotoğrafı seç (opsiyonel)' : 'Seçildi: ${_profileFileName!}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (_profileBytes != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Kaldır',
            onPressed: _loading
                ? null
                : () => setState(() {
              _profileBytes = null;
              _profileFileName = null;
            }),
            icon: const Icon(Icons.close),
          ),
        ],
      ],
    );
  }

  Widget _buildLoginTab() {
    return AutofillGroup(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Giriş',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _loginIdCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  decoration: _dec(
                    'Email veya kullanıcı adı',
                    prefixIcon: const Icon(Icons.alternate_email),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _loginPassCtrl,
                  obscureText: !_loginPasswordVisible,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: _dec(
                    'Şifre',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _loginPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _loginPasswordVisible = !_loginPasswordVisible;
                        });
                      },
                    ),
                  ),
                  onSubmitted: (_) => _loading ? null : _login(),
                ),
                _errorBox(),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Giriş Yap',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _loading
                ? null
                : () {
              _setError(null);
              _tabCtrl.animateTo(1);
            },
            child: const Text('Hesabın yok mu? Kayıt ol'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupTab() {
    final wantsExpert = _roleChoice == 'expert';

    return AutofillGroup(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Kayıt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                _buildCoverPicker(),
                const SizedBox(height: 12),
                _buildProfilePickerRow(),
                const SizedBox(height: 16),
                TextField(
                  controller: _fullNameCtrl,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: _dec(
                    'İsim Soyisim',
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameCtrl,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: _dec(
                    'Kullanıcı adı',
                    prefixIcon: const Icon(Icons.alternate_email),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: _dec(
                    'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: !_signupPasswordVisible,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: _dec(
                    'Şifre',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _signupPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _signupPasswordVisible = !_signupPasswordVisible;
                        });
                      },
                    ),
                    helperText: 'En az 6 karakter olmalı',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass2Ctrl,
                  obscureText: !_signupPassword2Visible,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: _dec(
                    'Şifre tekrar',
                    prefixIcon: const Icon(Icons.lock_reset),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _signupPassword2Visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _signupPassword2Visible = !_signupPassword2Visible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cityCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: _dec(
                    'Şehir',
                    prefixIcon: const Icon(Icons.location_city_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _loading ? null : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      locale: const Locale('tr', 'TR'),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.deepPurple,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Colors.black,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null && mounted) {
                      setState(() {
                        _birthDate = picked;
                        _birthDateCtrl.text = '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _birthDateCtrl,
                      readOnly: true,
                      decoration: _dec(
                        'Doğum Tarihi',
                        hint: 'Doğum tarihi seçin',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _aboutCtrl,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: _dec(
                    'Hakkımda',
                    hint: 'Kendiniz hakkında kısa bir açıklama (isteğe bağlı)',
                    prefixIcon: const Icon(Icons.info_outline),
                    helperText: 'İletişim bilgileri ve linkler ekleyebilirsiniz (opsiyonel)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _roleChoice,
                  decoration: _dec('Hesap Tipi', prefixIcon: const Icon(Icons.person_pin)),
                  items: const [
                    DropdownMenuItem(value: 'client', child: Text('Danışan')),
                    DropdownMenuItem(
                      value: 'expert',
                      child: Text('Uzman (Onay bekler)'),
                    ),
                  ],
                  onChanged: _loading
                      ? null
                      : (v) {
                    setState(() {
                      _roleChoice = v ?? 'client';
                      if (_roleChoice != 'expert') {
                        _selectedProfession = null;
                        _specialtiesCtrl.clear();
                        _cvBytes = null;
                        _cvFileName = null;
                      }
                    });
                  },
                ),
                if (wantsExpert) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.35)),
                    ),
                    child: const Text(
                      'Uzman seçimi başvuru olarak kaydedilir. Admin onaylayana kadar paylaşım/test oluşturma gibi uzman işlemleri kapalı olur.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedProfession,
                    decoration: _dec('Meslek', prefixIcon: const Icon(Icons.work_outline)),
                    items: _professionOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: _loading ? null : (v) => setState(() => _selectedProfession = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _specialtiesCtrl,
                    maxLines: 2,
                    textInputAction: TextInputAction.newline,
                    decoration: _dec(
                      'Uzmanlık Alanı',
                      prefixIcon: const Icon(Icons.psychology_alt_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _pickCvFile,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      _cvFileName == null ? 'CV seç (opsiyonel)' : 'Seçildi: $_cvFileName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_cvFileName != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                          _cvBytes = null;
                          _cvFileName = null;
                        }),
                        child: const Text('CV kaldır'),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _educationCtrl,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: _dec(
                    'Eğitim ve Sertifikalar',
                    hint: 'Aldığınız eğitimler ve sertifikalar (isteğe bağlı)',
                    prefixIcon: const Icon(Icons.workspace_premium_outlined),
                    helperText: 'Uzmanlar için önerilir (opsiyonel)',
                  ),
                ),
                _errorBox(),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Kayıt Ol',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _loading
                ? null
                : () {
              _setError(null);
              _tabCtrl.animateTo(0);
            },
            child: const Text('Zaten hesabın var mı? Giriş yap'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _buildHeader(),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Giriş'),
            Tab(text: 'Kayıt'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildLoginTab(),
          _buildSignupTab(),
        ],
      ),
    );
  }
}
