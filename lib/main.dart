import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

      // 👇 Default page is login
      initialRoute: '/login',

      // 👇 Register routes
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/askuner': (context) => const AskUnerPage(),
      },
    );
  }
}
