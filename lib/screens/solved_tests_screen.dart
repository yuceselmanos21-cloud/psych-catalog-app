import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SolvedTestsScreen extends StatelessWidget {
  const SolvedTestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Lütfen önce giriş yapın.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çözdüğüm Testler'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('test_results')
            .where('userId', isEqualTo: user.uid)
            .snapshots(), // <-- orderBy kaldırıldı
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Hata: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text('Henüz çözdüğün bir test yok.'),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['testTitle']?.toString() ?? 'Test';
              final ts = data['createdAt'] as Timestamp?;
              final dt = ts?.toDate();

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(title),
                  subtitle: dt != null
                      ? Text('Tarih: $dt')
                      : const Text('Tarih bilgisi yok'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/resultDetail',
                      arguments: {
                        'testTitle': data['testTitle'],
                        'answers': List<dynamic>.from(
                            data['answers'] ?? <dynamic>[]),
                        'questions': List<dynamic>.from(
                            data['questions'] ?? <dynamic>[]),
                        'createdAt': data['createdAt'],
                        'aiAnalysis': data['aiAnalysis'] ?? '',
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
