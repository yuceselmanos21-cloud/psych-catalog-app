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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildList(Set<String> followingIds) {
      return StreamBuilder<QuerySnapshot>(
        stream: expertsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 64,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz uzman kaydı yok',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final allDocs = snapshot.data!.docs;

          final filtered = allDocs.where((doc) {
            final data =
                doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
            return _matchesSearch(data);
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aramana uygun uzman bulunamadı',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
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
                      '/publicExpertProfile',
                      arguments: expertId,
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (isFollowing)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.deepPurple.shade800
                                            : Colors.deepPurple.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Takip ediliyor',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.deepPurple.shade200
                                              : Colors.deepPurple,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (profession.isNotEmpty)
                                Text(
                                  profession,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    city,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              if (specialties.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: specialties
                                      .split(',')
                                      .take(2)
                                      .map((spec) => Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.deepPurple.shade900.withOpacity(0.3)
                                                  : Colors.deepPurple.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.deepPurple.shade700
                                                    : Colors.deepPurple.shade200,
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              spec.trim(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? Colors.deepPurple.shade200
                                                    : Colors.deepPurple.shade700,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Uzman ara (isim, şehir, alan...)',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
