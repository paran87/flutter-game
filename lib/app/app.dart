import 'package:flutter/material.dart';

import '../game/screens/game_screen.dart';
import '../game/screens/home_screen.dart';
import 'theme.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const game = '/game';
  static const tutorial = '/tutorial';
  static const settings = '/settings';
  static const result = '/result';
}

class DotlineDuelApp extends StatelessWidget {
  const DotlineDuelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dotline Duel',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      initialRoute: AppRoutes.home,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  static Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      AppRoutes.game => const GameScreen(),
      _ => const HomeScreen(),
    };
    return inkRoute(page, settings);
  }
}

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
