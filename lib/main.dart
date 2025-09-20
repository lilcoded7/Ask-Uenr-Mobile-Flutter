import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// import your pages
import 'pages/LoginPage.dart';
import 'pages/SignUpPage.dart';
import 'pages/AskUnerPage.dart';

void main() {
  runApp(const AskUnerApp());
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
}

/// ----------------- Splash Page -----------------
/// Decides where to navigate based on login state
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool("is_logged_in") ?? false;
    final storedEmail = prefs.getString("user_email");
    final storedPassword = prefs.getString("user_password");

    // If user has credentials and is_logged_in flag, go to AskUner page
    if (isLoggedIn && storedEmail != null && storedPassword != null) {
      Navigator.pushReplacementNamed(context, '/askuner');
    } else if (storedEmail != null && storedPassword != null) {
      // If credentials exist but not logged in, go to Login
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      // No credentials -> go to SignUp
      Navigator.pushReplacementNamed(context, '/signup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// ----------------- Main App -----------------
class AskUnerApp extends StatelessWidget {
  const AskUnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AskUner - UENR Virtual Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: IconThemeData(color: Color(0xFF1A4D2B)),
        ),
      ),

      /// Start with SplashPage
      initialRoute: '/splash',

      /// Register routes
      routes: {
        '/splash': (context) => const SplashPage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/askuner': (context) => const AskUnerPage(),
      },
    );
  }
}
