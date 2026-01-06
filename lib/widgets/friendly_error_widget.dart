import 'package:flutter/material.dart';

/// Kullanıcı dostu hata mesajları gösteren widget
class FriendlyErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;
  final bool isDark;

  const FriendlyErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.isDark = false,
  });

  String _getFriendlyMessage(String error) {
    final errorLower = error.toLowerCase();
    
    if (errorLower.contains('timeout') || errorLower.contains('zaman aşımı')) {
      return 'Bağlantı zaman aşımına uğradı. İnternet bağlantınızı kontrol edin ve tekrar deneyin.';
    } else if (errorLower.contains('401') || errorLower.contains('unauthorized') || errorLower.contains('geçersiz token')) {
      return 'Oturum süreniz dolmuş. Lütfen uygulamadan çıkış yapıp tekrar giriş yapın.';
    } else if (errorLower.contains('429') || errorLower.contains('rate limit') || errorLower.contains('çok fazla istek')) {
      return 'Çok fazla istek gönderildi. Lütfen birkaç dakika sonra tekrar deneyin.';
    } else if (errorLower.contains('network') || errorLower.contains('internet') || errorLower.contains('bağlantı')) {
      return 'İnternet bağlantınızı kontrol edin ve tekrar deneyin.';
    } else if (errorLower.contains('404') || errorLower.contains('bulunamadı')) {
      return 'İstenen içerik bulunamadı. Lütfen sayfayı yenileyin.';
    } else if (errorLower.contains('500') || errorLower.contains('sunucu hatası')) {
      return 'Sunucu hatası oluştu. Lütfen birkaç dakika sonra tekrar deneyin.';
    }
    return 'Bir hata oluştu. Lütfen daha sonra tekrar deneyin.';
  }

  @override
  Widget build(BuildContext context) {
    final friendlyMsg = _getFriendlyMessage(error);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? Colors.red.shade300 : Colors.red.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              friendlyMsg,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey.shade200 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

