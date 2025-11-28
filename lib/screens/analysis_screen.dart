import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _loading = true;
  String? _error;
  String? _analysisText;
  Map<String, dynamic>? _resultData;

  // Senin Gemini API anahtarın (lokalde kullanıyoruz)
  static const String _geminiApiKey =
      'AIzaSyBRRUdVYG08zfejt8wYn9eVxrn-jgO0Ogw';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final resultId = ModalRoute.of(context)!.settings.arguments as String;
    _loadResultAndAnalyze(resultId);
  }

  Future<void> _loadResultAndAnalyze(String resultId) async {
    setState(() {
      _loading = true;
      _error = null;
      _analysisText = null;
    });

    try {
      // 1) Firestore'dan test sonucunu çek
      final snap = await FirebaseFirestore.instance
          .collection('test_results')
          .doc(resultId)
          .get();

      final data = snap.data();
      if (data == null) {
        setState(() {
          _error = 'Sonuç bulunamadı.';
          _loading = false;
        });
        return;
      }

      _resultData = data;

      // 2) Sorular + cevaplardan açıklayıcı prompt oluştur
      final questions = (data['questions'] as List).cast<String>();
      final answers = (data['answers'] as List).cast<int>();
      final testTitle = data['testTitle']?.toString() ?? 'Test';

      final buffer = StringBuffer();
      buffer.writeln(
          'Aşağıda "$testTitle" isimli psikolojik değerlendirme testinin sonuçları var.');
      buffer.writeln(
          'Cevaplar 1–5 arasında, 1 = Kesinlikle Katılmıyorum, 5 = Kesinlikle Katılıyorum.');
      buffer.writeln('Kullanıcının cevapları:');
      for (int i = 0; i < questions.length; i++) {
        buffer.writeln(
            'Soru ${i + 1}: ${questions[i]}\nCevap: ${answers[i]} / 5\n');
      }
      buffer.writeln(
          'Bu cevaplara göre kişinin genel psikolojik durumu hakkında profesyonel ama TANISAL OLMAYAN, destekleyici ve anlaşılır bir değerlendirme yaz.');
      buffer.writeln(
          'Kesin teşhis koyma, “kesin”, “mutlaka” gibi ifadeler kullanma. Gerekirse bir uzmandan destek almasını nazikçe önerebilirsin.');
      buffer.writeln(
          'Cevabını Türkçe, sade, empatik ve kullanıcıyı suçlamadan ver.');

      final prompt = buffer.toString();

      // 3) Gemini'den analiz al
      final aiText = await _callGemini(prompt);

      setState(() {
        _analysisText = aiText;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<String> _callGemini(String prompt) async {
    if (_geminiApiKey.isEmpty) {
      return '⚠ Yapay zekâ analizi için önce API anahtarı ayarlanmalı.';
    }

    // Senin projende mevcut ve generateContent destekleyen model:
    // name: "models/gemini-2.0-flash"
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiApiKey',
    );

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API hatası: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body);

    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini boş cevap döndürdü.');
    }

    final text = candidates[0]['content']['parts'][0]['text'] as String?;
    if (text == null) {
      throw Exception('Gemini cevabı çözümlenemedi.');
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Analizi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? SingleChildScrollView(
          child: Text(
            'Hata: $_error',
            style: const TextStyle(color: Colors.red),
          ),
        )
            : SingleChildScrollView(
          child: Text(
            _analysisText ?? 'Analiz bulunamadı.',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
