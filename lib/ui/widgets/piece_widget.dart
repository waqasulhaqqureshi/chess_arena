/// Chess piece renderer (Wikimedia-style vectors via
/// `chess_vectors_flutter`) + circular avatars.
library;

import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';

/// Real vector chess piece. [piece] is the signed type from the engine
/// (+ = white, - = black, 0 = empty).
class PieceWidget extends StatelessWidget {
  final int piece;
  final double size;

  const PieceWidget({super.key, required this.piece, required this.size});

  @override
  Widget build(BuildContext context) {
    if (piece == 0) return const SizedBox.shrink();
    final white = piece > 0;
    final Widget w;
    switch (piece.abs()) {
      case 6:
        w = white ? WhiteKing(size: size) : BlackKing(size: size);
        break;
      case 5:
        w = white ? WhiteQueen(size: size) : BlackQueen(size: size);
        break;
      case 4:
        w = white ? WhiteRook(size: size) : BlackRook(size: size);
        break;
      case 3:
        w = white ? WhiteBishop(size: size) : BlackBishop(size: size);
        break;
      case 2:
        w = white ? WhiteKnight(size: size) : BlackKnight(size: size);
        break;
      case 1:
      default:
        w = white ? WhitePawn(size: size) : BlackPawn(size: size);
        break;
    }
    // Soft drop shadow for depth on the wooden board.
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: w,
    );
  }
}

/// Circular avatar with initial + flag badge (matches video header style).
/// CPU opponents get a robot glyph instead of initials.
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
          child: isCpu
              ? Icon(Icons.smart_toy,
                  size: radius * 1.1, color: Colors.white)
              : Text(
                  _initials(name),
                  style: TextStyle(
                    fontSize: radius * 0.85,
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
