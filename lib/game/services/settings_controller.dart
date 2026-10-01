import 'package:flutter/widgets.dart';

import '../models/game_config.dart';

/// How far above the finger the pen sits.
enum TouchOffsetPreset {
  near(56, 'Near'),
  normal(76, 'Normal'),
  far(100, 'Far');

  const TouchOffsetPreset(this.pixels, this.label);

  final double pixels;
  final String label;
}

enum MatchLength {
  short(60, '1 min'),
  standard(120, '2 min'),
  long(180, '3 min');

  const MatchLength(this.seconds, this.label);

  final int seconds;
  final String label;
}

/// Player-facing preferences.
@immutable
class GameSettings {
  const GameSettings({
    this.difficulty = BotDifficulty.normal,
    this.matchLength = MatchLength.standard,
    this.touchOffset = TouchOffsetPreset.normal,
    this.hapticsEnabled = true,
    this.soundEnabled = true,
    this.penLiftRule = true,
    this.debugMode = false,
  });

  final BotDifficulty difficulty;
  final MatchLength matchLength;
  final TouchOffsetPreset touchOffset;
  final bool hapticsEnabled;
  final bool soundEnabled;

  /// Lifting the finger mid-run (beyond the grace period) fails the run.
  final bool penLiftRule;

  /// Shows coordinates, paths and live stats over the board.
  final bool debugMode;

  GameSettings copyWith({
    BotDifficulty? difficulty,
    MatchLength? matchLength,
    TouchOffsetPreset? touchOffset,
    bool? hapticsEnabled,
    bool? soundEnabled,
    bool? penLiftRule,
    bool? debugMode,
  }) => GameSettings(
    difficulty: difficulty ?? this.difficulty,
    matchLength: matchLength ?? this.matchLength,
    touchOffset: touchOffset ?? this.touchOffset,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    penLiftRule: penLiftRule ?? this.penLiftRule,
    debugMode: debugMode ?? this.debugMode,
  );

  /// Builds the gameplay config for a new match.
  GameConfig toConfig({
    GameConfig base = const GameConfig(),
    int? matchSecondsOverride,
  }) {
    return base.copyWith(
      botDifficulty: difficulty,
      gameDuration: Duration(
        seconds: matchSecondsOverride ?? matchLength.seconds,
      ),
      touchOffset: touchOffset.pixels,
      penLiftFailsRun: penLiftRule,
    );
  }
}

/// Holds the current settings. In-memory for this prototype; persisting them
/// (e.g. with shared_preferences) only needs a load/save around [value].
class SettingsController extends ValueNotifier<GameSettings> {
  SettingsController([super.value = const GameSettings()]);

  void update(GameSettings Function(GameSettings s) change) =>
      value = change(value);
}

/// Makes the [SettingsController] available to the widget tree.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope missing above $context');
    return scope!.notifier!;
  }
}
