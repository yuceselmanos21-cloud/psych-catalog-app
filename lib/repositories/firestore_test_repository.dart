import 'package:cloud_firestore/cloud_firestore.dart';
import 'test_repository.dart';

class FirestoreTestRepository implements TestRepository {
  final FirebaseFirestore _db;

  FirestoreTestRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // ---------------- TESTLER ----------------

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllTests() {
    return _db
        .collection('tests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTestsByCreator(String uid) {
    return _db
        .collection('tests')
        .where('createdBy', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTest(String testId) {
    return _db.collection('tests').doc(testId).snapshots();
  }

  @override
  Future<String> createTest({
    required String title,
    required String description,
    required String createdBy,
    required List<String> questions,
    required String answerType,
    String? expertName,
  }) async {
    // Minimal temizlik (ekranların davranışını bozmaz)
    final cleanQuestions = questions
        .map((q) => q.trim())
        .where((q) => q.isNotEmpty)
        .toList();

    final doc = await _db.collection('tests').add({
      'title': title.trim(),
      'description': description.trim(),
      'questions': cleanQuestions, // ✅ eski yapıyı bozma
      'answerType': answerType, // ✅ scale/text
      'createdBy': createdBy,
      if (expertName != null && expertName.trim().isNotEmpty)
        'expertName': expertName.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  @override
  Future<void> deleteTest(String testId) async {
    await _db.collection('tests').doc(testId).delete();
  }

  // ---------------- ÇÖZÜLEN TESTLER ----------------

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchSolvedTestsByUser(
      String userId,
      ) {
    return _db
        .collection('solvedTests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchSolvedTestsByTest(
      String testId,
      ) {
    // Count için ideal: index yükünü artırmamak adına orderBy yok.
    return _db
        .collection('solvedTests')
        .where('testId', isEqualTo: testId)
        .snapshots();
  }

  @override
  Future<void> submitSolvedTestWithAnalysis({
    required String userId,
    required String testId,
    required String testTitle,
    required List<String> questions,
    required List<dynamic> answers,
    required String answerMode,
    required String aiAnalysis,
  }) async {
    await _db.collection('solvedTests').add({
      'userId': userId,
      'testId': testId,
      'testTitle': testTitle,
      'questions': questions,
      'answers': answers,
      'answerMode': answerMode,
      'aiAnalysis': aiAnalysis,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ✅ Eski kodlar kırılmasın diye
  @override
  Future<void> submitSolvedTest({
    required String userId,
    required String testId,
    required String testTitle,
    required List<dynamic> questions,
    required List<dynamic> answers,
  }) async {
    final mode = _inferAnswerMode(answers);

    await _db.collection('solvedTests').add({
      'userId': userId,
      'testId': testId,
      'testTitle': testTitle,
      'questions': questions,
      'answers': answers,
      'answerMode': mode,
      'aiAnalysis': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _inferAnswerMode(List<dynamic> answers) {
    // Basit ve güvenli tahmin:
    final allInts = answers.every((a) => a is int);
    if (allInts) {
      final okRange =
      answers.whereType<int>().every((v) => v >= 1 && v <= 5);
      if (okRange) return 'scale';
    }
    return 'text';
  }
}
