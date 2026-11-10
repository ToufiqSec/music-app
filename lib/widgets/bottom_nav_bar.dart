import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_motion.dart';

/// Floating bottom navigation bar from Section 7 of Universal UI Design System: Twilight Calm.
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

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: 12 + bottomSafe,
      ),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadii.borderXL,
          boxShadow: const [AppShadows.shadowSoft],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / icons.length;
            final pillLeft = (currentIndex * itemWidth) + (itemWidth - 56) / 2;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Gliding Active Raised Pill (56x56, rising 6 above bar)
                AnimatedPositioned(
                  duration: AppMotion.durationMedium,
                  curve: AppMotion.curveEmphasizedDecelerate,
                  left: pillLeft,
                  top: -6,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.bgDeep,
                      shape: BoxShape.circle,
                      boxShadow: const [AppShadows.shadowSoft],
                      border: Border.all(
                        color: AppColors.primarySoft.withValues(alpha: 0.3),
                        width: 1.5,
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
                            transform: Matrix4.translationValues(0, isActive ? -6 : 0, 0),
                            child: Icon(
                              icons[index],
                              size: 28,
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
      ),
    );
  }
}
