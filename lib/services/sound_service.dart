/// Central sound effects (move, capture, check, end...).
///
/// Uses bundled WAVs in assets/sounds/. All calls are fire-and-forget and
/// never throw — a missing/broken audio backend must not break the game.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static bool _enabled = true;

  static void configure({required bool enabled}) {
    _enabled = enabled;
  }

  static Future<void> _play(String name) async {
    if (!_enabled) return;
    try {
      final player = AudioPlayer();
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
      await player.play(AssetSource('sounds/$name.wav'));
      // Safety net in case completion never fires.
      Future.delayed(const Duration(seconds: 5), () {
        try {
          player.dispose();
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[Sound] $name failed: $e');
    }
  }

  static void move() => _play('move');
  static void capture() => _play('capture');
  static void check() => _play('check');
  static void castle() => _play('castle');
  static void promote() => _play('promote');
  static void gameStart() => _play('start');
  static void gameEnd() => _play('end');
  static void illegal() => _play('illegal');
  static void click() => _play('click');
  static void win() => _play('win');
}
