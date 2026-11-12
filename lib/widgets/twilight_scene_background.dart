import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum TwilightSceneMode {
  header,    // Top 35% banner fading into content
  fullBleed, // Entire screen for Now Playing with dark scrim
  subtle,    // Lower opacity ambient background
}

/// Custom-painted multi-layered Twilight Calm landscape background.
/// Renders aesthetic layered mountain silhouettes, dusk sky gradients,
/// pine forest ridges, and tranquil lake reflections matching the reference design.
class TwilightSceneBackground extends StatelessWidget {
  final Widget? child;
  final TwilightSceneMode mode;
  final double? height;
  final double opacity;

  const TwilightSceneBackground({
    super.key,
    this.child,
    this.mode = TwilightSceneMode.header,
    this.height,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final effectiveHeight = height ??
        (mode == TwilightSceneMode.header
            ? screenHeight * 0.38
            : screenHeight);

    return Stack(
      children: [
        // Base Deep Slate Page Canvas
        Positioned.fill(
          child: Container(
            color: AppColors.bgDeep,
          ),
        ),

        // Illustrated Twilight Landscape Custom Painter
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: effectiveHeight,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: CustomPaint(
              size: Size(double.infinity, effectiveHeight),
              painter: _TwilightLandscapePainter(isFullBleed: mode == TwilightSceneMode.fullBleed),
            ),
          ),
        ),

        // Smooth downward gradient fade into page content
        if (mode == TwilightSceneMode.header)
          Positioned(
            top: effectiveHeight * 0.45,
            left: 0,
            right: 0,
            height: effectiveHeight * 0.55 + 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.bgDeep.withValues(alpha: 0.65),
                    AppColors.bgDeep.withValues(alpha: 0.95),
                    AppColors.bgDeep,
                  ],
                  stops: const [0.0, 0.45, 0.8, 1.0],
                ),
              ),
            ),
          ),

        // Full Bleed Scrim for Player readability
        if (mode == TwilightSceneMode.fullBleed)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bgDeep.withValues(alpha: 0.35),
                    AppColors.bgDeep.withValues(alpha: 0.60),
                    AppColors.bgDeep.withValues(alpha: 0.88),
                    AppColors.bgDeep.withValues(alpha: 0.96),
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),

        // Foreground Content
        if (child != null)
          Positioned.fill(child: child!),
      ],
    );
  }
}

/// High-performance Vector Painter rendering layered mountains & serene lake reflections
class _TwilightLandscapePainter extends CustomPainter {
  final bool isFullBleed;

  _TwilightLandscapePainter({this.isFullBleed = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Sky Gradient (Sunset Coral -> Dusty Rose -> Twilight Violet)
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF6A4C6), // Coral rose top
          Color(0xFFE277AE), // Sunset magenta
          Color(0xFFA259A8), // Orchid violet
          Color(0xFF6B45A8), // Deep purple
          Color(0xFF382368), // Twilight indigo
        ],
        stops: [0.0, 0.22, 0.48, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // 2. Distant Sun / Twilight Celestial Glow
    final sunCenter = Offset(w * 0.42, h * 0.28);
    final sunGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD5E5).withValues(alpha: 0.7),
          const Color(0xFFF6A4C6).withValues(alpha: 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: w * 0.35));
    canvas.drawCircle(sunCenter, w * 0.35, sunGlow);

    // 3. Farthest Mountain Silhouette (Soft Pink / Lilac)
    final m1 = Paint()..color = const Color(0xFFE070A8).withValues(alpha: 0.85);
    final p1 = Path();
    p1.moveTo(0, h * 0.42);
    p1.lineTo(w * 0.18, h * 0.32);
    p1.lineTo(w * 0.40, h * 0.22); // Majestic distant peak
    p1.lineTo(w * 0.62, h * 0.35);
    p1.lineTo(w * 0.85, h * 0.29);
    p1.lineTo(w, h * 0.38);
    p1.lineTo(w, h);
    p1.lineTo(0, h);
    p1.close();
    canvas.drawPath(p1, m1);

    // 4. Midground Mountain Layer 2 (Velvet Orchid)
    final m2 = Paint()..color = const Color(0xFFA8559E);
    final p2 = Path();
    p2.moveTo(0, h * 0.50);
    p2.lineTo(w * 0.22, h * 0.38);
    p2.lineTo(w * 0.48, h * 0.46);
    p2.lineTo(w * 0.72, h * 0.34);
    p2.lineTo(w * 0.90, h * 0.44);
    p2.lineTo(w, h * 0.48);
    p2.lineTo(w, h);
    p2.lineTo(0, h);
    p2.close();
    canvas.drawPath(p2, m2);

    // 5. Mountain Layer 3 (Deep Twilight Violet with Pine ridges)
    final m3 = Paint()..color = const Color(0xFF673F9E);
    final p3 = Path();
    p3.moveTo(0, h * 0.60);
    p3.lineTo(w * 0.15, h * 0.52);
    p3.lineTo(w * 0.35, h * 0.58);
    p3.lineTo(w * 0.58, h * 0.48);
    p3.lineTo(w * 0.82, h * 0.56);
    p3.lineTo(w, h * 0.52);
    p3.lineTo(w, h);
    p3.lineTo(0, h);
    p3.close();
    canvas.drawPath(p3, m3);

    // 6. Foreground Forest Silhouette (Midnight Indigo with pine trees silhouette)
    final m4 = Paint()..color = const Color(0xFF2B1D58);
    final p4 = Path();
    p4.moveTo(0, h * 0.70);

    // Forest pine tooth effect on left side
    for (double x = 0; x <= w * 0.45; x += 14) {
      final treeHeight = 12.0 + 8.0 * math.sin(x / 20.0);
      p4.lineTo(x + 7, h * 0.68 - treeHeight);
      p4.lineTo(x + 14, h * 0.68);
    }
    p4.lineTo(w * 0.60, h * 0.72);
    // Forest pine tooth effect on right side
    for (double x = w * 0.60; x <= w; x += 16) {
      final treeHeight = 10.0 + 10.0 * math.cos(x / 18.0);
      p4.lineTo(x + 8, h * 0.70 - treeHeight);
      p4.lineTo(x + 16, h * 0.70);
    }
    p4.lineTo(w, h);
    p4.lineTo(0, h);
    p4.close();
    canvas.drawPath(p4, m4);

    // 7. Water / Lake Mirror Base with Horizontal Glint Reflections
    final lakeY = h * 0.74;
    final lakePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF5D4294),
          const Color(0xFF321E5C),
          const Color(0xFF191036),
          AppColors.bgDeep,
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, lakeY, w, h - lakeY));
    canvas.drawRect(Rect.fromLTWH(0, lakeY, w, h - lakeY), lakePaint);

    // Gentle Water Reflection Glints
    final glintPaint = Paint()
      ..color = const Color(0xFFE277AE).withValues(alpha: 0.18)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(w * 0.25, lakeY + 8), Offset(w * 0.65, lakeY + 8), glintPaint);
    canvas.drawLine(Offset(w * 0.35, lakeY + 18), Offset(w * 0.55, lakeY + 18), glintPaint);
    canvas.drawLine(Offset(w * 0.15, lakeY + 28), Offset(w * 0.40, lakeY + 28), glintPaint);
    canvas.drawLine(Offset(w * 0.50, lakeY + 36), Offset(w * 0.75, lakeY + 36), glintPaint);
  }

  @override
  bool shouldRepaint(covariant _TwilightLandscapePainter oldDelegate) => false;
}
