import 'package:cloud_firestore/cloud_firestore.dart';

/// Grup modeli
class Group {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final String? photoUrl;
  final List<String> members;
  final List<String> moderators;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    this.photoUrl,
    required this.members,
    required this.moderators,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Group.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      createdBy: data['createdBy'] ?? '',
      photoUrl: data['photoUrl'],
      members: List<String>.from(data['members'] ?? []),
      moderators: List<String>.from(data['moderators'] ?? []),
      isPublic: data['isPublic'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'photoUrl': photoUrl,
      'members': members,
      'moderators': moderators,
      'isPublic': isPublic,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
