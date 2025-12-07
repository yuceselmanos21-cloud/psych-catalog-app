import 'package:cloud_firestore/cloud_firestore.dart';

abstract class PostRepository {
  // POST OLUŞTURMA
  Future<void> sendPost(
      String content, {
        String? authorId,
        String? authorName,
        String? authorRole, // 'expert' / 'client'
        String type, // text / image / video / audio
      });

  // FEED + DETAY OKUMA
  Stream<QuerySnapshot<Map<String, dynamic>>> watchFeed();
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPost(String postId);
  Stream<QuerySnapshot<Map<String, dynamic>>> watchReplies(String postId);
  Stream<QuerySnapshot<Map<String, dynamic>>> watchPostsByAuthor(
      String authorId, {
        int limit = 10,
      });


  // ETKİLEŞİMLER
  Future<void> addReply({
    required String postId,
    required String text,
    required String authorId,
    required String authorName,
  });

  Future<void> toggleLike({
    required String postId,
    required String userId,
  });

  Future<void> repostPost({
    required String originalPostId,
    required String text,
    required String type,
    required String authorId,
    required String authorName,
    required String authorRole,
  });

  // SAHİP İŞLEMLERİ
  Future<void> updatePostText({
    required String postId,
    required String newText,
  });

  Future<void> deletePost(String postId);
}
