import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';

abstract class PostRepository {
  Future<List<Post>> getGlobalFeed({DocumentSnapshot? lastDoc});
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPost(String postId);
  Stream<QuerySnapshot<Map<String, dynamic>>> watchPostsByAuthor(String authorId, {int limit = 10});
  Stream<QuerySnapshot<Map<String, dynamic>>> watchUserPostsAndReposts(String userId, {int limit = 50});
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllCommentsForPost(String postId);

  // ✅ Yorumlar artık Post olarak saklanıyor
  Future<List<Post>> getPostPreviewComments(String postId, List<String> followingIds);
  Future<List<Post>> getPostComments(String postId, {DocumentSnapshot? lastDoc});
  Stream<QuerySnapshot<Map<String, dynamic>>> getCommentsForComment(String commentId);

  // GÜNCELLENDİ
  Future<void> sendPost({
    required String content,
    required String authorId,
    required String authorName,
    required String authorUsername,
    required String authorRole,
    String? authorProfession,
    File? attachment,
  });

  Future<void> deletePost(String postId);
  Future<void> updatePost({required String postId, required String content, File? attachment});
  Future<void> repostPost({required String postId, required String userId});
  Future<void> undoRepost({required String postId, required String userId});
  Future<void> createQuotePost({
    required String originalPostId,
    required String userId,
    required String quoteContent,
    File? attachment,
  });
  Future<void> toggleLike({required String postId, required String userId});
  Future<void> toggleBookmark({required String postId, required String userId});
  Future<List<String>> getLikedByUsers(String postId, {int limit = 50});
  Future<List<Post>> getRepostsForPost(String postId, {DocumentSnapshot? lastDoc});
  
  // ✅ Profil ekranları için yeni methodlar
  Stream<QuerySnapshot<Map<String, dynamic>>> watchCommentsByAuthor(String authorId, {int limit = 50});
  Stream<QuerySnapshot<Map<String, dynamic>>> watchLikedPostsByUser(String userId, {int limit = 50});
  Stream<QuerySnapshot<Map<String, dynamic>>> watchSavedPostsByUser(String userId, {int limit = 50});
}