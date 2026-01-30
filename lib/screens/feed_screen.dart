import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

import '../repositories/firestore_post_repository.dart';
import '../repositories/firestore_block_repository.dart';
import '../repositories/firestore_subscription_repository.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import '../services/search_service.dart';
import '../services/analytics_service.dart';
import '../utils/error_handler.dart';
import 'experts_list_screen.dart';
import '../main.dart';
import '../services/theme_service.dart';

// --- ARAMA VE FİLTRE ENUMLARI (ESKİ KODDAN) ---
enum FeedFilter { discover, following }
enum SearchTarget { all, posts, people }
enum SearchPersonKind { any, expert, client }

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // --- TEMEL ---
  final _postRepo = FirestorePostRepository.instance;
  final _auth = FirebaseAuth.instance;
  final _discoverService = DiscoverService();
  final _blockRepo = FirestoreBlockRepository();
  static const Color _brandNavy = Color(0xFF0D1B3D);
  // ✅ Koyu neon yeşil renk
  static const Color _neonGreen = Color(0xFF00CC00);

  // Pagination & Akış
  final ScrollController _scrollController = ScrollController();
  List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  String? _lastPostIdForPagination; // Backend pagination için
  bool? _loadPostsDebounce; // Çoklu çağrı önleme
  Timer? _scrollDebounceTimer;

  // Filtreler
  FeedFilter _currentFilter = FeedFilter.discover;

  // Meslek Listesi (Arama için)
  static const List<String> _professionList = [
    'Psikolog', 'Klinik Psikolog', 'Nöropsikolog', 'Psikiyatr',
    'Psikolojik Danışman (PDR)', 'Sosyal Hizmet Uzmanı', 'Aile Danışmanı',
  ];

  // User Data (Cache için)
  String _userName = 'Kullanıcı';
  String? _userRole;
  String? _userPhoto;
  String? _userUsername; // Cache için
  String? _userProfession; // Cache için
  List<String> _myFollowingIds = [];
  Set<String> _blockedIds = {}; // Engellenen kullanıcı ID'leri
  bool _isAdmin = false;

  // Composer Data
  final TextEditingController _postCtrl = TextEditingController();
  bool _isPosting = false;
  File? _selectedFile;
  String? _fileType;

  @override
  void initState() {
    super.initState();
    // ✅ Analytics: Screen view tracking
    AnalyticsService.logScreenView('feed');
    // Önce kullanıcı verilerini yükle (admin kontrolü dahil)
    _loadUserData().then((_) {
      // Kullanıcı verileri yüklendikten sonra postları yükle
      if (mounted) {
        _feedLog('FEED_DEBUG', '--- Feed ilk yükleme; kopyalamak için [FEED_DEBUG] ile başlayan satırları al ---');
        _loadPosts();
        // ✅ Uygulama açılınca "Hoş geldin" mesajını göster ve kaybolsun
        _showWelcomeMessage();
      }
    });

    // ✅ OPTIMIZED: Scroll debouncing ile performans iyileştirmesi
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      if (_isLoading || !_hasMore) return;
      
      // Debounce: Scroll durduktan 300ms sonra kontrol et
      _scrollDebounceTimer?.cancel();
      _scrollDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (!_scrollController.hasClients) return;
        if (_isLoading || !_hasMore) return;
        
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        final threshold = maxScroll * 0.75; // %75'ine gelince yükle (daha erken)
        
        if (currentScroll >= threshold && maxScroll > 0) {
          _loadPosts();
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _postCtrl.dispose();
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer?.cancel();
    super.dispose();
  }

  // --- LOGIC ---

  // ✅ Uygulama açılınca "Hoş geldin" mesajını göster ve kaybolsun
  void _showWelcomeMessage() {
    if (_userName.isNotEmpty && _userName != 'Kullanıcı') {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.waving_hand, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hoş geldin, $_userName!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: _neonGreen,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          );
        }
      });
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      // Paralel olarak kullanıcı ve admin bilgilerini çek (verimlilik)
      final userFuture = FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final adminFuture = FirebaseFirestore.instance.collection('admins').doc(user.uid).get();
      final followingFuture = FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('following').get();
      final blockedFuture = FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('blocked').get();
      
      // Tüm verileri bekle
      final results = await Future.wait([userFuture, adminFuture, followingFuture, blockedFuture]);
      final userDoc = results[0] as DocumentSnapshot;
      final adminDoc = results[1] as DocumentSnapshot;
      final followingSnap = results[2] as QuerySnapshot;
      final blockedSnap = results[3] as QuerySnapshot;
      
      if (!mounted) return;
      
      // Kullanıcı bilgileri ve role (Cache için tüm bilgileri sakla)
      String? userRole;
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        _userName = data['name'] ?? 'Kullanıcı';
        userRole = data['role'] as String?;
        _userRole = userRole ?? 'client'; // ✅ Null ise 'client' olarak set et
        _userPhoto = data['photoUrl'];
        _userUsername = data['username'] as String?; // Cache
        _userProfession = data['profession'] as String?; // Cache
      } else {
        // ✅ User doc yoksa varsayılan değerler
        _userRole = 'client';
        userRole = 'client';
      }
      
      // Admin kontrolü: admins koleksiyonunda var VEYA users'da role='admin'
      final isAdminFromCollection = adminDoc.exists;
      final isAdminFromRole = userRole == 'admin';
      final isAdmin = isAdminFromCollection || isAdminFromRole;
      
      // ✅ DEBUG: Admin durumunu logla
      debugPrint('🔍 Admin Check: isAdminFromCollection=$isAdminFromCollection, isAdminFromRole=$isAdminFromRole, userRole=$userRole, final isAdmin=$isAdmin');
      
      setState(() {
        _isAdmin = isAdmin;
        // ✅ Admin ise role'ü de 'admin' olarak set et (expert yetkileri için)
        if (isAdmin) {
          _userRole = 'admin';
          debugPrint('✅ Admin detected! Setting _isAdmin=true and _userRole=admin');
        }
        // Takip listesi
        _myFollowingIds = followingSnap.docs.map((d) => d.id).toList();
        _myFollowingIds.add(user.uid);
        // Engellenen kullanıcılar
        _blockedIds = blockedSnap.docs.map((d) => d.id).toSet();
      });
    } catch (e) {
      // Hata durumunda sessizce devam et (kullanıcı deneyimini bozmamak için)
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _userRole = 'client'; // Güvenli varsayılan
        });
      }
    }
  }

  /// Console'dan kopyalayıp paylaşmak için: [FEED_DEBUG] ile başlayan tüm satırları al.
  static void _feedLog(String section, String message) {
    final ts = DateTime.now().toIso8601String();
    debugPrint('[FEED_DEBUG] $ts | $section | $message');
  }

  Future<void> _loadPosts({bool skipDiscoverCache = false}) async {
    _feedLog('LOAD_POSTS', 'called: skipDiscoverCache=$skipDiscoverCache, filter=$_currentFilter, hasMore=$_hasMore, isLoading=$_isLoading');
    if (_isLoading || !_hasMore) {
      _feedLog('LOAD_POSTS', 'early return: loading or no more');
      return;
    }
    
    // ✅ OPTIMIZED: Debounce ile çoklu çağrıları önle
    if (_loadPostsDebounce == true) {
      _feedLog('LOAD_POSTS', 'early return: debounce');
      return;
    }
    _loadPostsDebounce = true;
    
    setState(() => _isLoading = true);
    try {
      List<Post> newPosts;
      
      // Keşfet filtresi seçiliyse backend'den akıllı feed çek
      if (_currentFilter == FeedFilter.discover) {
        // İlk sayfa (lastDocId yok) her zaman cache atlansın: güncel postlar görünsün
        final isFirstPage = _lastPostIdForPagination == null;
        final skipCache = skipDiscoverCache || isFirstPage;
        _feedLog('DISCOVER', 'request: lastDocId=$_lastPostIdForPagination, skipCache=$skipCache (skipDiscoverCache=$skipDiscoverCache, isFirstPage=$isFirstPage)');
        try {
          final result = await _discoverService.getDiscoverFeed(
            limit: 20,
            lastDocId: _lastPostIdForPagination,
            skipCache: skipCache,
          );
          newPosts = result.posts;
          _feedLog('DISCOVER', 'result: count=${newPosts.length}, hasMore=${result.hasMore}');
          _feedLog('DISCOVER', 'postIds=${newPosts.map((p) => p.id).join(",")}');
          if (!result.hasMore) {
            setState(() => _hasMore = false);
          }
          // ✅ OPTIMIZED: Backend pagination için son post ID'sini sakla
          if (newPosts.isNotEmpty) {
            _lastPostIdForPagination = newPosts.last.id;
          }
        } catch (e) {
          // Backend hatası durumunda fallback olarak eski yöntemi kullan
          _feedLog('DISCOVER', 'ERROR fallback to Firestore: $e');
          newPosts = await _postRepo.getGlobalFeed(lastDoc: _lastDocument);
          _feedLog('FIRESTORE_FALLBACK', 'count=${newPosts.length}');
        }
      } else {
        _feedLog('FIRESTORE', 'getGlobalFeed');
        // Takip Ettiklerim filtresi için eski yöntem (henüz implement edilmedi)
        newPosts = await _postRepo.getGlobalFeed(lastDoc: _lastDocument);
        _feedLog('FIRESTORE', 'count=${newPosts.length}');
      }
      
      if (newPosts.isNotEmpty) {
        // ✅ Engellenen kullanıcıların postlarını filtrele
        final beforeBlock = newPosts.length;
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId != null && _blockedIds.isNotEmpty) {
          newPosts = newPosts.where((post) {
            // Post sahibi engellenmiş mi?
            if (_blockedIds.contains(post.authorId)) return false;
            // Repost yapan kullanıcı engellenmiş mi?
            if (post.repostedByUserId != null && _blockedIds.contains(post.repostedByUserId)) {
              return false;
            }
            // Bidirectional check: Post sahibi beni engellemiş mi?
            // (Bu kontrol async olduğu için şimdilik sadece client-side blocking yapıyoruz)
            return true;
          }).toList();
        }
        if (beforeBlock != newPosts.length) {
          _feedLog('BLOCK_FILTER', 'filtered $beforeBlock -> ${newPosts.length}');
        }
        
        setState(() {
          _posts.addAll(newPosts);
          // Pagination cursor'ı güncelle
          if (_currentFilter != FeedFilter.discover && newPosts.isNotEmpty) {
            _lastDocument = newPosts.last.docSnapshot;
          }
        });
        _feedLog('LOAD_POSTS', 'done: _posts.length=${_posts.length}, ids=${_posts.map((p) => p.id).join(",")}');
      } else {
        _feedLog('LOAD_POSTS', 'newPosts empty -> hasMore=false');
        setState(() => _hasMore = false);
      }
    } catch (e) {
      _feedLog('LOAD_POSTS', 'ERROR: $e');
      // Hata durumunda döngüyü durdur ama kullanıcıya bilgi ver
      setState(() {
        _hasMore = false;
        _loadPostsDebounce = null;
      });
      if (mounted) {
        // Sadece ilk hata mesajını göster, spam önle
        if (_posts.isEmpty) {
          final errorMessage = e.toString();
          final displayMessage = errorMessage.length > 80 
              ? '${errorMessage.substring(0, 80)}...' 
              : errorMessage;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gönderiler yüklenirken bir hata oluştu: $displayMessage'),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Yeniden Dene',
                onPressed: () {
                  setState(() {
                    _hasMore = true;
                    _lastDocument = null;
                  });
                  _loadPosts();
                },
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadPostsDebounce = null;
        });
      }
    }
  }

  /// [skipDiscoverCache] - true ise discover feed cache atlanır (paylaşım sonrası yeni post görünsün)
  Future<void> _refresh({bool skipDiscoverCache = false}) async {
    _feedLog('REFRESH', '>>> START skipDiscoverCache=$skipDiscoverCache');
    setState(() {
      _posts.clear();
      _lastDocument = null;
      _lastPostIdForPagination = null;
      _hasMore = true;
      _loadPostsDebounce = null;
    });
    await _loadPosts(skipDiscoverCache: skipDiscoverCache);
    _feedLog('REFRESH', '<<< END _posts.length=${_posts.length}');
  }

  void _resetToHome() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    _refresh(skipDiscoverCache: true);
  }

  // ✅ OPTIMIZED: Skeleton loading widget
  Widget _buildSkeletonLoading(bool isDark) {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 120,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 80,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 12,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity * 0.8,
                height: 12,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(4, (_) => Container(
                  width: 60,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- ARAMA MANTIĞI ---
  void _openSearch() {
    Navigator.pushNamed(context, '/search');
  }

  // --- PAYLAŞIM (COMPOSER) ---

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String ext = path.extension(file.path).toLowerCase();

        if (['.jpg', '.jpeg', '.png', '.heic'].contains(ext)) {
          final compressed = await FlutterImageCompress.compressAndGetFile(
            file.path, file.path.replaceFirst(ext, '_compressed.jpg'),
            quality: 60, minWidth: 1024,
          );
          setState(() {
            _selectedFile = compressed != null ? File(compressed.path) : file;
            _fileType = 'image';
          });
        } else {
          setState(() {
            _selectedFile = file;
            _fileType = ['.mp4', '.mov'].contains(ext) ? 'video' : 'file';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _submitPost() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty && _selectedFile == null) return;
    final user = _auth.currentUser;
    if (user == null) return;

    // 🔒 GÜVENLİK: Backend'de role kontrolü yapılacak, ama UI'da da kontrol edelim
    if (_userRole != 'expert' && _userRole != 'admin' && !_isAdmin) {
      AppErrorHandler.showInfo(
        context,
        'Sadece uzmanlar ve adminler post paylaşabilir',
      );
      return;
    }

    // ✅ ABONELİK KONTROLÜ: Expert ise aktif abonelik gerekli (Admin hariç)
    if ((_userRole == 'expert') && !_isAdmin) {
      final subscriptionRepo = FirestoreSubscriptionRepository();
      final hasActiveSubscription = await subscriptionRepo.hasActiveSubscription(user.uid);
      
      if (!hasActiveSubscription) {
        if (!mounted) return;
        AppErrorHandler.showInfo(
          context,
          'Post paylaşmak için aktif bir uzman aboneliğiniz olmalı. Lütfen abonelik planınızı yenileyin.',
        );
        return;
      }
    }

    // ✅ OPTİMİZASYON: Cache'den kullanıcı bilgilerini kullan (gereksiz query önle)
    final authorName = _userName;
    final authorUsername = _userUsername ?? '';
    final authorRole = _userRole ?? 'client';
    final authorProfession = _userProfession ?? '';

    setState(() => _isPosting = true);
    try {
      await _postRepo.sendPost(
        content: text,
        authorId: user.uid,
        authorName: authorName,
        authorUsername: authorUsername,
        authorRole: authorRole,
        authorProfession: authorProfession,
        attachment: _selectedFile,
      );
      _postCtrl.clear();
      setState(() { _selectedFile = null; _fileType = null; });
      _feedLog('POST_SENT', '>>> calling _refresh(skipDiscoverCache: true)');
      // ✅ Paylaşım sonrası discover cache atlansın, yeni post hemen görünsün
      await _refresh(skipDiscoverCache: true);
      _feedLog('POST_SENT', '<<< after refresh _posts.length=${_posts.length}');
      if (mounted) {
        AppErrorHandler.showSuccess(context, 'Post başarıyla paylaşıldı!');
      }
    } catch (e, stackTrace) {
      if (mounted) {
        AppErrorHandler.handleError(
          context,
          e,
          stackTrace: stackTrace,
          customMessage: 'Post paylaşılırken bir hata oluştu.',
          onRetry: () => _submitPost(),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  // --- WIDGETS ---

  // 1. MENÜ TUŞU (YETKİLERE GÖRE DÜZENLENMİŞ) - ✅ KOYU MOD EKLENDİ
  Widget _buildTopMainMenu() {
    // ✅ Admin kontrolü: hem _isAdmin hem de _userRole == 'admin' kontrolü
    // itemBuilder içinde her seferinde güncel değerleri kullan
    final themeService = ThemeService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopupMenuButton<String>(
      key: ValueKey('menu_${_isAdmin}_${_userRole}'), // ✅ State değiştiğinde menüyü yeniden build et
      icon: Icon(Icons.menu, color: isDark ? Colors.white : _neonGreen),
      tooltip: 'Menü',
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      onOpened: () {
        // ✅ Menü açıldığında admin kontrolünü yeniden yap
        final user = _auth.currentUser;
        if (user != null && (!_isAdmin && _userRole != 'admin')) {
          // Admin değil gibi görünüyorsa ama kontrol edelim
          FirebaseFirestore.instance.collection('admins').doc(user.uid).get().then((adminDoc) {
            if (adminDoc.exists && mounted) {
              setState(() {
                _isAdmin = true;
                _userRole = 'admin';
              });
              debugPrint('✅ Admin detected on menu open!');
            }
          });
        }
      },
      onSelected: (val) {
        // ✅ onSelected içinde de güncel değerleri kontrol et
        final currentIsAdmin = _isAdmin || _userRole == 'admin';
        
        switch (val) {
          case 'tests': Navigator.pushNamed(context, '/tests'); break;
          case 'solvedTests': Navigator.pushNamed(context, '/solvedTests'); break;
          case 'aiConsultations': Navigator.pushNamed(context, '/aiConsultations'); break;
          case 'analysis': Navigator.pushNamed(context, '/analysis'); break;
          case 'experts': Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpertsListScreen())); break;
          case 'groups': Navigator.pushNamed(context, '/groups'); break;
          case 'createTest': Navigator.pushNamed(context, '/createTest'); break;
          case 'expertTests': Navigator.pushNamed(context, '/expertTests'); break;
          case 'createPost': Navigator.pushNamed(context, '/createPost').then((_) => _refresh(skipDiscoverCache: true)); break;
          case 'darkMode': 
            themeService.toggleTheme();
            break;
          case 'settings': 
            Navigator.pushNamed(context, '/settings');
            break;
          case 'admin': 
            if (currentIsAdmin) {
              Navigator.pushNamed(context, '/admin');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Admin erişiminiz yok. Lütfen profil ekranından kontrol edin.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
            break;
        }
      },
      itemBuilder: (_) {
        // ✅ itemBuilder her açıldığında güncel değerleri kullan
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final items = <PopupMenuEntry<String>>[];
        
        // ✅ Güncel admin ve expert kontrolü - TÜM YOLLARLA KONTROL ET
        // 1. State'ten kontrol
        bool currentIsAdmin = _isAdmin || _userRole == 'admin';
        // 2. Expert kontrolü: Admin aynı zamanda expert yetkilerine sahiptir
        final currentIsExpert = _userRole == 'expert' || _userRole == 'admin' || currentIsAdmin;
        
        // ✅ DEBUG: Menü build edilirken admin durumunu logla
        debugPrint('📋 Menu Builder: _isAdmin=$_isAdmin, _userRole=$_userRole, currentIsAdmin=$currentIsAdmin, currentIsExpert=$currentIsExpert');
        
        // ✅ ÖNEMLİ: Admin ise expert yetkilerine de sahip olmalı
        if (currentIsAdmin && !currentIsExpert) {
          debugPrint('⚠️ WARNING: Admin but not Expert! This should not happen. _userRole=$_userRole');
        }
        
        // ✅ EĞER STATE'TE ADMIN YOK AMA KONTROL ETTİYSEK: OnOpened'da güncellenmiş olmalı
        // Eğer hala yoksa, belki de kullanıcı gerçekten admin değil - debug log'larına bak
        
        // ✅ ARAMA BAR (MENÜNÜN EN ÜSTÜNDE)
        items.add(
          PopupMenuItem<String>(
            enabled: false,
            child: InkWell(
              onTap: _openSearch,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? _neonGreen.withOpacity(0.1) : _neonGreen.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _neonGreen.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 18, color: isDark ? _neonGreen.withOpacity(0.7) : _neonGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ara...',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? _neonGreen.withOpacity(0.7) : _neonGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        
        items.add(const PopupMenuDivider());
        
        // ✅ HERKES İÇİN (Client, Expert, Admin)
        items.addAll([
          const PopupMenuItem(
            value: 'tests',
            child: Row(
              children: [
                Icon(Icons.quiz_outlined, size: 20, color: _neonGreen),
                SizedBox(width: 12),
                Text('Test Kataloğu/Test Çöz'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'solvedTests',
            child: Row(
              children: [
                Icon(Icons.assignment_turned_in_outlined, size: 20, color: _neonGreen),
                SizedBox(width: 12),
                Text('Çözdüğüm Testler'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'analysis',
            child: Row(
              children: [
                Icon(Icons.auto_awesome_outlined, size: 20, color: _neonGreen),
                SizedBox(width: 12),
                Text('AI Analizi\'ne Danış'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'aiConsultations',
            child: Row(
              children: [
                Icon(Icons.psychology_outlined, size: 20, color: _neonGreen),
                SizedBox(width: 12),
                Text('AI\'a Danıştıklarım'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'experts',
            child: Row(
              children: [
                Icon(Icons.people_outline, size: 20, color: _neonGreen),
                SizedBox(width: 12),
                Text('Uzmanları Keşfet'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'groups',
            child: Row(
              children: [
                Icon(Icons.group_outlined, size: 20, color: _neonGreen),
                SizedBox(width: 12),
                Text('Gruplar'),
              ],
            ),
          ),
        ]);
        
        // ✅ EXPERT/ADMIN İÇİN
        if (currentIsExpert) {
          items.addAll([
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'createTest',
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline, size: 20, color: Colors.green),
                  SizedBox(width: 12),
                  Text('Test Oluştur'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'expertTests',
              child: Row(
                children: [
                  Icon(Icons.quiz, size: 20, color: Colors.blue),
                  SizedBox(width: 12),
                  Text('Oluşturduğum Testler'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'createPost',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20, color: Colors.orange),
                  SizedBox(width: 12),
                  Text('Gönderi Paylaş (Tam Ekran)'),
                ],
              ),
            ),
          ]);
        }
        
        // ✅ AYARLAR (HERKES İÇİN)
        items.addAll([
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'darkMode',
            child: Row(
              children: [
                Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 20, color: Colors.amber),
                const SizedBox(width: 12),
                Text(isDark ? 'Açık Mod' : 'Koyu Mod'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'settings',
            child: Row(
              children: [
                Icon(Icons.settings_outlined, size: 20, color: Colors.grey),
                SizedBox(width: 12),
                Text('Ayarlar'),
              ],
            ),
          ),
        ]);
        
        // ✅ ADMIN PANELİ (SADECE ADMIN İÇİN)
        if (currentIsAdmin) {
          items.addAll([
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'admin',
              child: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Admin Paneli',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ]);
        }
        
        return items;
      },
    );
  }

  // 2. ARAMA (DIALOG AÇAR) - Compact version for AppBar
  Widget _buildSearchBarCompact() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: _openSearch,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? _neonGreen.withOpacity(0.1) : _neonGreen.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _neonGreen.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 16, color: isDark ? _neonGreen.withOpacity(0.7) : _neonGreen),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Ara...',
                style: TextStyle(fontSize: 12, color: isDark ? _neonGreen.withOpacity(0.7) : _neonGreen),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 2b. ARAMA (DIALOG AÇAR) - Full version (eski versiyon, gerekirse kullanılır)
  Widget _buildSearchBar() {
    return _buildSearchBarCompact();
  }

  // 3. FİLTRE
  Widget _buildExploreMenu() {
    final label = _currentFilter == FeedFilter.discover ? 'Keşfet' : 'Takip';
    return PopupMenuButton<FeedFilter>(
      tooltip: 'Filtre',
      onSelected: (val) {
        setState(() => _currentFilter = val);
        if (val == FeedFilter.discover) _refresh(skipDiscoverCache: true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _neonGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.white)
          ],
        ),
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(value: FeedFilter.discover, child: Text('Keşfet (Tümü)')),
        const PopupMenuItem(value: FeedFilter.following, child: Text('Takip Ettiklerim')),
      ],
    );
  }

  // 4. PAYLAŞIM KUTUSU (COMPOSER)
  Widget _buildComposerBox() {
    final bool canPost = _userRole == 'expert' || _userRole == 'admin' || _isAdmin;
    
    if (!canPost) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: containerBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seçili Dosya Önizleme
          if (_selectedFile != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? _neonGreen.withOpacity(0.15) : _neonGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? _neonGreen.withOpacity(0.4) : _neonGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(_fileType == 'image' ? Icons.image : Icons.insert_drive_file, color: _neonGreen),
                  const SizedBox(width: 8),
                  Expanded(child: Text(path.basename(_selectedFile!.path), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: isDark ? _neonGreen.withOpacity(0.8) : _neonGreen))),
                  GestureDetector(
                    onTap: () => setState(() { _selectedFile = null; _fileType = null; }),
                    child: const Icon(Icons.close, size: 18, color: Colors.red),
                  ),
                ],
              ),
            ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: isDark ? _neonGreen.withOpacity(0.2) : _neonGreen.withOpacity(0.1),
                  backgroundImage: _userPhoto != null ? NetworkImage(_userPhoto!) : null,
                  child: _userPhoto == null ? Text(_userName.isNotEmpty ? _userName[0] : '?', style: TextStyle(color: isDark ? _neonGreen.withOpacity(0.8) : _neonGreen, fontWeight: FontWeight.bold)) : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _postCtrl,
                      maxLines: null,
                      minLines: 1,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: "Neler oluyor?",
                        hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                    // Alt Butonlar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.attach_file, color: isDark ? _neonGreen.withOpacity(0.7) : _neonGreen, size: 20),
                          onPressed: _isPosting ? null : _pickFile,
                          tooltip: 'Dosya/Resim Ekle',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        _isPosting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : ElevatedButton(
                          onPressed: _submitPost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _neonGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text("Paylaş", style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : Colors.white;
    final appBarBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey.shade400 : Colors.black54;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // 1. LOGO & İSİM (MODERN) - Flexible
              Flexible(
                flex: 3,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _resetToHome,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/psych_catalog_logo.jpeg',
                        height: 28,
                        errorBuilder: (_,__,___) => Icon(Icons.psychology, color: isDark ? _neonGreen : _brandNavy, size: 20),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Psych Catalog',
                          style: TextStyle(color: const Color(0xFF0D1B3D), fontWeight: FontWeight.w900, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 2. MENÜ BUTONU (içinde arama barı var)
              _buildTopMainMenu(),
            ],
          ),
        ),
        actions: [
          // Filtre butonu (Keşfet/Takip) - Mesajın solunda
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _buildExploreMenu(),
          ),
          IconButton(
            icon: Icon(Icons.mail_outline, color: isDark ? Colors.white : _neonGreen),
            onPressed: () => Navigator.pushNamed(context, '/chatList'),
          ),
          PopupMenuButton<String>(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? _neonGreen.withOpacity(0.2) : _neonGreen.withOpacity(0.15),
                backgroundImage: _userPhoto != null && _userPhoto!.isNotEmpty 
                    ? NetworkImage(_userPhoto!) 
                    : null,
                child: _userPhoto == null || _userPhoto!.isEmpty
                    ? Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? _neonGreen.withOpacity(0.8) : _neonGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            onSelected: (val) async {
              if (val == 'profile') Navigator.pushNamed(context, '/profile');
              if (val == 'logout') await _auth.signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'profile', child: Text('Profilim ($_userName)')),
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, color: Colors.red, size: 20), SizedBox(width: 8), Text('Çıkış', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: dividerColor, height: 1)),
      ),

      body: Column(
        children: [
          // 1. PAYLAŞIM KUTUSU (Yukarı Taşındı)
          _buildComposerBox(),

          // 2. LİSTE
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refresh(skipDiscoverCache: true),
              color: _neonGreen,
              child: _posts.isEmpty && _isLoading
                  ? _buildSkeletonLoading(isDark)
                  : _posts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 64,
                                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Henüz gönderi yok',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'İlk gönderiyi sen paylaş!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          // ✅ OPTIMIZED: Cache extent ile performans iyileştirmesi
                          cacheExtent: 500, // Ekranın dışında 500px cache
                          itemCount: _posts.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _posts.length) {
                              return _hasMore
                                  ? const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(child: CircularProgressIndicator()),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.all(40),
                                      child: Center(
                                        child: Text(
                                          "Hepsi bu kadar.",
                                          style: TextStyle(
                                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    );
                            }
                            // ✅ OPTIMIZED: Key ile widget rebuild optimizasyonu
                            return PostCard(
                              key: ValueKey('post_${_posts[index].id}'),
                              post: _posts[index],
                              myFollowingIds: _myFollowingIds,
                              currentUserRole: _userRole,
                              onPostCreated: () => _refresh(skipDiscoverCache: true), // ✅ Alıntı sonrası cache atlansın
                              onPostDeleted: (postId) {
                                if (mounted) setState(() => _posts.removeWhere((p) => p.id == postId));
                              },
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}