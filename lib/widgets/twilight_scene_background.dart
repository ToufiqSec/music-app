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

/// High-performance Vector Painter rendering deep cosmic liquid aurora & diagonal glassmorphism light beams
/// perfectly aligned with the Reference UI (Dark Purple, Soft Pink & Glossy Liquid UI).
class _TwilightLandscapePainter extends CustomPainter {
  final bool isFullBleed;

  _TwilightLandscapePainter({this.isFullBleed = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Base Deep Canvas Gradient (#0B0A12 -> #130E26 -> #0B0A12)
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF110D22),
          Color(0xFF1B1438),
          Color(0xFF140F2B),
          Color(0xFF0B0A12),
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), basePaint);

    // 2. Ambient Deep Purple & Violet Radial Glow Orbs
    final orb1Center = Offset(w * 0.85, h * 0.18);
    final orb1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7955D9).withValues(alpha: 0.28),
          const Color(0xFF4C2F9E).withValues(alpha: 0.14),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: orb1Center, radius: w * 0.65));
    canvas.drawCircle(orb1Center, w * 0.65, orb1Paint);

    final orb2Center = Offset(w * 0.10, h * 0.45);
    final orb2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF9B4FD8).withValues(alpha: 0.20),
          const Color(0xFF381C6E).withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: orb2Center, radius: w * 0.55));
    canvas.drawCircle(orb2Center, w * 0.55, orb2Paint);

    // 3. Diagonal Liquid Luminous Streaks (Angled at ~32 degrees matching Reference UI)
    canvas.save();
    // Rotate canvas around center to paint natural diagonal light streaks
    canvas.translate(w * 0.5, h * 0.35);
    canvas.rotate(-0.55); // ~-31.5 degrees

    final streakPaints = [
      (
        Rect.fromLTWH(-w * 0.9, -h * 0.4, w * 0.35, h * 1.6),
        const Color(0xFF3D2775).withValues(alpha: 0.22),
      ),
      (
        Rect.fromLTWH(-w * 0.35, -h * 0.4, w * 0.50, h * 1.6),
        const Color(0xFF5E3AA8).withValues(alpha: 0.18),
      ),
      (
        Rect.fromLTWH(w * 0.30, -h * 0.4, w * 0.40, h * 1.6),
        const Color(0xFF7955D9).withValues(alpha: 0.15),
      ),
      (
        Rect.fromLTWH(w * 0.75, -h * 0.4, w * 0.25, h * 1.6),
        const Color(0xFF281852).withValues(alpha: 0.25),
      ),
    ];

    for (final streak in streakPaints) {
      final rect = streak.$1;
      final color = streak.$2;
      final p = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            color,
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, p);
    }
    canvas.restore();

    // 4. Subtle Top Liquid Specular Glow
    final specularPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE8A1D1).withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.25));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.25), specularPaint);
  }

  @override
  bool shouldRepaint(covariant _TwilightLandscapePainter oldDelegate) => false;
}
