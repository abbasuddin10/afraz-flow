import 'package:flutter/material.dart';

/// The Afraz Flow brand mark, shared by the splash, auth and app shell surfaces.
///
/// The source artwork lives in `assets/images/app_logo_mark.png` and is
/// generated from `assets/images/app_logo.jpg` so every platform and every
/// in-app logo use the same asset.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({
    super.key,
    this.size = 40,
    this.radius,
    this.shadow = false,
  });

  static const String assetPath = 'assets/images/app_logo_mark.png';

  final double size;

  /// Corner radius of the logo tile. Defaults to 28% of [size].
  final double? radius;

  /// Adds a soft drop shadow behind the logo tile.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius ?? size * 0.28),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: size * 0.45,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
