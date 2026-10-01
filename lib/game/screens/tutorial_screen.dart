import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../rendering/paper_painter.dart';
import '../widgets/ink_button.dart';
import '../widgets/tutorial_demos.dart';

class _Page {
  const _Page(this.title, this.points, this.demo);

  final String title;
  final List<String> points;
  final Widget demo;
}

final _pages = <_Page>[
  _Page(
    'Drag to draw',
    const [
      'Put your finger down below your pen and drag.',
      'The pen stays above your finger, so you can always see it.',
      'It leaves a ballpoint line: that is your route.',
    ],
    LoopingDemo(
      painter: (t) => DragDemoPainter(t),
      duration: const Duration(milliseconds: 3600),
    ),
  ),
  _Page(
    'Dots cost points',
    const [
      'Avoid the dots when you can.',
      'Touching one never stops you, but it costs points: small -5, medium -10, large -20.',
      'Your score is the distance you draw minus those penalties.',
    ],
    LoopingDemo(
      painter: (t) => DotsDemoPainter(t),
      duration: const Duration(milliseconds: 4200),
    ),
  ),
  _Page(
    'Reach the other side',
    const [
      "Cross the dashed line on your opponent's side to start hunting.",
      'Longer routes score more distance, but your pen only has so much ink.',
      'Run dry, or lift your finger for too long, and you lose one of 3 attempts.',
    ],
    LoopingDemo(
      painter: (t) => CrossDemoPainter(t),
      duration: const Duration(milliseconds: 3400),
    ),
  ),
  const _Page('Pop a balloon', [
    'Every completed run lets you attack one opponent balloon.',
    'Tap the balloon you want to pop.',
    'The bot races at the same time, and it will go for yours.',
  ], BalloonDemo()),
  const _Page('Win the duel', [
    'Destroy all 3 opponent balloons to win right away.',
    'When the clock runs out: balloons destroyed, then total score, then total distance decide.',
  ], WinDemo()),
];

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pager = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _pager.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.game);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    return Scaffold(
      appBar: AppBar(title: const Text('HOW TO PLAY')),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: PaperPainter(seed: 11)),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pager,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) =>
                        _PageView(page: _pages[i], number: i + 1),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _index ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? AppColors.ink
                              : AppColors.inkFaint.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: InkButton(
                    label: last ? "LET'S PLAY" : 'NEXT',
                    icon: last
                        ? Icons.play_arrow_rounded
                        : Icons.arrow_forward_rounded,
                    primary: last,
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page, required this.number});

  final _Page page;
  final int number;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: (constraints.maxHeight * 0.42).clamp(170.0, 280.0),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.ink, width: 2),
                  boxShadow: const [
                    BoxShadow(color: AppColors.ink, offset: Offset(0, 4)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: page.demo,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '$number',
                style: text.labelLarge?.copyWith(color: AppColors.inkFaint),
              ),
              Text(
                page.title,
                style: text.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final point in page.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 7, right: 10),
                        child: CircleAvatar(
                          radius: 3,
                          backgroundColor: AppColors.ink,
                        ),
                      ),
                      Expanded(child: Text(point, style: text.bodyLarge)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
