import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../repositories/firestore_test_repository.dart';
import '../repositories/firestore_report_repository.dart';
import '../services/analytics_service.dart';
import '../widgets/empty_state_widget.dart';
import '../utils/error_handler.dart';

class ExpertTestListScreen extends StatefulWidget {
  const ExpertTestListScreen({super.key});

  @override
  State<ExpertTestListScreen> createState() => _ExpertTestListScreenState();
}

class _ExpertTestListScreenState extends State<ExpertTestListScreen> {
  String _searchQuery = '';
  String _displaySearchQuery = ''; // ✅ PERFORMANCE: Debounced search query
  Timer? _debounceTimer;

  String _answerTypeLabel(String answerType) {
    return answerType == 'scale' ? '1–5 Skala' : 'Yazılı';
  }

  int _questionsLength(dynamic raw) {
    if (raw is List) return raw.length;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    // ✅ Analytics: Screen view tracking
    AnalyticsService.logScreenView('expert_test_list');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _displaySearchQuery = value.toLowerCase().trim();
        });
      }
    });
  }

  Future<void> _showDeleteRequestDialog(BuildContext context, String testId, String testTitle) async {
    final reasonCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();
    File? selectedFile;
    String? fileName;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Test Silme Başvurusu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test: $testTitle',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Silme Gerekçesi *'),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Örn: Test artık kullanılmıyor, hatalı içerik...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text('Açıklama (isteğe bağlı)'),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ek bilgiler...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final fileResult = await FilePicker.platform.pickFiles(type: FileType.any);
                      if (fileResult != null && fileResult.files.single.path != null) {
                        setDialogState(() {
                          selectedFile = File(fileResult.files.single.path!);
                          fileName = fileResult.files.single.name;
                        });
                      }
                    } catch (e) {
                      // Hata durumunda sessizce devam et
                    }
                  },
                  icon: const Icon(Icons.attach_file),
                  label: Text(fileName ?? 'Dosya Ekle (isteğe bağlı)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: reasonCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Başvuru Gönder'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    if (reasonCtrl.text.trim().isEmpty) {
      AppErrorHandler.showInfo(context, 'Lütfen silme gerekçesini belirtin');
      return;
    }

    try {
      final reportRepo = FirestoreReportRepository();
      await reportRepo.createReport(
        targetType: 'test_deletion_request',
        targetId: testId,
        reason: reasonCtrl.text.trim(),
        details: detailsCtrl.text.trim(),
        attachment: selectedFile,
      );

      if (context.mounted) {
        AppErrorHandler.showSuccess(
          context,
          'Silme başvurunuz admin\'e iletildi. İnceleme sonrası size bilgi verilecektir.',
        );
      }
    } catch (e, stackTrace) {
      if (context.mounted) {
        AppErrorHandler.handleError(
          context,
          e,
          stackTrace: stackTrace,
          customMessage: 'Başvuru gönderilirken bir hata oluştu',
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final testRepo = FirestoreTestRepository();

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Önce giriş yapmalısın.',
            style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Oluşturduğum Testler'),
      ),
      body: Column(
        children: [
          // Arama Barı
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _onSearchChanged(value);
              },
              decoration: InputDecoration(
                hintText: 'Test ara...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: testRepo.watchTestsByCreator(user.uid),
              builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return EmptyStates.error(
              message: 'Testler yüklenirken hata oluştu.',
              onRetry: () => setState(() {}),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return EmptyStates.noTests(
              onCreateTest: () => Navigator.pushNamed(context, '/createTest'),
            );
          }

          final allDocs = snapshot.data!.docs.toList();
          
          // ✅ PERFORMANCE: Arama filtresi (debounced)
          final filteredDocs = _displaySearchQuery.isEmpty
              ? allDocs
              : allDocs.where((doc) {
                  final data = doc.data();
                  final title = (data['title']?.toString() ?? '').toLowerCase();
                  final description = (data['description']?.toString() ?? '').toLowerCase();
                  return title.contains(_displaySearchQuery) || description.contains(_displaySearchQuery);
                }).toList();
          
          filteredDocs.sort((a, b) {
            final aTs = a.data()['createdAt'] as Timestamp?;
            final bTs = b.data()['createdAt'] as Timestamp?;
            final aTime =
                aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          if (filteredDocs.isEmpty) {
            return _displaySearchQuery.isEmpty 
                ? EmptyStates.noTests(
                    onCreateTest: () => Navigator.pushNamed(context, '/createTest'),
                  )
                : EmptyStates.noSearchResults();
          }

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data();

              final title = data['title']?.toString() ?? 'Başlıksız test';
              final description = data['description']?.toString() ?? '';
              final answerType = data['answerType']?.toString() ?? 'text';
              final qLen = _questionsLength(data['questions']);

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Soru sayısı: $qLen • Cevap tipi: ${_answerTypeLabel(answerType)}',
                            style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/expertTestDetail',
                          arguments: doc.id,
                        );
                      },
                    ),
                    // Test Silme Başvurusu Butonu
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showDeleteRequestDialog(context, doc.id, title),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Silme Başvurusu'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
              },
            ),
          ),
        ],
      ),
    );
  }
}
