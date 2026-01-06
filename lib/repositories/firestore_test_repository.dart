import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'test_repository.dart';

class FirestoreTestRepository implements TestRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- OKUMA ---
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllTests() =>
      _db.collection('tests').orderBy('createdAt', descending: true).snapshots();

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTestsByCreator(String uid) =>
      _db.collection('tests').where('createdBy', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots();

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTest(String testId) =>
      _db.collection('tests').doc(testId).snapshots();

  @override
  Stream<DocumentSnapshot> watchSolvedTestResult(String docId) =>
      _db.collection('solvedTests').doc(docId).snapshots();

  // --- YAZMA / GÜNCELLEME ---

  /// 1. Resmi Storage'a yükler ve URL döner
  Future<String> uploadAnswerFile(File file, String userId) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
    // Dosya Yolu: test_uploads/{userId}/{fileName}
    final ref = _storage.ref().child('test_uploads/$userId/$fileName');

    // Yükle
    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }

  /// 2. Cevapları Gönderir (AI Analizi için Pending olarak işaretler)
  @override
  Future<String> submitSolvedTestRaw({
    required String userId,
    required String testId,
    required String testTitle,
    required List<String> questions,
    required List<dynamic> answers,
    required String answerMode,
  }) async {
    // ✅ Firestore'a yaz
    final doc = await _db.collection('solvedTests').add({
      'userId': userId,
      'testId': testId,
      'testTitle': testTitle,
      'questions': questions,
      'answers': answers, // Resimler "IMAGE_URL:..." formatında olacak
      'answerMode': answerMode,
      'status': 'pending', // Sunucu tetikleyicisi
      'aiAnalysis': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // ✅ Backend'e analiz isteği gönder
    try {
      await _triggerBackendAnalysis(testId, doc.id);
    } catch (e) {
      // Backend hatası durumunda log'la ama devam et
      // Kullanıcı Firestore'da pending durumunu görecek
      debugPrint('Backend analiz tetikleme hatası: $e');
    }
    
    return doc.id;
  }

  // ✅ Backend API'ye analiz isteği gönder
  Future<void> _triggerBackendAnalysis(String testId, String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final idToken = await user.getIdToken();
      // ✅ Environment variable'dan al, yoksa default kullan
      const apiUrl = String.fromEnvironment('API_URL');
      final baseUrl = apiUrl.isNotEmpty ? apiUrl : 'http://localhost:3000';
      
      debugPrint('🔵 Backend analiz isteği gönderiliyor: $baseUrl/api/test/analyze');
      debugPrint('🔵 testId: $testId, docId: $docId');
      
      // ✅ Flutter web için retry mekanizması
      http.Response? response;
      int retries = 3;
      Exception? lastError;
      int attempt = 0;
      
      while (retries > 0) {
        attempt++;
        try {
          response = await http.post(
            Uri.parse('$baseUrl/api/test/analyze'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'testId': testId,
              'docId': docId,
            }),
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout after 30 seconds');
            },
          );
          
          // ✅ Status code kontrolü (200-299 arası başarılı)
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final responseData = jsonDecode(response.body);
            debugPrint('✅ Backend analiz isteği başarılı (deneme $attempt/$retries): ${responseData['message']}');
            break; // Başarılı, döngüden çık
          } else {
            // Status code hatası - retry yap
            throw Exception('HTTP ${response.statusCode}: ${response.body}');
          }
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          retries--;
          if (retries > 0) {
            debugPrint('⚠️ İstek başarısız (deneme $attempt): ${e.toString()}');
            debugPrint('⚠️ Tekrar deneniyor... ($retries kaldı)');
            await Future.delayed(const Duration(seconds: 2)); // ✅ 2 saniye bekle
          } else {
            debugPrint('❌ Tüm denemeler başarısız: ${e.toString()}');
          }
        }
      }
      
      if (response == null || response.statusCode < 200 || response.statusCode >= 300) {
        throw lastError ?? Exception('Backend isteği başarısız oldu');
      }
    } catch (e) {
      debugPrint('❌ Backend analiz tetikleme hatası: $e');
      // Hata durumunda sessizce devam et
    }
  }

  // --- TEST YÖNETİMİ ---
  @override
  Future<String> createTest({
    required String title, 
    required String description, 
    required String createdBy,
    required dynamic questions, // ✅ List<String> veya List<Map<String, dynamic>> olabilir
    required String answerType, 
    String? expertName
  }) async {
    // 🔒 GÜVENLİK: Backend'de role kontrolü
    final userDoc = await _db.collection('users').doc(createdBy).get();
    if (!userDoc.exists) {
      throw Exception('Kullanıcı bulunamadı');
    }
    
    final role = userDoc.data()?['role'] as String? ?? 'client';
    final adminDoc = await _db.collection('admins').doc(createdBy).get();
    final isAdmin = adminDoc.exists || role == 'admin';
    
    if (role != 'expert' && role != 'admin' && !isAdmin) {
      throw Exception('Sadece uzmanlar ve adminler test oluşturabilir');
    }
    
    // ✅ GÜVENLİK: Input validation
    if (title.trim().isEmpty) {
      throw Exception('Test başlığı boş olamaz');
    }
    if (title.length > 200) {
      throw Exception('Test başlığı en fazla 200 karakter olabilir');
    }
    if (description.length > 1000) {
      throw Exception('Test açıklaması en fazla 1000 karakter olabilir');
    }
    
    // ✅ Geriye dönük uyumluluk: Eğer List<String> ise, Map formatına çevir
    List<dynamic> normalizedQuestions;
    if (questions is List<String>) {
      // Eski format: Her soru string
      normalizedQuestions = questions.map((q) => {
        'text': q,
        'type': answerType, // Tüm sorular aynı tip
      }).toList();
    } else if (questions is List) {
      // Yeni format: Her soru Map
      // ✅ GÜVENLİK: Soru sayısı kontrolü
      if (questions.length > 50) {
        throw Exception('En fazla 50 soru eklenebilir');
      }
      if (questions.isEmpty) {
        throw Exception('En az bir soru gerekli');
      }
      
      // ✅ BACKEND VALIDATION: Her soruyu validate et
      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        if (q is Map) {
          final type = q['type']?.toString() ?? '';
          
          // ✅ Görsel soru için imageUrl kontrolü
          if (type == 'image_question') {
            final imageUrl = q['imageUrl']?.toString();
            if (imageUrl == null || imageUrl.isEmpty) {
              throw Exception('${i + 1}. soru (görsel soru) için görsel URL gerekli');
            }
            // ✅ Firebase Storage URL formatı kontrolü (güvenlik)
            if (!imageUrl.startsWith('https://') || 
                (!imageUrl.contains('firebasestorage.googleapis.com') && 
                 !imageUrl.contains('storage.googleapis.com'))) {
              throw Exception('${i + 1}. soru için geçersiz görsel URL formatı (sadece Firebase Storage URL\'leri kabul edilir)');
            }
          }
          
          // ✅ Çoktan seçmeli için options kontrolü
          if (type == 'multiple_choice') {
            final options = q['options'];
            if (options == null || (options is List && options.isEmpty)) {
              throw Exception('${i + 1}. soru (çoktan seçmeli) için seçenekler gerekli');
            }
            if (options is List && options.length < 2) {
              throw Exception('${i + 1}. soru (çoktan seçmeli) için en az 2 seçenek gerekli');
            }
          }
        }
      }
      
      normalizedQuestions = questions;
    } else {
      throw Exception('Geçersiz soru formatı');
    }
    
    final doc = await _db.collection('tests').add({
      'title': title, 
      'description': description, 
      'questions': normalizedQuestions, // ✅ Yeni yapı
      'answerType': answerType, // ✅ Geriye dönük uyumluluk için
      'createdBy': createdBy, 
      'expertName': expertName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  @override
  Future<void> deleteTest(String testId) async =>
      await _db.collection('tests').doc(testId).delete();

  // Interface uyumlulukları (Kullanılmayanlar)
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchSolvedTestsByUser(String userId) =>
      _db.collection('solvedTests').where('userId', isEqualTo: userId).snapshots();
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchSolvedTestsByTest(String testId) =>
      _db.collection('solvedTests').where('testId', isEqualTo: testId).snapshots();
  @override
  Future<void> submitSolvedTestWithAnalysis({required String userId, required String testId, required String testTitle, required List<String> questions, required List answers, required String answerMode, required String aiAnalysis}) async {}
  @override
  Future<void> submitSolvedTest({required String userId, required String testId, required String testTitle, required List questions, required List answers}) async {}
}