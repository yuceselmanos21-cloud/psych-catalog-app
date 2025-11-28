import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String? _error;

  Map<String, dynamic>? _userData;

  // Text controller'lar
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _specializationCtrl = TextEditingController();
  final TextEditingController _bioCtrl = TextEditingController();

  String? _selectedProfession;
  Uint8List? _newImageBytes;
  Uint8List? _newCvBytes;
  String? _newCvFileName;

  final ImagePicker _imagePicker = ImagePicker();

  final List<String> professions = const [
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
    _loadUserData();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _specializationCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _loading = false;
          _error = 'Oturum bulunamadı.';
        });
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!snap.exists) {
        setState(() {
          _loading = false;
          _error = 'Kullanıcı kaydı bulunamadı.';
        });
        return;
      }

      final data = snap.data() as Map<String, dynamic>;
      _userData = data;

      _cityCtrl.text = data['city']?.toString() ?? '';
      _specializationCtrl.text = data['specialization']?.toString() ?? '';
      _bioCtrl.text = data['bio']?.toString() ?? '';

      if (data['profession'] != null &&
          data['profession'].toString().isNotEmpty) {
        _selectedProfession = data['profession'].toString();
      } else {
        _selectedProfession = null;
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _enterEditMode() {
    if (_userData == null) return;

    setState(() {
      _editing = true;
      _error = null;
      _newImageBytes = null;
      _newCvBytes = null;
      _newCvFileName = null;

      _cityCtrl.text = _userData?['city']?.toString() ?? '';
      _specializationCtrl.text =
          _userData?['specialization']?.toString() ?? '';
      _bioCtrl.text = _userData?['bio']?.toString() ?? '';

      if (_userData?['profession'] != null &&
          _userData!['profession'].toString().isNotEmpty) {
        _selectedProfession = _userData!['profession'].toString();
      } else {
        _selectedProfession = null;
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _error = null;
      _newImageBytes = null;
      _newCvBytes = null;
      _newCvFileName = null;
    });
  }

  Future<void> _pickNewImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _newImageBytes = bytes;
      });
    } catch (e) {
      setState(() {
        _error = 'Fotoğraf seçilirken hata oluştu: $e';
      });
    }
  }

  Future<void> _pickNewCv() async {
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
          _error = 'CV dosyası okunamadı.';
        });
        return;
      }

      setState(() {
        _newCvBytes = file.bytes;
        _newCvFileName = file.name;
      });
    } catch (e) {
      setState(() {
        _error = 'CV seçilirken hata oluştu: $e';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_userData == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _saving = false;
          _error = 'Oturum bulunamadı.';
        });
        return;
      }

      final uid = user.uid;
      String? photoUrl = _userData?['photoUrl']?.toString();
      String? cvUrl = _userData?['cvUrl']?.toString();

      // Yeni fotoğraf yüklendiyse Storage'a yükle
      if (_newImageBytes != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('user_avatars')
            .child('$uid.jpg');

        await ref.putData(
          _newImageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        photoUrl = await ref.getDownloadURL();
        await user.updatePhotoURL(photoUrl);
      }

      // Yeni CV yüklendiyse Storage'a yükle
      if (_newCvBytes != null) {
        String ext = 'pdf';
        if (_newCvFileName != null && _newCvFileName!.contains('.')) {
          ext = _newCvFileName!.split('.').last;
        }

        final ref = FirebaseStorage.instance
            .ref()
            .child('user_cvs')
            .child('${uid}_cv.$ext');

        await ref.putData(
          _newCvBytes!,
          SettableMetadata(contentType: 'application/octet-stream'),
        );
        cvUrl = await ref.getDownloadURL();
      }

      final isExpert =
          (_userData?['role']?.toString() ?? 'client') == 'expert';

      final updateData = <String, dynamic>{
        'city': _cityCtrl.text.trim(),
        'photoUrl': photoUrl ?? '',
        'cvUrl': cvUrl ?? '',
      };

      if (isExpert) {
        updateData['profession'] = _selectedProfession;
        updateData['specialization'] = _specializationCtrl.text.trim();
        updateData['bio'] = _bioCtrl.text.trim();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updateData);

      _userData = {
        ...?_userData,
        ...updateData,
      };

      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          if (_loading)
            const SizedBox.shrink()
          else if (_editing)
            TextButton(
              onPressed: _saving ? null : _cancelEdit,
              child: const Text(
                'İPTAL',
                style: TextStyle(color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _enterEditMode,
              tooltip: 'Profili Düzenle',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
          ? Center(
        child: Text(
          _error ?? 'Kullanıcı verisi bulunamadı.',
          textAlign: TextAlign.center,
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(theme),
            const SizedBox(height: 16),
            _buildGeneralInfoCard(),
            const SizedBox(height: 12),
            _buildExpertInfoCard(),
            const SizedBox(height: 12),
            _buildCvCard(),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            if (_editing) ...[
              const SizedBox(height: 16),
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
                      : const Icon(Icons.save),
                  label: Text(
                    _saving
                        ? 'Kaydediliyor...'
                        : 'Değişiklikleri Kaydet',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------- UI PARÇALARI ----------------

  Widget _buildHeader(ThemeData theme) {
    final name = _userData?['name']?.toString() ?? '';
    final email = _userData?['email']?.toString() ?? '';
    final photoUrl = _userData?['photoUrl']?.toString() ?? '';

    final ImageProvider? imageProvider = _newImageBytes != null
        ? MemoryImage(_newImageBytes!)
        : (photoUrl.isNotEmpty
        ? NetworkImage(photoUrl) as ImageProvider
        : null);

    return Column(
      children: [
        GestureDetector(
          onTap: _editing ? _pickNewImage : null,
          child: CircleAvatar(
            radius: 45,
            backgroundColor: Colors.purple.shade100,
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? const Icon(Icons.person, size: 50, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        if (_editing)
          TextButton.icon(
            onPressed: _pickNewImage,
            icon: const Icon(Icons.photo_camera),
            label: const Text('Fotoğrafı Değiştir'),
          ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          email,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  /// GENEL BİLGİLER: Rol + Meslek
  Widget _buildGeneralInfoCard() {
    final role = _userData?['role']?.toString() ?? 'client';
    final isExpert = role == 'expert';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Genel Bilgiler',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // 1) ROL
            _infoRow('Rol', isExpert ? 'Uzman' : 'Danışan'),
            const SizedBox(height: 8),

            // 2) MESLEK (Uzman için dropdown, danışan için bilgi)
            if (isExpert)
              (_editing
                  ? DropdownButtonFormField<String>(
                value: _selectedProfession,
                decoration: const InputDecoration(
                  labelText: 'Meslek',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: professions
                    .map(
                      (p) => DropdownMenuItem(
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
                  : _infoRow(
                'Meslek',
                _userData?['profession']
                    ?.toString()
                    .isNotEmpty ==
                    true
                    ? _userData!['profession'].toString()
                    : 'Belirtilmemiş',
              ))
            else
              _infoRow('Meslek', 'Yok (Danışan)'),
          ],
        ),
      ),
    );
  }

  /// UZMAN BİLGİLERİ: Şehir, Uzmanlık Alanı, Hakkımda
  Widget _buildExpertInfoCard() {
    final role = _userData?['role']?.toString() ?? 'client';
    final isExpert = role == 'expert';
    if (!isExpert) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uzman Bilgileri',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // 1) ŞEHİR
            if (_editing)
              TextField(
                controller: _cityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Şehir',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              )
            else
              _infoRow(
                'Şehir',
                _userData?['city']?.toString().isNotEmpty == true
                    ? _userData!['city'].toString()
                    : 'Belirtilmemiş',
              ),
            const SizedBox(height: 8),

            // 2) UZMANLIK ALANI
            if (_editing)
              TextField(
                controller: _specializationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Uzmanlık Alanı',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              )
            else
              _infoRow(
                'Uzmanlık Alanı',
                _userData?['specialization']?.toString().isNotEmpty == true
                    ? _userData!['specialization'].toString()
                    : 'Belirtilmemiş',
              ),
            const SizedBox(height: 12),

            // 3) HAKKIMDA
            const Text(
              'Hakkımda',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (_editing)
              TextField(
                controller: _bioCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Kendinizi tanıtın...',
                ),
              )
            else
              Text(
                _userData?['bio']?.toString().trim().isNotEmpty == true
                    ? _userData!['bio'].toString()
                    : 'Kendinizi tanıtan bir yazı eklemediniz.',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCvCard() {
    final role = _userData?['role']?.toString() ?? 'client';
    final isExpert = role == 'expert';
    if (!isExpert) return const SizedBox.shrink();

    final currentCvUrl = _userData?['cvUrl']?.toString() ?? '';
    final hasCurrentCv = currentCvUrl.isNotEmpty;

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.description_outlined,
              size: 32,
              color: Colors.purple.shade400,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CV Bilgisi',
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (_editing) ...[
                    Text(
                      _newCvFileName ??
                          (hasCurrentCv
                              ? 'Mevcut CV korunacak. Yeni CV seçerseniz güncellenecek.'
                              : 'Henüz CV seçilmedi.'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickNewCv,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('CV Seç'),
                    ),
                  ] else ...[
                    if (hasCurrentCv) ...[
                      const Text(
                        'CV yüklendi.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Aşağıdaki linki kopyalayıp tarayıcıda açarak CV\'yi görüntüleyebilirsin:',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        currentCvUrl,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: currentCvUrl),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('CV linki panoya kopyalandı.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Linki Kopyala'),
                        ),
                      ),
                    ] else ...[
                      const Text('Herhangi bir CV yüklenmemiş.'),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
