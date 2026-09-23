/// Interactive chess board: tap-to-move, legal-move dots, last-move
/// highlight, check highlight, coordinates, promotion-agnostic.
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../engine/chess_rules.dart';
import 'piece_widget.dart';

class ChessBoardWidget extends StatelessWidget {
  final ChessGame game;
  final bool orientationWhite;
  final int? selected;
  final List<ChessMove> selectedMoves;
  final ChessMove? lastMove;
  final int? checkSquare;
  final int? hintFrom;
  final int? hintTo;
  final int? pendingFrom;
  final int? pendingTo;
  final bool showLastMove;
  final bool animate;
  final int animKey; // bump to animate the last-moved piece
  final BoardTheme theme;
  final bool pieceImages;
  final void Function(int sq) onTap;

  const ChessBoardWidget({
    super.key,
    required this.game,
    required this.orientationWhite,
    required this.onTap,
    this.selected,
    this.selectedMoves = const [],
    this.lastMove,
    this.checkSquare,
    this.hintFrom,
    this.hintTo,
    this.pendingFrom,
    this.pendingTo,
    this.showLastMove = true,
    this.animate = true,
    this.animKey = 0,
    this.theme = BoardTheme.brown,
    this.pieceImages = true,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.frame, width: 6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sqSize = constraints.maxWidth / 8;
            return Stack(
              children: [
                Column(
                  children: List.generate(8, (row) {
                    return Expanded(
                      child: Row(
                        children: List.generate(8, (col) {
                          final sq = _squareAt(row, col);
                          return Expanded(
                            child: _buildSquare(context, sq, sqSize),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  int _squareAt(int row, int col) {
    // row 0 is the top of the screen.
    final r = orientationWhite ? 7 - row : row;
    final f = orientationWhite ? col : 7 - col;
    return r * 8 + f;
  }

  bool _isLight(int sq) => (fileOf(sq) + rankOf(sq)) % 2 == 1;

  Widget _buildSquare(BuildContext context, int sq, double sqSize) {
    final piece = game.board[sq];
    final isLight = _isLight(sq);
    final isSelected = sq == selected;
    final target = selectedMoves.where((m) => m.to == sq).toList();
    final isTarget = target.isNotEmpty;
    final isCaptureTarget = isTarget && game.board[sq] != 0;
    final isLastMove =
        showLastMove &&
        lastMove != null &&
        (lastMove!.from == sq || lastMove!.to == sq);
    final isCheck = sq == checkSquare;
    final isHint = sq == hintFrom || sq == hintTo;
    final isPending = sq == pendingFrom || sq == pendingTo;

    Color overlay = Colors.transparent;
    if (isLastMove) {
      overlay = AppColors.lastMove.withValues(alpha: 0.22);
    }
    if (isHint) {
      overlay = AppColors.selectSq.withValues(alpha: 0.55);
    }
    if (isSelected || isPending) {
      overlay = (isPending ? AppColors.orange : AppColors.selectSq).withValues(
        alpha: 0.6,
      );
    }
    if (isCheck) {
      overlay = AppColors.checkSq.withValues(alpha: 0.75);
    }

    final showFile =
        (!orientationWhite && sq >= 56) || (orientationWhite && sq < 8);
    final showRank =
        (!orientationWhite && fileOf(sq) == 7) ||
        (orientationWhite && fileOf(sq) == 0);

    final coordColor = isLight
        ? theme.dark.withValues(alpha: 0.9)
        : theme.light.withValues(alpha: 0.9);

    return GestureDetector(
      onTap: () => onTap(sq),
      child: AnimatedContainer(
        duration: Duration(milliseconds: animate ? 150 : 0),
        color: isLight ? theme.light : theme.dark,
        child: Stack(
          children: [
            if (overlay != Colors.transparent)
              Positioned.fill(child: Container(color: overlay)),
            if (isSelected || isPending)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isPending
                          ? AppColors.orangeLight
                          : AppColors.selectSq,
                      width: 3,
                    ),
                  ),
                ),
              ),
            if (isLastMove && !isSelected && !isPending)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.lastMove, width: 3),
                  ),
                ),
              ),
            // Piece (scale-in animation on the just-moved piece).
            Center(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: animate ? 160 : 0),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: piece == 0
                    ? SizedBox(key: ValueKey('e$animKey-$sq'), width: sqSize)
                    : PieceWidget(
                        key: ValueKey(
                          lastMove != null && lastMove!.to == sq
                              ? 'm$animKey-$sq'
                              : 'p$piece-$sq',
                        ),
                        piece: piece,
                        size: sqSize * 0.78,
                        useImages: pieceImages,
                      ),
              ),
            ),
            // Move dot / capture ring.
            if (isTarget && !isCheck)
              Center(
                child: isCaptureTarget
                    ? Container(
                        width: sqSize * 0.86,
                        height: sqSize * 0.86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.selectSq.withValues(alpha: 0.9),
                            width: sqSize * 0.09,
                          ),
                        ),
                      )
                    : Container(
                        width: sqSize * 0.32,
                        height: sqSize * 0.32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.28),
                        ),
                      ),
              ),
            // Coordinates.
            if (showRank)
              Positioned(
                left: 2,
                top: 1,
                child: Text(
                  '${rankOf(sq) + 1}',
                  style: TextStyle(
                    fontSize: sqSize * 0.22,
                    fontWeight: FontWeight.w800,
                    color: coordColor,
                  ),
                ),
              ),
            if (showFile)
              Positioned(
                right: 3,
                bottom: 1,
                child: Text(
                  String.fromCharCode(97 + fileOf(sq)),
                  style: TextStyle(
                    fontSize: sqSize * 0.22,
                    fontWeight: FontWeight.w800,
                    color: coordColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tiny static board rendered from a FEN (puzzle list thumbnails).
class MiniBoard extends StatelessWidget {
  final String fen;
  final double size;
  final BoardTheme theme;
  const MiniBoard({
    super.key,
    required this.fen,
    this.size = 64,
    this.theme = BoardTheme.brown,
  });

  @override
  Widget build(BuildContext context) {
    final g = ChessGame.fromFen(fen);
    final sq = size / 8;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Column(
              children: List.generate(8, (r) {
                return Expanded(
                  child: Row(
                    children: List.generate(8, (f) {
                      final light = (f + (7 - r)) % 2 == 1;
                      return Expanded(
                        child: Container(
                          color: light ? theme.light : theme.dark,
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
            ...List.generate(64, (s) {
              final p = g.board[s];
              if (p == 0) return const SizedBox.shrink();
              final r = rankOf(s);
              final f = fileOf(s);
              return Positioned(
                left: f * sq,
                top: (7 - r) * sq,
                width: sq,
                height: sq,
                child: Center(
                  child: PieceWidget(piece: p, size: sq * 0.92),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
