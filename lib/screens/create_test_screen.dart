import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_test_repository.dart';

class CreateTestScreen extends StatefulWidget {
  const CreateTestScreen({super.key});

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  final _testRepo = FirestoreTestRepository();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _questionsCtrl = TextEditingController(); // her satıra 1 soru

  // Cevap tipi: scale = 1-5, text = yazılı
  String _answerType = 'scale';

  bool _loading = false;
  String? _error;
  String? _success;

  // ✅ sadece expert test oluşturabilsin
  bool _roleLoading = true;
  bool _isExpert = false;
  String? _expertName;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadRoleAndName();

    // ✅ soru sayacı canlı güncellensin
    _questionsCtrl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _loadRoleAndName() async {
    final user = _user;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _roleLoading = false;
        _isExpert = false;
        _expertName = null;
      });
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data() ?? <String, dynamic>{};
      final role = (data['role'] ?? 'client').toString();
      final name = (data['name'] ?? '').toString().trim();

      if (!mounted) return;
      setState(() {
        _isExpert = role == 'expert';
        _expertName = name.isNotEmpty ? name : null;
        _roleLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isExpert = false;
        _expertName = null;
        _roleLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _questionsCtrl.dispose();
    super.dispose();
  }

  List<String> _parseQuestions(String raw) {
    return raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _saveTest() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final user = _user;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Oturum bulunamadı. Lütfen tekrar giriş yapın.';
        });
        return;
      }

      if (!_isExpert) {
        if (!mounted) return;
        setState(() {
          _error = 'Sadece uzmanlar test oluşturabilir.';
        });
        return;
      }

      final title = _titleCtrl.text.trim();
      final description = _descCtrl.text.trim();
      final questions = _parseQuestions(_questionsCtrl.text.trim());

      if (title.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'Test başlığı boş olamaz.';
        });
        return;
      }

      if (title.length < 3) {
        if (!mounted) return;
        setState(() {
          _error = 'Test başlığı çok kısa.';
        });
        return;
      }

      if (questions.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'En az bir soru girmelisin. Her satıra bir soru yaz.';
        });
        return;
      }

      if (questions.length > 50) {
        if (!mounted) return;
        setState(() {
          _error = 'Şimdilik en fazla 50 soru ekleyebilirsin.';
        });
        return;
      }

      await _testRepo.createTest(
        title: title,
        description: description,
        createdBy: user.uid,
        questions: questions, // ✅ eski yapıyı bozma
        answerType: _answerType, // ✅ scale/text
        expertName: _expertName, // ✅ opsiyonel, varsa yazar
      );

      if (!mounted) return;
      setState(() {
        _success = 'Test kaydedildi 🎉';
        _titleCtrl.clear();
        _descCtrl.clear();
        _questionsCtrl.clear();
        _answerType = 'scale';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Test kaydedilemedi: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _buildAnswerTypeSelector() {
    return Row(
      children: [
        ChoiceChip(
          label: const Text('1-5 arası puan'),
          selected: _answerType == 'scale',
          onSelected: (selected) {
            if (!selected) return;
            setState(() => _answerType = 'scale');
          },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Yazılı cevap'),
          selected: _answerType == 'text',
          onSelected: (selected) {
            if (!selected) return;
            setState(() => _answerType = 'text');
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ const/AppBar hatası bu şekilde giderildi
    if (_roleLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test Oluştur')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isExpert) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test Oluştur')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Bu sayfa sadece uzmanlara açıktır.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final questionCount = _parseQuestions(_questionsCtrl.text).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Oluştur'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Test Başlığı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Açıklama (isteğe bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cevap Tipi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildAnswerTypeSelector(),
            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const Text(
                    'Sorular',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '($questionCount)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _questionsCtrl,
              maxLines: 10,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                labelText: 'Her satıra bir soru yaz',
                hintText: 'Örn:\nİyi hissediyor muyum?\nUykum düzenli mi?\n...',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            if (_success != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _success!,
                  style: const TextStyle(color: Colors.green),
                ),
              ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _saveTest,
                icon: _loading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.save),
                label: Text(_loading ? 'Kaydediliyor...' : 'Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
