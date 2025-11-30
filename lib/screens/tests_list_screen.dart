import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TestsListScreen extends StatelessWidget {
  const TestsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Testler')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Henüz test yok.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final title = data['title']?.toString() ?? 'Başlıksız test';
              final description = data['description']?.toString() ?? '';
              final answerType = data['answerType']?.toString() ?? 'text';
              final questions =
              (data['questions'] as List<dynamic>? ?? const []).toList();

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) Text(description),
                      Text(
                        'Soru sayısı: ${questions.length} • Cevap tipi: ${answerType == 'scale' ? '1–5 Skala' : 'Yazılı'}',
                        style:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/solveTest',
                      arguments: {
                        'id': doc.id,
                        'title': title,
                        'description': description,
                        'answerType': answerType,
                        'questions': questions,
                      },
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
}
