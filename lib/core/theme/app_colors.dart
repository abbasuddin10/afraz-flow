import 'package:flutter/material.dart';

/// The Afraz Flow brand palette. A calm, professional navy base with a
/// high-contrast teal accent and warm amber for attention states.
class AppColors {
  const AppColors._();

  static const Color navy = Color(0xFF0F2C4C);
  static const Color navyDeep = Color(0xFF081D33);
  static const Color navySoft = Color(0xFF1D4A75);
  static const Color teal = Color(0xFF0FA3A3);
  static const Color tealDark = Color(0xFF087C7C);
  static const Color tealSoft = Color(0xFFD7F2F0);
  static const Color amber = Color(0xFFF2B84B);
  static const Color amberSoft = Color(0xFFFFF2D6);
  static const Color red = Color(0xFFD64545);
  static const Color redSoft = Color(0xFFFDE7E7);
  static const Color green = Color(0xFF2E9E5B);
  static const Color greenSoft = Color(0xFFE3F5EA);
  static const Color blue = Color(0xFF3D7EFF);
  static const Color blueSoft = Color(0xFFE7EFFF);
  static const Color purple = Color(0xFF7A5AF8);
  static const Color purpleSoft = Color(0xFFEFEBFF);
  static const Color surface = Color(0xFFF4F7FB);
  static const Color surfaceAlt = Color(0xFFEEF2F8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color ink = Color(0xFF14263D);
  static const Color inkMuted = Color(0xFF68788D);
  static const Color white = Color(0xFFFFFFFF);

  static const Color darkSurface = Color(0xFF0C1622);
  static const Color darkCard = Color(0xFF13202F);
  static const Color darkBorder = Color(0xFF243346);

  /// Chart series colours used consistently across the app.
  static const List<Color> chart = [
    teal,
    blue,
    amber,
    purple,
    Color(0xFFF0796A),
    navySoft,
  ];

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDeep, navy, navySoft],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, Color(0xFF14B8A6)],
  );
}
