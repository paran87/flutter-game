import 'package:dotline_duel/game/controllers/movement_controller.dart';
import 'package:dotline_duel/game/models/game_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = GameConfig();
  const movement = MovementController(config);

  test('pen eases toward the target instead of snapping', () {
    const start = Offset(500, 800);
    const target = Offset(500, 790);
    final next = movement.step(
      position: start,
      target: target,
      dt: 1 / 60,
      maxSpeed: 10000,
    );
    expect(next.dy, lessThan(start.dy));
    expect(next.dy, greaterThan(target.dy));
  });

  test('speed is capped per frame', () {
    const start = Offset(500, 800);
    final next = movement.step(
      position: start,
      target: const Offset(500, 0),
      dt: 0.1,
      maxSpeed: 300,
    );
    expect((start - next).distance, closeTo(30, 1e-6));
  });

  test('global maximum speed overrides a faster agent', () {
    const start = Offset(500, 800);
    final next = movement.step(
      position: start,
      target: const Offset(500, 0),
      dt: 0.1,
      maxSpeed: 99999,
    );
    expect(
      (start - next).distance,
      closeTo(config.maximumMovementSpeed * 0.1, 1e-6),
    );
  });

  test('slowdown factor reduces the step', () {
    const start = Offset(500, 800);
    final next = movement.step(
      position: start,
      target: const Offset(500, 0),
      dt: 0.1,
      maxSpeed: 300,
      speedFactor: 0.5,
    );
    expect((start - next).distance, closeTo(15, 1e-6));
  });

  test('movement is frame-rate independent (same distance at 30/120 fps)', () {
    Offset run(int fps) {
      var p = const Offset(500, 800);
      for (var i = 0; i < fps; i++) {
        p = movement.step(
          position: p,
          target: const Offset(500, 780),
          dt: 1 / fps,
          maxSpeed: 100000,
        );
      }
      return p;
    }

    expect(run(30).dy, closeTo(run(120).dy, 0.01));
  });

  test('pen stays inside the playable area', () {
    final next = movement.step(
      position: const Offset(15, 15),
      target: const Offset(-500, -500),
      dt: 1,
      maxSpeed: 1000,
    );
    expect(next.dx, config.fieldRect.left + config.playerRadius);
    expect(next.dy, config.playerRadius);
  });
}
