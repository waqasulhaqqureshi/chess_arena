/// Root app + bottom-tab shell (Play / Friends / Rankings / Profile).
library;

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
                _item(0, '♞', 'Play'),
                _divider(),
                _item(1, '👥', 'Friends'),
                _divider(),
                _item(2, '🏆', 'Rankings'),
                _divider(),
                _item(3, '👤', 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() =>
      const SizedBox(height: 26, child: VerticalDivider(color: Colors.white12));

  Widget _item(int index, String icon, String label) {
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
              Text(icon, style: const TextStyle(fontSize: 22)),
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
