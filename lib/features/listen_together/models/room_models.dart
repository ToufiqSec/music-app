import 'package:flutter/foundation.dart';
import '../../music/models/music_models.dart';

enum RoomRole {
  admin,
  controller,
  listener;

  static RoomRole fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'admin':
        return RoomRole.admin;
      case 'controller':
        return RoomRole.controller;
      case 'listener':
      default:
        return RoomRole.listener;
    }
  }

  String toDbString() => name;
}

enum SyncStatus {
  synced,
  resyncing,
  reconnecting,
}

class RoomModel {
  final String id;
  final String code;
  final String adminId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? endedAt;

  const RoomModel({
    required this.id,
    required this.code,
    required this.adminId,
    required this.isActive,
    required this.createdAt,
    this.endedAt,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      adminId: json['admin_id']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'admin_id': adminId,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
      };
}

class RoomMember {
  final String id;
  final String roomId;
  final String userId;
  final RoomRole role;
  final String displayName;
  final String avatarUrl;
  final bool isReady;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final bool isOnline;

  const RoomMember({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.role,
    required this.displayName,
    this.avatarUrl = '',
    this.isReady = false,
    required this.joinedAt,
    this.leftAt,
    this.isOnline = true,
  });

  bool get isAdmin => role == RoomRole.admin;
  bool get isController => role == RoomRole.controller;
  bool get isListener => role == RoomRole.listener;
  bool get canControl => isAdmin || isController;

  factory RoomMember.fromJson(Map<String, dynamic> json, {bool isOnline = true}) {
    return RoomMember(
      id: json['id']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      role: RoomRole.fromString(json['role']?.toString()),
      displayName: json['display_name']?.toString() ?? 'Listener',
      avatarUrl: json['avatar_url']?.toString() ?? '',
      isReady: json['is_ready'] as bool? ?? false,
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      leftAt: json['left_at'] != null
          ? DateTime.tryParse(json['left_at'].toString())
          : null,
      isOnline: isOnline,
    );
  }

  RoomMember copyWith({
    RoomRole? role,
    String? displayName,
    String? avatarUrl,
    bool? isReady,
    DateTime? leftAt,
    bool? isOnline,
  }) {
    return RoomMember(
      id: id,
      roomId: roomId,
      userId: userId,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isReady: isReady ?? this.isReady,
      joinedAt: joinedAt,
      leftAt: leftAt ?? this.leftAt,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

class RoomPlaybackState {
  final String roomId;
  final String? currentTrackId;
  final Map<String, dynamic>? currentTrackMetadata;
  final bool isPlaying;
  final int positionMs;
  final int scheduledStartServerMs;
  final DateTime updatedAtServer;
  final int version;
  final String? updatedBy;

  const RoomPlaybackState({
    required this.roomId,
    this.currentTrackId,
    this.currentTrackMetadata,
    required this.isPlaying,
    required this.positionMs,
    this.scheduledStartServerMs = 0,
    required this.updatedAtServer,
    required this.version,
    this.updatedBy,
  });

  YoutubeTrack? get currentTrack {
    if (currentTrackMetadata == null || currentTrackMetadata!.isEmpty) return null;
    try {
      return YoutubeTrack.fromJson(currentTrackMetadata!);
    } catch (e) {
      debugPrint('[RoomPlaybackState] Error parsing track metadata: $e');
      return null;
    }
  }

  factory RoomPlaybackState.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? meta;
    if (json['current_track_metadata'] != null) {
      if (json['current_track_metadata'] is Map<String, dynamic>) {
        meta = json['current_track_metadata'] as Map<String, dynamic>;
      } else if (json['current_track_metadata'] is Map) {
        meta = Map<String, dynamic>.from(json['current_track_metadata'] as Map);
      }
    }

    return RoomPlaybackState(
      roomId: json['room_id']?.toString() ?? '',
      currentTrackId: json['current_track_id']?.toString(),
      currentTrackMetadata: meta,
      isPlaying: json['is_playing'] as bool? ?? false,
      positionMs: (json['position_ms'] as num?)?.toInt() ?? 0,
      scheduledStartServerMs: (json['scheduled_start_server_ms'] as num?)?.toInt() ?? 0,
      updatedAtServer: json['updated_at_server'] != null
          ? DateTime.tryParse(json['updated_at_server'].toString()) ?? DateTime.now()
          : DateTime.now(),
      version: (json['version'] as num?)?.toInt() ?? 1,
      updatedBy: json['updated_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'room_id': roomId,
        'current_track_id': currentTrackId,
        'current_track_metadata': currentTrackMetadata,
        'is_playing': isPlaying,
        'position_ms': positionMs,
        'scheduled_start_server_ms': scheduledStartServerMs,
        'updated_at_server': updatedAtServer.toIso8601String(),
        'version': version,
        'updated_by': updatedBy,
      };
}

class RoomQueueItem {
  final String id;
  final String roomId;
  final String trackId;
  final Map<String, dynamic> trackMetadata;
  final int position;
  final String addedBy;
  final String addedByName;
  final DateTime createdAt;

  const RoomQueueItem({
    required this.id,
    required this.roomId,
    required this.trackId,
    required this.trackMetadata,
    required this.position,
    required this.addedBy,
    required this.addedByName,
    required this.createdAt,
  });

  YoutubeTrack get track => YoutubeTrack.fromJson(trackMetadata);

  factory RoomQueueItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> meta = {};
    if (json['track_metadata'] != null) {
      if (json['track_metadata'] is Map<String, dynamic>) {
        meta = json['track_metadata'] as Map<String, dynamic>;
      } else if (json['track_metadata'] is Map) {
        meta = Map<String, dynamic>.from(json['track_metadata'] as Map);
      }
    }

    return RoomQueueItem(
      id: json['id']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      trackId: json['track_id']?.toString() ?? '',
      trackMetadata: meta,
      position: (json['position'] as num?)?.toInt() ?? 0,
      addedBy: json['added_by']?.toString() ?? '',
      addedByName: json['added_by_name']?.toString() ?? 'Member',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_id': roomId,
        'track_id': trackId,
        'track_metadata': trackMetadata,
        'position': position,
        'added_by': addedBy,
        'added_by_name': addedByName,
        'created_at': createdAt.toIso8601String(),
      };
}
