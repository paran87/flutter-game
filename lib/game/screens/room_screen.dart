import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../controllers/network_opponent.dart';
import '../models/game_config.dart';
import '../services/room_service.dart';
import '../services/settings_controller.dart';
import '../widgets/ink_button.dart';
import 'game_screen.dart';

enum _RoomPhase { chooser, creating, joining, waiting }

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final RoomService _service = RoomService(
    supabase: Supabase.instance.client,
  );

  _RoomPhase _phase = _RoomPhase.chooser;
  final _codeController = TextEditingController();
  String? _joinError;
  StreamSubscription<RoomSnapshot?>? _roomSub;

  @override
  void initState() {
    super.initState();
    _roomSub = _service.room.listen(_onRoomChanged);
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _service.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onRoomChanged(RoomSnapshot? snap) {
    if (snap == null) return;
    // Guest joined → host sees the waiting room fill.
    if (_phase == _RoomPhase.waiting && snap.status == RoomStatus.waiting) {
      setState(() {});
    }
    // Match started → go to game.
    if (snap.status == RoomStatus.playing && snap.matchStartAt != null) {
      _launchGame(snap);
    }
  }

  Future<void> _createRoom() async {
    setState(() => _phase = _RoomPhase.creating);
    await _service.createRoom();
    if (_service.error.value != null) {
      if (mounted) {
        setState(() => _phase = _RoomPhase.chooser);
        _showError(_service.error.value!);
      }
      return;
    }
    if (mounted) setState(() => _phase = _RoomPhase.waiting);
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _joinError = 'Enter the full 6-character code.');
      return;
    }
    setState(() { _joinError = null; _phase = _RoomPhase.creating; });
    await _service.joinRoom(code);
    if (_service.error.value != null) {
      if (mounted) {
        setState(() { _phase = _RoomPhase.joining; _joinError = _service.error.value; });
      }
      return;
    }
    if (mounted) {
      setState(() => _phase = _RoomPhase.waiting);
      // Guest joined — if both are present, host will start; tell the guest to wait.
    }
  }

  void _launchGame(RoomSnapshot snap) {
    final settings = SettingsScope.of(context).value;
    final config = settings
        .toConfig()
        .copyWith(obstacleSeed: snap.obstacleSeed);

    final opponent = NetworkOpponent(maxSpeed: config.playerSpeed * 1.1);
    _service.networkOpponent = opponent;
    _service.gameConfig = config;

    // Wait until matchStartAt, then push.
    final delay = snap.matchStartAt!.difference(DateTime.now());
    Future.delayed(delay.isNegative ? Duration.zero : delay, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        inkRoute(
          GameScreen(
            config: config,
            settings: settings,
            topAgent: opponent,
            roomService: _service,
          ),
        ),
      );
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.p1),
    );
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.ink,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'PRIVATE ROOM',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildPhase(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase() {
    return switch (_phase) {
      _RoomPhase.chooser => _ChooserView(
        key: const ValueKey('chooser'),
        onCreate: _createRoom,
        onJoin: () => setState(() => _phase = _RoomPhase.joining),
      ),
      _RoomPhase.creating => const _LoadingView(
        key: ValueKey('creating'),
        message: 'Setting up room…',
      ),
      _RoomPhase.joining => _JoinView(
        key: const ValueKey('joining'),
        controller: _codeController,
        error: _joinError,
        onJoin: _joinRoom,
        onBack: () => setState(() {
          _phase = _RoomPhase.chooser;
          _joinError = null;
        }),
      ),
      _RoomPhase.waiting => _WaitingView(
        key: const ValueKey('waiting'),
        service: _service,
        onStart: _service.room.value?.isHost == true &&
                _service.room.value?.isFull == true
            ? _service.startMatch
            : null,
      ),
    };
  }
}

// ---------------------------------------------------------------- Sub-widgets

class _ChooserView extends StatelessWidget {
  const _ChooserView({
    super.key,
    required this.onCreate,
    required this.onJoin,
  });

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.people_alt_rounded, size: 64, color: AppColors.p2),
        const SizedBox(height: 24),
        Text(
          'Play with a friend on the same\nWi-Fi or mobile data.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 48),
        InkButton(
          label: 'CREATE ROOM',
          icon: Icons.add_rounded,
          primary: true,
          onPressed: onCreate,
        ),
        const SizedBox(height: 16),
        InkButton(
          label: 'JOIN ROOM',
          icon: Icons.login_rounded,
          onPressed: onJoin,
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AppColors.p1),
        const SizedBox(height: 24),
        Text(message, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _JoinView extends StatelessWidget {
  const _JoinView({
    super.key,
    required this.controller,
    required this.error,
    required this.onJoin,
    required this.onBack,
  });

  final TextEditingController controller;
  final String? error;
  final VoidCallback onJoin;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Enter Room Code',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ask your friend for the 6-character code.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            _UpperCaseFormatter(),
          ],
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            letterSpacing: 12,
            fontWeight: FontWeight.w900,
          ),
          decoration: InputDecoration(
            hintText: 'ABC123',
            errorText: error,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            counterText: '',
          ),
          onSubmitted: (_) => onJoin(),
        ),
        const SizedBox(height: 24),
        InkButton(
          label: 'JOIN',
          icon: Icons.login_rounded,
          primary: true,
          onPressed: onJoin,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onBack,
          child: const Text('← Back'),
        ),
      ],
    );
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({
    super.key,
    required this.service,
    this.onStart,
  });

  final RoomService service;
  final Future<void> Function()? onStart;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RoomSnapshot?>(
      valueListenable: service.room,
      builder: (context, snap, _) {
        if (snap == null) return const SizedBox.shrink();
        final code = snap.roomCode;
        final guestConnected = snap.isFull;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Room Code',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                letterSpacing: 2,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Room code copied!')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.p2Light,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.p2.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      code,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.copy_rounded, size: 20, color: AppColors.inkSoft),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _PlayerSlot(label: snap.isHost ? 'YOU (HOST)' : 'HOST', connected: true),
            const SizedBox(height: 12),
            _PlayerSlot(
              label: snap.isHost ? 'OPPONENT' : 'YOU',
              connected: guestConnected,
            ),
            const SizedBox(height: 40),
            if (snap.isHost && guestConnected) ...[
              InkButton(
                label: 'START MATCH',
                icon: Icons.play_arrow_rounded,
                primary: true,
                onPressed: onStart != null ? () => onStart!() : null,
              ),
            ] else if (!guestConnected) ...[
              const CircularProgressIndicator(color: AppColors.p1),
              const SizedBox(height: 16),
              Text(
                snap.isHost
                    ? 'Waiting for opponent to join…'
                    : 'Waiting for host to start…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else ...[
              Text(
                'Opponent joined! Waiting for host…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  const _PlayerSlot({required this.label, required this.connected});

  final String label;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: connected
            ? AppColors.p1.withValues(alpha: 0.08)
            : AppColors.inkSoft.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: connected
              ? AppColors.p1.withValues(alpha: 0.35)
              : AppColors.inkSoft.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.person_rounded : Icons.person_outline_rounded,
            color: connected ? AppColors.p1 : AppColors.inkSoft,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: connected ? AppColors.ink : AppColors.inkSoft,
            ),
          ),
          const Spacer(),
          Text(
            connected ? 'CONNECTED' : 'WAITING…',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: connected ? AppColors.p1 : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// Forces text input to uppercase.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
