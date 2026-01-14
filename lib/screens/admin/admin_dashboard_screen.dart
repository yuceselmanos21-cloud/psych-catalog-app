import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../repositories/firestore_admin_repository.dart';
import '../post_detail_screen.dart';
import '../expert_public_profile_screen.dart';
import '../public_client_profile_screen.dart';
import '../expert_test_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // -----------------------------
  // COLLECTION NAMES (adjust here)
  // -----------------------------
  static const String kUsersCol = 'users';
  static const String kAdminsCol = 'admins';
  static const String kPostsCol = 'posts';
  // ✅ Yorumlar artık posts koleksiyonunda (isComment: true), replies koleksiyonu kullanılmıyor
  // static const String kRepliesCol = 'replies'; // DEPRECATED
  static const String kTestsCol = 'tests';

  // New tabs
  static const String kExpertApplicationsCol = 'expert_applications'; // pending/approved/rejected
  static const String kReportsCol = 'reports'; // open/closed

  // user docs fields
  static const String kUserRoleField = 'role'; // client/expert/admin
  static const String kUserBannedField = 'banned'; // bool

  // expert_applications fields
  static const String kAppStatusField = 'status'; // pending/approved/rejected
  static const String kAppApplicantUidField = 'uid'; // applicant user uid
  static const String kAppCreatedAtField = 'createdAt';
  static const String kAppReviewedAtField = 'reviewedAt';
  static const String kAppReviewedByField = 'reviewedBy';
  static const String kAppRejectReasonField = 'rejectReason';

  // reports fields
  static const String kReportStatusField = 'status'; // open/closed
  static const String kReportCreatedAtField = 'createdAt';
  static const String kReportClosedAtField = 'closedAt';
  static const String kReportClosedByField = 'closedBy';
  static const String kReportTargetTypeField = 'targetType'; // post/reply/...
  static const String kReportTargetIdField = 'targetId';
  static const String kReportReasonField = 'reason';
  static const String kReportTargetOwnerIdField = 'targetOwnerId';
  static const String kReportCreatedByField = 'createdBy';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreAdminRepository _adminRepo = FirestoreAdminRepository.instance;

  bool _checking = true;
  bool _isAdmin = false;
  bool _isLoading = false; // İşlemler için loading state
  String? _myUid;

  // Admin ekleme: username
  final TextEditingController _addAdminUsernameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  @override
  void dispose() {
    _addAdminUsernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    _myUid = user.uid;

    try {
      // ✅ PERFORMANCE: Paralel olarak kullanıcı ve admin bilgilerini çek
      final userFuture = _db.collection('users').doc(user.uid).get();
      final adminFuture = _db.collection(kAdminsCol).doc(user.uid).get();
      
      final results = await Future.wait([userFuture, adminFuture]);
      final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final adminDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      
      if (!mounted) return;
      
      final userRole = userDoc.data()?['role'] as String?;
      final isAdminFromCollection = adminDoc.exists;
      final isAdminFromRole = userRole == 'admin';
      final isAdmin = isAdminFromCollection || isAdminFromRole;
      
      setState(() {
        _isAdmin = isAdmin;
        _checking = false;
      });
      
      if (!isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin erişiminiz yok.'),
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _checking = false;
      });
      if (mounted) {
        final errorMessage = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin kontrolü yapılamadı: ${errorMessage.length > 60 ? errorMessage.substring(0, 60) + "..." : errorMessage}'),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: Duration(seconds: isError ? 4 : 2),
        backgroundColor: isError ? Colors.red.shade700 : null,
        action: isError
            ? SnackBarAction(
                label: 'Tamam',
                textColor: Colors.white,
                onPressed: () {},
              )
            : null,
      ),
    );
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static String _ts(Timestamp? t) {
    if (t == null) return '';
    final d = t.toDate();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // -------------------- USERS --------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchUsers() {
    // repo mevcutsa kullan, değilse doğrudan fallback
    try {
      return _adminRepo.watchLatestUsers(limit: 50);
    } catch (_) {
      return _db.collection(kUsersCol).orderBy('createdAt', descending: true).limit(50).snapshots();
    }
  }

  Future<void> _setUserRole({required String uid, required String newRole}) async {
    try {
      await _adminRepo.setRole(
        targetUid: uid,
        role: newRole,
        adminUid: _myUid ?? '',
      );
      _snack('Rol güncellendi.');
    } catch (e) {
      // fallback direct update
      try {
        await _db.collection(kUsersCol).doc(uid).set(
          {
            kUserRoleField: newRole,
            'roleUpdatedAt': FieldValue.serverTimestamp(),
            'roleUpdatedBy': _myUid ?? '',
          },
          SetOptions(merge: true),
        );
        _snack('Rol güncellendi.');
      } catch (e2) {
        final errorMessage = e2.toString();
        _snack('Rol güncellenemedi: ${errorMessage.length > 60 ? errorMessage.substring(0, 60) + "..." : errorMessage}', isError: true);
      }
    }
  }

  Future<void> _setUserBanned({required String uid, required bool banned}) async {
    try {
      await _adminRepo.setBanned(
        targetUid: uid,
        banned: banned,
        adminUid: _myUid ?? '',
      );
      _snack(banned ? 'Kullanıcı banlandı.' : 'Ban kaldırıldı.');
    } catch (e) {
      // fallback direct update
      try {
        await _db.collection(kUsersCol).doc(uid).set(
          {
            kUserBannedField: banned,
            'banUpdatedAt': FieldValue.serverTimestamp(),
            'banUpdatedBy': _myUid ?? '',
          },
          SetOptions(merge: true),
        );
        _snack(banned ? 'Kullanıcı banlandı.' : 'Ban kaldırıldı.');
      } catch (e2) {
        _snack('İşlem başarısız: $e2');
      }
    }
  }

  // -------------------- POSTS --------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchPosts() {
    // ✅ PERFORMANCE: Silinmiş postları da göster (admin için)
    return _db.collection(kPostsCol)
        .where('isComment', isEqualTo: false) // Sadece postlar (yorumlar değil)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> _deletePost(String postId) async {
    try {
      setState(() => _isLoading = true);
      await _adminRepo.deletePostAsAdmin(postId);
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Post başarıyla silindi.');
      }
    } catch (e) {
      // fallback: direct delete (NOTE: attachment/repost accounting repo'daki kadar kapsamlı olmayabilir)
      try {
        await _db.collection(kPostsCol).doc(postId).delete();
        if (mounted) {
          setState(() => _isLoading = false);
          _snack('Post silindi (fallback).');
        }
      } catch (e2) {
        if (mounted) {
          setState(() => _isLoading = false);
          final errorMessage = e2.toString();
          _snack('Post silinemedi: ${errorMessage.length > 60 ? errorMessage.substring(0, 60) + "..." : errorMessage}', isError: true);
        }
      }
    }
  }

  // -------------------- REPLIES --------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchReplies() {
    // ✅ PERFORMANCE: Yorumlar artık posts koleksiyonunda (isComment: true)
    return _db.collection(kPostsCol)
        .where('isComment', isEqualTo: true) // Sadece yorumlar
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> _softDeleteReply(String replyId) async {
    try {
      setState(() => _isLoading = true);
      await _adminRepo.softDeleteReplyAsAdmin(replyId);
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Yorum başarıyla gizlendi.');
      }
    } catch (e) {
      // ✅ Fallback: posts koleksiyonundan soft delete
      try {
        await _db.collection(kPostsCol).doc(replyId).update({
          'deleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': _myUid ?? '',
          'content': FieldValue.delete(),
          'mediaUrl': FieldValue.delete(),
          'mediaType': FieldValue.delete(),
          'mediaName': FieldValue.delete(),
        });
        if (mounted) {
          setState(() => _isLoading = false);
          _snack('Yorum gizlendi (fallback).');
        }
      } catch (e2) {
        if (mounted) {
          setState(() => _isLoading = false);
          final errorMessage = e2.toString();
          _snack('Yorum güncellenemedi: ${errorMessage.length > 60 ? errorMessage.substring(0, 60) + "..." : errorMessage}', isError: true);
        }
      }
    }
  }

  // -------------------- TESTS --------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchTests() {
    return _db.collection(kTestsCol).orderBy('createdAt', descending: true).limit(50).snapshots();
  }

  Future<void> _deleteTest(String testId) async {
    try {
      setState(() => _isLoading = true);
      await _adminRepo.deleteTestAsAdmin(testId);
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Test başarıyla silindi.');
      }
    } catch (e) {
      // fallback
      try {
        await _db.collection(kTestsCol).doc(testId).delete();
        if (mounted) {
          setState(() => _isLoading = false);
          _snack('Test silindi (fallback).');
        }
      } catch (e2) {
        if (mounted) {
          setState(() => _isLoading = false);
          final errorMessage = e2.toString();
          _snack('Test silinemedi: ${errorMessage.length > 60 ? errorMessage.substring(0, 60) + "..." : errorMessage}', isError: true);
        }
      }
    }
  }

  // -------------------- ADMINS --------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchAdmins() {
    return _db.collection(kAdminsCol).limit(100).snapshots();
  }

  String _normalizeUsername(String raw) => raw.trim().toLowerCase();

  Future<void> _addAdminByUsername() async {
    final raw = _addAdminUsernameCtrl.text.trim();
    if (raw.isEmpty) {
      _snack('Kullanıcı adı gir.');
      return;
    }

    final unameLower = _normalizeUsername(raw);

    try {
      setState(() => _isLoading = true);
      
      final unameDoc = await _db.collection('usernames').doc(unameLower).get();
      if (!unameDoc.exists) {
        if (mounted) {
          setState(() => _isLoading = false);
          _snack('Bu kullanıcı adı bulunamadı.');
        }
        return;
      }

      final data = unameDoc.data() ?? <String, dynamic>{};
      final uid = (data['uid'] ?? '').toString().trim();
      if (uid.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          _snack('UID bulunamadı (usernames dokümanı eksik).');
        }
        return;
      }

      // Repository metodunu kullan
      await _adminRepo.addAdminByUid(
        targetUid: uid,
        adminUid: _myUid ?? '',
        usernameLower: unameLower,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        _addAdminUsernameCtrl.clear();
        _snack('Admin başarıyla eklendi: @$unameLower');
      }
    } catch (e) {
      // fallback
      try {
        final uid = (await _db.collection('usernames').doc(unameLower).get()).data()?['uid'] as String?;
        if (uid != null && uid.isNotEmpty) {
          await _db.collection(kAdminsCol).doc(uid).set({
            'usernameLower': unameLower,
            'addedBy': _myUid ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        if (mounted) {
          setState(() => _isLoading = false);
          _addAdminUsernameCtrl.clear();
          _snack('Admin eklendi (fallback): @$unameLower');
        }
      } catch (e2) {
        if (mounted) {
          setState(() => _isLoading = false);
          final errorMessage = e2.toString();
          _snack('Admin eklenemedi: ${errorMessage.length > 60 ? errorMessage.substring(0, 60) + "..." : errorMessage}', isError: true);
        }
      }
    }
  }

  Future<void> _removeAdmin(String uid) async {
    if (_myUid == uid) {
      _snack('Kendi adminliğini panelden kaldıramazsın.');
      return;
    }

    try {
      setState(() => _isLoading = true);
      await _adminRepo.removeAdminByUid(uid);
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Admin başarıyla kaldırıldı.');
      }
    } catch (e) {
      // fallback
      try {
        await _db.collection(kAdminsCol).doc(uid).delete();
        if (mounted) {
          setState(() => _isLoading = false);
          _snack('Admin kaldırıldı (fallback).');
        }
      } catch (e2) {
        if (mounted) {
          setState(() => _isLoading = false);
          final errorMessage = e2.toString();
          _snack('Admin kaldırılamadı: ${errorMessage.length > 60 ? errorMessage.substring(0, 60) + "..." : errorMessage}', isError: true);
        }
      }
    }
  }

  // -------------------- APPLICATIONS (Başvurular) --------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchPendingExpertApplications() {
    return _db
        .collection(kExpertApplicationsCol)
        .where(kAppStatusField, isEqualTo: 'pending')
        .orderBy(kAppCreatedAtField, descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> _approveExpertApplication({
    required String applicationId,
    required String applicantUid,
  }) async {
    try {
      setState(() => _isLoading = true);
      
      await _db.runTransaction((tx) async {
        final appRef = _db.collection(kExpertApplicationsCol).doc(applicationId);
        final userRef = _db.collection(kUsersCol).doc(applicantUid);

        final appSnap = await tx.get(appRef);
        if (!appSnap.exists) {
          throw Exception('Başvuru bulunamadı.');
        }

        // Başvuru durumunu güncelle
        tx.set(
          appRef,
          {
            kAppStatusField: 'approved',
            kAppReviewedAtField: FieldValue.serverTimestamp(),
            kAppReviewedByField: _myUid ?? '',
          },
          SetOptions(merge: true),
        );

        // Kullanıcı rolünü expert yap
        tx.set(
          userRef,
          {
            kUserRoleField: 'expert',
            'expertApprovedAt': FieldValue.serverTimestamp(),
            'expertApprovedBy': _myUid ?? '',
            // Otomatik ban kaldır
            kUserBannedField: false,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Başvuru onaylandı. Kullanıcı artık uzman.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errorMessage = e.toString();
        _snack('Onay başarısız: ${errorMessage.length > 60 ? errorMessage.substring(0, 60) + "..." : errorMessage}', isError: true);
      }
    }
  }

  Future<void> _rejectExpertApplication({
    required String applicationId,
    required String applicantUid,
    String? reason,
  }) async {
    try {
      setState(() => _isLoading = true);
      
      await _db.collection(kExpertApplicationsCol).doc(applicationId).set(
        {
          kAppStatusField: 'rejected',
          kAppReviewedAtField: FieldValue.serverTimestamp(),
          kAppReviewedByField: _myUid ?? '',
          if (reason != null && reason.trim().isNotEmpty) kAppRejectReasonField: reason.trim(),
        },
        SetOptions(merge: true),
      );

      // Kullanıcının rolünü client olarak bırak (zaten client olmalı)
      // İsteğe bağlı: expertStatus'u rejected yap
      await _db.collection(kUsersCol).doc(applicantUid).set(
        {
          'expertStatus': 'rejected',
          'expertReviewedAt': FieldValue.serverTimestamp(),
          'expertReviewedBy': _myUid ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Başvuru reddedildi.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errorMessage = e.toString();
        _snack('Red başarısız: ${errorMessage.length > 60 ? errorMessage.substring(0, 60) + "..." : errorMessage}', isError: true);
      }
    }
  }

  Future<void> _promptRejectReasonAndReject({
    required String applicationId,
    required String applicantUid,
  }) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Başvuruyu reddet'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Red gerekçesi (isteğe bağlı)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reddet')),
        ],
      ),
    );

    if (ok == true) {
      await _rejectExpertApplication(
        applicationId: applicationId,
        applicantUid: applicantUid,
        reason: ctrl.text,
      );
    }
  }

  // -------------------- REPORTS (Şikayetler) --------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchOpenReports() {
    return _db
        .collection(kReportsCol)
        .where(kReportStatusField, isEqualTo: 'open')
        .orderBy(kReportCreatedAtField, descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> _closeReport(String reportId) async {
    try {
      setState(() => _isLoading = true);
      await _adminRepo.closeReport(
        reportId: reportId,
        adminUid: _myUid ?? '',
      );
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Şikayet başarıyla kapatıldı.');
      }
    } catch (e) {
      // fallback
      try {
        await _db.collection(kReportsCol).doc(reportId).set(
          {
            kReportStatusField: 'closed',
            kReportClosedAtField: FieldValue.serverTimestamp(),
            kReportClosedByField: _myUid ?? '',
          },
          SetOptions(merge: true),
        );
        if (mounted) {
          setState(() => _isLoading = false);
          _snack('Şikayet kapatıldı (fallback).');
        }
      } catch (e2) {
        if (mounted) {
          setState(() => _isLoading = false);
          final errorMessage = e2.toString();
          _snack('Şikayet kapatılamadı: ${errorMessage.length > 60 ? errorMessage.substring(0, 60) + "..." : errorMessage}', isError: true);
        }
      }
    }
  }

  Future<void> _deleteReportDoc(String reportId) async {
    try {
      await _db.collection(kReportsCol).doc(reportId).delete();
      _snack('Şikayet kaydı silindi.');
    } catch (e) {
      _snack('Şikayet kaydı silinemedi: $e');
    }
  }

  Future<void> _handleReportAction({
    required String reportId,
    required String targetType,
    required String targetId,
    required bool alsoClose,
  }) async {
    try {
      if (targetType == 'post') {
        await _deletePost(targetId);
      } else if (targetType == 'reply') {
        await _softDeleteReply(targetId);
      } else {
        _snack('Bu targetType için işlem tanımlı değil: $targetType');
        return;
      }

      if (alsoClose) {
        await _closeReport(reportId);
      }
    } catch (e) {
      _snack('İşlem başarısız: $e');
    }
  }

  // -------------------- UI building blocks --------------------

  Widget _sectionHeader(String title, {String? subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, {Color? bg, Color? fg}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg ?? (isDark ? Colors.white : Colors.black87))),
    );
  }

  Widget _buildNotAllowed() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Bu sayfaya erişim iznin yok.',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_checking && !_isAdmin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Admin kontrolü yapılıyor...',
                style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }
    if (!_isAdmin) return _buildNotAllowed();

    // 7 tabs: Users, Applications, Reports, Posts, Replies, Tests, Admins
    return DefaultTabController(
      length: 7,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('Admin Panel'),
              bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Kullanıcılar'),
              Tab(text: 'Başvurular'),
              Tab(text: 'Şikayetler'),
              Tab(text: 'Postlar'),
              Tab(text: 'Yorumlar'),
              Tab(text: 'Testler'),
              Tab(text: 'Adminler'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1) USERS (overflow fix: no ListTile.trailing Column)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _watchUsers(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                          const SizedBox(height: 16),
                          Text('Hata: ${snap.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text('Kullanıcı bulunamadı.', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();

                    final uid = doc.id;
                    final name = (d['name'] ?? '').toString();
                    final username = (d['username'] ?? '').toString();
                    final email = (d['email'] ?? '').toString();
                    final role = (d[kUserRoleField] ?? 'client').toString();
                    final banned = (d[kUserBannedField] == true);

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.black.withOpacity(0.06)),
                      ),
                      child: InkWell(
                        onTap: () {
                          // Kullanıcı profiline git
                          if (role == 'expert' || role == 'admin') {
                            Navigator.pushNamed(context, '/publicExpertProfile', arguments: uid);
                          } else {
                            Navigator.pushNamed(context, '/publicClientProfile', arguments: uid);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                                  ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name.isNotEmpty ? name : '(isimsiz)',
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '@$username',
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (email.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          email,
                                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Text(
                                        'uid: $uid',
                                        style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _pill(
                                      role == 'expert'
                                          ? 'Uzman'
                                          : (role == 'admin' ? 'Admin' : 'Danışan'),
                                      bg: role == 'expert'
                                          ? Colors.deepPurple.withOpacity(0.10)
                                          : (role == 'admin'
                                          ? Colors.blue.withOpacity(0.10)
                                          : Colors.black.withOpacity(0.05)),
                                      fg: role == 'expert'
                                          ? Colors.deepPurple
                                          : (role == 'admin' ? Colors.blue : (isDark ? Colors.white : Colors.black87)),
                                    ),
                                    const SizedBox(height: 6),
                                    _pill(
                                      banned ? 'BANLI' : 'AKTİF',
                                      bg: banned ? Colors.red.withOpacity(0.10) : Colors.green.withOpacity(0.10),
                                      fg: banned ? Colors.red : Colors.green,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: role,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Rol',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'client', child: Text('Danışan')),
                                      DropdownMenuItem(value: 'expert', child: Text('Uzman')),
                                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                    ],
                                    onChanged: (v) {
                                      if (v == null) return;
                                      _setUserRole(uid: uid, newRole: v);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Ban', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    Switch(
                                      value: banned,
                                      onChanged: (val) => _setUserBanned(uid: uid, banned: val),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ),
                    );
                  },
                );
              },
            ),

            // 2) APPLICATIONS (Başvurular)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _watchPendingExpertApplications(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Hata: ${snap.error}'));
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return ListView(
                    children: [
                      _sectionHeader('Başvurular', subtitle: 'Durumu “pending” olan uzman başvuruları listelenir.'),
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Bekleyen başvuru yok.'),
                      ),
                    ],
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _sectionHeader('Başvurular', subtitle: 'Onay/ret işlemlerini buradan yönetebilirsin.'),
                    ...docs.map((doc) {
                      final d = doc.data();
                      final appId = doc.id;

                      final applicantUid = (d[kAppApplicantUidField] ?? '').toString();
                      final name = (d['name'] ?? '').toString();
                      final username = (d['username'] ?? '').toString();
                      final profession = (d['profession'] ?? '').toString();
                      final expertise = (d['expertise'] ?? '').toString();
                      final note = (d['note'] ?? d['message'] ?? '').toString();
                      final createdAt = d[kAppCreatedAtField] as Timestamp?;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.black.withOpacity(0.06)),
                        ),
                        child: InkWell(
                          onTap: () {
                            // Başvuran kullanıcının profiline git
                            if (applicantUid.isNotEmpty) {
                              Navigator.pushNamed(context, '/publicClientProfile', arguments: applicantUid);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name.isNotEmpty ? name : '(isim yok)',
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (createdAt != null)
                                      Text(_ts(createdAt), style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                                  ],
                                ),
                              if (username.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text('@$username', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (profession.isNotEmpty) _pill(profession, bg: Colors.deepPurple.withOpacity(0.08), fg: Colors.deepPurple),
                                  if (expertise.isNotEmpty) _pill(expertise),
                                ],
                              ),
                              if (note.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(note, style: const TextStyle(fontSize: 13)),
                              ],
                              const SizedBox(height: 10),
                              Text(
                                'uid: $applicantUid',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: applicantUid.isEmpty
                                          ? null
                                          : () => _approveExpertApplication(
                                        applicationId: appId,
                                        applicantUid: applicantUid,
                                      ),
                                      icon: const Icon(Icons.check),
                                      label: const Text('Onayla'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: applicantUid.isEmpty
                                          ? null
                                          : () => _promptRejectReasonAndReject(
                                        applicationId: appId,
                                        applicantUid: applicantUid,
                                      ),
                                      icon: const Icon(Icons.close),
                                      label: const Text('Reddet'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      );
                    }),
                  ],
                );
              },
            ),

            // 3) REPORTS (Şikayetler)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _watchOpenReports(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Hata: ${snap.error}'));
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return ListView(
                    children: [
                      _sectionHeader('Şikayetler', subtitle: 'Durumu “open” olan şikayetler listelenir.'),
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Açık şikayet yok.'),
                      ),
                    ],
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _sectionHeader(
                      'Şikayetler',
                      subtitle: 'Close / içerik kaldır / rapor sil işlemlerini buradan yönetebilirsin.',
                    ),
                    ...docs.map((doc) {
                      final d = doc.data();
                      final reportId = doc.id;

                      final createdAt = d[kReportCreatedAtField] as Timestamp?;
                      final targetType = (d[kReportTargetTypeField] ?? '').toString();
                      final targetId = (d[kReportTargetIdField] ?? '').toString();
                      final reason = (d[kReportReasonField] ?? '').toString();
                      final targetOwnerId = (d[kReportTargetOwnerIdField] ?? '').toString();
                      final createdBy = (d[kReportCreatedByField] ?? '').toString();

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.black.withOpacity(0.06)),
                        ),
                        child: InkWell(
                          onTap: () {
                            // Şikayet edilen içeriğe git
                            if (targetType == 'post' && targetId.isNotEmpty) {
                              Navigator.pushNamed(context, '/postDetail', arguments: {'postId': targetId});
                            } else if (targetType == 'reply' && targetId.isNotEmpty) {
                              // ✅ Yorumlar artık posts koleksiyonunda (isComment: true)
                              // Reply için önce rootPostId'yi bul, sonra post detayına git
                              _db.collection(kPostsCol).doc(targetId).get().then((replyDoc) {
                                if (replyDoc.exists && mounted) {
                                  final rootPostId = replyDoc.data()?['rootPostId'] as String?;
                                  if (rootPostId != null && rootPostId.isNotEmpty) {
                                    Navigator.pushNamed(context, '/postDetail', arguments: {'postId': rootPostId});
                                  }
                                }
                              });
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Şikayet: ${targetType.isNotEmpty ? targetType : '(type yok)'}',
                                        style: const TextStyle(fontWeight: FontWeight.w900),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (createdAt != null)
                                      Text(_ts(createdAt), style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (reason.trim().isNotEmpty) Text(reason, style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (targetId.isNotEmpty) _pill('targetId: $targetId'),
                                    if (targetOwnerId.isNotEmpty) _pill('owner: $targetOwnerId'),
                                    if (createdBy.isNotEmpty) _pill('by: $createdBy'),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Actions
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _closeReport(reportId),
                                        child: const Text('Kapat'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: (targetType.isEmpty || targetId.isEmpty)
                                            ? null
                                            : () => _handleReportAction(
                                          reportId: reportId,
                                          targetType: targetType,
                                          targetId: targetId,
                                          alsoClose: true,
                                        ),
                                        child: Text(
                                          targetType == 'post'
                                              ? 'Postu Sil + Kapat'
                                              : (targetType == 'reply' ? 'Yorumu Gizle + Kapat' : 'İçeriği İşle'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => _deleteReportDoc(reportId),
                                        child: const Text('Şikayet Kaydını Sil'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),

            // 4) POSTS
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _watchPosts(),
              builder: (context, snap) {
                if (snap.hasError) {
                  final errorStr = snap.error.toString();
                  final isIndexError = errorStr.contains('index') || errorStr.contains('failed-precondition');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                          const SizedBox(height: 16),
                          Text(
                            isIndexError
                                ? 'Index oluşturuluyor... Lütfen birkaç dakika bekleyin.'
                                : 'Hata: ${errorStr.length > 100 ? errorStr.substring(0, 100) + "..." : errorStr}',
                            textAlign: TextAlign.center,
                          ),
                          if (isIndexError) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => setState(() {}),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tekrar Dene'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.article_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text('Post bulunamadı.', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();

                    final id = doc.id;
                    final authorName = (d['authorName'] ?? '').toString();
                    final content = (d['content'] ?? '').toString(); // ✅ Yorumlar artık 'content' kullanıyor
                    final createdAt = d['createdAt'] as Timestamp?;

                    // likeCount drift olabilir; varsa göster, yoksa likedBy length
                    final likedByRaw = d['likedBy'];
                    final likedByCount = likedByRaw is List ? likedByRaw.length : 0;
                    final likeCount = _asInt(d['likeCount'] ?? likedByCount);
                    final replyCount = _asInt(d['replyCount'] ?? 0);

                    return ListTile(
                      onTap: () {
                        // Post detayına git
                        Navigator.pushNamed(context, '/postDetail', arguments: {'postId': id});
                      },
                      title: Text(content.isNotEmpty ? content : '(içerik yok)', maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        'Yazar: $authorName • ${_ts(createdAt)}\nLike: $likeCount • Reply: $replyCount\npostId: $id',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'Sil',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Post sil'),
                              content: const Text('Bu post silinsin mi?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
                              ],
                            ),
                          );
                          if (ok == true) _deletePost(id);
                        },
                      ),
                    );
                  },
                );
              },
            ),

            // 5) REPLIES
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _watchReplies(),
              builder: (context, snap) {
                if (snap.hasError) {
                  final errorStr = snap.error.toString();
                  final isIndexError = errorStr.contains('index') || errorStr.contains('failed-precondition');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                          const SizedBox(height: 16),
                          Text(
                            isIndexError
                                ? 'Index oluşturuluyor... Lütfen birkaç dakika bekleyin.'
                                : 'Hata: ${errorStr.length > 100 ? errorStr.substring(0, 100) + "..." : errorStr}',
                            textAlign: TextAlign.center,
                          ),
                          if (isIndexError) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => setState(() {}),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tekrar Dene'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.comment_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text('Yorum bulunamadı.', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();

                    final id = doc.id;
                    final authorName = (d['authorName'] ?? '').toString();
                    final content = (d['content'] ?? '').toString(); // ✅ Yorumlar artık 'content' kullanıyor
                    final deleted = (d['deleted'] == true);
                    final rootPostId = (d['rootPostId'] ?? '').toString();
                    final parentPostId = (d['parentPostId'] ?? '').toString();
                    final createdAt = d['createdAt'] as Timestamp?;

                    return ListTile(
                      onTap: () {
                        // Yorumun ait olduğu post detayına git
                        if (rootPostId.isNotEmpty) {
                          Navigator.pushNamed(context, '/postDetail', arguments: {'postId': rootPostId});
                        }
                      },
                      title: Text(
                        deleted ? '(silinmiş/gizli)' : (content.isNotEmpty ? content : '(boş)'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Yazar: $authorName • ${_ts(createdAt)}\nrootPostId: $rootPostId${parentPostId.isNotEmpty && parentPostId != rootPostId ? '\nparentPostId: $parentPostId' : ''}\ncommentId: $id',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'Gizle',
                        icon: const Icon(Icons.hide_source),
                        onPressed: deleted
                            ? null
                            : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Yorumu gizle'),
                              content: const Text('Bu yorum soft-delete ile gizlenecek. Devam edilsin mi?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Gizle')),
                              ],
                            ),
                          );
                          if (ok == true) _softDeleteReply(id);
                        },
                      ),
                    );
                  },
                );
              },
            ),

            // 6) TESTS
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _watchTests(),
              builder: (context, snap) {
                if (snap.hasError) {
                  final errorStr = snap.error.toString();
                  final isIndexError = errorStr.contains('index') || errorStr.contains('failed-precondition');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                          const SizedBox(height: 16),
                          Text(
                            isIndexError
                                ? 'Index oluşturuluyor... Lütfen birkaç dakika bekleyin.'
                                : 'Hata: ${errorStr.length > 100 ? errorStr.substring(0, 100) + "..." : errorStr}',
                            textAlign: TextAlign.center,
                          ),
                          if (isIndexError) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => setState(() {}),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Yeniden Dene'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Test yok.'),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();

                    final id = doc.id;
                    final title = (d['title'] ?? '').toString();
                    final description = (d['description'] ?? '').toString();
                    final createdBy = (d['createdBy'] ?? '').toString();
                    final expertName = (d['expertName'] ?? '').toString();
                    final createdAt = d['createdAt'] as Timestamp?;
                    
                    // ✅ Soru sayısını hesapla
                    final questions = d['questions'];
                    final questionCount = questions is List ? questions.length : 0;

                    return ListTile(
                      onTap: () {
                        // Test detayına git
                        Navigator.pushNamed(context, '/expertTestDetail', arguments: id);
                      },
                      title: Text(
                        title.isNotEmpty ? title : '(adsız test)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            description.isNotEmpty 
                                ? (description.length > 60 ? '${description.substring(0, 60)}...' : description)
                                : '(açıklama yok)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Oluşturan: $createdBy${expertName.isNotEmpty ? ' ($expertName)' : ''} • ${_ts(createdAt)}\nSoru sayısı: $questionCount • testId: $id',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        tooltip: 'Sil',
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red.shade400,
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Test sil'),
                              content: Text('Bu test silinsin mi?\n\n"$title"'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Vazgeç'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Sil'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) _deleteTest(id);
                        },
                      ),
                    );
                  },
                );
              },
            ),

            // 7) ADMINS
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Admin Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _addAdminUsernameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Kullanıcı adı (username)',
                              hintText: 'ör: zelalkaya',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _addAdminByUsername,
                              icon: const Icon(Icons.person_add),
                              label: const Text('Admin Ekle'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Mevcut Adminler', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _watchAdmins(),
                      builder: (context, snap) {
                        if (snap.hasError) return Center(child: Text('Hata: ${snap.error}'));
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snap.data?.docs ?? const [];
                        if (docs.isEmpty) return const Center(child: Text('Admin yok.'));

                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final doc = docs[i];
                            final d = doc.data();

                            final uid = doc.id;
                            final uname = (d['usernameLower'] ?? '').toString();

                            return ListTile(
                              title: Text(uname.isNotEmpty ? '@$uname' : '(username yok)'),
                              subtitle: Text('uid: $uid'),
                              trailing: IconButton(
                                tooltip: 'Kaldır',
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Admin kaldır'),
                                      content: const Text('Bu admin kaldırılsın mı?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaldır')),
                                      ],
                                    ),
                                  );
                                  if (ok == true) _removeAdmin(uid);
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
          // Loading overlay (işlemler sırasında)
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
