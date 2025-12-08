import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExpertsListScreen extends StatefulWidget {
  const ExpertsListScreen({super.key});

  @override
  State<ExpertsListScreen> createState() => _ExpertsListScreenState();
}

class _ExpertsListScreenState extends State<ExpertsListScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final expertsQuery = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'expert');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uzmanları Keşfet'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Uzman ara (isim, şehir, alan...)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _search = value.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: expertsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Henüz uzman kaydı yok.'));
                }

                final allDocs = snapshot.data!.docs;

                final filtered = allDocs.where((doc) {
                  final data =
                      doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final city = (data['city'] ?? '').toString().toLowerCase();
                  final profession =
                  (data['profession'] ?? '').toString().toLowerCase();
                  final specialties =
                  (data['specialties'] ?? '').toString().toLowerCase();

                  if (_search.isEmpty) return true;

                  return name.contains(_search) ||
                      city.contains(_search) ||
                      profession.contains(_search) ||
                      specialties.contains(_search);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Aramana uygun uzman bulunamadı.'),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data =
                        doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

                    final expertId = doc.id;
                    final name = data['name']?.toString() ?? 'Uzman';
                    final city = data['city']?.toString() ?? 'Belirtilmemiş';
                    final profession = data['profession']?.toString() ??
                        'Meslek belirtilmemiş';
                    final specialties = data['specialties']?.toString() ?? '';
                    final photoUrl = data['photoUrl']?.toString();

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                          (photoUrl != null && photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                              : null,
                        ),
                        title: Text(name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profession, style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(city, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            if (specialties.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  specialties,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/publicExpertProfile',
                            arguments: expertId,
                          );
                        },
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
