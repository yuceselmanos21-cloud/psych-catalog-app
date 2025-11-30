import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'analysis_service.dart';

class SolveTestScreen extends StatefulWidget {
  const SolveTestScreen({super.key});

  @override
  State<SolveTestScreen> createState() => _SolveTestScreenState();
}

class _SolveTestScreenState extends State<SolveTestScreen> {
  bool _initialized = false;
  String? _loadError;

  late String _testId;
  late String _title;
  late String _description;
  late String _answerType;
  late List<String> _questions;

  late List<int?> _scaleAnswers;
  late List<TextEditingController> _textCtrls;

  bool _submitting = false;
  String? _submitError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final args =
    ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args == null) {
      _loadError = 'Test bilgisi bulunamadı.';
      _questions = [];
      _answerType = 'scale';
      _initialized = true;
      return;
    }

    _testId = args['id']?.toString() ?? '';
    _title = args['title']?.toString() ?? 'Test';
    _description = args['description']?.toString() ?? '';
    _answerType = (args['answerType'] ?? 'scale').toString();
    final qRaw = args['questions'] as List<dynamic>? ?? [];
    _questions = qRaw.map((e) => e.toString()).toList();

    _scaleAnswers = List<int?>.filled(_questions.length, null);
    _textCtrls =
        List.generate(_questions.length, (_) => TextEditingController());

    _initialized = true;
  }

  @override
  void dispose() {
    for (final c in _textCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _submitError = 'Oturum bulunamadı. Lütfen tekrar giriş yapın.';
      });
      return;
    }

    // Cevapları doğrula
    List<dynamic> answers;
    if (_answerType == 'scale') {
      if (_scaleAnswers.any((e) => e == null)) {
        setState(() {
          _submitError = 'Lütfen tüm sorular için 1–5 arasında bir yanıt seçin.';
        });
        return;
      }
      answers = _scaleAnswers.map((e) => e ?? 0).toList();
    } else {
      final texts = _textCtrls.map((c) => c.text.trim()).toList();
      if (texts.any((t) => t.isEmpty)) {
        setState(() {
          _submitError = 'Lütfen tüm sorular için bir yanıt yazın.';
        });
        return;
      }
      answers = texts;
    }

    setState(() {
      _submitError = null;
      _submitting = true;
    });

    try {
      // AI için prompt hazırla
      final buffer = StringBuffer();
      buffer.writeln('Psikolojik test: $_title');
      buffer.writeln('Test açıklaması: $_description');
      buffer.writeln('Cevap tipi: $_answerType');
      for (var i = 0; i < _questions.length; i++) {
        buffer.writeln('Soru ${i + 1}: ${_questions[i]}');
        buffer.writeln('Cevap: ${answers[i]}');
      }

      final aiText =
      await AnalysisService.generateAnalysis(buffer.toString());

      final docRef =
      FirebaseFirestore.instance.collection('solvedTests').doc();

      final payload = {
        'id': docRef.id,
        'testId': _testId,
        'testTitle': _title,
        'userId': user.uid,
        'answers': answers,
        'questions': _questions,
        'answerType': _answerType,
        'aiAnalysis': aiText,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(payload);

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/resultDetail',
        arguments: payload,
      );
    } catch (e) {
      setState(() {
        _submitError = 'Sonuç kaydedilirken hata oluştu: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test Çöz')),
        body: Center(child: Text(_loadError!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_description.isNotEmpty) ...[
              Text(
                _description,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              _answerType == 'scale'
                  ? 'Lütfen her soru için 1 (çok olumsuz) ile 5 (çok olumlu) arasında bir puan seçin.'
                  : 'Lütfen her soru için kısa bir yanıt yazın.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final soru = _questions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Soru ${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(soru),
                        const SizedBox(height: 12),
                        if (_answerType == 'scale')
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(5, (i) {
                              final value = i + 1;
                              final selected =
                                  _scaleAnswers[index] == value;
                              return ChoiceChip(
                                label: Text('$value'),
                                selected: selected,
                                onSelected: (_) {
                                  setState(() {
                                    _scaleAnswers[index] = value;
                                  });
                                },
                              );
                            }),
                          )
                        else
                          TextField(
                            controller: _textCtrls[index],
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Cevabın',
                              border: OutlineInputBorder(),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (_submitError != null)
              Text(
                _submitError!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Gönder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
