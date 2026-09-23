/// Friends / Profile / Watch / Highlights tabs.
///
/// Social + spectating features are online-dependent; these screens are
/// polished placeholders that light up once Supabase matchmaking lands.
library;

import 'package:flutter/material.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/local/database.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/repository/arena_repository.dart';
import '../../services/sound_service.dart';
import '../dialogs/app_dialogs.dart';
import '../widgets/app_widgets.dart';
import '../widgets/piece_widget.dart';

// ---------------------------------------------------------------- friends

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Friends', style: AppTheme.title22),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                enabled: false,
                decoration: InputDecoration(
                  hintText: 'Search players… (online soon)',
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: AppColors.textDim),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Column(
                children: [
                  Icon(Icons.group, size: 64, color: AppColors.textDim),
                  SizedBox(height: 12),
                  Text(
                    'No friends yet',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Challenge friends and climb together\nonce online play lands.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textDim),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ArenaButton(
              label: 'Invite friends',
              onPressed: () => showArenaSnack(context,
                  'Invites arrive with the online update '),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- profile

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ArenaRepository>();
    final online = SupabaseService.isReady;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text('Profile', style: AppTheme.title22),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    SoundService.click();
                    showSettingsDialog(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            AvatarWidget(
                name: repo.name, flag: repo.flagEmoji, radius: 40),
            const SizedBox(height: 10),
            Text(repo.name,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            GestureDetector(
              onTap: () {
                SoundService.click();
                repo.cycleFlag();
              },
              child: Text('Tap flag to change: ${repo.flagEmoji}',
                  style: AppTheme.dim13),
            ),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: online
                    ? AppColors.green.withOpacity( 0.25)
                    : AppColors.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                online
                    ? '● Supabase: Online '
                    : '● Supabase: Local only (offline)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: online
                      ? AppColors.greenBright
                      : AppColors.textDim,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _statCard(
                        const Icon(Icons.bar_chart,
                            size: 24, color: AppColors.orange),
                        'Rating',
                        '${repo.rating}')),
                const SizedBox(width: 10),
                Expanded(
                    child:
                        _statCard(SvgPicture.asset('assets/icons/coin.svg', width: 24, height: 24), 'Coins', '${repo.coins}')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _statCard(
                        const Icon(Icons.videogame_asset,
                            size: 24, color: Color(0xFF3FA7FF)),
                        'Games',
                        '${repo.games}')),
                const SizedBox(width: 10),
                Expanded(
                    child: _statCard(
                        const Icon(Icons.local_fire_department,
                            size: 24, color: AppColors.orange),
                        'Streak',
                        '${repo.streak}')),
                const SizedBox(width: 10),
                Expanded(
                    child: _statCard(const Icon(Icons.extension, size: 24, color: Color(0xFF9B7BF5)), 'Puzzles',
                        '${repo.puzzlesSolved}')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child:
                        _statCard(const Icon(Icons.emoji_events, size: 24, color: AppColors.gold), 'Wins', '${repo.wins}')),
                const SizedBox(width: 10),
                Expanded(
                    child: _statCard(
                        const Icon(Icons.handshake,
                            size: 24, color: AppColors.textDim),
                        'Draws',
                        '${repo.draws}')),
                const SizedBox(width: 10),
                Expanded(
                    child: _statCard(
                        const Icon(Icons.sentiment_dissatisfied,
                            size: 24, color: AppColors.red),
                        'Losses',
                        '${repo.losses}')),
              ],
            ),
            const SizedBox(height: 14),
            ArenaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Recent games'),
                  const SizedBox(height: 8),
                  ..._recentGames(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ArenaButton(
              label: 'Create Account',
              subtitle: 'Sync rating & games to the cloud',
              onPressed: () => showArenaSnack(context,
                  'Accounts arrive with the online update '),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(Widget icon, String label, String value) {
    return ArenaCard(
      child: Column(
        children: [
          icon,
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: AppTheme.dim12),
        ],
      ),
    );
  }

  List<Widget> _recentGames() {
    final games = Database.recentGames(limit: 5);
    if (games.isEmpty) {
      return [
        Text('No games yet — go play!', style: AppTheme.dim13),
      ];
    }
    return games.map((g) {
      final tag = g['result'] as String? ?? '?';
      final icon = tag == 'w'
          ? Icons.emoji_events
          : tag == 'd'
              ? Icons.handshake
              : Icons.sentiment_dissatisfied;
      final iconColor = tag == 'w'
          ? AppColors.gold
          : tag == 'd'
              ? AppColors.textDim
              : AppColors.red;
      final delta =
          ((g['ratingAfter'] as int?) ?? 0) - ((g['ratingBefore'] as int?) ?? 0);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'vs ${g['opponent']} (${g['opponentRating']})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${delta >= 0 ? '+' : ''}$delta',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: delta >= 0
                    ? AppColors.greenBright
                    : AppColors.red,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

// ---------------------------------------------------------------- watch

class WatchScreen extends StatelessWidget {
  const WatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ArenaRepository>();
    final games = List.generate(4, (i) {
      final a = repo.randomSimulatedOpponent(1500 + i * 120);
      final b = repo.randomSimulatedOpponent(1500 + i * 120);
      return {'a': a, 'b': b};
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Watch')),
      body: ArenaBackground(
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: games.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final g = games[i];
            final a = g['a']! as Map<String, Object?>;
            final b = g['b']! as Map<String, Object?>;
            return ArenaCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fiber_manual_record, color: AppColors.red, size: 18),
                title: Text(
                  '${a['name']}  vs  ${b['name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                    '${a['rating']} · ${b['rating']} · Blitz',
                    style: AppTheme.dim13),
                trailing: const Icon(Icons.play_circle_fill,
                    color: AppColors.orange, size: 30),
                onTap: () => showArenaSnack(context,
                    'Spectating arrives with the online update '),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- highlights

class HighlightsScreen extends StatelessWidget {
  const HighlightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Highlights')),
      body: ArenaBackground(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: const [
            _HighlightCard(
              thumb: const BlackKnight(size: 30),
              title: 'Brilliant knight sacrifice',
              subtitle: 'GM Carlsen · 2h ago · 12K views',
            ),
            _HighlightCard(
              thumb: const Icon(Icons.workspace_premium, size: 30, color: AppColors.gold),
              title: 'Queen odds comeback',
              subtitle: 'Nightingale · 5h ago · 8K views',
            ),
            _HighlightCard(
              thumb: const Icon(Icons.local_fire_department, size: 30, color: AppColors.orange),
              title: 'Fastest mate of the day — 9 moves!',
              subtitle: 'pawnstormer · 1d ago · 31K views',
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final Widget thumb;
  final String title;
  final String subtitle;
  const _HighlightCard(
      {required this.thumb, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ArenaCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: thumb,
          ),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle, style: AppTheme.dim13),
          trailing: const Icon(Icons.play_circle_fill,
              color: AppColors.orange, size: 30),
          onTap: () => showArenaSnack(
              context, 'Replays arrive with the online update '),
        ),
      ),
    );
  }
}
