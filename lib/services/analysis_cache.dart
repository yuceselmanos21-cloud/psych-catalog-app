import 'dart:convert';

class AnalysisCache {
  // Kısa vadeli bellek cache (session boyunca)
  static final Map<String, _CacheEntry> _memory = {};

  // İstersen süreyi değiştirebilirsin
  static const Duration ttl = Duration(minutes: 10);

  static String _key(String prompt) {
    final normalized = prompt.trim().toLowerCase();
    // Basit ve stabil key üretimi (paketsiz)
    return base64Url.encode(utf8.encode(normalized));
  }

  static String? get(String prompt) {
    final k = _key(prompt);
    final entry = _memory[k];

    if (entry == null) return null;

    final age = DateTime.now().difference(entry.createdAt);
    if (age > ttl) {
      _memory.remove(k);
      return null;
    }
    return entry.value;
  }

  static void set(String prompt, String value) {
    final k = _key(prompt);
    _memory[k] = _CacheEntry(value, DateTime.now());
  }

  static void clear() => _memory.clear();
}

class _CacheEntry {
  final String value;
  final DateTime createdAt;

  _CacheEntry(this.value, this.createdAt);
}
