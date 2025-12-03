import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PublicExpertProfileScreen extends StatelessWidget {
  final String expertId;

  const PublicExpertProfileScreen({super.key, required this.expertId});

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uzman Profili')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(expertId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Uzman bulunamadı.'));
          }

          final data =
              snapshot.data!.data() as Map<String, dynamic>? ?? <String, dynamic>{};

          final name = data['name']?.toString() ?? 'Uzman';
          final city = data['city']?.toString() ?? 'Belirtilmemiş';
          final profession = data['profession']?.toString() ?? 'Belirtilmemiş';
          final expertise = data['expertise']?.toString() ?? 'Belirtilmemiş';
          final about = data['about']?.toString() ?? '';
          final photoUrl = data['photoUrl']?.toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 24),
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
                          const Icon(Icons.location_on,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            city,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Card(
                  child: ListTile(
                    title: const Text('Uzmanlık Alanı'),
                    subtitle: Text(expertise),
                  ),
                ),

                if (about.isNotEmpty)
                  Card(
                    child: ListTile(
                      title: const Text('Hakkında'),
                      subtitle: Text(about),
                    ),
                  ),

                const SizedBox(height: 16),
                const Text(
                  'Yayınladığı Testler',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildExpertTestsSection(context),

                const SizedBox(height: 16),
                const Text(
                  'Paylaşımları',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildExpertPostsSection(context),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  // Uzmanın testleri
  Widget _buildExpertTestsSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tests')
          .where('expertId', isEqualTo: expertId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('Bu uzmanın yayınladığı test bulunmuyor.');
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data =
                doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

            final title = data['title']?.toString() ?? 'Test';
            final description = data['description']?.toString() ?? '';

            final testData = <String, dynamic>{
              ...data,
              'id': doc.id,
            };

            return Card(
              child: ListTile(
                title: Text(title),
                subtitle: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/solveTest',
                    arguments: testData,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // Uzmanın paylaşımları
  Widget _buildExpertPostsSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: expertId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('Bu uzmanın henüz paylaşımı yok.');
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data =
                doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

            final text = data['text']?.toString() ?? '';
            final ts = data['createdAt'] as Timestamp?;
            final dt = ts?.toDate();
            final List<dynamic> likedBy =
            List<dynamic>.from(data['likedBy'] ?? []);
            final likeCount = likedBy.length;
            final commentsCount = (data['commentsCount'] as int?) ?? 0;

            return Card(
              child: ListTile(
                title: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dt != null)
                      Text(
                        _formatDateTime(dt),
                        style:
                        const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.favorite, size: 14),
                        const SizedBox(width: 2),
                        Text('$likeCount'),
                        const SizedBox(width: 12),
                        const Icon(Icons.comment, size: 14),
                        const SizedBox(width: 2),
                        Text('$commentsCount'),
                      ],
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/postDetail',
                    arguments: doc.id,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
