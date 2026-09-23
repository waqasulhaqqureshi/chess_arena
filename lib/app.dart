/// Root app + bottom-tab shell (Play / Friends / Rankings / Profile).
library;

import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/rankings_screen.dart';
import 'ui/screens/secondary_screens.dart';
import 'ui/widgets/app_widgets.dart';

class ChessArenaApp extends StatelessWidget {
  const ChessArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Arena',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ArenaBackground(
        child: IndexedStack(
          index: _tab,
          children: [
            HomeScreen(onTab: _go),
            const FriendsScreen(),
            const RankingsScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A1728),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _item(0, _knightIcon(_tab == 0), 'Play'),
                _divider(),
                _item(1, _navIcon(Icons.group, _tab == 1), 'Friends'),
                _divider(),
                _item(2, _navIcon(Icons.emoji_events, _tab == 2), 'Rankings'),
                _divider(),
                _item(3, _navIcon(Icons.person, _tab == 3), 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, bool sel) {
    return Icon(icon,
        size: 24, color: sel ? AppColors.orange : AppColors.textDim);
  }

  Widget _knightIcon(bool sel) {
    return BlackKnight(
      size: 24,
      fillColor: sel ? AppColors.orange : const Color(0xFF7E94AB),
      strokeColor: sel ? AppColors.orangeDeep : const Color(0xFF3A4A5E),
    );
  }

  Widget _divider() =>
      const SizedBox(height: 26, child: VerticalDivider(color: Colors.white12));

  Widget _item(int index, Widget icon, String label) {
    final sel = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _go(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel ? AppColors.orange : Colors.transparent,
              width: 1.5,
            ),
            color: sel
                ? AppColors.orange.withOpacity( 0.12)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: sel ? AppColors.orange : AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
