import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/create_test_screen.dart';
import 'screens/solve_test_screen.dart';
import 'screens/analysis_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/experts_list_screen.dart';
import 'screens/result_detail_screen.dart';
import 'screens/expert_test_list_screen.dart';
import 'screens/solved_tests_screen.dart';
import 'screens/expert_test_detail_screen.dart';
import 'screens/tests_screen.dart';






void main() async {
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
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xfff5f5f5),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/feed': (context) => const FeedScreen(),
        '/createTest': (context) => const CreateTestScreen(),
        '/solveTest': (context) => const SolveTestScreen(),
        '/analysis': (context) => const AnalysisScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/experts': (context) => const ExpertsListScreen(),
        '/resultDetail': (context) => const ResultDetailScreen(),
        '/expertTests': (context) => const ExpertTestListScreen(),
        '/solvedTests': (context) => const SolvedTestsScreen(),
        '/expertTestDetail': (context) => const ExpertTestDetailScreen(),
        '/tests': (context) => const TestsScreen(),

      },
    );
  }
}

