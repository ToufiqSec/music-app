import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/room_models.dart';

typedef SeekCallback = Future<void> Function(Duration target);
typedef PlayCallback = Future<void> Function();
typedef PauseCallback = Future<void> Function();
typedef GetPositionCallback = Duration Function();

/// Core Synchronization Engine for Listen Together rooms (Spec Section 6).
/// Computes drift against server time using NTP clock offset estimation,
/// schedules synchronized song starts, and applies automatic drift nudges.
class RoomSyncEngine {
  final Future<int> Function() _fetchServerTimeMs;
  final SeekCallback _seek;
  final PlayCallback _play;
  final PauseCallback _pause;
  final GetPositionCallback _getPosition;
  final void Function(SyncStatus status) _onSyncStatusChanged;

  // Clock offset in ms: serverTime = localTime + _clockOffsetMs
  int _clockOffsetMs = 0;
  bool _isClockCalibrated = false;

  Timer? _clockSyncTimer;
  Timer? _driftLoopTimer;
  Timer? _scheduledStartTimer;

  RoomPlaybackState? _lastAppliedState;
  int _lastAppliedVersion = -1;
  bool _isDisposed = false;

  RoomSyncEngine({
    required Future<int> Function() fetchServerTimeMs,
    required SeekCallback seek,
    required PlayCallback play,
    required PauseCallback pause,
    required GetPositionCallback getPosition,
    required void Function(SyncStatus status) onSyncStatusChanged,
  })  : _fetchServerTimeMs = fetchServerTimeMs,
        _seek = seek,
        _play = play,
        _pause = pause,
        _getPosition = getPosition,
        _onSyncStatusChanged = onSyncStatusChanged;

  int get clockOffsetMs => _clockOffsetMs;
  bool get isClockCalibrated => _isClockCalibrated;

  /// Returns current estimated server time in milliseconds
  int get currentServerTimeMs => DateTime.now().millisecondsSinceEpoch + _clockOffsetMs;

