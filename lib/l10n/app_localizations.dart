import 'package:flutter/material.dart';

/// App localization class
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('tr', 'TR'),
    Locale('en', 'US'),
  ];

  // Common
  String get appName => _localizedValues[locale.languageCode]?['appName'] ?? 'Psych Catalog';
  String get loading => _localizedValues[locale.languageCode]?['loading'] ?? 'Yükleniyor...';
  String get error => _localizedValues[locale.languageCode]?['error'] ?? 'Hata';
  String get success => _localizedValues[locale.languageCode]?['success'] ?? 'Başarılı';
  String get cancel => _localizedValues[locale.languageCode]?['cancel'] ?? 'İptal';
  String get save => _localizedValues[locale.languageCode]?['save'] ?? 'Kaydet';
  String get delete => _localizedValues[locale.languageCode]?['delete'] ?? 'Sil';
  String get edit => _localizedValues[locale.languageCode]?['edit'] ?? 'Düzenle';
  String get search => _localizedValues[locale.languageCode]?['search'] ?? 'Ara';
  
  // Auth
  String get login => _localizedValues[locale.languageCode]?['login'] ?? 'Giriş Yap';
  String get signup => _localizedValues[locale.languageCode]?['signup'] ?? 'Kayıt Ol';
  String get email => _localizedValues[locale.languageCode]?['email'] ?? 'E-posta';
  String get password => _localizedValues[locale.languageCode]?['password'] ?? 'Şifre';
  String get username => _localizedValues[locale.languageCode]?['username'] ?? 'Kullanıcı Adı';
  
  // Feed
  String get feed => _localizedValues[locale.languageCode]?['feed'] ?? 'Akış';
  String get discover => _localizedValues[locale.languageCode]?['discover'] ?? 'Keşfet';
  String get following => _localizedValues[locale.languageCode]?['following'] ?? 'Takip Edilenler';
  String get post => _localizedValues[locale.languageCode]?['post'] ?? 'Paylaş';
  
  // Profile
  String get profile => _localizedValues[locale.languageCode]?['profile'] ?? 'Profil';
  String get followers => _localizedValues[locale.languageCode]?['followers'] ?? 'Takipçiler';
  String get followingCount => _localizedValues[locale.languageCode]?['followingCount'] ?? 'Takip Edilen';
  String get posts => _localizedValues[locale.languageCode]?['posts'] ?? 'Paylaşımlar';
  String get tests => _localizedValues[locale.languageCode]?['tests'] ?? 'Testler';
  
  // Tests
  String get testResults => _localizedValues[locale.languageCode]?['testResults'] ?? 'Test Sonuçları';
  String get createTest => _localizedValues[locale.languageCode]?['createTest'] ?? 'Test Oluştur';
  String get solveTest => _localizedValues[locale.languageCode]?['solveTest'] ?? 'Test Çöz';
  
  // Settings
  String get settings => _localizedValues[locale.languageCode]?['settings'] ?? 'Ayarlar';
  String get notifications => _localizedValues[locale.languageCode]?['notifications'] ?? 'Bildirimler';
  String get language => _localizedValues[locale.languageCode]?['language'] ?? 'Dil';
  String get theme => _localizedValues[locale.languageCode]?['theme'] ?? 'Tema';
  
  // Notifications
  String get enableNotifications => _localizedValues[locale.languageCode]?['enableNotifications'] ?? 'Bildirimleri Etkinleştir';
  String get notificationSettings => _localizedValues[locale.languageCode]?['notificationSettings'] ?? 'Bildirim Ayarları';
  
  static final Map<String, Map<String, String>> _localizedValues = {
    'tr': {
      'appName': 'Psych Catalog',
      'loading': 'Yükleniyor...',
      'error': 'Hata',
      'success': 'Başarılı',
      'cancel': 'İptal',
      'save': 'Kaydet',
      'delete': 'Sil',
      'edit': 'Düzenle',
      'search': 'Ara',
      'login': 'Giriş Yap',
      'signup': 'Kayıt Ol',
      'email': 'E-posta',
      'password': 'Şifre',
      'username': 'Kullanıcı Adı',
      'feed': 'Akış',
      'discover': 'Keşfet',
      'following': 'Takip Edilenler',
      'post': 'Paylaş',
      'profile': 'Profil',
      'followers': 'Takipçiler',
      'followingCount': 'Takip Edilen',
      'posts': 'Paylaşımlar',
      'tests': 'Testler',
      'testResults': 'Test Sonuçları',
      'createTest': 'Test Oluştur',
      'solveTest': 'Test Çöz',
      'settings': 'Ayarlar',
      'notifications': 'Bildirimler',
      'language': 'Dil',
      'theme': 'Tema',
      'enableNotifications': 'Bildirimleri Etkinleştir',
      'notificationSettings': 'Bildirim Ayarları',
    },
    'en': {
      'appName': 'Psych Catalog',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'search': 'Search',
      'login': 'Login',
      'signup': 'Sign Up',
      'email': 'Email',
      'password': 'Password',
      'username': 'Username',
      'feed': 'Feed',
      'discover': 'Discover',
      'following': 'Following',
      'post': 'Post',
      'profile': 'Profile',
      'followers': 'Followers',
      'followingCount': 'Following',
      'posts': 'Posts',
      'tests': 'Tests',
      'testResults': 'Test Results',
      'createTest': 'Create Test',
      'solveTest': 'Solve Test',
      'settings': 'Settings',
      'notifications': 'Notifications',
      'language': 'Language',
      'theme': 'Theme',
      'enableNotifications': 'Enable Notifications',
      'notificationSettings': 'Notification Settings',
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['tr', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
