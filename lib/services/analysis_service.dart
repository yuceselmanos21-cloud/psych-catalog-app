import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../services/analysis_cache.dart';

/// ✅ Backend'de çalışan güvenli AI analiz servisi
/// Node.js backend REST API kullanıyor
class AnalysisService {
  // Backend API URL - environment variable veya default
  static String get _apiUrl {
    // ✅ Environment variable'dan al, yoksa default kullan
    const apiUrl = String.fromEnvironment('API_URL');
    if (apiUrl.isNotEmpty) return apiUrl;
    
    // Development default
    return 'http://localhost:3000';
    // Production için: flutter run --dart-define=API_URL=https://your-backend.railway.app
  }

  /// ✅ Backend REST API'yi çağır
  static Future<Map<String, dynamic>> generateAnalysis(String prompt, {List<String>? attachments}) async {
    final normalized = prompt.trim();
    
    // ✅ Metin veya eklenti olmalı (ikisi de boş olamaz)
    if (normalized.isEmpty && (attachments == null || attachments.isEmpty)) {
      return {'error': 'Analiz için metin veya eklenti gerekli.'};
    }

    // ✅ Cache hit (client-side cache hala çalışıyor)
    // Not: Eklentiler varsa cache kullanma
    if (attachments == null || attachments.isEmpty) {
      final cached = AnalysisCache.get(normalized);
      if (cached != null) return {'analysis': cached, 'consultationId': null};
    }

    try {
      // Firebase ID token al
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'error': 'Giriş yapmalısınız.'};
      }

      final idToken = await user.getIdToken();

      // Backend API'ye istek gönder
      final response = await http.post(
        Uri.parse('$_apiUrl/api/ai/analyze'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'text': normalized,
          'attachments': attachments ?? [],
        }),
      );

      if (response.statusCode == 200) {
        // ✅ Raw response body'yi log'la
        debugPrint('🔵 [FRONTEND] Raw response body: ${response.body.substring(0, response.body.length.clamp(0, 500))}');
        
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final analysis = data['analysis'] as String?;
        final consultationId = data['consultationId'] as String?;
        
        // ✅ Debug: Backend response'unu log'la
        debugPrint('🔵 [FRONTEND] Backend response: analysis=${analysis != null ? "exists (${analysis.length} chars)" : "null"}, consultationId=$consultationId');
        debugPrint('🔵 [FRONTEND] Full backend response keys: ${data.keys.toList()}');
        debugPrint('🔵 [FRONTEND] consultationId type: ${consultationId.runtimeType}');
        debugPrint('🔵 [FRONTEND] consultationId value: $consultationId');
        debugPrint('🔵 [FRONTEND] data.containsKey("consultationId"): ${data.containsKey("consultationId")}');
        
        if (analysis != null && analysis.trim().isNotEmpty) {
          final clean = analysis.trim();
          // ✅ Cache set (sadece metin için)
          if (attachments == null || attachments.isEmpty) {
            AnalysisCache.set(normalized, clean);
          }
          return {'analysis': clean, 'consultationId': consultationId};
        }
      } else if (response.statusCode == 429) {
        return {'error': 'Çok fazla istek gönderildi. Lütfen birkaç dakika sonra tekrar deneyin.'};
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
        return {'error': errorData?['error'] as String? ?? 
            'Yapay zekâ isteği sırasında hata oluştu.'};
      }

      return {'error': 'Yapay zekâdan anlamlı bir yanıt alınamadı.'};
    } catch (e) {
      return {'error': 'Yapay zekâ isteği sırasında hata oluştu: $e'};
    }
  }
}
