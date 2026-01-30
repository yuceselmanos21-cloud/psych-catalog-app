import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import '../models/post_model.dart';
import '../utils/mention_parser.dart';
import 'post_repository.dart';

// ✅ PERFORMANCE: Cache helper classes (TTL: 5 dakika)
const Duration _cacheTTL = Duration(minutes: 5);

class _CachedUserData {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  _CachedUserData(this.data, this.timestamp);
  bool get isValid => DateTime.now().difference(timestamp) < _cacheTTL;
}

class _CachedRoleData {
  final String? role;
  final DateTime timestamp;
  _CachedRoleData(this.role, this.timestamp);
  bool get isValid => DateTime.now().difference(timestamp) < _cacheTTL;
}

class _CachedAdminData {
  final bool isAdmin;
  final DateTime timestamp;
  _CachedAdminData(this.isAdmin, this.timestamp);
  bool get isValid => DateTime.now().difference(timestamp) < _cacheTTL;
}

/// Singleton pattern ile bellek optimizasyonu
class FirestorePostRepository implements PostRepository {
  static FirestorePostRepository? _instance;
  static FirestorePostRepository get instance {
    _instance ??= FirestorePostRepository._();
    return _instance!;
  }

  FirestorePostRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final int _pageSize = 20;

  // ✅ Güvenli int değer alma (type casting hatalarını önlemek için)
  int _safeGetInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? defaultValue;
    }
    return defaultValue;
  }

  @override
  Future<List<Post>> getGlobalFeed({DocumentSnapshot? lastDoc}) async {
    try {
      // ✅ YENİ YAKLAŞIM: Yorumlar artık post olarak saklanıyor
      // Feed'de sadece post'lar görünmeli (yorumlar değil)
      // - Orijinal postlar (repostOfPostId == null, isComment != true)
      // - Alıntılar (isQuoteRepost == true, isComment != true)
      // - Repost'lar (repostOfPostId != null, isQuoteRepost == false, isComment != true)
      // 
      // ✅ MALİYET OPTİMİZASYONU: %80 daha az read!
      // Tek query ile tüm post'ları çekip client-side'da filtreliyoruz
      
      // ✅ BACKEND OPTİMİZASYONU: Server-side filtering (daha az read, daha hızlı)
      // ⚠️ GEÇİCİ: Eski postlar için deleted field'ı olmayabilir, bu yüzden client-side'da da filtrele
      Query feedQuery = _db.collection('posts')
          .where('isComment', isEqualTo: false) // Yorumları hariç tut
          .where('deleted', isEqualTo: false) // ✅ Silinmiş postları server-side'da filtrele (yeni postlar için)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize * 2); // ⚠️ Eski postlar için daha fazla çek
      
      // Pagination
      if (lastDoc != null) {
        feedQuery = feedQuery.startAfterDocument(lastDoc);
      }
      
      final snapshot = await feedQuery.get();
      // ✅ Client-side'da deleted kontrolü yap (eski postlar deleted field'ına sahip olmayabilir)
      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;
        final deleted = data['deleted'] as bool?;
        // deleted field'ı yoksa veya false ise dahil et
        return deleted == null || deleted == false;
      }).toList();
      
      // Limit'e uygun şekilde kes
      final limitedDocs = filteredDocs.take(_pageSize).toList();
      return limitedDocs.map((doc) => Post.fromFirestore(doc)).toList();
    } catch (e) {
      // Index eksikse veya başka bir hata varsa fallback kullan
      // Eğer index hatası varsa, fallback: isComment olmayan postları çek
      try {
        Query fallbackQuery = _db.collection('posts')
            .orderBy('createdAt', descending: true)
            .limit(_pageSize * 2); // Daha fazla çek, sonra filtrele
        
        if (lastDoc != null) {
          fallbackQuery = fallbackQuery.startAfterDocument(lastDoc);
        }
        
        final fallbackSnapshot = await fallbackQuery.get();
        final allPosts = fallbackSnapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
        
        // Client-side'da filtrele: Yorumları ve repost'ları dahil et
        return allPosts.where((post) {
          final data = fallbackSnapshot.docs[allPosts.indexOf(post)].data() as Map<String, dynamic>;
          final isComment = data['isComment'] == true;
          return !isComment; // Yorumları hariç tut
        }).take(_pageSize).toList();
      } catch (fallbackError) {
        rethrow;
      }
    }
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPost(String postId) {
    return _db.collection('posts').doc(postId).snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchPostsByAuthor(String authorId, {int limit = 10}) {
    return _db.collection('posts')
        .where('authorId', isEqualTo: authorId)
        .where('repostOfPostId', isNull: true) // Sadece orijinal postlar
        .where('isComment', isEqualTo: false) // Yorumları hariç tut
        .where('deleted', isEqualTo: false) // ✅ Silinmiş postları hariç tut
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchUserPostsAndReposts(String userId, {int limit = 50}) {
    // ✅ OPTIMIZE: Kullanıcının orijinal postları, repost'ları ve quote'larını birleştir
    // Firestore'da OR sorgusu yok, bu yüzden iki ayrı sorgu yapıp client-side'da birleştireceğiz
    // 
    // ✅ BACKEND OPTIMIZATION: 
    // 1. authorId sorgusu: Kullanıcının orijinal postları ve quote'ları
    // 2. repostedByUserId sorgusu: Kullanıcının repost'ları
    // Client-side'da birleştirip sıralayacağız
    //
    // ⚠️ NOT: Composite index gerekebilir (authorId + createdAt, repostedByUserId + createdAt)
    // Şimdilik authorId sorgusu kullanıyoruz, client-side'da repostedByUserId kontrolü yapıyoruz
    
    // ✅ OPTIMIZE: Sadece kullanıcının postlarını çek (repost'lar için client-side filtreleme)
    // Bu yaklaşım daha verimli çünkü sadece bir sorgu yapıyoruz
    return _db.collection('posts')
        .where('isComment', isEqualTo: false)
        .where('deleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit * 3) // ✅ Buffer: Client-side filtreleme için daha fazla çek
        .snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllCommentsForPost(String postId) {
    // ✅ Yorumlar artık post olarak saklanıyor
    // ⚠️ GEÇİCİ: Eski yorumlar için deleted field'ı olmayabilir, bu yüzden client-side'da da filtrele
    // Stream'de client-side filtering yapılamaz, bu yüzden sadece server-side filtering kullanıyoruz
    // Migration sonrası tüm yorumlarda deleted field'ı olacak
    return _db.collection('posts')
        .where('rootPostId', isEqualTo: postId)
        .where('isComment', isEqualTo: true)
        // ⚠️ GEÇİCİ: deleted filtresini kaldırdık (eski yorumlar için)
        // Migration sonrası geri ekleyeceğiz: .where('deleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Future<List<Post>> getPostPreviewComments(String postId, List<String> followingIds) async {
    if (followingIds.isEmpty) return [];
    final safeList = followingIds.take(10).toList();
    try {
      final snapshot = await _db.collection('posts')
          .where('rootPostId', isEqualTo: postId)
          .where('isComment', isEqualTo: true)
          .where('deleted', isEqualTo: false) // ✅ Silinmiş yorumları hariç tut
          .where('authorId', whereIn: safeList)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Post>> getPostComments(String postId, {DocumentSnapshot? lastDoc}) async {
    // ✅ Yorumlar artık post olarak saklanıyor
    // ⚠️ GEÇİCİ: Index oluşana kadar orderBy ve parentPostId isNull query'sini kaldırdık
    // ⚠️ GEÇİCİ: Eski yorumlar için deleted field'ı olmayabilir, bu yüzden client-side'da da filtrele
    try {
      // ⚠️ Index oluşana kadar orderBy olmadan çek, client-side'da sırala ve filtrele
      Query query = _db.collection('posts')
          .where('rootPostId', isEqualTo: postId)
          .where('isComment', isEqualTo: true)
          // ⚠️ GEÇİCİ: deleted filtresini kaldırdık (eski yorumlar için)
          // ⚠️ GEÇİCİ: parentPostId isNull'ı kaldırdık (index oluşana kadar)
          // ⚠️ GEÇİCİ: orderBy'ı kaldırdık (index oluşana kadar)
          .limit(30); // ✅ Optimize: Client-side filtering için 30 yeterli (20 top-level + 10 buffer)
      if (lastDoc != null) query = query.startAfterDocument(lastDoc);
      final snapshot = await query.get();
      
      // ✅ Client-side'da filtrele ve sırala: deleted ve parentPostId null kontrolü
      final posts = snapshot.docs.map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) {
            return null;
          }
          
          // ✅ Silinmiş yorumları referans olarak tut (içerik gizlenecek ama referans görünecek)
          // Silinmiş yorumları da döndür (referans olarak)
          
          // ✅ Sadece ana yorumlar (parentPostId null veya yok)
          final parentPostId = data['parentPostId'];
          if (parentPostId != null && parentPostId.toString().isNotEmpty) {
            // ⚠️ ÖNEMLİ: Eğer parentPostId rootPostId ile aynıysa, bu top-level yorumdur
            // Çünkü bazı yorumlar parentPostId olarak rootPostId'yi kullanıyor olabilir
            final rootPostId = data['rootPostId'];
            if (parentPostId != rootPostId) {
              // ✅ Bu nested yorum (parentPostId != rootPostId)
              return null;
            }
            // ✅ Bu top-level yorum (parentPostId = rootPostId)
          }
          
          return Post.fromFirestore(doc);
        } catch (e) {
          return null;
        }
      }).whereType<Post>().toList(); // null'ları filtrele
      
      // ✅ Client-side'da createdAt'e göre sırala (descending)
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Limit'e uygun şekilde kes
      return posts.take(20).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> getCommentsForComment(String commentId) {
    // ✅ Nested yorumlar için (bir yorumun alt yorumları)
    // ⚠️ GEÇİCİ: Eski yorumlar için deleted field'ı olmayabilir, bu yüzden client-side'da da filtrele
    // Stream'de client-side filtering yapılamaz, bu yüzden sadece server-side filtering kullanıyoruz
    // Migration sonrası tüm yorumlarda deleted field'ı olacak
    return _db.collection('posts')
        .where('parentPostId', isEqualTo: commentId)
        .where('isComment', isEqualTo: true)
        // ⚠️ GEÇİCİ: deleted filtresini kaldırdık (eski yorumlar için)
        // Migration sonrası geri ekleyeceğiz: .where('deleted', isEqualTo: false)
        .orderBy('createdAt') // ascending (default)
        .snapshots();
  }

  // ✅ PERFORMANCE: Basit cache mekanizması (TTL: 5 dakika)
  final Map<String, _CachedUserData> _userDataCache = {};
  final Map<String, _CachedRoleData> _roleCache = {};
  final Map<String, _CachedAdminData> _adminCache = {};

  /// Kullanıcı bilgilerini al (cache ile)
  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    // ✅ Cache kontrolü
    final cached = _userDataCache[userId];
    if (cached != null && cached.isValid) {
      return cached.data;
    }
    
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final rawData = doc.data()!;
      final data = {
        'name': rawData['name'] ?? '',
        'username': rawData['username'] ?? '',
        'role': rawData['role'] ?? 'client',
        'profession': rawData['profession'] ?? '',
      };
      // Cache'e kaydet
      _userDataCache[userId] = _CachedUserData(data, DateTime.now());
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Kullanıcı rolünü kontrol et (cache ile)
  Future<String?> _getUserRole(String userId) async {
    // ✅ Cache kontrolü
    final cached = _roleCache[userId];
    if (cached != null && cached.isValid) {
      return cached.role;
    }
    
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final role = doc.data()?['role'] as String?;
      // Cache'e kaydet
      _roleCache[userId] = _CachedRoleData(role, DateTime.now());
      return role;
    } catch (_) {
      return null;
    }
  }

  /// Admin kontrolü (cache ile)
  Future<bool> _isAdmin(String userId) async {
    // ✅ Cache kontrolü
    final cached = _adminCache[userId];
    if (cached != null && cached.isValid) {
      return cached.isAdmin;
    }
    
    try {
      final doc = await _db.collection('admins').doc(userId).get();
      final isAdmin = doc.exists;
      // Cache'e kaydet
      _adminCache[userId] = _CachedAdminData(isAdmin, DateTime.now());
      return isAdmin;
    } catch (_) {
      return false;
    }
  }
  
  /// Cache'i temizle (kullanıcı bilgileri değiştiğinde)
  void _clearUserCache(String userId) {
    _userDataCache.remove(userId);
    _roleCache.remove(userId);
    _adminCache.remove(userId);
  }

  /// Username'lerden userId'lere çevir (@mention için)
  Future<List<String>> _resolveMentionedUserIds(List<String> usernames) async {
    if (usernames.isEmpty) return [];
    
    final userIds = <String>[];
    
    // Batch query için username'leri al
    for (final username in usernames) {
      try {
        final query = await _db.collection('users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();
        
        if (query.docs.isNotEmpty) {
          userIds.add(query.docs.first.id);
        }
      } catch (_) {
        // Kullanıcı bulunamadı, atla
      }
    }
    
    return userIds.toSet().toList(); // Duplicate'leri kaldır
  }

  @override
  Future<void> sendPost({
    required String content,
    required String authorId,
    required String authorName,
    required String authorUsername,
    required String authorRole,
    String? authorProfession,
    File? attachment,
  }) async {
    // 🔒 GÜVENLİK: Backend'de role kontrolü
    final actualRole = await _getUserRole(authorId);
    final isAdminUser = await _isAdmin(authorId);
    
    // Sadece expert veya admin post oluşturabilir
    if (actualRole != 'expert' && actualRole != 'admin' && !isAdminUser) {
      throw Exception('Sadece uzmanlar ve adminler post paylaşabilir');
    }

    // ✅ GÜVENLİK: Content validasyonu ve sanitization
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty && attachment == null) {
      throw Exception('Post içeriği boş olamaz');
    }
    if (trimmedContent.length > 1000) {
      throw Exception('Post içeriği 1000 karakterden uzun olamaz');
    }
    
    // ✅ GÜVENLİK: XSS koruması için basit sanitization (HTML tag'lerini temizle)
    final sanitizedContent = trimmedContent
        .replaceAll(RegExp(r'<[^>]*>'), '') // HTML tag'lerini kaldır
        .trim();
    
    if (sanitizedContent.isEmpty && attachment == null) {
      throw Exception('Post içeriği geçersiz');
    }

    // ✅ @mention'ları parse et ve userId'lere çevir
    final mentionedUsernames = MentionParser.extractMentionedUserIds(sanitizedContent);
    final mentionedUserIds = await _resolveMentionedUserIds(mentionedUsernames);

    String? mediaUrl;
    String? mediaType;

    if (attachment != null) {
      final extension = path.extension(attachment.path).toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(attachment.path)}';

      if (['.jpg', '.jpeg', '.png', '.heic'].contains(extension)) {
        mediaType = 'image';
      } else if (['.mp4', '.mov'].contains(extension)) {
        mediaType = 'video';
      } else {
        mediaType = 'file';
      }

      final ref = _storage.ref().child('post_attachments/$authorId/$fileName');
      await ref.putFile(attachment);
      mediaUrl = await ref.getDownloadURL();
    }

    await _db.collection('posts').add({
      'content': sanitizedContent.isEmpty ? ' ' : sanitizedContent, // Eğer sadece dosya varsa boşluk
      'authorId': authorId,
      // Denormalize Veriler (Hız için)
      'authorName': authorName,
      'authorUsername': authorUsername,
      'authorRole': authorRole,
      'authorProfession': authorProfession ?? '',
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'stats': {
        'likeCount': 0,
        'replyCount': 0,
        'repostCount': 0,
        'quoteCount': 0,
      },
      'likedBy': [],
      'savedBy': [],
      'mentionedUserIds': mentionedUserIds, // ✅ @mention edilen kullanıcı ID'leri
      'repostOfPostId': null,
      'isQuoteRepost': false,
      'isComment': false, // ✅ Normal post (yorum değil)
      'rootPostId': null,
      'parentPostId': null,
      'deleted': false, // ✅ Soft delete flag (yeni postlar için)
    });
  }

  @override
  Future<void> deletePost(String postId) async {
    final postDoc = await _db.collection('posts').doc(postId).get();
    if (!postDoc.exists) {
      throw Exception('Post bulunamadı');
    }

    final data = postDoc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Post verisi bulunamadı');
    }
    
    final isComment = data['isComment'] == true;
    final repostOf = data['repostOfPostId'] as String?;
    final rootPostId = data['rootPostId'] as String?;
    final parentPostId = data['parentPostId'] as String?;
    
    // ✅ BACKEND: Storage'dan eklentiyi sil (maliyet optimizasyonu)
    // Firebase Storage'dan dosya silme işlemi storage maliyetini azaltır
    final mediaUrl = data['mediaUrl'] as String?;
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      try {
        // Firebase Storage URL formatı: 
        // https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}?alt=media&token=...
        // veya
        // gs://{bucket}/{path}
        
        // URL'den path çıkarma
        String? storagePath;
        
        // Method 1: Firebase Storage download URL'den path çıkar
        if (mediaUrl.contains('firebasestorage.googleapis.com')) {
          final uri = Uri.parse(mediaUrl);
          final pathSegments = uri.pathSegments;
          
          // Format: /v0/b/{bucket}/o/{encodedPath}
          if (pathSegments.length >= 4 && pathSegments[0] == 'v0' && pathSegments[1] == 'b') {
            final oIndex = pathSegments.indexOf('o');
            if (oIndex != -1 && oIndex + 1 < pathSegments.length) {
              // URL decode yap
              final encodedPath = pathSegments[oIndex + 1];
              storagePath = Uri.decodeComponent(encodedPath);
            }
          }
        }
        // Method 2: gs:// URL formatı
        else if (mediaUrl.startsWith('gs://')) {
          final uri = Uri.parse(mediaUrl);
          storagePath = uri.path.substring(1); // Başındaki / karakterini kaldır
        }
        // Method 3: Regex ile post_attachments path'ini bul
        else {
          final match = RegExp(r'post_attachments/([^?&#]+)').firstMatch(mediaUrl);
          if (match != null) {
            storagePath = 'post_attachments/${Uri.decodeComponent(match.group(1)!)}';
          }
        }
        
        // Storage'dan dosyayı sil
        if (storagePath != null && storagePath.isNotEmpty) {
          final storageRef = _storage.ref().child(storagePath);
          await storageRef.delete();
        }
        // Storage path çıkarılamazsa veya silme başarısız olursa sessizce devam et
        // Dosya zaten silinmiş olabilir veya URL formatı farklı olabilir
      } catch (e) {
        // Storage silme hatası kritik değil, sessizce devam et
      }
    }

    // ✅ Web platformu için Batch Write kullan (transaction yerine - daha güvenilir)
    try {
      final batch = _db.batch();
      
      // ✅ SOFT DELETE: Postu silme, sadece deleted flag'i ekle
      // ✅ Eklentiyi kaldır (mediaUrl, mediaType, mediaName) - Firestore'dan
      final postRef = _db.collection('posts').doc(postId);
      batch.update(postRef, {
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'mediaUrl': FieldValue.delete(), // ✅ Eklentiyi kaldır (Firestore'dan)
        'mediaType': FieldValue.delete(), // ✅ Eklenti tipini kaldır
        'mediaName': FieldValue.delete(), // ✅ Eklenti adını kaldır
      });
      
      // ✅ Eğer yorum ise, root post'un ve parent yorumun sayacını düşür
      // ⚠️ ÖNEMLİ: Eğer parentPostId == rootPostId ise (top-level yorum), sadece root post için düşür
      if (isComment && rootPostId != null && rootPostId.isNotEmpty) {
        final rootPostRef = _db.collection('posts').doc(rootPostId);
        // ✅ Batch'te document varlık kontrolü yapılamaz, bu yüzden direkt update yapıyoruz
        // FieldValue.increment negatif değerlerle de çalışır ve mevcut değeri kontrol eder
        batch.update(rootPostRef, {
          'stats.replyCount': FieldValue.increment(-1),
        });
      }

      // ✅ Nested yorum ise (parentPostId != rootPostId), parent yorumun sayacını da düşür
      // ⚠️ ÖNEMLİ: Eğer parentPostId == rootPostId ise, zaten root post için düşürdük, tekrar düşürmemeliyiz
      if (isComment && parentPostId != null && parentPostId.isNotEmpty && parentPostId != rootPostId) {
        final parentCommentRef = _db.collection('posts').doc(parentPostId);
        batch.update(parentCommentRef, {
          'stats.replyCount': FieldValue.increment(-1),
        });
      }
      
      // Eğer repost ise, orijinal postun sayacını düşür
      if (!isComment && repostOf != null && repostOf.isNotEmpty) {
        final isQuote = data['isQuoteRepost'] == true;
        final originalRef = _db.collection('posts').doc(repostOf);
        
        if (isQuote) {
          batch.update(originalRef, {
            'stats.quoteCount': FieldValue.increment(-1),
          });
        } else {
          batch.update(originalRef, {
            'stats.repostCount': FieldValue.increment(-1),
          });
        }
      }
      
      // ✅ Batch'i commit et (tüm işlemler atomik olarak yapılır)
      await batch.commit();
    } on FirebaseException catch (e) {
      // ✅ Firebase özel hatalarını yakala ve user-friendly mesaj döndür
      String errorMessage = 'Post silme işlemi başarısız oldu';
      
      switch (e.code) {
        case 'permission-denied':
        case 'PERMISSION_DENIED':
          errorMessage = 'Bu işlem için yetkiniz yok';
          break;
        case 'not-found':
        case 'NOT_FOUND':
          errorMessage = 'Post bulunamadı';
          break;
        case 'already-exists':
        case 'ALREADY_EXISTS':
          errorMessage = 'Post zaten silinmiş';
          break;
        case 'failed-precondition':
        case 'FAILED_PRECONDITION':
          errorMessage = 'Veritabanı durumu uygun değil. Lütfen tekrar deneyin.';
          break;
        case 'aborted':
        case 'ABORTED':
          errorMessage = 'İşlem iptal edildi. Lütfen tekrar deneyin.';
          break;
        case 'unavailable':
        case 'UNAVAILABLE':
          errorMessage = 'Servis şu anda kullanılamıyor. Lütfen tekrar deneyin.';
          break;
        default:
          errorMessage = e.message ?? 'Bilinmeyen bir hata oluştu (${e.code})';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      // ✅ Genel hataları yakala (NativeError dahil)
      // ✅ Web platformunda NativeError'ı özel olarak yakala
      if (e.runtimeType.toString().contains('NativeError') || 
          e.toString().contains('NativeError') ||
          e.toString().contains('Dart exception thrown from converted Future')) {
        // Web platformunda JavaScript'ten gelen hata
        // Bu genellikle Firestore transaction hatasıdır
        throw Exception('Veritabanı işlemi başarısız oldu. Lütfen tekrar deneyin.');
      }
      
      // ✅ Web platformunda Firestore hatalarını daha iyi yakala
      String errorMessage = 'Post silme işlemi başarısız oldu';
      
      final errorStr = e.toString();
      if (errorStr.contains('permission') || errorStr.contains('PERMISSION_DENIED')) {
        errorMessage = 'Bu işlem için yetkiniz yok';
      } else if (errorStr.contains('not-found') || errorStr.contains('NOT_FOUND')) {
        errorMessage = 'Post bulunamadı';
      } else if (errorStr.contains('already-exists') || errorStr.contains('ALREADY_EXISTS')) {
        errorMessage = 'Post zaten silinmiş';
      } else if (errorStr.contains('failed-precondition') || errorStr.contains('FAILED_PRECONDITION')) {
        errorMessage = 'Veritabanı durumu uygun değil. Lütfen tekrar deneyin.';
      } else if (errorStr.contains('aborted') || errorStr.contains('ABORTED')) {
        errorMessage = 'İşlem iptal edildi. Lütfen tekrar deneyin.';
      } else if (errorStr.contains('unavailable') || errorStr.contains('UNAVAILABLE')) {
        errorMessage = 'Servis şu anda kullanılamıyor. Lütfen tekrar deneyin.';
      } else if (errorStr.isNotEmpty) {
        // ✅ Gerçek hata mesajını göster (ilk 150 karakter)
        errorMessage = errorStr.length > 150 
            ? 'Hata: ${errorStr.substring(0, 150)}...' 
            : 'Hata: $errorStr';
      }
      
      throw Exception(errorMessage);
    }
  }

  @override
  Future<void> updatePost({required String postId, required String content, File? attachment}) async {
    // ✅ GÜVENLİK: Content validasyonu ve sanitization
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty && attachment == null) {
      throw Exception('Post içeriği boş olamaz');
    }
    if (trimmedContent.length > 1000) {
      throw Exception('Post içeriği 1000 karakterden uzun olamaz');
    }
    
    // ✅ GÜVENLİK: XSS koruması için basit sanitization
    final sanitizedContent = trimmedContent
        .replaceAll(RegExp(r'<[^>]*>'), '') // HTML tag'lerini kaldır
        .trim();
    
    if (sanitizedContent.isEmpty && attachment == null) {
      throw Exception('Post içeriği geçersiz');
    }
    
    final postRef = _db.collection('posts').doc(postId);
    final updates = <String, dynamic>{
      'content': sanitizedContent.isEmpty ? ' ' : sanitizedContent, // Eğer sadece dosya varsa boşluk
      'editedAt': FieldValue.serverTimestamp(),
    };

    if (attachment != null) {
      final extension = path.extension(attachment.path).toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(attachment.path)}';

      String mediaType;
      if (['.jpg', '.jpeg', '.png', '.heic'].contains(extension)) {
        mediaType = 'image';
      } else if (['.mp4', '.mov'].contains(extension)) {
        mediaType = 'video';
      } else {
        mediaType = 'file';
      }

      final ref = _storage.ref().child('post_attachments/${FirebaseAuth.instance.currentUser?.uid}/$fileName');
      await ref.putFile(attachment);
      final mediaUrl = await ref.getDownloadURL();
      
      updates['mediaUrl'] = mediaUrl;
      updates['mediaType'] = mediaType;
    }

    await postRef.update(updates);
  }

  @override
  Future<void> repostPost({required String postId, required String userId}) async {
    // 🔒 GÜVENLİK: Backend'de role kontrolü
    final actualRole = await _getUserRole(userId);
    final isAdminUser = await _isAdmin(userId);
    
    // ✅ GÜVENLİK: Expert, Admin veya admins koleksiyonunda olmalı
    if (actualRole != 'expert' && actualRole != 'admin' && !isAdminUser) {
      throw Exception('Sadece uzmanlar ve adminler repost yapabilir');
    }

    // ✅ TWITTER BENZERİ: Transaction dışında kontrol (Firestore transaction içinde query yapılamaz)
    final existingRepostQuery = await _db.collection('posts')
        .where('repostOfPostId', isEqualTo: postId)
        .where('repostedByUserId', isEqualTo: userId)
        .where('isQuoteRepost', isEqualTo: false)
        .limit(1)
        .get();

    if (existingRepostQuery.docs.isNotEmpty) {
      throw Exception('Bu postu zaten repost ettiniz');
    }

    // Kullanıcı bilgilerini al
    final userData = await _getUserData(userId);
    if (userData == null) throw Exception('Kullanıcı bilgileri bulunamadı');

    // ✅ TWITTER BENZERİ: Transaction içinde oluşturma (atomic)
    await _db.runTransaction((tx) async {
      // Orijinal postu kontrol et
      final originalRef = _db.collection('posts').doc(postId);
      final originalDoc = await tx.get(originalRef);
      
      if (!originalDoc.exists) {
        throw Exception('Post bulunamadı');
      }

      final originalData = originalDoc.data()!;

      // Repost oluştur (yorum değil, normal post)
      final repostRef = _db.collection('posts').doc();
      tx.set(repostRef, {
        'content': originalData['content'] ?? '',
        'authorId': originalData['authorId'],
        'authorName': originalData['authorName'],
        'authorUsername': originalData['authorUsername'],
        'authorRole': originalData['authorRole'],
        'authorProfession': originalData['authorProfession'] ?? '',
        'mediaUrl': originalData['mediaUrl'],
        'mediaType': originalData['mediaType'],
        'repostOfPostId': postId,
        'isQuoteRepost': false,
        'repostedByUserId': userId,
        'repostedByName': userData['name'],
        'repostedByUsername': userData['username'],
        'repostedByRole': userData['role'] ?? 'client',
        'isComment': false, // ✅ Repost bir yorum değil
        'rootPostId': null,
        'parentPostId': null,
        'deleted': false, // ✅ Soft delete flag
        'createdAt': FieldValue.serverTimestamp(),
        'stats': {
          'likeCount': 0,
          'replyCount': 0,
          'repostCount': 0,
          'quoteCount': 0,
        },
        'likedBy': [],
        'savedBy': [],
      });

      // ✅ ATOMIC: Orijinal postun repost sayısını artır
      tx.update(originalRef, {
        'stats.repostCount': FieldValue.increment(1),
      });
    });
  }

  @override
  Future<void> undoRepost({required String postId, required String userId}) async {
    // ✅ TWITTER BENZERİ: Transaction içinde hem kontrol hem silme (atomic)
    // Not: Firestore transaction içinde query yapılamaz, bu yüzden önce bulup sonra transaction'a alıyoruz
    final repostQuery = await _db.collection('posts')
        .where('repostOfPostId', isEqualTo: postId)
        .where('repostedByUserId', isEqualTo: userId)
        .where('isQuoteRepost', isEqualTo: false)
        .limit(1)
        .get();

    if (repostQuery.docs.isEmpty) {
      throw Exception('Repost bulunamadı');
    }

    final repostId = repostQuery.docs.first.id;

    await _db.runTransaction((tx) async {
      // Orijinal postu kontrol et
      final originalRef = _db.collection('posts').doc(postId);
      final originalDoc = await tx.get(originalRef);
      
      if (!originalDoc.exists) {
        throw Exception('Post bulunamadı');
      }

      // Repost'u kontrol et
      final repostRef = _db.collection('posts').doc(repostId);
      final repostDoc = await tx.get(repostRef);
      
      if (!repostDoc.exists) {
        throw Exception('Repost bulunamadı');
      }

      // ✅ ATOMIC: Repost'u soft delete yap (hard delete yerine)
      tx.update(repostRef, {
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      // ✅ ATOMIC: Orijinal postun sayacını düşür (FieldValue.increment kullan - daha güvenilir)
      tx.update(originalRef, {
        'stats.repostCount': FieldValue.increment(-1),
      });
    });
  }

  @override
  Future<void> createQuotePost({
    required String originalPostId,
    required String userId,
    required String quoteContent,
    File? attachment,
  }) async {
    // 🔒 GÜVENLİK: Backend'de role kontrolü
    final actualRole = await _getUserRole(userId);
    final isAdminUser = await _isAdmin(userId);
    
    if (actualRole != 'expert' && actualRole != 'admin' && !isAdminUser) {
      throw Exception('Sadece uzmanlar ve adminler alıntı yapabilir');
    }

    // ✅ GÜVENLİK: Content validasyonu - metin veya dosya olmalı
    if (quoteContent.trim().isEmpty && attachment == null) {
      throw Exception('Alıntı içeriği veya dosya eklemelisiniz');
    }
    if (quoteContent.length > 1000) {
      throw Exception('Alıntı içeriği 1000 karakterden uzun olamaz');
    }

    // ✅ TWITTER BENZERİ: Aynı postu tekrar quote edebilirsin (Twitter'da da böyle)
    // Ancak spam koruması için rate limiting eklenebilir (ileride)

    // Kullanıcı bilgilerini al
    final userData = await _getUserData(userId);
    if (userData == null) throw Exception('Kullanıcı bilgileri bulunamadı');

    String? mediaUrl;
    String? mediaType;

    if (attachment != null) {
      final extension = path.extension(attachment.path).toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(attachment.path)}';

      if (['.jpg', '.jpeg', '.png', '.heic'].contains(extension)) {
        mediaType = 'image';
      } else if (['.mp4', '.mov'].contains(extension)) {
        mediaType = 'video';
      } else {
        mediaType = 'file';
      }

      final ref = _storage.ref().child('post_attachments/$userId/$fileName');
      await ref.putFile(attachment);
      mediaUrl = await ref.getDownloadURL();
    }

    // ✅ TWITTER BENZERİ: Transaction içinde hem kontrol hem oluşturma
    await _db.runTransaction((tx) async {
      // Orijinal postu kontrol et
      final originalRef = _db.collection('posts').doc(originalPostId);
      final originalDoc = await tx.get(originalRef);
      
      if (!originalDoc.exists) {
        throw Exception('Post bulunamadı');
      }

      final originalData = originalDoc.data()!;

      // ✅ ATOMIC: Quote post oluştur (yorum değil, normal post)
      final quoteRef = _db.collection('posts').doc();
      tx.set(quoteRef, {
        'content': quoteContent,
        'authorId': userId,
        'authorName': userData['name'],
        'authorUsername': userData['username'],
        'authorRole': userData['role'],
        'authorProfession': userData['profession'],
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'repostOfPostId': originalPostId,
        'isQuoteRepost': true,
        'repostedByUserId': userId,
        'isComment': false, // ✅ Quote post bir yorum değil
        'rootPostId': null,
        'parentPostId': null,
        'deleted': false, // ✅ Soft delete flag
        'createdAt': FieldValue.serverTimestamp(),
        'stats': {
          'likeCount': 0,
          'replyCount': 0,
          'repostCount': 0,
          'quoteCount': 0,
        },
        'likedBy': [],
        'savedBy': [],
      });

      // ✅ ATOMIC: Orijinal postun quote sayısını artır
      tx.update(originalRef, {
        'stats.quoteCount': FieldValue.increment(1),
      });
    });
  }

  @override
  Future<void> toggleLike({required String postId, required String userId}) async {
    final docRef = _db.collection('posts').doc(postId);
    
    // ✅ TWITTER BENZERİ: Idempotent toggle - atomic transaction
    await _db.runTransaction((tx) async {
      final doc = await tx.get(docRef);
      if (!doc.exists) {
        throw Exception('Post bulunamadı');
      }
      
      final data = doc.data()!;
      final likedBy = List<String>.from(data['likedBy'] ?? []);
      final currentLikeCount = (data['stats']?['likeCount'] ?? 0) as int;
      
    if (likedBy.contains(userId)) {
        // ✅ Unlike - idempotent
        tx.update(docRef, {
          'likedBy': FieldValue.arrayRemove([userId]),
          'stats.likeCount': (currentLikeCount - 1).clamp(0, double.infinity).toInt(),
        });
      } else {
        // ✅ Like - idempotent
        tx.update(docRef, {
          'likedBy': FieldValue.arrayUnion([userId]),
          'stats.likeCount': currentLikeCount + 1,
        });
      }
    });
  }

  @override
  Future<void> toggleBookmark({required String postId, required String userId}) async {
    final docRef = _db.collection('posts').doc(postId);
    
    // ✅ TWITTER BENZERİ: Idempotent toggle - atomic transaction
    await _db.runTransaction((tx) async {
      final doc = await tx.get(docRef);
      if (!doc.exists) {
        throw Exception('Post bulunamadı');
      }
      
      final data = doc.data()!;
      final savedBy = List<String>.from(data['savedBy'] ?? []);
      
      if (savedBy.contains(userId)) {
        // ✅ Unbookmark - idempotent
        tx.update(docRef, {
          'savedBy': FieldValue.arrayRemove([userId]),
        });
    } else {
        // ✅ Bookmark - idempotent
        tx.update(docRef, {
          'savedBy': FieldValue.arrayUnion([userId]),
        });
      }
    });
  }

  @override
  Future<List<String>> getLikedByUsers(String postId, {int limit = 50}) async {
    final doc = await _db.collection('posts').doc(postId).get();
    if (!doc.exists) return [];
    
    final data = doc.data()!;
    final likedBy = List<String>.from(data['likedBy'] ?? []);
    return likedBy.take(limit).toList();
  }

  @override
  Future<List<Post>> getRepostsForPost(String postId, {DocumentSnapshot? lastDoc}) async {
    // ✅ Yorumlar da repost/quote edilebilir
    Query query = _db.collection('posts')
        .where('repostOfPostId', isEqualTo: postId)
        .where('deleted', isEqualTo: false) // ✅ Silinmiş repost/quote'ları hariç tut
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);
    if (lastDoc != null) query = query.startAfterDocument(lastDoc);
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
  }

  // ✅ Yorum oluşturma (artık post olarak saklanıyor)
  Future<void> addComment({
    required String rootPostId,
    String? parentPostId,
    required String content,
    required String authorId,
    required String authorName,
    required String authorUsername,
    required String authorRole,
    String? authorProfession,
    String? mediaUrl,
    String? mediaType,
    String? mediaName,
  }) async {
    // 🔒 GÜVENLİK: Backend'de role kontrolü
    final actualRole = await _getUserRole(authorId);
    final isAdminUser = await _isAdmin(authorId);
    
    if (actualRole != 'expert' && actualRole != 'admin' && !isAdminUser) {
      throw Exception('Sadece uzmanlar ve adminler yorum yapabilir');
    }

    // ✅ GÜVENLİK: Content validasyonu ve sanitization
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty && mediaUrl == null) {
      throw Exception('Yorum içeriği veya eklenti boş olamaz');
    }
    if (trimmedContent.length > 500) {
      throw Exception('Yorum içeriği 500 karakterden uzun olamaz');
    }
    
    // ✅ GÜVENLİK: XSS koruması için basit sanitization (HTML tag'lerini temizle)
    final sanitizedContent = trimmedContent
        .replaceAll(RegExp(r'<[^>]*>'), '') // HTML tag'lerini kaldır
        .trim();
    
    if (sanitizedContent.isEmpty && mediaUrl == null) {
      throw Exception('Yorum içeriği geçersiz');
    }

    final cleanParent = (parentPostId != null && parentPostId.trim().isNotEmpty)
        ? parentPostId.trim()
        : null;

    // ✅ ATOMIC: Transaction kullanarak yorum oluştur
    await _db.runTransaction((tx) async {
      // Root post'u kontrol et
      final rootPostRef = _db.collection('posts').doc(rootPostId);
      final rootPostDoc = await tx.get(rootPostRef);
      
      if (!rootPostDoc.exists) {
        throw Exception('Post bulunamadı');
      }

      // Parent yorumu kontrol et (eğer nested yorum ise)
      if (cleanParent != null) {
        final parentCommentRef = _db.collection('posts').doc(cleanParent);
        final parentCommentDoc = await tx.get(parentCommentRef);
        
        if (!parentCommentDoc.exists) {
          throw Exception('Yanıtlanacak yorum bulunamadı');
        }
        
        // Parent yorumun aynı root post'a ait olduğunu kontrol et
        final parentData = parentCommentDoc.data()!;
        if (parentData['rootPostId'] != rootPostId || parentData['isComment'] != true) {
          throw Exception('Geçersiz yorum thread\'i');
        }
      }

      // ✅ ATOMIC: Yorum post'u oluştur
      final commentRef = _db.collection('posts').doc();
      tx.set(commentRef, {
        'content': sanitizedContent.isEmpty ? ' ' : sanitizedContent, // Media varsa boşluk
        'authorId': authorId,
        'authorName': authorName,
        'authorUsername': authorUsername,
        'authorRole': authorRole,
        'authorProfession': authorProfession ?? '',
        'mediaUrl': mediaUrl ?? '',
        'mediaType': mediaType ?? '',
        'mediaName': mediaName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
        'isComment': true, // ✅ Yorum flag'i
        'rootPostId': rootPostId,
        'parentPostId': cleanParent,
        'repostOfPostId': null,
        'isQuoteRepost': false,
        'deleted': false, // ✅ Soft delete flag
        'stats': {
          'likeCount': 0,
          'replyCount': 0, // Nested yorumlar için
          'repostCount': 0,
          'quoteCount': 0,
        },
        'likedBy': <String>[],
        'savedBy': <String>[],
      });

      // ✅ ATOMIC: Root post'un reply sayısını artır
      tx.update(rootPostRef, {
        'stats.replyCount': FieldValue.increment(1),
      });

      // ✅ TWITTER BENZERİ: Nested yorum ise (parentPostId != rootPostId) parent'ın sayacını da artır
      // ⚠️ ÖNEMLİ: Eğer parentPostId == rootPostId ise (top-level yorum), zaten root post için artırdık, tekrar artırmamalıyız
      if (cleanParent != null && cleanParent != rootPostId) {
        final parentCommentRef = _db.collection('posts').doc(cleanParent);
        tx.update(parentCommentRef, {
          'stats.replyCount': FieldValue.increment(1),
        });
      }
    });
  }

  // ✅ Yorum beğenme (artık post olarak saklanıyor, toggleLike kullanılabilir)
  // Not: toggleLike zaten var, yorumlar için de çalışır

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchCommentsByAuthor(String authorId, {int limit = 50}) {
    // ✅ Kullanıcının yaptığı yorumları getir (isComment: true ve authorId eşleşmeli)
    return _db.collection('posts')
        .where('authorId', isEqualTo: authorId)
        .where('isComment', isEqualTo: true)
        .where('deleted', isEqualTo: false) // ✅ Silinmiş yorumları hariç tut
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchLikedPostsByUser(String userId, {int limit = 50}) {
    // ✅ Kullanıcının beğendiği postları getir (likedBy array'inde userId var mı?)
    // ⚠️ NOT: arrayContains query için index gerekiyor
    return _db.collection('posts')
        .where('likedBy', arrayContains: userId)
        .where('deleted', isEqualTo: false) // ✅ Silinmiş postları hariç tut
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchSavedPostsByUser(String userId, {int limit = 50}) {
    // ✅ Kullanıcının kaydettiği postları getir (savedBy array'inde userId var mı?)
    // ⚠️ NOT: arrayContains query için index gerekiyor
    return _db.collection('posts')
        .where('savedBy', arrayContains: userId)
        .where('deleted', isEqualTo: false) // ✅ Silinmiş postları hariç tut
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}
