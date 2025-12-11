import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

// Screens
import 'screens/auth_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/experts_list_screen.dart';
import 'screens/expert_public_profile_screen.dart';

import 'screens/tests_list_screen.dart';
import 'screens/tests_screen.dart';
import 'screens/solve_test_screen.dart';
import 'screens/solved_tests_screen.dart';
import 'screens/result_detail_screen.dart';

import 'screens/create_test_screen.dart';
import 'screens/expert_test_list_screen.dart';
import 'screens/expert_test_detail_screen.dart';

import 'screens/analysis_screen.dart';
import 'screens/post_create_screen.dart';
import 'screens/post_detail_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Web için ekstra stabilite
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  }

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
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),

      initialRoute: '/login',

      routes: {
        '/auth': (_) => const AuthScreen(),
        '/login': (_) => const AuthScreen(initialTab: AuthInitialTab.login),
        '/signup': (_) => const AuthScreen(initialTab: AuthInitialTab.signup),

        '/feed': (_) => const FeedScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/experts': (_) => const ExpertsListScreen(),

        '/tests': (_) => const TestsListScreen(),
        '/allTests': (_) => const TestsScreen(),
        '/solvedTests': (_) => const SolvedTestsScreen(),
        '/analysis': (_) => const AnalysisScreen(),

        '/createTest': (_) => const CreateTestScreen(),
        '/expertTests': (_) => const ExpertTestListScreen(),

        '/createPost': (_) => const PostCreateScreen(),
      },

      onGenerateRoute: (settings) {
        final name = settings.name;
        final args = settings.arguments;

        if (name == '/resultDetail') {
          return MaterialPageRoute(
            builder: (_) => const ResultDetailScreen(),
            settings: settings,
          );
        }

        if (name == '/postDetail') {
          final postId = _extractId(args, mapKey: 'postId');
          if (postId == null || postId.isEmpty) {
            return _errorRoute('Gönderi bilgisi bulunamadı.');
          }

          return MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: postId),
            settings: settings,
          );
        }

        if (name == '/publicExpertProfile') {
          final expertId = _extractId(args, mapKey: 'expertId');
          if (expertId == null || expertId.isEmpty) {
            return _errorRoute('Uzman bilgisi bulunamadı.');
          }

          return MaterialPageRoute(
            builder: (_) => ExpertPublicProfileScreen(expertId: expertId),
            settings: settings,
          );
        }

        if (name == '/expertTestDetail') {
          final testId = _extractId(args, mapKey: 'testId');
          if (testId == null || testId.isEmpty) {
            return _errorRoute('Test bilgisi bulunamadı.');
          }

          return MaterialPageRoute(
            builder: (_) => ExpertTestDetailScreen(testId: testId),
            settings: settings,
          );
        }

        if (name == '/solveTest') {
          if (args is Map<String, dynamic>) {
            return MaterialPageRoute(
              builder: (_) => SolveTestScreen(testData: args),
              settings: settings,
            );
          }
          return _errorRoute('Test verisi eksik veya hatalı.');
        }

        return null;
      },
    );
  }

  static String? _extractId(Object? args, {String? mapKey}) {
    if (args == null) return null;

    if (args is String) return args;

    if (args is DocumentSnapshot) return args.id;
    if (args is QueryDocumentSnapshot) return args.id;

    if (args is Map) {
      if (mapKey != null && args[mapKey] is String) {
        return args[mapKey] as String;
      }
      if (args['id'] is String) return args['id'] as String;
      if (args['postId'] is String) return args['postId'] as String;
      if (args['expertId'] is String) return args['expertId'] as String;
      if (args['testId'] is String) return args['testId'] as String;
    }

    return null;
  }

  static MaterialPageRoute _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Hata')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
