import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ResultDetailScreen extends StatelessWidget {
  final bool fromArguments;

  final String? testTitle;
  final List<dynamic>? answers;
  final List<dynamic>? questions;
  final DateTime? solvedAt;
  final String? aiAnalysis;

  const ResultDetailScreen({
    super.key,
    this.fromArguments = true,
    this.testTitle,
    this.answers,
    this.questions,
    this.solvedAt,
    this.aiAnalysis,
  });

  static String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $hh:$mm';
  }

  List<String> _normalizeList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  @override
  Widget build(BuildContext context) {
    String title = testTitle ?? 'Test Sonucu';
    List<String> localAnswers = _normalizeList(answers);
    List<String> localQuestions = _normalizeList(questions);
    DateTime? localSolvedAt = solvedAt;
    String localAnalysis = aiAnalysis ?? '';

    if (fromArguments) {
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args == null) {
        return const Scaffold(
          body: Center(child: Text('Sonuç bilgisi bulunamadı.')),
        );
      }

      title = args['testTitle']?.toString() ?? 'Test Sonucu';

      localAnswers = _normalizeList(args['answers']);
      localQuestions = _normalizeList(args['questions']);

      final dynamic rawCreated = args['createdAt'];
      if (rawCreated is Timestamp) {
        localSolvedAt = rawCreated.toDate();
      } else if (rawCreated is DateTime) {
        localSolvedAt = rawCreated;
      }

      localAnalysis = args['aiAnalysis']?.toString() ?? '';
    }

    final itemCount = localAnswers.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Sonucu Detayı'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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

            if (localSolvedAt != null)
              Text(
                'Çözülme tarihi: ${_formatDateTime(localSolvedAt!)}',
                style: const TextStyle(color: Colors.grey),
              ),

            const SizedBox(height: 16),

            if (localAnalysis.trim().isNotEmpty)
              Card(
                color: Colors.purple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Yapay Zekâ Analizi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(localAnalysis),
                    ],
                  ),
                ),
              )
            else
              Card(
                color: Colors.grey.shade200,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Bu sonuç için kayıtlı bir yapay zekâ analizi bulunamadı.',
                  ),
                ),
              ),

            const SizedBox(height: 24),

            const Text(
              'Sorular ve Cevapların',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (itemCount == 0)
              const Text(
                'Bu test sonucu için cevap bulunamadı.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  final soru = index < localQuestions.length
                      ? localQuestions[index]
                      : 'Soru ${index + 1}';
                  final cevap = localAnswers[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Soru ${index + 1}: $soru',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text('Cevabın: $cevap'),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
