import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExpertTestDetailScreen extends StatelessWidget {
  final String testId;

  const ExpertTestDetailScreen({super.key, required this.testId});

  @override
  Widget build(BuildContext context) {
    final testDocRef =
    FirebaseFirestore.instance.collection('tests').doc(testId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Detayı'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: testDocRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Test bulunamadı.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final title = data['title']?.toString() ?? 'Başlıksız test';
          final description = data['description']?.toString() ?? '';
          final questions =
          (data['questions'] as List<dynamic>? ?? const []).toList();
          final answerType = data['answerType']?.toString() ?? 'text';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (description.isNotEmpty) ...[
                    Text(description),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Cevap tipi: ${answerType == 'scale' ? '1–5 Arası Skala' : 'Yazılı'}',
                    style:
                    const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sorular:',
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...questions.asMap().entries.map(
                        (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• Soru ${e.key + 1}: ${e.value}'),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Kaç kez çözülmüş bilgisi
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('solvedTests')
                        .where('testId', isEqualTo: testId)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const SizedBox.shrink();
                      }
                      final count = snap.data!.docs.length;
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
