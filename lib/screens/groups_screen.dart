import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../repositories/firestore_group_repository.dart';
import '../widgets/empty_state_widget.dart';
import '../services/analytics_service.dart';
import '../utils/error_handler.dart';

/// Gruplar ekranı
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _groupRepo = FirestoreGroupRepository();
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // ✅ Analytics: Screen view tracking
    AnalyticsService.logScreenView('groups');
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gruplar')),
        body: const Center(child: Text('Giriş yapmanız gerekiyor')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gruplar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateGroupDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _groupRepo.watchAllGroups(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            // ✅ DEBUG: Hata detaylarını logla
            final error = snapshot.error;
            debugPrint('❌ Groups Screen Error:');
            debugPrint('   Error: $error');
            debugPrint('   Error Type: ${error.runtimeType}');
            if (error is FirebaseException) {
              debugPrint('   Firebase Code: ${error.code}');
              debugPrint('   Firebase Message: ${error.message}');
              debugPrint('   Firebase Stack: ${error.stackTrace}');
            }
            debugPrint('   Stack Trace: ${StackTrace.current}');
            
            // ✅ Kullanıcıya daha detaylı hata mesajı göster
            String errorMessage = 'Gruplar yüklenirken bir hata oluştu';
            String errorDetails = '';
            if (error is FirebaseException) {
              switch (error.code) {
                case 'permission-denied':
                  errorMessage = 'Grupları görüntüleme yetkiniz yok';
                  errorDetails = 'Firebase Code: ${error.code}\n${error.message ?? ""}';
                  break;
                case 'unavailable':
                  errorMessage = 'Servis şu anda kullanılamıyor. Lütfen tekrar deneyin.';
                  errorDetails = 'Firebase Code: ${error.code}\n${error.message ?? ""}';
                  break;
                case 'failed-precondition':
                  errorMessage = 'Firestore index eksik. Lütfen Firebase Console\'dan index oluşturun.';
                  errorDetails = 'Firebase Code: ${error.code}\n${error.message ?? ""}';
                  break;
                default:
                  errorMessage = 'Hata: ${error.code}';
                  errorDetails = '${error.message ?? "Bilinmeyen hata"}';
              }
            } else {
              errorMessage = 'Hata oluştu';
              errorDetails = error.toString();
            }
            
            // ✅ Hata detaylarını ekranda göster (debug için)
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          errorDetails,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final groups = snapshot.data?.docs ?? [];
          if (groups.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.group_outlined,
              title: 'Henüz grup yok',
              subtitle: 'İlk grubu oluşturarak başla',
              actionLabel: 'Grup Oluştur',
              onAction: () => _showCreateGroupDialog(context),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final data = group.data();
              
              final name = data['name'] ?? 'Adsız Grup';
              final description = data['description'] ?? '';
              final memberCount = (data['members'] as List?)?.length ?? 0;
              final photoUrl = data['photoUrl'];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.deepPurple.shade100,
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null || photoUrl.isEmpty
                        ? const Icon(Icons.group, color: Colors.deepPurple)
                        : null,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) ...[
                        Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        '$memberCount üye',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to group detail
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Grup detayı yakında eklenecek')),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Grup oluşturma dialog'u
  void _showCreateGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isPublic = true;
    bool isCreating = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yeni Grup Oluştur'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Grup Adı *',
                    hintText: 'Örn: Psikoloji Öğrencileri',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !isCreating,
                  maxLength: 100,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    hintText: 'Grup hakkında kısa bir açıklama...',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !isCreating,
                  maxLines: 3,
                  maxLength: 500,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: isPublic,
                      onChanged: isCreating
                          ? null
                          : (value) {
                              setDialogState(() {
                                isPublic = value ?? true;
                              });
                            },
                    ),
                    const Expanded(
                      child: Text('Herkese açık grup'),
                    ),
                  ],
                ),
                if (!isPublic)
                  Padding(
                    padding: const EdgeInsets.only(left: 40, top: 8),
                    child: Text(
                      'Özel gruplar sadece davet ile katılım sağlanabilir',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final description = descriptionController.text.trim();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Grup adı gereklidir')),
                        );
                        return;
                      }

                      if (name.length > 100) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Grup adı 100 karakterden uzun olamaz')),
                        );
                        return;
                      }

                      if (description.length > 500) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Açıklama 500 karakterden uzun olamaz')),
                        );
                        return;
                      }

                      setDialogState(() => isCreating = true);

                      try {
                        final user = _auth.currentUser;
                        if (user == null) {
                          throw Exception('Giriş yapmanız gerekiyor');
                        }

                        await _groupRepo.createGroup(
                          name: name,
                          description: description,
                          createdBy: user.uid,
                          isPublic: isPublic,
                        );

                        if (context.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Grup başarıyla oluşturuldu'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e, stackTrace) {
                        if (context.mounted) {
                          setDialogState(() => isCreating = false);
                          AppErrorHandler.handleError(
                            context,
                            e,
                            stackTrace: stackTrace,
                            customMessage: 'Grup oluşturulurken bir hata oluştu',
                          );
                        }
                      }
                    },
              child: isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}
