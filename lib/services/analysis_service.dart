import 'dart:convert';
import 'package:http/http.dart' as http;

import '../analysis_secrets.dart';
import '../services/analysis_cache.dart';

class AnalysisService {
  static const String _model = 'models/gemini-2.0-flash-lite-001';

  static Future<String> generateAnalysis(String prompt) async {
    final apiKey = AnalysisSecrets.geminiApiKey;

    final normalized = prompt.trim();
    if (normalized.isEmpty) {
      return 'Analiz için metin boş olamaz.';
    }

    // ✅ Cache hit
    final cached = AnalysisCache.get(normalized);
    if (cached != null) return cached;

    if (apiKey.trim().isEmpty) {
      return 'Yapay zekâ anahtarı bulunamadı. (analysis_secrets.dart kontrol et)';
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/$_model:generateContent'
          '?key=$apiKey',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': normalized},
          ]
        }
      ]
    });

    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      // ✅ 429 için daha açıklayıcı mesaj
      if (res.statusCode == 429) {
        return 'Çok fazla istek gönderildi (429). '
            'Lütfen kısa bir süre sonra tekrar dene.';
      }

      if (res.statusCode != 200) {
        return 'Gemini API hatası: ${res.statusCode}';
      }

      final data = jsonDecode(res.body);
      final text = data['candidates']?[0]['content']?['parts']?[0]['text'];

      if (text is String && text.trim().isNotEmpty) {
        final clean = text.trim();
        // ✅ Cache set
        AnalysisCache.set(normalized, clean);
        return clean;
      }

      return 'Yapay zekâdan anlamlı bir yanıt alınamadı.';
    } catch (e) {
      return 'Yapay zekâ isteği sırasında hata oluştu: $e';
    }
  }
}
