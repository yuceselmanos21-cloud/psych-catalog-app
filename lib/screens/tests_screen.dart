import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TestsScreen extends StatelessWidget {
  const TestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tüm Testler'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Testler yüklenirken hata oluştu.'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('Henüz test bulunmuyor.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};

              final title = data['title']?.toString() ?? 'İsimsiz Test';
              final description =
                  data['description']?.toString() ?? 'Açıklama yok';
              final answerType = data['answerType']?.toString() ?? 'scale';
              final questions = List<String>.from(data['questions'] ?? []);

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(title),
                  subtitle: Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
