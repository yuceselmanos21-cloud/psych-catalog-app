import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/firestore_block_repository.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import 'users_list_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _blockRepo = FirestoreBlockRepository();
  final _themeService = ThemeService();
  bool _isPrivate = false;
  bool _loading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    // ✅ Analytics: Screen view tracking
    AnalyticsService.logScreenView('settings');
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      setState(() {
        _isPrivate = userDoc.data()?['isPrivate'] ?? false;
        _userRole = userDoc.data()?['role'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _togglePrivacy() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'isPrivate': !_isPrivate});

      if (!mounted) return;
      setState(() => _isPrivate = !_isPrivate);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isPrivate
                ? 'Profil gizliliği açıldı'
                : 'Profil gizliliği kapatıldı',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : Colors.grey.shade50;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Ayarlar'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profil Ayarları
                _buildSectionTitle('Profil Ayarları', isDark),
                const SizedBox(height: 8),
                _buildSettingCard(
                  title: 'Profil Düzenle',
                  subtitle: 'Ad, kullanıcı adı, bio ve diğer bilgileri düzenle',
                  icon: Icons.edit_outlined,
                  iconColor: Colors.blue,
                  onTap: () {
                    Navigator.pushNamed(context, '/profile');
                  },
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildSettingCard(
                  title: 'Profil Gizliliği',
                  subtitle: _isPrivate
                      ? 'Profiliniz gizli (sadece takipçileriniz görebilir)'
                      : 'Profiliniz herkese açık',
                  icon: _isPrivate ? Icons.lock : Icons.lock_open,
                  iconColor: _isPrivate ? Colors.orange : Colors.green,
                  trailing: Switch(
                    value: _isPrivate,
                    onChanged: (_) => _togglePrivacy(),
                  ),
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),

                // Abonelik (Expert ise)
                if (_userRole == 'expert' || _userRole == 'admin') ...[
                  _buildSectionTitle('Abonelik', isDark),
                  const SizedBox(height: 8),
                  _buildSettingCard(
                    title: 'Abonelik Yönetimi',
                    subtitle: 'Abonelik planınızı görüntüleyin ve yönetin',
                    icon: Icons.payment,
                    iconColor: Colors.green,
                    onTap: () {
                      Navigator.pushNamed(context, '/subscription');
                    },
                    cardBg: cardBg,
                    borderColor: borderColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 24),
                ],

                // Engelleme ve Güvenlik
                _buildSectionTitle('Engelleme ve Güvenlik', isDark),
                const SizedBox(height: 8),
                _buildSettingCard(
                  title: 'Engellenenler',
                  subtitle: 'Engellediğiniz kullanıcıları görüntüle ve yönet',
                  icon: Icons.block,
                  iconColor: Colors.red,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BlockedUsersScreen(),
                      ),
                    );
                  },
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),

                // Görünüm
                _buildSectionTitle('Görünüm', isDark),
                const SizedBox(height: 8),
                _buildSettingCard(
                  title: 'Koyu Mod',
                  subtitle: isDark ? 'Açık moda geç' : 'Koyu moda geç',
                  icon: isDark ? Icons.light_mode : Icons.dark_mode,
                  iconColor: Colors.amber,
                  trailing: Switch(
                    value: isDark,
                    onChanged: (_) => _themeService.toggleTheme(),
                  ),
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),

                // Bildirimler
                _buildSectionTitle('Bildirimler', isDark),
                const SizedBox(height: 8),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(_auth.currentUser?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data() as Map<String, dynamic>?;
                    final hasToken = data?['fcmToken'] != null;
                    return _buildSettingCard(
                      title: 'Push Bildirimleri',
                      subtitle: hasToken 
                          ? 'Bildirimler aktif'
                          : 'Yeni mesajlar, beğeniler ve yorumlar için bildirim al',
                      icon: Icons.notifications_outlined,
                      iconColor: Colors.blue,
                      trailing: Switch(
                        value: hasToken,
                        onChanged: (value) async {
                          if (value) {
                            await NotificationService.initialize();
                          } else {
                            await NotificationService.deleteToken();
                          }
                        },
                      ),
                      cardBg: cardBg,
                      borderColor: borderColor,
                      isDark: isDark,
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    Widget? trailing,
    VoidCallback? onTap,
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
  }) {
    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (onTap != null && trailing == null)
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Engellenenler Listesi Ekranı
class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : Colors.grey.shade50;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final blockRepo = FirestoreBlockRepository();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Engellenenler'),
        elevation: 0,
      ),
      body: currentUserId == null
          ? const Center(child: Text('Giriş yapmanız gerekiyor'))
          : StreamBuilder<Set<String>>(
              stream: blockRepo.watchBlockedIds(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.block,
                          size: 64,
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Engellenen kullanıcı yok',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final blockedIds = snapshot.data!.toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: blockedIds.length,
                  itemBuilder: (context, index) {
                    final blockedId = blockedIds[index];
                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(blockedId)
                          .snapshots(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) {
                          return const SizedBox.shrink();
                        }

                        final userData = userSnap.data!.data() as Map<String, dynamic>?;
                        if (userData == null) {
                          return const SizedBox.shrink();
                        }

                        final name = userData['name'] ?? 'Kullanıcı';
                        final username = userData['username'] ?? '';
                        final photoUrl = userData['photoUrl'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          color: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: borderColor, width: 1),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade200,
                              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl == null || photoUrl.isEmpty
                                  ? Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: username.isNotEmpty
                                ? Text(
                                    '@$username',
                                    style: TextStyle(
                                      color: Colors.deepPurple,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            trailing: TextButton(
                              onPressed: () async {
                                try {
                                  await blockRepo.unblock(
                                    currentUserId: currentUserId,
                                    blockedUserId: blockedId,
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Engel kaldırıldı'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Hata: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Engeli Kaldır'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
