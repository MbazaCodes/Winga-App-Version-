import 'package:flutter/material.dart';

class AppColors {
  static const primaryGreen = Color(0xFF1A5C2A);
  static const accentAmber = Color(0xFFF9A825);
  static const surface = Color(0xFFF7F7F7);
  static const textPrimary = Color(0xFF1E1E1E);
  static const textSecondary = Color(0xFF6B6B6B);
}

class AppTextStyles {
  static const headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 16,
    color: AppColors.textSecondary,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryGreen),
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: const TextTheme(
        headlineLarge: AppTextStyles.headline,
        bodyLarge: AppTextStyles.body,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData.dark(useMaterial3: true);
  }
}
