import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../music/models/music_models.dart';
import '../models/room_models.dart';
import '../../../core/services/supabase_service.dart';

class RoomService {
  final SupabaseClient _client = SupabaseService.client;
  RealtimeChannel? _roomChannel;

  // Rate limiting helper (max 5 state updates / sec) (Spec Section 6.5)
  int _lastUpdatePlaybackTimestamp = 0;

  /// Retrieves server time in epoch milliseconds (Spec Section 6.2)
  Future<int> getServerTimeMs() async {
    try {
      final res = await _client.rpc('get_server_time');
      if (res is num) {
        return res.toInt();
      }
      return DateTime.now().millisecondsSinceEpoch;
    } catch (_) {
      // Fallback: estimate from local clock if RPC not configured yet
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Create a new room with a unique 6-character code (Spec Section 3 & 4)
  Future<RoomModel> createRoom({
    required String displayName,
    String? avatarUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to create a room.');
    }

    try {
      final res = await _client.rpc('create_room', params: {
        'p_display_name': displayName.trim().isNotEmpty ? displayName.trim() : 'Host',
        'p_avatar_url': avatarUrl ?? '',
      });

      if (res is Map<String, dynamic>) {
        return RoomModel.fromJson(res);
      } else if (res is Map) {
        return RoomModel.fromJson(Map<String, dynamic>.from(res));
      }
      throw Exception('Unexpected create_room response: $res');
    } catch (e) {
      debugPrint('[RoomService] create_room RPC error: $e');
      // Fallback: direct table insert if RPC is missing
      return _createRoomFallback(displayName: displayName, avatarUrl: avatarUrl);
    }
  }

  Future<RoomModel> _createRoomFallback({required String displayName, String? avatarUrl}) async {
    final user = _client.auth.currentUser!;
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code = List.generate(6, (i) => chars[(DateTime.now().microsecondsSinceEpoch + i) % chars.length]).join();

    final roomData = await _client.from('rooms').insert({
      'code': code,
      'admin_id': user.id,
      'is_active': true,
    }).select().single();

    final roomId = roomData['id'].toString();

    // Insert admin membership
    await _client.from('room_members').upsert({
      'room_id': roomId,
      'user_id': user.id,
      'role': 'admin',
      'display_name': displayName,
      'avatar_url': avatarUrl ?? '',
      'is_ready': true,
    });

    // Insert playback state
    await _client.from('room_playback_state').upsert({
      'room_id': roomId,
      'is_playing': false,
      'position_ms': 0,
      'version': 1,
      'updated_by': user.id,
    });

    return RoomModel.fromJson(roomData);
  }

  /// Join an existing room via 6-character code (Spec Section 3 & 7.2)
  Future<RoomModel> joinRoom({
    required String code,
    required String displayName,
    String? avatarUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to join a room.');
    }

    final cleanCode = code.toUpperCase().trim();
    if (cleanCode.length != 6) {
      throw Exception('Room code must be exactly 6 characters.');
    }

    try {
      final res = await _client.rpc('join_room', params: {
        'p_code': cleanCode,
        'p_display_name': displayName.trim().isNotEmpty ? displayName.trim() : 'Listener',
        'p_avatar_url': avatarUrl ?? '',
      });

      if (res is Map<String, dynamic>) {
        return RoomModel.fromJson(res);
      } else if (res is Map) {
        return RoomModel.fromJson(Map<String, dynamic>.from(res));
      }
      throw Exception('Unexpected join_room response: $res');
    } catch (e) {
      debugPrint('[RoomService] join_room RPC error: $e');
      if (e.toString().contains('Room not found') ||
          e.toString().contains('Room has ended') ||
          e.toString().contains('Room is full')) {
        rethrow;
      }
      return _joinRoomFallback(cleanCode, displayName, avatarUrl);
    }
  }

  Future<RoomModel> _joinRoomFallback(String code, String displayName, String? avatarUrl) async {
    final user = _client.auth.currentUser!;
    final roomData = await _client
        .from('rooms')
        .select()
        .eq('code', code)
        .eq('is_active', true)
        .maybeSingle();

    if (roomData == null) {
      throw Exception('Room not found or has already ended.');
    }

    final roomId = roomData['id'].toString();

    // Check count
    final countRes = await _client
        .from('room_members')
        .select('id')
        .eq('room_id', roomId)
        .isFilter('left_at', null);

    if ((countRes as List).length >= 20) {
      throw Exception('Room is full (maximum 20 listeners).');
    }

    await _client.from('room_members').upsert({
      'room_id': roomId,
      'user_id': user.id,
      'role': roomData['admin_id'] == user.id ? 'admin' : 'listener',
      'display_name': displayName,
      'avatar_url': avatarUrl ?? '',
      'left_at': null,
    });

    return RoomModel.fromJson(roomData);
  }

  /// Leave room (Spec Section 3 & 6.5)
  Future<void> leaveRoom(String roomId) async {
    try {
      await _client.rpc('leave_room', params: {'p_room_id': roomId});
    } catch (_) {
      final user = _client.auth.currentUser;
      if (user != null) {
        await _client.from('room_members').update({
          'left_at': DateTime.now().toIso8601String(),
        }).eq('room_id', roomId).eq('user_id', user.id);
      }
    }
  }

  /// End room (Host only) (Spec Section 2, 3)
  Future<void> endRoom(String roomId) async {
    try {
      await _client.rpc('end_room', params: {'p_room_id': roomId});
    } catch (_) {
      await _client.from('rooms').update({
        'is_active': false,
        'ended_at': DateTime.now().toIso8601String(),
      }).eq('id', roomId);
    }
  }

  /// Promote/demote member role (Host only) (Spec Section 2)
  Future<void> setMemberRole(String roomId, String targetUserId, RoomRole role) async {
    try {
      await _client.rpc('set_member_role', params: {
        'p_room_id': roomId,
        'p_target_user_id': targetUserId,
        'p_role': role.toDbString(),
      });
    } catch (_) {
      await _client.from('room_members').update({
        'role': role.toDbString(),
      }).eq('room_id', roomId).eq('user_id', targetUserId);
    }
  }

  /// Remove member from room (Host only) (Spec Section 2, 7.5)
  Future<void> removeMember(String roomId, String targetUserId) async {
    try {
      await _client.rpc('remove_member', params: {
        'p_room_id': roomId,
        'p_target_user_id': targetUserId,
      });
    } catch (_) {
      await _client.from('room_members').update({
        'left_at': DateTime.now().toIso8601String(),
      }).eq('room_id', roomId).eq('user_id', targetUserId);
    }
  }

  /// Update playback state in Supabase (Host/Controller only) (Spec Section 6.1 & 6.5)
  Future<void> updatePlayback(
    String roomId, {
    String? trackId,
    Map<String, dynamic>? trackMetadata,
    required bool isPlaying,
    required int positionMs,
    int scheduledStartServerMs = 0,
  }) async {
    // Rate limit: max 5 state updates per second (Spec 6.5)
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastUpdatePlaybackTimestamp < 180) {
      return;
    }
    _lastUpdatePlaybackTimestamp = now;

    try {
      await _client.rpc('update_room_playback', params: {
        'p_room_id': roomId,
        'p_current_track_id': trackId,
        'p_track_metadata': trackMetadata,
        'p_is_playing': isPlaying,
        'p_position_ms': positionMs,
        'p_scheduled_start_server_ms': scheduledStartServerMs,
      });
    } catch (e) {
      debugPrint('[RoomService] update_room_playback RPC failed, using table update: $e');
      final user = _client.auth.currentUser;
      final current = await fetchPlaybackState(roomId);
      final nextVersion = (current?.version ?? 0) + 1;

      await _client.from('room_playback_state').upsert({
        'room_id': roomId,
        'current_track_id': trackId,
        'current_track_metadata': trackMetadata,
        'is_playing': isPlaying,
        'position_ms': positionMs,
        'scheduled_start_server_ms': scheduledStartServerMs,
        'updated_at_server': DateTime.now().toIso8601String(),
        'version': nextVersion,
        'updated_by': user?.id,
      });
    }
  }

  /// Report member buffering readiness (Spec Section 6.4)
  Future<void> setMemberReady(String roomId, bool isReady) async {
    try {
      await _client.rpc('set_member_ready', params: {
        'p_room_id': roomId,
        'p_is_ready': isReady,
      });
    } catch (_) {
      final user = _client.auth.currentUser;
      if (user != null) {
        await _client.from('room_members').update({
          'is_ready': isReady,
        }).eq('room_id', roomId).eq('user_id', user.id);
      }
    }
  }

  /// Queue Management (Spec Section 7.4, 7.6)
  Future<void> addToQueue(String roomId, YoutubeTrack track, String addedByName) async {
    try {
      await _client.rpc('add_to_room_queue', params: {
        'p_room_id': roomId,
        'p_track_id': track.id,
        'p_track_metadata': track.toJson(),
        'p_added_by_name': addedByName,
      });
    } catch (e) {
      debugPrint('[RoomService] add_to_room_queue RPC failed, using table insert: $e');
      final user = _client.auth.currentUser!;
      final queueItems = await fetchQueue(roomId);
      final nextPos = queueItems.isEmpty ? 0 : queueItems.map((q) => q.position).reduce((a, b) => a > b ? a : b) + 1;

      await _client.from('room_queue').insert({
        'room_id': roomId,
        'track_id': track.id,
        'track_metadata': track.toJson(),
        'position': nextPos,
        'added_by': user.id,
        'added_by_name': addedByName,
      });
    }
  }

  Future<void> removeFromQueue(String roomId, String queueItemId) async {
    try {
      await _client.rpc('remove_from_room_queue', params: {
        'p_room_id': roomId,
        'p_queue_item_id': queueItemId,
      });
    } catch (_) {
      await _client.from('room_queue').delete().eq('id', queueItemId).eq('room_id', roomId);
    }
  }

  Future<void> reorderQueue(String roomId, List<String> itemIds) async {
    try {
      await _client.rpc('reorder_room_queue', params: {
        'p_room_id': roomId,
        'p_item_ids': itemIds,
      });
    } catch (_) {
      for (int i = 0; i < itemIds.length; i++) {
        await _client.from('room_queue').update({'position': i}).eq('id', itemIds[i]);
      }
    }
  }

  /// Fetch initial snapshot data
  Future<RoomPlaybackState?> fetchPlaybackState(String roomId) async {
    try {
      final res = await _client
          .from('room_playback_state')
          .select()
          .eq('room_id', roomId)
          .maybeSingle();
      if (res != null) {
        return RoomPlaybackState.fromJson(res);
      }
    } catch (e) {
      debugPrint('[RoomService] Error fetching playback state: $e');
    }
    return null;
  }

  Future<List<RoomMember>> fetchMembers(String roomId) async {
    try {
      final res = await _client
          .from('room_members')
          .select()
          .eq('room_id', roomId)
          .isFilter('left_at', null)
          .order('joined_at', ascending: true);
      return (res as List).map((m) => RoomMember.fromJson(m)).toList();
    } catch (e) {
      debugPrint('[RoomService] Error fetching members: $e');
      return [];
    }
  }

  Future<List<RoomQueueItem>> fetchQueue(String roomId) async {
    try {
      final res = await _client
          .from('room_queue')
          .select()
          .eq('room_id', roomId)
          .order('position', ascending: true);
      return (res as List).map((q) => RoomQueueItem.fromJson(q)).toList();
    } catch (e) {
      debugPrint('[RoomService] Error fetching queue: $e');
      return [];
    }
  }

  Future<RoomModel?> fetchActiveRoomForUser(String userId) async {
    try {
      final membership = await _client
          .from('room_members')
          .select('room_id')
          .eq('user_id', userId)
          .isFilter('left_at', null)
          .order('joined_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (membership != null) {
        final rId = membership['room_id'].toString();
        final roomData = await _client
            .from('rooms')
            .select()
            .eq('id', rId)
            .eq('is_active', true)
            .maybeSingle();
        if (roomData != null) {
          return RoomModel.fromJson(roomData);
        }
      }
    } catch (e) {
      debugPrint('[RoomService] Error checking active room: $e');
    }
    return null;
  }

  /// Subscribe to Realtime room events (Spec Section 4, 6.1, 7.5)
  void subscribeToRoom({
    required String roomId,
    required void Function(RoomPlaybackState state) onPlaybackStateChanged,
    required void Function() onMembersChanged,
    required void Function() onQueueChanged,
    required void Function() onRoomEnded,
    required void Function(Set<String> onlineUserIds) onPresenceChanged,
  }) {
    unsubscribeFromRoom();

    final channelName = 'room:$roomId';
    _roomChannel = _client.channel(channelName);

    // 1. Playback State changes
    _roomChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'room_playback_state',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (payload) {
        debugPrint('[Realtime] Playback state updated: ${payload.newRecord}');
        if (payload.newRecord.isNotEmpty) {
          final newState = RoomPlaybackState.fromJson(payload.newRecord);
          onPlaybackStateChanged(newState);
        }
      },
    );

    // 2. Members changes
    _roomChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'room_members',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (payload) {
        debugPrint('[Realtime] Room members updated.');
        onMembersChanged();
      },
    );

