import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../rendering/paper_painter.dart';
import '../widgets/ink_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: PaperPainter())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  Text(
                    'DOTLINE\nDUEL',
                    textAlign: TextAlign.center,
                    style: text.displayLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Draw your way through.', style: text.bodyLarge),
                  const Spacer(flex: 4),
                  InkButton(
                    label: 'PLAY',
                    icon: Icons.play_arrow_rounded,
                    primary: true,
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.game),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InkButton(
                    label: 'HOW TO PLAY',
                    icon: Icons.menu_book_rounded,
                    onPressed: () {},
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InkButton(
                    label: 'SETTINGS',
                    icon: Icons.tune_rounded,
                    onPressed: () {},
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
