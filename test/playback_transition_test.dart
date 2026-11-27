import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/services/playback_transition_controller.dart';

void main() {
  group('PlaybackTransitionController', () {
    test('one completed track triggers at most one completion transition', () {
      final controller = PlaybackTransitionController();
      final reqId = controller.beginPlayRequest();

      expect(controller.tryBeginCompletion(reqId), isTrue);
      expect(controller.isCompleting, isTrue);

      // Duplicate completion event while completing is rejected
      expect(controller.tryBeginCompletion(reqId), isFalse);

      // Even after finishing completion, the same requestId cannot complete again
      controller.finishCompletion();
      expect(controller.isCompleting, isFalse);
      expect(controller.tryBeginCompletion(reqId), isFalse);

      // A new track play request allows completion once for the new requestId
      final nextReqId = controller.beginPlayRequest();
      expect(controller.tryBeginCompletion(nextReqId), isTrue);
    });

    test('rapid playTrack calls supersede older in-flight request IDs', () {
      final controller = PlaybackTransitionController();
      final req1 = controller.beginPlayRequest();
      final req2 = controller.beginPlayRequest();
      final req3 = controller.beginPlayRequest();

      expect(controller.isCurrentRequest(req1), isFalse);
      expect(controller.isCurrentRequest(req2), isFalse);
      expect(controller.isCurrentRequest(req3), isTrue);

      // Stale requestId cannot trigger completion
      expect(controller.tryBeginCompletion(req1), isFalse);
      expect(controller.tryBeginCompletion(req2), isFalse);
    });

    test('consecutive failure guard stops infinite skip loops and resets on success', () {
      final controller = PlaybackTransitionController();

      expect(controller.recordFailureAndShouldAdvance(queueLength: 5), isTrue); // 1
      expect(controller.recordFailureAndShouldAdvance(queueLength: 5), isTrue); // 2
      expect(controller.recordFailureAndShouldAdvance(queueLength: 5), isFalse); // 3 -> stop advancing

      controller.recordSuccess();
      expect(controller.consecutiveFailures, 0);
      expect(controller.recordFailureAndShouldAdvance(queueLength: 5), isTrue);
      expect(controller.recordFailureAndShouldAdvance(queueLength: 1), isFalse);
    });

    test('computeNextIndex and computePreviousIndex respect repeat modes', () {
      final controller = PlaybackTransitionController();

      // RepeatMode.off at end of queue returns null
      expect(
        controller.computeNextIndex(
          currentIndex: 2,
          queueLength: 3,
          repeatMode: TransitionRepeatMode.off,
        ),
        isNull,
      );

      // RepeatMode.all wraps around
      expect(
        controller.computeNextIndex(
          currentIndex: 2,
          queueLength: 3,
          repeatMode: TransitionRepeatMode.all,
        ),
        0,
      );
      expect(
        controller.computePreviousIndex(
          currentIndex: 0,
          queueLength: 3,
          repeatMode: TransitionRepeatMode.all,
        ),
        2,
      );

      // RepeatMode.off at start of queue returns null for previous
      expect(
        controller.computePreviousIndex(
          currentIndex: 0,
          queueLength: 3,
          repeatMode: TransitionRepeatMode.off,
        ),
        isNull,
      );
    });
  });
}
