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
        body: Center(child: Text('Önce giriş yapmalısın.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çözdüğüm Testler'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('solvedTests')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Henüz çözülmüş test yok.'));
          }

          final docs = snapshot.data!.docs.toList();

          // createdAt'e göre son çözülen en üstte olacak şekilde sırala
          docs.sort((a, b) {
            final aTs = a['createdAt'] as Timestamp?;
            final bTs = b['createdAt'] as Timestamp?;
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
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final title = data['testTitle']?.toString() ?? 'Test';
              final ts = data['createdAt'] as Timestamp?;
              final solvedAt = ts?.toDate();
              final hasAi =
              (data['aiAnalysis']?.toString().trim().isNotEmpty ?? false);

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
                          style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      Text(
                        hasAi
                            ? 'AI yorumu kayıtlı'
                            : 'AI yorumu bulunmuyor',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasAi ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
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

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
