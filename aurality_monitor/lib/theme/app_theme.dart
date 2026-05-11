import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Brand Colors ───────────────────────────────────────────────────────────
class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0D0D0F);
  static const Color surface = Color(0xFF16161A);
  static const Color surfaceElevated = Color(0xFF1E1E24);

  // Glass overlay
  static const Color glassWhite = Color(0x14FFFFFF);
  static const Color glassBorder = Color(0x26FFFFFF);

  // Neon Accents — Priority
  static const Color accentRed = Color(0xFFFF3B3B); // HIGH  – Glass Break
  static const Color accentAmber = Color(
    0xFFFFB800,
  ); // MEDIUM – Shouting / Alarm
  static const Color accentCyan = Color(0xFF00E5FF); // LOW   – System status

  // Text
  static const Color textPrimary = Color(0xFFEEEEEE);
  static const Color textSecondary = Color(0xFF8A8A9A);
  static const Color textMuted = Color(0xFF4A4A5A);

  // Utility
  static const Color divider = Color(0x1AFFFFFF);
  static const Color iconDismiss = Color(0x99FF3B3B);
}

// ─── Glassmorphism Helper ─────────────────────────────────────────────────
class GlassDecoration extends BoxDecoration {
  GlassDecoration({Color? borderColor, double radius = 20, Color? fill})
    : super(
        color: fill ?? AppColors.glassWhite,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppColors.glassBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      );
}

// ─── Theme ────────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accentCyan,
        secondary: AppColors.accentAmber,
        error: AppColors.accentRed,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      dividerColor: AppColors.divider,
    );
  }

  // Convenience: priority color from string
  static Color priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.accentRed;
      case 'medium':
        return AppColors.accentAmber;
      default:
        return AppColors.accentCyan;
    }
  }

  // Convenience: priority icon
  static IconData priorityIcon(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'glass_break':
      case 'glass break':
        return Icons.broken_image_rounded;
      case 'shouting':
      case 'scream':
        return Icons.record_voice_over_rounded;
      case 'alarm':
      case 'smoke_alarm':
        return Icons.sensors_rounded;
      case 'baby_cry':
      case 'baby crying':
        return Icons.child_care_rounded;
      default:
        return Icons.graphic_eq_rounded;
    }
  }
}
