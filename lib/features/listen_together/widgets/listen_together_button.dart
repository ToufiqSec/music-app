import 'package:flutter/material.dart';
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
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final roomProvider = context.watch<RoomProvider>();
    final isInRoom = roomProvider.isInRoom;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: isInRoom ? 'Current Room (${roomProvider.currentRoom?.code})' : 'Listen Together',
          icon: Icon(
            Icons.speaker_group_rounded,
            color: isInRoom ? AppColors.accentTeal : AppColors.iconIdle,
            size: size,
          ),
          onPressed: () {
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
        ),
        if (isInRoom)
          Positioned(
            right: 8,
            top: 8,
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
    );
  }
}
