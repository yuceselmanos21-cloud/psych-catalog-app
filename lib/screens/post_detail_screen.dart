import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';
import '../repositories/firestore_post_repository.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FirestorePostRepository _postRepo = FirestorePostRepository.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _reposting = false;
  String _currentUserId = '';
  String? _currentUserRole;
  bool _isAdmin = false;
  List<String> _myFollowingIds = []; // PostCard için
  
  // ✅ PERFORMANCE: Kullanıcı bilgilerini cache'le (gereksiz query'leri önle)
  String? _cachedUserName;
  String? _cachedUserUsername;
  String? _cachedUserProfession;
  
  // ✅ Yorum sistemi (artık Post olarak saklanıyor)
  final TextEditingController _replyCtrl = TextEditingController();
  bool _isReplying = false;
  String? _replyingToCommentId; // ✅ Hangi yoruma yanıt veriliyor
  List<Post> _comments = []; // ✅ Reply yerine Post
  bool _loadingComments = false;
  DocumentSnapshot? _lastCommentDoc;
  bool _hasMoreComments = true;
  bool _hasTriedLoadingComments = false; // ✅ İlk yükleme denemesi yapıldı mı?
  
  // ✅ Yorum detayı için parent thread
  Post? _rootPost; // Ana post (eğer yorum ise)
  List<Post> _parentComments = []; // Parent yorumlar (kuyruk)
  bool _loadingParentThread = false;
  Post? _currentPost; // Mevcut post (yorum detayı için)
  
  // ✅ Eklenti desteği
  File? _selectedFile;
  String? _fileType;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadUserData();
  }
  
  @override
  void dispose() {
    // ✅ Geri butonuna basıldığında state'i temizle
    _rootPost = null;
    _parentComments.clear();
    _currentPost = null;
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (_currentUserId.isEmpty) return;
    try {
      // ✅ OPTİMİZASYON: Paralel olarak kullanıcı, admin ve following bilgilerini çek
      final userFuture = FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      final adminFuture = FirebaseFirestore.instance.collection('admins').doc(_currentUserId).get();
      final followingFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('following')
          .get();
      
      final results = await Future.wait([userFuture, adminFuture, followingFuture]);
      final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final adminDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      final followingSnapshot = results[2] as QuerySnapshot<Map<String, dynamic>>;
      
      if (mounted) {
        String? userRole;
        if (userDoc.exists) {
          final data = userDoc.data();
          userRole = data?['role'] as String?;
        }
        
        // Admin kontrolü
        final isAdminFromCollection = adminDoc.exists;
        final isAdminFromRole = userRole == 'admin';
        final isAdmin = isAdminFromCollection || isAdminFromRole;
        
        // Following listesi
        final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();
        
        // ✅ PERFORMANCE: Kullanıcı bilgilerini cache'le
        final userData = userDoc.data();
        if (userData != null) {
          _cachedUserName = userData['name'] as String?;
          _cachedUserUsername = userData['username'] as String?;
          _cachedUserProfession = userData['profession'] as String?;
        }
        
        setState(() {
          _currentUserRole = userRole;
          _isAdmin = isAdmin;
          _myFollowingIds = followingIds;
          // ✅ Admin ise role'ü de 'admin' olarak set et
          if (isAdmin && _currentUserRole != 'admin') {
            _currentUserRole = 'admin';
          }
        });
      }
    } catch (_) {}
    
    // Yorumları yükle (sadece normal post için, yorum detay ekranında StreamBuilder kullanılacak)
    // Post bilgisi geldiğinde yüklenecek
  }

  bool get _canRepost => _currentUserRole == 'expert' || _currentUserRole == 'admin' || _isAdmin;
  bool get _canComment => _currentUserRole == 'expert' || _currentUserRole == 'admin' || _isAdmin;

  void _handleRepost() async {
    if (_reposting || !_canRepost) return;
    setState(() => _reposting = true);
    try {
      await _postRepo.repostPost(postId: widget.postId, userId: _currentUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Repost yapıldı.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _reposting = false);
    }
  }

  void _toggleLike() {
    if (_currentUserId.isEmpty) return;
    _postRepo.toggleLike(postId: widget.postId, userId: _currentUserId);
  }

  // ✅ Yorum like toggle (artık post olarak saklanıyor)
  void _toggleCommentLike(String commentId) {
    if (_currentUserId.isEmpty) return;
    _postRepo.toggleLike(postId: commentId, userId: _currentUserId);
  }

  // ✅ Yorum düzenleme
  Future<void> _editComment(Post comment) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: comment.content);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Yorumu Düzenle',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Yorum içeriği...',
            hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        await _postRepo.updatePost(
          postId: comment.id,
          content: result.trim(),
        );
        // Yorumları yeniden yükle
        setState(() {
          _comments.clear();
          _lastCommentDoc = null;
          _hasMoreComments = true;
        });
        await _loadComments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yorum güncellendi')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
  }

  // ✅ Yorum silme
  Future<void> _deleteComment(Post comment) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Yorumu Sil',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          'Bu yorumu silmek istediğinize emin misiniz?',
          style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // ✅ Silmeden önce yorumun bilgilerini sakla (thread güncellemesi için)
        final commentId = comment.id;
        final isInParentThread = _parentComments.any((p) => p.id == commentId);
        final isRootPost = _rootPost?.id == commentId;
        final isCurrentPost = _currentPost?.id == commentId;
        final hasChildComments = _comments.any((c) => c.parentPostId == commentId);
        
        await _postRepo.deletePost(commentId);
        
        // ✅ Eğer silinen yorum ana yorum ise (current post), geri git
        if (isCurrentPost && _currentPost != null) {
          setState(() {
            _parentComments.clear();
            _rootPost = null;
            _currentPost = null;
          });
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Yorum silindi')),
            );
          }
          return;
        }
        
        // ✅ Eğer silinen yorum parent thread'de ise, thread'i güncelle
        // ✅ MANTIK: 
        // - Kuyruğun sonundaki yorum silinirse → tamamen yok et
        // - Kuyruğun ortasındaki/başındaki yorum silinirse → "silindi" olarak göster
        // - Ancak kuyruğun sonundan başlayarak birkaç yorum silinirse → o silinen yorumları tamamen kaldır
        if (isInParentThread || isRootPost) {
          // ✅ Thread'i yeniden yükle (silinmiş yorumu da gösterecek)
          if (_currentPost != null) {
            // ✅ Current post'un güncel halini al (silme işlemi sonrası)
            try {
              final currentPostDoc = await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(_currentPost!.id)
                  .get();
              if (currentPostDoc.exists) {
                final updatedCurrentPost = Post.fromFirestore(currentPostDoc);
                
                // ✅ Eğer current post da silinmişse, geri git
                if (updatedCurrentPost.deleted) {
                  if (mounted) {
                    setState(() {
                      _parentComments.clear();
                      _rootPost = null;
                      _currentPost = null;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Yorum silindi')),
                    );
                  }
                  return;
                }
                
                // ✅ Thread'i yeniden yükle (bu zaten doğru şekilde temizlenmiş parent comments'i set edecek)
                await _loadCommentThread(updatedCurrentPost);
                
                // ✅ Current post'u güncelle (setState _loadCommentThread içinde yapılıyor)
                if (mounted) {
                  setState(() {
                    _currentPost = updatedCurrentPost;
                  });
                }
              } else {
                // Current post da silinmiş, geri git
                if (mounted) {
                  setState(() {
                    _parentComments.clear();
                    _rootPost = null;
                    _currentPost = null;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Yorum silindi')),
                  );
                }
                return;
              }
            } catch (e) {
              // Hata olsa bile thread'i yeniden yükle (mevcut current post ile)
              if (_currentPost != null) {
                await _loadCommentThread(_currentPost!);
              }
            }
          } else {
            // Eğer current post yoksa, sadece state'ten silinen yorumu çıkar
            // ✅ ÖNEMLİ: Sadece silinen yorumu çıkar, diğer yorumları manipüle etme
            if (mounted) {
              setState(() {
                // ✅ Sadece silinen yorumu listeden çıkar
                _parentComments.removeWhere((p) => p.id == commentId);
                // ✅ Eğer root post silindiyse, null yap
                if (isRootPost) {
                  _rootPost = null;
                }
              });
            }
          }
        }
        
        // ✅ Yorumları güncelle (silinen yorumu listeden çıkar)
        // Not: StreamBuilder ile yüklenen yorumlar otomatik olarak filtrelenecek (deleted: false)
        setState(() {
          _comments.removeWhere((c) => c.id == commentId);
          // Alt yorumları da listeden çıkar (eğer varsa)
          _comments.removeWhere((c) => c.parentPostId == commentId);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yorum silindi')),
          );
        }
      } catch (e) {
        if (mounted) {
          // ✅ User-friendly hata mesajı
          String errorMessage = 'Yorum silinirken bir hata oluştu';
          final errorStr = e.toString();
          if (errorStr.contains('Post bulunamadı') || errorStr.contains('bulunamadı')) {
            errorMessage = 'Yorum bulunamadı';
          } else if (errorStr.contains('transaction') || errorStr.contains('database') || errorStr.contains('veritabanı')) {
            errorMessage = 'Veritabanı işlemi başarısız oldu. Lütfen tekrar deneyin.';
          } else if (errorStr.isNotEmpty && errorStr.length < 100) {
            errorMessage = 'Hata: $errorStr';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.red.shade700,
              action: SnackBarAction(
                label: 'Tekrar Dene',
                textColor: Colors.white,
                onPressed: () => _deleteComment(comment),
              ),
            ),
          );
        }
      }
    }
  }

  // ✅ Parent ID'leri topla (recursive - verimli)
  List<String> _collectParentIds(String? parentPostId, List<String> collected) {
    if (parentPostId == null || parentPostId.isEmpty || collected.contains(parentPostId)) {
      return collected;
    }
    collected.add(parentPostId);
    return collected; // Parent ID'yi ekle, gerçek parent'ı yükleme sırasında bulacağız
  }
  
  // ✅ Yorum detayı için tüm thread'i yükle (VERİMLİ: Batch query)
  Future<void> _loadCommentThread(Post comment) async {
    if (!comment.isComment) return;
    
    setState(() => _loadingParentThread = true);
    try {
      // ✅ VERİMLİ: Önce tüm parent ID'lerini recursive olarak topla
      final List<String> postIdsToLoad = [];
      
      // Root post ID'yi ekle
      if (comment.rootPostId != null) {
        postIdsToLoad.add(comment.rootPostId!);
      }
      
      // ✅ Parent yorum ID'lerini recursive olarak topla
      // ⚠️ ÖNEMLİ: Silinmiş yorumlar da dahil edilmeli (chain kopmasın)
      String? currentParentId = comment.parentPostId;
      final Set<String> collectedIds = {};
      
      // Parent chain'i recursive olarak topla
      while (currentParentId != null && !collectedIds.contains(currentParentId)) {
        collectedIds.add(currentParentId);
        postIdsToLoad.add(currentParentId);
        
        try {
          // Parent'ın parent'ını bulmak için yükle
          // ⚠️ ÖNEMLİ: Silinmiş olsa bile parentPostId field'ı var, chain devam etmeli
          final parentDoc = await FirebaseFirestore.instance
              .collection('posts')
              .doc(currentParentId)
              .get();
          
          if (parentDoc.exists) {
            final parentData = parentDoc.data()!;
            // ✅ Silinmiş olsa bile parentPostId field'ını al (chain kopmasın)
            currentParentId = parentData['parentPostId'] as String?;
            // ✅ Eğer parentPostId null ise, chain sona erdi
            if (currentParentId == null) break;
          } else {
            // Doküman yok (hard delete edilmiş), chain'i kır
            print('⚠️ Parent yorum dokümanı bulunamadı (hard delete?): $currentParentId');
            break;
          }
        } catch (e) {
          print('⚠️ Parent ID toplama hatası: $e');
          break;
        }
      }
      
      // ✅ BATCH QUERY: Tüm post'ları bir seferde yükle (daha verimli)
      if (postIdsToLoad.isNotEmpty) {
        // Firestore'da 'in' query'si maksimum 10 item alabilir
        final batches = <List<String>>[];
        for (int i = 0; i < postIdsToLoad.length; i += 10) {
          batches.add(postIdsToLoad.sublist(i, (i + 10 > postIdsToLoad.length) ? postIdsToLoad.length : i + 10));
        }
        
        final Map<String, Post> postsMap = {};
        
        // Her batch'i yükle
        for (final batch in batches) {
          final snapshot = await FirebaseFirestore.instance
              .collection('posts')
              .where(FieldPath.documentId, whereIn: batch)
              .get();
          
          for (final doc in snapshot.docs) {
            postsMap[doc.id] = Post.fromFirestore(doc);
          }
        }
        
        // Root post'u ayır (silinmiş olsa bile sakla, UI'da kontrol edeceğiz)
        // ✅ ÖNEMLİ: State manipülasyonunu önlemek için sadece gerçekten değiştiğinde güncelle
        Post? newRootPost;
        if (comment.rootPostId != null && postsMap.containsKey(comment.rootPostId)) {
          newRootPost = postsMap[comment.rootPostId]!;
        } else if (comment.rootPostId != null) {
          // Root post bulunamadı veya silinmiş, yine de ID'yi sakla
          // UI'da "silinmiş" mesajı göstereceğiz
          try {
            final rootDoc = await FirebaseFirestore.instance
                .collection('posts')
                .doc(comment.rootPostId)
                .get();
            if (rootDoc.exists) {
              newRootPost = Post.fromFirestore(rootDoc);
            }
          } catch (e) {
            print('⚠️ Root post yükleme hatası: $e');
          }
        }
        
        // ✅ Parent yorumları sırayla topla (root'tan ana yoruma kadar)
        // ✅ Silinmiş yorumları da göster (chain kopmasın)
        final List<Post> orderedParents = [];
        String? currentId = comment.parentPostId;
        final Set<String> visited = {};
        
        while (currentId != null && !visited.contains(currentId)) {
          visited.add(currentId);
          
          // Önce map'te var mı kontrol et
          if (postsMap.containsKey(currentId)) {
            final parentPost = postsMap[currentId]!;
            // ✅ Silinmiş olsa bile ekle (chain kopmasın, UI'da "silinmiş" göstereceğiz)
            orderedParents.add(parentPost);
            currentId = parentPost.parentPostId;
          } else {
            // Map'te yok, direkt Firestore'dan yükle (silinmiş olabilir)
            try {
              final parentDoc = await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(currentId)
                  .get();
              if (parentDoc.exists) {
                final parentPost = Post.fromFirestore(parentDoc);
                // ✅ Silinmiş olsa bile ekle (chain kopmasın, UI'da "silinmiş" göstereceğiz)
                orderedParents.add(parentPost);
                currentId = parentPost.parentPostId;
                // ✅ Eğer parentPostId null ise, chain sona erdi
                if (currentId == null) break;
              } else {
                // Doküman yok, chain'i kır ama silinmiş olarak işaretle
                print('⚠️ Parent yorum bulunamadı: $currentId');
                break;
              }
            } catch (e) {
              print('⚠️ Parent yorum yükleme hatası: $e');
              break;
            }
          }
        }
        
        // ✅ Parent yorumları ters çevir (root'tan ana yoruma doğru sıralama için)
        // Şu anda orderedParents root'tan uzak olanı önce ekliyor, ters çevirmemiz gerekiyor
        final reversedParents = orderedParents.reversed.toList();
        
        // ✅ MANTIK: 
        // 1. Kuyruğun sonundan başlayarak silinen yorumları kontrol et
        // 2. Eğer bir yorum silinmişse ve devamında silinmemiş yorum varsa → "silindi" olarak göster (kaldırma)
        // 3. Eğer bir yorum silinmişse ve devamında sadece silinmiş yorumlar varsa → o yorumdan sonrasını tamamen kaldır
        // 4. Eğer kuyruğun en ucundaki yorum silinmişse → direkt kaldır (zaten devamında bir şey yok)
        // 
        // Örnek 1: [Root, Parent1, "Parent2 silindi", Parent3, Parent4]
        // → [Root, Parent1, "Parent2 silindi", Parent3, Parent4] (Parent2 silindi olarak gösterilir, devamı görünür)
        // 
        // Örnek 2: [Root, Parent1, "Parent2 silindi", "Parent3 silindi", "Parent4 silindi"]
        // → [Root, Parent1] (Parent2, Parent3, Parent4 tamamen kaldırılır)
        // 
        // Örnek 3: [Root, Parent1, Parent2, "Parent3 silindi"]
        // → [Root, Parent1, Parent2] (Parent3 tamamen kaldırılır, en uç)
        final cleanedParents = <Post>[];
        
        // ✅ Kuyruğu sondan başa doğru tarayarak temizle
        // ⚠️ ÖNEMLİ: reversedParents = [Root, Parent1, Parent2, ...] (root'tan ana yoruma)
        // Index 0 = Root, Index length-1 = Ana yoruma en yakın parent
        // Sondan başa doğru tararken, "devamında" = daha büyük index (ana yoruma daha yakın)
        
        // ✅ ÖNEMLİ: Önce tüm yorumları ekle (silinmiş olsa bile)
        // Sonra kuyruğun sonundan başlayarak silinen yorumları kontrol et
        for (int i = 0; i < reversedParents.length; i++) {
          cleanedParents.add(reversedParents[i]);
        }
        
        // ✅ Şimdi kuyruğun sonundan başlayarak silinen yorumları kontrol et ve kaldır
        // Eğer son yorumlar silinmişse, onları kaldır
        // Ama ortadaki silinmiş yorumlar kalacak (devamında silinmemiş yorum var)
        while (cleanedParents.isNotEmpty && cleanedParents.last.deleted) {
          // ✅ Son yorum silinmiş, devamında (sonrasında) silinmemiş yorum var mı?
          // Eğer bu son yorum ise (cleanedParents.length == 1), direkt kaldır
          // Eğer bu son yorum değilse, bir önceki yorum silinmemiş mi kontrol et
          if (cleanedParents.length == 1) {
            // ✅ Son yorum, direkt kaldır
            cleanedParents.removeLast();
          } else {
            // ✅ Son yorum değil, bir önceki yorum silinmemiş mi?
            final previousIndex = cleanedParents.length - 2;
            if (!cleanedParents[previousIndex].deleted) {
              // ✅ Bir önceki yorum silinmemiş, bu yorumu "silindi" olarak göster (kaldırma)
              // Ama zaten ekledik, sadece kaldırmayalım
              break; // Son yorumu kaldırma, "silindi" olarak göster
            } else {
              // ✅ Bir önceki yorum da silinmiş, bu yorumu kaldır
              cleanedParents.removeLast();
            }
          }
        }
        
        // ✅ ÖNEMLİ: State manipülasyonunu önlemek için sadece gerçekten değiştiğinde güncelle
        // ✅ Root post ve parent comments'i tek bir setState'te güncelle
        if (mounted) {
          setState(() {
            // ✅ Root post'u güncelle (yeni değer varsa)
            if (newRootPost != null) {
              _rootPost = newRootPost;
            }
            // ✅ Parent comments'i güncelle (kuyruğun sonundan başlayarak silinen yorumlar kaldırıldı)
            _parentComments = cleanedParents;
          });
        }
      }
    } catch (e) {
      // Sessizce devam et (kullanıcı deneyimini bozmamak için)
      // Parent thread yüklenemezse, sadece root post ve current post gösterilir
    } finally {
      if (mounted) setState(() => _loadingParentThread = false);
    }
  }

  Future<void> _loadComments() async {
    if (_loadingComments || !_hasMoreComments) return;
    if (!mounted) return; // ✅ Mounted kontrolü
    setState(() {
      _loadingComments = true;
      _hasTriedLoadingComments = true; // ✅ İlk yükleme denemesi yapıldı
    });
    try {
      final newComments = await _postRepo.getPostComments(widget.postId, lastDoc: _lastCommentDoc);
      
      if (!mounted) return; // ✅ Async işlem sonrası mounted kontrolü
      
      if (newComments.isNotEmpty) {
        if (mounted) {
          setState(() {
            _comments.addAll(newComments);
            // ✅ docSnapshot'ı güvenli şekilde al
            final lastPost = newComments.last;
            if (lastPost.docSnapshot != null) {
              _lastCommentDoc = lastPost.docSnapshot;
            } else {
              // Eğer docSnapshot yoksa, güvenli tarafta kal
              _hasMoreComments = false;
            }
          });
        }
        // ✅ Eğer 20'den az yorum geldiyse, daha fazla yok demektir
        if (newComments.length < 20) {
          if (mounted) {
            setState(() => _hasMoreComments = false);
          }
        }
      } else {
        if (mounted) {
          setState(() => _hasMoreComments = false);
        }
      }
    } catch (e) {
      // Hata durumunda kullanıcıya bilgi ver
      if (mounted) {
        setState(() => _hasMoreComments = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yorumlar yüklenirken bir hata oluştu: ${e.toString().length > 60 ? e.toString().substring(0, 60) + "..." : e}'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Tekrar Dene',
              onPressed: () => _loadComments(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  // ✅ File picker için
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileExtension = path.extension(fileName).toLowerCase();
        
        String? mediaType;
        if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(fileExtension)) {
          mediaType = 'image';
        } else if (['.mp4', '.mov', '.avi', '.webm'].contains(fileExtension)) {
          mediaType = 'video';
        } else {
          mediaType = 'file';
        }
        
        setState(() {
          _selectedFile = file;
          _fileType = mediaType;
          _fileName = fileName;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dosya seçme hatası: ${e.toString().length > 60 ? e.toString().substring(0, 60) + "..." : e}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    if (!_canComment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sadece uzmanlar ve adminler yorum yapabilir')),
      );
      return;
    }
    
    final text = _replyCtrl.text.trim();
    if (text.isEmpty && _selectedFile == null) return;
    
    // ✅ PERFORMANCE: Kullanıcı bilgilerini cache'den al (gereksiz query önle)
    // Eğer cache'de yoksa, Firestore'dan çek (ilk yüklemede olabilir)
    String authorName = _cachedUserName ?? 'Kullanıcı';
    String authorUsername = _cachedUserUsername ?? '';
    String authorProfession = _cachedUserProfession ?? '';
    String authorRole = _currentUserRole ?? 'client';
    
    // ✅ Admin kontrolü: Eğer admin ise role'ü 'admin' olarak set et
    if (_isAdmin && authorRole != 'admin') {
      authorRole = 'admin';
    }
    
    // ✅ Eğer cache'de bilgiler yoksa, Firestore'dan çek (fallback)
    if (_cachedUserName == null || _cachedUserUsername == null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          authorName = userData['name'] ?? 'Kullanıcı';
          authorUsername = userData['username'] ?? '';
          authorProfession = userData['profession'] ?? '';
          // Cache'i güncelle
          _cachedUserName = authorName;
          _cachedUserUsername = authorUsername;
          _cachedUserProfession = authorProfession;
        }
      } catch (e) {
        // Hata durumunda cache'deki değerleri kullan
      }
    }
    
    setState(() => _isReplying = true);
    try {
      String? mediaUrl;
      String? mediaType;
      String? mediaName;
      
      // ✅ Eklenti yükleme (eğer varsa)
      if (_selectedFile != null) {
        final extension = path.extension(_selectedFile!.path).toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(_selectedFile!.path)}';
        final ref = _storage.ref().child('post_attachments/$_currentUserId/$fileName');
        await ref.putFile(_selectedFile!);
        mediaUrl = await ref.getDownloadURL();
        mediaType = _fileType;
        mediaName = _fileName;
      }
      
      // ✅ Yorum artık post olarak oluşturuluyor
      // Eğer yorum detayındaysak, root post ID'yi kullan
      final currentPost = _currentPost;
      final rootPostId = (currentPost?.isComment == true && _rootPost != null) ? _rootPost!.id : widget.postId;
      await _postRepo.addComment(
        rootPostId: rootPostId,
        parentPostId: _replyingToCommentId ?? (currentPost?.isComment == true ? widget.postId : null), // ✅ Yorum detayında ana yorum parent olur
        content: text.isEmpty ? ' ' : text, // Eğer sadece dosya varsa boşluk
        authorId: _currentUserId,
        authorName: authorName,
        authorUsername: authorUsername,
        authorRole: authorRole,
        authorProfession: authorProfession,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        mediaName: mediaName,
      );
      
      _replyCtrl.clear();
      setState(() {
        _selectedFile = null;
        _fileType = null;
        _fileName = null;
        _replyingToCommentId = null; // ✅ Yorum modunu kapat
      });
      
      // Yorumları yeniden yükle
      setState(() {
        _comments.clear();
        _lastCommentDoc = null;
        _hasMoreComments = true;
      });
      await _loadComments();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yorum eklendi')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Text('Gönderi Detayı'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _postRepo.watchPost(widget.postId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
              ),
            );
          }
          if (!snapshot.data!.exists) {
            return Center(
              child: Text(
                'Gönderi bulunamadı.',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
            );
          }
          
          final post = Post.fromFirestore(snapshot.data!);
          _currentPost = post; // Mevcut post'u sakla
          
          // ✅ ÖNEMLİ: Silinmiş yorumlar için de child'ları göstermek gerekiyor
          // Bu yüzden silinmiş kontrolünü kaldırdık, _buildPostContent içinde "silinmiş" mesajı gösterilecek
          // Ama child'lar (yanıtlar) gösterilmeye devam edecek
          // ⚠️ Sadece normal post'lar (yorum değil) için silinmiş kontrolü yapıyoruz
          if (post.deleted && !post.isComment) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 64,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bu gönderi silinmiş',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bu gönderi artık görüntülenemiyor',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // ✅ Eğer yorum ise, parent thread'i yükle (build sonrası)
          // ⚠️ Silinmiş yorumlar için de parent thread yüklenmeli (child'lara erişim için)
          // ⚠️ ÖNEMLİ: Silinmiş yorumlar için de thread yüklenmeli, böylece child'lar gösterilebilir
          if (post.isComment && _rootPost == null && !_loadingParentThread) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadCommentThread(post);
            });
          } else if (!post.isComment && !post.deleted) {
            // ✅ Normal post ise (ve silinmemişse), yorumları yükle (sadece ilk yüklemede)
            // ✅ ÖNEMLİ: Eğer yorumlar boşsa ve daha önce hiç yükleme denemesi yapılmadıysa (_hasTriedLoadingComments == false), _hasMoreComments'i true yap
            // ⚠️ ÖNEMLİ: Eğer daha önce yükleme denemesi yapıldıysa (_hasTriedLoadingComments == true) ve 0 yorum geldiyse, tekrar denememeli (sonsuz döngü önleme)
            // ⚠️ ÖNEMLİ: setState'i build sırasında çağırmamak için addPostFrameCallback kullan
            if (_comments.isEmpty && !_loadingComments && !_hasTriedLoadingComments) {
              // ✅ Sadece hiç yükleme denemesi yapılmadıysa (_hasTriedLoadingComments == false), bir kez daha deneyebiliriz
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                
                if (!_hasMoreComments) {
                  setState(() {
                    _hasMoreComments = true;
                  });
                }
                
                _loadComments();
              });
            }
          }
          
          return _buildPostContent(post, snapshot.data!.data()!);
        },
      ),
    );
  }

  Widget _buildPostContent(Post post, Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    final likedBy = List<String>.from(data['likedBy'] ?? []);
    final isLiked = likedBy.contains(_currentUserId);
    final isBookmarked = (data['savedBy'] as List<dynamic>?)?.contains(_currentUserId) ?? false;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Eğer yorum ise, önce root post ve parent thread'i göster
                // ⚠️ ÖNEMLİ: Silinmiş yorumlar için de kuyruk gösterilmeli
                if (post.isComment) ...[
                  if (_loadingParentThread)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                        ),
                      ),
                    )
                  else if (_rootPost != null || _parentComments.isNotEmpty) ...[
                    // ✅ Root post veya parent comments varsa göster (silinmiş olsa bile)
                    // ✅ Root post görünümü - daha profesyonel
                    if (_rootPost != null) ...[
                      if (_rootPost!.deleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.grey.shade800.withOpacity(0.5)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark 
                                ? Colors.grey.shade700.withOpacity(0.3)
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.remove_circle_outline,
                              size: 18,
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Bu gönderi silinmiş',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: PostCard(
                            post: _rootPost!,
                            myFollowingIds: _myFollowingIds,
                            currentUserRole: _currentUserRole,
                            hideCommentButton: true,
                          ),
                        ),
                    ],
                    // ✅ Parent yorumlar (kuyruk) - daha kompakt ve profesyonel görünüm
                    if (_parentComments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._parentComments.asMap().entries.map((entry) {
                        final index = entry.key;
                        final parentComment = entry.value;
                        final indent = (index + 1) * 16.0; // ✅ Daha kompakt: 16px indent
                        return Padding(
                          padding: EdgeInsets.only(
                            left: indent,
                            bottom: 4,
                            top: 4,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ✅ Minimal thread line (daha ince ve yumuşak)
                              Container(
                                width: 1.5,
                                margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                                decoration: BoxDecoration(
                                  color: isDark 
                                      ? Colors.deepPurple.shade800.withOpacity(0.4)
                                      : Colors.deepPurple.shade200.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                              // ✅ Yorum içeriği
                              Expanded(
                                child: parentComment.deleted
                                    ? Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.pushNamed(
                                              context,
                                              '/postDetail',
                                              arguments: {'postId': parentComment.id},
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isDark 
                                                  ? Colors.grey.shade800.withOpacity(0.5)
                                                  : Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isDark 
                                                    ? Colors.grey.shade700.withOpacity(0.3)
                                                    : Colors.grey.shade300,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.remove_circle_outline,
                                                  size: 14,
                                                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Bu yorum silinmiş',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                    : Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.pushNamed(
                                              context,
                                              '/postDetail',
                                              arguments: {'postId': parentComment.id},
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: PostCard(
                                            post: parentComment,
                                            myFollowingIds: _myFollowingIds,
                                            currentUserRole: _currentUserRole,
                                            hideCommentButton: false,
                                            disableTap: true, // ✅ Parent comment'te double tap önleme
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                    // ✅ Ana yorum (highlight edilmiş) - daha yumuşak ve profesyonel
                    Container(
                      margin: EdgeInsets.only(
                        left: (_parentComments.length + 1) * 16.0, // ✅ Parent seviyesine göre indent
                        top: 4,
                        bottom: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ Ana yorum için daha belirgin thread line
                          Container(
                            width: 2,
                            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          // ✅ Ana yorum içeriği (hafif highlight)
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark 
                                    ? Colors.deepPurple.shade900.withOpacity(0.2)
                                    : Colors.deepPurple.shade50.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.deepPurple.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: PostCard(
                                post: post,
                                myFollowingIds: _myFollowingIds,
                                currentUserRole: _currentUserRole,
                                hideCommentButton: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  // ✅ Normal post (yorum değil)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: PostCard(
                      post: post,
                      myFollowingIds: _myFollowingIds,
                      currentUserRole: _currentUserRole,
                      hideCommentButton: true, // Post detail'de yorum butonunu gizle
                    ),
                  ),
                ],
                
                // Yorum Listesi Header - Gerçek yorum sayısını göster
                Builder(
                  builder: (context) {
                    // ✅ Eğer yorum detayındaysak, bu yorumun alt yorumlarını say
                    // ✅ Eğer normal post ise, root post'un top-level yorumlarını say
                    if (post.isComment) {
                      // Yorum detayı: Bu yorumun alt yorumlarını say
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _postRepo.getCommentsForComment(widget.postId),
                        builder: (context, snapshot) {
                          int actualReplyCount = 0;
                          if (snapshot.hasData) {
                            actualReplyCount = snapshot.data!.docs
                                .where((doc) {
                                  final data = doc.data() as Map<String, dynamic>?;
                                  if (data == null) return false;
                                  // ✅ Sadece silinmemiş yorumları say
                                  final deleted = data['deleted'] as bool?;
                                  return deleted != true;
                                })
                                .length;
                          }
                          
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Yanıtlar ($actualReplyCount)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          );
                        },
                      );
                    } else {
                      // Normal post: Root post'un top-level yorumlarını say
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _postRepo.watchAllCommentsForPost(widget.postId),
                        builder: (context, snapshot) {
                          int actualReplyCount = 0;
                          if (snapshot.hasData) {
                            actualReplyCount = snapshot.data!.docs
                                .where((doc) {
                                  final data = doc.data() as Map<String, dynamic>?;
                                  if (data == null) return false;
                                  // ✅ Sadece silinmemiş yorumları say
                                  final deleted = data['deleted'] as bool?;
                                  if (deleted == true) return false;
                                  // ✅ Sadece top-level yorumları say (nested yorumlar ayrı gösteriliyor)
                                  final parentPostId = data['parentPostId'];
                                  final rootPostId = data['rootPostId'];
                                  // Top-level yorum: parentPostId null, boş veya rootPostId ile aynı
                                  if (parentPostId != null && parentPostId.toString().isNotEmpty && parentPostId != rootPostId) {
                                    return false; // Nested yorum, sayma
                                  }
                                  return true;
                                })
                                .length;
                          }
                          
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Yorumlar ($actualReplyCount)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
                
                // Yorum Input (Sadece Expert/Admin) - Her iki durumda da göster
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildReplyInput(isDark),
                ),
                
                // ✅ Reply to comment indicator
                if (_replyingToCommentId != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance.collection('posts').doc(_replyingToCommentId).get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final parentCommentAuthorUsername = snapshot.data!.data()?['authorUsername'] ?? 'kullanıcı';
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.deepPurple.shade900 : Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.reply, size: 16, color: Colors.deepPurple),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Yanıtlanıyor: @$parentCommentAuthorUsername',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple.shade700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      _replyingToCommentId = null;
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // ✅ Yorum Listesi (artık Post olarak)
                // Eğer yorum detayındaysak, sadece bu yorumun alt yorumlarını göster
                if (post.isComment) ...[
                  // Bu yorumun alt yorumları (StreamBuilder ile real-time)
                  // ⚠️ ÖNEMLİ: Silinmiş yorumlar için de child'lar gösterilmeli
                  Builder(
                    builder: (context) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _postRepo.getCommentsForComment(widget.postId),
                        builder: (context, snapshot) {
                      // ✅ ÖNEMLİ: Önce hasData kontrolü yap, sonra hata kontrolü
                      // Çünkü hata olsa bile önceki veriler olabilir ve gösterilmeli
                      if (snapshot.hasData && snapshot.data != null && snapshot.data!.docs.isNotEmpty) {
                        // ✅ Veri var, hata olsa bile göster (Index oluşana kadar geçici çözüm)
                        // Devam et, aşağıdaki kod verileri gösterecek
                      } else if (snapshot.hasError) {
                        // ⚠️ Hata var ve veri yok, hata mesajı göster
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Yorumlar yüklenirken hata oluştu',
                                  style: TextStyle(
                                    color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Index oluşturuluyor, lütfen bekleyin...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      } else if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      } else if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Henüz yanıt yok',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        );
                      }
                      
                      // ✅ Tüm yorumları map'le (silinmiş yorumları da referans olarak göster)
                      final rawDocs = snapshot.data!.docs;
                      final childComments = rawDocs
                          .map((doc) {
                            try {
                              return Post.fromFirestore(doc);
                            } catch (e) {
                              return null;
                            }
                          })
                          .whereType<Post>()
                          // ✅ Silinmiş yorumları da referans olarak göster (filtreleme yok)
                          .toList();
                      
                      if (childComments.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Henüz yanıt yok',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        );
                      }
                      
                      return Column(
                        children: childComments.map((comment) => Padding(
                          padding: EdgeInsets.only(
                            left: comment.parentPostId != null ? 32 : 0,
                            bottom: 8,
                          ),
                          child: PostCard(
                            post: comment,
                            myFollowingIds: _myFollowingIds,
                            currentUserRole: _currentUserRole,
                            hideCommentButton: false,
                          ),
                        )).toList(),
                      );
                        },
                      );
                    },
                  ),
                ] else ...[
                  // Normal post'un yorumları
                  if (_comments.isEmpty && !_loadingComments && !_hasMoreComments)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'Henüz yorum yok',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    )
                  else if (_comments.isNotEmpty)
                    ..._comments.map((comment) => Padding(
                      padding: EdgeInsets.only(
                        left: comment.parentPostId != null ? 32 : 0, // ✅ Nested yorumlar için indent
                        bottom: 8,
                      ),
                      child: PostCard(
                        post: comment,
                        myFollowingIds: _myFollowingIds,
                        currentUserRole: _currentUserRole,
                        hideCommentButton: false, // Yorumlar için yorum butonu göster
                      ),
                    )),
                  
                  if (_loadingComments)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  
                  // ✅ Load more button (sadece normal post için)
                  if (_hasMoreComments && !_loadingComments && _comments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: TextButton(
                          onPressed: _loadComments,
                          child: const Text('Daha fazla yorum yükle'),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ✅ Yorum input widget'ı (eklenti desteği ile)
  Widget _buildReplyInput(bool isDark) {
    if (!_canComment) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sadece uzmanlar ve adminler yorum yapabilir',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _replyCtrl,
                  maxLines: null,
                  minLines: 1,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Yorum yaz...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ✅ File picker butonu
              IconButton(
                icon: Icon(
                  Icons.attach_file,
                  color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                  size: 20,
                ),
                onPressed: _pickFile,
                tooltip: 'Dosya ekle',
              ),
              _isReplying
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.send,
                        color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                      ),
                      onPressed: _submitComment,
                    ),
            ],
          ),
          // ✅ Seçilen dosya gösterimi
          if (_selectedFile != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _fileType == 'image' 
                        ? Icons.image 
                        : _fileType == 'video' 
                            ? Icons.video_file 
                            : Icons.insert_drive_file,
                    size: 20,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _fileName ?? 'Dosya',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                        _fileType = null;
                        _fileName = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ✅ Yorumlar artık PostCard ile gösteriliyor - özel widget'a gerek yok

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}sa';
    if (diff.inDays < 7) return '${diff.inDays}g';
    
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}
