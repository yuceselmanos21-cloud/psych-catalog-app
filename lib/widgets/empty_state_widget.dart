import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Tutarlı empty state widget'ı
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColorValue = iconColor ?? 
        (isDark ? Colors.grey.shade600 : Colors.grey.shade400);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColorValue,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Önceden tanımlanmış empty state'ler
class EmptyStates {
  EmptyStates._();

  static Widget noPosts({VoidCallback? onCreatePost}) {
    return EmptyStateWidget(
      icon: Icons.article_outlined,
      title: 'Henüz gönderi yok',
      subtitle: 'İlk gönderinizi paylaşarak başlayın',
      actionLabel: 'Gönderi Paylaş',
      onAction: onCreatePost,
    );
  }

  static Widget noComments() {
    return const EmptyStateWidget(
      icon: Icons.comment_outlined,
      title: 'Henüz yorum yok',
      subtitle: 'İlk yorumu sen yap',
    );
  }

  static Widget noUsers() {
    return const EmptyStateWidget(
      icon: Icons.people_outline,
      title: 'Kullanıcı bulunamadı',
      subtitle: 'Arama kriterlerinizi değiştirmeyi deneyin',
    );
  }

  static Widget noTests({VoidCallback? onCreateTest}) {
    return EmptyStateWidget(
      icon: Icons.quiz_outlined,
      title: 'Henüz test yok',
      subtitle: 'İlk testini oluşturarak başla',
      actionLabel: 'Test Oluştur',
      onAction: onCreateTest,
    );
  }

  static Widget noMessages() {
    return const EmptyStateWidget(
      icon: Icons.message_outlined,
      title: 'Henüz mesaj yok',
      subtitle: 'Birine mesaj göndererek başlayın',
    );
  }

  static Widget noSearchResults() {
    return const EmptyStateWidget(
      icon: Icons.search_off,
      title: 'Sonuç bulunamadı',
      subtitle: 'Arama terimlerinizi değiştirmeyi deneyin',
    );
  }

  static Widget noFollowers() {
    return const EmptyStateWidget(
      icon: Icons.person_outline,
      title: 'Henüz takipçi yok',
    );
  }

  static Widget noFollowing() {
    return const EmptyStateWidget(
      icon: Icons.person_add_outlined,
      title: 'Henüz kimseyi takip etmiyorsun',
      subtitle: 'İlginç insanları keşfet ve takip et',
    );
  }

  static Widget noBlockedUsers() {
    return const EmptyStateWidget(
      icon: Icons.block,
      title: 'Engellenen kullanıcı yok',
    );
  }

  static Widget noSavedPosts() {
    return const EmptyStateWidget(
      icon: Icons.bookmark_outline,
      title: 'Kaydedilmiş gönderi yok',
      subtitle: 'Beğendiğin gönderileri kaydet',
    );
  }

  static Widget noLikedPosts() {
    return const EmptyStateWidget(
      icon: Icons.favorite_outline,
      title: 'Beğenilen gönderi yok',
    );
  }

  static Widget noSolvedTests() {
    return const EmptyStateWidget(
      icon: Icons.assignment_turned_in_outlined,
      title: 'Henüz test çözmedin',
      subtitle: 'Testleri keşfet ve çöz',
    );
  }

  static Widget error({
    required String message,
    VoidCallback? onRetry,
  }) {
    return EmptyStateWidget(
      icon: Icons.error_outline,
      title: 'Bir hata oluştu',
      subtitle: message,
      actionLabel: 'Tekrar Dene',
      onAction: onRetry,
      iconColor: Colors.red,
    );
  }

  static Widget loading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}
