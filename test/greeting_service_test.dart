import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/services/greeting_service.dart';

void main() {
  group('GreetingService Time-of-Day Boundary Tests (Issue 7)', () {
    test('04:59 is Good Night', () {
      final time = DateTime(2026, 11, 20, 4, 59);
      expect(GreetingService.getGreeting(time: time), 'Good Night');
    });

    test('05:00 is Good Morning', () {
      final time = DateTime(2026, 11, 20, 5, 0);
      expect(GreetingService.getGreeting(time: time), 'Good Morning');
    });

    test('11:59 is Good Morning', () {
      final time = DateTime(2026, 11, 20, 11, 59);
      expect(GreetingService.getGreeting(time: time), 'Good Morning');
    });

    test('12:00 is Good Afternoon', () {
      final time = DateTime(2026, 11, 20, 12, 0);
      expect(GreetingService.getGreeting(time: time), 'Good Afternoon');
    });

    test('16:59 is Good Afternoon', () {
      final time = DateTime(2026, 11, 20, 16, 59);
      expect(GreetingService.getGreeting(time: time), 'Good Afternoon');
    });

    test('17:00 is Good Evening', () {
      final time = DateTime(2026, 11, 20, 17, 0);
      expect(GreetingService.getGreeting(time: time), 'Good Evening');
    });

    test('20:59 is Good Evening', () {
      final time = DateTime(2026, 11, 20, 20, 59);
      expect(GreetingService.getGreeting(time: time), 'Good Evening');
    });

    test('21:00 is Good Night', () {
      final time = DateTime(2026, 11, 20, 21, 0);
      expect(GreetingService.getGreeting(time: time), 'Good Night');
    });

    test('Hindi translations work for all time intervals', () {
      expect(GreetingService.getGreeting(time: DateTime(2026, 1, 1, 6, 30), isHindi: true), 'सुप्रभात');
      expect(GreetingService.getGreeting(time: DateTime(2026, 1, 1, 14, 0), isHindi: true), 'शुभ दोपहर');
      expect(GreetingService.getGreeting(time: DateTime(2026, 1, 1, 18, 0), isHindi: true), 'शुभ संध्या');
      expect(GreetingService.getGreeting(time: DateTime(2026, 1, 1, 23, 0), isHindi: true), 'शुभ रात्रि');
    });
  });
}
