import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

// EKRANLAR
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/experts_list_screen.dart';
import 'screens/expert_public_profile_screen.dart';
import 'screens/tests_list_screen.dart';
import 'screens/solve_test_screen.dart';
import 'screens/create_test_screen.dart';
import 'screens/expert_test_list_screen.dart';
import 'screens/expert_test_detail_screen.dart';
import 'screens/solved_tests_screen.dart';
import 'screens/result_detail_screen.dart';
import 'screens/analysis_screen.dart';
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
        useMaterial3: true,
      ),

      /// ─── GİRİŞ KONTROLÜ (GİRİŞ YAPMIŞ MI) ─────────────────────────────
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snap.hasData) {
            return const FeedScreen();
          }

          return const LoginScreen();
        },
      ),

      /// ─── PARAMETRE İSTEMEYEN SAYFALAR ────────────────────────────────
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/feed': (_) => const FeedScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/experts': (_) => const ExpertsListScreen(),
        '/tests': (_) => const TestsListScreen(),
        '/createTest': (_) => const CreateTestScreen(),
        '/expertTests': (_) => const ExpertTestListScreen(),
        '/solvedTests': (_) => const SolvedTestsScreen(),
        '/analysis': (_) => const AnalysisScreen(),
      },

      /// ─── PARAMETRELİ SAYFALAR ────────────────────────────────────────
      onGenerateRoute: (settings) {
        final name = settings.name;
        final args = settings.arguments;

        // TEST ÇÖZME: /solveTest  -> SolveTestScreen(testData: Map)
        if (name == '/solveTest') {
          if (args is Map<String, dynamic>) {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => SolveTestScreen(testData: args),
            );
          }
          return _errorRoute('Test bilgisi alınamadı.');
        }

        // UZMANIN OLUŞTURDUĞU TESTİN DETAYI: /expertTestDetail -> ExpertTestDetailScreen(testId)
        if (name == '/expertTestDetail') {
          final testId = args as String?;
          if (testId == null || testId.isEmpty) {
            return _errorRoute('Test bilgisi eksik.');
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => ExpertTestDetailScreen(testId: testId),
          );
        }

        // HERKESE AÇIK UZMAN PROFİLİ: /publicExpertProfile
        // Argüman bazen String (uid), bazen DocumentSnapshot gelebiliyor.
        if (name == '/publicExpertProfile') {
          String? expertId;

          if (args is String) {
            expertId = args;
          } else if (args is DocumentSnapshot) {
            expertId = args.id;
          }

          if (expertId == null || expertId.isEmpty) {
            return _errorRoute('Uzman bilgisi alınamadı.');
          }

          return MaterialPageRoute(
            settings: settings,
            builder: (_) => ExpertPublicProfileScreen(expertId: expertId!),
          );
        }

        // ÇÖZÜLEN TEST SONUCU DETAYI: /resultDetail
        // ResultDetailScreen, argümanı kendi içinde ModalRoute ile alıyor.
        if (name == '/resultDetail') {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const ResultDetailScreen(),
          );
        }

        // GÖNDERİ DETAYI (TWITTER GİBİ): /postDetail -> PostDetailScreen(postId)
        if (name == '/postDetail') {
          final postId = args as String?;
          if (postId == null || postId.isEmpty) {
            return _errorRoute('Gönderi bulunamadı.');
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => PostDetailScreen(postId: postId),
          );
        }

        // Bilinmeyen route için null dönüyoruz; Flutter kendi unknownRoute hatasını gösterir.
        return null;
      },
    );
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Hata')),
        body: Center(child: Text(message)),
      ),
    );
  }
}
