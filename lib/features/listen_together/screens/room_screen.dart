import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_text_styles.dart';
import '../../../providers/audio_provider.dart';
import '../../../features/music/models/music_models.dart';
import '../../../widgets/generated_cover_art.dart';
import '../../../widgets/cascading_artwork.dart';
import '../models/room_models.dart';
import '../providers/room_provider.dart';
import '../widgets/room_share_sheet.dart';

class RoomScreen extends StatefulWidget {
  final bool autoShowShare;
  const RoomScreen({super.key, this.autoShowShare = false});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<YoutubeTrack> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.autoShowShare) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final roomProvider = context.read<RoomProvider>();
        final code = roomProvider.currentRoom?.code;
        if (code != null && code.isNotEmpty) {
          RoomShareSheet.show(context, code);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showDisabledControlToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Only the host and controllers can control playback.'),
        backgroundColor: AppColors.surface2,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final audio = context.read<AudioProvider>();
    try {
      final results = await audio.musicService.searchTracks(clean);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _showPlaylistSelector(RoomProvider roomProvider) async {
    final audio = context.read<AudioProvider>();
    final playlists = audio.userPlaylists;

    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved playlists found in your library.'),
          backgroundColor: AppColors.surface2,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Choose a Playlist', style: AppTextStyles.h3),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: playlists.keys.length,
                      itemBuilder: (_, i) {
                      final name = playlists.keys.elementAt(i);
                      final trackCount = playlists[name]?.length ?? 0;
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: const Icon(Icons.playlist_play_rounded, color: AppColors.accentTeal),
                        ),
                        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('$trackCount songs', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          final tracks = await audio.getPlaylistTracks(name);
                          if (tracks.isNotEmpty) {
                            await roomProvider.addPlaylistToQueue(tracks);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added ${tracks.length} songs from "$name" to room queue!'),
                                  backgroundColor: AppColors.surface2,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  }

  void _showMemberActionSheet(RoomMember member, RoomProvider roomProvider) {
    if (!roomProvider.isHost || member.isAdmin) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Manage ${member.displayName}',
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 16),
              if (member.isController)
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.warning),
                  title: const Text('Remove as Controller', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Member becomes a listener only', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    roomProvider.demoteToListener(member.userId);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.verified_user_rounded, color: AppColors.accentTeal),
                  title: const Text('Make Controller', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Allow member to pause, play, and edit the queue', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    roomProvider.promoteToController(member.userId);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: AppColors.error),
                title: const Text('Remove from Room', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  roomProvider.removeMember(member.userId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = context.watch<RoomProvider>();
    final audioProvider = context.watch<AudioProvider>();

    // Listen for remote session termination by host (Spec Section 3)
    if (roomProvider.isSessionEndedRemotely) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        roomProvider.resetSessionEndedFlag();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The host has ended this Listen Together session.'),
            backgroundColor: AppColors.surface2,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
      });
    }

    if (!roomProvider.isInRoom) {
      return Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.meeting_room_outlined, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              const Text('No active room session.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primarySoft),
                child: const Text('Go Back', style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    final currentRoom = roomProvider.currentRoom!;
    final playbackState = roomProvider.playbackState;
    final currentTrack = playbackState?.currentTrack ?? audioProvider.currentTrack;
    final canControl = roomProvider.canControlPlayback;

    final duration = audioProvider.duration;
    final position = audioProvider.position;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Minimize Room (Keeps playing)',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
          onTap: () => RoomShareSheet.show(context, currentRoom.code),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppRadii.full),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.speaker_group_rounded, color: AppColors.accentTeal, size: 16),
                const SizedBox(width: 8),
                Text(
                  currentRoom.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.copy_rounded, color: AppColors.textSecondary, size: 14),
              ],
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          // Member Count Chip
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_alt_rounded, size: 14, color: AppColors.accentTeal),
                const SizedBox(width: 4),
                Text(
                  '${roomProvider.memberCount}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),

          // Three Dot Menu (Spec Section 7.3)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: AppColors.surface1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
            onSelected: (val) {
              if (val == 'share') {
                RoomShareSheet.show(context, currentRoom.code);
              } else if (val == 'leave') {
                roomProvider.leaveRoom();
                Navigator.of(context).pop();
              } else if (val == 'end') {
                roomProvider.endRoom();
                Navigator.of(context).pop();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Share Invite Code', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app_rounded, size: 18, color: AppColors.warning),
                    SizedBox(width: 12),
                    Text('Leave Room', style: TextStyle(color: AppColors.warning)),
                  ],
                ),
              ),
              if (roomProvider.isHost)
                const PopupMenuItem(
                  value: 'end',
                  child: Row(
                    children: [
                      Icon(Icons.stop_circle_outlined, size: 18, color: AppColors.error),
                      SizedBox(width: 12),
                      Text('End Room (For All)', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Now Playing Card (Spec Section 7.3)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              children: [
                // Album Art
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    child: CascadingArtwork(
                      key: ValueKey('room_art_${currentTrack?.id}'),
                      trackId: currentTrack?.id,
                      imageUrl: currentTrack?.thumbnail ?? currentTrack?.thumbnailUrl,
                      title: currentTrack?.title ?? 'No Track Playing',
                      artist: currentTrack?.artist ?? 'Room Waiting',
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Title & Artist
                Text(
                  currentTrack?.title ?? 'Queue Empty — Pick a Song',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  currentTrack?.artist ?? 'Host or controllers can add tracks below',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 10),

                // Synced Badge (Spec Section 7.3)
                _buildSyncBadge(roomProvider.syncStatus),
                const SizedBox(height: 10),

                // Progress Bar
                ProgressBar(
                  progress: position,
                  total: duration,
                  progressBarColor: AppColors.primarySoft,
                  baseBarColor: AppColors.surface2,
                  thumbColor: AppColors.primarySoft,
                  thumbRadius: canControl ? 6.0 : 0.0,
                  timeLabelTextStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  onSeek: canControl
                      ? (target) {
                          roomProvider.sendSeek(target);
                        }
                      : null,
                ),

                // Playback Controls (Previous, Play/Pause, Next) (Spec Section 7.3)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Previous
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        size: 32,
                        color: canControl ? Colors.white : AppColors.iconDisabled,
                      ),
                      onPressed: canControl
                          ? () => roomProvider.sendPrevious()
                          : _showDisabledControlToast,
                    ),
                    const SizedBox(width: 16),

                    // Play / Pause
                    GestureDetector(
                      onTap: canControl
                          ? () {
                              if (playbackState?.isPlaying == true) {
                                roomProvider.sendPause();
                              } else {
                                roomProvider.sendPlay();
                              }
                            }
                          : _showDisabledControlToast,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: canControl ? AppColors.primarySoft : AppColors.surface2,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            playbackState?.isPlaying == true
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: canControl ? Colors.white : AppColors.textTertiary,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Next
                    IconButton(
                      icon: Icon(
                        Icons.skip_next_rounded,
                        size: 32,
                        color: canControl ? Colors.white : AppColors.iconDisabled,
                      ),
                      onPressed: canControl
                          ? () => roomProvider.sendNext()
                          : _showDisabledControlToast,
                    ),

                    if (!canControl)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textTertiary),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 2. Tab Bar (Queue, Members, Add Songs) (Spec Section 7.3 - 7.6)
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.accentTeal,
            indicatorWeight: 2.5,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.queue_music_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('Queue (${roomProvider.queue.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.group_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('Members (${roomProvider.memberCount})'),
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Add Songs'),
                  ],
                ),
              ),
            ],
          ),

          // 3. Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildQueueTab(roomProvider),
                _buildMembersTab(roomProvider),
                _buildAddSongsTab(roomProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBadge(SyncStatus status) {
    Color dotColor;
    String text;

    switch (status) {
      case SyncStatus.synced:
        dotColor = AppColors.success;
        text = 'Synced';
        break;
      case SyncStatus.resyncing:
        dotColor = AppColors.warning;
        text = 'Resyncing...';
        break;
      case SyncStatus.reconnecting:
        dotColor = AppColors.error;
        text = 'Reconnecting...';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: dotColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: dotColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- QUEUE TAB (Spec Section 7.4) ---
  Widget _buildQueueTab(RoomProvider roomProvider) {
    final queue = roomProvider.queue;
    final canManage = roomProvider.canManageQueue;

    if (queue.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.playlist_remove_rounded, size: 44, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              const Text('The room queue is empty', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                canManage
                    ? 'Use the Add Songs tab or import a playlist to start group playback.'
                    : 'The host or controllers will add songs to the queue.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              if (canManage) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface2),
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Search Songs'),
                  onPressed: () => _tabController.animateTo(2),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (canManage) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: queue.length,
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) newIndex -= 1;
          roomProvider.reorderQueue(oldIndex, newIndex);
        },
        itemBuilder: (ctx, index) {
          final item = queue[index];
          final track = item.track;
          return Dismissible(
            key: ValueKey(item.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: AppColors.error,
              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            ),
            onDismissed: (_) {
              roomProvider.removeFromQueue(item.id);
            },
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CascadingArtwork(
                    key: ValueKey('room_queue_art_${track.id}'),
                    trackId: track.id,
                    imageUrl: track.thumbnail.isNotEmpty ? track.thumbnail : track.thumbnailUrl,
                    title: track.title,
                    artist: track.artist,
                    width: 44,
                    height: 44,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
              ),
              title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('${track.artist} • Added by ${item.addedByName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow_rounded, color: AppColors.accentTeal),
                    onPressed: () {
                      roomProvider.removeFromQueue(item.id);
                      roomProvider.playTrackNow(track);
                    },
                  ),
                  const Icon(Icons.drag_handle_rounded, color: AppColors.iconIdle),
                ],
              ),
            ),
          );
        },
      );
    }

    // Read-only for listeners
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: queue.length,
      itemBuilder: (ctx, index) {
        final item = queue[index];
        final track = item.track;
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: SizedBox(
              width: 44,
              height: 44,
              child: CascadingArtwork(
                key: ValueKey('room_hist_art_${track.id}'),
                trackId: track.id,
                imageUrl: track.thumbnail.isNotEmpty ? track.thumbnail : track.thumbnailUrl,
                title: track.title,
                artist: track.artist,
                width: 44,
                height: 44,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
            ),
          ),
          title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('${track.artist} • Added by ${item.addedByName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        );
      },
    );
  }

  // --- MEMBERS TAB (Spec Section 7.5) ---
  Widget _buildMembersTab(RoomProvider roomProvider) {
    final members = roomProvider.members;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: members.length,
      itemBuilder: (ctx, index) {
        final member = members[index];
        final isHostMember = member.isAdmin;
        final isControllerMember = member.isController;

        return ListTile(
          onTap: roomProvider.isHost && !isHostMember
              ? () => _showMemberActionSheet(member, roomProvider)
              : null,
          leading: Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.surface2,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              // Online Presence Dot (Spec Section 7.5)
              if (member.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bgDeep, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            member.displayName,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            member.isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: member.isOnline ? AppColors.success : AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isHostMember)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.4)),
                  ),
                  child: const Text('Host', style: TextStyle(color: AppColors.accentTeal, fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else if (isControllerMember)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    border: Border.all(color: AppColors.primarySoft.withValues(alpha: 0.4)),
                  ),
                  child: const Text('Controller', style: TextStyle(color: AppColors.primarySoft, fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else
                const Text('Listener', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              if (roomProvider.isHost && !isHostMember) ...[
                const SizedBox(width: 8),
                const Icon(Icons.more_horiz_rounded, color: AppColors.iconIdle, size: 20),
              ],
            ],
          ),
        );
      },
    );
  }

  // --- ADD SONGS TAB (Spec Section 7.6) ---
  Widget _buildAddSongsTab(RoomProvider roomProvider) {
    if (!roomProvider.canManageQueue) {
      return const Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.textTertiary),
              SizedBox(height: 12),
              Text(
                'Only the host and controllers can add songs.',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Ask the host to make you a Controller to add tracks to the queue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search songs to add...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.iconIdle, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppColors.iconIdle, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _handleSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface1,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: const BorderSide(color: AppColors.accentTeal),
                    ),
                  ),
                  onSubmitted: _handleSearch,
                ),
              ),
              const SizedBox(width: 8),
              // Choose Playlist Button (Spec Section 7.6)
              IconButton(
                tooltip: 'Choose a Playlist',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                ),
                icon: const Icon(Icons.playlist_add_rounded, color: AppColors.accentTeal),
                onPressed: () => _showPlaylistSelector(roomProvider),
              ),
            ],
          ),
        ),

        // Live Search Results
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(AppColors.accentTeal)))
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.music_note_rounded, size: 40, color: AppColors.textTertiary),
                          const SizedBox(height: 10),
                          Text(
                            _searchController.text.isEmpty
                                ? 'Search for any song or tap the playlist icon'
                                : 'No songs found. Try another query.',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (ctx, index) {
                        final track = _searchResults[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: CascadingArtwork(
                                key: ValueKey('room_search_art_${track.id}'),
                                trackId: track.id,
                                imageUrl: track.thumbnail.isNotEmpty ? track.thumbnail : track.thumbnailUrl,
                                title: track.title,
                                artist: track.artist,
                                width: 44,
                                height: 44,
                                borderRadius: BorderRadius.circular(AppRadii.sm),
                              ),
                            ),
                          ),
                          title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Play Now
                              IconButton(
                                tooltip: 'Play Now',
                                icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.accentTeal, size: 28),
                                onPressed: () {
                                  roomProvider.playTrackNow(track);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Playing "${track.title}" for room!'),
                                      backgroundColor: AppColors.surface2,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                              // Add to Queue
                              IconButton(
                                tooltip: 'Add to Queue',
                                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white70, size: 24),
                                onPressed: () {
                                  roomProvider.addToQueue(track);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Added "${track.title}" to queue!'),
                                      backgroundColor: AppColors.surface2,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
