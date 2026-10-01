import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../models/game_config.dart';
import '../rendering/paper_painter.dart';
import '../services/settings_controller.dart';
import '../widgets/home_backdrop.dart';
import '../widgets/ink_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Animation<double> _at(
    double begin,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) => CurvedAnimation(
    parent: _intro,
    curve: Interval(begin, end, curve: curve),
  );

  Widget _rise(double begin, Widget child) {
    final a = _at(begin, (begin + 0.35).clamp(0, 1));
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final settings = SettingsScope.of(context).value;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: PaperPainter())),
          const Positioned.fill(child: HomeBackdrop()),
          // Soft paper glow behind the menu so the backdrop stays quiet.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.8,
                  colors: [
                    AppColors.paper.withValues(alpha: 0.92),
                    AppColors.paper.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 3),
                      ScaleTransition(
                        scale: Tween(
                          begin: 0.85,
                          end: 1.0,
                        ).animate(_at(0, 0.45, Curves.easeOutBack)),
                        child: FadeTransition(
                          opacity: _at(0, 0.3),
                          child: Text(
                            'DOTLINE\nDUEL',
                            textAlign: TextAlign.center,
                            style: text.displayLarge?.copyWith(fontSize: 54),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 210,
                        height: 14,
                        child: AnimatedBuilder(
                          animation: _at(0.25, 0.7, Curves.easeInOut),
                          builder: (context, _) => CustomPaint(
                            painter: _UnderlinePainter(
                              _at(0.25, 0.7, Curves.easeInOut).value,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeTransition(
                        opacity: _at(0.45, 0.8),
                        child: Text(
                          'Draw your way through.',
                          style: text.bodyLarge?.copyWith(fontSize: 17),
                        ),
                      ),
                      const Spacer(flex: 4),
                      _rise(
                        0.4,
                        InkButton(
                          label: 'PLAY',
                          icon: Icons.play_arrow_rounded,
                          primary: true,
                          onPressed: () =>
                              Navigator.of(context).pushNamed(AppRoutes.game),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _rise(
                        0.48,
                        _OpponentChip(
                          difficulty: settings.difficulty,
                          onTap: () =>
                              Navigator.of(context)
                                  .pushNamed(AppRoutes.settings),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _rise(
                        0.55,
                        InkButton(
                          label: 'HOW TO PLAY',
                          icon: Icons.menu_book_rounded,
                          onPressed: () =>
                              Navigator.of(context)
                                  .pushNamed(AppRoutes.tutorial),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _rise(
                        0.62,
                        InkButton(
                          label: 'SETTINGS',
                          icon: Icons.tune_rounded,
                          onPressed: () =>
                              Navigator.of(context)
                                  .pushNamed(AppRoutes.settings),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpponentChip extends StatelessWidget {
  const _OpponentChip({required this.difficulty, required this.onTap});

  final BotDifficulty difficulty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Opponent: ${difficulty.label} bot. Change in settings.',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.p2Light,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.p2.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.smart_toy_outlined,
                size: 16,
                color: AppColors.p2,
              ),
              const SizedBox(width: 6),
              Text(
                'VS BOT · ${difficulty.label.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: AppColors.p2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quick ballpoint flourish under the title, drawn left to right.
class _UnderlinePainter extends CustomPainter {
  _UnderlinePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.6)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.1,
        size.width * 0.6,
        size.height * 1.1,
        size.width,
        size.height * 0.35,
      );
    final metric = path.computeMetrics().first;
    final part = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      part,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = AppColors.p1,
    );
    canvas.drawPath(
      part.shift(const Offset(0, 4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = AppColors.p2.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_UnderlinePainter old) => old.progress != progress;
}
