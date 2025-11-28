import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpertTestListScreen extends StatelessWidget {
  const ExpertTestListScreen({super.key});

  Future<List<Map<String, dynamic>>> _loadTests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final snap = await FirebaseFirestore.instance
          .collection('tests')
          .where('createdBy', isEqualTo: user.uid)
      // .orderBy('createdAt', descending: true)  // ŞİMDİLİK KALDIRDIK
          .get();

      return snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Testler yüklenirken hata oluştu: $e');
    }
  }

  Future<void> _deleteTest(String id) async {
    await FirebaseFirestore.instance.collection('tests').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Oluşturduğum Testler"),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadTests(),
        builder: (context, snapshot) {
          // 1) Yükleniyor
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2) Hata
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Hata: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Veri bulunamadı.'));
          }

          final tests = snapshot.data!;
          if (tests.isEmpty) {
            return const Center(
              child: Text("Henüz test oluşturmadınız."),
            );
          }

          // 3) Liste
          return ListView.builder(
            itemCount: tests.length,
            itemBuilder: (context, i) {
              final test = tests[i];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(test['title'] ?? 'Başlık yok'),
                  subtitle: Text(
                    (test['description'] ?? 'Açıklama yok.').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/expertTestDetail',
                      arguments: test['id'],  // az önce eklediğimiz id
                    );
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await _deleteTest(test['id']);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Test silindi")),
                      );
                      (context as Element).reassemble();
                    },
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
