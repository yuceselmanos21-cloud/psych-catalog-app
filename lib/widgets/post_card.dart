import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../models/post_model.dart';
import '../repositories/firestore_post_repository.dart';
import '../repositories/firestore_report_repository.dart';
import 'mention_text.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final List<String> myFollowingIds;
  final String? currentUserRole; // RBAC için
  final bool hideCommentButton; // Post detail ekranında yorum butonunu gizle
  final bool disableTap; // ✅ PostCard'ın kendi onTap'ini devre dışı bırak
  final VoidCallback? onPostCreated; // ✅ Post oluşturulduktan sonra callback
  final void Function(String postId)? onPostDeleted; // ✅ Post silindikten sonra feed/liste güncellensin

  const PostCard({
    super.key,
    required this.post,
    required this.myFollowingIds,
    this.currentUserRole,
    this.hideCommentButton = false,
    this.disableTap = false, // ✅ Default olarak false
    this.onPostCreated, // ✅ Post oluşturulduktan sonra callback
    this.onPostDeleted,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  // Singleton repository
  final FirestorePostRepository _postRepo = FirestorePostRepository.instance;
  final FirestoreReportRepository _reportRepo = FirestoreReportRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // ✅ Koyu neon yeşil renk
  static const Color _neonGreen = Color(0xFF00CC00);

  bool _isReposting = false;
  bool _isBookmarking = false;
  
  // ✅ OPTIMISTIC UI: Local state for immediate feedback
  bool? _optimisticLiked;
  bool? _optimisticBookmarked;
  int? _optimisticLikeCount;

  // Tarih Formatlayıcı
  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}sa';
    if (diff.inDays < 7) return '${diff.inDays}g';
    
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  // RBAC: Expert/Admin kontrolü
  bool get _canPost => widget.currentUserRole == 'expert' || widget.currentUserRole == 'admin';
  bool get _canComment => _canPost;
  bool get _canRepost => _canPost;

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid;

    // ✅ TWITTER BENZERİ: Eğer repost ise (alıntı değilse), orijinal postu göster
    if (widget.post.isRepost && !widget.post.isQuote) {
      return RepaintBoundary(
        child: _buildRepostCard(context, currentUid),
      );
    }
    
    // ✅ TWITTER BENZERİ: Eğer alıntı ise, tam post olarak göster (menü dahil)
    if (widget.post.isQuote) {
      return RepaintBoundary(
        child: _buildQuotePostCard(context, currentUid),
      );
    }

    return RepaintBoundary(
      child: _buildNormalPostCard(context, currentUid),
    );
  }

  // Normal post kartı - ✅ KOYU MOD DESTEĞİ
  Widget _buildNormalPostCard(BuildContext context, String? currentUid) {
    final authorName = widget.post.authorName ?? 'Kullanıcı';
    final authorUsername = widget.post.authorUsername ?? '';
    final authorRole = widget.post.authorRole ?? 'client';
    final authorProfession = widget.post.authorProfession ?? '';

    final isExpert = authorRole == 'expert' || authorRole == 'admin';
    final isAdmin = authorRole == 'admin';
    // ✅ Admin etiketi ekle
    String subtitle = authorProfession.isNotEmpty ? authorProfession : (isExpert ? 'Uzman' : 'Danışan');
    if (isAdmin) {
      subtitle = subtitle.isNotEmpty ? '$subtitle · Admin' : 'Admin';
    }

    // ✅ OPTIMISTIC UI: Use optimistic state if available, otherwise use post data
    final isLiked = _optimisticLiked ?? (currentUid != null && widget.post.likedBy.contains(currentUid));
    final isBookmarked = _optimisticBookmarked ?? (currentUid != null && widget.post.savedBy.contains(currentUid));
    final likeCount = _optimisticLikeCount ?? widget.post.stats.likeCount;
    final isOwner = currentUid == widget.post.authorId;
    
    // ✅ Tema renkleri
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE);
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey.shade400 : Colors.black87;
    final greyTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade500;

    return Card(
      margin: const EdgeInsets.only(bottom: 10, left: 0, right: 0),
      elevation: 0,
      shape: Border(bottom: BorderSide(color: borderColor)),
      color: cardColor,
      child: InkWell(
        onTap: widget.disableTap ? null : () => Navigator.pushNamed(context, '/postDetail', arguments: {'postId': widget.post.id}),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // --- 1. HEADER ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Avatar (tıklanabilir - profile gider)
                  GestureDetector(
                    onTap: () {
                      final currentUid = _auth.currentUser?.uid;
                      // ✅ Kendi profiliyse kendi profil ekranına git
                      if (currentUid != null && currentUid == widget.post.authorId) {
                        Navigator.pushNamed(context, '/profile');
                      } else if (authorRole == 'expert' || authorRole == 'admin') {
                        Navigator.pushNamed(context, '/publicExpertProfile', arguments: widget.post.authorId);
                      } else {
                        Navigator.pushNamed(context, '/publicClientProfile', arguments: widget.post.authorId);
                      }
                    },
                    child: CircleAvatar(
                  radius: 20,
                  backgroundColor: isExpert 
                      ? (isDark ? _neonGreen.withOpacity(0.3) : _neonGreen.withOpacity(0.1))
                      : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                  child: Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isExpert 
                          ? (isDark ? _neonGreen.withOpacity(0.8) : _neonGreen)
                          : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                        ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // İsimler ve Rol
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // İsim + @KullanıcıAdı (tıklanabilir)
                        GestureDetector(
                          onTap: () {
                            final currentUid = _auth.currentUser?.uid;
                            // ✅ Kendi profiliyse kendi profil ekranına git
                            if (currentUid != null && currentUid == widget.post.authorId) {
                              Navigator.pushNamed(context, '/profile');
                            } else if (authorRole == 'expert' || authorRole == 'admin') {
                              Navigator.pushNamed(context, '/publicExpertProfile', arguments: widget.post.authorId);
                            } else {
                              Navigator.pushNamed(context, '/publicClientProfile', arguments: widget.post.authorId);
                            }
                          },
                          child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: authorName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                fontSize: 15,
                              ),
                            ),
                            if (authorUsername.isNotEmpty)
                              TextSpan(
                                text: '  @$authorUsername',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: _neonGreen,
                                ),
                              ),
                                // "Düzenledi" etiketi
                                if (widget.post.editedAt != null)
                                  TextSpan(
                                    text: ' · düzenledi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: greyTextColor,
                                      fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      ),
                      // ✅ Yorum ise: "@username'a yorumladı" göster (referans gösterimi)
                      // ✅ Silinmiş yorumlar için de göster (referans olarak)
                      if (widget.post.isComment && widget.post.rootPostId != null)
                        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.post.rootPostId)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final rootPostData = snapshot.data!.data()!;
                              final rootPostAuthorUsername = rootPostData['authorUsername'] ?? '';
                              final rootPostAuthorId = rootPostData['authorId'] ?? '';
                              final rootPostAuthorRole = rootPostData['authorRole'] ?? 'client';
                              if (rootPostAuthorUsername.isNotEmpty) {
                                return RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '@$rootPostAuthorUsername',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _neonGreen,
                                          fontWeight: FontWeight.w600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            final currentUid = _auth.currentUser?.uid;
                                            if (currentUid != null && currentUid == rootPostAuthorId) {
                                              Navigator.pushNamed(context, '/profile');
                                            } else if (rootPostAuthorRole == 'expert' || rootPostAuthorRole == 'admin') {
                                              Navigator.pushNamed(context, '/publicExpertProfile', arguments: rootPostAuthorId);
                                            } else {
                                              Navigator.pushNamed(context, '/publicClientProfile', arguments: rootPostAuthorId);
                                            }
                                          },
                                      ),
                                      TextSpan(
                                        text: widget.post.deleted 
                                            ? '\'a yorumladı (silindi)' 
                                            : '\'a yorumladı',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: widget.post.deleted 
                                              ? (isDark ? Colors.grey.shade500 : Colors.grey.shade400)
                                              : greyTextColor,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      // Rol / Meslek (Admin etiketi dahil)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isExpert 
                              ? _neonGreen 
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tarih ve Menü
                Row(
                  children: [
                    Text(
                        _formatDate(widget.post.createdAt),
                      style: TextStyle(fontSize: 11, color: greyTextColor),
                    ),
                    const SizedBox(width: 4),
                      // Menü
                      _buildMenuButton(context, currentUid, isOwner),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // --- 2. İÇERİK (METİN) ---
            // ✅ Silinmiş yorumlar için referans gösterimi
            if (widget.post.deleted) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
            ] else ...[
              // ✅ Normal yorumlar için içerik göster (mention desteği ile)
              if (widget.post.content.isNotEmpty)
                MentionText(
                  text: widget.post.content,
                  style: TextStyle(fontSize: 15, color: secondaryTextColor, height: 1.4),
                  onMentionTap: (userId) {
                    // Mention'a tıklandığında profili aç
                    final currentUid = _auth.currentUser?.uid;
                    if (currentUid != null && currentUid == userId) {
                      Navigator.pushNamed(context, '/profile');
                    } else {
                      // Kullanıcı rolünü kontrol et
                      FirebaseFirestore.instance.collection('users').doc(userId).get().then((doc) {
                        if (doc.exists) {
                          final role = doc.data()?['role'] as String?;
                          if (role == 'expert' || role == 'admin') {
                            Navigator.pushNamed(context, '/publicExpertProfile', arguments: userId);
                          } else {
                            Navigator.pushNamed(context, '/publicClientProfile', arguments: userId);
                          }
                        }
                      });
                    }
                  },
                ),

              // --- 3. MEDYA (RESİM/DOSYA) ---
              // ✅ Silinmiş yorumlar için medya gösterilmez
              if (widget.post.mediaUrl != null && widget.post.mediaUrl!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildMediaWidget(),
              ],
            ],

              // --- 4. ARKADAŞ YORUMU ÖNİZLEMESİ (artık Post olarak saklanıyor) ---
              if (widget.myFollowingIds.isNotEmpty)
                FutureBuilder<List<Post>>(
                  future: _postRepo.getPostPreviewComments(widget.post.id, widget.myFollowingIds),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                    final comment = snapshot.data!.first; // ✅ Artık Post
                    final authorUsername = comment.authorUsername ?? 'kullanıcı';

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // ✅ Direkt yorumun detay sayfasına git
                          Navigator.pushNamed(
                            context,
                            '/postDetail',
                            arguments: {'postId': comment.id},
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? _neonGreen.withOpacity(0.15)
                                : _neonGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark 
                                  ? _neonGreen.withOpacity(0.3)
                                  : _neonGreen.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 18,
                                color: _neonGreen.withOpacity(0.9),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                                    // ✅ Username ile göster (mention ile uyumlu)
                                    RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: '@$authorUsername ',
                                            style: TextStyle(
                                              color: _neonGreen,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = () {
                                                final currentUid = _auth.currentUser?.uid;
                                                final commentAuthorId = comment.authorId;
                                                final commentAuthorRole = comment.authorRole ?? 'client';
                                                if (currentUid != null && currentUid == commentAuthorId) {
                                                  Navigator.pushNamed(context, '/profile');
                                                } else if (commentAuthorRole == 'expert' || commentAuthorRole == 'admin') {
                                                  Navigator.pushNamed(context, '/publicExpertProfile', arguments: commentAuthorId);
                                                } else {
                                                  Navigator.pushNamed(context, '/publicClientProfile', arguments: commentAuthorId);
                                                }
                                              },
                                          ),
                                          TextSpan(
                                            text: 'yorumladı',
                                            style: TextStyle(
                                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // ✅ Yorum içeriği
                                    Text(
                                      comment.content.isNotEmpty ? comment.content : '(içerik yok)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // ✅ Ok ikonu (tıklanabilir olduğunu göster)
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

            // --- 5. AKSİYONLAR (ALT BAR) ---
              // ✅ Silinmiş yorumlar için action bar gösterilmez
              if (!widget.post.deleted) ...[
            const SizedBox(height: 12),
                _buildActionBar(context, currentUid, isLiked, isBookmarked),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Repost kartı (repost header + orijinal post) - ✅ TWITTER BENZERİ + KOYU MOD
  Widget _buildRepostCard(BuildContext context, String? currentUid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 10, left: 0, right: 0),
      elevation: 0,
      shape: Border(bottom: BorderSide(color: borderColor)),
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ TWITTER BENZERİ: Repost Header (küçük, gri, sol tarafta icon)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 4),
            child: Row(
              children: [
                Icon(Icons.repeat, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                const SizedBox(width: 4),
                // ✅ TWITTER BENZERİ: Eğer ben repost ettiysem "Yeniden gönderi yayınladın", başkası ettiyse "@username yeniden gönderdi"
                Expanded(
                  child: _buildRepostHeaderText(context, currentUid),
                ),
                // ✅ TWITTER BENZERİ: Sadece repost eden kişi için menü (geri alma)
                if (currentUid == widget.post.repostedByUserId)
                  _buildRepostMenuButton(context, currentUid),
              ],
            ),
          ),
          // ✅ TWITTER BENZERİ: Orijinal post (gömülü, hafif gri arka plan, border)
          // ✅ Repost'tan post detail'e gidilebilir
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            key: ValueKey('repost_${widget.post.repostOfPostId}'),
            stream: _postRepo.watchPost(widget.post.repostOfPostId!),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
              final originalData = snapshot.data!.data()!;
              final originalPost = Post.fromFirestore(snapshot.data!);
              // ✅ Silinmiş post kontrolü
              if (originalPost.deleted) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.grey.shade800 
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.grey.shade400 
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bu gönderi silinmiş',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.grey.shade400 
                                : Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return InkWell(
                onTap: () => Navigator.pushNamed(context, '/postDetail', arguments: {'postId': originalPost.id}),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F9F9), // Twitter benzeri hafif gri arka plan (koyu modda daha koyu)
                    border: Border.all(color: isDark ? Colors.grey.shade700 : const Color(0xFFE1E8ED), width: 1), // Twitter benzeri border
                    borderRadius: BorderRadius.circular(12), // Twitter benzeri border radius
                  ),
                  child: _buildEmbeddedPost(context, originalPost, originalData, showActionBar: true), // Repost içinde action bar göster
                ),
              );
            },
          ),
              ],
            ),
    );
  }

  // ✅ TWITTER BENZERİ: Alıntı post kartı (tam post özellikleri ile)
  Widget _buildQuotePostCard(BuildContext context, String? currentUid) {
    final authorName = widget.post.authorName ?? 'Kullanıcı';
    final authorUsername = widget.post.authorUsername ?? '';
    final authorRole = widget.post.authorRole ?? 'client';
    final authorProfession = widget.post.authorProfession ?? '';
    final isExpert = authorRole == 'expert' || authorRole == 'admin';
    final isAdmin = authorRole == 'admin';
    // ✅ Admin etiketi ekle
    String subtitle = authorProfession.isNotEmpty ? authorProfession : (isExpert ? 'Uzman' : 'Danışan');
    if (isAdmin) {
      subtitle = subtitle.isNotEmpty ? '$subtitle · Admin' : 'Admin';
    }
    final isLiked = _optimisticLiked ?? (currentUid != null && widget.post.likedBy.contains(currentUid));
    final isBookmarked = _optimisticBookmarked ?? (currentUid != null && widget.post.savedBy.contains(currentUid));
    final likeCount = _optimisticLikeCount ?? widget.post.stats.likeCount;
    final isOwner = currentUid == widget.post.authorId;
    
    // ✅ Tema renkleri
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE);
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey.shade400 : Colors.black87;
    final greyTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade500;

    return Card(
      margin: const EdgeInsets.only(bottom: 10, left: 0, right: 0),
      elevation: 0,
      shape: Border(bottom: BorderSide(color: borderColor)),
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
          // ✅ TWITTER BENZERİ: Alıntı post'un kendi header'ı (menü dahil)
          // ✅ Ana quote post'un header ve content alanına tıklayınca kendi post detail'ine gider
          InkWell(
            onTap: () => Navigator.pushNamed(context, '/postDetail', arguments: {'postId': widget.post.id}),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header (normal post gibi)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final currentUid = _auth.currentUser?.uid;
                          // ✅ Kendi profiliyse kendi profil ekranına git
                          if (currentUid != null && currentUid == widget.post.authorId) {
                            Navigator.pushNamed(context, '/profile');
                          } else if (authorRole == 'expert' || authorRole == 'admin') {
                            Navigator.pushNamed(context, '/publicExpertProfile', arguments: widget.post.authorId);
                          } else {
                            Navigator.pushNamed(context, '/publicClientProfile', arguments: widget.post.authorId);
                          }
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: isExpert 
                              ? (isDark ? _neonGreen.withOpacity(0.3) : _neonGreen.withOpacity(0.1))
                              : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                          child: Text(
                            authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isExpert 
                                  ? (isDark ? _neonGreen.withOpacity(0.8) : _neonGreen)
                                  : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                            ),
                          ),
                        ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                final currentUid = _auth.currentUser?.uid;
                                // ✅ Kendi profiliyse kendi profil ekranına git
                                if (currentUid != null && currentUid == widget.post.authorId) {
                                  Navigator.pushNamed(context, '/profile');
                                } else if (authorRole == 'expert' || authorRole == 'admin') {
                                  Navigator.pushNamed(context, '/publicExpertProfile', arguments: widget.post.authorId);
                                } else {
                                  Navigator.pushNamed(context, '/publicClientProfile', arguments: widget.post.authorId);
                                }
                              },
                              child: RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: authorName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: textColor,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (authorUsername.isNotEmpty)
                                      TextSpan(
                                        text: '  @$authorUsername',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                          color: _neonGreen,
                                        ),
                                      ),
                                    if (widget.post.editedAt != null)
                                      TextSpan(
                                        text: ' · düzenledi',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: greyTextColor,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: isExpert 
                                    ? _neonGreen 
                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _formatDate(widget.post.createdAt),
                            style: TextStyle(fontSize: 11, color: greyTextColor),
                          ),
                          const SizedBox(width: 4),
                          _buildMenuButton(context, currentUid, isOwner),
                        ],
                      ),
                    ],
                  ),
              const SizedBox(height: 10),
                  // ✅ Alıntı içeriği (ana alıntı postunun post detail'ine gider)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.post.content.isNotEmpty)
                        MentionText(
                          text: widget.post.content,
                          style: TextStyle(fontSize: 15, color: secondaryTextColor, height: 1.4),
                          onMentionTap: (userId) {
                            final currentUid = _auth.currentUser?.uid;
                            if (currentUid != null && currentUid == userId) {
                              Navigator.pushNamed(context, '/profile');
                            } else {
                              FirebaseFirestore.instance.collection('users').doc(userId).get().then((doc) {
                                if (doc.exists) {
                                  final role = doc.data()?['role'] as String?;
                                  if (role == 'expert' || role == 'admin') {
                                    Navigator.pushNamed(context, '/publicExpertProfile', arguments: userId);
                                  } else {
                                    Navigator.pushNamed(context, '/publicClientProfile', arguments: userId);
                                  }
                                }
                              });
                            }
                          },
                        ),
                      // Alıntı medyası
                      if (widget.post.mediaUrl != null && widget.post.mediaUrl!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildMediaWidget(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ✅ TWITTER BENZERİ: Alıntılanan orijinal post (gömülü, hafif gri arka plan, border)
          if (widget.post.repostOfPostId != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _postRepo.watchPost(widget.post.repostOfPostId!),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                final originalData = snapshot.data!.data()!;
                final originalPost = Post.fromFirestore(snapshot.data!);
                final isDark = Theme.of(context).brightness == Brightness.dark;
                // ✅ Silinmiş post kontrolü
                if (originalPost.deleted) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
                  );
                }

                return InkWell(
                  onTap: () => Navigator.pushNamed(context, '/postDetail', arguments: {'postId': originalPost.id}),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(left: 16, right: 16, top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F9F9), // Twitter benzeri hafif gri arka plan (koyu modda daha koyu)
                      border: Border.all(color: isDark ? Colors.grey.shade700 : const Color(0xFFE1E8ED), width: 1), // Twitter benzeri border
                      borderRadius: BorderRadius.circular(12), // Twitter benzeri border radius
                    ),
                    child: _buildEmbeddedPost(context, originalPost, originalData, showActionBar: false), // Quote içinde action bar gizle
                  ),
                );
              },
            ),
          // ✅ TWITTER BENZERİ: Alıntı post'un action bar'ı en altta (gömülü post'tan sonra)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _buildActionBar(context, currentUid, isLiked, isBookmarked),
          ),
        ],
      ),
    );
  }

  // Gömülü post (repost/quote içinde) - ✅ TWITTER BENZERİ + KOYU MOD
  // showActionBar: true = repost içinde (action bar göster), false = quote içinde (action bar gizle)
  Widget _buildEmbeddedPost(BuildContext context, Post post, Map<String, dynamic> data, {bool showActionBar = true}) {
    final currentUid = _auth.currentUser?.uid;
    final authorName = data['authorName'] ?? 'Kullanıcı';
    final authorUsername = data['authorUsername'] ?? '';
    final authorRole = data['authorRole'] ?? 'client';
    final authorId = data['authorId'] ?? '';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? post.createdAt;
    
    // ✅ Tema renkleri
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final greyTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    
    // ✅ TWITTER BENZERİ: Sadece repost içinde action bar gösterilir, quote içinde gösterilmez
    final isLiked = showActionBar ? (currentUid != null && (data['likedBy'] as List<dynamic>?)?.contains(currentUid) == true) : false;
    final isBookmarked = showActionBar ? (currentUid != null && (data['savedBy'] as List<dynamic>?)?.contains(currentUid) == true) : false;
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    final likeCount = stats['likeCount'] ?? 0;
    final replyCount = stats['replyCount'] ?? 0;
    final repostCount = stats['repostCount'] ?? 0;
    final quoteCount = stats['quoteCount'] ?? 0;
    final totalRepostQuote = repostCount + quoteCount;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ TWITTER BENZERİ: Header (küçük avatar, isim, username, tarih)
        // ✅ Profil navigasyonu korunuyor: Avatar ve isim/username'e tıklanınca profil'e gider
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                final currentUid = _auth.currentUser?.uid;
                // ✅ Kendi profiliyse kendi profil ekranına git
                if (currentUid != null && currentUid == authorId) {
                  Navigator.pushNamed(context, '/profile');
                } else if (authorRole == 'expert' || authorRole == 'admin') {
                  Navigator.pushNamed(context, '/publicExpertProfile', arguments: authorId);
                } else {
                  Navigator.pushNamed(context, '/publicClientProfile', arguments: authorId);
                }
              },
              child: CircleAvatar(
                radius: 18, // Twitter benzeri küçük avatar
                backgroundColor: (authorRole == 'expert' || authorRole == 'admin') 
                    ? (isDark ? _neonGreen.withOpacity(0.3) : _neonGreen.withOpacity(0.1))
                    : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                child: Text(
                  authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: (authorRole == 'expert' || authorRole == 'admin') 
                        ? (isDark ? _neonGreen.withOpacity(0.8) : _neonGreen)
                        : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  final currentUid = _auth.currentUser?.uid;
                  // ✅ Kendi profiliyse kendi profil ekranına git
                  if (currentUid != null && currentUid == authorId) {
                    Navigator.pushNamed(context, '/profile');
                  } else if (authorRole == 'expert' || authorRole == 'admin') {
                    Navigator.pushNamed(context, '/publicExpertProfile', arguments: authorId);
                  } else {
                    Navigator.pushNamed(context, '/publicClientProfile', arguments: authorId);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: authorName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: textColor,
                                    height: 1.2,
                                  ),
                                ),
                                if (authorUsername.isNotEmpty)
                                  TextSpan(
                                    text: ' @$authorUsername',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: _neonGreen,
                                      height: 1.2,
                                    ),
                                  ),
                                TextSpan(
                                  text: ' · ${_formatDate(createdAt)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: greyTextColor,
                                    height: 1.2,
                                  ),
                    ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // ✅ Yorum ise: "@username'a yorumladı" göster
                    if (post.isComment && post.rootPostId != null)
                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance
                            .collection('posts')
                            .doc(post.rootPostId)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final rootPostData = snapshot.data!.data()!;
                            final rootPostAuthorUsername = rootPostData['authorUsername'] ?? '';
                            final rootPostAuthorId = rootPostData['authorId'] ?? '';
                            final rootPostAuthorRole = rootPostData['authorRole'] ?? 'client';
                            if (rootPostAuthorUsername.isNotEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '@$rootPostAuthorUsername',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _neonGreen,
                                          fontWeight: FontWeight.w600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            final currentUid = FirebaseAuth.instance.currentUser?.uid;
                                            if (currentUid != null && currentUid == rootPostAuthorId) {
                                              Navigator.pushNamed(context, '/profile');
                                            } else if (rootPostAuthorRole == 'expert' || rootPostAuthorRole == 'admin') {
                                              Navigator.pushNamed(context, '/publicExpertProfile', arguments: rootPostAuthorId);
                                            } else {
                                              Navigator.pushNamed(context, '/publicClientProfile', arguments: rootPostAuthorId);
                                            }
                                          },
                                      ),
                                      TextSpan(
                                        text: '\'a yorumladı',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: greyTextColor,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ✅ TWITTER BENZERİ: Content (tıklanabilir, post detail'e gider)
        // ✅ Alıntı postunda: Tüm içerik alanına tıklanınca post detail'e gider
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.content.isNotEmpty)
              MentionText(
                text: post.content,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                  height: 1.3,
                ),
                onMentionTap: (userId) {
                  final currentUid = _auth.currentUser?.uid;
                  if (currentUid != null && currentUid == userId) {
                    Navigator.pushNamed(context, '/profile');
                  } else {
                    FirebaseFirestore.instance.collection('users').doc(userId).get().then((doc) {
                      if (doc.exists) {
                        final role = doc.data()?['role'] as String?;
                        if (role == 'expert' || role == 'admin') {
                          Navigator.pushNamed(context, '/publicExpertProfile', arguments: userId);
                        } else {
                          Navigator.pushNamed(context, '/publicClientProfile', arguments: userId);
                        }
                      }
                    });
                  }
                },
              ),
            // ✅ TWITTER BENZERİ: Media preview (küçük, rounded corners)
            if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty && post.mediaType == 'image')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8), // Twitter benzeri border radius
                    child: Image.network(
                      post.mediaUrl!,
                    height: 200, // Twitter benzeri yükseklik
                      width: double.infinity,
                      fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.error_outline, color: Colors.grey, size: 32),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
        // ✅ TWITTER BENZERİ: Sadece repost içinde action bar gösterilir, quote içinde gösterilmez
        if (showActionBar) ...[
          const SizedBox(height: 12),
          _buildEmbeddedActionBar(context, post, currentUid, isLiked, isBookmarked, 
            likeCount, replyCount, totalRepostQuote),
        ],
      ],
    );
  }

  // ✅ TWITTER BENZERİ: Gömülü post için aksiyon bar (küçük, kompakt)
  Widget _buildEmbeddedActionBar(BuildContext context, Post post, String? currentUid, 
      bool isLiked, bool isBookmarked, int likeCount, int replyCount, int totalRepostQuote) {
    return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
        // ✅ Yorum - Gerçek yorum sayısını göster (silinmemiş yorumlar)
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          key: ValueKey('comments_${post.id}'),
          stream: post.isComment 
              ? _postRepo.getCommentsForComment(post.id)
              : _postRepo.watchAllCommentsForPost(post.id),
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
                    
                    // ✅ Eğer normal post ise, sadece top-level yorumları say
                    if (!post.isComment) {
                      final parentPostId = data['parentPostId'];
                      final rootPostId = data['rootPostId'];
                      // Top-level yorum: parentPostId null, boş veya rootPostId ile aynı
                      if (parentPostId != null && parentPostId.toString().isNotEmpty && parentPostId != rootPostId) {
                        return false; // Nested yorum, sayma
                      }
                    }
                    return true;
                  })
                  .length;
            }
            
            return _embeddedActionButton(
              icon: Icons.chat_bubble_outline,
              value: actualReplyCount > 0 ? '$actualReplyCount' : '',
              color: _canComment ? _neonGreen : Colors.grey.shade300,
              onTap: () => Navigator.pushNamed(context, '/postDetail', arguments: {'postId': post.id}),
              onValueTap: actualReplyCount > 0
                  ? () => Navigator.pushNamed(context, '/postDetail', arguments: {'postId': post.id})
                  : null,
            );
          },
        ),
        // Repost (sadece Expert) - ✅ Yorumlar da repost/quote edilebilir
        if (_canRepost)
          FutureBuilder<bool>(
            future: currentUid != null 
                ? _checkIfRepostedForPost(post.id, currentUid)
                : Future.value(false),
            builder: (context, snapshot) {
              final isReposted = snapshot.data ?? false;
              return _embeddedActionButton(
                icon: Icons.repeat,
                value: totalRepostQuote > 0 ? '$totalRepostQuote' : '',
                color: isReposted ? _neonGreen : _neonGreen.withOpacity(0.7),
                onTap: () => _showRepostOptionsForPost(context, post.id, isReposted: isReposted),
                onValueTap: totalRepostQuote > 0
                    ? () => Navigator.pushNamed(context, '/repostsQuotes', arguments: post.id)
                    : null,
              );
            },
                )
              else
          _embeddedActionButton(
            icon: Icons.repeat,
            value: totalRepostQuote > 0 ? '$totalRepostQuote' : '',
            color: Colors.grey.shade300,
            onTap: null,
            onValueTap: totalRepostQuote > 0
                ? () => Navigator.pushNamed(context, '/repostsQuotes', arguments: post.id)
                : null,
          ),
        // Like
        // Mor çerçeve (pasif), kırmızı iç (aktif)
        _embeddedActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          value: likeCount > 0 ? '$likeCount' : '',
          color: isLiked ? Colors.red : _neonGreen,
                  onTap: () {
            if (currentUid != null) {
              _postRepo.toggleLike(postId: post.id, userId: currentUid);
            }
          },
          onValueTap: likeCount > 0
              ? () => _showLikedByListForPost(context, post.id)
              : null,
        ),
        // Kaydet
        _embeddedActionButton(
          icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          value: '',
          color: isBookmarked ? _neonGreen : _neonGreen.withOpacity(0.7),
          onTap: () {
            if (currentUid != null && !_isBookmarking) {
              setState(() => _isBookmarking = true);
              _postRepo.toggleBookmark(postId: post.id, userId: currentUid).then((_) {
                if (mounted) setState(() => _isBookmarking = false);
              }).catchError((_) {
                if (mounted) setState(() => _isBookmarking = false);
              });
            }
          },
        ),
      ],
    );
  }

  // ✅ TWITTER BENZERİ: Gömülü post için küçük action button
  Widget _embeddedActionButton({
    required IconData icon,
    required String value,
    required Color color,
    required VoidCallback? onTap,
    VoidCallback? onValueTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
          mainAxisSize: MainAxisSize.min,
                    children: [
            Icon(icon, size: 16, color: color), // Twitter benzeri küçük icon
            if (value.isNotEmpty) ...[
              const SizedBox(width: 3),
              GestureDetector(
                onTap: onValueTap,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13, // Twitter benzeri küçük font
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool> _checkIfRepostedForPost(String postId, String userId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('posts')
          .where('repostOfPostId', isEqualTo: postId)
          .where('repostedByUserId', isEqualTo: userId)
          .where('isQuoteRepost', isEqualTo: false)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _showRepostOptionsForPost(BuildContext context, String postId, {bool isReposted = false}) {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isReposted)
              ListTile(
                leading: const Icon(Icons.undo, color: Colors.red),
                title: const Text('Repostu geri al', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _undoRepostForPost(context, postId, currentUid);
                },
              ),
            if (isReposted) const Divider(),
            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Repost'),
              onTap: () {
                Navigator.pop(ctx);
                _doRepostForPost(context, postId, currentUid);
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_quote),
              title: const Text('Alıntıla'),
              onTap: () {
                Navigator.pop(ctx);
                _showQuoteDialogForPost(context, postId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _doRepostForPost(BuildContext context, String postId, String userId) async {
    setState(() => _isReposting = true);
    try {
      await _postRepo.repostPost(postId: postId, userId: userId);
      if (mounted) {
        // ✅ UI'ı güncelle
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repost yapıldı')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isReposting = false);
    }
  }

  void _undoRepostForPost(BuildContext context, String postId, String userId) async {
    try {
      await _postRepo.undoRepost(postId: postId, userId: userId);
      if (mounted) {
        // ✅ UI'ı güncelle
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repost geri alındı')),
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

  void _showQuoteDialogForPost(BuildContext context, String postId) {
    final quoteController = TextEditingController();
    File? _selectedFile;
    String? _fileType;
    bool _isPosting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Alıntıla'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: quoteController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Yorumunuzu ekleyin...',
                    border: OutlineInputBorder(),
                  ),
                      ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: _isPosting ? null : () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.any,
                            allowMultiple: false,
                          );
                          if (result != null && result.files.single.path != null) {
                            final file = File(result.files.single.path!);
                            final ext = result.files.single.extension?.toLowerCase() ?? '';
                            
                            String? fileType;
                            if (['jpg', 'jpeg', 'png', 'heic', 'webp'].contains(ext)) {
                              fileType = 'image';
                            } else if (['mp4', 'mov', 'avi'].contains(ext)) {
                              fileType = 'video';
                            } else {
                              fileType = 'file';
                            }
                            
                            setDialogState(() {
                              _selectedFile = file;
                              _fileType = fileType;
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Dosya seçme hatası: $e')),
                            );
                          }
                        }
                      },
                    ),
                    if (_selectedFile != null) ...[
                      Expanded(
                        child: Text(
                          path.basename(_selectedFile!.path),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _isPosting ? null : () {
                          setDialogState(() {
                            _selectedFile = null;
                            _fileType = null;
                          });
                        },
                      ),
                    ],
                  ],
                ),
            ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isPosting ? null : () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: _isPosting ? null : () async {
                final currentUid = _auth.currentUser?.uid;
                if (currentUid == null) return;
                
                final text = quoteController.text.trim();
                if (text.isEmpty && _selectedFile == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen metin veya dosya ekleyin')),
                  );
                  return;
                }

                setDialogState(() => _isPosting = true);
                try {
                  await _postRepo.createQuotePost(
                    originalPostId: postId,
                    userId: currentUid,
                    quoteContent: text,
                    attachment: _selectedFile,
                  );
                  if (mounted) {
                    Navigator.pop(ctx);
                    // ✅ UI'ı güncelle
                    setState(() {});
                    // ✅ Feed'i refresh et
                    widget.onPostCreated?.call();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alıntı paylaşıldı')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setDialogState(() => _isPosting = false);
                  }
                }
              },
              child: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Paylaş'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLikedByListForPost(BuildContext context, String postId) {
    _showLikedByList(context, postId: postId);
  }

  // Medya widget'ı
  Widget _buildMediaWidget() {
    if (widget.post.mediaType == 'image') {
      return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.network(
            widget.post.mediaUrl!,
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Container(
                height: 250,
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                height: 250,
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                child: Center(
                  child: Icon(Icons.error_outline, color: isDark ? Colors.grey.shade400 : Colors.grey, size: 48),
                ),
              );
            },
          ),
        ),
      );
    } else {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
                  padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                      Icon(
              widget.post.mediaType == 'video' ? Icons.play_circle_fill : Icons.insert_drive_file,
              size: 30,
              color: _neonGreen,
                      ),
                      const SizedBox(width: 10),
                        Expanded(
                        child: Text(
                widget.post.mediaType?.toUpperCase() ?? 'DOSYA',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Icon(Icons.open_in_new, color: isDark ? Colors.grey.shade400 : Colors.grey, size: 20),
                    ],
                  ),
      );
    }
  }

  // Menü butonu
  Widget _buildMenuButton(BuildContext context, String? currentUid, bool isOwner) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: Colors.grey.shade400, size: 20),
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            _showEditDialog(context);
            break;
          case 'delete':
            _confirmDelete(context);
            break;
          case 'report':
            _showReportDialog(context);
            break;
        }
      },
      itemBuilder: (ctx) => [
        if (isOwner) ...[
          const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
        if (!isOwner)
          const PopupMenuItem(value: 'report', child: Text('Şikayet Et')),
      ],
    );
  }

  // Repost menü butonu (sadece geri alma)
  // ✅ TWITTER BENZERİ: Repost header metni (ben mi yaptım, başkası mı?)
  Widget _buildRepostHeaderText(BuildContext context, String? currentUid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greyTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    
    // Eğer ben repost ettiysem: "Yeniden gönderi yayınladın"
    if (currentUid != null && currentUid == widget.post.repostedByUserId) {
      return Text(
        'Yeniden gönderi yayınladın',
        style: TextStyle(fontSize: 13, color: greyTextColor, height: 1.2),
      );
    }
    
    // Başkası repost ettiyse: "@username yeniden gönderdi" (tıklanabilir)
    return GestureDetector(
      onTap: () {
        // Repost eden kişinin profiline git
        if (widget.post.repostedByUserId != null) {
          final currentUid = _auth.currentUser?.uid;
          // ✅ Kendi profiliyse kendi profil ekranına git
          if (currentUid != null && currentUid == widget.post.repostedByUserId) {
            Navigator.pushNamed(context, '/profile');
          } else {
            // ✅ BACKEND VERİMLİLİK: Repost eden kişinin rolü denormalize edilmiş
            final repostedByRole = widget.post.repostedByRole ?? 'client';
            if (repostedByRole == 'expert' || repostedByRole == 'admin') {
              Navigator.pushNamed(context, '/publicExpertProfile', 
                arguments: widget.post.repostedByUserId);
            } else {
              Navigator.pushNamed(context, '/publicClientProfile', 
                arguments: widget.post.repostedByUserId);
            }
          }
        }
      },
                          child: RichText(
                            text: TextSpan(
          style: TextStyle(fontSize: 13, color: greyTextColor, height: 1.2),
                              children: [
            if (widget.post.repostedByUsername != null && widget.post.repostedByUsername!.isNotEmpty)
              TextSpan(
                text: '@${widget.post.repostedByUsername}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            else if (widget.post.repostedByName != null)
              TextSpan(
                text: widget.post.repostedByName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const TextSpan(text: ' yeniden gönderdi'),
                              ],
                            ),
      ),
    );
  }

  Widget _buildRepostMenuButton(BuildContext context, String? currentUid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, size: 16),
      onSelected: (value) {
        if (value == 'undo') {
          _undoRepost(context);
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'undo',
          child: Text('Repostu geri al'),
                        ),
                      ],
                  );
  }

  // Aksiyon bar (yorum, repost, like, kaydet)
  Widget _buildActionBar(BuildContext context, String? currentUid, bool isLiked, bool isBookmarked) {
    final totalRepostQuote = widget.post.stats.totalRepostAndQuote;
    // ✅ OPTIMISTIC UI: Use optimistic state if available, otherwise use post data
    final likeCount = _optimisticLikeCount ?? widget.post.stats.likeCount;
    
    // ✅ TWITTER BENZERİ: Repost edilmiş mi kontrol et (mavi buton için)
    bool? _isRepostedByCurrentUser;
    if (currentUid != null && _canRepost) {
      // Cache için FutureBuilder kullanmadan önce kontrol edelim
      // Ancak bu async olduğu için FutureBuilder kullanmalıyız
    }
    
    return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
        // Yorum (herkes görebilir ve tıklayabilir, ama sadece Expert/Admin yorum yazabilir)
        // ✅ Post detail ekranında gizle
        if (!widget.hideCommentButton)
          // ✅ Gerçek yorum sayısını göster (silinmemiş yorumlar)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            key: ValueKey('comments_detail_${widget.post.id}'),
            stream: widget.post.isComment 
                ? _postRepo.getCommentsForComment(widget.post.id)
                : _postRepo.watchAllCommentsForPost(widget.post.id),
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
                      
                      // ✅ Eğer normal post ise, sadece top-level yorumları say
                      if (!widget.post.isComment) {
                        final parentPostId = data['parentPostId'];
                        final rootPostId = data['rootPostId'];
                        // Top-level yorum: parentPostId null, boş veya rootPostId ile aynı
                        if (parentPostId != null && parentPostId.toString().isNotEmpty && parentPostId != rootPostId) {
                          return false; // Nested yorum, sayma
                        }
                      }
                      return true;
                    })
                    .length;
              }
              
              return _actionButton(
                icon: Icons.chat_bubble_outline,
                value: actualReplyCount > 0 ? '$actualReplyCount' : '',
                color: _canComment ? _neonGreen : Colors.grey.shade300,
                onTap: () => Navigator.pushNamed(context, '/postDetail', arguments: {'postId': widget.post.id}),
                onValueTap: actualReplyCount > 0
                    ? () => Navigator.pushNamed(context, '/postDetail', arguments: {'postId': widget.post.id})
                    : null,
              );
            },
          ),
        // Repost (sadece Expert) - ✅ Yorumlar da repost/quote edilebilir
        if (_canRepost)
          FutureBuilder<bool>(
            future: _checkIfReposted(),
            builder: (context, snapshot) {
              final isReposted = snapshot.data ?? false;
              return _actionButton(
                  icon: Icons.repeat,
                value: totalRepostQuote > 0 ? '$totalRepostQuote' : '',
                color: isReposted ? _neonGreen : _neonGreen.withOpacity(0.7),
                onTap: () => _showRepostOptions(context, isReposted: isReposted),
                onValueTap: totalRepostQuote > 0
                    ? () => Navigator.pushNamed(context, '/repostsQuotes', arguments: widget.post.id)
                    : null,
              );
            },
          )
        else
                _actionButton(
                  icon: Icons.repeat,
            value: totalRepostQuote > 0 ? '$totalRepostQuote' : '',
            color: Colors.grey.shade300,
            onTap: null, // Disabled
            onValueTap: totalRepostQuote > 0
                ? () => Navigator.pushNamed(context, '/repostsQuotes', arguments: widget.post.id)
                : null,
          ),
        // Like (herkes) - ✅ OPTIMISTIC UI
        // ✅ TWITTER BENZERİ: Like sayısına tıklayınca beğenenler listesi
        // Mor çerçeve (pasif), kırmızı iç (aktif)
                _actionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
          value: likeCount > 0 ? '$likeCount' : '',
                  color: isLiked ? Colors.red : _neonGreen,
                  onTap: () {
            if (currentUid != null) {
              // ✅ OPTIMISTIC UPDATE: Immediately update UI
              final wasLiked = isLiked;
              final currentLikeCount = _optimisticLikeCount ?? widget.post.stats.likeCount;
              final newLikeCount = wasLiked ? (currentLikeCount - 1) : (currentLikeCount + 1);
              
              setState(() {
                _optimisticLiked = !wasLiked;
                _optimisticLikeCount = newLikeCount.clamp(0, double.infinity).toInt();
              });
              
              // Backend'e gönder
              _postRepo.toggleLike(postId: widget.post.id, userId: currentUid).catchError((e) {
                // Hata durumunda geri al
                if (mounted) {
                  setState(() {
                    _optimisticLiked = wasLiked;
                    _optimisticLikeCount = currentLikeCount;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hata: $e')),
                  );
                }
              });
            }
          },
          onLongPress: likeCount > 0
              ? () => _showLikedByList(context)
              : null,
          // ✅ TWITTER BENZERİ: Like sayısına tıklayınca beğenenler listesi
          onValueTap: likeCount > 0
              ? () => _showLikedByList(context)
              : null,
        ),
        // Kaydet (herkes) - ✅ OPTIMISTIC UI
                _actionButton(
          icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  value: '',
          color: isBookmarked ? _neonGreen : _neonGreen.withOpacity(0.7),
          onTap: () {
            if (currentUid != null && !_isBookmarking) {
              // ✅ OPTIMISTIC UPDATE: Immediately update UI
              final wasBookmarked = isBookmarked;
              
              setState(() {
                _isBookmarking = true;
                _optimisticBookmarked = !wasBookmarked;
              });
              
              // Backend'e gönder
              _postRepo.toggleBookmark(postId: widget.post.id, userId: currentUid).then((_) {
                if (mounted) setState(() => _isBookmarking = false);
              }).catchError((e) {
                // Hata durumunda geri al
                if (mounted) {
                  setState(() {
                    _isBookmarking = false;
                    _optimisticBookmarked = wasBookmarked;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hata: $e')),
                  );
                }
              });
            }
          },
      ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String value,
    required Color color,
    required VoidCallback? onTap,
    VoidCallback? onLongPress,
    VoidCallback? onValueTap, // ✅ TWITTER BENZERİ: Sayıya tıklayınca (like sayısı için)
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            if (value.isNotEmpty) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onValueTap,
                child: Text(value, style: TextStyle(fontSize: 12, color: color)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Repost seçenekleri dialogu - ✅ TWITTER BENZERİ: Repost edildiğinde "Geri al" seçeneği
  void _showRepostOptions(BuildContext context, {bool isReposted = false}) {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ TWITTER BENZERİ: Eğer zaten repost edilmişse önce "Geri al" seçeneği
            if (isReposted)
              ListTile(
                leading: const Icon(Icons.undo, color: Colors.red),
                title: const Text('Repostu geri al', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _undoRepost(context);
                },
              ),
            if (isReposted) const Divider(),
            // Repost ve Alıntı seçenekleri
            if (!isReposted) ...[
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('Repost'),
                onTap: () {
                  Navigator.pop(ctx);
                  _doRepost(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.format_quote),
                title: const Text('Alıntıla'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showQuoteDialog(context);
                },
              ),
            ] else ...[
              // Repost edildiğinde de repost ve alıntı seçenekleri göster (yeni repost yapabilir)
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('Repost'),
                onTap: () {
                  Navigator.pop(ctx);
                  _doRepost(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.format_quote),
                title: const Text('Alıntıla'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showQuoteDialog(context);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool> _checkIfReposted() async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return false;
    
    try {
      final query = await FirebaseFirestore.instance
          .collection('posts')
          .where('repostOfPostId', isEqualTo: widget.post.id)
          .where('repostedByUserId', isEqualTo: currentUid)
          .where('isQuoteRepost', isEqualTo: false)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _doRepost(BuildContext context) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    setState(() => _isReposting = true);
    try {
      await _postRepo.repostPost(postId: widget.post.id, userId: currentUid);
      if (mounted) {
        // ✅ UI'ı güncelle - repost butonu mavi olmalı
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repost yapıldı')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isReposting = false);
    }
  }

  void _undoRepost(BuildContext context) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    try {
      await _postRepo.undoRepost(postId: widget.post.id, userId: currentUid);
      if (mounted) {
        // ✅ UI'ı güncelle - repost butonu gri olmalı
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repost geri alındı')),
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

  void _showQuoteDialog(BuildContext context) {
    final quoteController = TextEditingController();
    File? _selectedFile;
    String? _fileType;
    bool _isPosting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Alıntıla'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: quoteController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Yorumunuzu ekleyin...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Dosya seçimi
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: _isPosting ? null : () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.any,
                            allowMultiple: false,
                          );
                          if (result != null && result.files.single.path != null) {
                            final file = File(result.files.single.path!);
                            final ext = result.files.single.extension?.toLowerCase() ?? '';
                            
                            String? fileType;
                            if (['jpg', 'jpeg', 'png', 'heic', 'webp'].contains(ext)) {
                              fileType = 'image';
                            } else if (['mp4', 'mov', 'avi'].contains(ext)) {
                              fileType = 'video';
                            } else {
                              fileType = 'file';
                            }
                            
                            setDialogState(() {
                              _selectedFile = file;
                              _fileType = fileType;
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Dosya seçme hatası: $e')),
                            );
                          }
                        }
                      },
                    ),
                    if (_selectedFile != null) ...[
                      Expanded(
                        child: Text(
                          path.basename(_selectedFile!.path),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _isPosting ? null : () {
                          setDialogState(() {
                            _selectedFile = null;
                            _fileType = null;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isPosting ? null : () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: _isPosting ? null : () async {
                final currentUid = _auth.currentUser?.uid;
                if (currentUid == null) return;
                
                final text = quoteController.text.trim();
                if (text.isEmpty && _selectedFile == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen metin veya dosya ekleyin')),
                  );
                  return;
                }

                setDialogState(() => _isPosting = true);
                try {
                  await _postRepo.createQuotePost(
                    originalPostId: widget.post.id,
                    userId: currentUid,
                    quoteContent: text,
                    attachment: _selectedFile,
                  );
                  if (mounted) {
                    Navigator.pop(ctx);
                    // ✅ UI'ı güncelle
                    setState(() {});
                    // ✅ Feed'i refresh et
                    widget.onPostCreated?.call();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alıntı paylaşıldı')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setDialogState(() => _isPosting = false);
                  }
                }
              },
              child: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Paylaş'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final editController = TextEditingController(text: widget.post.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gönderiyi Düzenle'),
        content: TextField(
          controller: editController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Gönderi içeriği...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (editController.text.trim().isEmpty) return;
              try {
                await _postRepo.updatePost(
                  postId: widget.post.id,
                  content: editController.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gönderi güncellendi')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hata: $e')),
                  );
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gönderiyi Sil'),
        content: const Text('Bu gönderiyi silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // ✅ Silmeden önce post'un bilgilerini sakla
                final postId = widget.post.id;
                final isComment = widget.post.isComment;
                final isRepost = widget.post.isRepost;
                final isQuote = widget.post.isQuote;
                
                await _postRepo.deletePost(postId);
                
                if (mounted) {
                  Navigator.pop(ctx);
                  // ✅ Feed/liste UI güncellemesi: ana post silindiyse callback ile listeden kaldır
                  if (!isComment) {
                    widget.onPostDeleted?.call(postId);
                  }
                  // ✅ Eğer yorum ise, post detail ekranından geri git
                  if (isComment) {
                    Navigator.pop(context);
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isComment ? 'Yorum silindi' : (isRepost || isQuote) ? 'Yeniden gönderi silindi' : 'Gönderi silindi'),
                    ),
                  );
                }
              } catch (e, stackTrace) {
                print('⚠️ Post silme hatası: $e');
                print('⚠️ Stack trace: $stackTrace');
                if (mounted) {
                  // ✅ Daha detaylı hata mesajı
                  String errorMessage = 'Gönderi silinirken bir hata oluştu';
                  if (e.toString().contains('Post bulunamadı')) {
                    errorMessage = 'Gönderi bulunamadı';
                  } else if (e.toString().contains('Post verisi bulunamadı')) {
                    errorMessage = 'Gönderi verisi bulunamadı';
                  } else if (e.toString().contains('transaction')) {
                    errorMessage = 'Veritabanı işlemi başarısız oldu. Lütfen tekrar deneyin.';
                  } else if (e.toString().isNotEmpty) {
                    errorMessage = 'Hata: ${e.toString().length > 80 ? e.toString().substring(0, 80) + "..." : e}';
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      duration: const Duration(seconds: 4),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şikayet Et'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Şikayet gerekçenizi yazın:'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Gerekçe...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              try {
                await _reportRepo.createReport(
                  targetType: 'POST',
                  targetId: widget.post.id,
                  reason: reasonController.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Şikayet gönderildi')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hata: $e')),
                  );
                }
              }
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  // ✅ BACKEND VERİMLİLİK: Beğenenler listesi (batch user fetch)
  void _showLikedByList(BuildContext context, {String? postId}) {
    final targetPostId = postId ?? widget.post.id;
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<List<String>>(
        future: _postRepo.getLikedByUsers(targetPostId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AlertDialog(
              content: Center(child: CircularProgressIndicator()),
            );
          }

          final userIds = snapshot.data!;
          if (userIds.isEmpty) {
            return AlertDialog(
              title: const Text('Beğenenler'),
              content: const Text('Henüz beğenen yok'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Kapat'),
                ),
              ],
            );
          }

          // ✅ BACKEND VERİMLİLİK: Batch user fetch (max 10 at a time for Firestore)
          return FutureBuilder<List<DocumentSnapshot>>(
            future: _fetchUsersBatch(userIds.take(50).toList()),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return const AlertDialog(
                  content: Center(child: CircularProgressIndicator()),
                );
              }

              final userDocs = userSnapshot.data!;
              return AlertDialog(
                title: const Text('Beğenenler'),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: userDocs.length,
                    itemBuilder: (context, index) {
                      final userDoc = userDocs[index];
                      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
                      final userName = userData['name'] ?? 'Kullanıcı';
                      final userUsername = userData['username'] ?? '';
                      final userRole = userData['role'] ?? 'client';
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (userRole == 'expert' || userRole == 'admin')
                              ? _neonGreen.withOpacity(0.1)
                              : Colors.grey.shade200,
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: (userRole == 'expert' || userRole == 'admin')
                                  ? _neonGreen
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        title: Text(userName),
                        subtitle: userUsername.isNotEmpty ? Text('@$userUsername') : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          final currentUid = _auth.currentUser?.uid;
                          // ✅ Kendi profiliyse kendi profil ekranına git
                          if (currentUid != null && currentUid == userDoc.id) {
                            Navigator.pushNamed(context, '/profile');
                          } else if (userRole == 'expert' || userRole == 'admin') {
                            Navigator.pushNamed(context, '/publicExpertProfile', arguments: userDoc.id);
                          } else {
                            Navigator.pushNamed(context, '/publicClientProfile', arguments: userDoc.id);
                          }
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Kapat'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ✅ BACKEND VERİMLİLİK: Batch user fetch (Firestore limit: 10 per batch)
  Future<List<DocumentSnapshot>> _fetchUsersBatch(List<String> userIds) async {
    final batches = <List<String>>[];
    for (var i = 0; i < userIds.length; i += 10) {
      batches.add(userIds.sublist(i, (i + 10).clamp(0, userIds.length)));
    }

    final allDocs = <DocumentSnapshot>[];
    for (final batch in batches) {
      final futures = batch.map((uid) => 
        FirebaseFirestore.instance.collection('users').doc(uid).get()
      );
      final results = await Future.wait(futures);
      allDocs.addAll(results);
    }
    return allDocs;
  }
}
