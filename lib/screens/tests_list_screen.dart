import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TestsListScreen extends StatefulWidget {
  const TestsListScreen({super.key});

  @override
  State<TestsListScreen> createState() => _TestsListScreenState();
}

class _TestsListScreenState extends State<TestsListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchText = _searchCtrl.text.toLowerCase();
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

  /// Cevap tipini (answerType) ekranda güzel gösterelim
  Widget _buildAnswerTypeChip(String answerType) {
    String label;
    IconData icon;
    Color bg;
    Color fg;

    if (answerType == 'scale') {
      label = '1-5 arası puanlama';
      icon = Icons.format_list_numbered;
      bg = Colors.deepPurple.shade50;
      fg = Colors.deepPurple;
    } else {
      // varsayılan: text
      label = 'Serbest metin';
      icon = Icons.text_fields;
      bg = Colors.blueGrey.shade50;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Testler'),
      ),
      body: Column(
        children: [
          // Arama kutusu
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tests')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Testler yüklenirken hata oluştu.'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Text('Henüz hiç test yok.'),
                  );
                }

                final allDocs = snapshot.data!.docs;

                // 🔍 Arama filtresi (başlık + açıklama + uzman adı)
                final filteredDocs = allDocs.where((doc) {
                  if (_searchText.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final title = data['title']?.toString().toLowerCase() ?? '';
                  final description =
                      data['description']?.toString().toLowerCase() ?? '';
                  final expertName =
                      data['expertName']?.toString().toLowerCase() ?? '';
                  return title.contains(_searchText) ||
                      description.contains(_searchText) ||
                      expertName.contains(_searchText);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text('Aramaya uygun test bulunamadı.'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>? ?? {};

                    final String title =
                        data['title']?.toString() ?? 'Başlıksız test';
                    final String description =
                        data['description']?.toString() ?? '';
                    final String expertName =
                        data['expertName']?.toString() ?? 'Uzman';
                    final String answerType =
                        data['answerType']?.toString() ?? 'text';
                    final Timestamp? ts =
                    data['createdAt'] as Timestamp?;
                    final String dateStr = _formatDate(ts);

                    // SolveTestScreen'e gönderilecek map –
                    // önceki davranışı bozmayalım:
                    final Map<String, dynamic> test = {
                      'id': doc.id,
                      ...data,
                    };

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
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
                              // Üst satır: Başlık + tarih
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

                              // Uzman adı + cevap tipi chip’i
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Uzman: $expertName',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  _buildAnswerTypeChip(answerType),
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
