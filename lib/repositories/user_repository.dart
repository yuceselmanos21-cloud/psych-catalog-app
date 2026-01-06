import 'package:cloud_firestore/cloud_firestore.dart';

abstract class UserRepository {
  Future<Map<String, dynamic>> getUser(String uid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUser(String uid);

  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? username,
    String? city,
    String? specialties,
    String? about,
    String? profession,
    String? education,
  });

  Future<void> updateHideLikes({
    required String uid,
    required bool hideLikes,
  });

  Future<void> updatePhotoUrl({
    required String uid,
    required String photoUrl,
  });

  Future<void> updateCoverPhotoUrl({
    required String uid,
    required String coverPhotoUrl,
  });

  Future<bool> isAdmin(String uid);
}
