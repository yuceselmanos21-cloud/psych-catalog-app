/// Uygulama genelinde kullanılan sabitler
class AppConstants {
  AppConstants._(); // Private constructor - singleton pattern

  // --- POST & CONTENT LIMITS ---
  static const int maxPostLength = 1000;
  static const int maxCommentLength = 500;
  static const int maxBioLength = 500;
  static const int maxAboutLength = 2000;
  static const int maxSpecialtiesLength = 500;
  static const int maxEducationLength = 2000;

  // --- PAGINATION ---
  static const int postsPerPage = 20;
  static const int commentsPerPage = 15;
  static const int usersPerPage = 20;
  static const int testsPerPage = 15;
  static const int messagesPerPage = 50;

  // --- DEBOUNCE & THROTTLE ---
  static const Duration debounceDelay = Duration(milliseconds: 500);
  static const Duration throttleDelay = Duration(milliseconds: 300);
  static const Duration scrollDebounceDelay = Duration(milliseconds: 100);

  // --- FILE UPLOAD ---
  static const int maxImageSizeMB = 5;
  static const int maxFileSizeMB = 10;
  static const int maxVideoSizeMB = 50;
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1920;
  static const int imageQuality = 85; // 0-100

  // --- SUPPORTED FILE TYPES ---
  static const List<String> supportedImageTypes = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
  static const List<String> supportedVideoTypes = ['mp4', 'mov', 'avi'];
  static const List<String> supportedDocumentTypes = ['pdf', 'doc', 'docx'];

  // --- CACHE DURATIONS ---
  static const Duration cacheExpiration = Duration(hours: 24);
  static const Duration analysisCacheExpiration = Duration(days: 7);
  static const Duration expertCacheExpiration = Duration(hours: 1);

  // --- RATE LIMITING ---
  static const Duration postCooldown = Duration(seconds: 5);
  static const Duration followCooldown = Duration(seconds: 2);
  static const Duration reportCooldown = Duration(minutes: 5);
  static const Duration analysisCooldown = Duration(seconds: 8);

  // --- UI CONSTANTS ---
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;

  // --- ANIMATION DURATIONS ---
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // --- PROFESSION LIST ---
  static const List<String> professionList = [
    'Psikolog',
    'Klinik Psikolog',
    'Nöropsikolog',
    'Psikiyatr',
    'Psikolojik Danışman (PDR)',
    'Sosyal Hizmet Uzmanı',
    'Aile Danışmanı',
  ];

  // --- BRAND COLORS ---
  static const int brandNavyValue = 0xFF0D1B3D;
  static const int brandPurpleValue = 0xFF6B46C1;

  // --- RETRY CONFIGURATION ---
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration requestTimeout = Duration(seconds: 30);

  // --- VALIDATION ---
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 50;

  // --- FEATURE FLAGS (gelecekte Remote Config ile yönetilebilir) ---
  static const bool enablePushNotifications = false; // Hazır ama aktif değil
  static const bool enableVideoCalls = false;
  static const bool enableStories = false;
  static const bool enableHashtags = false;
}
