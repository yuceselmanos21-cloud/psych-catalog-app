import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_post_repository.dart';
import '../repositories/firestore_user_repository.dart';
import '../repositories/firestore_follow_repository.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'users_list_screen.dart';

class PublicClientProfileScreen extends StatefulWidget {
  final String clientId;

  const PublicClientProfileScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<PublicClientProfileScreen> createState() => _PublicClientProfileScreenState();
}

class _PublicClientProfileScreenState extends State<PublicClientProfileScreen> {
  final _postRepo = FirestorePostRepository.instance;
  final _userRepo = FirestoreUserRepository();
  final _followRepo = FirestoreFollowRepository();

  User? get _me => FirebaseAuth.instance.currentUser;

  // ✅ PostCard için gerekli veriler
  String? _currentUserRole;
  List<String> _myFollowingIds = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    final user = _me;
    if (user == null) return;

    try {
      // ✅ Paralel olarak kullanıcı ve following bilgilerini çek
      final userFuture = FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final followingFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .get();

      final results = await Future.wait([userFuture, followingFuture]);
      final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final followingSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;

      if (!mounted) return;

      String? userRole;
      if (userDoc.exists) {
        final data = userDoc.data();
        userRole = data?['role'] as String?;
      }

      // Following listesi
      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();

      setState(() {
        _currentUserRole = userRole ?? 'client';
        _myFollowingIds = followingIds;
      });
    } catch (_) {
      // Hata durumunda varsayılan değerler
      if (mounted) {
        setState(() {
          _currentUserRole = 'client';
          _myFollowingIds = [];
        });
      }
    }
  }

  // ---------- UI/UX HELPER METODLAR ----------
  
  /// ✅ Profesyonel loading state
  Widget _buildLoadingState({String? message, bool? isDark}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 2.5,
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// ✅ Profesyonel empty state
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    bool? isDark,
  }) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColor ?? (dark ? Colors.grey.shade600 : Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: dark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// ✅ Profesyonel error state (retry butonlu)
  Widget _buildErrorState({
    required String message,
    VoidCallback? onRetry,
    bool? isDark,
  }) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: dark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Yeniden Dene'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _statItemStream(String label, Stream<int> stream, {required String userId, required bool isFollowers}) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snap) {
        final value = snap.data ?? 0;
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UsersListScreen(
                  userId: userId,
                  isFollowersList: isFollowers,
                ),
              ),
            );
          },
          child: _statItem(label, value),
        );
      },
    );
  }

  Widget _buildProfileHeader(
    Map<String, dynamic> data,
    String name,
    String username,
    String role,
    String profession,
    String photoUrl,
    String? currentUserId,
    bool canFollow,
    bool isDark,
  ) {
    final coverUrl = data['coverUrl']?.toString();
    final city = data['city']?.toString() ?? 'Belirtilmemiş';
    final isAdmin = role == 'admin';
    
    return Column(
      children: [
        // ✅ Kapak fotoğrafı (sadece fotoğraf, üstünde hiçbir şey yok)
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            image: coverUrl != null && coverUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(coverUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: coverUrl == null || coverUrl.isEmpty
              ? Center(
                  child: Icon(
                    Icons.wallpaper_rounded,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                )
              : null,
        ),
        
        // ✅ Profil bilgileri (kapak fotoğrafının altında)
        Container(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol taraf: Profil fotoğrafı ve bilgiler
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profil fotoğrafı
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      child: photoUrl.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 28),
                            )
                          : null,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Bilgiler (meslek, isim+username, şehir)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    // Meslek + Admin
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          profession.isNotEmpty ? profession : 'Danışan',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 6),
                          Text(
                            'admin',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                      const SizedBox(height: 2),
                      // İsim + Username
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (username.trim().isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '@$username',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.purple,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Şehir
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.purple.shade400),
                          const SizedBox(width: 4),
                          Text(
                            city,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.purple.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Sağ taraf: Butonlar ve istatistikler
              if (canFollow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Butonlar (yan yana)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StreamBuilder<bool>(
                          stream: _followRepo.watchIsFollowing(
                            currentUserId: currentUserId!,
                            expertId: widget.clientId,
                          ),
                          builder: (context, followSnap) {
                            final isFollowing = followSnap.data ?? false;
                            final label = isFollowing ? 'Takip Ediliyor' : 'Takip Et';
                            final icon = isFollowing ? Icons.person_remove : Icons.person_add;

                            return SizedBox(
                              width: 110,
                              child: isFollowing
                                  ? OutlinedButton.icon(
                                      onPressed: () async {
                                        try {
                                          await _followRepo.toggleFollow(
                                            currentUserId: currentUserId,
                                            expertId: widget.clientId,
                                          );
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Takip işlemi başarısız: $e'),
                                            ),
                                          );
                                        }
                                      },
                                      icon: Icon(icon, size: 16),
                                      label: Text(label, style: const TextStyle(fontSize: 11)),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: () async {
                                        try {
                                          await _followRepo.toggleFollow(
                                            currentUserId: currentUserId,
                                            expertId: widget.clientId,
                                          );
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Takip işlemi başarısız: $e'),
                                            ),
                                          );
                                        }
                                      },
                                      icon: Icon(icon, size: 16),
                                      label: Text(label, style: const TextStyle(fontSize: 11)),
                                    ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 110,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/chat',
                                arguments: {
                                  'otherUserId': widget.clientId,
                                  'otherUserName': name,
                                },
                              );
                            },
                            icon: const Icon(Icons.message, size: 16),
                            label: const Text('Mesaj', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // İstatistikler (takip etme butonunun tam hizasında altında)
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 110, // Takip Et butonunun genişliği ile aynı
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _statItemStream(
                              'Takipçi',
                              _followRepo.watchFollowersCount(widget.clientId),
                              userId: widget.clientId,
                              isFollowers: true,
                            ),
                            const SizedBox(width: 16),
                            _statItemStream(
                              'Takip',
                              _followRepo.watchFollowingCount(widget.clientId),
                              userId: widget.clientId,
                              isFollowers: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _postRepo.watchUserPostsAndReposts(widget.clientId, limit: 30),
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildErrorState(
            message: 'Paylaşımlar yüklenirken hata oluştu.',
            onRetry: () => setState(() {}),
            isDark: isDark,
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(message: 'Paylaşımlar yükleniyor...', isDark: isDark);
        }

        final allDocs = snap.data?.docs ?? const [];
        
        // ✅ OPTIMIZE: Client-side filtreleme (hızlı kontroller önce)
        final filteredDocs = allDocs.where((doc) {
          final data = doc.data();
          
          // ✅ Hızlı kontroller önce
          if (data['isComment'] == true || data['deleted'] == true) return false;
          
          // ✅ String karşılaştırmaları
          final authorId = data['authorId']?.toString() ?? '';
          final repostedByUserId = data['repostedByUserId']?.toString();
          
          // Kullanıcının orijinal postları veya repost/quote'ları
          return authorId == widget.clientId || 
                 (repostedByUserId != null && repostedByUserId == widget.clientId);
        }).toList();
        
        // ✅ OPTIMIZE: Tarihe göre sırala (en yeni önce)
        filteredDocs.sort((a, b) {
          final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });
        
        // ✅ Limit uygula (performans için)
        const int displayLimit = 30;
        final limitedDocs = filteredDocs.take(displayLimit).toList();
        
        if (limitedDocs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.forum_outlined,
            title: 'Henüz paylaşım yok',
            subtitle: 'Bu kullanıcı henüz paylaşım yapmamış',
            iconColor: Colors.deepPurple.shade300,
            isDark: isDark,
          );
        }

        // ✅ Performance: ListView.builder kullan
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: limitedDocs.length,
          itemBuilder: (context, index) {
            try {
              final post = Post.fromFirestore(limitedDocs[index]);
              return PostCard(
                post: post,
                myFollowingIds: _myFollowingIds,
                currentUserRole: _currentUserRole,
              );
            } catch (e) {
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  Widget _buildCommentsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _postRepo.watchCommentsByAuthor(widget.clientId, limit: 50),
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildErrorState(
            message: 'Yorumlar yüklenirken hata oluştu.',
            onRetry: () => setState(() {}),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(message: 'Yorumlar yükleniyor...', isDark: isDark);
        }

        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.comment_outlined,
            title: 'Henüz yorum yok',
            subtitle: 'Bu kullanıcı henüz yorum yapmamış',
            iconColor: Colors.orange.shade300,
            isDark: isDark,
          );
        }

        // ✅ Performance: ListView.builder kullan
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            try {
              final post = Post.fromFirestore(docs[index]);
              return PostCard(
                post: post,
                myFollowingIds: _myFollowingIds,
                currentUserRole: _currentUserRole,
              );
            } catch (e) {
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  Widget _buildLikedPostsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userRepo.watchUser(widget.clientId),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final hideLikes = (userSnap.data?.data()?['hideLikes'] as bool?) ?? false;

        if (hideLikes) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility_off, size: 48, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Bu kullanıcı beğenilerini gizliyor.',
                    style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _postRepo.watchLikedPostsByUser(widget.clientId, limit: 50),
          builder: (context, snap) {
            if (snap.hasError) {
              return _buildErrorState(
                message: 'Beğeniler yüklenirken hata oluştu.',
                onRetry: () => setState(() {}),
                isDark: isDark,
              );
            }

            if (snap.connectionState == ConnectionState.waiting) {
              return _buildLoadingState(message: 'Beğeniler yükleniyor...', isDark: isDark);
            }

            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return _buildEmptyState(
                icon: Icons.favorite_border,
                title: 'Henüz beğeni yok',
                subtitle: 'Bu kullanıcının beğenileri gizli veya henüz beğenisi yok',
                iconColor: Colors.pink.shade300,
                isDark: isDark,
              );
            }

            // ✅ Performance: ListView.builder kullan
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                try {
                  final post = Post.fromFirestore(docs[index]);
                  return PostCard(
                    post: post,
                    myFollowingIds: _myFollowingIds,
                    currentUserRole: _currentUserRole,
                  );
                } catch (e) {
                  return const SizedBox.shrink();
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAboutTab(String education, String? cvUrl, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Eğitim ve Sertifikalar
          if (education.isNotEmpty) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school_outlined, size: 20, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Eğitim ve Sertifikalar',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      education,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // CV
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: cvUrl != null && cvUrl.isNotEmpty
                ? InkWell(
                    onTap: () {
                      // CV'yi açmak için URL'yi kullan
                      // TODO: PDF viewer veya browser açılabilir
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.picture_as_pdf, size: 28, color: Colors.red.shade700),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CV',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'CV belgesini görüntülemek için tıklayın',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, size: 24),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.picture_as_pdf, size: 28, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CV',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'CV eklenmedi',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = _me?.uid;
    final canFollow = myId != null && myId != widget.clientId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          if (myId != null && myId == widget.clientId)
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/profile'),
              child: const Text('Profilim'),
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userRepo.watchUser(widget.clientId),
        builder: (context, snap) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Profil yüklenirken hata oluştu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snap.hasData || !snap.data!.exists) {
            return Center(
              child: Text(
                'Kullanıcı bulunamadı.',
                style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              ),
            );
          }

          final data = snap.data!.data() ?? <String, dynamic>{};

          final name = (data['name'] ?? 'Kullanıcı').toString();
          final username = (data['username'] ?? '').toString();
          final role = (data['role'] ?? 'client').toString();
          final profession = (data['profession'] ?? '').toString();
          final photoUrl = (data['photoUrl'] ?? '').toString();

          final education = (data['education'] ?? '').toString();
          final cvUrl = data['cvUrl']?.toString();

          return DefaultTabController(
            length: 4, // +1 for "Ben" tab
            child: Column(
            children: [
                _buildProfileHeader(
                  data,
                  name,
                  username,
                  role,
                  profession,
                  photoUrl,
                  myId,
                  canFollow,
                  isDark,
                ),
                
                // ✅ Tab bar (Danışanlar için sadece Bio ve Beğeniler)
                TabBar(
                  isScrollable: true,
                  tabs: [
                    const Tab(text: 'Bio', icon: Icon(Icons.person_outline)),
                    const Tab(text: 'Beğeniler', icon: Icon(Icons.favorite_outline)),
                  ],
                ),
                      Expanded(
                  child: TabBarView(
                          children: [
                      _buildAboutTab(education, cvUrl, isDark),
                      SingleChildScrollView(child: _buildLikedPostsTab()),
                          ],
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
