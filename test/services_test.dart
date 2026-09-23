/// Matchmaking + chat brain verification (v7). Run with: flutter test
library;

import 'package:chess_arena/services/chat_brain.dart';
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
}
