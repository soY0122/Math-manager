import 'package:flutter/material.dart';

class AppTheme {
  // Light Mode Colors
  static const Color lightPrimary = Color(0xFF1E88E5); // Bright Blue
  static const Color lightSecondary = Color(0xFF42A5F5); // Lighter Blue
  static const Color lightBackground = Colors.white;
  static const Color lightSurface = Color(0xFFF5F7FA); // Soft gray/blue surface
  static const Color lightCardColor = Colors.white;
  static const Color lightTextPrimary = Color(0xFF1A1C1E);
  static const Color lightTextSecondary = Color(0xFF5C6066);

  // Dark Mode Colors
  static const Color darkPrimary = Color(0xFF90CAF9); // Light Blue for dark contrast
  static const Color darkSecondary = Color(0xFF64B5F6);
  static const Color darkBackground = Color(0xFF121417);
  static const Color darkSurface = Color(0xFF1A1C1E);
  static const Color darkCardColor = Color(0xFF22252A);
  static const Color darkTextPrimary = Color(0xFFE2E2E6);
  static const Color darkTextSecondary = Color(0xFFC2C6CE);

  // Status Colors (Shared)
  static const Color attendanceColor = Color(0xFF4CAF50); // Green
  static const Color lateColor = Color(0xFFFF9800); // Orange
  static const Color absentColor = Color(0xFFF44336); // Red
  static const Color leaveColor = Color(0xFF9C27B0); // Purple
  
  static const Color homeworkCompleted = Color(0xFF4CAF50);
  static const Color homeworkPartial = Color(0xFFFFB74D);
  static const Color homeworkIncomplete = Color(0xFFEF5350);

  // Light Theme Configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: lightPrimary,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: lightSecondary,
        surface: lightSurface,
        background: lightBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
        onBackground: lightTextPrimary,
        error: Color(0xFFBA1A1A),
      ),
      cardTheme: CardThemeData(
        color: lightCardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: Colors.grey.shade200, width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightBackground,
        selectedItemColor: lightPrimary,
        unselectedItemColor: Color(0xFF8E9199),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: lightTextPrimary, fontFamily: 'Outfit'),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: lightTextPrimary, fontFamily: 'Outfit'),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: lightTextPrimary, fontFamily: 'Inter'),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: lightTextPrimary, fontFamily: 'Inter'),
        bodyLarge: TextStyle(fontSize: 16, color: lightTextPrimary, fontFamily: 'Inter'),
        bodyMedium: TextStyle(fontSize: 14, color: lightTextSecondary, fontFamily: 'Inter'),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: lightPrimary, fontFamily: 'Inter'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: lightPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: lightTextSecondary, fontSize: 14, fontFamily: 'Inter'),
        hintStyle: const TextStyle(color: Color(0xFF8E9199), fontSize: 14, fontFamily: 'Inter'),
      ),
    );
  }

  // Dark Theme Configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: darkPrimary,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkSecondary,
        surface: darkSurface,
        background: darkBackground,
        onPrimary: Color(0xFF0F3057),
        onSecondary: Color(0xFF0F3057),
        onSurface: darkTextPrimary,
        onBackground: darkTextPrimary,
        error: Color(0xFFFFB4AB),
      ),
      cardTheme: CardThemeData(
        color: darkCardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: Color(0xFF2E3135), width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkBackground,
        selectedItemColor: darkPrimary,
        unselectedItemColor: Color(0xFF8E9199),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: darkTextPrimary, fontFamily: 'Outfit'),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkTextPrimary, fontFamily: 'Outfit'),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: darkTextPrimary, fontFamily: 'Inter'),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkTextPrimary, fontFamily: 'Inter'),
        bodyLarge: TextStyle(fontSize: 16, color: darkTextPrimary, fontFamily: 'Inter'),
        bodyMedium: TextStyle(fontSize: 14, color: darkTextSecondary, fontFamily: 'Inter'),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: darkPrimary, fontFamily: 'Inter'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: const Color(0xFF0F3057),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: darkPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: darkTextSecondary, fontSize: 14, fontFamily: 'Inter'),
        hintStyle: const TextStyle(color: Color(0xFF8E9199), fontSize: 14, fontFamily: 'Inter'),
      ),
    );
  }
}
