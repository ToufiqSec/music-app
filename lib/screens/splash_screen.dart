import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Swarva Official Splash Screen
///
/// Implements the Swarva App Icon and Splash Screen Spec:
/// - Brand Background: #121014 with subtle violet/coral ambient radial glow
/// - Icon Entrance: S-ribbon scales gently from 90% to 100% and fades in over 500ms
/// - Title Entrance: "Swarva" fades in beneath the icon in clean off-white with generous letter spacing
/// - Respects reduced motion settings
/// - Zero color jump, zero white/black flash on transition
class SwarvaSplashScreen extends StatefulWidget {
  const SwarvaSplashScreen({super.key});

  @override
  State<SwarvaSplashScreen> createState() => _SwarvaSplashScreenState();
}

class _SwarvaSplashScreenState extends State<SwarvaSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<double> _textSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Icon entrance: 0% to 60% of timeline (0 - 540ms), scale 90% -> 100%
    _iconScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOut),
      ),
    );

    // Text entrance: 35% to 85% of timeline (315 - 765ms)
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<double>(begin: 6.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // Start entrance animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect system setting for reduced motion
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.swarvaBgDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Subtle background radial glow (soft violet & coral hint on dark)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.0, -0.1),
                    radius: 0.85,
                    colors: [
                      Color(0xFF1E1728), // Faint violet glow
                      Color(0xFF121014), // Brand dark background #121014
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // Centered Icon & Swarva Typography
            Center(
              child: reduceMotion
                  ? _buildStaticContent()
                  : AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return _buildAnimatedContent();
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // S-Ribbon Icon with soft ease-out scale & fade
        Opacity(
          opacity: _iconOpacity.value,
          child: Transform.scale(
            scale: _iconScale.value,
            child: SizedBox(
              width: 140,
              height: 140,
              child: Image.asset(
                'assets/icon/splash_icon.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.music_note_rounded,
                  size: 90,
                  color: AppColors.swarvaCoral,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // "Swarva" Brand Typography in clean off-white with generous letter spacing
        Opacity(
          opacity: _textOpacity.value,
          child: Transform.translate(
            offset: Offset(0, _textSlide.value),
            child: const Text(
              'Swarva',
              style: TextStyle(
                fontFamily: 'sans-serif',
                color: AppColors.swarvaOffWhite,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 4.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaticContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Image.asset(
            'assets/icon/splash_icon.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.music_note_rounded,
              size: 90,
              color: AppColors.swarvaCoral,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Swarva',
          style: TextStyle(
            fontFamily: 'sans-serif',
            color: AppColors.swarvaOffWhite,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 4.5,
          ),
        ),
      ],
    );
  }
}
