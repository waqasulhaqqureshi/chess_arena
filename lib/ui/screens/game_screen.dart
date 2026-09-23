/// Game screen — wood theme, player bars, board, captures, move list.
///
/// Performance: the 100 ms clock ticker only rebuilds the tiny clock
/// leaves — board / move-list subtrees are [Selector]-gated on immutable
/// snapshots so they rebuild solely on moves.
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

/// Variant that rebuilds a persisted mid-game snapshot.
class ResumedGameScreen extends StatelessWidget {
  final Map<String, Object?> snapshot;
  const ResumedGameScreen({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => GameController.resume(
        repo: ctx.read<ArenaRepository>(),
        settings: ctx.read<SettingsController>(),
        snapshot: snapshot,
      ),
      child: const _GameBody(),
    );
  }
}

// ---------------------------------------------------------------- snapshots

class _TopState {
  final bool thinking;
  final bool over;
  final bool canTakeback;
  final int unread;
  final bool drawOffer;
  const _TopState(
      this.thinking, this.over, this.canTakeback, this.unread, this.drawOffer);

  @override
  bool operator ==(Object o) =>
      o is _TopState &&
      thinking == o.thinking &&
      over == o.over &&
      canTakeback == o.canTakeback &&
      unread == o.unread &&
      drawOffer == o.drawOffer;
  @override
  int get hashCode => Object.hash(thinking, over, canTakeback, unread);
}

class _ClockView {
  final double ms;
  final bool active;
  final bool firstMove;
  const _ClockView(this.ms, this.active, this.firstMove);

  @override
  bool operator ==(Object o) =>
      o is _ClockView &&
      ms == o.ms &&
      active == o.active &&
      firstMove == o.firstMove;
  @override
  int get hashCode => Object.hash(ms, active, firstMove);
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
  final int themeIdx;
  final bool pieceImages;
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
    required this.themeIdx,
    required this.pieceImages,
  });

  factory _BoardView.from(GameController c, bool showLast, bool animate,
      int themeIdx, bool pieceImages) {
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
      themeIdx: themeIdx,
      pieceImages: pieceImages,
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
      animate == o.animate &&
      themeIdx == o.themeIdx &&
      pieceImages == o.pieceImages;

  @override
  int get hashCode => Object.hash(len, sel, targets, lastFrom, lastTo, check,
      pendF, pendT, showLast, themeIdx, pieceImages);
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
  bool _drawOpen = false;

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
    if (c.cpuDrawOffer && !_drawOpen) {
      _drawOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final accept = await showVideoConfirm(
          context,
          title: 'Draw offered',
          subtitle: '${c.setup.opponentName} offers a draw',
          actionLabel: 'Accept',
          cancelLabel: 'Decline',
        );
        _drawOpen = false;
        await c.answerCpuDraw(accept == true);
      });
    }
    if (c.gameOverInfo != null && !_overOpen) {
      _overOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || c.gameOverInfo == null) return;
        final action =
            await showGameOverDialog(context, c.gameOverInfo!, c.setup);
        if (!mounted) return;
        if (action == 'rematch') {
          final setup = c.setup;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GameScreen(
                setup: GameSetup(
                  rated: setup.rated,
                  timed: setup.timed,
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
          child: Stack(
            children: [
              Column(
                children: [
                  Selector<GameController, _TopState>(
                    selector: (_, c) => _TopState(c.cpuThinking, c.isGameOver,
                        c.canTakeback, c.unread, c.cpuDrawOffer),
                    builder: (_, v, __) => _topBar(context, v),
                  ),
                  // Opponent bar (rebuilds on clock ticks only).
                  Selector<GameController, _ClockView>(
                    selector: (_, c) => _ClockView(
                      setup.playerIsWhite ? c.blackMs : c.whiteMs,
                      !c.isGameOver &&
                          c.game.whiteToMove == !setup.playerIsWhite,
                      !c.cpuHasMoved,
                    ),
                    builder: (_, clock, __) => PlayerBar(
                      name: setup.opponentName,
                      flag: setup.opponentFlag,
                      rating: setup.opponentRating,
                      clockText: formatClock(clock.ms),
                      active: clock.active,
                      showClock: setup.timed,
                      firstMove: clock.firstMove,
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: RepaintBoundary(
                      child: Selector2<GameController, SettingsController,
                          _BoardView>(
                        selector: (_, c, s) => _BoardView.from(c,
                            s.showLastMove, s.pieceAnimation, s.boardTheme,
                            s.pieceImages),
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
                            theme: BoardTheme.all[
                                v.themeIdx.clamp(0, BoardTheme.all.length - 1)],
                            pieceImages: v.pieceImages,
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
                      !c.playerHasMoved,
                    ),
                    builder: (_, clock, __) {
                      final repo = context.watch<ArenaRepository>();
                      return PlayerBar(
                        name: '${repo.name} (You)',
                        flag: repo.flagEmoji,
                        rating: repo.rating,
                        clockText: formatClock(clock.ms),
                        active: clock.active,
                        showClock: setup.timed,
                        firstMove: clock.firstMove,
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
              // No-show abort countdown overlay (video parity).
              Selector<GameController, int?>(
                selector: (_, c) => c.idleAbortRemaining,
                builder: (_, remain, __) {
                  if (remain == null) return const SizedBox.shrink();
                  return Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.6),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF39607E),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Waiting for opponent',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 12),
                              const CircularProgressIndicator(
                                  color: Colors.white),
                              const SizedBox(height: 12),
                              Text(
                                'Aborting game in $remain..',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble, color: Colors.white),
                  onPressed: () => showChatSheet(context),
                ),
                if (v.unread > 0)
                  Positioned(
                    right: 6,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text('${v.unread}',
                          style: const TextStyle(fontSize: 9)),
                    ),
                  ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            tooltip: 'Takeback',
            onPressed: v.canTakeback ? c.takeback : null,
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            tooltip: 'Game menu',
            onPressed: v.over ? null : () => _openMenu(context, c),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => showSettingsDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openMenu(BuildContext context, GameController c) async {
    final muted = !context.read<SettingsController>().sound;
    final action = await showGameMenuSheet(context, muted: muted);
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'mute':
        final s = context.read<SettingsController>();
        await s.set('sound', !s.sound);
      case 'draw':
        final r = await c.offerDraw();
        if (r == 'declined' && context.mounted) {
          showArenaSnack(context, 'Draw declined — keep fighting!');
        }
      case 'friend':
        showArenaSnack(context, 'Friend request sent ✔');
      case 'resign':
        await _confirmResign(context, c);
    }
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
    final played = c.playerHasMoved || c.cpuHasMoved;
    final yes = await showVideoConfirm(
      context,
      title: 'Resign Game',
      subtitle: played
          ? 'If you quit, it will count as a loss'
          : 'No moves played — game will be aborted (not rated)',
      actionLabel: played ? 'Resign' : 'Abort',
      cancelLabel: 'Cancel',
    );
    if (yes == true) await c.resign();
  }

  Future<void> _confirmExit(
      BuildContext context, GameController c) async {
    if (c.isGameOver) {
      Navigator.of(context).pop();
      return;
    }
    final played = c.playerHasMoved || c.cpuHasMoved;
    final yes = await showVideoConfirm(
      context,
      title: 'Leave game?',
      subtitle: played
          ? 'Leaving now counts as a loss'
          : 'No moves played — game will be aborted (not rated)',
      actionLabel: played ? 'Leave' : 'Abort',
      cancelLabel: 'Stay',
    );
    if (yes == true) {
      await c.resign();
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
