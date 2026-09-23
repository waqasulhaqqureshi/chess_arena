/// All dialogs & bottom sheets: Play CPU, Time Controls, Settings,
/// Promotion picker, Game Over, in-game menu, chat, customize, rules.
library;

import 'package:country_pickers/country.dart';
import 'package:country_pickers/country_pickers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
// Video-style confirm (U3): translucent card, bold title, subtitle,
// dim Cancel + orange action side by side.
// ---------------------------------------------------------------------------

Future<bool> showVideoConfirm(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String actionLabel,
  String cancelLabel = 'Cancel',
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (_) => Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF39607E).withOpacity(0.92),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 18,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 2)),
                    ]),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cancelLabel,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            AppColors.orangeLight,
                            AppColors.orangeDark
                          ]),
                          borderRadius: BorderRadius.circular(10),
                          border: const Border(
                              bottom: BorderSide(
                                  color: AppColors.orangeDeep, width: 3)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          actionLabel,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// In-game hamburger menu (U2): Mute / Offer Draw / Friend request / Resign.
// ---------------------------------------------------------------------------

Future<String?> showGameMenuSheet(
  BuildContext context, {
  required bool muted,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),
            _menuRow(Icons.do_not_disturb_on, AppColors.red,
                muted ? 'Unmute opponent' : 'Mute opponent', 'mute'),
            const Divider(color: AppColors.divider, height: 1),
            _menuRow(Icons.handshake, AppColors.orange, 'Offer Draw', 'draw'),
            const Divider(color: AppColors.divider, height: 1),
            _menuRow(Icons.person_add_alt_1, AppColors.greenBright,
                'Send friend request', 'friend'),
            const Divider(color: AppColors.divider, height: 1),
            _menuRow(Icons.flag, Colors.white, 'Resign', 'resign'),
          ],
        ),
      ),
    ),
  );
}

Widget _menuRow(IconData icon, Color color, String label, String value) {
  return Builder(builder: (context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 14),
            Text(label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  });
}

// ---------------------------------------------------------------------------
// Chat sheet (U9): bubbles + quick replies, unread cleared on open.
// ---------------------------------------------------------------------------

Future<void> showChatSheet(BuildContext context) {
  final c = context.read<GameController>();
  c.markChatRead();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // The sheet lives under the root navigator, outside the screen-level
    // GameController provider — pass the instance in explicitly.
    builder: (_) => _ChatSheet(c: c),
  );
}

