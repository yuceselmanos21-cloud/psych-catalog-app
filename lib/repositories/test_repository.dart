import 'package:cloud_firestore/cloud_firestore.dart';

abstract class TestRepository {
  // ---------------- TESTLER ----------------
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllTests();
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTestsByCreator(String uid);
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTest(String testId);

  Future<String> createTest({
    required String title,
    required String description,
    required String createdBy,
    required dynamic questions, // ✅ List<String> (eski) veya List<Map<String, dynamic>> (yeni)
    required String answerType, // 'scale' | 'text' | 'multiple_choice' (geriye dönük uyumluluk için)
    String? expertName,
  });

  Future<void> deleteTest(String testId);

  // ---------------- ÇÖZÜLEN TESTLER ----------------
  Stream<QuerySnapshot<Map<String, dynamic>>> watchSolvedTestsByUser(
      String userId,
      );

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSolvedTestsByTest(
      String testId,
      );

  Future<void> submitSolvedTestWithAnalysis({
    required String userId,
    required String testId,
    required String testTitle,
    required List<String> questions,
    required List<dynamic> answers, // int veya String
    required String answerMode, // 'scale' | 'text'
    required String aiAnalysis,
  });

  // Eski kodları kırmamak için opsiyonel legacy fonksiyon
  @Deprecated('Use submitSolvedTestWithAnalysis')
  Future<void> submitSolvedTest({
    required String userId,
    required String testId,
    required String testTitle,
    required List<dynamic> questions,
    required List<dynamic> answers,
  });
}
