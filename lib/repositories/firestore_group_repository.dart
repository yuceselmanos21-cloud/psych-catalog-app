import 'package:cloud_firestore/cloud_firestore.dart';

/// Grup repository
class FirestoreGroupRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  /// Tüm grupları getir
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllGroups() {
    return _groups
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Kullanıcının üye olduğu grupları getir
  Stream<QuerySnapshot<Map<String, dynamic>>> watchUserGroups(String userId) {
    return _groups
        .where('members', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Grup oluştur
  Future<String> createGroup({
    required String name,
    required String description,
    required String createdBy,
    String? photoUrl,
    bool isPublic = true,
  }) async {
    final doc = await _groups.add({
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'photoUrl': photoUrl,
      'members': [createdBy],
      'moderators': [createdBy],
      'isPublic': isPublic,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// Gruba katıl
  Future<void> joinGroup(String groupId, String userId) async {
    await _groups.doc(groupId).update({
      'members': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Gruptan ayrıl
  Future<void> leaveGroup(String groupId, String userId) async {
    await _groups.doc(groupId).update({
      'members': FieldValue.arrayRemove([userId]),
      'moderators': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Grup detayını getir
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGroup(String groupId) {
    return _groups.doc(groupId).snapshots();
  }
}
