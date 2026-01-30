import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const BaymaxApp(),
    ),
  );
}

class BaymaxApp extends StatelessWidget {
  const BaymaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDark = themeService.isDarkMode;
        
        return MaterialApp(
          title: 'Baymax Health',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Roboto',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1A1A1A),
              primary: const Color(0xFF1A1A1A),
              surface: const Color(0xFFF5F5F5),
              background: const Color(0xFFF5F5F5),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            cardTheme: CardThemeData(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFF0F0F0)),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1A1A1A),
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              iconTheme: IconThemeData(color: Colors.white),
            ),
            textTheme: const TextTheme(
              headlineLarge: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w700, fontSize: 32),
              titleLarge: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600, fontSize: 20),
              bodyLarge: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500, fontSize: 15),
              bodyMedium: TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w400, fontSize: 13),
              labelLarge: TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Roboto',
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.white,
              primary: Colors.white,
              surface: const Color(0xFF2C2C2C),
              background: const Color(0xFF121212),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardTheme: CardThemeData(
              elevation: 0,
              color: const Color(0xFF1C1C1C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF2C2C2C)),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF000000),
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              iconTheme: IconThemeData(color: Colors.white),
            ),
            textTheme: const TextTheme(
              headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 32),
              titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
              bodyLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15),
              bodyMedium: TextStyle(color: Color(0xFFAAAAAA), fontWeight: FontWeight.w400, fontSize: 13),
              labelLarge: TextStyle(color: Color(0xFFAAAAAA), fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasData) return const MainNavigation();
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}
