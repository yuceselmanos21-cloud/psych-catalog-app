import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExpertsListScreen extends StatelessWidget {
  const ExpertsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expertsQuery = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'expert');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uzmanlar'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: expertsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Uzmanlar yüklenirken hata oluştu.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Kayıtlı uzman bulunamadı.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final name = data['name']?.toString() ?? 'İsimsiz';
              final city = data['city']?.toString() ?? 'Şehir belirtilmemiş';
              final profession =
                  data['profession']?.toString() ?? 'Meslek belirtilmemiş';
              final specialization =
                  data['specialization']?.toString() ?? 'Uzmanlık belirtilmemiş';

              return ListTile(
                title: Text(name),
                subtitle: Text('$profession • $specialization\n$city'),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
