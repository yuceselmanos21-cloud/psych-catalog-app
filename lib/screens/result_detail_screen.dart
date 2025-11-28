import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ResultDetailScreen extends StatelessWidget {
  const ResultDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
    ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args == null) {
      return const Scaffold(
        body: Center(child: Text('Sonuç bilgisi bulunamadı.')),
      );
    }

    final String testTitle = args['testTitle']?.toString() ?? 'Test Sonucu';
    final List<dynamic> answersRaw =
    List<dynamic>.from(args['answers'] ?? <dynamic>[]);
    final List<dynamic> questionsRaw =
    List<dynamic>.from(args['questions'] ?? <dynamic>[]);
    final Timestamp? ts = args['createdAt'] as Timestamp?;
    final String aiAnalysis = args['aiAnalysis']?.toString() ?? '';

    final DateTime? solvedAt = ts?.toDate();

    // Cevapları stringe çevir
    final answers = answersRaw.map((e) => e.toString()).toList();
    final questions = questionsRaw.map((e) => e.toString()).toList();

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
              testTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            if (solvedAt != null)
              Text(
                'Çözülme tarihi: $solvedAt',
                style: const TextStyle(color: Colors.grey),
              ),

            const SizedBox(height: 16),

            // AI ANALİZİ
            if (aiAnalysis.isNotEmpty)
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
                        aiAnalysis,
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
              'Soru ve Cevapların',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // SORU + CEVAP LİSTESİ
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: answers.length,
              itemBuilder: (context, index) {
                final soru = index < questions.length ? questions[index] : 'Soru ${index + 1}';
                final cevap = answers[index];


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
