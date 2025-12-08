import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
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

  final List<String> professions = const [
    "Psikolog",
    "Klinik Psikolog",
    "Nöropsikolog",
    "Psikiyatr",
    "Psikolojik Danışman (PDR)",
    "Sosyal Hizmet Uzmanı",
    "Aile Danışmanı",
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _cityCtrl.dispose();
    _specialtiesCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final city = _cityCtrl.text.trim();

    if (name.isEmpty) {
      _error = 'İsim boş olamaz.';
      return false;
    }
    if (email.isEmpty || !email.contains('@')) {
      _error = 'Geçerli bir email gir.';
      return false;
    }
    if (pass.length < 6) {
      _error = 'Şifre en az 6 karakter olmalı.';
      return false;
    }
    if (city.isEmpty) {
      _error = 'Şehir boş olamaz.';
      return false;
    }

    if (_role == 'expert') {
      if ((_selectedProfession ?? '').trim().isEmpty) {
        _error = 'Uzman için meslek seçmelisin.';
        return false;
      }
    }

    _error = null;
    return true;
  }

  Future<void> _signup() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!_validate()) {
        setState(() => _loading = false);
        return;
      }

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final uid = cred.user!.uid;
      final isExpert = _role == 'expert';

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': _role,
        'city': _cityCtrl.text.trim(),

        // ✅ Profile/Experts/Public ile uyum
        'profession': isExpert ? (_selectedProfession ?? '') : '',
        'specialties': isExpert ? _specialtiesCtrl.text.trim() : '',
        'about': _aboutCtrl.text.trim(),

        // ✅ Storage yokken boş tutulur
        'photoUrl': '',
        'cvUrl': '',

        // ✅ Follow V1 hazırlık
        'followersCount': 0,
        'followingCount': 0,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/feed');
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Kayıt başarısız.';
      if (e.code == 'email-already-in-use') {
        msg = 'Bu e-posta zaten kullanımda.';
      } else if (e.code == 'weak-password') {
        msg = 'Şifre çok zayıf.';
      } else if (e.code == 'invalid-email') {
        msg = 'Geçersiz e-posta.';
      }

      if (!mounted) return;
      setState(() => _error = msg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isExpert = _role == 'expert';

    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Basit header
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.purple.shade100,
              child: const Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'İsim',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _emailCtrl,
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
              onChanged: (v) {
                setState(() {
                  _role = v ?? 'client';
                  if (_role == 'client') {
                    _selectedProfession = null;
                    _specialtiesCtrl.clear();
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
                items: professions
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedProfession = v),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _specialtiesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Uzmanlık Alanı',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _aboutCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText:
                isExpert ? 'Hakkımda' : 'Hakkımda (isteğe bağlı)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

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
          ],
        ),
      ),
    );
  }
}
