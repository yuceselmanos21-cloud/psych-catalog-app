import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_repository.dart';

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _db;

  FirestoreUserRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Map<String, dynamic>> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data() ?? <String, dynamic>{};
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  @override
  Future<void> updateUserProfile({
    required String uid,
    required String city,
    required String specialties,
    required String about,
    String? profession,
  }) async {
    final payload = <String, dynamic>{
      'city': city.trim(),
      'specialties': specialties.trim(),
      'about': about.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (profession != null && profession.trim().isNotEmpty) {
      payload['profession'] = profession.trim();
    }

    await _db
        .collection('users')
        .doc(uid)
        .set(payload, SetOptions(merge: true));
  }
}
