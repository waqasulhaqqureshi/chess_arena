/// Chess piece renderer + circular avatars.
///
/// Pieces render from the MIT `chess_interface` package's fillable PNG set
/// (`modern_minimalist`), tinted via [BlendMode.srcIn] color filter — the same
/// image is recolored white or black, exactly like the classic
/// "white sprite + filter" trick. Falls back to `chess_vectors_flutter`
/// vectors if the package asset is ever unavailable.
library;

import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:country_pickers/country_pickers.dart';
import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';

import '../../core/theme/app_theme.dart';

/// Renders a flag from either an emoji string (legacy) or an ISO-3166
/// alpha-2 code (real flag image via `country_pickers`).
Widget flagWidget(String flag, double size) {
  if (flag.isEmpty || flag == 'cpu') return const SizedBox.shrink();
  if (flag.length <= 2) {
    try {
      final c = CountryPickerUtils.getCountryByIsoCode(flag.toUpperCase());
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          width: size,
          height: size * 0.72,
          child: FittedBox(
            fit: BoxFit.fill,
            child: CountryPickerUtils.getDefaultFlagImage(c),
          ),
        ),
      );
    } catch (_) {
      // unknown ISO → fall through to text
    }
  }
  return Text(flag, style: TextStyle(fontSize: size));
}

const Map<int, String> _pieceFiles = {
  1: 'pawn',
  2: 'knight',
  3: 'bishop',
  4: 'rook',
  5: 'queen',
  6: 'king',
};

/// Real chess piece image. [piece] is the signed type from the engine
/// (+ = white, - = black, 0 = empty).
class PieceWidget extends StatelessWidget {
  final int piece;
  final double size;

  /// False → classic vector set instead of PNG images.
  final bool useImages;

  const PieceWidget({
    super.key,
    required this.piece,
    required this.size,
    this.useImages = true,
  });

  @override
  Widget build(BuildContext context) {
    if (piece == 0) return const SizedBox.shrink();
    final white = piece > 0;
    if (!useImages) return _vector(white);
    final file = _pieceFiles[piece.abs()] ?? 'pawn';
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
      child: Image.asset(
        'packages/chess_interface/assets/modern_minimalist/$file.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        // The bundled sprite is a single-color fill; the color filter
        // turns it into a white or a black piece.
        color: white ? AppColors.whitePiece : AppColors.blackPiece,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, __, ___) => _vector(white),
      ),
    );
  }

  Widget _vector(bool white) {
    switch (piece.abs()) {
      case 6:
        return white ? WhiteKing(size: size) : BlackKing(size: size);
      case 5:
        return white ? WhiteQueen(size: size) : BlackQueen(size: size);
      case 4:
        return white ? WhiteRook(size: size) : BlackRook(size: size);
      case 3:
        return white ? WhiteBishop(size: size) : BlackBishop(size: size);
      case 2:
        return white ? WhiteKnight(size: size) : BlackKnight(size: size);
      case 1:
      default:
        return white ? WhitePawn(size: size) : BlackPawn(size: size);
    }
  }
}

/// Circular Multiavatar identicon (deterministic per name) + flag badge.
/// CPU opponents get a robot glyph instead.
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
    final d = radius * 2;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: SizedBox(
            width: d,
            height: d,
            child: isCpu
                ? Container(
                    color: const Color(0xFF3A3A3A),
                    child: Icon(Icons.smart_toy,
                        size: radius * 1.1, color: Colors.white),
                  )
                : RandomAvatar(
                    name,
                    trBackground: true,
                    width: d,
                    height: d,
                  ),
          ),
        ),
        if (!isCpu)
          Positioned(
            right: -2,
            bottom: -2,
            child: flagWidget(flag, radius * 0.7),
          ),
      ],
    );
  }
}
