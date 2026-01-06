import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_follow_repository.dart';
import '../repositories/firestore_post_repository.dart';
import '../repositories/firestore_test_repository.dart';
import '../repositories/firestore_user_repository.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'users_list_screen.dart';

class ExpertPublicProfileScreen extends StatefulWidget {
  final String expertId;

  const ExpertPublicProfileScreen({
    super.key,
    required this.expertId,
  });

  @override
  State<ExpertPublicProfileScreen> createState() => _ExpertPublicProfileScreenState();
}

class _ExpertPublicProfileScreenState extends State<ExpertPublicProfileScreen> {
  // ✅ PostCard için gerekli veriler
  String? _currentUserRole;
  List<String> _myFollowingIds = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
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

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }

  // ---------- UI/UX HELPER METODLAR ----------
  
  /// ✅ Profesyonel loading state
  Widget _buildLoadingState({String? message}) {
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
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColor ?? Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
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
  }) {
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
                color: Colors.grey.shade700,
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

  String _readText(
      Map<String, dynamic> data,
      String key, {
        String fallback = 'Belirtilmemiş',
      }) {
    final v = data[key];
    if (v == null) return fallback;

    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? fallback : s;
    }

    if (v is Iterable) {
      final items = v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      if (items.isEmpty) return fallback;
      return items.join(', ');
    }

    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
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

  Widget _buildPostsTab(FirestorePostRepository postRepo) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: postRepo.watchUserPostsAndReposts(widget.expertId, limit: 30),
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildErrorState(
            message: 'Paylaşımlar yüklenirken hata oluştu.',
            onRetry: () => setState(() {}),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(message: 'Paylaşımlar yükleniyor...');
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
          return authorId == widget.expertId || 
                 (repostedByUserId != null && repostedByUserId == widget.expertId);
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

  Widget _buildCommentsTab(FirestorePostRepository postRepo) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: postRepo.watchCommentsByAuthor(widget.expertId, limit: 50),
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildErrorState(
            message: 'Yorumlar yüklenirken hata oluştu.',
            onRetry: () => setState(() {}),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(message: 'Yorumlar yükleniyor...');
        }

        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.comment_outlined,
            title: 'Henüz yorum yok',
            subtitle: 'Bu kullanıcı henüz yorum yapmamış',
            iconColor: Colors.orange.shade300,
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

  Widget _buildAboutTab(String specialties, String about, String education, String? cvUrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hakkımda
          if (about.isNotEmpty && about != 'Henüz bilgi eklenmemiş.') ...[
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
                        Icon(Icons.person_outline, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Hakkımda',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      about,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Uzmanlık Alanı
          if (specialties.isNotEmpty && specialties != 'Belirtilmemiş') ...[
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
                        Icon(Icons.work_outline, size: 20, color: Colors.purple.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Uzmanlık Alanı',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      specialties,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
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
                        const Text(
                          'Eğitim ve Sertifikalar',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      education,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
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
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.picture_as_pdf, size: 28, color: Colors.red.shade700),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CV',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'CV belgesini görüntülemek için tıklayın',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
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
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.picture_as_pdf, size: 28, color: Colors.grey.shade400),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CV',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'CV eklenmedi',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
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

  Widget _buildPublishedTestsTab(FirestoreTestRepository testRepo) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: testRepo.watchTestsByCreator(widget.expertId),
      builder: (context, testSnap) {
        if (testSnap.hasError) {
          return _buildErrorState(
            message: 'Testler yüklenirken hata oluştu.',
            onRetry: () => setState(() {}),
          );
        }

        if (testSnap.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(message: 'Testler yükleniyor...');
        }

        if (!testSnap.hasData || testSnap.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.quiz_outlined,
            title: 'Henüz test yok',
            subtitle: 'Bu kullanıcı henüz test oluşturmamış',
            iconColor: Colors.deepPurple.shade300,
          );
        }

        final testDocs = testSnap.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: testDocs.length,
          itemBuilder: (context, index) {
            final tDoc = testDocs[index];
            final tData = tDoc.data();

            final title = (tData['title'] ?? 'Adsız test').toString();
            final desc = (tData['description'] ?? '').toString();

            final testMap = {
              'id': tDoc.id,
              ...tData,
            };

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 1,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: desc.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      )
                    : null,
                trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/solveTest',
                    arguments: testMap,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSolvedTestsTab(FirestoreTestRepository testRepo) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: testRepo.watchSolvedTestsByUser(widget.expertId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(
            message: 'Çözülen testler yüklenirken hata oluştu.',
            onRetry: () => setState(() {}),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(message: 'Testler yükleniyor...');
        }

        final data = snapshot.data;
        if (data == null || data.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Henüz çözülmüş test yok',
            subtitle: 'Bu kullanıcı henüz test çözmemiş',
            iconColor: Colors.blue.shade300,
          );
        }

        // Sıralama: en yeni önce
        final docs = data.docs.toList();
        docs.sort((a, b) {
          final aTs = a.data()['createdAt'] as Timestamp?;
          final bTs = b.data()['createdAt'] as Timestamp?;
          final aTime = aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final d = doc.data();

            final title = d['testTitle']?.toString().trim();
            final safeTitle = (title == null || title.isEmpty) ? 'Test' : title;

            final ts = d['createdAt'] as Timestamp?;
            final solvedAt = ts?.toDate();

            final aiText = d['aiAnalysis']?.toString() ?? '';
            final hasAi = aiText.trim().isNotEmpty;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 1,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  safeTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (solvedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Çözüldü: ${_formatDate(solvedAt)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          hasAi ? Icons.check_circle : Icons.info_outline,
                          size: 14,
                          color: hasAi ? Colors.green.shade600 : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasAi ? 'AI yorumu mevcut' : 'AI yorumu yok',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasAi ? Colors.green.shade700 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/resultDetail',
                    arguments: {
                      'testTitle': safeTitle,
                      'answers': List<dynamic>.from(d['answers'] ?? const []),
                      'questions': List<dynamic>.from(d['questions'] ?? const []),
                      'createdAt': ts,
                      'aiAnalysis': aiText,
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLikedPostsTab(FirestorePostRepository postRepo) {
    final userRepo = FirestoreUserRepository();
    
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRepo.watchUser(widget.expertId),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(message: 'Beğeniler kontrol ediliyor...');
        }

        final hideLikes = (userSnap.data?.data()?['hideLikes'] as bool?) ?? false;

        if (hideLikes) {
          return _buildEmptyState(
            icon: Icons.favorite_border,
            title: 'Beğeniler gizli',
            subtitle: 'Bu kullanıcı beğenilerini gizlemiş',
            iconColor: Colors.pink.shade300,
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: postRepo.watchLikedPostsByUser(widget.expertId, limit: 50),
          builder: (context, snap) {
            if (snap.hasError) {
              return _buildErrorState(
                message: 'Beğeniler yüklenirken hata oluştu.',
                onRetry: () => setState(() {}),
              );
            }

            if (snap.connectionState == ConnectionState.waiting) {
              return _buildLoadingState(message: 'Beğeniler yükleniyor...');
            }

            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return _buildEmptyState(
                icon: Icons.favorite_border,
                title: 'Henüz beğeni yok',
                subtitle: 'Bu kullanıcının henüz beğenisi yok',
                iconColor: Colors.pink.shade300,
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

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(widget.expertId);

    final testRepo = FirestoreTestRepository();
    final postRepo = FirestorePostRepository.instance;
    final followRepo = FirestoreFollowRepository();

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final canFollow = currentUserId != null && currentUserId != widget.expertId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uzman Profili'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Uzman bulunamadı.'));
          }

          final data = snap.data!.data() ?? <String, dynamic>{};

          final role = (data['role'] ?? 'client').toString();
          // ✅ Admin kullanıcılar da expert yetkilerine sahip olduğu için kabul et
          final isExpert = role == 'expert' || role == 'admin';
          
          // ✅ Eğer role expert veya admin değilse, admins koleksiyonunda var mı kontrol et
          if (!isExpert) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('admins').doc(widget.expertId).get(),
              builder: (context, adminSnap) {
                if (adminSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final isAdmin = adminSnap.data?.exists ?? false;
                if (!isAdmin) {
            return const Center(child: Text('Bu kullanıcı uzman değil.'));
                }
                // ✅ Admin ise profil içeriğini göster (data'yı kullan)
                return _buildProfileContent(context, data, widget.expertId, testRepo, postRepo, followRepo, currentUserId, canFollow);
              },
            );
          }
          
          // ✅ Expert veya Admin ise devam et
          return _buildProfileContent(context, data, widget.expertId, testRepo, postRepo, followRepo, currentUserId, canFollow);
        },
      ),
    );
  }

  // ✅ Profil içeriğini ayrı method'a çıkar (kod tekrarını önlemek için)
  Widget _buildProfileContent(
    BuildContext context,
    Map<String, dynamic> data,
    String expertId,
    FirestoreTestRepository testRepo,
    FirestorePostRepository postRepo,
    FirestoreFollowRepository followRepo,
    String? currentUserId,
    bool canFollow,
  ) {
          final name = _readText(data, 'name', fallback: 'Uzman');
    final username = _readText(data, 'username', fallback: '');
          final city = _readText(data, 'city', fallback: 'Belirtilmemiş');
          final profession = _readText(data, 'profession', fallback: 'Belirtilmemiş');
          final specialties = _readText(data, 'specialties', fallback: 'Belirtilmemiş');
          final about = _readText(data, 'about', fallback: 'Henüz bilgi eklenmemiş.');
          final education = _readText(data, 'education', fallback: '');
          final photoUrl = (data['photoUrl'] ?? '').toString().trim();
    final coverUrl = (data['coverUrl'] ?? '').toString().trim();
    final cvUrl = data['cvUrl']?.toString();
    final role = (data['role'] ?? 'client').toString();
    
    // ✅ Admin kontrolü
    final isAdmin = role == 'admin';

    // ✅ Çözdüğü Testler sadece kendi profilinde görünür
    final isOwnProfile = currentUserId != null && currentUserId == expertId;
    final tabCount = isOwnProfile ? 6 : 5; // +1 for "Ben" tab

    return DefaultTabController(
      length: tabCount,
      child: Column(
        children: [
          // ✅ Kapak fotoğrafı (sadece fotoğraf, üstünde hiçbir şey yok)
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              image: coverUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(coverUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: coverUrl.isEmpty
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
            color: Colors.white,
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
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 38,
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        backgroundColor: Colors.grey.shade200,
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
                              profession,
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
                        style: const TextStyle(
                                fontSize: 16,
                          fontWeight: FontWeight.bold,
                                color: Colors.black87,
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
                              stream: followRepo.watchIsFollowing(
                                currentUserId: currentUserId!,
                                expertId: expertId,
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
                                    await followRepo.toggleFollow(
                                      currentUserId: currentUserId,
                                              expertId: widget.expertId,
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
                                    await followRepo.toggleFollow(
                                      currentUserId: currentUserId,
                                              expertId: widget.expertId,
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
                                    'otherUserId': widget.expertId,
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
                                followRepo.watchFollowersCount(expertId),
                                userId: expertId,
                                isFollowers: true,
                              ),
                              const SizedBox(width: 16),
                              _statItemStream(
                                'Takip',
                                followRepo.watchFollowingCount(expertId),
                                userId: expertId,
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
          TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'Bio', icon: Icon(Icons.person_outline)),
              const Tab(text: 'Paylaşımlar', icon: Icon(Icons.forum_outlined)),
              const Tab(text: 'Yorumlar', icon: Icon(Icons.comment_outlined)),
              const Tab(text: 'Oluşturduğum Testler', icon: Icon(Icons.quiz_outlined)),
              if (isOwnProfile)
                const Tab(text: 'Çözdüğü Testler', icon: Icon(Icons.assignment_turned_in_outlined)),
              const Tab(text: 'Beğeniler', icon: Icon(Icons.favorite_outline)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildAboutTab(specialties, about, education, cvUrl),
                SingleChildScrollView(child: _buildPostsTab(postRepo)),
                SingleChildScrollView(child: _buildCommentsTab(postRepo)),
                _buildPublishedTestsTab(testRepo),
                if (isOwnProfile) _buildSolvedTestsTab(testRepo),
                SingleChildScrollView(child: _buildLikedPostsTab(postRepo)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

