import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpertTestDetailScreen extends StatelessWidget {
  const ExpertTestDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // main.dart üzerinden Navigator.pushNamed ile
    // gönderdiğimiz testId burada arguments olarak geliyor
    final testId = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Test Detayı"),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('tests')
            .doc(testId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Hata: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Test bulunamadı."));
          }

          final data = snapshot.data!.data()!;
          final title = data['title']?.toString() ?? 'Başlık yok';
          final description = data['description']?.toString() ?? '';
          final questionsDynamic = (data['questions'] ?? []) as List<dynamic>;
          final questions = questionsDynamic.map((e) => e.toString()).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: const TextStyle(fontSize: 16),
                  ),
                if (description.isNotEmpty) const SizedBox(height: 16),
                const Text(
                  "Sorular",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (questions.isEmpty)
                  const Text("Bu test için soru bulunmuyor."),
                if (questions.isNotEmpty)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: questions.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('${index + 1}'),
                        ),
                        title: Text(questions[index]),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
