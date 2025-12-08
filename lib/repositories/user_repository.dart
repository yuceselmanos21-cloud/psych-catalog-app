import 'package:cloud_firestore/cloud_firestore.dart';

abstract class UserRepository {
  Future<Map<String, dynamic>> getUser(String uid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUser(String uid);

  Future<void> updateUserProfile({
    required String uid,
    required String city,
    required String specialties,
    required String about,
    String? profession,
  });
}
