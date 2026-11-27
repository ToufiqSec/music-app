/// Explicit state machine governing track playback requests, completion
/// deduplication, queue index calculation, and failure backoff.
///
/// Ensures:
/// - Rapid play/skip calls supersede stale async resolutions via [requestId].
/// - Each played track can trigger at most ONE completion transition.
/// - Consecutive playback failures do not cause infinite skip loops.
enum TransitionRepeatMode { off, all, one }

class PlaybackTransitionController {
  static const int maxConsecutiveFailures = 3;

  int _requestId = 0;
  int _completedRequestId = -1;
  bool _isCompleting = false;
  int _consecutiveFailures = 0;

  int get currentRequestId => _requestId;
  bool get isCompleting => _isCompleting;
  int get consecutiveFailures => _consecutiveFailures;

  /// Starts a new playback request and returns its unique monotonic ID.
  /// Any older in-flight async resolution with a different ID is superseded.
  int beginPlayRequest() {
    _requestId++;
    _isCompleting = false;
    return _requestId;
  }

  /// Returns true only if [requestId] is still the latest active request.
  bool isCurrentRequest(int requestId) => requestId == _requestId;

  /// Attempts to claim the single completion transition for the current track.
  /// Returns false if a completion is already running or if this [requestId]
  /// has already completed.
  bool tryBeginCompletion(int requestId) {
    if (_isCompleting) return false;
    if (requestId != _requestId) return false;
    if (_completedRequestId == requestId) return false;

    _isCompleting = true;
    _completedRequestId = requestId;
    return true;
  }

  /// Marks the active completion transition as finished.
  void finishCompletion() {
    _isCompleting = false;
  }

  /// Resets the consecutive failure counter after a track starts playing.
  void recordSuccess() {
    _consecutiveFailures = 0;
  }

  /// Records a track playback failure and returns whether the player should
  /// auto-advance to the next track without entering an infinite skip loop.
  bool recordFailureAndShouldAdvance({required int queueLength}) {
    _consecutiveFailures++;
    return queueLength > 1 && _consecutiveFailures < maxConsecutiveFailures;
  }

  /// Computes the next queue index, or null if queue has ended.
  int? computeNextIndex({
    required int currentIndex,
    required int queueLength,
    required TransitionRepeatMode repeatMode,
  }) {
    if (queueLength <= 0 || currentIndex < 0) return null;
    if (currentIndex + 1 < queueLength) {
      return currentIndex + 1;
    }
    if (repeatMode == TransitionRepeatMode.all) {
      return 0;
    }
    return null;
  }

  /// Computes the previous queue index, or null if at the beginning.
  int? computePreviousIndex({
    required int currentIndex,
    required int queueLength,
    required TransitionRepeatMode repeatMode,
  }) {
    if (queueLength <= 0 || currentIndex < 0) return null;
    if (currentIndex - 1 >= 0) {
      return currentIndex - 1;
    }
    if (repeatMode == TransitionRepeatMode.all) {
      return queueLength - 1;
    }
    return null;
  }
}
