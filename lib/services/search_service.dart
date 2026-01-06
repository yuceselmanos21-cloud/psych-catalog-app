import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';

class SearchService {
  static String get _baseUrl {
    // ✅ Environment variable'dan al, yoksa default kullan
    const apiUrl = String.fromEnvironment('API_URL');
    if (apiUrl.isNotEmpty) return '$apiUrl/api';
    return 'http://localhost:3000/api';
  }
  
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Gönderi araması yapar
  /// 
  /// [query] - Arama metni
  /// [limit] - Sonuç sayısı (varsayılan: 20, maksimum: 50)
  /// [lastDocId] - Pagination için son doküman ID'si
  Future<SearchPostsResult> searchPosts({
    required String query,
    int limit = 20,
    String? lastDocId,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/search/posts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'query': query,
          'limit': limit,
          if (lastDocId != null) 'lastDocId': lastDocId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final postsList = data['posts'] as List<dynamic>;
        final posts = postsList.map((p) => Post.fromJson(p)).toList();
        
        return SearchPostsResult(
          posts: posts,
          hasMore: data['hasMore'] as bool? ?? false,
          totalResults: data['totalResults'] as int? ?? posts.length,
        );
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Search failed');
      }
    } catch (e) {
      throw Exception('Search error: ${e.toString()}');
    }
  }

  /// Kullanıcı araması yapar
  /// 
  /// [query] - Arama metni (opsiyonel)
  /// [role] - Kullanıcı rolü ('expert' | 'client' | null)
  /// [profession] - Meslek filtresi
  /// [expertise] - Uzmanlık alanı
  /// [limit] - Sonuç sayısı (varsayılan: 20, maksimum: 50)
  /// [lastDocId] - Pagination için son doküman ID'si
  Future<SearchUsersResult> searchUsers({
    String? query,
    String? role,
    String? profession,
    String? expertise,
    int limit = 20,
    String? lastDocId,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      final body = <String, dynamic>{
        'limit': limit,
      };
      
      if (query != null && query.isNotEmpty) {
        body['query'] = query;
      }
      if (role != null) {
        body['role'] = role;
      }
      if (profession != null && profession != 'all') {
        body['profession'] = profession;
      }
      if (expertise != null && expertise.isNotEmpty) {
        body['expertise'] = expertise;
      }
      if (lastDocId != null) {
        body['lastDocId'] = lastDocId;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/search/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final usersList = data['users'] as List<dynamic>;
        
        return SearchUsersResult(
          users: usersList.cast<Map<String, dynamic>>(),
          hasMore: data['hasMore'] as bool? ?? false,
          totalResults: data['totalResults'] as int? ?? usersList.length,
        );
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Search failed');
      }
    } catch (e) {
      throw Exception('Search error: ${e.toString()}');
    }
  }
}

class SearchPostsResult {
  final List<Post> posts;
  final bool hasMore;
  final int totalResults;

  SearchPostsResult({
    required this.posts,
    required this.hasMore,
    required this.totalResults,
  });
}

class SearchUsersResult {
  final List<Map<String, dynamic>> users;
  final bool hasMore;
  final int totalResults;

  SearchUsersResult({
    required this.users,
    required this.hasMore,
    required this.totalResults,
  });
}

/// Keşfet feed servisi
class DiscoverService {
  static String get _baseUrl {
    // ✅ Environment variable'dan al, yoksa default kullan
    const apiUrl = String.fromEnvironment('API_URL');
    if (apiUrl.isNotEmpty) return '$apiUrl/api';
    return 'http://localhost:3000/api';
  }
  
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Akıllı keşfet feed'i getirir
  /// 
  /// [limit] - Sonuç sayısı (varsayılan: 20, maksimum: 50)
  /// [lastDocId] - Pagination için son doküman ID'si
  Future<DiscoverFeedResult> getDiscoverFeed({
    int limit = 20,
    String? lastDocId,
  }) async {
    try {
      final token = await _getIdToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/discover/feed'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'limit': limit,
          if (lastDocId != null) 'lastDocId': lastDocId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final postsList = data['posts'] as List<dynamic>;
        final posts = postsList.map((p) => Post.fromJson(p)).toList();
        
        return DiscoverFeedResult(
          posts: posts,
          hasMore: data['hasMore'] as bool? ?? false,
          totalResults: data['totalResults'] as int? ?? posts.length,
        );
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Discover feed failed');
      }
    } catch (e) {
      throw Exception('Discover feed error: ${e.toString()}');
    }
  }
}

class DiscoverFeedResult {
  final List<Post> posts;
  final bool hasMore;
  final int totalResults;

  DiscoverFeedResult({
    required this.posts,
    required this.hasMore,
    required this.totalResults,
  });
}

