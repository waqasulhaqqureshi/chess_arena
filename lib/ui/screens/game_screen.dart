/// Game screen — wood theme, player bars, board, captures, move list.
///
/// Performance: the 100 ms clock ticker only rebuilds the tiny clock
/// leaves — board / move-list subtrees are [Selector]-gated on immutable
/// snapshots ([_BoardView], [_InfoView]) so they rebuild solely on moves.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repository/arena_repository.dart';
import '../../engine/chess_rules.dart';
import '../../game/game_controller.dart';
import '../../services/ads_service.dart';
import '../dialogs/app_dialogs.dart';
import '../widgets/app_widgets.dart';
import '../widgets/chess_board_widget.dart';
import '../widgets/piece_widget.dart';
import '../widgets/player_bar.dart';

class GameScreen extends StatelessWidget {
  final GameSetup setup;
  const GameScreen({super.key, required this.setup});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => GameController(
        repo: ctx.read<ArenaRepository>(),
        settings: ctx.read<SettingsController>(),
        setup: setup,
      ),
      child: const _GameBody(),
    );
  }
}

// ---------------------------------------------------------------- snapshots

class _TopState {
  final bool thinking;
  final bool over;
  const _TopState(this.thinking, this.over);

  @override
  bool operator ==(Object o) =>
      o is _TopState && thinking == o.thinking && over == o.over;
  @override
  int get hashCode => thinking.hashCode ^ over.hashCode;
}

class _ClockView {
  final double ms;
  final bool active;
  const _ClockView(this.ms, this.active);

  @override
  bool operator ==(Object o) =>
      o is _ClockView && ms == o.ms && active == o.active;
  @override
  int get hashCode => ms.hashCode ^ active.hashCode;
}

class _BoardView {
  final int len;
  final int? sel;
  final String targets;
  final int? lastFrom;
  final int? lastTo;
  final int? check;
  final int? pendF;
  final int? pendT;
  final bool showLast;
  final bool animate;
  const _BoardView({
    required this.len,
    required this.sel,
    required this.targets,
    required this.lastFrom,
    required this.lastTo,
    required this.check,
    required this.pendF,
    required this.pendT,
    required this.showLast,
    required this.animate,
  });

  factory _BoardView.from(GameController c, bool showLast, bool animate) {
    return _BoardView(
      len: c.game.moveHistory.length,
      sel: c.selected,
      targets: c.selectedMoves
          .map((m) => '${m.from}-${m.to}-${m.promotion}')
          .join(','),
      lastFrom: c.lastMove?.from,
      lastTo: c.lastMove?.to,
      check: c.kingInCheckSquare(),
      pendF: c.pendingFrom,
      pendT: c.pendingTo,
      showLast: showLast,
      animate: animate,
    );
  }

  @override
  bool operator ==(Object o) =>
      o is _BoardView &&
      len == o.len &&
      sel == o.sel &&
      targets == o.targets &&
      lastFrom == o.lastFrom &&
      lastTo == o.lastTo &&
      check == o.check &&
      pendF == o.pendF &&
      pendT == o.pendT &&
      showLast == o.showLast &&
      animate == o.animate;

  @override
  int get hashCode => Object.hash(
      len, sel, targets, lastFrom, lastTo, check, pendF, pendT, showLast);
}

class _InfoView {
  final String status;
  final String moves;
  final String caps;
  final int diff;
  const _InfoView(this.status, this.moves, this.caps, this.diff);

  factory _InfoView.from(GameController c) {
    final (w, b) = c.capturedPieces();
    return _InfoView(
      c.statusText(),
      c.game.sanHistory.join(' '),
      '${w.join(',')}|${b.join(',')}',
      c.materialDiff(),
    );
  }

  @override
  bool operator ==(Object o) =>
      o is _InfoView &&
      status == o.status &&
      moves == o.moves &&
      caps == o.caps &&
      diff == o.diff;
  @override
  int get hashCode => Object.hash(status, moves, caps, diff);
}

// ------------------------------------------------------------------- body

class _GameBody extends StatefulWidget {
  const _GameBody();

  @override
  State<_GameBody> createState() => _GameBodyState();
}

