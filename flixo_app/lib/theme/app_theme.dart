import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background    = Color(0xFF0A0A0A);
  static const surface       = Color(0xFF141414);
  static const card          = Color(0xFF1A1A1A);
  static const accent        = Color(0xFFFFB800); // golden yellow
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF999999);
  static const textMuted     = Color(0xFF555555);
  static const live          = Color(0xFFE50914);
  static const border        = Color(0xFF2A2A2A);
  static const navBg         = Color(0xFF0F0F0F);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      surface: AppColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(

      backgroundColor: AppColors.navBg,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 10),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
  );
}
