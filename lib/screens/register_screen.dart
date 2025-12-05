import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordAgainCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _specialtiesCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();

  String _role = 'client'; // 'expert' veya 'client'
  String? _profession; // sadece uzman için

  bool _loading = false;
  String? _error;

  // Uzman meslekleri
  final List<String> _professions = const [
    'Psikolog',
    'Klinik Psikolog',
    'Nöropsikolog',
    'Psikiyatr',
    'Psikolojik Danışman (PDR)',
    'Sosyal Hizmet Uzmanı',
    'Aile Danışmanı',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordAgainCtrl.dispose();
    _cityCtrl.dispose();
    _specialtiesCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Firebase Auth ile kullanıcı oluştur
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final uid = cred.user!.uid;

      // Firestore'a user dokümanı yaz
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': _role, // 'expert' / 'client'
        'city': _cityCtrl.text.trim(),
        'profession': _role == 'expert' ? (_profession ?? '') : '',
        'specialties':
        _role == 'expert' ? _specialtiesCtrl.text.trim() : '',
        'about': _aboutCtrl.text.trim(),
        // Şimdilik foto / CV’yi boş geçiyoruz (profilden sonra düzenlenebilir)
        'photoUrl': '',
        'cvUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Kayıt başarılı → feed’e yönlendir
      Navigator.pushReplacementNamed(context, '/feed');
    } on FirebaseAuthException catch (e) {
      String msg = 'Kayıt başarısız.';
      if (e.code == 'email-already-in-use') {
        msg = 'Bu e-posta zaten kullanımda.';
      } else if (e.code == 'weak-password') {
        msg = 'Şifre çok zayıf. Daha güçlü bir şifre belirleyin.';
      }
      setState(() {
        _error = msg;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpert = _role == 'expert';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Ol'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // İSİM
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ad soyad zorunludur.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // E-POSTA
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'E-posta zorunludur.';
                  }
                  if (!v.contains('@')) {
                    return 'Geçerli bir e-posta girin.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ŞİFRE
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.length < 6) {
                    return 'En az 6 karakter olmalıdır.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ŞİFRE TEKRAR
              TextFormField(
                controller: _passwordAgainCtrl,
                decoration: const InputDecoration(
                  labelText: 'Şifre (Tekrar)',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) {
                  if (v != _passwordCtrl.text) {
                    return 'Şifreler uyuşmuyor.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ROL SEÇİMİ
              Row(
                children: [
                  const Text(
                    'Rolünüz:',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: const Text('Danışan'),
                    selected: _role == 'client',
                    onSelected: (sel) {
                      if (!sel) return;
                      setState(() {
                        _role = 'client';
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Uzman'),
                    selected: _role == 'expert',
                    onSelected: (sel) {
                      if (!sel) return;
                      setState(() {
                        _role = 'expert';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ŞEHİR (her iki rol için de)
              TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Şehir',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Şehir alanı zorunludur.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Eğer ROL = UZMAN ise MESLEK alanı
              if (isExpert) ...[
                DropdownButtonFormField<String>(
                  value: _profession,
                  decoration: const InputDecoration(
                    labelText: 'Meslek',
                    border: OutlineInputBorder(),
                  ),
                  items: _professions
                      .map(
                        (p) => DropdownMenuItem(
                      value: p,
                      child: Text(p),
                    ),
                  )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _profession = val;
                    });
                  },
                  validator: (v) {
                    if (_role == 'expert' && (v == null || v.isEmpty)) {
                      return 'Meslek seçmelisiniz.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Uzmanlık alanı
                TextFormField(
                  controller: _specialtiesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Uzmanlık Alanı',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
              ],

              // Hakkımda (isteğe bağlı)
              TextFormField(
                controller: _aboutCtrl,
                decoration: const InputDecoration(
                  labelText: 'Hakkımda (isteğe bağlı)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Kayıt Ol'),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text('Zaten hesabın var mı? Giriş yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
