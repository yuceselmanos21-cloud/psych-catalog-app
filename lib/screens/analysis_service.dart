import 'dart:convert';
import 'package:http/http.dart' as http;
import '../analysis_secrets.dart'; // 👈 key buradan gelecek

class AnalysisService {
  static const String _model = 'models/gemini-2.0-flash-lite-001';

  static Future<String> generateAnalysis(String prompt) async {
    final apiKey = AnalysisSecrets.geminiApiKey;

    // Güvenlik için sadece ilk 6 karakteri loglayalım
    // debugPrint('Gemini key (ilk 6): ${apiKey.substring(0, 6)}******');

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/$_model:generateContent'
          '?key=$apiKey',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
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

      if (res.statusCode != 200) {
        // Hata durumunda Flutter tarafında düzgün mesaj gösterelim
        return 'Gemini API hatası: ${res.statusCode} ${res.body}';
      }

      final data = jsonDecode(res.body);
      final text = data['candidates']?[0]['content']?['parts']?[0]['text'];

      if (text is String && text.trim().isNotEmpty) {
        return text.trim();
      }
      return 'Yapay zekâdan anlamlı bir yanıt alınamadı.';
    } catch (e) {
      return 'Yapay zekâ isteği sırasında hata oluştu: $e';
    }
  }
}