class _GameBodyState extends State<_GameBody> {
  bool _promoOpen = false;
  bool _overOpen = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<GameController>();
    c.addListener(_onController);
  }

  @override
  void dispose() {
    try {
      context.read<GameController>().removeListener(_onController);
    } catch (_) {}
    super.dispose();
  }

  void _onController() {
    final c = context.read<GameController>();
    if (c.promotionRequest != null && !_promoOpen) {
      _promoOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final req = c.promotionRequest;
        final pick = req == null
            ? null
            : await showPromotionDialog(context, req.white);
        _promoOpen = false;
        await c.answerPromotion(pick);
      });
    }
    if (c.gameOverInfo != null && !_overOpen) {
      _overOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || c.gameOverInfo == null) return;
        final action = await showGameOverDialog(
            context, c.gameOverInfo!, c.setup);
        if (!mounted) return;
        if (action == 'rematch') {
          final setup = c.setup;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GameScreen(
                setup: GameSetup(
                  rated: setup.rated,
                  opponentName: setup.opponentName,
                  opponentFlag: setup.opponentFlag,
                  opponentRating: setup.opponentRating,
                  difficulty: setup.difficulty,
                  playerIsWhite: !setup.playerIsWhite, // swap colors
                  timeControl: setup.timeControl,
                ),
              ),
            ),
          );
        } else {
          Navigator.of(context).pop(); // 'new' + 'home' → back
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = context.read<GameController>().setup;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0E04), Color(0xFF4A2A10)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Selector<GameController, _TopState>(
                selector: (_, c) => _TopState(c.cpuThinking, c.isGameOver),
                builder: (_, v, __) => _topBar(context, v),
              ),
              // Opponent bar (rebuilds on clock ticks only).
              Selector<GameController, _ClockView>(
                selector: (_, c) => _ClockView(
                  setup.playerIsWhite ? c.blackMs : c.whiteMs,
                  !c.isGameOver &&
                      c.game.whiteToMove == !setup.playerIsWhite,
                ),
                builder: (_, clock, __) => PlayerBar(
                  name: setup.opponentName,
                  flag: setup.opponentFlag,
                  rating: setup.opponentRating,
                  clockText: formatClock(clock.ms),
                  active: clock.active,
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: RepaintBoundary(
                  child: Selector2<GameController, SettingsController,
                      _BoardView>(
                    selector: (_, c, s) => _BoardView.from(
                        c, s.showLastMove, s.pieceAnimation),
                    builder: (_, v, __) {
                      final c = context.read<GameController>();
                      return ChessBoardWidget(
                        game: c.game,
                        orientationWhite: setup.playerIsWhite,
                        onTap: c.tapSquare,
                        selected: v.sel,
                        selectedMoves: c.selectedMoves,
                        lastMove: c.lastMove,
                        checkSquare: v.check,
                        pendingFrom: v.pendF,
                        pendingTo: v.pendT,
                        showLastMove: v.showLast,
                        animate: v.animate,
                        animKey: v.len,
                      );
                    },
                  ),
                ),
              ),
              // Player bar (rebuilds on clock ticks only).
              Selector<GameController, _ClockView>(
                selector: (_, c) => _ClockView(
                  setup.playerIsWhite ? c.whiteMs : c.blackMs,
                  !c.isGameOver &&
                      c.game.whiteToMove == setup.playerIsWhite,
                ),
                builder: (_, clock, __) {
                  final repo = context.watch<ArenaRepository>();
                  return PlayerBar(
                    name: '${repo.name} (You)',
                    flag: repo.flagEmoji,
                    rating: repo.rating,
                    clockText: formatClock(clock.ms),
                    active: clock.active,
                  );
                },
              ),
              Expanded(
                child: Selector<GameController, _InfoView>(
                  selector: (_, c) => _InfoView.from(c),
                  builder: (_, v, __) => _infoPanel(context, v),
                ),
              ),
              if (AdsService.showBannerPlaceholder)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.movie_filter,
                          size: 14, color: AppColors.textDim),
                      const SizedBox(width: 6),
                      Text(
                        'Ad banner placeholder (google_mobile_ads)',
                        style: AppTheme.dim12,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, _TopState v) {
    final c = context.read<GameController>();
    final showChat = context.watch<SettingsController>().showChat;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _confirmExit(context, c),
          ),
          const Spacer(),
          if (showChat)
            IconButton(
              icon: const Icon(Icons.chat_bubble, color: Colors.white),
              onPressed: () => showArenaSnack(
                  context, 'Chat arrives with the online update'),
            ),
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            tooltip: 'Takeback',
            onPressed: v.thinking || v.over ? null : c.takeback,
          ),
          IconButton(
            icon: const Icon(Icons.handshake, color: Colors.white),
            tooltip: 'Offer draw',
            onPressed: v.thinking || v.over
                ? null
                : () async {
                    final r = await c.offerDraw();
                    if (r == 'declined' && context.mounted) {
                      showArenaSnack(
                          context, 'Draw declined — keep fighting!');
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.flag, color: Colors.white),
            tooltip: 'Resign',
            onPressed: v.over ? null : () => _confirmResign(context, c),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => showSettingsDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _infoPanel(BuildContext context, _InfoView v) {
    final c = context.read<GameController>();
    final (whiteCaps, blackCaps) = c.capturedPieces();
    final myWhite = c.setup.playerIsWhite;
    final myCaps = myWhite ? whiteCaps : blackCaps;
    final oppCaps = myWhite ? blackCaps : whiteCaps;
    final myDiff = myWhite ? v.diff : -v.diff;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    v.status,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                if (myDiff != 0)
                  Text(
                    '${myDiff > 0 ? '+' : ''}$myDiff',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            _capsRow('You', myCaps),
            const SizedBox(height: 2),
            _capsRow(c.setup.opponentName, oppCaps),
            const SizedBox(height: 6),
            if (v.moves.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _movesText(c.game),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _capsRow(String who, List<int> caps) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            who,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textDim),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 0,
            runSpacing: 0,
            children:
                caps.map((p) => PieceWidget(piece: p, size: 20)).toList(),
          ),
        ),
      ],
    );
  }

  String _movesText(ChessGame g) {
    final sb = StringBuffer();
    for (var i = 0; i < g.sanHistory.length; i += 2) {
      sb.write('${i ~/ 2 + 1}. ${g.sanHistory[i]}');
      if (i + 1 < g.sanHistory.length) {
        sb.write(' ${g.sanHistory[i + 1]}  ');
      } else {
        sb.write('  ');
      }
    }
    return sb.toString();
  }

  Future<void> _confirmResign(
      BuildContext context, GameController c) async {
    final played = c.playerHasMoved;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resign game?'),
        content: Text(played
            ? 'This counts as a loss.'
            : 'No moves played — game will be aborted (not rated).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep playing')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(played ? 'Resign' : 'Abort',
                  style: const TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (yes == true) await c.resign();
  }

  Future<void> _confirmExit(
      BuildContext context, GameController c) async {
    if (c.isGameOver) {
      Navigator.of(context).pop();
      return;
    }
    final played = c.playerHasMoved;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave game?'),
        content: Text(played
            ? 'Leaving counts as a loss.'
            : 'No moves played — game will be aborted (not rated).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(played ? 'Leave' : 'Abort',
                  style: const TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (yes == true) {
      await c.resign();
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
