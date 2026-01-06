import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import '../repositories/firestore_post_repository.dart';
import '../widgets/mention_autocomplete.dart';
import '../utils/mention_parser.dart';

class PostCreateScreen extends StatefulWidget {
  const PostCreateScreen({super.key});

  @override
  State<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  // Repository ve Araçlar
  final _postRepo = FirestorePostRepository.instance;
  final _textCtrl = TextEditingController();
  
  // @mention autocomplete için
  String? _mentionQuery;
  int? _mentionStartPosition;

  // Dosya Seçimi Durumu
  File? _selectedFile;
  String? _fileType; // 'image', 'video', 'file'
  bool _sending = false;

  // Kullanıcı Bilgileri (Repository'ye göndermek için)
  bool _profileLoading = true;
  String _authorName = 'Kullanıcı';
  String _authorUsername = '';
  String _authorRole = 'client';
  String _authorProfession = '';
  String? _photoUrl;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadFullUserProfile();
    _textCtrl.addListener(_onTextChanged);
  }
  
  void _onTextChanged() {
    final text = _textCtrl.text;
    final selection = _textCtrl.selection;
    final cursorPosition = selection.baseOffset;
    
    if (MentionParser.hasMentionTrigger(text, cursorPosition)) {
      final query = MentionParser.getMentionQuery(text, cursorPosition);
      final startPos = MentionParser.getMentionStartPosition(text, cursorPosition);
      
      setState(() {
        _mentionQuery = query;
        _mentionStartPosition = startPos;
      });
    } else {
      setState(() {
        _mentionQuery = null;
        _mentionStartPosition = null;
      });
    }
  }
  
  void _insertMention(String userId, String username) {
    if (_mentionStartPosition == null) return;
    
    // Listener'ı geçici olarak kaldır (sonsuz döngüyü önlemek için)
    _textCtrl.removeListener(_onTextChanged);
    
    final text = _textCtrl.text;
    final selection = _textCtrl.selection;
    final cursorPosition = selection.baseOffset;
    
    // @ işaretinden cursor'a kadar olan kısmı değiştir
    final before = text.substring(0, _mentionStartPosition!);
    final after = text.substring(cursorPosition);
    final newText = '$before@$username $after';
    
    final newCursorPosition = _mentionStartPosition! + username.length + 2; // @ + username + space
    
    _textCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
    
    // Listener'ı tekrar ekle
    _textCtrl.addListener(_onTextChanged);
    
    setState(() {
      _mentionQuery = null;
      _mentionStartPosition = null;
    });
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    super.dispose();
  }

  /// Kullanıcının TÜM bilgilerini çeker (Feed'de hızlı göstermek için)
  Future<void> _loadFullUserProfile() async {
    final user = _user;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _authorName = data['name'] ?? 'Kullanıcı';
          _authorUsername = data['username'] ?? '';
          _authorRole = data['role'] ?? 'client';
          _authorProfession = data['profession'] ?? '';
          _photoUrl = data['photoUrl'];
          _profileLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  /// HER TÜRLÜ DOSYAYI SEÇME (Resim, PDF, Video...)
  Future<void> _pickAnyFile() async {
    try {
      // Dosya seçiciyi aç
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        File originalFile = File(result.files.single.path!);
        String ext = path.extension(originalFile.path).toLowerCase();

        // Eğer Resimse -> SIKIŞTIR (Verimlilik & Hız)
        if (['.jpg', '.jpeg', '.png', '.heic', '.webp'].contains(ext)) {
          final compressed = await FlutterImageCompress.compressAndGetFile(
            originalFile.path,
            originalFile.path.replaceFirst(ext, '_compressed.jpg'),
            quality: 60, // %40 sıkıştırma
            minWidth: 1024,
          );
          setState(() {
            _selectedFile = compressed != null ? File(compressed.path) : originalFile;
            _fileType = 'image';
          });
        }
        // Video
        else if (['.mp4', '.mov', '.avi'].contains(ext)) {
          setState(() {
            _selectedFile = originalFile;
            _fileType = 'video';
          });
        }
        // Diğer (PDF, Doc vs.)
        else {
          setState(() {
            _selectedFile = originalFile;
            _fileType = 'file';
          });
        }
      }
    } catch (e) {
      debugPrint("Dosya seçme hatası: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dosya seçilemedi.")));
    }
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İçerik boş olamaz.')));
      return;
    }

    final user = _user;
    if (user == null) return;

    setState(() => _sending = true);

    try {
      // ✅ GÜNCELLENMİŞ REPOSITORY ÇAĞRISI
      // Tüm kullanıcı verilerini gönderiyoruz
      await _postRepo.sendPost(
        content: text,
        authorId: user.uid,
        authorName: _authorName,
        authorUsername: _authorUsername,
        authorRole: _authorRole,
        authorProfession: _authorProfession,
        attachment: _selectedFile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paylaşıldı!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // --- UI Widget'ları ---

  // Dosya Önizleme Kartı (Türe göre değişir)
  Widget _buildAttachmentPreview() {
    if (_selectedFile == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _fileType == 'image'
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_selectedFile!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _fileType == 'video' ? Icons.videocam : Icons.insert_drive_file,
                        size: 50,
                        color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          path.basename(_selectedFile!.path),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${(_selectedFile!.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB",
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() { _selectedFile = null; _fileType = null; }),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Paylaşım Oluştur', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
              ),
              child: _sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("PAYLAŞ", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: _profileLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (Avatar + İsim)
            Card(
              elevation: 0,
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isDark ? Colors.deepPurple.shade800 : Colors.deepPurple.shade50,
                      backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                      child: _photoUrl == null
                          ? Text(
                              _authorName.isNotEmpty ? _authorName[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _authorName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        if (_authorProfession.isNotEmpty)
                          Text(
                            _authorProfession,
                            style: TextStyle(fontSize: 12, color: secondaryTextColor),
                          )
                        else
                          Text(
                            _authorRole == 'expert' ? 'Uzman' : 'Kullanıcı',
                            style: TextStyle(fontSize: 12, color: secondaryTextColor),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Metin Alanı (mention autocomplete ile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 0,
                  color: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: borderColor, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _textCtrl,
                      maxLines: null,
                      minLines: 6,
                      style: TextStyle(fontSize: 18, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Neler oluyor? Paylaşmak istediklerini yaz...\n\n@ işareti ile kullanıcıları etiketleyebilirsiniz.',
                        hintStyle: TextStyle(color: secondaryTextColor, fontSize: 18),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                // @mention autocomplete (TextField'ın altında)
                if (_mentionQuery != null && _mentionQuery!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: MentionAutocomplete(
                      query: _mentionQuery!,
                      mentionStartPosition: _mentionStartPosition,
                      onSelect: _insertMention,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Eklenmiş Dosya Önizlemesi
            _buildAttachmentPreview(),

            const SizedBox(height: 16),

            // Alt Araç Çubuğu
            Card(
              elevation: 0,
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: _pickAnyFile,
                      icon: Icon(
                        Icons.image_outlined,
                        color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                      ),
                      label: Text(
                        "Medya / Dosya Ekle",
                        style: TextStyle(
                          color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Fotoğraf, Video, PDF veya herhangi bir dosya yükleyebilirsiniz.",
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}