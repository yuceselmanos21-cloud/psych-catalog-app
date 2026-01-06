import 'package:cloud_firestore/cloud_firestore.dart';

/// Cache for expert lists to reduce Firestore reads
class ExpertCache {
  static const Duration ttl = Duration(minutes: 5);
  static final Map<String, _ExpertCacheEntry> _cache = {};

  static List<DocumentSnapshot>? get(String? city) {
    final key = city ?? 'no_city';
    final entry = _cache[key];
    
    if (entry == null) return null;
    
    final age = DateTime.now().difference(entry.createdAt);
    if (age > ttl) {
      _cache.remove(key);
      return null;
    }
    
    return entry.experts;
  }

  static void set(String? city, List<DocumentSnapshot> experts) {
    final key = city ?? 'no_city';
    _cache[key] = _ExpertCacheEntry(experts, DateTime.now());
  }

  static void clear() {
    _cache.clear();
  }

  static void clearCity(String? city) {
    final key = city ?? 'no_city';
    _cache.remove(key);
  }
}

class _ExpertCacheEntry {
  final List<DocumentSnapshot> experts;
  final DateTime createdAt;

  _ExpertCacheEntry(this.experts, this.createdAt);
}

