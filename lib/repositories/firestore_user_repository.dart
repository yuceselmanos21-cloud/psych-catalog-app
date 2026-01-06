import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_repository.dart';

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _db;

  FirestoreUserRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) {
    return _db.collection('users').doc(uid);
  }

  @override
  Future<Map<String, dynamic>> getUser(String uid) async {
    final snap = await _userRef(uid).get();
    if (!snap.exists) {
      throw Exception('USER_NOT_FOUND');
    }
    return snap.data() ?? <String, dynamic>{};
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUser(String uid) {
    return _userRef(uid).snapshots();
  }

  @override
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? username,
    String? city,
    String? specialties,
    String? about,
    String? profession,
    String? education,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updates['name'] = name.trim();
    if (username != null) {
      updates['username'] = username.trim();
      updates['usernameLower'] = username.trim().toLowerCase();
    }
    if (city != null) updates['city'] = city.trim();
    if (specialties != null) updates['specialties'] = specialties.trim();
    if (about != null) updates['about'] = about.trim();
    if (profession != null) updates['profession'] = profession.trim();
    if (education != null) updates['education'] = education.trim();

    await _userRef(uid).update(updates);
  }

  @override
  Future<void> updateHideLikes({
    required String uid,
    required bool hideLikes,
  }) async {
    await _userRef(uid).update({
      'hideLikes': hideLikes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updatePhotoUrl({
    required String uid,
    required String photoUrl,
  }) async {
    await _userRef(uid).update({
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateCoverPhotoUrl({
    required String uid,
    required String coverPhotoUrl,
  }) async {
    await _userRef(uid).update({
      'coverUrl': coverPhotoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<bool> isAdmin(String uid) async {
    final data = await getUser(uid);
    return (data['role'] ?? '').toString() == 'admin';
  }

  // ✅ Chat ekranları için kullanıcı bilgilerini getir
  Future<Map<String, dynamic>?> getUserById(String uid) async {
    try {
      final data = await getUser(uid);
      return {
        'name': data['name'] ?? 'Kullanıcı',
        'photoUrl': data['photoUrl'],
        'role': data['role'] ?? 'client',
        'profession': data['profession'],
      };
    } catch (e) {
      return null;
    }
  }
}
