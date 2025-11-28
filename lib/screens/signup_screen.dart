import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

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
  final _specializationCtrl = TextEditingController(); // Uzmanlık alanı
  final _bioCtrl = TextEditingController();

  String _role = 'client'; // client / expert
  String? _selectedProfession; // Meslek
  bool _loading = false;
  String? _error;

  // Fotoğraf ve CV için
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _imageBytes;
  Uint8List? _cvBytes;
  String? _cvFileName;

  final List<String> professions = [
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
    _specializationCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    } catch (e) {
      setState(() {
        _error = 'Fotoğraf seçilirken hata oluştu: $e';
      });
    }
  }

  Future<void> _pickCv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        setState(() {
          _error = 'CV dosyasının içeriği okunamadı.';
        });
        return;
      }

      setState(() {
        _cvBytes = file.bytes;
        _cvFileName = file.name;
      });
    } catch (e) {
      setState(() {
        _error = 'CV seçilirken hata oluştu: $e';
      });
    }
  }

  Future<void> _signup() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Auth hesabı oluştur
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final uid = cred.user!.uid;

      // 2) Profil fotoğrafını Storage'a yükle (varsa)
      String? photoUrl;
      if (_imageBytes != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('user_avatars')
            .child('$uid.jpg');

        await ref.putData(
          _imageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        photoUrl = await ref.getDownloadURL();
        await cred.user!.updatePhotoURL(photoUrl);
      }

      // 3) CV'yi Storage'a yükle (sadece uzman ve varsa)
      String? cvUrl;
      if (_role == 'expert' && _cvBytes != null) {
        String ext = 'pdf';
        if (_cvFileName != null && _cvFileName!.contains('.')) {
          ext = _cvFileName!.split('.').last;
        }

        final ref = FirebaseStorage.instance
            .ref()
            .child('user_cvs')
            .child('${uid}_cv.$ext');

        await ref.putData(
          _cvBytes!,
          SettableMetadata(contentType: 'application/octet-stream'),
        );

        cvUrl = await ref.getDownloadURL();
      }

      // 4) Firestore'a kullanıcı kaydı
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': _role,
        'city': _cityCtrl.text.trim(),
        'profession': _role == 'expert' ? _selectedProfession : null,
        'specialization':
        _role == 'expert' ? _specializationCtrl.text.trim() : null,
        'bio': _role == 'expert' ? _bioCtrl.text.trim() : null,
        'photoUrl': photoUrl ?? '',
        'cvUrl': cvUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/feed');
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
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
            // 🔹 PROFİL FOTOĞRAFI (HER İKİ ROL İÇİN)
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.purple.shade100,
                    backgroundImage:
                    _imageBytes != null ? MemoryImage(_imageBytes!) : null,
                    child: _imageBytes == null
                        ? const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Fotoğraf Seç'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // İSİM
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'İsim',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // E-POSTA
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ŞİFRE
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ŞEHİR (herkes için)
            TextField(
              controller: _cityCtrl,
              decoration: const InputDecoration(
                labelText: 'Şehir',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ROL
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
                });
              },
            ),
            const SizedBox(height: 12),

            // UZMAN ALANLARI
            if (isExpert) ...[
              // MESLEK
              DropdownButtonFormField<String>(
                value: _selectedProfession,
                decoration: const InputDecoration(
                  labelText: 'Meslek',
                  border: OutlineInputBorder(),
                ),
                items: professions
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedProfession = v;
                  });
                },
              ),
              const SizedBox(height: 12),

              // UZMANLIK ALANI
              TextField(
                controller: _specializationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Uzmanlık Alanı',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // KISA BİYOGRAFİ
              TextField(
                controller: _bioCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Kendinizi Tanıtın',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // 🔹 CV YÜKLEME
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CV Yükle (PDF / DOC / DOCX)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _cvFileName ?? 'Henüz seçilmedi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickCv,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('CV Seç'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _signup,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Kayıt Ol'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
