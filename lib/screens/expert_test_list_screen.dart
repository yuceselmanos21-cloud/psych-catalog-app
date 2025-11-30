import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'expert_test_detail_screen.dart';

class ExpertTestListScreen extends StatelessWidget {
  const ExpertTestListScreen({super.key});

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
        .where('createdBy', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    Future<void> deleteTest(String testId) async {
      await FirebaseFirestore.instance.collection('tests').doc(testId).delete();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Oluşturduğum Testler')),
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
            return const Center(child: Text('Henüz test oluşturmamışsınız.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title']?.toString() ?? 'Başlıksız test';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

              return ListTile(
                title: Text(title),
                subtitle: createdAt != null
                    ? Text('Oluşturulma: $createdAt')
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Testi sil'),
                        content: const Text(
                            'Bu testi silmek istediğinizden emin misiniz?'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(false),
                            child: const Text('Vazgeç'),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(true),
                            child: const Text('Sil'),
                          ),
                        ],
                      ),
                    ) ??
                        false;
                    if (ok) {
                      await deleteTest(doc.id);
                    }
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExpertTestDetailScreen(testId: doc.id),
                    ),
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
