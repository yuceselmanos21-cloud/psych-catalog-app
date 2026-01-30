import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_test_repository.dart';
import '../services/analytics_service.dart';
import '../widgets/empty_state_widget.dart';

class SolvedTestsScreen extends StatefulWidget {
  const SolvedTestsScreen({super.key});

  @override
  State<SolvedTestsScreen> createState() => _SolvedTestsScreenState();
}

class _SolvedTestsScreenState extends State<SolvedTestsScreen> {
  String _searchQuery = '';
  String _displaySearchQuery = ''; // ✅ PERFORMANCE: Debounced search query
  Timer? _debounceTimer;

  static String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _displaySearchQuery = value.toLowerCase().trim();
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // ✅ Analytics: Screen view tracking
    AnalyticsService.logScreenView('solved_tests');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final testRepo = FirestoreTestRepository();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Önce giriş yapmalısın.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çözdüğüm Testler'),
      ),
      body: Column(
        children: [
          // Arama Barı
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _onSearchChanged(value);
              },
              decoration: InputDecoration(
                hintText: 'Test ara...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: testRepo.watchSolvedTestsByUser(user.uid),
              builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return EmptyStates.error(
              message: 'Çözdüğün testler yüklenirken hata oluştu.',
              onRetry: () => setState(() {}),
            );
          }

          final data = snapshot.data;
          if (data == null || data.docs.isEmpty) {
            return EmptyStates.noSolvedTests();
          }

          // Repo tarafı sıralıyor olsa da, createdAt eksik durumlarına karşı
          // extra güvenlik için client-side sıralama bırakıyoruz.
          final allDocs = data.docs.toList();
          
          // ✅ PERFORMANCE: Arama filtresi (debounced)
          final filteredDocs = _displaySearchQuery.isEmpty
              ? allDocs
              : allDocs.where((doc) {
                  final d = doc.data();
                  final title = d['testTitle']?.toString().toLowerCase() ?? '';
                  return title.contains(_displaySearchQuery);
                }).toList();
          
          filteredDocs.sort((a, b) {
            final aTs = a.data()['createdAt'] as Timestamp?;
            final bTs = b.data()['createdAt'] as Timestamp?;
            final aTime =
                aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          if (filteredDocs.isEmpty) {
            return Center(
              child: Text(
                _displaySearchQuery.isEmpty ? 'Henüz çözülmüş test yok.' : 'Arama sonucu bulunamadı.',
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
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
          ),
        ],
      ),
    );
  }
}
