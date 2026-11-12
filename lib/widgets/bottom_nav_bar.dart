import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_motion.dart';

/// Stationary Bottom Navigation Bar docked to the screen bottom.
/// Designed for the Twilight Calm design system:
/// Full-width docked bar, rounded top corners, safe-area padding,
/// and a gliding elevated active circular indicator pill.
class TwilightBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> icons;

  const TwilightBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    const barHeight = 64.0;

    return Container(
      width: double.infinity,
      height: barHeight + bottomSafe,
      padding: EdgeInsets.only(bottom: bottomSafe),
      decoration: BoxDecoration(
        color: AppColors.surface1.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: AppColors.surface2.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / icons.length;
          final pillSize = 52.0;
          final pillLeft = (currentIndex * itemWidth) + (itemWidth - pillSize) / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Gliding Active Raised Circular Pill (rising slightly above bar)
              AnimatedPositioned(
                duration: AppMotion.durationMedium,
                curve: AppMotion.curveEmphasizedDecelerate,
                left: pillLeft,
                top: -10,
                child: Container(
                  width: pillSize,
                  height: pillSize,
                  decoration: BoxDecoration(
                    color: AppColors.bgDeep,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primarySoft.withValues(alpha: 0.4),
                        blurRadius: 14,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                      const BoxShadow(
                        color: Colors.black45,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: AppColors.primarySoft,
                      width: 2,
                    ),
                  ),
                ),
              ),

              // Icon Row
              Row(
                children: List.generate(icons.length, (index) {
                  final isActive = index == currentIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!isActive) {
                          HapticFeedback.lightImpact();
                          onTap(index);
                        }
                      },
                      child: Center(
                        child: AnimatedContainer(
                          duration: AppMotion.durationBase,
                          transform: Matrix4.translationValues(0, isActive ? -10 : 0, 0),
                          child: Icon(
                            icons[index],
                            size: 26,
                            color: isActive ? AppColors.iconActive : AppColors.iconIdle,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
