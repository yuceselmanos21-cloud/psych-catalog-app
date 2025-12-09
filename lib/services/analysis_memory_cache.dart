class AnalysisMemoryCache {
  static const Duration ttl = Duration(minutes: 10);

  static final Map<String, _Entry> _cache = {};

  static String _normalize(String s) => s.trim();

  static String? get(String prompt) {
    final key = _normalize(prompt);
    final entry = _cache[key];
    if (entry == null) return null;

    final isExpired = DateTime.now().difference(entry.createdAt) > ttl;
    if (isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.value;
  }

  static void set(String prompt, String value) {
    final key = _normalize(prompt);
    _cache[key] = _Entry(value, DateTime.now());
  }

  static void clear() => _cache.clear();
}

class _Entry {
  final String value;
  final DateTime createdAt;

  _Entry(this.value, this.createdAt);
}
