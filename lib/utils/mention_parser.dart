/// @mention parsing ve detection utility fonksiyonları

class MentionParser {
  /// Metinden @mention'ları bulur ve userId listesi döner
  /// Format: @username veya @userId
  static List<String> extractMentionedUserIds(String text) {
    final mentions = <String>[];
    final regex = RegExp(r'@(\w+)');
    final matches = regex.allMatches(text);
    
    for (final match in matches) {
      final mention = match.group(1) ?? '';
      if (mention.isNotEmpty) {
        mentions.add(mention);
      }
    }
    
    return mentions.toSet().toList(); // Duplicate'leri kaldır
  }

  /// Metinden @mention pattern'lerini bulur (username veya userId)
  /// Returns: List of mention strings (e.g., ['@username1', '@username2'])
  static List<String> extractMentions(String text) {
    final mentions = <String>[];
    final regex = RegExp(r'@(\w+)');
    final matches = regex.allMatches(text);
    
    for (final match in matches) {
      final fullMatch = match.group(0) ?? '';
      if (fullMatch.isNotEmpty) {
        mentions.add(fullMatch);
      }
    }
    
    return mentions.toSet().toList(); // Duplicate'leri kaldır
  }

  /// Metinde @ işareti var mı kontrol eder (autocomplete için)
  static bool hasMentionTrigger(String text, int cursorPosition) {
    if (cursorPosition == 0) return false;
    
    // Cursor'dan geriye doğru bak
    for (int i = cursorPosition - 1; i >= 0; i--) {
      final char = text[i];
      if (char == ' ') return false; // Boşluk bulundu, mention yok
      if (char == '@') return true; // @ bulundu
    }
    
    return false;
  }

  /// Cursor pozisyonundan geriye doğru @mention query'sini bulur
  /// Returns: Query string (e.g., "john" for "@john")
  static String? getMentionQuery(String text, int cursorPosition) {
    if (cursorPosition == 0) return null;
    
    int startPos = -1;
    
    // Cursor'dan geriye doğru @ işaretini bul
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        startPos = i;
        break;
      }
      if (text[i] == ' ' || text[i] == '\n') {
        return null; // Boşluk bulundu, mention yok
      }
    }
    
    if (startPos == -1) return null;
    
    // @ işaretinden sonraki kısmı al
    final query = text.substring(startPos + 1, cursorPosition);
    return query.isEmpty ? null : query;
  }

  /// Mention query'sinin başlangıç pozisyonunu bulur
  static int? getMentionStartPosition(String text, int cursorPosition) {
    if (cursorPosition == 0) return null;
    
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        return i;
      }
      if (text[i] == ' ' || text[i] == '\n') {
        return null;
      }
    }
    
    return null;
  }
}

