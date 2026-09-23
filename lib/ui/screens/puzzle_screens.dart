/// Puzzle list + puzzle board (mirrors the video's Puzzle #5 screen).
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/local/database.dart';
import '../../data/repository/arena_repository.dart';
import '../../engine/puzzles.dart';
import '../../game/puzzle_controller.dart';
import '../widgets/app_widgets.dart';
import '../widgets/chess_board_widget.dart';

// ---------------------------------------------------------------- list

class PuzzleListScreen extends StatelessWidget {
  const PuzzleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ArenaRepository>();
    final solved = Database.solvedPuzzles().toSet();
    final daily = dailyPuzzle(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Puzzles')),
      body: ArenaBackground(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ArenaCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month,
                    size: 34, color: AppColors.orange),
                title: Text('Daily Puzzle — #${daily.id}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                    repo.dailyPuzzleDone
                        ? 'Completed! Come back tomorrow'
                        : 'Solve for +10 coins',
                    style: AppTheme.dim13),
                trailing: repo.dailyPuzzleDone
                    ? const Icon(Icons.check_circle,
                        color: AppColors.green, size: 30)
                    : const Icon(Icons.arrow_forward_ios,
                        color: AppColors.orange),
                onTap: repo.dailyPuzzleDone
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            const PuzzleScreen(daily: true))),
              ),
            ),
            const SizedBox(height: 10),
            ...kPuzzles.map((p) {
              final done = solved.contains(p.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ArenaCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        children: [
                          MiniBoard(fen: p.fen, size: 48),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: done
                                    ? AppColors.green
                                    : Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: done
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 10)
                                  : Text(
                                      '#${p.id}',
                                      style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: Text(p.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800)),
                    subtitle: Text(
                        p.whiteToMove
                            ? 'White to move · Mate in 1'
                            : 'Black to move · Mate in 1',
                        style: AppTheme.dim13),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: AppColors.textDim),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                PuzzleScreen(puzzle: p))),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- board

class PuzzleScreen extends StatelessWidget {
  final Puzzle? puzzle;
  final bool daily;
  const PuzzleScreen({super.key, this.puzzle, this.daily = false});

  @override
  Widget build(BuildContext context) {
    final initial =
        puzzle ?? (daily ? dailyPuzzle(DateTime.now()) : kPuzzles.first);
    return ChangeNotifierProvider(
      create: (ctx) => PuzzleController(
        repo: ctx.read<ArenaRepository>(),
        settings: ctx.read<SettingsController>(),
        initial: initial,
        isDaily: daily && puzzle == null,
      ),
      child: const _PuzzleBody(),
    );
  }
}

class _PuzzleBody extends StatelessWidget {
  const _PuzzleBody();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PuzzleController>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Puzzle #${c.puzzle.id}'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CoinChip(coins: context.watch<ArenaRepository>().coins),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0E04), Color(0xFF4A2A10)],
          ),
        ),
        child: Column(
          children: [
            _banner(c),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: ChessBoardWidget(
                game: c.game,
                orientationWhite: c.orientationWhite,
                onTap: c.tapSquare,
                selected: c.selected,
                selectedMoves: c.selectedMoves,
                lastMove: c.lastMove,
                hintFrom: c.hintFrom,
                hintTo: c.hintTo,
                showLastMove:
                    context.watch<SettingsController>().showLastMove,
                animate: context
                    .watch<SettingsController>()
                    .pieceAnimation,
                animKey: c.game.moveHistory.length,
                theme: BoardTheme.all[context
                    .watch<SettingsController>()
                    .boardTheme
                    .clamp(0, BoardTheme.all.length - 1)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                c.solved ? 'Solved!' : c.puzzle.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            if (!c.solved)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                        child: _coinButton(
                            context, Icons.help, 'Solution', 20, () async {
                      final ok = await context
                          .read<PuzzleController>()
                          .showSolution();
                      if (!ok && context.mounted) {
                        showArenaSnack(context,
                            'Not enough coins (need 20) ');
                      }
                    })),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _coinButton(
                            context, Icons.lightbulb, 'Hint', 10, () async {
                      final ok = await context
                          .read<PuzzleController>()
                          .showHint();
                      if (!ok && context.mounted) {
                        showArenaSnack(context,
                            'Not enough coins (need 10) ');
                      }
                    })),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ArenaButton(
                  label: 'Next puzzle ›',
                  onPressed: () {
                    final ctrl = context.read<PuzzleController>();
                    final next = kPuzzles[
                        (ctrl.puzzle.id) % kPuzzles.length];
                    ctrl.loadPuzzle(next);
                  },
                ),
              ),
            const SizedBox(height: 8),
            Text(
              c.orientationWhite
                  ? 'White to move · Mate in 1'
                  : 'Black to move · Mate in 1',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textDim),
            ),
            const SizedBox(height: 8),
            _navRow(context, c),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _navRow(BuildContext context, PuzzleController c) {
    final idx = kPuzzles.indexWhere((p) => p.id == c.puzzle.id);
    final safe = idx < 0 ? 0 : idx;
    final prev = kPuzzles[(safe - 1 + kPuzzles.length) % kPuzzles.length];
    final next = kPuzzles[(safe + 1) % kPuzzles.length];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _navBtn(Icons.chevron_left,
              () => context.read<PuzzleController>().loadPuzzle(prev)),
          Expanded(
            child: Text(
              '#${c.puzzle.id} of ${kPuzzles.length} · tries: ${c.attempts}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textDim,
                  fontWeight: FontWeight.w700),
            ),
          ),
          _navBtn(Icons.chevron_right,
              () => context.read<PuzzleController>().loadPuzzle(next)),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _banner(PuzzleController c) {
    if (c.solved) {
      return Container(
        width: double.infinity,
        color: const Color(0xFF1E4D2B),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle,
                color: AppColors.greenBright, size: 20),
            SizedBox(width: 6),
            Text('Good job!',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      );
    }
    if (c.wrongFlash) {
      return Container(
        width: double.infinity,
        color: const Color(0xFF5A1F1F),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, color: AppColors.red, size: 20),
            SizedBox(width: 6),
            Text('Wrong move!',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      );
    }
    return const SizedBox(height: 8);
  }

  Widget _coinButton(BuildContext context, IconData icon, String label,
      int cost, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: AppColors.orangeLight),
                const SizedBox(width: 6),
                SvgPicture.asset('assets/icons/coin.svg',
                    width: 14,
                    height: 14),
                const SizedBox(width: 3),
                Text('$cost',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold)),
              ],
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
