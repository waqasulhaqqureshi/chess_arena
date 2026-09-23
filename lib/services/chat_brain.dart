/// Opponent chat brain — dependency-backed (offline ELIZA via
/// `eliza_chat`), wrapped so chess-context lines (draw offers, greetings,
/// gg) stay on topic while free-form messages get genuine conversational
/// replies instead of canned strings.
library;

import 'package:eliza_chat/eliza_chat.dart';

class ChatBrain {
  final Eliza _eliza = Eliza();

  /// Opening line when the game starts.
  String greeting() {
    try {
      return _eliza.getInitial();
    } catch (_) {
      return 'hi, good luck!';
    }
  }

  /// Parting line at game end.
  String farewell() {
    try {
      return _eliza.getFinal();
    } catch (_) {
      return 'gg, well played!';
    }
  }

  /// Conversational reply to a player message; null-safe.
  String? reply(String input) {
    try {
      final r = _eliza.processInput(input);
      if (r != null && r.trim().isNotEmpty) return r;
    } catch (_) {}
    return null;
  }
}
