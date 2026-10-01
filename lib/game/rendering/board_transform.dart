import 'dart:math' as math;
import 'dart:ui';

import '../models/game_config.dart';

/// Maps the fixed game world onto the screen with a uniform scale, so dots
/// stay round and gameplay is identical on every aspect ratio.
class BoardTransform {
  const BoardTransform({
    required this.scale,
    required this.origin,
    required this.worldSize,
  });

  /// Fits the world inside [available], centred.
  factory BoardTransform.fit(Size available, GameConfig config) {
    final worldSize = Size(config.worldWidth, config.worldHeight);
    final scale = math.min(
      available.width / worldSize.width,
      available.height / worldSize.height,
    );
    final boardSize = worldSize * scale;
    final origin = Offset(
      (available.width - boardSize.width) / 2,
      (available.height - boardSize.height) / 2,
    );
    return BoardTransform(scale: scale, origin: origin, worldSize: worldSize);
  }

  /// Screen pixels per world unit.
  final double scale;

  /// Screen position of the world origin (top-left of the board).
  final Offset origin;
  final Size worldSize;

  Rect get boardRect => origin & (worldSize * scale);

  Offset toScreen(Offset world) => origin + world * scale;
  Offset toWorld(Offset screen) => (screen - origin) / scale;
  double toWorldLength(double screenLength) => screenLength / scale;

  @override
  bool operator ==(Object other) =>
      other is BoardTransform &&
      other.scale == scale &&
      other.origin == origin &&
      other.worldSize == worldSize;

  @override
  int get hashCode => Object.hash(scale, origin, worldSize);
}
