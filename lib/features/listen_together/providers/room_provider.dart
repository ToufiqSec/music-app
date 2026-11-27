import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../music/models/music_models.dart';
import '../models/room_models.dart';
import '../services/room_service.dart';
import '../services/room_sync_engine.dart';
import '../../../providers/audio_provider.dart';
import '../../../core/services/supabase_service.dart';

class RoomProvider extends ChangeNotifier {
  final RoomService _roomService = RoomService();
  RoomSyncEngine? _syncEngine;
  AudioProvider? _audioProvider;

  RoomModel? _currentRoom;
  RoomMember? _myMembership;
  List<RoomMember> _members = [];
  RoomPlaybackState? _playbackState;
  List<RoomQueueItem> _queue = [];
  Set<String> _onlineUserIds = {};

  SyncStatus _syncStatus = SyncStatus.synced;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSessionEndedRemotely = false;

  // Track the ID of track currently loaded by room engine
  String? _activeRoomTrackId;

  // Getters
  RoomModel? get currentRoom => _currentRoom;
  bool get isInRoom => _currentRoom != null && _currentRoom!.isActive;
  RoomMember? get myMembership => _myMembership;
  List<RoomMember> get members => _members;
  RoomPlaybackState? get playbackState => _playbackState;
  List<RoomQueueItem> get queue => _queue;
  SyncStatus get syncStatus => _syncStatus;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSessionEndedRemotely => _isSessionEndedRemotely;
  int get memberCount => _members.length;

  bool get isHost => _myMembership?.isAdmin == true;
  bool get isController => _myMembership?.isController == true;
  bool get canControlPlayback => _myMembership?.canControl == true;
  bool get canManageQueue => _myMembership?.canControl == true;
  bool get canManageMembers => isHost;

  void attachAudioProvider(AudioProvider provider) {
    _audioProvider = provider;
    _audioProvider!.onTrackCompletedInRoom = () async {
      if (!isInRoom) return false;
      // If host or controller, advance room queue automatically (Spec Section 1 & 6)
      if (canControlPlayback) {
        await sendNext();
      }
      return true; // Keep personal queue untouched
    };
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  void resetSessionEndedFlag() {
    _isSessionEndedRemotely = false;
    notifyListeners();
  }

  /// Check if the user is already in an active room session on launch/open
  Future<void> checkActiveRoom() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    try {
      final activeRoom = await _roomService.fetchActiveRoomForUser(user.id);
      if (activeRoom != null && _currentRoom?.id != activeRoom.id) {
        _currentRoom = activeRoom;
        await _setupRoomSession(activeRoom.id);
      }
    } catch (e) {
      debugPrint('[RoomProvider] checkActiveRoom error: $e');
    }
  }