class _ChatSheet extends StatelessWidget {
  final GameController c;
  const _ChatSheet({required this.c});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
            const SizedBox(height: 10),
            Text('Chat · ${c.setup.opponentName}', style: AppTheme.title18),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: c.chat.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: Text('Say hi! Quick messages below.',
                            style: AppTheme.dim13),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: c.chat
                          .map((m) => Align(
                                alignment: m.mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: m.mine
                                        ? AppColors.orange.withOpacity(0.85)
                                        : AppColors.cardLight,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    m.text,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Hi!', 'GL 🙂', 'Nice!', 'GG', 'Thanks']
                  .map((q) => GestureDetector(
                        onTap: () => c.sendChat(q),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.cardDark,
                            borderRadius: BorderRadius.circular(18),
                            border:
                                Border.all(color: AppColors.orange, width: 1),
                          ),
                          child: Text(q,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.orangeLight)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Play CPU (L1): difficulty + color, casual by default, optional
// "Competitive" (clock + rating).
// ---------------------------------------------------------------------------

class PlayCpuChoice {
  final CpuDifficulty difficulty;
  final bool playerIsWhite;
  final bool competitive;
  const PlayCpuChoice(this.difficulty, this.playerIsWhite,
      {this.competitive = false});
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
  bool _competitive = false;

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
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _competitive = !_competitive),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          _competitive ? AppColors.orange : AppColors.textDim,
                      width: 2.5,
                    ),
                  ),
                  child: _competitive
                      ? const Center(
                          child: Icon(Icons.circle,
                              size: 12, color: AppColors.orange))
                      : null,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Competitive (clock + rating)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _competitive
                ? 'Timed game · result affects your rating'
                : 'Friendly untimed game · no rating at stake',
            style: AppTheme.dim12,
          ),
          const SizedBox(height: 16),
          ArenaButton(
            label: 'Go!',
            onPressed: () {
              final d = [
                _diff == 0
                    ? CpuDifficulty.easy
                    : _diff == 1
                        ? CpuDifficulty.medium
                        : CpuDifficulty.hard
              ][0];
              Navigator.of(context)
                  .pop(PlayCpuChoice(d, _color == 0, competitive: _competitive));
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
                    leading:
                        SvgPicture.asset(tc.iconAsset, width: 36, height: 36),
                    title: Text(tc.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    subtitle: Text(tc.subtitle, style: AppTheme.dim13),
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
                            color:
                                sel ? AppColors.orange : AppColors.textDim,
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
// Settings (+ board theme, U10)
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
            _toggle(context, s, Icons.volume_up, 'Sound', s.sound, 'sound'),
            _toggle(context, s, Icons.grid_on, 'Show last move', s.showLastMove,
                'showLastMove'),
            _toggle(context, s, Icons.animation, 'Piece animation',
                s.pieceAnimation, 'pieceAnimation'),
            _toggle(context, s, Icons.help_outline, 'Show move help',
                s.showMoveHelp, 'showMoveHelp'),
            _toggle(context, s, Icons.check_circle_outline, 'Confirm my moves',
                s.confirmMoves, 'confirmMoves'),
            _toggle(context, s, Icons.workspace_premium, 'Auto promote queen',
                s.autoQueen, 'autoQueen'),
            _toggle(context, s, Icons.chat_bubble_outline, 'Show chat',
                s.showChat, 'showChat'),
            _toggle(context, s, Icons.image, 'Piece images (PNG set)',
                s.pieceImages, 'pieceImages'),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: SectionLabel('Board theme'),
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(BoardTheme.all.length, (i) {
                final t = BoardTheme.all[i];
                final sel = s.boardTheme == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => s.setInt('boardTheme', i),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? AppColors.orange : Colors.transparent,
                          width: 2,
                        ),
                        color: AppColors.cardDark,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: Container(
                                      height: 16, color: t.light)),
                              Expanded(child: Container(height: 16, color: t.dark)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(t.name,
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle(BuildContext context, SettingsController s, IconData icon,
      String label, bool value, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.orange),
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
// Customize (U1): name / board / pieces.
// ---------------------------------------------------------------------------

Future<void> showCustomizeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CustomizeSheet(),
  );
}

class _CustomizeSheet extends StatefulWidget {
  const _CustomizeSheet();

  @override
  State<_CustomizeSheet> createState() => _CustomizeSheetState();
}

class _CustomizeSheetState extends State<_CustomizeSheet> {
  late TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.read<ArenaRepository>().name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ArenaRepository>();
    final s = context.watch<SettingsController>();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            18, 10, 18, MediaQuery.of(context).viewInsets.bottom + 16),
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
            Text('Customize', style: AppTheme.title22),
            const SizedBox(height: 12),
            const SectionLabel('Display name'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    maxLength: 18,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.cardDark,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(10))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ArenaButton(
                  label: 'Save',
                  onPressed: () async {
                    await repo.rename(_name.text);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            const SectionLabel('Board'),
            const SizedBox(height: 6),
            Row(
              children: List.generate(BoardTheme.all.length, (i) {
                final t = BoardTheme.all[i];
                final sel = s.boardTheme == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => s.setInt('boardTheme', i),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? AppColors.orange : Colors.transparent,
                          width: 2,
                        ),
                        color: AppColors.cardDark,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: Container(
                                      height: 22, color: t.light)),
                              Expanded(
                                  child:
                                      Container(height: 22, color: t.dark)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(t.name, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            const SectionLabel('Pieces'),
            const SizedBox(height: 6),
            Row(
              children: [
                ...[
                  const PieceWidget(piece: knight, size: 34),
                  const PieceWidget(piece: -knight, size: 34),
                  const PieceWidget(piece: queen, size: 34),
                  const PieceWidget(piece: -queen, size: 34),
                ],
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Classic vector set · more sets soon',
                      style: AppTheme.dim12),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const SectionLabel('Avatar'),
            const SizedBox(height: 6),
            Row(
              children: [
                AvatarWidget(name: repo.name, flag: repo.flagEmoji, radius: 26),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _pickCountry(context, repo),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text('Flag ${repo.flagEmoji} · tap to change',
                        style: AppTheme.dim13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _pickCountry(BuildContext context, ArenaRepository repo) {
    const supported = [
      'US', 'GB', 'IN', 'PK', 'PL', 'DE', 'FR', 'ES',
      'IT', 'BR', 'RU', 'MX', 'NO', 'MA', 'TR',
    ];
    showDialog(
      context: context,
      builder: (ctx) => CountryPickerDialog(
        isSearchable: true,
        titlePadding: const EdgeInsets.all(8),
        searchInputDecoration:
            const InputDecoration(hintText: 'Search country…'),
        title: const Text('Select your country'),
        itemFilter: (c) => supported.contains(c.isoCode),
        priorityList: [
          CountryPickerUtils.getCountryByIsoCode(repo.flagCode.toUpperCase()),
        ],
        onValuePicked: (Country country) =>
            repo.setFlagCode(country.isoCode),
        itemBuilder: (Country country) => Row(
          children: [
            CountryPickerUtils.getDefaultFlagImage(country),
            const SizedBox(width: 8),
            Text(country.name),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rules (U1 "How to play chess")
// ---------------------------------------------------------------------------

Future<void> showRulesDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('How to play',
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('• White moves first; players alternate one move.',
                style: TextStyle(fontSize: 13)),
            SizedBox(height: 6),
            Text('• Tap a piece to see its legal moves (dots).',
                style: TextStyle(fontSize: 13)),
            SizedBox(height: 6),
            Text('• Capture by landing on an enemy piece.',
                style: TextStyle(fontSize: 13)),
            SizedBox(height: 6),
            Text('• Check = king attacked; you must escape it.',
                style: TextStyle(fontSize: 13)),
            SizedBox(height: 6),
            Text('• Checkmate = no escape → game over.',
                style: TextStyle(fontSize: 13)),
            SizedBox(height: 6),
            Text('• Castling, en passant and promotion are supported.',
                style: TextStyle(fontSize: 13)),
            SizedBox(height: 6),
            Text('• Flag falling loses on time (draw vs bare king).',
                style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
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
// Game over (U8): rich sheet with animated rating count.
// ---------------------------------------------------------------------------

Future<String?> showGameOverDialog(
  BuildContext context,
  GameOverInfo info,
  GameSetup setup,
) {
  return showModalBottomSheet<String>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _GameOverSheet(info: info, setup: setup),
  );
}

class _GameOverSheet extends StatelessWidget {
  final GameOverInfo info;
  final GameSetup setup;
  const _GameOverSheet({required this.info, required this.setup});

  @override
  Widget build(BuildContext context) {
    final delta = info.ratingDelta;
    final deltaColor = delta > 0
        ? AppColors.greenBright
        : delta < 0
            ? AppColors.red
            : AppColors.textDim;
    final IconData resultIcon;
    final Color resultColor;
    if (info.playerScore == 1) {
      resultIcon = Icons.emoji_events;
      resultColor = AppColors.gold;
    } else if (info.playerScore == 0.5) {
      resultIcon = Icons.handshake;
      resultColor = AppColors.textDim;
    } else {
      resultIcon = Icons.sentiment_dissatisfied;
      resultColor = AppColors.red;
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: resultColor.withOpacity(0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(resultIcon, size: 54, color: resultColor),
            ),
            const SizedBox(height: 10),
            Text(info.title,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(info.reason, style: AppTheme.dim13),
            Text('${info.movesPlayed} moves · vs ${setup.opponentName}',
                style: AppTheme.dim12),
            const SizedBox(height: 14),
            if (info.rated)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bar_chart,
                      size: 18, color: AppColors.textDim),
                  // Animated count-up / count-down of the rating delta.
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: delta.toDouble()),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOut,
                    builder: (_, v, __) => Text(
                      '${v.round() >= 0 ? '+' : ''}${v.round()} → ${info.newRating}',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: deltaColor),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SvgPicture.asset('assets/icons/coin.svg',
                      width: 18, height: 18),
                  const SizedBox(width: 4),
                  Text(
                    '+${info.coinsEarned}',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold),
                  ),
                ],
              )
            else
              Text(
                'Not rated · no rating change',
                style: AppTheme.dim13,
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
                  'Ad placeholder — fullscreen ad shows here in the online build',
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
      ),
    );
  }
}
