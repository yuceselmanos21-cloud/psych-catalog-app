import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_test_repository.dart';

class ExpertTestDetailScreen extends StatelessWidget {
  final String testId;

  const ExpertTestDetailScreen({
    super.key,
    required this.testId,
  });

  static const _answerTypeScale = 'scale';

  String _answerTypeLabel(String answerType) {
    return answerType == _answerTypeScale ? '1–5 Arası Skala' : 'Yazılı';
  }

  /// questions eski/yeni formatla uyumlu:
  /// - List<String>
  /// - List<dynamic>
  /// - List<Map {text: ...}>
  List<String> _normalizeQuestions(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) {
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          return m['text']?.toString() ?? e.toString();
        }
        return e.toString();
      })
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final testRepo = FirestoreTestRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Detayı'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: testRepo.watchTest(testId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Test yüklenirken hata oluştu.',
                style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Test bulunamadı.',
                style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              ),
            );
          }

          final data = snapshot.data!.data() ?? <String, dynamic>{};

          final title = data['title']?.toString().trim().isNotEmpty == true
              ? data['title'].toString()
              : 'Başlıksız test';

          final description = data['description']?.toString() ?? '';
          final answerType = data['answerType']?.toString() ?? 'text';
          final questions = _normalizeQuestions(data['questions']);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (description.trim().isNotEmpty) ...[
                    Text(description),
                    const SizedBox(height: 12),
                  ],

                  Text(
                    'Cevap tipi: ${_answerTypeLabel(answerType)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Sorular',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (questions.isEmpty)
                    Text(
                      'Bu testte soru bulunamadı.',
                      style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey),
                    )
                  else
                    ...questions.asMap().entries.map(
                          (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• Soru ${e.key + 1}: ${e.value}'),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ✅ Kaç kez çözülmüş bilgisi (repo üzerinden)
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: testRepo.watchSolvedTestsByTest(testId),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Text(
                          'Çözülme sayısı yükleniyor...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        );
                      }

                      if (snap.hasError) {
                        return const Text(
                          'Çözülme sayısı alınamadı.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        );
                      }

                      final count = snap.data?.docs.length ?? 0;

                      return Text(
                        'Bu test $count kez çözülmüş.',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
