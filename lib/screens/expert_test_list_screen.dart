import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_test_repository.dart';

class ExpertTestListScreen extends StatelessWidget {
  const ExpertTestListScreen({super.key});

  String _answerTypeLabel(String answerType) {
    return answerType == 'scale' ? '1–5 Skala' : 'Yazılı';
  }

  int _questionsLength(dynamic raw) {
    if (raw is List) return raw.length;
    return 0;
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
        title: const Text('Oluşturduğum Testler'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // ✅ Firestore çağrısı ekrandan kalktı
        stream: testRepo.watchTestsByCreator(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Testler yüklenirken hata oluştu.'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Henüz test oluşturmadın.'));
          }

          // ✅ Güvenli sıralama (repo zaten orderBy yapıyorsa da sorun değil)
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

              final title = data['title']?.toString() ?? 'Başlıksız test';
              final description = data['description']?.toString() ?? '';
              final answerType = data['answerType']?.toString() ?? 'text';
              final qLen = _questionsLength(data['questions']);

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Soru sayısı: $qLen • Cevap tipi: ${_answerTypeLabel(answerType)}',
                        style:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/expertTestDetail',
                      arguments: doc.id, // ✅ eski davranış korunuyor
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
