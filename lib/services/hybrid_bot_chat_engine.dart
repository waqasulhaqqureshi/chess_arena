/// HybridBotChatEngine — the bot's voice.
///
/// Layer 1 (contextual): Google ML Kit **Smart Reply** via the standalone
/// `google_mlkit_smart_reply` package (NOT the monolithic `google_ml_kit`,
/// which would bloat the app 100 MB+). Reads the real conversation and
/// suggests replies on-device.
///
/// Layer 2 (contextual fallback): the offline ELIZA brain (`eliza_chat`)
/// when the ML model is unavailable (desktop/web/CI) or returns nothing.
///
/// Layer 3 (event-driven): a hardcoded phrase matrix for game-state events
/// (blunders, low time, checkmate…) and as the last safety net. Casual,
/// modern, female-biased tone.
///
/// Every outgoing line passes through a human **typing delay**
/// (~0.6 s warm-up + ~38 ms/char + jitter) so replies never land in 0.1 s.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_smart_reply/google_mlkit_smart_reply.dart';

import 'chat_brain.dart';

enum BotEvent {
  greeting,
  blunder,
  brilliant,
  lowTime,
  checkGiven,
  playerPromotion,
  drawOffered,
  win,
  loss,
  draw,
  smalltalk,
}

class HybridBotChatEngine {
  HybridBotChatEngine();

  final ChatBrain _eliza = ChatBrain();
  final Random _rng = Random();
  SmartReply? _sr;
  bool _mlProbed = false;
  bool _mlAvailable = false;

  bool get mlAvailable => _mlAvailable;

  /// Probes ML Kit once; never throws (desktop/web/CI → false).
  Future<bool> _ensureMl() async {
    if (_mlProbed) return _mlAvailable;
    _mlProbed = true;
    try {
      _sr = SmartReply();
      _mlAvailable = true;
      debugPrint('[Chat] ML Kit Smart Reply ready');
    } catch (e) {
      debugPrint('[Chat] ML Kit unavailable, ELIZA + matrix fallback: $e');
      _mlAvailable = false;
    }
    return _mlAvailable;
  }

  // ------------------------------------------------------ typing cadence

  /// Human-feeling typing time: warm-up + per-char typing + jitter.
  static int typingMillis(String text, [Random? rng]) =>
      600 + text.length * 38 + (rng ?? Random()).nextInt(500);

  Future<void> _typingDelay(String text) =>
      Future.delayed(Duration(milliseconds: typingMillis(text, _rng)));

  // ------------------------------------------------------- event matrix

  static const Map<BotEvent, List<String>> _matrix = {
    BotEvent.greeting: [
      'heyy 🙂 glhf!',
      'hii! good luck have fun',
      'hey, ready when you are 😄',
    ],
    BotEvent.blunder: [
      'omg nooo i meant that?? 😅',
      'wait thats not what i planned lol',
      'ugh my hand slipped fr 😭',
    ],
    BotEvent.brilliant: [
      'ok that was clean ngl',
      'wow nice one!!',
      'sheesh you play good 😳',
    ],
    BotEvent.lowTime: [
      'my clock is screaming 😭',
      'brb panicking lol',
      'ok ok thinking thinking!!',
    ],
    BotEvent.checkGiven: ['check!! 👀', 'oops check hehe', 'watch the king 👑'],
    BotEvent.playerPromotion: [
      'of course the queen 😒',
      'omg another queen wow',
      'queening everything fr',
    ],
    BotEvent.drawOffered: [
      'hmm idk let me think 🤔',
      'maybe later, im having fun rn',
      'draw? you scared? 😏',
    ],
    BotEvent.win: [
      'gg!! that was so fun 🥳',
      'yay gg wp!! rematch?',
      'gggg good game!!',
    ],
    BotEvent.loss: [
      'aww gg, you got me 😭',
      'gg wp!! that was intense',
      'nooo gg, rematch pls 🙏',
    ],
    BotEvent.draw: ['ok draw it is 🤝 gg!', 'gg, fair enough 🤝'],
    BotEvent.smalltalk: [
      'lol true',
      'haha yeah 😄',
      'omg same fr',
      'wait really?',
      'hehe ok ok',
    ],
  };

  /// Synchronous random phrase for an event (no typing delay).
  String eventPhrase(BotEvent e) {
    final opts = _matrix[e]!;
    return opts[_rng.nextInt(opts.length)];
  }

  /// Event phrase delivered after a human typing delay.
  Future<String> phraseFor(BotEvent e) async {
    final t = eventPhrase(e);
    await _typingDelay(t);
    return t;
  }

  // -------------------------------------------------- conversation feed

  void notePlayerMessage(String text) {
    final sr = _sr;
    if (sr == null) return;
    try {
      sr.addMessageToConversationFromRemoteUser(
        text,
        DateTime.now().millisecondsSinceEpoch,
        'player',
      );
    } catch (e) {
      debugPrint('[Chat] ml feed failed: $e');
      _mlAvailable = false;
    }
  }

  void noteBotMessage(String text) {
    final sr = _sr;
    if (sr == null) return;
    try {
      sr.addMessageToConversationFromLocalUser(
        text,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  /// Contextual reply to a free-text player message:
  /// ML Kit → ELIZA → matrix smalltalk. Always typing-delayed.
  Future<String> replyTo(String playerText) async {
    notePlayerMessage(playerText);
    String? text;
    if (await _ensureMl()) {
      try {
        final res = await _sr!.suggestReplies();
        final opts = res.suggestions
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (opts.isNotEmpty) text = opts[_rng.nextInt(opts.length)];
      } catch (e) {
        debugPrint('[Chat] suggestReplies failed: $e');
        _mlAvailable = false;
      }
    }
    text ??= _eliza.reply(playerText);
    text ??= eventPhrase(BotEvent.smalltalk);
    noteBotMessage(text);
    await _typingDelay(text);
    return text;
  }

  Future<void> dispose() async {
    try {
      await _sr?.close();
    } catch (_) {}
    _sr = null;
  }
}
