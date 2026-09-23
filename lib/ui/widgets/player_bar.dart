/// Player info bar above/below the board (avatar, name, rating, clock).
/// Video parity: ringed avatar, "(First move)" tag, orange active tint.
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'piece_widget.dart';

class PlayerBar extends StatelessWidget {
  final String name;
  final String flag; // emoji or 'cpu'
  final int? rating;
  final String clockText;
  final bool active; // side to move → orange tint like the video
  final bool showClock;
  final bool firstMove; // "(First move)" tag until that side has moved

  const PlayerBar({
    super.key,
    required this.name,
    required this.flag,
    this.rating,
    required this.clockText,
    this.active = false,
    this.showClock = true,
    this.firstMove = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(
                colors: [Color(0xFF8A4E12), Color(0xFFB96A1B)])
            : const LinearGradient(
                colors: [Color(0xFF2A1608), Color(0xFF3A2110)]),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AvatarWidget(name: name, flag: flag, radius: 23),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rating == null ? name : '$name ($rating)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (showClock)
                  Row(
                    children: [
                      Icon(Icons.timer,
                          size: 14,
                          color: active ? Colors.white : AppColors.textDim),
                      const SizedBox(width: 4),
                      Text(
                        clockText,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : AppColors.textDim,
                        ),
                      ),
                      if (firstMove) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(First move)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white.withOpacity(0.85)
                                : AppColors.textDim,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
