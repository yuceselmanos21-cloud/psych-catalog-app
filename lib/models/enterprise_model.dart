import 'package:cloud_firestore/cloud_firestore.dart';

/// Kurumsal hesap modeli
class EnterpriseAccount {
  final String id;
  final String companyName;
  final String email;
  final String? logoUrl;
  final List<String> adminUserIds;
  final List<String> memberUserIds;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  EnterpriseAccount({
    required this.id,
    required this.companyName,
    required this.email,
    this.logoUrl,
    required this.adminUserIds,
    required this.memberUserIds,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EnterpriseAccount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EnterpriseAccount(
      id: doc.id,
      companyName: data['companyName'] ?? '',
      email: data['email'] ?? '',
      logoUrl: data['logoUrl'],
      adminUserIds: List<String>.from(data['adminUserIds'] ?? []),
      memberUserIds: List<String>.from(data['memberUserIds'] ?? []),
      settings: Map<String, dynamic>.from(data['settings'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyName': companyName,
      'email': email,
      'logoUrl': logoUrl,
      'adminUserIds': adminUserIds,
      'memberUserIds': memberUserIds,
      'settings': settings,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
