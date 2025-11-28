import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateTestScreen extends StatefulWidget {
  const CreateTestScreen({super.key});

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _questionsCtrl = TextEditingController(); // her satıra 1 soru

  // Cevap tipi: scale = 1-5, text = yazılı
  String _answerType = 'scale';

  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _questionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveTest() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Oturum bulunamadı. Lütfen tekrar giriş yapın.';
        });
        return;
      }

      final raw = _questionsCtrl.text.trim();

      // satır satır soruları al
      final questions = raw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (_titleCtrl.text.trim().isEmpty) {
        setState(() {
          _error = 'Test başlığı boş olamaz.';
        });
        return;
      }

      if (questions.isEmpty) {
        setState(() {
          _error = 'En az bir soru girmelisin. Her satıra bir soru yaz.';
        });
        return;
      }

      await FirebaseFirestore.instance.collection('tests').add({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'questions': questions,       // satırlardan gelen liste
        'answerType': _answerType,    // 1–5 mi, yazı mı
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _success = 'Test kaydedildi 🎉';
        _titleCtrl.clear();
        _descCtrl.clear();
        _questionsCtrl.clear();
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

            // ---- Cevap tipi seçimi ----
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cevap Tipi',
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('1-5 arası puan'),
                  selected: _answerType == 'scale',
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() {
                      _answerType = 'scale';
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Yazılı cevap'),
                  selected: _answerType == 'text',
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() {
                      _answerType = 'text';
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ---- Sorular alanı (her satıra 1 soru) ----
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sorular',
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_success != null)
              Text(_success!, style: const TextStyle(color: Colors.green)),
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
