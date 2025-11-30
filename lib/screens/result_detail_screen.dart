import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ResultDetailScreen extends StatelessWidget {
  // Eğer çözülen testler listesinden geliyorsak arguments kullanıyoruz
  final bool fromArguments;

  // Eğer SolveTestScreen içinden direkt geliyorsak, burada dolu geliyor
  final String? testTitle;
  final List<String>? answers;
  final List<String>? questions;
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

  @override
  Widget build(BuildContext context) {
    // 1) Eğer fromArguments true ise, Navigator.pushNamed ile gelen argümanları al
    String title = testTitle ?? 'Test Sonucu';
    List<String> localAnswers = answers ?? [];
    List<String> localQuestions = questions ?? [];
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

      final answersRaw = List<dynamic>.from(args['answers'] ?? <dynamic>[]);
      final questionsRaw =
      List<dynamic>.from(args['questions'] ?? <dynamic>[]);

      localAnswers = answersRaw.map((e) => e.toString()).toList();
      localQuestions = questionsRaw.map((e) => e.toString()).toList();

      final Timestamp? ts = args['createdAt'] as Timestamp?;
      localSolvedAt = ts?.toDate();

      localAnalysis = args['aiAnalysis']?.toString() ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Sonucu Detayı'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
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
                'Çözülme tarihi: $localSolvedAt',
                style: const TextStyle(color: Colors.grey),
              ),

            const SizedBox(height: 16),

            // AI ANALİZİ
            if (localAnalysis.isNotEmpty)
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
                      Text(
                        localAnalysis,
                        style: const TextStyle(fontSize: 14),
                      ),
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

            // SORU + CEVAP LİSTESİ
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: localAnswers.length,
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
                        // Soru
                        Text(
                          'Soru ${index + 1}: $soru',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Cevap
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
