import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../repositories/firestore_test_repository.dart';
import '../repositories/firestore_report_repository.dart';
import '../services/analytics_service.dart';
import '../utils/error_handler.dart';

class TestsScreen extends StatefulWidget {
  const TestsScreen({super.key});

  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> {
  String _searchQuery = '';
  String _displaySearchQuery = ''; // ✅ PERFORMANCE: Debounced search query
  Timer? _debounceTimer;

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

  @override
  void initState() {
    super.initState();
    // ✅ Analytics: Screen view tracking
    AnalyticsService.logScreenView('tests');
  }

  @override
  Widget build(BuildContext context) {
    final testRepo = FirestoreTestRepository();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tüm Testler'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
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
              stream: testRepo.watchAllTests(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Testler yüklenirken hata oluştu.',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.quiz_outlined,
                          size: 64,
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz test bulunmuyor',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs.toList();

                // Sort by date
                docs.sort((a, b) {
                  final aTs = a.data()['createdAt'] as Timestamp?;
                  final bTs = b.data()['createdAt'] as Timestamp?;
                  final aTime =
                      aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime =
                      bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });

                // ✅ PERFORMANCE: Filter by debounced search query
                final filteredDocs = _displaySearchQuery.isEmpty
                    ? docs
                    : docs.where((doc) {
                        final data = doc.data();
                        final title = (data['title']?.toString() ?? '').toLowerCase();
                        final description = (data['description']?.toString() ?? '').toLowerCase();
                        return title.contains(_displaySearchQuery) || description.contains(_displaySearchQuery);
                      }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aramana uygun test bulunamadı',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data();

                    final title = data['title']?.toString() ?? 'İsimsiz Test';
                    final description =
                        data['description']?.toString() ?? 'Açıklama yok';
                    final answerType = data['answerType']?.toString() ?? 'scale';
                    final questions = data['questions'];
                    final questionCount = questions is List ? questions.length : 0;
                    final createdAt = data['createdAt'] as Timestamp?;
                    final createdDate = createdAt?.toDate();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/solveTest',
                            arguments: {
                              'id': doc.id,
                              'title': title,
                              'description': description,
                              'questions': questions,
                              'answerType': answerType,
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.help_outline,
                                    size: 16,
                                    color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$questionCount soru',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    createdDate != null
                                        ? '${createdDate.day}.${createdDate.month}.${createdDate.year}'
                                        : 'Tarih belirtilmemiş',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Şikayet Butonu
                                  IconButton(
                                    icon: const Icon(Icons.flag_outlined, size: 18),
                                    color: Colors.orange,
                                    tooltip: 'Testi Şikayet Et',
                                    onPressed: () => _showTestReportDialog(context, doc.id, title),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
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
          ),
        ],
      ),
    );
  }

  Future<void> _showTestReportDialog(BuildContext context, String testId, String testTitle) async {
    final reasonCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();
    File? selectedFile;
    String? fileName;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Testi Şikayet Et'),
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
                const Text('Şikayet Gerekçesi *'),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Örn: Uygunsuz içerik, yanlış bilgi, spam...',
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
              child: const Text('Şikayet Et'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    if (reasonCtrl.text.trim().isEmpty) {
      AppErrorHandler.showInfo(context, 'Lütfen şikayet gerekçesini belirtin');
      return;
    }

    try {
      final reportRepo = FirestoreReportRepository();
      await reportRepo.createReport(
        targetType: 'test',
        targetId: testId,
        reason: reasonCtrl.text.trim(),
        details: detailsCtrl.text.trim(),
        attachment: selectedFile,
      );

      if (context.mounted) {
        AppErrorHandler.showSuccess(
          context,
          'Şikayetiniz admin\'e iletildi. İnceleme sonrası gerekli işlemler yapılacaktır.',
        );
      }
    } catch (e, stackTrace) {
      if (context.mounted) {
        AppErrorHandler.handleError(
          context,
          e,
          stackTrace: stackTrace,
          customMessage: 'Şikayet gönderilirken bir hata oluştu',
        );
      }
    }
  }
}
