import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF0B0E14);
  static const Color surface = Color(0xFF131824);
  static const Color surfaceElevated = Color(0xFF1B2232);
  static const Color surfaceLight = Color(0xFF232B3E);
  
  // Borders & Dividers
  static const Color border = Color(0xFF263043);
  static const Color borderHighlight = Color(0xFF3B4864);

  // Brand / Purple Gradient
  static const Color primaryPurple = Color(0xFF7928CA);
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color accentPink = Color(0xFFEC4899);

  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient vibrantPurpleGradient = LinearGradient(
    colors: [Color(0xFF9333EA), Color(0xFF4F46E5)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient glowGradient = LinearGradient(
    colors: [Color(0x338B5CF6), Color(0x3338BDF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Platform Brand Colors
  static const Color tiktok = Color(0xFFFE2C55);
  static const Color instagram = Color(0xFFE1306C);
  static const Color youtube = Color(0xFFFF0000);
  static const Color twitter = Color(0xFF1D9BF0);
  static const Color facebook = Color(0xFF1877F2);
}
