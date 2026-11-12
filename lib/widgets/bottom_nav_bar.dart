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
      padding: EdgeInsets.only(bottom: bottomSafe, left: 12, right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1633).withValues(alpha: 0.98),
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
            color: AppColors.surface2.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                  curve: AppMotion.curveStandard,
                  padding: EdgeInsets.symmetric(
                    horizontal: isActive ? 16 : 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primarySoft.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive
                          ? AppColors.primarySoft.withValues(alpha: 0.45)
                          : Colors.transparent,
                      width: 1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icons[index],
                    size: 24,
                    color: isActive ? Colors.white : AppColors.iconIdle,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
