import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_post_repository.dart';

class PostCreateScreen extends StatefulWidget {
  const PostCreateScreen({super.key});

  @override
  State<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  final _postRepo = FirestorePostRepository();

  final _textCtrl = TextEditingController();
  bool _sending = false;

  String _selectedType = 'text';

  String _authorName = 'Kullanıcı';
  String _authorRole = 'client';
  bool _profileLoading = true;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _user;
    if (user == null) {
      setState(() => _profileLoading = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data() ?? <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _authorName = (data['name'] ?? 'Kullanıcı').toString();
        _authorRole = (data['role'] ?? 'client').toString();
        _profileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _profileLoading = false);
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Widget _typeChip(String value, IconData icon, String label) {
    final selected = _selectedType == value;
    return ChoiceChip(
      selected: selected,
      selectedColor: Colors.deepPurple,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey[700]),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (_) => setState(() => _selectedType = value),
    );
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    final user = _user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce giriş yapmalısın.')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await _postRepo.sendPost(
        text,
        authorId: user.uid,
        authorName: _authorName,
        authorRole: _authorRole,
        type: _selectedType,
      );

      _textCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paylaşım yayınlandı.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım yapılamadı: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profileLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Paylaşım Oluştur')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paylaşım Oluştur'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gönderi türü',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _typeChip('text', Icons.text_fields, 'Metin'),
                    _typeChip('image', Icons.image, 'Fotoğraf'),
                    _typeChip('video', Icons.videocam, 'Video'),
                    _typeChip('audio', Icons.graphic_eq, 'Ses'),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _textCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Danışanlara / uzmanlara yönelik paylaşım yaz...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.send),
                    label: Text(_sending ? 'Gönderiliyor...' : 'Paylaş'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
