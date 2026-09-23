/// All dialogs & bottom sheets: Play CPU, Time Controls, Settings,
/// Promotion picker, Game Over.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repository/arena_repository.dart';
import '../../data/time_controls.dart';
import '../../engine/chess_ai.dart';
import '../../engine/chess_rules.dart';
import '../../game/game_controller.dart';
import '../../services/ads_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/piece_widget.dart';

// ---------------------------------------------------------------------------
// Play CPU
// ---------------------------------------------------------------------------

class PlayCpuChoice {
  final CpuDifficulty difficulty;
  final bool playerIsWhite;
  const PlayCpuChoice(this.difficulty, this.playerIsWhite);
}

Future<PlayCpuChoice?> showPlayCpuDialog(BuildContext context) {
  return showDialog<PlayCpuChoice>(
    context: context,
    builder: (_) => const _PlayCpuDialog(),
  );
}

class _PlayCpuDialog extends StatefulWidget {
  const _PlayCpuDialog();

  @override
  State<_PlayCpuDialog> createState() => _PlayCpuDialogState();
}

class _PlayCpuDialogState extends State<_PlayCpuDialog> {
  int _diff = 0; // 0 easy, 1 medium, 2 hard
  int _color = 0; // 0 white, 1 black

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Center(
        child: Text('Play CPU', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Difficulty'),
          _radio(0, _diff, 'Easy', '~600 ELO', (v) => setState(() => _diff = v)),
          _radio(1, _diff, 'Medium', '~1100 ELO',
              (v) => setState(() => _diff = v)),
          _radio(2, _diff, 'Hard', '~1600 ELO',
              (v) => setState(() => _diff = v)),
          const SizedBox(height: 12),
          const SectionLabel('Color'),
          _radio(0, _color, 'As white', null,
              (v) => setState(() => _color = v)),
          _radio(1, _color, 'As black', null,
              (v) => setState(() => _color = v)),
          const SizedBox(height: 16),
          ArenaButton(
            label: 'Go!',
            onPressed: () {
              final d = [_diff == 0
                  ? CpuDifficulty.easy
                  : _diff == 1
                      ? CpuDifficulty.medium
                      : CpuDifficulty.hard][0];
              Navigator.of(context)
                  .pop(PlayCpuChoice(d, _color == 0));
            },
          ),
        ],
      ),
    );
  }

  Widget _radio(
      int value, int group, String label, String? sub, ValueChanged<int> onTap) {
    final sel = value == group;
    return InkWell(
      onTap: () => onTap(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: sel ? AppColors.orange : AppColors.textDim,
                  width: 2.5,
                ),
              ),
              child: sel
                  ? const Center(
                      child: Icon(Icons.circle,
                          size: 12, color: AppColors.orange),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (sub != null) ...[
              const SizedBox(width: 8),
              Text(sub, style: AppTheme.dim12),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time controls sheet
// ---------------------------------------------------------------------------

Future<List<String>?> showTimeControlsSheet(
  BuildContext context,
  List<String> selected,
) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TimeControlsSheet(initial: selected),
  );
}

class _TimeControlsSheet extends StatefulWidget {
  final List<String> initial;
  const _TimeControlsSheet({required this.initial});

  @override
  State<_TimeControlsSheet> createState() => _TimeControlsSheetState();
}

class _TimeControlsSheetState extends State<_TimeControlsSheet> {
  late Set<String> _sel;

  @override
  void initState() {
    super.initState();
    _sel = widget.initial.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Time controls', style: AppTheme.title22),
            Text(
              'Pick as many as you like — more modes, faster match',
              style: AppTheme.dim13,
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: kTimeControls.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: AppColors.divider, height: 1),
                itemBuilder: (_, i) {
                  final tc = kTimeControls[i];
                  final sel = _sel.contains(tc.id);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(tc.icon, style: const TextStyle(fontSize: 30)),
                    title: Text(tc.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    subtitle:
                        Text(tc.subtitle, style: AppTheme.dim13),
                    trailing: GestureDetector(
                      onTap: () => setState(() {
                        sel ? _sel.remove(tc.id) : _sel.add(tc.id);
                      }),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sel ? AppColors.orange : Colors.transparent,
                          border: Border.all(
                            color: sel
                                ? AppColors.orange
                                : AppColors.textDim,
                            width: 2,
                          ),
                        ),
                        child: sel
                            ? const Icon(Icons.check,
                                size: 18, color: Colors.white)
                            : null,
                      ),
                    ),
                    onTap: () => setState(() {
                      sel ? _sel.remove(tc.id) : _sel.add(tc.id);
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '● ${_sel.length} mode${_sel.length == 1 ? '' : 's'} selected',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 130,
                  child: ArenaButton(
                    label: 'DONE',
                    onPressed: () =>
                        Navigator.of(context).pop(_sel.toList()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

Future<void> showSettingsDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _SettingsDialog(),
  );
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    return AlertDialog(
      title: const Center(
        child: Text('Settings', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toggle(context, s, '🔊', 'Sound', s.sound, 'sound'),
            _toggle(context, s, '▦', 'Show last move', s.showLastMove,
                'showLastMove'),
            _toggle(context, s, '❏', 'Piece animation', s.pieceAnimation,
                'pieceAnimation'),
            _toggle(context, s, '❓', 'Show move help', s.showMoveHelp,
                'showMoveHelp'),
            _toggle(context, s, '✓', 'Confirm my moves', s.confirmMoves,
                'confirmMoves'),
            _toggle(context, s, '♛', 'Auto promote queen', s.autoQueen,
                'autoQueen'),
            _toggle(context, s, '💬', 'Show chat', s.showChat, 'showChat'),
          ],
        ),
      ),
    );
  }

  Widget _toggle(BuildContext context, SettingsController s, String icon,
      String label, bool value, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Switch(
            value: value,
            activeColor: AppColors.orange,
            onChanged: (v) => s.set(key, v),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Promotion
// ---------------------------------------------------------------------------

Future<int?> showPromotionDialog(BuildContext context, bool white) {
  return showDialog<int>(
    context: context,
    barrierDismissible: true,
    builder: (_) => AlertDialog(
      title: const Center(child: Text('Promote to')),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [queen, rook, bishop, knight].map((t) {
          final piece = white ? t : -t;
          return InkWell(
            onTap: () => Navigator.of(context).pop(t),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: PieceWidget(piece: piece, size: 44),
            ),
          );
        }).toList(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Game over
// ---------------------------------------------------------------------------

Future<String?> showGameOverDialog(
  BuildContext context,
  GameOverInfo info,
  GameSetup setup,
) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _GameOverDialog(info: info, setup: setup),
  );
}

class _GameOverDialog extends StatelessWidget {
  final GameOverInfo info;
  final GameSetup setup;
  const _GameOverDialog({required this.info, required this.setup});

  @override
  Widget build(BuildContext context) {
    final delta = info.ratingDelta;
    final deltaText =
        '${delta >= 0 ? '+' : ''}$delta → ${info.newRating}';
    final deltaColor =
        delta > 0 ? AppColors.greenBright : delta < 0 ? AppColors.red : AppColors.textDim;
    String emoji;
    if (info.playerScore == 1) {
      emoji = '🏆';
    } else if (info.playerScore == 0.5) {
      emoji = '🤝';
    } else {
      emoji = '😞';
    }
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 8),
          Text(info.title,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(info.reason, style: AppTheme.dim13),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📊 ', style: TextStyle(fontSize: 16)),
              Text(
                deltaText,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: deltaColor),
              ),
              const SizedBox(width: 14),
              const Text('🪙', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                '+${info.coinsEarned}',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold),
              ),
            ],
          ),
          if (!AdsService.isConfigured) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🎬 Ad placeholder — fullscreen ad shows here in the online build',
                textAlign: TextAlign.center,
                style: AppTheme.dim12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ArenaButton(
            label: 'Rematch',
            onPressed: () => Navigator.of(context).pop('rematch'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop('new'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.textDim),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('New game',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop('home'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.textDim),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Home',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
