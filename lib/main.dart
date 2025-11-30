import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

// Ekranlar
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/create_test_screen.dart';
import 'screens/solve_test_screen.dart';
import 'screens/solved_tests_screen.dart';
import 'screens/result_detail_screen.dart';
import 'screens/experts_list_screen.dart';
import 'screens/expert_test_list_screen.dart';
import 'screens/analysis_screen.dart';
import 'screens/post_create_screen.dart';
import 'screens/tests_list_screen.dart';

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
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: const Color(0xfffaf5ff),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/feed': (_) => const FeedScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/createTest': (_) => const CreateTestScreen(),

        '/tests': (_) => const TestsListScreen(),        // Danışan tüm testler
        '/expertTests': (_) => const ExpertTestListScreen(), // Uzmanın testleri

        '/solveTest': (_) => const SolveTestScreen(),
        '/solvedTests': (_) => const SolvedTestsScreen(),
        '/resultDetail': (_) => const ResultDetailScreen(),

        '/experts': (_) => const ExpertsListScreen(),
        '/analysis': (_) => const AnalysisScreen(),
        '/createPost': (_) => const PostCreateScreen(),
      },
    );
  }
}
