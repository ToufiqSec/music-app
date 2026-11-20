import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../widgets/room_share_sheet.dart';
import 'join_room_screen.dart';
import 'room_screen.dart';

class ListenTogetherEntryScreen extends StatefulWidget {
  const ListenTogetherEntryScreen({super.key});

  @override
  State<ListenTogetherEntryScreen> createState() => _ListenTogetherEntryScreenState();
}

class _ListenTogetherEntryScreenState extends State<ListenTogetherEntryScreen> {
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomProvider>().checkActiveRoom();
    });
  }

  Future<void> _handleCreateRoom() async {
    final auth = context.read<AuthProvider>();
    final roomProvider = context.read<RoomProvider>();

    final nameController = TextEditingController(text: auth.displayName);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: Text('Create Listen Together Room', style: AppTextStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You will be the room host with full control over the queue and member permissions.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Your Host Name',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primarySoft,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
            ),
            child: const Text('Start Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCreating = true);

    final success = await roomProvider.createRoom(
      displayName: nameController.text.trim().isNotEmpty
          ? nameController.text.trim()
          : 'Host',
    );

    if (!mounted) return;
    setState(() => _isCreating = false);

    if (success && roomProvider.currentRoom != null) {
      // Navigate to Room Screen with auto-show share sheet
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RoomScreen(autoShowShare: true)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(roomProvider.errorMessage ?? 'Failed to create room. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = context.watch<RoomProvider>();
    final isInRoom = roomProvider.isInRoom;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Active Room Banner (Spec Section 7.1)
              if (isInRoom) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.headset_mic_rounded, color: AppColors.accentTeal, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'You are currently in a room',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Room Code: ${roomProvider.currentRoom?.code}',
                              style: const TextStyle(
                                color: AppColors.accentTeal,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentTeal,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                        ),
                        child: const Text('Return', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const RoomScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Hero Illustration & Heading
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primarySoft.withValues(alpha: 0.25),
                      AppColors.accentTeal.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primarySoft.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.speaker_group_rounded,
                  color: AppColors.accentTeal,
                  size: 46,
                ),
              ),
              const SizedBox(height: 20),

              Text('Listen Together', style: AppTextStyles.h1.copyWith(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                'Play music in sync with friends. Perfect for study sessions, hangouts, and group road trips.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 36),

              // Feature Highlights
              _buildFeatureRow(
                icon: Icons.sync_rounded,
                title: 'Tight Millisecond Sync',
                subtitle: 'All connected phones hear the same beat at the same moment.',
              ),
              const SizedBox(height: 16),
              _buildFeatureRow(
                icon: Icons.queue_music_rounded,
                title: 'Shared Real-Time Queue',
                subtitle: 'Host & promoted controllers can add and reorder songs together.',
              ),
              const SizedBox(height: 16),
              _buildFeatureRow(
                icon: Icons.lock_outline_rounded,
                title: 'Private & Isolated',
                subtitle: 'Your personal playlists, favorites, and history are never touched.',
              ),
              const SizedBox(height: 40),

              // 2. Action Buttons (Spec Section 7.1)
              // Create Room (Primary)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarySoft,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  icon: _isCreating
                      ? const SizedBox.shrink()
                      : const Icon(Icons.add_circle_outline_rounded, size: 22),
                  label: _isCreating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create Room',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                  onPressed: _isCreating ? null : _handleCreateRoom,
                ),
              ),
              const SizedBox(height: 14),

              // Join Room (Secondary)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                    backgroundColor: AppColors.surface1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  icon: const Icon(Icons.meeting_room_outlined, size: 22, color: AppColors.accentTeal),
                  label: const Text(
                    'Join Room with Code',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, color: AppColors.accentTeal, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
