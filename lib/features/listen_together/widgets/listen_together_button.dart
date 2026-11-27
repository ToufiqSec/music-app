import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../providers/room_provider.dart';
import '../screens/listen_together_entry_screen.dart';
import '../screens/room_screen.dart';

/// Reusable Header Button for Listen Together (Spec Section 8).
/// Can be positioned anywhere in the app (e.g. Home screen header).
/// Displays a green pulsing active indicator when user is currently in a room.
class ListenTogetherButton extends StatelessWidget {
  final double size;

  const ListenTogetherButton({
    super.key,
    this.size = 19.0,
  });

  @override
  Widget build(BuildContext context) {
    final roomProvider = context.watch<RoomProvider>();
    final isInRoom = roomProvider.isInRoom;
    final tooltipText = isInRoom
        ? 'Current Room (${roomProvider.currentRoom?.code})'
        : 'Listen Together';

    return Semantics(
      button: true,
      label: tooltipText,
      child: Tooltip(
        message: tooltipText,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              if (isInRoom) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RoomScreen()),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ListenTogetherEntryScreen()),
                );
              }
            },
            borderRadius: BorderRadius.circular(19),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cardBg.withValues(alpha: 0.75),
                border: Border.all(
                  color: isInRoom
                      ? AppColors.accentTeal.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.speaker_group_rounded,
                    color: isInRoom ? AppColors.accentTeal : Colors.white,
                    size: size,
                  ),
                  if (isInRoom)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success,
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
