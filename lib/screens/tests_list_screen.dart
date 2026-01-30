import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_test_repository.dart';
import '../widgets/empty_state_widget.dart';

class TestsListScreen extends StatefulWidget {
  const TestsListScreen({super.key});

  @override
  State<TestsListScreen> createState() => _TestsListScreenState();
}

class _TestsListScreenState extends State<TestsListScreen> {
  final _testRepo = FirestoreTestRepository();

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final txt = _searchCtrl.text.toLowerCase();
      if (txt == _searchText) return;
      setState(() {
        _searchText = txt;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }

  Widget _buildAnswerTypeChip(String answerType, bool isDark) {
    String label;
    IconData icon;
    Color bg;
    Color fg;

    if (answerType == 'scale') {
      label = '1-5 arası puanlama';
      icon = Icons.format_list_numbered;
      bg = isDark ? Colors.deepPurple.shade900.withOpacity(0.3) : Colors.deepPurple.shade50;
      fg = Colors.deepPurple;
    } else {
      label = 'Serbest metin';
      icon = Icons.text_fields;
      bg = isDark ? Colors.blueGrey.shade900.withOpacity(0.3) : Colors.blueGrey.shade50;
      fg = Colors.blueGrey;
    }

    return Chip(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      labelPadding: const EdgeInsets.only(left: 4, right: 4),
      avatar: Icon(icon, size: 16, color: fg),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: fg),
      ),
      backgroundColor: bg,
      side: BorderSide(color: fg.withOpacity(0.4)),
    );
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchText.isEmpty) return true;

    final title = data['title']?.toString().toLowerCase() ?? '';
    final description = data['description']?.toString().toLowerCase() ?? '';
    final expertName = data['expertName']?.toString().toLowerCase() ?? '';

    return title.contains(_searchText) ||
        description.contains(_searchText) ||
        expertName.contains(_searchText);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Testler'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Test ara (başlık / açıklama / uzman)...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 4),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _testRepo.watchAllTests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return EmptyStates.error(
                    message: 'Testler yüklenirken hata oluştu.',
                    onRetry: () => setState(() {}),
                  );
                }

                if (!snapshot.hasData || snapshot.data == null) {
                  return EmptyStates.noTests();
                }

                final allDocs = snapshot.data!.docs;

                if (allDocs.isEmpty) {
                  return EmptyStates.noTests();
                }

                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data();
                  return _matchesSearch(data);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return EmptyStates.noSearchResults();
                }

                // ✅ küçük stabilite: tarih sırası garanti
                filteredDocs.sort((a, b) {
                  final aTs = a.data()['createdAt'] as Timestamp?;
                  final bTs = b.data()['createdAt'] as Timestamp?;
                  final aTime =
                      aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime =
                      bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data();

                    final String title =
                        data['title']?.toString() ?? 'Başlıksız test';
                    final String description =
                        data['description']?.toString() ?? '';
                    final String expertName =
                        data['expertName']?.toString() ?? 'Uzman';
                    final String answerType =
                        data['answerType']?.toString() ?? 'text';

                    final Timestamp? ts = data['createdAt'] as Timestamp?;
                    final String dateStr = _formatDate(ts);

                    // ✅ SolveTestScreen'e tam veri veriyoruz (eski davranışı bozmaz)
                    final Map<String, dynamic> test = {
                      'id': doc.id,
                      ...data,
                      'answerType': answerType,
                    };

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/solveTest',
                            arguments: test,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (dateStr.isNotEmpty)
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              if (description.isNotEmpty)
                                Text(
                                  description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),

                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Uzman: $expertName',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  _buildAnswerTypeChip(answerType, isDark),
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
