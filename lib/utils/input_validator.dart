import '../constants/app_constants.dart';

/// Input validation utilities
class InputValidator {
  InputValidator._(); // Private constructor

  /// Username validation
  static ValidationResult validateUsername(String username) {
    if (username.isEmpty) {
      return ValidationResult(false, 'Kullanıcı adı boş olamaz');
    }

    if (username.length < AppConstants.minUsernameLength) {
      return ValidationResult(
        false,
        'Kullanıcı adı en az ${AppConstants.minUsernameLength} karakter olmalı',
      );
    }

    if (username.length > AppConstants.maxUsernameLength) {
      return ValidationResult(
        false,
        'Kullanıcı adı en fazla ${AppConstants.maxUsernameLength} karakter olabilir',
      );
    }

    // Sadece harf, rakam ve alt çizgi
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return ValidationResult(
        false,
        'Kullanıcı adı sadece harf, rakam ve alt çizgi içerebilir',
      );
    }

    // Rezerve kelimeler
    final reservedWords = ['admin', 'root', 'system', 'null', 'undefined'];
    if (reservedWords.contains(username.toLowerCase())) {
      return ValidationResult(false, 'Bu kullanıcı adı kullanılamaz');
    }

    return ValidationResult(true);
  }

  /// Email validation
  static ValidationResult validateEmail(String email) {
    if (email.isEmpty) {
      return ValidationResult(false, 'E-posta adresi boş olamaz');
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      return ValidationResult(false, 'Geçerli bir e-posta adresi girin');
    }

    return ValidationResult(true);
  }

  /// Password validation
  static ValidationResult validatePassword(String password) {
    if (password.isEmpty) {
      return ValidationResult(false, 'Şifre boş olamaz');
    }

    if (password.length < AppConstants.minPasswordLength) {
      return ValidationResult(
        false,
        'Şifre en az ${AppConstants.minPasswordLength} karakter olmalı',
      );
    }

    if (password.length > AppConstants.maxPasswordLength) {
      return ValidationResult(
        false,
        'Şifre en fazla ${AppConstants.maxPasswordLength} karakter olabilir',
      );
    }

    return ValidationResult(true);
  }

  /// Post content validation
  static ValidationResult validatePostContent(String content) {
    if (content.trim().isEmpty) {
      return ValidationResult(false, 'Gönderi içeriği boş olamaz');
    }

    if (content.length > AppConstants.maxPostLength) {
      return ValidationResult(
        false,
        'Gönderi en fazla ${AppConstants.maxPostLength} karakter olabilir',
      );
    }

    return ValidationResult(true);
  }

  /// Comment content validation
  static ValidationResult validateCommentContent(String content) {
    if (content.trim().isEmpty) {
      return ValidationResult(false, 'Yorum içeriği boş olamaz');
    }

    if (content.length > AppConstants.maxCommentLength) {
      return ValidationResult(
        false,
        'Yorum en fazla ${AppConstants.maxCommentLength} karakter olabilir',
      );
    }

    return ValidationResult(true);
  }

  /// Sanitize input (XSS koruması)
  static String sanitize(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '') // HTML tags
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '') // JavaScript
        .replaceAll(RegExp(r'on\w+=', caseSensitive: false), '') // Event handlers
        .trim();
  }

  /// Profanity filter (basit)
  static bool containsProfanity(String text) {
    final profanityWords = [
      // Türkçe küfürler (örnek - gerçek liste daha kapsamlı olmalı)
      'küfür1', 'küfür2', // Bu liste genişletilmeli
    ];

    final lowerText = text.toLowerCase();
    return profanityWords.any((word) => lowerText.contains(word));
  }

  /// URL validation
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }
}

/// Validation result
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult(this.isValid, [this.errorMessage]);
}
