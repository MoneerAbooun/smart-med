import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 7, 207, 221),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF0394F4),
          secondary: const Color(0xFF7CCBFF),
          surface: const Color(0xFFF4F8FC),
          onPrimary: Colors.white,
          onSurface: const Color(0xFF1A2A36),
          secondaryContainer: const Color(0xFFE3F2FD),
          onSecondaryContainer: const Color(0xFF1A2A36),
          surfaceContainerHighest: const Color(0xFFE9EEF3),
          outlineVariant: const Color(0xFFB7C4D1),
        ),

    scaffoldBackgroundColor: const Color(0xFF85C1E9),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      foregroundColor: Colors.white,
      backgroundColor: Color(0xFF2980B9),
    ),

    cardTheme: CardThemeData(
      color: const Color(0xFFF7F7F7),
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFE9EEF3),
      hintStyle: const TextStyle(color: Color(0xFF6B7C87)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB7C4D1)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0394F4), width: 1.8),
      ),

      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF2980B9),
        foregroundColor: Colors.white,
        minimumSize: const Size(130, 48),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),

    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: Color(0xFF1A2A36),
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: TextStyle(color: Color(0xFF1A2A36), fontSize: 15),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF4DB6FF),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF4DB6FF),
          secondary: const Color(0xFF7FD0FF),
          surface: const Color(0xFF1A2733),
          onPrimary: const Color(0xFF08131A),
          onSurface: Colors.white,
          secondaryContainer: const Color(0xFF203544),
          onSecondaryContainer: Colors.white,
          surfaceContainerHighest: const Color(0xFF223241),
          outlineVariant: const Color(0xFF506373),
        ),

    scaffoldBackgroundColor: const Color.fromARGB(255, 9, 23, 34),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      foregroundColor: Colors.white,
      backgroundColor: Color(0xFF2980B9),
    ),

    cardTheme: CardThemeData(
      color: const Color(0xFF1A2733),
      elevation: 5,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF223241),
      hintStyle: const TextStyle(color: Color(0xFF9DB2BF)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF506373)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF4DB6FF), width: 1.8),
      ),

      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF2980B9),
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
        minimumSize: const Size(130, 48),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),

    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: TextStyle(color: Colors.white, fontSize: 15),
    ),
  );
}
