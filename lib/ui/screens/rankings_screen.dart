/// Rankings tab — global leaderboard (remote when online,
/// seeded offline board otherwise).
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/repository/arena_repository.dart';
import 'package:provider/provider.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  bool _world = true;
  Future<List<RankingEntry>>? _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ArenaRepository>().rankings();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ArenaRepository>();
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text('Rankings', style: AppTheme.title22),
                const Spacer(),
                _filterChip('🌍', _world, () => setState(() => _world = true)),
                const SizedBox(width: 8),
                _filterChip(repo.flagEmoji, !_world,
                    () => setState(() => _world = false)),
              ],
            ),
          ),
          if (!SupabaseService.isReady)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Offline board · live global rankings sync with Supabase ☁️',
                style: AppTheme.dim12,
              ),
            ),
          Expanded(
            child: FutureBuilder<List<RankingEntry>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.orange));
                }
                var rows = snap.data!;
                if (!_world) {
                  final mine = rows
                      .where((r) => r.flag == repo.flagEmoji)
                      .toList();
                  rows = mine.isEmpty ? rows : mine;
                }
                return RefreshIndicator(
                  color: AppColors.orange,
                  onRefresh: () async {
                    final f =
                        context.read<ArenaRepository>().rankings();
                    setState(() => _future = f);
                    await f;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: AppColors.divider, height: 1),
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      return Container(
                        color: r.isPlayer
                            ? AppColors.orange.withOpacity( 0.18)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 44,
                              child: Text(
                                '#${i + 1}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDim),
                              ),
                            ),
                            Text(r.flag,
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: r.isPlayer
                                      ? AppColors.orangeLight
                                      : Colors.white,
                                ),
                              ),
                            ),
                            const Text('📊',
                                style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              '${r.rating}',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: sel
              ? const LinearGradient(colors: [
                  AppColors.orangeLight,
                  AppColors.orangeDark
                ])
              : null,
          color: sel ? null : AppColors.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
