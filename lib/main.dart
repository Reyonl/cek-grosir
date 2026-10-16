import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.init();
  runApp(const CekGrosirApp());
}

class CekGrosirApp extends StatelessWidget {
  const CekGrosirApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme emeraldScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF059669),
      primary: const Color(0xFF047857),
      secondary: const Color(0xFFD97706),
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'CekGrosir - Kalkulator Kulakan Warung',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: emeraldScheme,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF065F46),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
