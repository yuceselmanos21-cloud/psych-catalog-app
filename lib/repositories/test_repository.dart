import 'package:cloud_firestore/cloud_firestore.dart';

abstract class TestRepository {
  // TESTLER
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTestsByCreator(String uid);
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTest(String testId);
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllTests() {
    return _db
        .collection('tests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

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

  Future<String> createTest({
    required String title,
    required String description,
    required String createdBy,
    required List<String> questions,
    required String answerType, // 'scale' | 'text'
    String? expertName,
  });


  Future<void> deleteTest(String testId);

  // ÇÖZÜLEN TESTLER
  Future<void> submitSolvedTest({
    required String userId,
    required String testId,
    required String testTitle,
    required List<Map<String, dynamic>> questions,
    required List<Map<String, dynamic>> answers,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSolvedTestsByUser(
      String userId,
      );
}
