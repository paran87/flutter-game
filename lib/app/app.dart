import 'package:flutter/material.dart';

import '../game/screens/game_screen.dart';
import '../game/screens/home_screen.dart';
import '../game/screens/room_screen.dart';
import '../game/screens/settings_screen.dart';
import '../game/screens/tutorial_screen.dart';
import '../game/services/settings_controller.dart';
import 'theme.dart';

/// Dev override for quick testing: `--dart-define=MATCH_SECONDS=15`.
const _matchSecondsOverride = int.fromEnvironment('MATCH_SECONDS');

abstract final class AppRoutes {
  static const home = '/';
  static const game = '/game';
  static const room = '/room';
  static const tutorial = '/tutorial';
  static const settings = '/settings';
}

class DotlineDuelApp extends StatefulWidget {
  const DotlineDuelApp({super.key, this.settings});

  /// Injected in tests; otherwise the app owns its own controller.
  final SettingsController? settings;

  @override
  State<DotlineDuelApp> createState() => _DotlineDuelAppState();
}

class _DotlineDuelAppState extends State<DotlineDuelApp> {
  late final SettingsController _settings =
      widget.settings ?? SettingsController();

  @override
  void dispose() {
    if (widget.settings == null) _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      controller: _settings,
      child: MaterialApp(
        title: 'Dotline Duel',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        initialRoute: AppRoutes.home,
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings route) {
    final Widget page = switch (route.name) {
      AppRoutes.game => gameScreenFor(_settings.value),
      AppRoutes.room => const RoomScreen(),
      AppRoutes.tutorial => const TutorialScreen(),
      AppRoutes.settings => const SettingsScreen(),
      _ => const HomeScreen(),
    };
    return inkRoute(page, route);
  }
}

/// A new match using the current settings.
GameScreen gameScreenFor(GameSettings settings) => GameScreen(
  settings: settings,
  config: settings.toConfig(
    matchSecondsOverride: _matchSecondsOverride > 0
        ? _matchSecondsOverride
        : null,
  ),
);

/// Fade + gentle rise, like a sheet of paper sliding into place.
PageRoute<T> inkRoute<T>(Widget page, [RouteSettings? settings]) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
