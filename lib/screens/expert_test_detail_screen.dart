import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExpertTestDetailScreen extends StatelessWidget {
  final String testId;

  const ExpertTestDetailScreen({super.key, required this.testId});

  @override
  Widget build(BuildContext context) {
    final docRef =
    FirebaseFirestore.instance.collection('tests').doc(testId);

    return Scaffold(
      appBar: AppBar(title: const Text('Test Detayı')),
      body: FutureBuilder<DocumentSnapshot>(
        future: docRef.get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Test bulunamadı.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final title = data['title']?.toString() ?? '';
          final description = data['description']?.toString() ?? '';
          final questions =
          (data['questions'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
          final answerType = data['answerType']?.toString() ?? 'scale';

          return SingleChildScrollView(
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
                if (description.isNotEmpty) ...[
                  Text(description),
                  const SizedBox(height: 16),
                ],
                Text(
                  answerType == 'scale'
                      ? 'Cevap tipi: 1–5 ölçek'
                      : 'Cevap tipi: Metin',
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
                for (var i = 0; i < questions.length; i++)
                  ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(questions[i]),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
