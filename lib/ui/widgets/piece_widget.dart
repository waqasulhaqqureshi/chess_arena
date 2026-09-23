/// Chess piece renderer (styled Unicode glyphs).
///
/// Future upgrade path: drop SVG/PNG sets into assets/pieces/ and switch
/// [PieceWidget] to an asset lookup — all call sites stay unchanged.
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../engine/chess_rules.dart';

class PieceWidget extends StatelessWidget {
  final int piece; // signed piece type
  final double size;

  const PieceWidget({super.key, required this.piece, required this.size});

  static String glyphFor(int piece) {
    // Filled glyphs for both colors; color carries the side.
    switch (piece.abs()) {
      case king:
        return '♚';
      case queen:
        return '♛';
      case rook:
        return '♜';
      case bishop:
        return '♝';
      case knight:
        return '♞';
      case pawn:
        return '♟';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (piece == 0) return const SizedBox.shrink();
    final white = piece > 0;
    final fill = white ? AppColors.whitePiece : AppColors.blackPiece;
    final edge = white ? const Color(0xFF2A1C10) : const Color(0xFFE8DCC8);
    final o = size * 0.035;
    return Text(
      glyphFor(piece),
      style: TextStyle(
        fontSize: size,
        height: 1.0,
        color: fill,
        shadows: [
          Shadow(offset: Offset(o, 0), color: edge),
          Shadow(offset: Offset(-o, 0), color: edge),
          Shadow(offset: Offset(0, o), color: edge),
          Shadow(offset: Offset(0, -o), color: edge),
          Shadow(offset: Offset(o, o), color: edge),
          Shadow(offset: Offset(-o, -o), color: edge),
          Shadow(offset: Offset(o, -o), color: edge),
          Shadow(offset: Offset(-o, o), color: edge),
          Shadow(
            offset: Offset(0, size * 0.06),
            blurRadius: size * 0.08,
            color: Colors.black54,
          ),
        ],
      ),
    );
  }
}

/// Circular avatar with initial + flag badge (matches video header style).
class AvatarWidget extends StatelessWidget {
  final String name;
  final String flag; // emoji flag or 'cpu'
  final double radius;

  const AvatarWidget({
    super.key,
    required this.name,
    required this.flag,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final isCpu = flag == 'cpu';
    final hue = (name.hashCode % 360).abs().toDouble();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: isCpu
              ? const Color(0xFF3A3A3A)
              : HSLColor.fromAHSL(1, hue, 0.55, 0.45).toColor(),
          child: Text(
            isCpu ? '🤖' : _initials(name),
            style: TextStyle(
              fontSize: isCpu ? radius : radius * 0.85,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        if (!isCpu)
          Positioned(
            right: -2,
            bottom: -2,
            child: Text(flag, style: TextStyle(fontSize: radius * 0.7)),
          ),
      ],
    );
  }

  String _initials(String n) {
    final clean = n.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (clean.isEmpty) return '?';
    if (clean.toLowerCase().startsWith('guest') && clean.length > 5) {
      return clean.substring(5, clean.length >= 7 ? 7 : clean.length);
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }
}
