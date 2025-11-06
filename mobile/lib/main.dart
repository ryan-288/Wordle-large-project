import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/game_screen.dart';
import 'screens/verify_notice_screen.dart';
import 'screens/verify_code_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/game_history_screen.dart';

void main() {
  runApp(const WordleApp());
}

class WordleApp extends StatelessWidget {
  const WordleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wordle',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121213),
        brightness: Brightness.dark,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/game': (context) => const GameScreen(),
        '/verify': (context) => const VerifyNoticeScreen(),
        '/verify-code': (context) {
          final email = ModalRoute.of(context)!.settings.arguments as String? ?? '';
          return VerifyCodeScreen(email: email);
        },
        '/stats': (context) => const StatsScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/friends': (context) => const FriendsScreen(),
        '/history': (context) => const GameHistoryScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    checkAuth();
  }

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    
    if (userJson == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    
    // Parse user and check verification
    try {
      final user = json.decode(userJson);
      if (user['emailVerified'] == false) {
        Navigator.of(context).pushReplacementNamed('/verify');
      } else {
        Navigator.of(context).pushReplacementNamed('/game');
      }
    } catch (e) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121213),
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

