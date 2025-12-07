import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_test_repository.dart';
import 'analysis_service.dart'; // AI yorum için

class SolveTestScreen extends StatefulWidget {
  final Map<String, dynamic> testData; // test bilgisi buradan geliyor

  const SolveTestScreen({super.key, required this.testData});

  @override
  State<SolveTestScreen> createState() => _SolveTestScreenState();
}

class _SolveTestScreenState extends State<SolveTestScreen> {
  final _testRepo = FirestoreTestRepository();

  late final List<String> _questions;
  late final String _answerMode; // 'scale' veya 'text'

  // scale modu için: 1–5
  late final List<int?> _scaleAnswers;

  // text modu için
  late final List<TextEditingController> _textControllers;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final rawQuestions = widget.testData['questions'];

    _questions = _normalizeQuestions(rawQuestions);

    _answerMode = _detectAnswerMode(widget.testData);

    if (_answerMode == 'scale') {
      _scaleAnswers = List<int?>.filled(_questions.length, null);
      _textControllers = [];
    } else {
      _textControllers = List.generate(
        _questions.length,
            (_) => TextEditingController(),
      );
      _scaleAnswers = [];
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// questions eski/yeni formatla gelebilir:
  /// - List<String>
  /// - List<dynamic>
  /// - List<Map {text: ...}>
  List<String> _normalizeQuestions(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) {
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          return m['text']?.toString() ?? e.toString();
        }
        return e.toString();
      })
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  /// Test belgesinden cevap modunu tespit etmeye çalışır.
  /// Daha önce ne isim verdiğimizi bilmediğimiz için ESNEK davranıyor.
  String _detectAnswerMode(Map<String, dynamic> data) {
    final dynamic raw = data['answerMode'] ??
        data['answer_mode'] ??
        data['answerType'] ??
        data['answer_type'] ??
        data['mode'];

    final v = raw?.toString().toLowerCase() ?? '';

    if (v.contains('scale') ||
        v.contains('1-5') ||
        v.contains('1_5') ||
        v.contains('numeric') ||
        v.contains('number')) {
      return 'scale';
    }

    return 'text';
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Oturum bulunamadı. Lütfen tekrar giriş yap.';
        });
        return;
      }

      final testId = widget.testData['id']?.toString() ?? '';
      final testTitle = widget.testData['title']?.toString() ?? 'Test';

      if (testId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'Test kimliği eksik görünüyor.';
        });
        return;
      }

      // 1) Cevapları topla
      late final List<dynamic> answers;

      if (_answerMode == 'scale') {
        if (_scaleAnswers.any((v) => v == null)) {
          if (!mounted) return;
          setState(() {
            _error = 'Lütfen tüm sorular için 1–5 arasında bir seçim yap.';
          });
          return;
        }
        answers = _scaleAnswers.map((e) => e!).toList();
      } else {
        if (_textControllers.any((c) => c.text.trim().isEmpty)) {
          if (!mounted) return;
          setState(() {
            _error = 'Lütfen tüm sorulara cevap yaz.';
          });
          return;
        }
        answers = _textControllers.map((c) => c.text.trim()).toList();
      }

      // 2) AI için prompt hazırla
      final buffer = StringBuffer();
      buffer.writeln(
          'Sen klinik psikoloji odaklı, teşhis koymadan destekleyici analiz yapan bir yardımcı yapay zekâsın.');
      buffer.writeln(
          'Aşağıda bir psikolojik testin soruları ve kullanıcının cevapları var:');
      buffer.writeln('');

      for (int i = 0; i < _questions.length; i++) {
        buffer.writeln('Soru ${i + 1}: ${_questions[i]}');
        buffer.writeln('Cevap ${i + 1}: ${answers[i]}');
        buffer.writeln('');
      }

      buffer.writeln(
          'Lütfen kısa bir özet, kullanıcının duygusal durumu, olası riskler ve destekleyici, yargılayıcı olmayan öneriler ver.');
      buffer.writeln(
          'Psikiyatrik tanı koyma, kesin teşhis söyleme. Destekleyici ve anlaşılır ol.');

      final prompt = buffer.toString();

      // 3) AI analizi al
      String aiText = '';
      try {
        aiText = await AnalysisService.generateAnalysis(prompt);
      } catch (e) {
        aiText = 'Yapay zekâ analizi alınırken bir hata oluştu: $e';
      }

      // 4) Repo üzerinden kaydet (solvedTests)
      await _testRepo.submitSolvedTestWithAnalysis(
        userId: user.uid,
        testId: testId,
        testTitle: testTitle,
        questions: _questions,
        answers: answers,
        answerMode: _answerMode,
        aiAnalysis: aiText,
      );

      // 5) Anlık sonuç ekranına yönlendir
      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/resultDetail',
        arguments: {
          'testTitle': testTitle,
          'questions': _questions,
          'answers': answers,
          'aiAnalysis': aiText,
          'createdAt': Timestamp.now(), // ekrandaki gösterim için
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Test kaydedilirken bir hata oluştu: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    }
  }

  Widget _buildQuestionItem(int index) {
    final soru = _questions[index];

    if (_answerMode == 'scale') {
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
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(soru),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(5, (i) {
                  final value = i + 1;
                  final selected = _scaleAnswers[index] == value;
                  return ChoiceChip(
                    label: Text(value.toString()),
                    selected: selected,
                    selectedColor: Colors.deepPurple,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _scaleAnswers[index] = value;
                      });
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      );
    } else {
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
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(soru),
              const SizedBox(height: 8),
              TextField(
                controller: _textControllers[index],
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Cevabın',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final testTitle = widget.testData['title']?.toString() ?? 'Test Çöz';

    return Scaffold(
      appBar: AppBar(
        title: Text(testTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_answerMode == 'scale')
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Bu testte cevaplar 1–5 arası sayısal olarak verilir.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              )
            else
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Bu testte cevaplarını serbest metin olarak yazmalısın.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _questions.length,
                itemBuilder: (context, index) => _buildQuestionItem(index),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Kaydediliyor...' : 'Testi Tamamla'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
