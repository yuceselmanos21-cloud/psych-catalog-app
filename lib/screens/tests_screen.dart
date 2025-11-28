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
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title']?.toString() ?? 'Başlıksız';
              final desc = data['description']?.toString() ?? '';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (desc.isNotEmpty)
                        Text(
                          desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (createdAt != null)
                        Text(
                          'Oluşturulma: $createdAt',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/solveTest',
                      arguments: {
                        'id': doc.id,
                        'title': title,
                        'description': desc,
                        'questions': data['questions'] ?? <dynamic>[],
                        'answerType': data['answerType'] ?? 'scale', // <-- EKLEDİK
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
