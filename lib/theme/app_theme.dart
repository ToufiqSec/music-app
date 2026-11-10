import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_radii.dart';
import 'app_spacing.dart';

/// Central ThemeData assembly for Universal UI Design System: Twilight Calm.
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgBase,
      primaryColor: AppColors.primary,
      canvasColor: AppColors.bgDeep,
      cardColor: AppColors.surface1,
      dividerColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.bgDeep,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: AppTextStyles.screenTitle,
        iconTheme: const IconThemeData(color: AppColors.iconActive, size: 24),
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primarySoft,
        surface: AppColors.surface1,
        surfaceContainerHighest: AppColors.surface2,
        error: AppColors.error,
        onPrimary: AppColors.textPrimary,
        onSecondary: AppColors.textPrimary,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayTitle,
        titleLarge: AppTextStyles.screenTitle,
        titleMedium: AppTextStyles.sectionTitle,
        titleSmall: AppTextStyles.cardTitle,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.subtitle,
        labelLarge: AppTextStyles.buttonLabel,
        labelSmall: AppTextStyles.meta,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.iconIdle,
        size: 24,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: AppRadii.rXL),
        ),
      ),
    );
  }
}
