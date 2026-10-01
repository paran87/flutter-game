import 'package:dotline_duel/game/controllers/win_resolver.dart';
import 'package:dotline_duel/game/models/game_result.dart';
import 'package:dotline_duel/game/models/game_state.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

ResultLine line({
  int destroyed = 0,
  int standing = 3,
  int score = 0,
  int distance = 0,
}) => ResultLine(
  name: 'P',
  color: const Color(0xFF000000),
  isBot: false,
  balloonsDestroyed: destroyed,
  balloonsStanding: standing,
  score: score,
  distance: distance,
  penalties: 0,
  successfulRuns: 0,
  failedRuns: 0,
);

void main() {
  test('destroying all opponent balloons wins outright', () {
    final o = resolveWinner(
      bottom: line(destroyed: 3, score: 10),
      top: line(standing: 0, score: 9999),
      trigger: GameEndTrigger.balloons,
    );
    expect(o.winner, 0);
    expect(o.reason, WinReason.allBalloonsDestroyed);
  });

  test('top player can win by elimination too', () {
    final o = resolveWinner(
      bottom: line(standing: 0),
      top: line(destroyed: 3),
      trigger: GameEndTrigger.balloons,
    );
    expect(o.winner, 1);
  });

  test('timer: more balloons destroyed wins (spec example 2 vs 1)', () {
    final o = resolveWinner(
      bottom: line(destroyed: 2, score: 1240, distance: 1420),
      top: line(destroyed: 1, score: 5000, distance: 9000),
      trigger: GameEndTrigger.timer,
    );
    expect(o.winner, 0);
    expect(o.reason, WinReason.moreBalloonsDestroyed);
  });

  test('timer: equal balloons -> higher score wins', () {
    final o = resolveWinner(
      bottom: line(destroyed: 1, score: 1180, distance: 9000),
      top: line(destroyed: 1, score: 1240, distance: 100),
      trigger: GameEndTrigger.timer,
    );
    expect(o.winner, 1);
    expect(o.reason, WinReason.higherScore);
  });

  test('timer: equal balloons and score -> longer distance wins', () {
    final o = resolveWinner(
      bottom: line(destroyed: 1, score: 800, distance: 1420),
      top: line(destroyed: 1, score: 800, distance: 1350),
      trigger: GameEndTrigger.timer,
    );
    expect(o.winner, 0);
    expect(o.reason, WinReason.longerDistance);
  });

  test('everything equal is a draw', () {
    final o = resolveWinner(
      bottom: line(destroyed: 1, score: 800, distance: 1000),
      top: line(destroyed: 1, score: 800, distance: 1000),
      trigger: GameEndTrigger.timer,
    );
    expect(o.isDraw, isTrue);
    expect(o.reason, WinReason.draw);
  });

  test('zero vs zero (nobody crossed, nobody scored) is a draw', () {
    final o = resolveWinner(
      bottom: line(),
      top: line(),
      trigger: GameEndTrigger.timer,
    );
    expect(o.isDraw, isTrue);
  });

  test('both players out of attempts uses the same tie-breaks', () {
    final o = resolveWinner(
      bottom: line(score: 10),
      top: line(score: 20),
      trigger: GameEndTrigger.noAttempts,
    );
    expect(o.winner, 1);
    expect(o.reason, WinReason.higherScore);
  });
}
