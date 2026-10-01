# Dotline Duel

> *Draw your way through.*

A two-player, mobile-first Flutter game. Each player drags a ballpoint pen
through a dense field of ink dots toward the opponent's side. Every crossing
pops one of the opponent's three balloons, and the first player to pop all
three wins. Player 1 is you; Player 2 is a bot that plays by exactly the same
rules.

Built with Flutter 3.47 / Dart 3.13 and no third-party runtime packages:
`CustomPainter`, `Ticker` and `ValueNotifier` throughout.

## Running

```bash
flutter pub get
flutter run                      # Android / iOS device or emulator
flutter run -d chrome            # quick look in a browser
flutter test                     # 72 unit + widget tests
```

Dev flag for a quick end-of-game check:
`flutter run --dart-define=MATCH_SECONDS=15`

## How a match plays

1. **Draw.** Put your finger down below your pen and drag. The pen sits
   above your finger (configurable offset) and eases toward it with a speed
   cap, so it never hides under your thumb or snaps around.
2. **Dots cost points, never stop you.** Touching a dot costs 5/10/20 points
   by size, flashes it, shakes the pen and briefly slows it. A dot charges
   once per contact, and touching the same dot again within 300 ms is free.
3. **Score = distance − penalties.** Distance is the length of the path you
   actually drew, so winding routes count. The run score is banked only
   when you reach the opponent's dashed line.
4. **Ink and attempts.** Each run has limited ink. Running dry, or lifting
   your finger for more than 1.5 s mid-run, fails the run and costs one of
   your 3 attempts. Touching dots never costs an attempt.
5. **Attack.** The first player across each round taps (or the bot picks)
   one opponent balloon to pop. Then both players reset on a fresh dot field.
6. **Win.** Pop all three balloons. If the 2-minute clock runs out first
   (it only runs while players are racing), the winner is decided by
   balloons destroyed, then total score, then total distance, else a draw.

## Project layout

```
lib/
  main.dart                      portrait lock + app start
  app/                           MaterialApp, routes, theme/palette
  game/
    models/                      plain data: GameConfig, Player (+HUD snapshot),
                                 ObstacleDot/Field, Balloon, InkTrace, stats,
                                 phases, results, effects
    controllers/
      game_controller.dart       the state machine (phases, rounds, rules)
      player_agent.dart          PlayerAgent interface + touch agent
      bot_controller.dart        the AI (cost grid + A* + smoothing)
      movement_controller.dart   easing, speed caps, play-area clamp
      collision_controller.dart  swept collision, enter-only + cooldown
      scoring_controller.dart    penalties, run/live/banked score
      timer_controller.dart      match clock and warning levels
      win_resolver.dart          winner + reason (pure function)
      effects_controller.dart    floating text, flashes, bursts
    rendering/                   CustomPainters: paper, dots, ballpoint trace,
                                 board (per frame), balloons, effects, debug
    services/                    audio + haptics behind GameFeedback; settings
    widgets/                     HUD, overlays, balloons, tutorial demos
    screens/                     home, game, tutorial, settings, result
    utils/                       obstacle generator, distance/collision/path maths
test/                            rules, flow, bot and widget tests
docs/IMPLEMENTATION_PLAN.md      design notes and phase plan
```

### Key design decisions

* **Fixed world, uniform scale.** The board is a 1000 × 1600 world scaled
  to fit the screen, so scoring and difficulty are identical on every phone.
  The HUD adapts separately: compact cards and timer below 370 dp.
* **Agents only express intent.** `PlayerAgent.update()` returns a target
  point and pen state, and `chooseBalloon()` picks a target. The controller
  applies the same movement, collision and scoring to everyone. The human is
  `TouchPlayerAgent` and the bot is `BotController`. **A networked opponent
  is just another `PlayerAgent`** that feeds remote input; nothing else
  needs to change.
* **No per-frame widget rebuilds.** A `Ticker` drives `GameController.tick`.
  The board painter repaints from a frame `Listenable`. HUD widgets listen to
  value-equality snapshots that only notify when a displayed number changes.
  The dot field is cached behind a `RepaintBoundary`, and trace geometry is
  cached per chunk so only the newest segment is rebuilt each frame.
* **Deterministic and testable.** All timing goes through `tick(dt)`, never
  `Future.delayed`, and layouts are seeded (`GameConfig.obstacleSeed`), so whole
  matches, including bot-vs-bot, run headlessly in tests.

## Tuning

Every gameplay number lives in `lib/game/models/game_config.dart`: match
length, balloons, attempts, speeds, touch offset, smoothing, dot density and
sizes, collision tolerance, penalties per size, cooldown, slowdown, distance
scale, ink capacity, pen-lift grace, trace look, phase timings and bot
profiles. Player-facing options (difficulty, match length, pen offset, the
pen-lift rule, haptics, sound, debug overlay) are on the Settings screen.

The bot difficulties were tuned against seeded simulations (see
`test/bot_test.dart`): harder bots cross faster and touch fewer dots.

## Debug mode

Settings → Developer → *Debug overlay* shows pen coordinates, phase, timer,
run/total distance, scores, penalties, collision status, ink, attempts,
balloons, the bot's planned path, every trace sample point, pen collision
radii, and the dots currently being touched.

## Audio

`GameSound` lists every event (button, movement, collision, pop, success,
failure, countdown, warning, victory, defeat), and `AudioService` is the
seam for real assets. No audio files are bundled yet. The default service
plays only the platform's own UI click, so no third-party or copyrighted
sounds are included.

## Not in this prototype

* Online multiplayer (the `PlayerAgent` seam is ready for it).
* Persisted settings (they're in-memory; `SettingsController` is the single
  place to add `shared_preferences`).
* Bundled sound effects and a custom app icon.
