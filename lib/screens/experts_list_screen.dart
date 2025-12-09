import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ExpertsListScreen extends StatefulWidget {
  const ExpertsListScreen({super.key});

  @override
  State<ExpertsListScreen> createState() => _ExpertsListScreenState();
}

class _ExpertsListScreenState extends State<ExpertsListScreen> {
  String _search = '';

  Stream<Set<String>> _watchFollowingIds(String currentUserId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_search.isEmpty) return true;

    final name = (data['name'] ?? '').toString().toLowerCase();
    final city = (data['city'] ?? '').toString().toLowerCase();
    final profession = (data['profession'] ?? '').toString().toLowerCase();
    final specialties = (data['specialties'] ?? '').toString().toLowerCase();

    return name.contains(_search) ||
        city.contains(_search) ||
        profession.contains(_search) ||
        specialties.contains(_search);
  }

  @override
  Widget build(BuildContext context) {
    final expertsQuery = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'expert');

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    Widget buildList(Set<String> followingIds) {
      return StreamBuilder<QuerySnapshot>(
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
            return _matchesSearch(data);
          }).toList();

          if (filtered.isEmpty) {
            return const Center(
              child: Text('Aramana uygun uzman bulunamadı.'),
            );
          }

          // ✅ Takip edilenleri üste al + isimle stabil sırala
          filtered.sort((a, b) {
            final aFollowed = followingIds.contains(a.id);
            final bFollowed = followingIds.contains(b.id);

            if (aFollowed != bFollowed) {
              return aFollowed ? -1 : 1;
            }

            final aName = ((a.data() as Map?)?['name'] ?? '')
                .toString()
                .toLowerCase();
            final bName = ((b.data() as Map?)?['name'] ?? '')
                .toString()
                .toLowerCase();

            return aName.compareTo(bName);
          });

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final doc = filtered[index];
              final data =
                  doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

              final expertId = doc.id;
              final name = data['name']?.toString() ?? 'Uzman';
              final city = data['city']?.toString() ?? 'Belirtilmemiş';
              final profession =
                  data['profession']?.toString() ?? 'Meslek belirtilmemiş';
              final specialties = data['specialties']?.toString() ?? '';
              final photoUrl = data['photoUrl']?.toString();

              final isFollowing = followingIds.contains(expertId);

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                        : null,
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(name)),
                      if (isFollowing)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Takip ediliyor',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
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
      );
    }

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
            child: currentUserId == null
                ? buildList(<String>{})
                : StreamBuilder<Set<String>>(
              stream: _watchFollowingIds(currentUserId),
              builder: (context, snap) {
                final followingIds = snap.data ?? <String>{};
                return buildList(followingIds);
              },
            ),
          ),
        ],
      ),
    );
  }
}
