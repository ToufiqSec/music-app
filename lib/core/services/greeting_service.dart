/// Time-of-Day Greeting Service (Issue 7).
/// Computes accurate contextual greetings based on exact time boundaries:
/// - 05:00 to 11:59 -> 'Good Morning'
/// - 12:00 to 16:59 -> 'Good Afternoon'
/// - 17:00 to 20:59 -> 'Good Evening'
/// - 21:00 to 04:59 -> 'Good Night'
class GreetingService {
  /// Computes the time-of-day greeting for a given [DateTime].
  /// Defaults to [DateTime.now()] when [time] is omitted.
  static String getGreeting({DateTime? time, bool isHindi = false}) {
    final t = time ?? DateTime.now();
    final hour = t.hour;
    final minute = t.minute;

    // Convert time into minutes since midnight for clean boundary evaluation
    final minutesSinceMidnight = (hour * 60) + minute;

    // 05:00 is 300 minutes; 11:59 is 719 minutes
    if (minutesSinceMidnight >= 300 && minutesSinceMidnight < 720) {
      return isHindi ? 'सुप्रभात' : 'Good Morning';
    }

    // 12:00 is 720 minutes; 16:59 is 1019 minutes
    if (minutesSinceMidnight >= 720 && minutesSinceMidnight < 1020) {
      return isHindi ? 'शुभ दोपहर' : 'Good Afternoon';
    }

    // 17:00 is 1020 minutes; 20:59 is 1259 minutes
    if (minutesSinceMidnight >= 1020 && minutesSinceMidnight < 1260) {
      return isHindi ? 'शुभ संध्या' : 'Good Evening';
    }

    // 21:00 (1260 min) to 04:59 (299 min)
    return isHindi ? 'शुभ रात्रि' : 'Good Night';
  }
}