  /// Create Room (Spec Section 3 & 4)
  Future<bool> createRoom({
    required String displayName,
    String? avatarUrl,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final room = await _roomService.createRoom(
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      _currentRoom = room;
      await _setupRoomSession(room.id);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to create room: ${e.toString().replaceAll('Exception: ', '')}');
      _setLoading(false);
      return false;
    }
  }

  /// Join Room via 6-character code (Spec Section 3 & 7.2)
  Future<bool> joinRoom({
    required String code,
    required String displayName,
    String? avatarUrl,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final room = await _roomService.joinRoom(
        code: code,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      _currentRoom = room;
      await _setupRoomSession(room.id);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  /// Sets up Realtime subscriptions, sync engine, and initial snapshots
  Future<void> _setupRoomSession(String roomId) async {
    _isSessionEndedRemotely = false;

    // 1. Fetch initial snapshots
    final results = await Future.wait([
      _roomService.fetchMembers(roomId),
      _roomService.fetchPlaybackState(roomId),
      _roomService.fetchQueue(roomId),
    ]);

    _members = results[0] as List<RoomMember>;
    _playbackState = results[1] as RoomPlaybackState?;
    _queue = results[2] as List<RoomQueueItem>;

    final currentUserId = SupabaseService.currentUser?.id;
    if (currentUserId != null) {
      final myMemList = _members.where((m) => m.userId == currentUserId);
      _myMembership = myMemList.isNotEmpty ? myMemList.first : null;
    }

    // 2. Initialize sync engine (Spec Section 6)
    _syncEngine?.dispose();
    _syncEngine = RoomSyncEngine(
      fetchServerTimeMs: _roomService.getServerTimeMs,
      seek: (target) async {
        await _audioProvider?.seekImmediate(target);
      },
      play: () async {
        await _audioProvider?.play();
      },
      pause: () async {
        await _audioProvider?.pause();
      },
      getPosition: () => _audioProvider?.position ?? Duration.zero,
      onSyncStatusChanged: (status) {
        if (_syncStatus != status) {
          _syncStatus = status;
          notifyListeners();
        }
      },
    );

    await _syncEngine!.start();

    // 3. Connect Realtime room channels (Spec Section 4 & 6.1)
    _roomService.subscribeToRoom(
      roomId: roomId,
      onPlaybackStateChanged: _handleRemotePlaybackStateChanged,
      onMembersChanged: () async {
        _members = await _roomService.fetchMembers(roomId);
        final currentUserId = SupabaseService.currentUser?.id;
        if (currentUserId != null) {
          final myMemList = _members.where((m) => m.userId == currentUserId);
          _myMembership = myMemList.isNotEmpty ? myMemList.first : null;
        }
        notifyListeners();
      },
      onQueueChanged: () async {
        _queue = await _roomService.fetchQueue(roomId);
        notifyListeners();
      },
      onRoomEnded: () {
        _handleRoomEndedRemotely();
      },
      onPresenceChanged: (onlineIds) {
        _onlineUserIds = onlineIds;
        _members = _members.map((m) {
          return m.copyWith(isOnline: _onlineUserIds.contains(m.userId));
        }).toList();
        notifyListeners();
      },
    );

    // 4. Apply initial playback state if exists
    if (_playbackState != null && _playbackState!.currentTrack != null) {
      await _handleRemotePlaybackStateChanged(_playbackState!);
    }

    notifyListeners();
  }

  /// Handles incoming playback state from Supabase Realtime
  Future<void> _handleRemotePlaybackStateChanged(RoomPlaybackState state) async {
    _playbackState = state;
    notifyListeners();

    if (_audioProvider == null) return;

    final track = state.currentTrack;
    if (track == null) return;

    // If track changed, load the track first
    if (_activeRoomTrackId != track.id) {
      _activeRoomTrackId = track.id;
      _syncStatus = SyncStatus.resyncing;
      notifyListeners();

      // Report buffering ready
      if (_currentRoom != null) {
        _roomService.setMemberReady(_currentRoom!.id, false).catchError((_) {});
      }

      await _audioProvider!.playTrack(track);

      if (_currentRoom != null) {
        _roomService.setMemberReady(_currentRoom!.id, true).catchError((_) {});
      }

      await _syncEngine?.applyPlaybackState(state, isNewTrack: true);
    } else {
      await _syncEngine?.applyPlaybackState(state);
    }
  }

  /// Leave Room (Spec Section 3)
  Future<void> leaveRoom() async {
    final roomId = _currentRoom?.id;
    _cleanupSession();

    if (roomId != null) {
      try {
        await _roomService.leaveRoom(roomId);
      } catch (e) {
        debugPrint('[RoomProvider] leaveRoom error: $e');
      }
    }
    notifyListeners();
  }

  /// End Room (Host only) (Spec Section 2 & 3)
  Future<void> endRoom() async {
    if (!isHost || _currentRoom == null) return;
    final roomId = _currentRoom!.id;
    _cleanupSession();

    try {
      await _roomService.endRoom(roomId);
    } catch (e) {
      debugPrint('[RoomProvider] endRoom error: $e');
    }
    notifyListeners();
  }

  void _handleRoomEndedRemotely() {
    _cleanupSession();
    _isSessionEndedRemotely = true;
    notifyListeners();
  }

  void _cleanupSession() {
    _syncEngine?.dispose();
    _syncEngine = null;
    _roomService.unsubscribeFromRoom();
    _currentRoom = null;
    _myMembership = null;
    _members = [];
    _playbackState = null;
    _queue = [];
    _activeRoomTrackId = null;
    _syncStatus = SyncStatus.synced;
  }

  // --- CONTROLLER & ADMIN CONTROLS (Spec Section 2, 6.1, 7.3) ---

  Future<void> sendPlay() async {
    if (!canControlPlayback || _currentRoom == null || _playbackState == null) return;

    final currentPosMs = _audioProvider?.position.inMilliseconds ?? _playbackState!.positionMs;
    // Scheduled start 500ms ahead for synchronized group rhythm (Spec Section 6.4)
    final serverTime = _syncEngine?.currentServerTimeMs ?? DateTime.now().millisecondsSinceEpoch;
    final scheduledStart = serverTime + 450;

    await _roomService.updatePlayback(
      _currentRoom!.id,
      trackId: _playbackState!.currentTrackId,
      trackMetadata: _playbackState!.currentTrackMetadata,
      isPlaying: true,
      positionMs: currentPosMs,
      scheduledStartServerMs: scheduledStart,
    );
  }

  Future<void> sendPause() async {
    if (!canControlPlayback || _currentRoom == null || _playbackState == null) return;

    final currentPosMs = _audioProvider?.position.inMilliseconds ?? _playbackState!.positionMs;

    await _roomService.updatePlayback(
      _currentRoom!.id,
      trackId: _playbackState!.currentTrackId,
      trackMetadata: _playbackState!.currentTrackMetadata,
      isPlaying: false,
      positionMs: currentPosMs,
      scheduledStartServerMs: 0,
    );
  }

  Future<void> sendSeek(Duration position) async {
    if (!canControlPlayback || _currentRoom == null || _playbackState == null) return;

    final serverTime = _syncEngine?.currentServerTimeMs ?? DateTime.now().millisecondsSinceEpoch;
    final scheduledStart = _playbackState!.isPlaying ? serverTime + 300 : 0;

    await _roomService.updatePlayback(
      _currentRoom!.id,
      trackId: _playbackState!.currentTrackId,
      trackMetadata: _playbackState!.currentTrackMetadata,
      isPlaying: _playbackState!.isPlaying,
      positionMs: position.inMilliseconds,
      scheduledStartServerMs: scheduledStart,
    );
  }

  Future<void> playTrackNow(YoutubeTrack track) async {
    if (!canControlPlayback || _currentRoom == null) return;

    // Spec Section 6.4: Start buffering with isPlaying: false, then trigger scheduled start
    await _roomService.updatePlayback(
      _currentRoom!.id,
      trackId: track.id,
      trackMetadata: track.toJson(),
      isPlaying: false,
      positionMs: 0,
      scheduledStartServerMs: 0,
    );

    // Give peers a short buffering window (800ms) then start synchronized playback
    Future.delayed(const Duration(milliseconds: 800), () async {
      if (_currentRoom != null && _playbackState?.currentTrackId == track.id) {
        final serverTime = _syncEngine?.currentServerTimeMs ?? DateTime.now().millisecondsSinceEpoch;
        await _roomService.updatePlayback(
          _currentRoom!.id,
          trackId: track.id,
          trackMetadata: track.toJson(),
          isPlaying: true,
          positionMs: 0,
          scheduledStartServerMs: serverTime + 450,
        );
      }
    });
  }

  Future<void> sendNext() async {
    if (!canControlPlayback || _currentRoom == null) return;

    if (_queue.isNotEmpty) {
      final nextItem = _queue.first;
      await removeFromQueue(nextItem.id);
      await playTrackNow(nextItem.track);
    } else {
      // Seek to end or loop
      await sendSeek(Duration.zero);
    }
  }

  Future<void> sendPrevious() async {
    if (!canControlPlayback || _currentRoom == null) return;
    await sendSeek(Duration.zero);
  }

  // --- QUEUE MANAGEMENT (Spec Section 7.4) ---

  Future<void> addToQueue(YoutubeTrack track) async {
    if (!canManageQueue || _currentRoom == null) return;
    final myName = _myMembership?.displayName ?? 'Member';
    await _roomService.addToQueue(_currentRoom!.id, track, myName);
  }

  Future<void> addPlaylistToQueue(List<YoutubeTrack> tracks) async {
    if (!canManageQueue || _currentRoom == null || tracks.isEmpty) return;
    final myName = _myMembership?.displayName ?? 'Member';
    await _roomService.addBatchToQueue(_currentRoom!.id, tracks, myName);
  }

  Future<void> removeFromQueue(String queueItemId) async {
    if (!canManageQueue || _currentRoom == null) return;
    await _roomService.removeFromQueue(_currentRoom!.id, queueItemId);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (!canManageQueue || _currentRoom == null) return;
    if (oldIndex < 0 || oldIndex >= _queue.length || newIndex < 0 || newIndex >= _queue.length) {
      return;
    }

    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);
    notifyListeners();

    final itemIds = _queue.map((q) => q.id).toList();
    await _roomService.reorderQueue(_currentRoom!.id, itemIds);
  }

  // --- MEMBER MANAGEMENT (Host only) (Spec Section 2 & 7.5) ---

  Future<void> promoteToController(String userId) async {
    if (!isHost || _currentRoom == null) return;
    await _roomService.setMemberRole(_currentRoom!.id, userId, RoomRole.controller);
  }

  Future<void> demoteToListener(String userId) async {
    if (!isHost || _currentRoom == null) return;
    await _roomService.setMemberRole(_currentRoom!.id, userId, RoomRole.listener);
  }

  Future<void> removeMember(String userId) async {
    if (!isHost || _currentRoom == null) return;
    await _roomService.removeMember(_currentRoom!.id, userId);
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncEngine?.dispose();
    _roomService.unsubscribeFromRoom();
    super.dispose();
  }
}