  /// Starts the sync engine: measures clock offset and starts 5-second drift loop
  Future<void> start() async {
    _isDisposed = false;
    await calibrateClock();

    // Re-measure clock offset every 60 seconds (Spec 6.2)
    _clockSyncTimer?.cancel();
    _clockSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!_isDisposed) {
        calibrateClock();
      }
    });

    // Run drift correction loop every 5 seconds (Spec 6.3)
    _driftLoopTimer?.cancel();
    _driftLoopTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isDisposed) {
        checkAndCorrectDrift();
      }
    });
  }

  /// NTP-style clock offset estimation (Spec Section 6.2)
  /// Repeats 3 to 5 times and keeps the sample with lowest round-trip latency:
  /// offset = server_time + (round_trip / 2) - phone_time
  Future<void> calibrateClock() async {
    const int sampleCount = 4;
    int bestRtt = 999999;
    int bestOffset = 0;

    for (int i = 0; i < sampleCount; i++) {
      if (_isDisposed) return;
      final t0 = DateTime.now().millisecondsSinceEpoch;
      try {
        final serverTime = await _fetchServerTimeMs().timeout(const Duration(seconds: 3));
        final t1 = DateTime.now().millisecondsSinceEpoch;
        final rtt = t1 - t0;

        if (rtt < bestRtt) {
          bestRtt = rtt;
          bestOffset = (serverTime + (rtt ~/ 2)) - t1;
        }
      } catch (e) {
        debugPrint('[RoomSyncEngine] Clock calibration sample $i failed: $e');
      }
      // Small pause between samples
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (bestRtt < 999999) {
      _clockOffsetMs = bestOffset;
      _isClockCalibrated = true;
      debugPrint('[RoomSyncEngine] Clock calibrated. Offset: ${_clockOffsetMs}ms (Best RTT: ${bestRtt}ms)');
    }
  }

  /// Computes the exact target position for the current moment (Spec Section 6.2)
  int calculateTargetPositionMs(RoomPlaybackState state) {
    if (!state.isPlaying) {
      return state.positionMs;
    }

    final nowServer = currentServerTimeMs;

    // Scheduled start support (Spec Section 6.4)
    if (state.scheduledStartServerMs > 0 && nowServer < state.scheduledStartServerMs) {
      return state.positionMs;
    }

    final baseTime = state.scheduledStartServerMs > 0
        ? state.scheduledStartServerMs
        : state.updatedAtServer.millisecondsSinceEpoch;

    final elapsed = (nowServer - baseTime).clamp(0, 86400000);
    return state.positionMs + elapsed;
  }

  /// Applies incoming room playback state pushed via Realtime or polled (Spec 6.1, 6.3, 6.4)
  Future<void> applyPlaybackState(RoomPlaybackState newState, {bool isNewTrack = false}) async {
    // Ignore stale updates with lower version (Spec 6.3)
    if (newState.version < _lastAppliedVersion && !isNewTrack) {
      debugPrint('[RoomSyncEngine] Ignoring stale state update (v${newState.version} < v$_lastAppliedVersion)');
      return;
    }

    _lastAppliedState = newState;
    _lastAppliedVersion = newState.version;
    _scheduledStartTimer?.cancel();

    final nowServer = currentServerTimeMs;
    final targetPosMs = calculateTargetPositionMs(newState);

    if (!newState.isPlaying) {
      // Paused state: pause and seek directly
      await _pause();
      await _seek(Duration(milliseconds: newState.positionMs));
      _onSyncStatusChanged(SyncStatus.synced);
      return;
    }

    // If a future scheduled start is defined (Spec Section 6.4)
    if (newState.scheduledStartServerMs > 0 && nowServer < newState.scheduledStartServerMs) {
      final delayMs = newState.scheduledStartServerMs - nowServer;
      debugPrint('[RoomSyncEngine] Scheduled synchronized start in ${delayMs}ms');
      await _seek(Duration(milliseconds: newState.positionMs));
      await _pause();
      _onSyncStatusChanged(SyncStatus.resyncing);

      _scheduledStartTimer = Timer(Duration(milliseconds: delayMs), () async {
        if (!_isDisposed && _lastAppliedState?.isPlaying == true) {
          debugPrint('[RoomSyncEngine] Executing scheduled start!');
          await _play();
          _onSyncStatusChanged(SyncStatus.synced);
        }
      });
      return;
    }

    // Normal playing state update: seek and play
    await _seek(Duration(milliseconds: targetPosMs));
    await _play();
    _onSyncStatusChanged(SyncStatus.synced);
  }

  /// Periodic 5-second drift correction loop (Spec Section 6.3)
  /// - drift < 150 ms: do nothing
  /// - 150 ms <= drift <= 1500 ms: nudge by small seek
  /// - drift > 1500 ms: seek straight to target position
  Future<void> checkAndCorrectDrift() async {
    final state = _lastAppliedState;
    if (state == null || !state.isPlaying) {
      _onSyncStatusChanged(SyncStatus.synced);
      return;
    }

    // If currently waiting for scheduled start, skip drift check
    if (state.scheduledStartServerMs > 0 && currentServerTimeMs < state.scheduledStartServerMs) {
      return;
    }

    final targetPosMs = calculateTargetPositionMs(state);
    final currentPosMs = _getPosition().inMilliseconds;
    final driftMs = (currentPosMs - targetPosMs).abs();

    if (driftMs < 150) {
      // Tight sync achieved
      _onSyncStatusChanged(SyncStatus.synced);
    } else if (driftMs <= 1500) {
      // Small drift: nudge seek
      debugPrint('[RoomSyncEngine] Nudging small drift: ${driftMs}ms (current: ${currentPosMs}ms, target: ${targetPosMs}ms)');
      _onSyncStatusChanged(SyncStatus.resyncing);
      await _seek(Duration(milliseconds: targetPosMs));
      _onSyncStatusChanged(SyncStatus.synced);
    } else {
      // Large drift (>1.5s): hard seek
      debugPrint('[RoomSyncEngine] Hard seeking large drift: ${driftMs}ms');
      _onSyncStatusChanged(SyncStatus.resyncing);
      await _seek(Duration(milliseconds: targetPosMs));
      _onSyncStatusChanged(SyncStatus.synced);
    }
  }

  void dispose() {
    _isDisposed = true;
    _clockSyncTimer?.cancel();
    _driftLoopTimer?.cancel();
    _scheduledStartTimer?.cancel();
  }
}
