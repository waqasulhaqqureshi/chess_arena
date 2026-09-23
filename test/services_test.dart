/// Matchmaking + chat brain verification (v7). Run with: flutter test
library;

import 'dart:math';

import 'package:chess_arena/services/chat_brain.dart';
import 'package:chess_arena/services/hybrid_bot_chat_engine.dart';
import 'package:chess_arena/services/matchmaking_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simulated humans get dependency-generated full names + ISO flags',
      () {
    for (var i = 0; i < 25; i++) {
      final id = MatchmakingService.simulatedHuman(1200);
      expect(id.name.trim().contains(' '), isTrue,
          reason: 'full name (first + last)');
      expect(id.flagIso.length, 2);
      expect(id.rating, inInclusiveRange(400, 2400));
    }
  });

  test('form boost rewards winning streaks, softens losing ones', () {
    expect(MatchmakingService.formBoostFor(['w', 'w', 'w', 'w']),
        greaterThan(0));
    expect(MatchmakingService.formBoostFor(['l', 'l', 'l']), lessThan(0));
    expect(MatchmakingService.formBoostFor([]), 0);
  });

  test('eliza brain produces greetings, replies and farewells', () {
    final b = ChatBrain();
    expect(b.greeting().isNotEmpty, isTrue);
    expect(b.farewell().isNotEmpty, isTrue);
    final r = b.reply('I really love playing chess every day');
    expect(r, isNotNull);
    expect(r!.isNotEmpty, isTrue);
  });

  test('typing delay: warm-up floor + scales with length, never instant',
      () {
    final short = HybridBotChatEngine.typingMillis('gg', Random(1));
    final long = HybridBotChatEngine.typingMillis(
        'that was such a fun game omg', Random(1));
    expect(short, greaterThanOrEqualTo(600));
    expect(long, greaterThan(short));
    expect(short, lessThan(2000));
  });

  test('event matrix covers every BotEvent with casual phrases', () {
    final e = HybridBotChatEngine();
    for (final ev in BotEvent.values) {
      expect(e.eventPhrase(ev).isNotEmpty, isTrue);
    }
  });
}
