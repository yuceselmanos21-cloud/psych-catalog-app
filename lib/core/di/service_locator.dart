import 'package:get_it/get_it.dart';
import '../../repositories/firestore_post_repository.dart';
import '../../repositories/firestore_user_repository.dart';
import '../../repositories/firestore_test_repository.dart';
import '../../repositories/firestore_follow_repository.dart';
import '../../repositories/firestore_block_repository.dart';
import '../../repositories/firestore_chat_repository.dart';
import '../../repositories/firestore_report_repository.dart';
import '../../services/theme_service.dart';
import '../../utils/logger.dart';

/// Dependency Injection container
final getIt = GetIt.instance;

/// Service locator setup
Future<void> setupServiceLocator() async {
  AppLogger.debug('Setting up service locator...');

  // --- REPOSITORIES (Singletons) ---
  getIt.registerLazySingleton<FirestorePostRepository>(
    () => FirestorePostRepository.instance,
  );

  getIt.registerLazySingleton<FirestoreUserRepository>(
    () => FirestoreUserRepository(),
  );

  getIt.registerLazySingleton<FirestoreTestRepository>(
    () => FirestoreTestRepository(),
  );

  getIt.registerLazySingleton<FirestoreFollowRepository>(
    () => FirestoreFollowRepository(),
  );

  getIt.registerLazySingleton<FirestoreBlockRepository>(
    () => FirestoreBlockRepository(),
  );

  getIt.registerLazySingleton<FirestoreChatRepository>(
    () => FirestoreChatRepository(),
  );

  getIt.registerLazySingleton<FirestoreReportRepository>(
    () => FirestoreReportRepository(),
  );

  // --- SERVICES (Singletons) ---
  getIt.registerLazySingleton<ThemeService>(
    () => ThemeService(),
  );

  // AnalysisService static methods kullanıyor, şimdilik register etmiyoruz
  // Gelecekte instance-based yapılabilir

  AppLogger.success('Service locator setup completed');
}
