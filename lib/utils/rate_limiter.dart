import 'dart:async';
import '../constants/app_constants.dart';
import '../utils/logger.dart';

/// Rate limiting utility
class RateLimiter {
  RateLimiter._(); // Private constructor

  // Action bazlı son çalıştırma zamanları
  static final Map<String, DateTime> _lastActionTimes = {};
  
  // Action bazlı deneme sayıları (cooldown için)
  static final Map<String, int> _actionAttempts = {};
  static final Map<String, Timer> _resetTimers = {};

  /// Rate limit kontrolü
  static bool canPerformAction(
    String actionId, {
    Duration? cooldown,
    int? maxAttempts,
    Duration? resetWindow,
  }) {
    final now = DateTime.now();
    final lastTime = _lastActionTimes[actionId];
    
    // Cooldown kontrolü
    if (cooldown != null && lastTime != null) {
      final timeSinceLastAction = now.difference(lastTime);
      if (timeSinceLastAction < cooldown) {
        AppLogger.debug('Rate limit: action in cooldown', context: {
          'action': actionId,
          'remaining': (cooldown.inSeconds - timeSinceLastAction.inSeconds).toString(),
        });
        return false;
      }
    }

    // Max attempts kontrolü
    if (maxAttempts != null && resetWindow != null) {
      final attempts = _actionAttempts[actionId] ?? 0;
      if (attempts >= maxAttempts) {
        AppLogger.warning('Rate limit: max attempts reached', context: {
          'action': actionId,
          'attempts': attempts.toString(),
        });
        return false;
      }
    }

    return true;
  }

  /// Action'ı kaydet
  static void recordAction(
    String actionId, {
    Duration? resetWindow,
  }) {
    _lastActionTimes[actionId] = DateTime.now();

    // Reset window varsa attempt sayısını artır
    if (resetWindow != null) {
      _actionAttempts[actionId] = (_actionAttempts[actionId] ?? 0) + 1;

      // Reset timer'ı iptal et ve yeniden başlat
      _resetTimers[actionId]?.cancel();
      _resetTimers[actionId] = Timer(resetWindow, () {
        _actionAttempts[actionId] = 0;
        _resetTimers[actionId]?.cancel();
        _resetTimers.remove(actionId);
      });
    }
  }

  /// Kalan süreyi al
  static Duration? getRemainingCooldown(String actionId, Duration cooldown) {
    final lastTime = _lastActionTimes[actionId];
    if (lastTime == null) return null;

    final elapsed = DateTime.now().difference(lastTime);
    if (elapsed >= cooldown) return null;

    return cooldown - elapsed;
  }

  /// Rate limit'i temizle (test için)
  static void clear(String? actionId) {
    if (actionId != null) {
      _lastActionTimes.remove(actionId);
      _actionAttempts.remove(actionId);
      _resetTimers[actionId]?.cancel();
      _resetTimers.remove(actionId);
    } else {
      _lastActionTimes.clear();
      _actionAttempts.clear();
      _resetTimers.values.forEach((timer) => timer.cancel());
      _resetTimers.clear();
    }
  }
}

/// Rate limit decorator
Future<T> withRateLimit<T>(
  String actionId,
  Future<T> Function() action, {
  Duration? cooldown,
  int? maxAttempts,
  Duration? resetWindow,
  String? errorMessage,
}) async {
  if (!RateLimiter.canPerformAction(
    actionId,
    cooldown: cooldown,
    maxAttempts: maxAttempts,
    resetWindow: resetWindow,
  )) {
    final remaining = RateLimiter.getRemainingCooldown(actionId, cooldown ?? Duration.zero);
    throw RateLimitException(
      errorMessage ?? 'Bu işlemi çok sık yapıyorsunuz. Lütfen bekleyin.',
      remaining,
    );
  }

  try {
    final result = await action();
    RateLimiter.recordAction(actionId, resetWindow: resetWindow);
    return result;
  } catch (e) {
    // Hata durumunda rate limit kaydı yapma
    rethrow;
  }
}

/// Rate limit exception
class RateLimitException implements Exception {
  final String message;
  final Duration? remainingTime;

  RateLimitException(this.message, this.remainingTime);

  @override
  String toString() {
    if (remainingTime != null) {
      final seconds = remainingTime!.inSeconds;
      return '$message (${seconds}s kaldı)';
    }
    return message;
  }
}
