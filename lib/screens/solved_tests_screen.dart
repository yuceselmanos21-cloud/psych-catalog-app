import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_test_repository.dart';

class SolvedTestsScreen extends StatelessWidget {
  const SolvedTestsScreen({super.key});

  static String _formatDateTime(DateTime dt) {
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

          final data = snapshot.data;
          if (data == null || data.docs.isEmpty) {
            return const Center(child: Text('Henüz çözülmüş test yok.'));
          }

          // Repo tarafı sıralıyor olsa da, createdAt eksik durumlarına karşı
          // extra güvenlik için client-side sıralama bırakıyoruz.
          final docs = data.docs.toList();
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
              final d = doc.data();

              final title = d['testTitle']?.toString().trim();
              final safeTitle = (title == null || title.isEmpty)
                  ? 'Test'
                  : title;

              final ts = d['createdAt'] as Timestamp?;
              final solvedAt = ts?.toDate();

              final aiText = d['aiAnalysis']?.toString() ?? '';
              final hasAi = aiText.trim().isNotEmpty;

              final isDark = Theme.of(context).brightness == Brightness.dark;
              final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
              final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 0,
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor, width: 1),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/resultDetail',
                      arguments: {
                        'testTitle': safeTitle,
                        'answers': List<dynamic>.from(d['answers'] ?? const []),
                        'questions': List<dynamic>.from(d['questions'] ?? const []),
                        'createdAt': ts,
                        'aiAnalysis': aiText,
                        'testId': d['testId']?.toString(), // Testi oluşturan uzmanı bulmak için
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                safeTitle,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (solvedAt != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Çözüldü: ${_formatDateTime(solvedAt)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Icon(
                              hasAi ? Icons.check_circle : Icons.info_outline,
                              size: 16,
                              color: hasAi
                                  ? (isDark ? Colors.green.shade300 : Colors.green)
                                  : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasAi ? 'AI yorumu kayıtlı' : 'AI yorumu bulunmuyor',
                              style: TextStyle(
                                fontSize: 13,
                                color: hasAi
                                    ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                fontWeight: hasAi ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
