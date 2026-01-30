import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_provider.dart';
import 'subscription_provider.dart';

/// Expert erişim kontrolü - Abonelik aktif mi?
final canAccessExpertFeaturesProvider = Provider<bool>((ref) {
  final userState = ref.watch(userProvider);
  final hasSubscription = ref.watch(hasActiveSubscriptionProvider);

  // Admin her zaman erişebilir
  if (userState.isAdmin) return true;

  // Expert ise abonelik kontrolü
  if (userState.isExpert) {
    return hasSubscription;
  }

  return false;
});

/// Expert özelliklerine erişim kontrolü için action
final expertAccessActionProvider = Provider<ExpertAccessAction>((ref) {
  return ExpertAccessAction(ref);
});

class ExpertAccessAction {
  final Ref _ref;

  ExpertAccessAction(this._ref);

  /// Expert özelliklerine erişebilir mi kontrol et
  bool canAccess() {
    return _ref.read(canAccessExpertFeaturesProvider);
  }

  /// Erişim yoksa hata fırlat
  void requireAccess() {
    if (!canAccess()) {
      throw ExpertAccessException(
        'Bu özelliği kullanmak için aktif bir aboneliğiniz olmalıdır.',
      );
    }
  }
}

/// Expert erişim exception
class ExpertAccessException implements Exception {
  final String message;

  ExpertAccessException(this.message);

  @override
  String toString() => message;
}
