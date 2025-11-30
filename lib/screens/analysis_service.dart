import 'dart:convert';
import 'package:http/http.dart' as http;

/// Gemini ile konuşan servis sınıfı
class AnalysisService {
  // 🔐 KENDİ API KEY’İNİ YAZ
  static const String _apiKey = 'AIzaSyBRRUdVYG08zfejt8wYn9eVxrn-jgO0Ogw';

  static const String _model = 'models/gemini-2.5-flash';

  static Future<String> generateAnalysis(String prompt) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/$_model:generateContent?key=$_apiKey',
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
      // Hata mesajını ekranda gösterebilmek için olduğu gibi döndürüyoruz
      return 'Gemini API hatası: ${response.statusCode} ${response.body}';
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      return 'Modelden yanıt alınamadı.';
    }

    final first = candidates.first as Map<String, dynamic>;
    final content = first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;

    if (parts == null || parts.isEmpty) {
      return 'Modelden yanıt alınamadı.';
    }

    final part0 = parts.first as Map<String, dynamic>;
    final text = part0['text']?.toString();

    return text?.trim().isNotEmpty == true
        ? text!.trim()
        : 'Model boş yanıt döndürdü.';
  }
}
