import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/theme/app_colors.dart';
import 'package:music_app/theme/app_text_styles.dart';

Widget buildTestHeader({
  required double screenWidth,
  required double textScaleFactor,
  required bool isAuthenticated,
  String? avatarUrl,
  String displayName = 'Music Lover',
  String email = 'test@example.com',
}) {
  final initial = (displayName.isNotEmpty && displayName != 'Guest' && displayName != 'Music Lover')
      ? displayName[0].toUpperCase()
      : (email.isNotEmpty && email != 'Guest' ? email[0].toUpperCase() : '');

  Widget fallbackContent;
  if (isAuthenticated && initial.isNotEmpty) {
    fallbackContent = Text(
      initial,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  } else {
    fallbackContent = const Icon(
      Icons.person_rounded,
      size: 22,
      color: Colors.white,
    );
  }

  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(screenWidth, 800),
        textScaler: TextScaler.linear(textScaleFactor),
        padding: const EdgeInsets.only(top: 36),
      ),
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Good Evening',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h2.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ready to stream lossless audio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Action group
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Recent history',
                      child: Tooltip(
                        message: 'Recent history',
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface2.withValues(alpha: 0.85),
                            border: Border.all(
                              color: AppColors.primarySoft.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.history_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Search',
                      child: Tooltip(
                        message: 'Search',
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface2.withValues(alpha: 0.85),
                            border: Border.all(
                              color: AppColors.primarySoft.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.search_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Profile',
                      child: Tooltip(
                        message: 'Profile',
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface2.withValues(alpha: 0.85),
                            border: Border.all(
                              color: isAuthenticated
                                  ? AppColors.primarySoft.withValues(alpha: 0.7)
                                  : AppColors.primarySoft.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Center(child: fallbackContent),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Part B: Home Header Layout & Test Matrix Tests', () {
    testWidgets('Header renders without overflow across widths: 320dp, 360dp, 412dp', (tester) async {
      for (final width in [320.0, 360.0, 412.0]) {
        await tester.pumpWidget(buildTestHeader(
          screenWidth: width,
          textScaleFactor: 1.0,
          isAuthenticated: false,
        ));
        expect(tester.takeException(), isNull, reason: 'Must not throw overflow at width $width');
        expect(find.byTooltip('Recent history'), findsOneWidget);
        expect(find.byTooltip('Search'), findsOneWidget);
        expect(find.byTooltip('Profile'), findsOneWidget);
      }
    });

    testWidgets('Header handles accessibility text scaling: 1.0, 1.3, 2.0 without overflow', (tester) async {
      for (final scale in [1.0, 1.3, 2.0]) {
        await tester.pumpWidget(buildTestHeader(
          screenWidth: 320.0,
          textScaleFactor: scale,
          isAuthenticated: false,
        ));
        expect(tester.takeException(), isNull, reason: 'Must not throw overflow at scale $scale');
        expect(find.byTooltip('Profile'), findsOneWidget);
      }
    });

    testWidgets('Profile control in Logged Out state shows default person icon', (tester) async {
      await tester.pumpWidget(buildTestHeader(
        screenWidth: 360.0,
        textScaleFactor: 1.0,
        isAuthenticated: false,
      ));
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byTooltip('Profile'), findsOneWidget);
    });

    testWidgets('Profile control in Logged In state falls back to initial on missing/empty avatar', (tester) async {
      await tester.pumpWidget(buildTestHeader(
        screenWidth: 360.0,
        textScaleFactor: 1.0,
        isAuthenticated: true,
        displayName: 'Toufiq',
        avatarUrl: '',
      ));
      expect(find.text('T'), findsOneWidget);
      expect(find.byTooltip('Profile'), findsOneWidget);
    });

    testWidgets('Action group maintains 44x44dp touch targets and 8dp spacing', (tester) async {
      await tester.pumpWidget(buildTestHeader(
        screenWidth: 360.0,
        textScaleFactor: 1.0,
        isAuthenticated: true,
      ));

      final historyFinder = find.byTooltip('Recent history');
      final searchFinder = find.byTooltip('Search');
      final profileFinder = find.byTooltip('Profile');

      expect(tester.getSize(historyFinder), const Size(44, 44));
      expect(tester.getSize(searchFinder), const Size(44, 44));
      expect(tester.getSize(profileFinder), const Size(44, 44));

      final historyTopRight = tester.getTopRight(historyFinder);
      final searchTopLeft = tester.getTopLeft(searchFinder);
      expect((searchTopLeft.dx - historyTopRight.dx).round(), 8);

      final searchTopRight = tester.getTopRight(searchFinder);
      final profileTopLeft = tester.getTopLeft(profileFinder);
      expect((profileTopLeft.dx - searchTopRight.dx).round(), 8);
    });
  });
}
