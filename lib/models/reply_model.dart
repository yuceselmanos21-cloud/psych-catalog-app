import 'package:cloud_firestore/cloud_firestore.dart';

class Reply {
  final String id;
  final String rootPostId;
  final String? parentReplyId;
  final String authorId;
  final String content;
  final int engagement;
  final bool deleted; // boolean, boolean değil bool
  final DateTime createdAt;
  final DocumentSnapshot? docSnapshot; // Pagination için
  
  // ✅ Denormalized data (backend verimliliği için)
  final String? authorName;
  final String? authorUsername;
  final String? authorRole;
  final String? authorProfession;
  
  // ✅ Media support
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaName;
  
  // ✅ Like support
  final List<String> likedBy;
  final int likeCount;
  
  // ✅ Reply count (nested replies için)
  final int replyCount;

  Reply({
    required this.id,
    required this.rootPostId,
    this.parentReplyId,
    required this.authorId,
    required this.content,
    required this.engagement,
    required this.deleted,
    required this.createdAt,
    this.docSnapshot,
    this.authorName,
    this.authorUsername,
    this.authorRole,
    this.authorProfession,
    this.mediaUrl,
    this.mediaType,
    this.mediaName,
    this.likedBy = const [],
    this.likeCount = 0,
    this.replyCount = 0,
  });

  factory Reply.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    // Firestore'da 'text' olarak saklanıyor, 'content' olarak da olabilir
    final contentValue = data['text'] ?? data['content'] ?? '';
    return Reply(
      id: doc.id,
      rootPostId: data['rootPostId'] ?? '',
      parentReplyId: data['parentReplyId'], // null olabilir
      authorId: data['authorId'] ?? '',
      content: contentValue,
      engagement: data['engagement'] ?? 0,
      deleted: data['deleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      docSnapshot: doc,
      // ✅ Denormalized data
      authorName: data['authorName'],
      authorUsername: data['authorUsername'],
      authorRole: data['authorRole'],
      authorProfession: data['authorProfession'],
      // ✅ Media
      mediaUrl: data['mediaUrl'],
      mediaType: data['mediaType'],
      mediaName: data['mediaName'],
      // ✅ Likes
      likedBy: List<String>.from(data['likedBy'] ?? []),
      likeCount: data['likeCount'] ?? 0,
      // ✅ Reply count
      replyCount: data['replyCount'] ?? 0,
    );
  }
}