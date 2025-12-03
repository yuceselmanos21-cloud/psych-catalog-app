import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExpertPublicProfileScreen extends StatelessWidget {
  final String expertId;

  const ExpertPublicProfileScreen({
    super.key,
    required this.expertId,
  });

  @override
  Widget build(BuildContext context) {
    final userRef =
    FirebaseFirestore.instance.collection('users').doc(expertId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uzman Profili'),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: userRef.get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Uzman bulunamadı.'));
          }

          final data = snap.data!.data() ?? <String, dynamic>{};

          // Bu kişi gerçekten uzman mı?
          if ((data['role'] ?? 'client') != 'expert') {
            return const Center(
              child: Text('Bu kullanıcı uzman değil.'),
            );
          }

          final name = data['name']?.toString() ?? 'Uzman';
          final city = data['city']?.toString() ?? 'Belirtilmemiş';
          final profession = data['profession']?.toString() ?? 'Belirtilmemiş';
          final specialties =
              data['specialties']?.toString() ?? 'Belirtilmemiş';
          final about =
              data['about']?.toString() ?? 'Henüz bilgi eklenmemiş.';
          final photoUrl = data['photoUrl']?.toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------- PROFİL ÜST KISIM ----------------
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: (photoUrl != null &&
                            photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 32),
                        )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profession,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, size: 16),
                          const SizedBox(width: 4),
                          Text(city),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ---------------- UZMANLIK & HAKKINDA ----------------
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

                const SizedBox(height: 16),

                // ---------------- YAYINLADIĞI TESTLER ----------------
                const Text(
                  'Yayınladığı Testler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('tests')
                  // CreateTestScreen’de kaydederken 'createdBy': user.uid kullanıyorduk
                      .where('createdBy', isEqualTo: expertId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, testSnap) {
                    if (testSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
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
                        final tData =
                        testDocs[index].data() as Map<String, dynamic>;
                        final title =
                            tData['title']?.toString() ?? 'Adsız test';
                        final desc =
                            tData['description']?.toString() ?? '';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(title),
                          subtitle: Text(
                            desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // 🔥 BURASI YENİ: teste tıklayınca SolveTestScreen aç
                          onTap: () {
                            final Map<String, dynamic> testData = {
                              'id': testDocs[index].id,
                              ...tData,
                            };
                            Navigator.pushNamed(
                              context,
                              '/solveTest',
                              arguments: testData,
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ---------------- PAYLAŞIMLAR ----------------
                const Text(
                  'Paylaşımlar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('authorId', isEqualTo: expertId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, postSnap) {
                    // Hata durumu
                    if (postSnap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Paylaşımlar yüklenirken hata: ${postSnap.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    // İlk yükleme
                    if (postSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    // Veri yoksa
                    if (!postSnap.hasData ||
                        postSnap.data!.docs.isEmpty) {
                      return const Text(
                        'Bu uzmanın henüz paylaşımı yok.',
                        style: TextStyle(color: Colors.grey),
                      );
                    }

                    // Paylaşımlar listesi
                    final postDocs = postSnap.data!.docs;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: postDocs.length,
                      itemBuilder: (context, index) {
                        final pData = postDocs[index].data()
                        as Map<String, dynamic>? ??
                            {};
                        final text =
                            pData['text']?.toString() ?? '';
                        final createdTs =
                        pData['createdAt'] as Timestamp?;
                        final created = createdTs?.toDate();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                if (created != null)
                                  Text(
                                    _formatDateTime(created),
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

  static String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }
}
