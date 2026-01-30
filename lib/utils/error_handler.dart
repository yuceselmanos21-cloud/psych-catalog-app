import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';
import '../constants/app_constants.dart';

/// Global error handler utility
class AppErrorHandler {
  AppErrorHandler._(); // Private constructor

  /// Hata mesajını kullanıcı dostu formata çevir
  static String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return _getAuthErrorMessage(error);
    }
    
    if (error is FirebaseException) {
      return _getFirebaseErrorMessage(error);
    }
    
    if (error is FormatException) {
      return 'Veri formatı hatası. Lütfen tekrar deneyin.';
    }
    
    if (error is AppTimeoutException || error.toString().toLowerCase().contains('timeout')) {
      return 'İstek zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edin.';
    }
    
    // Generic error
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'İnternet bağlantısı hatası. Lütfen bağlantınızı kontrol edin.';
    }
    
    if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'Bu işlem için yetkiniz bulunmuyor.';
    }
    
    if (errorString.contains('not found')) {
      return 'İstenen içerik bulunamadı.';
    }
    
    // Default
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }

  /// Firebase Auth hata mesajlarını Türkçe'ye çevir
  static String _getAuthErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'Kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Hatalı şifre.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanılıyor.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az ${AppConstants.minPasswordLength} karakter olmalı.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';
      case 'operation-not-allowed':
        return 'Bu işlem şu anda izin verilmiyor.';
      case 'network-request-failed':
        return 'İnternet bağlantısı hatası.';
      default:
        return 'Giriş hatası: ${error.message ?? "Bilinmeyen hata"}';
    }
  }

  /// Firebase hata mesajlarını Türkçe'ye çevir
  static String _getFirebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Bu işlem için yetkiniz bulunmuyor.';
      case 'unavailable':
        return 'Servis şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
      case 'deadline-exceeded':
        return 'İstek zaman aşımına uğradı.';
      case 'unauthenticated':
        return 'Oturum açmanız gerekiyor.';
      case 'not-found':
        return 'İstenen içerik bulunamadı.';
      case 'already-exists':
        return 'Bu kayıt zaten mevcut.';
      case 'failed-precondition':
        return 'İşlem ön koşulları karşılanmıyor.';
      case 'aborted':
        return 'İşlem iptal edildi.';
      case 'out-of-range':
        return 'Geçersiz değer aralığı.';
      case 'unimplemented':
        return 'Bu özellik henüz uygulanmadı.';
      case 'internal':
        return 'Sunucu hatası. Lütfen daha sonra tekrar deneyin.';
      case 'data-loss':
        return 'Veri kaybı oluştu.';
      default:
        return 'Bir hata oluştu: ${error.message ?? "Bilinmeyen hata"}';
    }
  }

  /// Hata göster ve logla
  static void handleError(
    BuildContext buildContext,
    dynamic error, {
    StackTrace? stackTrace,
    String? customMessage,
    Map<String, dynamic>? context,
    VoidCallback? onRetry,
  }) {
    // Log error
    AppLogger.error(
      customMessage ?? 'Error occurred',
      error: error,
      stackTrace: stackTrace,
      context: context,
    );

    // Show user-friendly message
    if (buildContext.mounted) {
      final message = customMessage ?? getErrorMessage(error);
      
      ScaffoldMessenger.of(buildContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: onRetry != null
              ? SnackBarAction(
                  label: 'Tekrar Dene',
                  textColor: Colors.white,
                  onPressed: onRetry,
                )
              : null,
        ),
      );
    }
  }

  /// Success mesajı göster
  static void showSuccess(
    BuildContext buildContext,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (buildContext.mounted) {
      ScaffoldMessenger.of(buildContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          duration: duration,
        ),
      );
    }
  }

  /// Info mesajı göster
  static void showInfo(
    BuildContext buildContext,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (buildContext.mounted) {
      ScaffoldMessenger.of(buildContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: duration,
        ),
      );
    }
  }
}

/// TimeoutException için custom exception
class AppTimeoutException implements Exception {
  final String message;
  AppTimeoutException(this.message);
  
  @override
  String toString() => message;
}
