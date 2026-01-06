import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/mention_parser.dart';

/// @mention autocomplete widget'ı
/// TextField'ın üzerinde kullanıcı önerileri gösterir
class MentionAutocomplete extends StatelessWidget {
  final String query;
  final Function(String userId, String username) onSelect;
  final int? mentionStartPosition;

  const MentionAutocomplete({
    super.key,
    required this.query,
    required this.onSelect,
    this.mentionStartPosition,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final users = snapshot.data!.docs;

        return Card(
          elevation: 8,
          color: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: 1),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final data = user.data() as Map<String, dynamic>;
                final username = data['username']?.toString() ?? '';
                final name = data['name']?.toString() ?? 'Kullanıcı';
                final photoUrl = data['photoUrl']?.toString();

                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: isDark
                        ? Colors.deepPurple.shade800
                        : Colors.deepPurple.shade50,
                    backgroundImage:
                        photoUrl != null && photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                    child: photoUrl == null || photoUrl.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.deepPurple.shade200
                                  : Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '@$username',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => onSelect(user.id, username),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

