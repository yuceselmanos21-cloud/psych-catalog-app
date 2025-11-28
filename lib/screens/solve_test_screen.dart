import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class SolveTestScreen extends StatefulWidget {
  const SolveTestScreen({super.key});

  @override
  State<SolveTestScreen> createState() => _SolveTestScreenState();
}

class _SolveTestScreenState extends State<SolveTestScreen> {
  final Map<int, String> _answers = {};
  bool _saving = false;
  String? _error;
  String? _aiResult;

  // 🔥 GEMINI API İSTEĞİ
  Future<String?> _generateAiAnalysis({
    required String testTitle,
    required List<String> answers,
  }) async {
    // BURAYA KENDİ GEMINI API KEY'İNİ YAZ
    const apiKey = 'AIzaSyBRRUdVYG08zfejt8wYn9eVxrn-jgO0Ogw';

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
    );

    final buffer = StringBuffer();
    for (var i = 0; i < answers.length; i++) {
      buffer.writeln('Soru ${i + 1} cevabı: ${answers[i]}');
    }

    final prompt = '''
Ben bir psikolog değilim, sadece yardımcı bir yapay zekâ modeliyim.
Aşağıdaki test cevaplarını yumuşak ve destekleyici bir dille yorumla.

Test başlığı: $testTitle

Kullanıcının yanıtları:
${buffer.toString()}

Şu başlıklarla cevap ver:
- Genel duygu durumu
- Güçlü yönler
- Dikkat edilmesi gereken noktalar (teşhis koyma, sadece gözlem)
- Öneriler (gerekirse profesyonel destek almaya teşvik edebilirsin)
''';

    final body = {
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ]
    };

    try {
      final resp = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (resp.statusCode != 200) {
        debugPrint(
            'Gemini hatası (${resp.statusCode}): ${resp.body.toString()}');
        return null;
      }

      final data = jsonDecode(resp.body);
      final textResponse = data['candidates']?[0]?['content']?['parts']?[0]
      ?['text']
          ?.toString();

      return textResponse;
    } catch (e) {
      debugPrint('Gemini isteği sırasında hata: $e');
      return null;
    }
  }

  Future<void> _submit(Map<String, dynamic> testData) async {
    setState(() {
      _saving = true;
      _error = null;
      _aiResult = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Oturum bulunamadı.';
        });
        return;
      }

      final questions = (testData['questions'] ?? []) as List<dynamic>;
      final answerType = testData['answerType']?.toString() ?? 'scale';

      // cevapları listeye çevir
      final answersList = List<String>.generate(
        questions.length,
            (index) => _answers[index] ?? '',
      );

      // önce Firestore'a kaydet
      final resultRef = await FirebaseFirestore.instance
          .collection('test_results')
          .add({
        'userId': user.uid,
        'testId': testData['id'],
        'testTitle': testData['title'],
        'questions': questions,
        'answers': answersList,
        'answerType': answerType,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // sonra AI analizi al
      final aiText = await _generateAiAnalysis(
        testTitle: (testData['title'] ?? '').toString(),
        answers: answersList,
      );

      final cleaned = (aiText ?? '').trim();

      // sonucu Firestore'da güncelle
      await resultRef.update({
        'aiAnalysis': cleaned,
      });

      setState(() {
        _aiResult = cleaned;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
    ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args == null) {
      return const Scaffold(
        body: Center(
          child: Text('Test verisi bulunamadı. Lütfen tekrar deneyin.'),
        ),
      );
    }

    final testData = args;
    final questions = (testData['questions'] ?? []) as List<dynamic>;
    final answerType = testData['answerType']?.toString() ?? 'scale';

    return Scaffold(
      appBar: AppBar(
        title: Text(testData['title']?.toString() ?? 'Test Çöz'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (testData['description'] != null &&
                testData['description'].toString().isNotEmpty) ...[
              Text(
                testData['description'],
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
            ],
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final q = questions[index].toString();
                final number = index + 1;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Soru $number: $q',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // CEVAP TİPİNE GÖRE INPUT
                        if (answerType == 'text')
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Cevabın',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              _answers[index] = v;
                            },
                          )
                        else
                          Wrap(
                            spacing: 8,
                            children: List.generate(5, (i) {
                              final value = (i + 1).toString();
                              final selected = _answers[index] == value;
                              return ChoiceChip(
                                label: Text(value),
                                selected: selected,
                                onSelected: (sel) {
                                  setState(() {
                                    _answers[index] = value;
                                  });
                                },
                              );
                            }),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : () => _submit(testData),
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Testi Gönder (AI Analizli)'),
              ),
            ),
            const SizedBox(height: 16),
            if (_aiResult != null && _aiResult!.isNotEmpty)
              Card(
                color: Colors.purple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _aiResult!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
