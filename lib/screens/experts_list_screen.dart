import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpertsListScreen extends StatelessWidget {
  const ExpertsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uzmanları Keşfet')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'expert')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Uzmanlar yüklenirken hata oluştu.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text('Henüz kayıtlı uzman yok.'),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'İsimsiz';
              final email = data['email'] ?? '';
              final spec = data['specialization'] ?? '';
              final city = data['city'] ?? '';

              final subtitleParts = <String>[];
              if (spec.toString().isNotEmpty) subtitleParts.add(spec);
              if (city.toString().isNotEmpty) subtitleParts.add(city);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (subtitleParts.isNotEmpty)
                        Text(subtitleParts.join(' • ')),
                      if (email.toString().isNotEmpty)
                        Text(
                          email,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
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
