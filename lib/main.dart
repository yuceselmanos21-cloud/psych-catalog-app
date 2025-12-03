import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

// EKRANLAR
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/create_test_screen.dart';
import 'screens/tests_list_screen.dart';
import 'screens/solve_test_screen.dart';
import 'screens/solved_tests_screen.dart';
import 'screens/result_detail_screen.dart';
import 'screens/analysis_screen.dart';
import 'screens/experts_list_screen.dart';
import 'screens/expert_public_profile_screen.dart';
import 'screens/expert_test_list_screen.dart';
import 'screens/expert_test_detail_screen.dart';
import 'screens/post_detail_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PsychCatalogApp());
}

class PsychCatalogApp extends StatelessWidget {
  const PsychCatalogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Psych Catalog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: false,
      ),

      /// Giriş yapılmış mı, yapılmamış mı buradan karar veriyoruz
      home: const _AuthGate(),

      /// ARGÜMAN İSTEMEYEN SAYFALAR
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/feed': (_) => const FeedScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/createTest': (_) => const CreateTestScreen(),
        '/tests': (_) => const TestsListScreen(),
        '/solvedTests': (_) => const SolvedTestsScreen(),
        '/analysis': (_) => const AnalysisScreen(),
        '/experts': (_) => const ExpertsListScreen(),
        '/expertTests': (_) => const ExpertTestListScreen(),
        '/resultDetail': (_) => const ResultDetailScreen(),
      },

      /// ARGÜMAN GEREKEN ROUTE'LAR
      onGenerateRoute: (settings) {
        // ✅ Test çözme: /solveTest
        if (settings.name == '/solveTest') {
          final args = settings.arguments as Map<String, dynamic>?;

          if (args == null) {
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Test bilgisi alınamadı.')),
              ),
            );
          }

          return MaterialPageRoute(
            builder: (_) => SolveTestScreen(testData: args),
          );
        }

        // ✅ Post detay: /postDetail  (arguments: String postId)
        if (settings.name == '/postDetail') {
          final postId = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: postId ?? ''),
          );
        }

        // ✅ Uzmanın herkese açık profili: /publicExpertProfile (arguments: String expertId)
        if (settings.name == '/publicExpertProfile') {
          final expertId = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (_) =>
                ExpertPublicProfileScreen(expertId: expertId ?? ''),
          );
        }

        // ✅ Uzmanın oluşturduğu test detayı: /expertTestDetail (arguments: String testId)
        if (settings.name == '/expertTestDetail') {
          final testId = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (_) => ExpertTestDetailScreen(testId: testId ?? ''),
          );
        }

        // Bilinmeyen route'lar için null döner; Flutter kendi hatasını gösterir.
        return null;
      },
    );
  }
}

/// Kullanıcı giriş yapmış mı, ona göre Login / Feed gösteren widget
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;
        if (user == null) {
          return const LoginScreen();
        }

        return const FeedScreen();
      },
    );
  }
}
