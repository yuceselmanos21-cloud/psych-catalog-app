import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_test_repository.dart';

class SolvedTestsScreen extends StatelessWidget {
  const SolvedTestsScreen({super.key});

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final testRepo = FirestoreTestRepository();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Önce giriş yapmalısın.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çözdüğüm Testler'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // ✅ Firestore çağrısı ekrandan kalktı
        stream: testRepo.watchSolvedTestsByUser(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Çözdüğün testler yüklenirken hata oluştu.'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Henüz çözülmüş test yok.'));
          }

          final docs = snapshot.data!.docs.toList();

          // ✅ Ekstra güvenlik: createdAt eksikse bile sıralama bozulmasın
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

              final title = data['testTitle']?.toString() ?? 'Test';
              final ts = data['createdAt'] as Timestamp?;
              final solvedAt = ts?.toDate();

              final aiText = data['aiAnalysis']?.toString() ?? '';
              final hasAi = aiText.trim().isNotEmpty;

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (solvedAt != null)
                        Text(
                          'Çözüldü: ${_formatDateTime(solvedAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      Text(
                        hasAi ? 'AI yorumu kayıtlı' : 'AI yorumu bulunmuyor',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasAi ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/resultDetail',
                      arguments: {
                        'testTitle': title,
                        'answers':
                        List<dynamic>.from(data['answers'] ?? const []),
                        'questions':
                        List<dynamic>.from(data['questions'] ?? const []),
                        'createdAt': ts,
                        'aiAnalysis': aiText,
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
