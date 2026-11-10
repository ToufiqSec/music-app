import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';

/// Glassmorphism circular utility button from Section 7 of Universal UI Design System: Twilight Calm.
class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color iconColor;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44.0,
    this.iconColor = AppColors.iconActive,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: ClipRRect(
          borderRadius: AppRadii.borderFull,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppShadows.glassBlurSigma,
              sigmaY: AppShadows.glassBlurSigma,
            ),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppShadows.glassFill,
                border: Border.all(
                  color: AppShadows.glassBorderColor,
                  width: AppShadows.glassBorderWidth,
                ),
              ),
              child: Icon(
                widget.icon,
                size: 22,
                color: widget.iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
