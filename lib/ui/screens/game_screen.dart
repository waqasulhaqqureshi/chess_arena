/// Game screen — wood theme, player bars, board, captures, move list.
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
    final c = context.watch<GameController>();
    final setup = c.setup;
    final oppClock = setup.playerIsWhite
        ? formatClock(c.blackMs)
        : formatClock(c.whiteMs);
    final myClock = setup.playerIsWhite
        ? formatClock(c.whiteMs)
        : formatClock(c.blackMs);
    final oppActive = !c.isGameOver &&
        c.game.whiteToMove == !setup.playerIsWhite;
    final myActive =
        !c.isGameOver && c.game.whiteToMove == setup.playerIsWhite;

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
              _topBar(context, c),
              PlayerBar(
                name: setup.opponentName,
                flag: setup.opponentFlag,
                rating: setup.opponentRating,
                clockText: oppClock,
                active: oppActive,
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: ChessBoardWidget(
                  game: c.game,
                  orientationWhite: setup.playerIsWhite,
                  onTap: c.tapSquare,
                  selected: c.selected,
                  selectedMoves: c.selectedMoves,
                  lastMove: c.lastMove,
                  checkSquare: c.kingInCheckSquare(),
                  pendingFrom: c.pendingFrom,
                  pendingTo: c.pendingTo,
                  showLastMove:
                      context.watch<SettingsController>().showLastMove,
                  animate: context
                      .watch<SettingsController>()
                      .pieceAnimation,
                  animKey: c.game.moveHistory.length,
                ),
              ),
              PlayerBar(
                name:
                    '${context.watch<ArenaRepository>().name} (You)',
                flag: context.watch<ArenaRepository>().flagEmoji,
                rating: context.watch<ArenaRepository>().rating,
                clockText: myClock,
                active: myActive,
              ),
              Expanded(child: _infoPanel(context, c)),
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
                  child: Text(
                    '🎬 Ad banner placeholder (google_mobile_ads)',
                    textAlign: TextAlign.center,
                    style: AppTheme.dim12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, GameController c) {
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
          if (context.watch<SettingsController>().showChat)
            IconButton(
              icon: const Icon(Icons.chat_bubble, color: Colors.white),
              onPressed: () => showArenaSnack(
                  context, 'Chat arrives with the online update 💬'),
            ),
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            tooltip: 'Takeback',
            onPressed: c.cpuThinking || c.isGameOver ? null : c.takeback,
          ),
          IconButton(
            icon: const Icon(Icons.flag, color: Colors.white),
            tooltip: 'Resign',
            onPressed:
                c.isGameOver ? null : () => _confirmResign(context, c),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => showSettingsDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _infoPanel(BuildContext context, GameController c) {
    final (whiteCaps, blackCaps) = c.capturedPieces();
    final diff = c.materialDiff();
    final repo = context.watch<ArenaRepository>();
    final myWhite = c.setup.playerIsWhite;
    final myCaps = myWhite ? whiteCaps : blackCaps;
    final oppCaps = myWhite ? blackCaps : whiteCaps;
    final myDiff = myWhite ? diff : -diff;

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
                    c.statusText(),
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
            _capsRow('You', myCaps, repo.flagEmoji),
            const SizedBox(height: 2),
            _capsRow(c.setup.opponentName, oppCaps,
                c.setup.isCpuAvatar ? 'cpu' : c.setup.opponentFlag),
            const SizedBox(height: 6),
            if (c.game.sanHistory.isNotEmpty)
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

  Widget _capsRow(String who, List<int> caps, String flag) {
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
            children: caps
                .map((p) => PieceWidget(piece: p, size: 20))
                .toList(),
          ),
        ),
      ],
    );
  }

  String _movesText(ChessGame g) {
    final sb = StringBuffer();
    for (var i = 0; i < g.sanHistory.length; i += 2) {
      sb.write('${i ~/ 2 + 1}. ${g.sanHistory[i]}');
      if (i + 1 < g.sanHistory.length) sb.write(' ${g.sanHistory[i + 1]}  ');
      if (i + 1 >= g.sanHistory.length) sb.write('  ');
    }
    return sb.toString();
  }

  Future<void> _confirmResign(
      BuildContext context, GameController c) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resign game?'),
        content: const Text('This counts as a loss.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep playing')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Resign',
                  style: TextStyle(color: AppColors.red))),
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
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave game?'),
        content: const Text('Leaving counts as a loss.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave',
                  style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (yes == true) {
      await c.resign();
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
