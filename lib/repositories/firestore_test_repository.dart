import 'test_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreTestRepository implements TestRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;


  FirestoreTestRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchSolvedTestsByUser(
      String userId,
      ) {
    // where + orderBy kombinasyonu genelde sorunsuzdur.
    // Eğer index isterse Firebase console yönlendirecek.
    return _db
        .collection('solvedTests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
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

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchSolvedTestsByTest(
      String testId,
      ) {
    return _db
        .collection('solvedTests')
        .where('testId', isEqualTo: testId)
        .snapshots();
  }


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
    final doc = await _db.collection('tests').add({
      'title': title.trim(),
      'description': description.trim(),
      'questions': questions, // ✅ eski yapıyı bozma
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

  @override
  Future<void> submitSolvedTest({
    required String userId,
    required String testId,
    required String testTitle,
    required List<Map<String, dynamic>> questions,
    required List<Map<String, dynamic>> answers,
  }) async {
    await _db.collection('solvedTests').add({
      'userId': userId,
      'testId': testId,
      'testTitle': testTitle,
      'questions': questions,
      'answers': answers,
      'createdAt': FieldValue.serverTimestamp(),
      'aiAnalysis': '', // ileride dolduracağız
    });
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchSolvedTestsByUser(
      String userId) {
    return _db
        .collection('solvedTests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
