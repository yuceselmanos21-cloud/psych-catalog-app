import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

// --- EKRANLAR ---
import 'screens/auth_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/experts_list_screen.dart';
import 'screens/expert_public_profile_screen.dart';
import 'screens/public_client_profile_screen.dart';

import 'screens/tests_screen.dart';
import 'screens/create_test_screen.dart';
import 'screens/solve_test_screen.dart';
import 'screens/solved_tests_screen.dart';
import 'screens/result_detail_screen.dart';

import 'screens/expert_test_list_screen.dart';
import 'screens/expert_test_detail_screen.dart';

import 'screens/post_create_screen.dart';
import 'screens/post_detail_screen.dart';
import 'screens/reposts_quotes_list_screen.dart';

import 'screens/chat_list_screen.dart';
import 'screens/chat_screen.dart';

import 'screens/analysis_screen.dart';
import 'screens/ai_consultations_screen.dart';
import 'screens/ai_consultation_detail_screen.dart';
import 'screens/search_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    // ✅ ThemeService değişikliklerini dinle
    _themeService.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // ✅ Singleton olduğu için dispose etme, sadece listener'ı kaldır
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Psych Catalog',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'), // Türkçe
        Locale('en', 'US'), // İngilizce (fallback)
      ],
      locale: const Locale('tr', 'TR'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D1B3D),
          primary: const Color(0xFF0D1B3D),
          secondary: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Color(0xFF0D1B3D), fontSize: 18, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Color(0xFF0D1B3D)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          primary: Colors.deepPurple,
          secondary: Colors.deepPurpleAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade800, width: 1),
          ),
        ),
        dividerColor: Colors.grey.shade800,
      ),
      themeMode: _themeService.themeMode,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (snapshot.hasData) return const FeedScreen();
          return const AuthScreen();
        },
      ),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/auth': return MaterialPageRoute(builder: (_) => const AuthScreen());
          case '/feed': return MaterialPageRoute(builder: (_) => const FeedScreen());
          case '/profile': return MaterialPageRoute(builder: (_) => const ProfileScreen());
          case '/experts': return MaterialPageRoute(builder: (_) => const ExpertsListScreen());
          case '/tests': return MaterialPageRoute(builder: (_) => const TestsScreen());
          case '/createTest': return MaterialPageRoute(builder: (_) => const CreateTestScreen());
          case '/solvedTests': return MaterialPageRoute(builder: (_) => const SolvedTestsScreen());
          case '/expertTests': return MaterialPageRoute(builder: (_) => const ExpertTestListScreen());
          case '/myTests': return MaterialPageRoute(builder: (_) => const ExpertTestListScreen()); // ✅ Geriye dönük uyumluluk
          case '/createPost': return MaterialPageRoute(builder: (_) => const PostCreateScreen());
          case '/admin': return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());
          case '/chatList': return MaterialPageRoute(builder: (_) => const ChatListScreen());
          case '/analysis': return MaterialPageRoute(builder: (_) => const AnalysisScreen());
          case '/aiConsultations': return MaterialPageRoute(builder: (_) => const AIConsultationsScreen());
          case '/search': return MaterialPageRoute(builder: (_) => const SearchScreen());

        // ✅ DÜZELTİLDİ: Chat ID üretimi
          case '/chat':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              final myUid = FirebaseAuth.instance.currentUser?.uid;
              final otherUid = args['otherUserId'] as String;

              // Chat ID'yi alfabetik sıraya göre oluştur (örn: userA_userB)
              // Böylece her iki kullanıcı da aynı ID'yi bulur.
              final ids = [myUid, otherUid];
              ids.sort();
              final chatId = ids.join("_");

              return MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: chatId, // Artık chatId gönderiyoruz
                  otherUserId: otherUid,
                  otherUserName: args['otherUserName'],
                ),
              );
            }
            break;

          case '/postDetail':
            final id = _extractId(settings.arguments);
            if (id != null) return MaterialPageRoute(builder: (_) => PostDetailScreen(postId: id));
            break;
          case '/publicExpertProfile':
            final id = _extractId(settings.arguments);
            if (id != null) return MaterialPageRoute(builder: (_) => ExpertPublicProfileScreen(expertId: id));
            break;
          case '/publicClientProfile':
            final id = _extractId(settings.arguments);
            if (id != null) return MaterialPageRoute(builder: (_) => PublicClientProfileScreen(clientId: id));
            break;
          case '/solveTest':
            final args = settings.arguments;
            if (args is Map<String, dynamic>) return MaterialPageRoute(builder: (_) => SolveTestScreen(testData: args));
            break;
          case '/resultDetail':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(builder: (_) => ResultDetailScreen(
              testTitle: args?['testTitle'] ?? 'Test Sonucu',
              aiAnalysis: args?['aiAnalysis'] ?? '',
              solvedAt: args?['createdAt'] is Timestamp ? (args!['createdAt'] as Timestamp).toDate() : null,
              questions: args?['questions'] as List<dynamic>?,
              answers: args?['answers'] as List<dynamic>?,
              testId: args?['testId'] as String?,
            ));
          case '/expertTestDetail':
            final id = _extractId(settings.arguments);
            if (id != null) return MaterialPageRoute(builder: (_) => ExpertTestDetailScreen(testId: id));
            break;
          case '/repostsQuotes':
            final id = _extractId(settings.arguments);
            if (id != null) return MaterialPageRoute(builder: (_) => RepostsQuotesListScreen(postId: id));
            break;
        }
        return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text("Sayfa bulunamadı"))));
      },
    );
  }

  static String? _extractId(Object? args) {
    if (args == null) return null;
    if (args is String) return args;
    if (args is Map) return args['id'] ?? args['postId'] ?? args['expertId'] ?? args['clientId'] ?? args['testId'];
    return null;
  }
}