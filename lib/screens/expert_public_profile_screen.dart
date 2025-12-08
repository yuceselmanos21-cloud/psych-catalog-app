import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/firestore_post_repository.dart';
import '../repositories/firestore_test_repository.dart';
import '../repositories/firestore_follow_repository.dart';

class ExpertPublicProfileScreen extends StatelessWidget {
  final String expertId;

  const ExpertPublicProfileScreen({
    super.key,
    required this.expertId,
  });

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Widget _statItem(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userRef =
    FirebaseFirestore.instance.collection('users').doc(expertId);

    final testRepo = FirestoreTestRepository();
    final postRepo = FirestorePostRepository();
    final followRepo = FirestoreFollowRepository();

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final canFollow = currentUserId != null && currentUserId != expertId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uzman Profili'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Uzman bulunamadı.'));
          }

          final data = snap.data!.data() ?? <String, dynamic>{};

          if ((data['role'] ?? 'client') != 'expert') {
            return const Center(child: Text('Bu kullanıcı uzman değil.'));
          }

          final name = data['name']?.toString() ?? 'Uzman';
          final city = data['city']?.toString() ?? 'Belirtilmemiş';
          final profession = data['profession']?.toString() ?? 'Belirtilmemiş';
          final specialties = data['specialties']?.toString() ?? 'Belirtilmemiş';
          final about = data['about']?.toString() ?? 'Henüz bilgi eklenmemiş.';
          final photoUrl = data['photoUrl']?.toString();

          final followersCount = _asInt(data['followersCount']);
          final followingCount = _asInt(data['followingCount']);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------- HEADER --------
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundImage:
                        (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 32),
                        )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profession,
                        style:
                        const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, size: 16),
                          const SizedBox(width: 4),
                          Text(city),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // -------- STATS + FOLLOW BUTTON --------
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 18,
                        runSpacing: 8,
                        children: [
                          _statItem('Takipçi', followersCount),
                          _statItem('Takip', followingCount),
                          if (canFollow)
                            StreamBuilder<bool>(
                              stream: followRepo.watchIsFollowing(
                                currentUserId: currentUserId!,
                                expertId: expertId,
                              ),
                              builder: (context, followSnap) {
                                final isFollowing = followSnap.data ?? false;

                                final label =
                                isFollowing ? 'Takip Ediliyor' : 'Takip Et';
                                final icon = isFollowing
                                    ? Icons.person_remove
                                    : Icons.person_add;

                                final buttonChild = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 18),
                                    const SizedBox(width: 6),
                                    Text(label),
                                  ],
                                );

                                return isFollowing
                                    ? OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      await followRepo.toggleFollow(
                                        currentUserId: currentUserId!,
                                        expertId: expertId,
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Takip işlemi başarısız: $e'),
                                        ),
                                      );
                                    }
                                  },
                                  child: buttonChild,
                                )
                                    : ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await followRepo.toggleFollow(
                                        currentUserId: currentUserId!,
                                        expertId: expertId,
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Takip işlemi başarısız: $e'),
                                        ),
                                      );
                                    }
                                  },
                                  child: buttonChild,
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // -------- ABOUT CARD --------
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Uzmanlık Alanı',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(specialties),
                        const SizedBox(height: 12),
                        const Text(
                          'Hakkında',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(about),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // -------- TESTS --------
                const Text(
                  'Yayınladığı Testler',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: testRepo.watchTestsByCreator(expertId),
                  builder: (context, testSnap) {
                    if (testSnap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (!testSnap.hasData || testSnap.data!.docs.isEmpty) {
                      return const Text(
                        'Bu uzmanın henüz yayınladığı test yok.',
                        style: TextStyle(color: Colors.grey),
                      );
                    }

                    final testDocs = testSnap.data!.docs;

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: testDocs.length,
                      itemBuilder: (context, index) {
                        final tDoc = testDocs[index];
                        final tData = tDoc.data();

                        final title = tData['title']?.toString() ?? 'Adsız test';
                        final desc = tData['description']?.toString() ?? '';

                        final testMap = {
                          'id': tDoc.id,
                          ...tData,
                        };

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(title),
                          subtitle: desc.isEmpty
                              ? null
                              : Text(
                            desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/solveTest',
                              arguments: testMap,
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 18),

                // -------- POSTS --------
                const Text(
                  'Paylaşımlar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: postRepo.watchPostsByAuthor(expertId, limit: 10),
                  builder: (context, postSnap) {
                    if (postSnap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (postSnap.hasError) {
                      return Text(
                        'Paylaşımlar yüklenirken hata: ${postSnap.error}',
                        style: const TextStyle(color: Colors.red),
                      );
                    }

                    if (!postSnap.hasData || postSnap.data!.docs.isEmpty) {
                      return const Text(
                        'Bu uzmanın henüz paylaşımı yok.',
                        style: TextStyle(color: Colors.grey),
                      );
                    }

                    final postDocs = postSnap.data!.docs;

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: postDocs.length,
                      itemBuilder: (context, index) {
                        final pData = postDocs[index].data();
                        final text = pData['text']?.toString() ?? '';
                        final createdTs = pData['createdAt'] as Timestamp?;
                        final created = createdTs?.toDate();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (created != null)
                                  Text(
                                    _formatDate(created),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  text,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
