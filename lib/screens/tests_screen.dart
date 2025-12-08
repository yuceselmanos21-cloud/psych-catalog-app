import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_test_repository.dart';

class TestsScreen extends StatelessWidget {
  const TestsScreen({super.key});

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
    final testRepo = FirestoreTestRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tüm Testler'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: testRepo.watchAllTests(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Testler yüklenirken hata oluştu.'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Henüz test bulunmuyor.'));
          }

          final docs = snapshot.data!.docs.toList();

          docs.sort((a, b) {
            final aTs = a.data()['createdAt'] as Timestamp?;
            final bTs = b.data()['createdAt'] as Timestamp?;
            final aTime =
                aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final title = data['title']?.toString() ?? 'İsimsiz Test';
              final description =
                  data['description']?.toString() ?? 'Açıklama yok';
              final answerType = data['answerType']?.toString() ?? 'scale';

              final questions = _normalizeQuestions(data['questions']);

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
