import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TestsListScreen extends StatelessWidget {
  const TestsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Devam etmek için lütfen giriş yapın.')),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('tests')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Tüm Testler')),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Testler yüklenirken hata oluştu.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Henüz test yok.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title']?.toString() ?? 'Başlıksız test';
              final description = data['description']?.toString() ?? '';
              final answerType = data['answerType']?.toString() ?? 'scale';
              final createdByName = data['createdByName']?.toString() ?? '';

              return ListTile(
                title: Text(title),
                subtitle: Text(
                  [
                    if (createdByName.isNotEmpty) 'Uzman: $createdByName',
                    answerType == 'scale'
                        ? 'Cevap tipi: 1–5 ölçek'
                        : 'Cevap tipi: Metin',
                    if (description.isNotEmpty) description,
                  ].join(' • '),
                ),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/solveTest',
                    arguments: {
                      'id': doc.id,
                      'title': title,
                      'description': description,
                      'questions': data['questions'] ?? [],
                      'answerType': answerType,
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
