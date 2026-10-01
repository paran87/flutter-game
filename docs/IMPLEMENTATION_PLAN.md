# Dotline Duel — Implementation Plan

> "Draw your way through."

## Reference analysis

The reference sketch shows a portrait board with three rings at the top
(player 2) and three at the bottom (player 1), a ragged rectangle of
hundreds of ink dots in the middle, a timer in the top-right, and two
hand-drawn ballpoint lines (red and blue) wandering through the dots from
one side to the other. Dotline Duel keeps that composition — balloons at
each end of the page, a dense organic dot field, red/blue ballpoint traces —
and wraps it in a casual mobile-game UI.

## Core rules (as implemented)

| Topic | Rule |
| --- | --- |
| Turn model | Both players race **simultaneously** through the same dot field in one continuous match (no rounds). |
| Movement | Human drags; the marker sits *above* the finger (configurable offset) and eases toward it with a speed cap. Bot follows a generated path through the same movement integrator. |
| Collision | Touching a dot never stops a run. It costs points by dot size (5/10/20), flashes the dot, shakes the marker, briefly slows the pen, and fires a haptic. Each dot can only be re-penalised after it was left *and* the cooldown (300 ms) expired. |
| Score | Live run score = distance − penalties (floored at 0). It is **banked** only when the run pops a balloon. |
| Ink | Each run has a limited amount of ink (path length). Running dry fails the run. This caps the "scribble for distance" exploit and creates the long-route-vs-safe-route trade-off. |
| Attempts | Consumed only by failed runs: *out of ink*, or *pen lifted* for longer than the grace period mid-run. A player with 0 attempts sits out; if both are out, the game ends. |
| Balloons | After crossing the opponent's line the pen keeps going and must physically touch an opponent balloon to pop it (one per run). The pen then respawns at its start; the opponent is never interrupted. |
| Timer | 2:00 game clock, running continuously once play starts. Warning states at 0:30 and 0:10. Final totals appear on the result screen. |
| Win | Destroy all three opponent balloons, or when the clock expires: balloons destroyed → total score → total distance → draw. |

## Architecture

```
lib/
  main.dart                 entry point
  app/                      MaterialApp, theme, routes
  game/
    models/                 plain data: config, players, dots, balloons, stats, state
    controllers/            game logic: orchestration, agents (human/bot), collision,
                            scoring, timer, movement, win resolution, effects
    rendering/              CustomPainters: paper, obstacles, traces, board, balloons
    services/               audio + haptics interfaces, settings
    widgets/                HUD pieces and overlays
    screens/                home, game, tutorial, settings, result
    utils/                  geometry, distance, collision maths, obstacle generation
```

Key decisions:

* **World coordinates.** The board is a fixed 1000 × 1600 world, uniformly
  scaled to fit the available space. Gameplay and scoring are identical on
  every phone; only the rendering scale changes.
* **One movement rule for everyone.** Both players are driven by a
  `PlayerAgent` that only expresses *intent* (target point + pen state).
  `TouchPlayerAgent` (human) and `BotController` (AI) implement it; a future
  `RemotePlayerAgent` can feed network input through the same interface.
* **Frame loop without widget rebuilds.** A `Ticker` drives
  `GameController.tick(dt)`. Painters repaint from a frame `Listenable`; HUD
  widgets listen to small notifiers that only fire when a displayed value
  changes. The obstacle layer is cached behind a `RepaintBoundary`.
* **Deterministic & testable.** All timing is driven by `tick(dt)` (no
  `Future.delayed` in game logic), obstacle generation is seeded, and rules
  live in pure classes that are unit-tested.

## Phases

1. Gameplay UI with mock data (theme, HUD, board shell, home screen).
2. Obstacle field generator + painter, player markers.
3. Human touch movement with finger offset and smoothing.
4. Ballpoint trace rendering.
5. Obstacle collision, penalties, cooldown, feedback.
6. Distance tracking, ink, attempts, failures.
7. Balloon targeting and destruction animation.
8. Countdown timer and win conditions, result screen.
9. Bot movement / pathfinding with difficulty levels.
10. Polish: animations, tutorial, settings, haptics/audio services, debug mode, balance.
