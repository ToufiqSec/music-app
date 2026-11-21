import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Floating Rounded Bottom Navigation Bar with Premium Pill Highlight.
/// Adheres to WCAG AA accessibility with >=48dp touch targets and semantic labels.
class TwilightBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> icons;
  final List<String> labels;

  const TwilightBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.icons,
    this.labels = const ['Home', 'Search', 'Moods', 'Library', 'Albums'],
  });

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    const barHeight = 64.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomSafe > 0 ? bottomSafe : 10,
        top: 4,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: const Color(0xFF161228).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: AppColors.primarySoft.withValues(alpha: 0.28),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: AppColors.primarySoft.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(icons.length, (index) {
                final isActive = index == currentIndex;
                final label = index < labels.length ? labels[index] : 'Tab ${index + 1}';

                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: isActive,
                    label: '$label tab',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!isActive) {
                          HapticFeedback.lightImpact();
                          onTap(index);
                        }
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                        alignment: Alignment.center,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            horizontal: isActive ? 18 : 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primarySoft.withValues(alpha: 0.28)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primarySoft.withValues(alpha: 0.65)
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: AppColors.primarySoft.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            icons[index],
                            size: 26,
                            color: isActive ? Colors.white : AppColors.iconIdle,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
