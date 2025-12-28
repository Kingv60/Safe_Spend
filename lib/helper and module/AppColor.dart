import 'package:flutter/material.dart';

/// Central place to manage all app colors.
/// Use these constants across the app to ensure consistency.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ✅ Primary Brand Colors
  static const Color primary   = Color(0xFF4A90E2);
  static const Color navColor = Color(0xFF8F87F1);
  static const Color accent    = Color(0xffB7B1F2);

  // ✅ Neutral Palette
  static const Color white      = Color(0xFFFFFFFF);
  static const Color blackz     = Color(0xff393E46);
  static const Color greyLight  = Color(0xFFF5F5F5);
  static const Color grey       = Color(0xFF9E9E9E);
  static const Color greyDark   = Color(0xFF424242);
  static Color greyShade  = Color(0xffC7F8F2);//Color(0xff757575).withOpacity(0.1);

  // ✅ Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error   = Color(0xFFF44336);
  static const Color info    = Color(0xFF2196F3);

  // ✅ Backgrounds
  static const Color scaffoldBackground = Color(0xFFF0F2F5);
  static const Color cardBackground     = Color(0xFFFFFFFF);

  // ✅ Overlays
  static const Color overlayLight = Color.fromRGBO(0, 0, 0, 0.05);
  static const Color overlayDark  = Color.fromRGBO(0, 0, 0, 0.4);
}