    // 3. Queue changes
    _roomChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'room_queue',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (payload) {
        debugPrint('[Realtime] Queue updated.');
        onQueueChanged();
      },
    );

    // 4. Room ended check
    _roomChannel!.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'rooms',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: roomId,
      ),
      callback: (payload) {
        final isActive = payload.newRecord['is_active'] as bool? ?? true;
        if (!isActive) {
          debugPrint('[Realtime] Room has been ended by host.');
          onRoomEnded();
        }
      },
    );

    // 5. Presence for online member dots (Spec Section 7.5)
    _roomChannel!.onPresenceSync((_) {
      final state = _roomChannel!.presenceState();
      final onlineIds = <String>{};
      for (final p in state) {
        for (final item in p.presences) {
          if (item is Map && item['user_id'] != null) {
            final uId = item['user_id']?.toString();
            if (uId != null && uId.isNotEmpty) {
              onlineIds.add(uId);
            }
          }
        }
      }
      onPresenceChanged(onlineIds);
    });

    _roomChannel!.subscribe((status, [error]) async {
      debugPrint('[Realtime] Room channel status: $status');
      if (status == RealtimeSubscribeStatus.subscribed) {
        final currentUserId = _client.auth.currentUser?.id;
        if (currentUserId != null) {
          await _roomChannel!.track({'user_id': currentUserId});
        }
      }
    });
  }

  void unsubscribeFromRoom() {
    if (_roomChannel != null) {
      _client.removeChannel(_roomChannel!);
      _roomChannel = null;
    }
  }
}
