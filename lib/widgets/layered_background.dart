import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

enum BackgroundIntensity { soft, medium, strong }

enum BackgroundScene { none, mountains, lake, forest }

/// Declarative multi-layer background from Section 3 of Universal UI Design System: Twilight Calm.
class LayeredBackground extends StatefulWidget {
  final Widget child;
  final bool hasHeroGlow; // L1
  final bool hasIllustration; // L2
  final bool hasScrim; // L3
  final bool isPlayerScreen; // Uses playerGradient instead of pageGradient
  final BackgroundScene scene;
  final BackgroundIntensity intensity;

  const LayeredBackground({
    super.key,
    required this.child,
    this.hasHeroGlow = false,
    this.hasIllustration = false,
    this.hasScrim = false,
    this.isPlayerScreen = false,
    this.scene = BackgroundScene.mountains,
    this.intensity = BackgroundIntensity.soft,
  });

  @override
  State<LayeredBackground> createState() => _LayeredBackgroundState();
}

class _LayeredBackgroundState extends State<LayeredBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _driftController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _driftController = AnimationController(
      vsync: this,
      duration: AppMotion.durationAmbient,
    );

    if (widget.hasIllustration) {
      _driftController.repeat(reverse: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.hasIllustration) {
      _driftController.repeat(reverse: true);
    } else if (state == AppLifecycleState.paused) {
      _driftController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _driftController.dispose();
    super.dispose();
  }

  double get _heroGlowOpacity {
    switch (widget.intensity) {
      case BackgroundIntensity.soft:
        return 0.0;
      case BackgroundIntensity.medium:
        return 0.70;
      case BackgroundIntensity.strong:
        return 1.0;
    }
  }

  double get _illustrationOpacity {
    switch (widget.intensity) {
      case BackgroundIntensity.soft:
        return 0.0;
      case BackgroundIntensity.medium:
        return 0.85;
      case BackgroundIntensity.strong:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // L0: Base Gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: widget.isPlayerScreen
                  ? AppColors.playerGradient
                  : AppColors.pageGradient,
            ),
          ),
        ),

        // L1: Hero Glow (Top 32% of screen)
        if (widget.hasHeroGlow && _heroGlowOpacity > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.32,
            child: Opacity(
              opacity: _heroGlowOpacity,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.heroGradient,
                ),
              ),
            ),
          ),

        // L2: Vector Silhouette Scenery
        if (widget.hasIllustration && _illustrationOpacity > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: widget.isPlayerScreen
                ? MediaQuery.of(context).size.height
                : MediaQuery.of(context).size.height * 0.35,
            child: Opacity(
              opacity: _illustrationOpacity,
              child: AnimatedBuilder(
                animation: _driftController,
                builder: (context, _) {
                  final shift = (_driftController.value - 0.5) * 12.0; // max 6px drift
                  return CustomPaint(
                    painter: _MountainSceneryPainter(horizontalShift: shift),
                  );
                },
              ),
            ),
          ),

        // L3: Scrim for text legibility
        if (widget.hasScrim)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.40,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.scrim,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

        // L4: Real Content
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

/// Flat vector silhouette mountain and forest painter from Section 3.
class _MountainSceneryPainter extends CustomPainter {
  final double horizontalShift;

  _MountainSceneryPainter({this.horizontalShift = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Layer 1: Farthest Mountain (#E070A8)
    final p1 = Paint()..color = AppColors.mountainFarthest;
    final path1 = Path()
      ..moveTo(0, h * 0.45)
      ..cubicTo(w * 0.25 + horizontalShift, h * 0.25, w * 0.45 + horizontalShift, h * 0.35, w * 0.65, h * 0.20)
      ..cubicTo(w * 0.85, h * 0.30, w * 0.95, h * 0.40, w, h * 0.45)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path1, p1);

    // Layer 2: Mountain (#A8559E)
    final p2 = Paint()..color = AppColors.mountainLayer2;
    final path2 = Path()
      ..moveTo(0, h * 0.55)
      ..cubicTo(w * 0.2, h * 0.40, w * 0.5, h * 0.38, w * 0.75, h * 0.50)
      ..lineTo(w, h * 0.60)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path2, p2);

    // Layer 3: Mountain (#7A4FB8)
    final p3 = Paint()..color = AppColors.mountainLayer3;
    final path3 = Path()
      ..moveTo(0, h * 0.65)
      ..cubicTo(w * 0.35, h * 0.52, w * 0.6, h * 0.68, w, h * 0.58)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path3, p3);

    // Layer 4: Mountain (#4A3D96)
    final p4 = Paint()..color = AppColors.mountainLayer4;
    final path4 = Path()
      ..moveTo(0, h * 0.75)
      ..cubicTo(w * 0.4, h * 0.65, w * 0.7, h * 0.78, w, h * 0.72)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path4, p4);

    // Layer 5: Nearest Mountain & Forest Foreground (#231A52)
    final p5 = Paint()..color = AppColors.forestForeground;
    final path5 = Path()
      ..moveTo(0, h * 0.82)
      ..lineTo(w * 0.15, h * 0.80)
      ..lineTo(w * 0.18, h * 0.76) // Pine tree notch
      ..lineTo(w * 0.21, h * 0.80)
      ..lineTo(w * 0.45, h * 0.79)
      ..lineTo(w * 0.48, h * 0.74) // Pine tree notch
      ..lineTo(w * 0.51, h * 0.80)
      ..lineTo(w * 0.80, h * 0.83)
      ..lineTo(w * 0.83, h * 0.77) // Pine tree notch
      ..lineTo(w * 0.86, h * 0.83)
      ..lineTo(w, h * 0.84)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path5, p5);
  }

  @override
  bool shouldRepaint(covariant _MountainSceneryPainter oldDelegate) {
    return oldDelegate.horizontalShift != horizontalShift;
  }
}
