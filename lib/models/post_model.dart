import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String content;
  final String? mediaUrl;
  final String? mediaType;
  final String? mediaName; // ✅ Dosya adı (yorumlar için)
  final PostStats stats;
  final DateTime createdAt;
  final DateTime? editedAt;

  // --- DENORMALIZE ALANLAR (Performans için) ---
  final String? authorName;
  final String? authorUsername;
  final String? authorRole;
  final String? authorProfession;

  // --- REPOST/QUOTE ALANLARI ---
  final String? repostOfPostId; // Repost edilen orijinal post ID
  final bool isQuoteRepost; // Alıntı mı yoksa sadece repost mu?
  final String? repostedByUserId; // Repost eden kullanıcı ID (sadece repost item'lar için)
  final String? repostedByName; // Repost eden kullanıcı adı (denormalize)
  final String? repostedByUsername; // Repost eden kullanıcı adı (denormalize)
  final String? repostedByRole; // Repost eden kullanıcı rolü (denormalize - profil navigasyonu için)

  // --- YORUM (COMMENT) ALANLARI ---
  final bool isComment; // Bu post bir yorum mu? (feed'de görünmemesi için)
  final String? rootPostId; // Ana post ID (yorumlar için)
  final String? parentPostId; // Parent yorum ID (nested yorumlar için)

  // --- ETKİLEŞİM ALANLARI ---
  final List<String> likedBy; // Like eden kullanıcı ID'leri
  final List<String> savedBy; // Bookmark eden kullanıcı ID'leri
  
  // --- MENTION ALANLARI ---
  final List<String> mentionedUserIds; // @mention edilen kullanıcı ID'leri

  // --- SOFT DELETE ---
  final bool deleted; // ✅ Soft delete flag (audit için)

  // --- YENİ EKLENEN KRİTİK ALAN ---
  // Pagination (Sonsuz Kaydırma) için veritabanı imlecini tutar.
  // UI'da kullanılmaz, sadece Logic içindir.
  final DocumentSnapshot? docSnapshot;

  Post({
    required this.id,
    required this.authorId,
    required this.content,
    this.mediaUrl,
    this.mediaType,
    this.mediaName,
    required this.stats,
    required this.createdAt,
    this.editedAt,
    this.authorName,
    this.authorUsername,
    this.authorRole,
    this.authorProfession,
    this.repostOfPostId,
    this.isQuoteRepost = false,
    this.repostedByUserId,
    this.repostedByName,
    this.repostedByUsername,
    this.repostedByRole,
    this.isComment = false,
    this.rootPostId,
    this.parentPostId,
    this.likedBy = const [],
    this.savedBy = const [],
    this.mentionedUserIds = const [],
    this.deleted = false,
    this.docSnapshot,
  });

  // Orijinal post mu yoksa repost mu?
  bool get isRepost => repostOfPostId != null && repostOfPostId!.isNotEmpty;
  
  // Alıntı mı?
  bool get isQuote => isRepost && isQuoteRepost;
  
  // Yorum mu? (feed'de görünmemesi için)
  bool get isCommentPost => isComment == true;

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      content: data['content'] ?? '',
      mediaUrl: data['mediaUrl'],
      mediaType: data['mediaType'],
      mediaName: data['mediaName'],
      stats: PostStats.fromMap(data['stats'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
      // Denormalize alanlar
      authorName: data['authorName'],
      authorUsername: data['authorUsername'],
      authorRole: data['authorRole'],
      authorProfession: data['authorProfession'],
      // Repost/Quote alanları
      repostOfPostId: data['repostOfPostId'],
      isQuoteRepost: data['isQuoteRepost'] ?? false,
      repostedByUserId: data['repostedByUserId'],
      repostedByName: data['repostedByName'],
      repostedByUsername: data['repostedByUsername'],
      repostedByRole: data['repostedByRole'],
      // Yorum alanları
      isComment: data['isComment'] ?? false,
      rootPostId: data['rootPostId'],
      parentPostId: data['parentPostId'],
      // Etkileşim alanları
      likedBy: List<String>.from(data['likedBy'] ?? []),
      savedBy: List<String>.from(data['savedBy'] ?? []),
      // Mention alanları
      mentionedUserIds: List<String>.from(data['mentionedUserIds'] ?? []),
      // Soft delete
      deleted: data['deleted'] ?? false,
      docSnapshot: doc, // Dokümanın kendisini saklıyoruz
    );
  }

  // Backend'den gelen JSON için factory constructor
  factory Post.fromJson(Map<String, dynamic> json) {
    // Backend'den gelen createdAt ve editedAt ISO string formatında
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }
      if (value is Timestamp) {
        return value.toDate();
      }
      return null;
    }

    // Backend'den gelen stats Map formatında
    Map<String, dynamic> statsMap = json['stats'] ?? {};
    if (statsMap is Map) {
      statsMap = Map<String, dynamic>.from(statsMap);
    } else {
      statsMap = {};
    }

    return Post(
      id: json['id'] ?? '',
      authorId: json['authorId'] ?? '',
      content: json['content'] ?? '',
      mediaUrl: json['mediaUrl'],
      mediaType: json['mediaType'],
      mediaName: json['mediaName'],
      stats: PostStats.fromMap(statsMap),
      createdAt: parseDateTime(json['createdAt']) ?? DateTime.now(),
      editedAt: parseDateTime(json['editedAt']),
      // Denormalize alanlar
      authorName: json['authorName'],
      authorUsername: json['authorUsername'],
      authorRole: json['authorRole'],
      authorProfession: json['authorProfession'],
      // Repost/Quote alanları
      repostOfPostId: json['repostOfPostId'],
      isQuoteRepost: json['isQuoteRepost'] ?? false,
      repostedByUserId: json['repostedByUserId'],
      repostedByName: json['repostedByName'],
      repostedByUsername: json['repostedByUsername'],
      repostedByRole: json['repostedByRole'],
      // Yorum alanları
      isComment: json['isComment'] ?? false,
      rootPostId: json['rootPostId'],
      parentPostId: json['parentPostId'],
      // Etkileşim alanları
      likedBy: List<String>.from(json['likedBy'] ?? []),
      savedBy: List<String>.from(json['savedBy'] ?? []),
      // Mention alanları
      mentionedUserIds: List<String>.from(json['mentionedUserIds'] ?? []),
      // Soft delete
      deleted: json['deleted'] ?? false,
      docSnapshot: null, // Backend'den gelen verilerde docSnapshot yok
    );
  }
}

class PostStats {
  final int likeCount;
  final int replyCount;
  final int repostCount;
  final int quoteCount; // Alıntı sayısı

  PostStats({
    required this.likeCount,
    required this.replyCount,
    required this.repostCount,
    this.quoteCount = 0,
  });

  factory PostStats.fromMap(Map<String, dynamic> map) {
    return PostStats(
      likeCount: map['likeCount'] ?? 0,
      replyCount: map['replyCount'] ?? 0,
      repostCount: map['repostCount'] ?? 0,
      quoteCount: map['quoteCount'] ?? 0,
    );
  }

  // Repost butonunda gösterilecek toplam sayı (repost + quote)
  int get totalRepostAndQuote => repostCount + quoteCount;
}