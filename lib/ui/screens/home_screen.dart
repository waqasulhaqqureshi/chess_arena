/// Home "Play" tab — mirrors goal.mp4: header, TODAY card,
/// Play Online card, Play CPU / Puzzles / Watch / Highlights grid.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/local/database.dart';
import '../../data/repository/arena_repository.dart';
import '../../data/time_controls.dart';
import '../../engine/chess_ai.dart';
import '../../game/game_controller.dart';
import '../../services/sound_service.dart';
import '../dialogs/app_dialogs.dart';
import '../widgets/app_widgets.dart';
import '../widgets/piece_widget.dart';
import 'game_screen.dart';
import 'puzzle_screens.dart';
import 'secondary_screens.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int tab) onTab;
  const HomeScreen({super.key, required this.onTab});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ArenaRepository>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _header(context, repo),
            const SizedBox(height: 12),
            _todayCard(context, repo),
            const SizedBox(height: 12),
            _playOnlineCard(context, repo),
            const SizedBox(height: 12),
            _grid(context, repo),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- header

  Widget _header(BuildContext context, ArenaRepository repo) {
    return Row(
      children: [
        AvatarWidget(name: repo.name, flag: repo.flagEmoji, radius: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                repo.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              GestureDetector(
                onTap: () => showArenaSnack(
                    context, 'Accounts arrive with the online update ☁️'),
                child: const Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: AppColors.greenBright),
                    SizedBox(width: 4),
                    Text('Create Account', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        CoinChip(coins: repo.coins),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            onPressed: () {
              SoundService.click();
              onTab(3); // profile stats
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------- today card

  Widget _todayCard(BuildContext context, ArenaRepository repo) {
    return ArenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Today'),
          const SizedBox(height: 8),
          _todayRow(
            icon: '🥇',
            title: 'Daily game',
            subtitle:
                '${repo.streak} day streak · longer streaks pay more',
            trailing: repo.dailyGameDone
                ? _doneCheck()
                : _smallButton(context, 'Play', () {
                    final d = CpuDifficulty.forElo(repo.rating);
                    _startGame(
                      context,
                      repo,
                      GameSetup(
                        rated: true,
                        opponentName: 'Daily Challenge',
                        opponentFlag: 'cpu',
                        opponentRating: d.targetElo,
                        difficulty: d,
                        playerIsWhite: true,
                        timeControl: timeControlById(
                            repo.timeControls.first),
                      ),
                    );
                  }),
          ),
          const Divider(color: AppColors.divider),
          _todayRow(
            icon: '🧩',
            title: 'Daily puzzle 🪙10',
            subtitle: repo.dailyPuzzleDone
                ? 'Come back tomorrow for another'
                : 'Solve one puzzle today',
            trailing: repo.dailyPuzzleDone
                ? _doneCheck()
                : _smallButton(context, 'Solve', () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PuzzleScreen(daily: true),
                    ));
                  }),
          ),
          const Divider(color: AppColors.divider),
          _todayRow(
            icon: '📜',
            title: 'Next Mission 🪙25',
            subtitle: repo.missionClaimed
                ? 'Play a game online (${repo.missionProgress}/1)'
                : 'Play a game online (${repo.missionProgress}/1) — ready!',
            trailing: (!repo.missionClaimed && repo.missionProgress >= 1)
                ? _smallButton(context, 'Claim ›', () async {
                    final ok = await repo.claimMission();
                    if (context.mounted) {
                      showArenaSnack(context,
                          ok ? '+25 coins! 🎉' : 'Play a rated game first');
                    }
                  })
                : _smallButton(context, 'Claim ›', null),
          ),
        ],
      ),
    );
  }

  Widget _todayRow({
    required String icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 30)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textDim)),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _doneCheck() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppColors.green,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 18),
    );
  }

  Widget _smallButton(
      BuildContext context, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              SoundService.click();
              onTap();
            },
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              AppColors.orangeLight,
              AppColors.orangeDark
            ]),
            borderRadius: BorderRadius.circular(20),
            border: const Border(
                bottom:
                    BorderSide(color: AppColors.orangeDeep, width: 3)),
          ),
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------ play online card

  Widget _playOnlineCard(BuildContext context, ArenaRepository repo) {
    final lastDelta = _lastRatingDelta();
    return ArenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Play Online', style: AppTheme.title18),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '● ${repo.gamesLast24h} games in the last 24h',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Your rating'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${repo.rating}',
                          style: const TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w800),
                        ),
                        if (lastDelta != null) ...[
                          const SizedBox(width: 6),
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${lastDelta >= 0 ? '+' : ''}$lastDelta',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: lastDelta >= 0
                                    ? AppColors.greenBright
                                    : AppColors.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    _formDots(repo),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SectionLabel('Time controls'),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _editTimeControls(context, repo),
                          child: const Text(
                            'Edit ›',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _timeControlIcons(repo),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ArenaButton(
            label: 'Find opponent',
            subtitle: 'Random Opponent',
            leading: const Text('🐺', style: TextStyle(fontSize: 34)),
            onPressed: () => _findOpponent(context, repo),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '👥 Matched with players near your rating',
              style: TextStyle(fontSize: 12, color: AppColors.textDim),
            ),
          ),
        ],
      ),
    );
  }

  int? _lastRatingDelta() {
    final games = Database.recentGames(limit: 1);
    if (games.isEmpty) return null;
    final g = games.first;
    final a = g['ratingAfter'];
    final b = g['ratingBefore'];
    if (a is int && b is int) return a - b;
    return null;
  }

  Widget _formDots(ArenaRepository repo) {
    if (repo.form.isEmpty) {
      return const Text('No games yet', style: TextStyle(fontSize: 11));
    }
    return Row(
      children: repo.form.map((r) {
        final c = r == 'w'
            ? AppColors.greenBright
            : r == 'd'
                ? Colors.grey
                : AppColors.red;
        return Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        );
      }).toList(),
    );
  }

  Widget _timeControlIcons(ArenaRepository repo) {
    final icons = repo.timeControls
        .map((id) => timeControlById(id).icon)
        .toList();
    final shown = icons.take(3).toList();
    final extra = icons.length - shown.length;
    return Wrap(
      spacing: 4,
      children: [
        ...shown.map((e) => Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(e, style: const TextStyle(fontSize: 18)),
            )),
        if (extra > 0)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('+$extra',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }

  Future<void> _editTimeControls(
      BuildContext context, ArenaRepository repo) async {
    SoundService.click();
    final sel = await showTimeControlsSheet(context, repo.timeControls);
    if (sel != null && sel.isNotEmpty) {
      await repo.setTimeControls(sel);
    }
  }

  // --------------------------------------------------------------- grid

  Widget _grid(BuildContext context, ArenaRepository repo) {
    return ArenaCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _gridCell(context, '🎯', 'Play CPU',
                      onTap: () => _playCpu(context, repo))),
              Container(width: 1, height: 84, color: AppColors.divider),
              Expanded(
                  child: _gridCell(context, '🧩', 'Puzzles',
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const PuzzleListScreen())))),
            ],
          ),
          Container(height: 1, color: AppColors.divider),
          Row(
            children: [
              Expanded(
                  child: _gridCell(context, '👁️', 'Watch',
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const WatchScreen())))),
              Container(width: 1, height: 84, color: AppColors.divider),
              Expanded(
                  child: _gridCell(context, '🎬', 'Highlights',
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const HighlightsScreen())))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gridCell(BuildContext context, String icon, String label,
      {required VoidCallback onTap}) {
    return InkWell(
      onTap: () {
        SoundService.click();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- actions

  Future<void> _playCpu(
      BuildContext context, ArenaRepository repo) async {
    final choice = await showPlayCpuDialog(context);
    if (choice == null || !context.mounted) return;
    _startGame(
      context,
      repo,
      GameSetup(
        rated: false,
        opponentName: 'CPU (${choice.difficulty.name})',
        opponentFlag: 'cpu',
        opponentRating: choice.difficulty.targetElo,
        difficulty: choice.difficulty,
        playerIsWhite: choice.playerIsWhite,
        timeControl: timeControlById(repo.timeControls.first),
      ),
    );
  }

  Future<void> _findOpponent(
      BuildContext context, ArenaRepository repo) async {
    SoundService.click();
    // Simulated matchmaking (real lobby arrives with online update).
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.orange),
            const SizedBox(height: 14),
            Text('Finding opponent near ${repo.rating}…',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Simulated opponent · real matchmaking coming soon',
              style: AppTheme.dim12,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!context.mounted) return;
    Navigator.of(context).pop(); // close matchmaking
    final opp = repo.randomSimulatedOpponent(repo.rating);
    final elo = opp['rating']! as int;
    final asWhite = DateTime.now().millisecond % 2 == 0;
    _startGame(
      context,
      repo,
      GameSetup(
        rated: true,
        opponentName: opp['name']! as String,
        opponentFlag: opp['flag']! as String,
        opponentRating: elo,
        difficulty: CpuDifficulty.forElo(elo),
        playerIsWhite: asWhite,
        timeControl: timeControlById(repo.timeControls.first),
      ),
    );
  }

  void _startGame(
      BuildContext context, ArenaRepository repo, GameSetup setup) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(setup: setup)),
    );
  }
}
