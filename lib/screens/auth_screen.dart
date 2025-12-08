import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // ---- login controllers
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();

  // ---- signup controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _specialtiesCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();

  String _role = 'client';
  String? _selectedProfession;

  bool _loading = false;
  String? _error;

  final List<String> _professionOptions = const [
    'Psikolog',
    'Klinik Psikolog',
    'Nöropsikolog',
    'Psikiyatr',
    'Psikolojik Danışman (PDR)',
    'Sosyal Hizmet Uzmanı',
    'Aile Danışmanı',
  ];

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

    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();

    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _cityCtrl.dispose();
    _specialtiesCtrl.dispose();
    _aboutCtrl.dispose();

    super.dispose();
  }

  void _setError(String? msg) {
    if (!mounted) return;
    setState(() => _error = msg);
  }

  Future<void> _login() async {
    _setError(null);

    final email = _loginEmailCtrl.text.trim();
    final pass = _loginPassCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _setError('Email ve şifre gerekli.');
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/feed');
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Giriş başarısız.');
    } catch (e) {
      _setError('Giriş başarısız: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _signup() async {
    _setError(null);

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final isExpert = _role == 'expert';

    if (name.isEmpty) {
      _setError('İsim gerekli.');
      return;
    }
    if (email.isEmpty) {
      _setError('Email gerekli.');
      return;
    }
    if (pass.length < 6) {
      _setError('Şifre en az 6 karakter olmalı.');
      return;
    }

    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);

      final uid = cred.user!.uid;

      await cred.user!.updateDisplayName(name);

      // ---- Firestore user doc (Profile/Experts/Follow uyumlu)
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'role': _role,
        'city': city,

        'profession': isExpert ? (_selectedProfession ?? '') : '',
        'specialties': isExpert ? _specialtiesCtrl.text.trim() : '',
        'about': _aboutCtrl.text.trim(),

        // Storage yok -> alanlar boş string kalsın
        'photoUrl': '',
        'cvUrl': '',

        // Follow sistemi için default
        'followersCount': 0,
        'followingCount': 0,

        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/feed');
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Kayıt başarısız.');
    } catch (e) {
      _setError('Kayıt başarısız: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _errorBox() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        _error!,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  // ---------------- UI ----------------

  Widget _buildLoginTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: _loginEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loginPassCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Şifre',
            border: OutlineInputBorder(),
          ),
        ),
        _errorBox(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _login,
            child: _loading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Giriş Yap'),
          ),
        ),
        const SizedBox(height: 8),
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
    );
  }

  Widget _buildSignupTab() {
    final isExpert = _role == 'expert';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: _nameCtrl,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'İsim',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Şifre',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cityCtrl,
          decoration: const InputDecoration(
            labelText: 'Şehir',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          value: _role,
          decoration: const InputDecoration(
            labelText: 'Rol',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'client', child: Text('Danışan')),
            DropdownMenuItem(value: 'expert', child: Text('Uzman')),
          ],
          onChanged: _loading
              ? null
              : (v) {
            setState(() {
              _role = v ?? 'client';
              if (_role != 'expert') {
                _selectedProfession = null;
              }
            });
          },
        ),

        const SizedBox(height: 12),

        if (isExpert) ...[
          DropdownButtonFormField<String>(
            value: _selectedProfession,
            decoration: const InputDecoration(
              labelText: 'Meslek',
              border: OutlineInputBorder(),
            ),
            items: _professionOptions
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: _loading ? null : (v) => setState(() {
              _selectedProfession = v;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _specialtiesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Uzmanlık Alanı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        TextField(
          controller: _aboutCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: isExpert ? 'Hakkımda' : 'Hakkımda (isteğe bağlı)',
            border: const OutlineInputBorder(),
          ),
        ),

        _errorBox(),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _signup,
            child: _loading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Kayıt Ol'),
          ),
        ),
        const SizedBox(height: 8),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Psych Catalog'),
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
