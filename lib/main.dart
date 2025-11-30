import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/create_test_screen.dart';
import 'screens/tests_list_screen.dart';
import 'screens/solve_test_screen.dart';
import 'screens/solved_tests_screen.dart';
import 'screens/expert_test_list_screen.dart';
import 'screens/expert_test_detail_screen.dart';
import 'screens/analysis_screen.dart';
import 'screens/result_detail_screen.dart';

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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: false,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/feed': (_) => const FeedScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/createTest': (_) => const CreateTestScreen(),
        '/tests': (_) => const TestsListScreen(),
        '/solvedTests': (_) => const SolvedTestsScreen(),
        '/expertTests': (_) => const ExpertTestListScreen(),
        '/analysis': (_) => const AnalysisScreen(),
        '/resultDetail': (_) => const ResultDetailScreen(),
        '/solveTest': (context) {
          final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return SolveTestScreen(testData: args);
        },

      },
      onGenerateRoute: (settings) {
        if (settings.name == '/solveTest') {
          final args =
              settings.arguments as Map<String, dynamic>? ?? <String, dynamic>{};
          return MaterialPageRoute(
            builder: (_) => SolveTestScreen(testData: args),
          );
        }

        if (settings.name == '/expertTestDetail') {
          final testId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => ExpertTestDetailScreen(testId: testId),
          );
        }

        return null;
      },
    );
  }
}
