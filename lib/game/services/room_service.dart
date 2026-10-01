import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/network_opponent.dart';
import '../models/game_config.dart';

/// A 6-character room code using unambiguous uppercase letters and digits.
/// Avoids O/0, I/1, S/5 to prevent misreading.
String generateRoomCode() {
  const chars = 'ABCDEFGHJKLMNPQRTUVWXYZ2346789';
  final rng = Random.secure();
  return String.fromCharCodes(
    List.generate(6, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
  );
}

enum RoomStatus { waiting, playing, finished }

/// Room state snapshot.
class RoomSnapshot {
  const RoomSnapshot({
    required this.roomCode,
    required this.roomId,
    required this.status,
    required this.obstacleSeed,
    required this.matchStartAt,
    required this.hostId,
    required this.guestId,
    required this.isHost,
  });

  final String roomCode;
  final String roomId;
  final RoomStatus status;
  final int obstacleSeed;
  final DateTime? matchStartAt;
  final String hostId;
  final String? guestId;
  final bool isHost;

  bool get isFull => guestId != null;

  RoomSnapshot copyWith({
    RoomStatus? status,
    DateTime? matchStartAt,
    String? guestId,
  }) => RoomSnapshot(
    roomCode: roomCode,
    roomId: roomId,
    status: status ?? this.status,
    obstacleSeed: obstacleSeed,
    matchStartAt: matchStartAt ?? this.matchStartAt,
    hostId: hostId,
    guestId: guestId ?? this.guestId,
    isHost: isHost,
  );
}

/// Manages the Supabase room lifecycle and Realtime sync for Private Room mode.
///
/// Usage:
///   final service = RoomService(supabase: Supabase.instance.client);
///   await service.createRoom();         // host path
///   await service.joinRoom('ABC123');   // guest path
///   service.sendPosition(x, y, pen);   // every frame while playing
///   service.dispose();                  // on screen dispose
class RoomService {
  RoomService({required this.supabase});

  final SupabaseClient supabase;

  final ValueNotifier<RoomSnapshot?> room = ValueNotifier(null);
  final ValueNotifier<String?> error = ValueNotifier(null);

  /// Set by the GameScreen so the service can forward remote positions.
  NetworkOpponent? networkOpponent;

  /// The GameConfig used in this match (needed to de-normalize coords).
  GameConfig? gameConfig;

  RealtimeChannel? _channel;
  String? _myId;

  String get _userId {
    _myId ??= supabase.auth.currentUser?.id ?? _anonId();
    return _myId!;
  }

  static String? _cachedAnonId;
  static String _anonId() {
    _cachedAnonId ??=
        'anon_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    return _cachedAnonId!;
  }

  // ---------------------------------------------------------------- Host path

  Future<void> createRoom() async {
    error.value = null;
    try {
      final code = generateRoomCode();
      final seed = Random().nextInt(1 << 30);
      final res = await supabase
          .from('rooms')
          .insert({
            'code': code,
            'status': 'waiting',
            'obstacle_seed': seed,
            'host_id': _userId,
          })
          .select()
          .single();

      room.value = RoomSnapshot(
        roomCode: code,
        roomId: res['id'] as String,
        status: RoomStatus.waiting,
        obstacleSeed: seed,
        matchStartAt: null,
        hostId: _userId,
        guestId: null,
        isHost: true,
      );
      _subscribeToRoom(res['id'] as String);
    } catch (e) {
      error.value = 'Failed to create room: $e';
    }
  }

  // --------------------------------------------------------------- Guest path

  Future<void> joinRoom(String code) async {
    error.value = null;
    try {
      final res = await supabase
          .from('rooms')
          .select()
          .eq('code', code.toUpperCase())
          .eq('status', 'waiting')
          .is_('guest_id', null)
          .single();

      final roomId = res['id'] as String;
      await supabase
          .from('rooms')
          .update({'guest_id': _userId})
          .eq('id', roomId);

      room.value = RoomSnapshot(
        roomCode: code.toUpperCase(),
        roomId: roomId,
        status: RoomStatus.waiting,
        obstacleSeed: res['obstacle_seed'] as int,
        matchStartAt: null,
        hostId: res['host_id'] as String,
        guestId: _userId,
        isHost: false,
      );
      _subscribeToRoom(roomId);
    } catch (e) {
      error.value = 'Room not found or already full.';
    }
  }

  // -------------------------------------------------------- Host: start match

  Future<void> startMatch() async {
    final r = room.value;
    if (r == null || !r.isHost || !r.isFull) return;
    final startAt = DateTime.now().add(const Duration(seconds: 4));
    await supabase
        .from('rooms')
        .update({
          'status': 'playing',
          'match_start_at': startAt.toIso8601String(),
        })
        .eq('id', r.roomId);
  }

  // --------------------------------------------------------- Realtime channel

  void _subscribeToRoom(String roomId) {
    _channel = supabase.channel('room:$roomId');

    // Room-level changes (guest joined, status → playing, etc.)
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rooms',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: roomId,
          ),
          callback: (payload) => _onRoomUpdate(payload.newRecord),
        )
        // Broadcast: opponent's live pen position
        .onBroadcast(
          event: 'pos',
          callback: (payload) => _onRemotePosition(payload),
        )
        .subscribe();
  }

  void _onRoomUpdate(Map<String, dynamic> row) {
    final r = room.value;
    if (r == null) return;
    final status = switch (row['status'] as String?) {
      'playing' => RoomStatus.playing,
      'finished' => RoomStatus.finished,
      _ => RoomStatus.waiting,
    };
    final startAtStr = row['match_start_at'] as String?;
    room.value = r.copyWith(
      status: status,
      matchStartAt: startAtStr != null ? DateTime.parse(startAtStr) : null,
      guestId: row['guest_id'] as String?,
    );
  }

  void _onRemotePosition(Map<String, dynamic> payload) {
    final opponent = networkOpponent;
    final config = gameConfig;
    if (opponent == null || config == null) return;
    // Ignore our own broadcasts echoed back.
    if (payload['uid'] == _userId) return;
    opponent.applyRemoteState(
      normalizedX: (payload['x'] as num).toDouble(),
      normalizedY: (payload['y'] as num).toDouble(),
      penDown: payload['p'] as bool? ?? false,
      worldWidth: config.worldWidth,
      worldHeight: config.worldHeight,
    );
  }

  // --------------------------------------------------------- Outbound sync

  /// Call this every game frame with the local player's world position.
  void sendPosition(double worldX, double worldY, bool penDown) {
    final config = gameConfig;
    if (config == null || _channel == null) return;
    _channel!.sendBroadcastMessage(
      event: 'pos',
      payload: {
        'uid': _userId,
        'x': worldX / config.worldWidth,
        'y': worldY / config.worldHeight,
        'p': penDown,
      },
    );
  }

  Future<void> endMatch() async {
    final r = room.value;
    if (r == null) return;
    await supabase
        .from('rooms')
        .update({'status': 'finished'})
        .eq('id', r.roomId);
  }

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
    room.dispose();
    error.dispose();
  }
}
