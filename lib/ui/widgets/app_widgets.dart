/// Shared UI atoms: cards, 3D orange button, chips, screen background.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_theme.dart';

/// Gradient scaffold background matching the video (deep navy).
class ArenaBackground extends StatelessWidget {
  final Widget child;
  const ArenaBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgTop, AppColors.bgDeep],
        ),
      ),
      child: child,
    );
  }
}

class ArenaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const ArenaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

/// 3D orange button from the video (highlight top, deep bottom edge).
class ArenaButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final VoidCallback? onPressed;
  final Widget? leading;
  final double fontSize;

  const ArenaButton({
    super.key,
    required this.label,
    this.subtitle,
    this.onPressed,
    this.leading,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? const LinearGradient(
                  colors: [Color(0xFF6B7B8D), Color(0xFF4A5A6D)])
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.orangeLight, AppColors.orangeDark],
                ),
          borderRadius: BorderRadius.circular(14),
          border: Border(
            bottom: BorderSide(
              color: onPressed == null
                  ? const Color(0xFF2E3B48)
                  : AppColors.orangeDeep,
              width: 4,
            ),
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black38, offset: Offset(0, 1))
                    ],
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
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

class CoinChip extends StatelessWidget {
  final int coins;
  const CoinChip({super.key, required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/icons/coin.svg', width: 18, height: 18),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppColors.textDim,
      ),
    );
  }
}

void showArenaSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.cardLight,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}
