import 'package:dotline_duel/app/app.dart';
import 'package:dotline_duel/game/models/game_config.dart';
import 'package:dotline_duel/game/models/game_result.dart';
import 'package:dotline_duel/game/models/game_state.dart';
import 'package:dotline_duel/game/screens/game_screen.dart';
import 'package:dotline_duel/game/screens/result_screen.dart';
import 'package:dotline_duel/game/screens/tutorial_screen.dart';
import 'package:dotline_duel/game/services/settings_controller.dart';
import 'package:dotline_duel/game/widgets/scoreboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One frame to start animations/route transitions (a pushed route is
/// offstage for its first frame), then let them run for [ms].
Future<void> settle(WidgetTester tester, [int ms = 800]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

void usePhoneSize(WidgetTester tester, {Size size = const Size(393, 852)}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

ResultLine line(String name, bool bot, int destroyed) => ResultLine(
  name: name,
  color: bot ? Colors.red : Colors.blue,
  isBot: bot,
  balloonsDestroyed: destroyed,
  balloonsStanding: 3 - (bot ? 2 : 1),
  score: 1240,
  distance: 1420,
  penalties: 60,
  successfulRuns: destroyed,
  failedRuns: 1,
);

void main() {
  testWidgets('home screen shows title and menu', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(const DotlineDuelApp());
    await settle(tester, 1600);
    expect(find.text('DOTLINE\nDUEL'), findsOneWidget);
    expect(find.text('Draw your way through.'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('HOW TO PLAY'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('VS BOT · NORMAL'), findsOneWidget);
  });

  testWidgets('PLAY opens a running game with both scorecards', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(const DotlineDuelApp());
    await settle(tester, 1600);
    await tester.tap(find.text('PLAY'));
    await settle(tester);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byType(PlayerScoreCard), findsNWidgets(2));
    expect(find.text('02:00'), findsOneWidget);
    // Run through intro + countdown into play without exceptions.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging moves the human pen during play', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(config: GameConfig(obstacleSeed: 1))),
    );
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final state = tester.state(find.byType(GameScreen));
    final gesture = await tester.startGesture(const Offset(196, 760));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    expect(state.mounted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tutorial pages through to the last step', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(const MaterialApp(home: TutorialScreen()));
    await settle(tester);
    expect(find.text('Drag to draw'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('NEXT'));
      await settle(tester, 600);
    }
    expect(find.text('Win the duel'), findsOneWidget);
    expect(find.text("LET'S PLAY"), findsOneWidget);
  });

  testWidgets('settings change difficulty and toggles', (tester) async {
    usePhoneSize(tester);
    final settings = SettingsController();
    await tester.pumpWidget(DotlineDuelApp(settings: settings));
    await settle(tester, 1600);
    await tester.tap(find.text('SETTINGS'));
    await settle(tester);
    await tester.tap(find.text('Hard'));
    await settle(tester, 300);
    expect(settings.value.difficulty, BotDifficulty.hard);
    await tester.tap(find.text('3 min'));
    await settle(tester, 300);
    expect(settings.value.matchLength, MatchLength.long);
    expect(
      settings.value.toConfig().gameDuration,
      const Duration(seconds: 180),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await settle(tester, 300);
    await tester.tap(find.text('Debug overlay'));
    await settle(tester, 300);
    expect(settings.value.debugMode, isTrue);
  });

  testWidgets('result screen explains the winner', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          config: const GameConfig(),
          result: GameResult(
            bottom: line('YOU', false, 2),
            top: line('BOT', true, 1),
            outcome: const GameOutcome(0, WinReason.moreBalloonsDestroyed),
            trigger: GameEndTrigger.timer,
            rounds: 4,
          ),
        ),
      ),
    );
    await settle(tester, 1600);
    expect(find.text('VICTORY!'), findsOneWidget);
    expect(find.text("TIME'S UP"), findsOneWidget);
    expect(find.text('More balloons destroyed'), findsOneWidget);
    expect(find.text('Balloons destroyed'), findsOneWidget);
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('game screen fits a small phone without overflow', (
    tester,
  ) async {
    usePhoneSize(tester, size: const Size(320, 568));
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('debug overlay renders during a bot race', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          config: GameConfig(obstacleSeed: 2),
          settings: GameSettings(debugMode: true),
        ),
      ),
    );
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining('phase playing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
