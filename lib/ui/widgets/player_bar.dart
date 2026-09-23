/// Player info bar above/below the board (avatar, name, rating, clock).
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

  const PlayerBar({
    super.key,
    required this.name,
    required this.flag,
    this.rating,
    required this.clockText,
    this.active = false,
    this.showClock = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(
                colors: [Color(0xFF8A4E12), Color(0xFFB96A1B)])
            : const LinearGradient(
                colors: [Color(0xFF2A1608), Color(0xFF3A2110)]),
      ),
      child: Row(
        children: [
          AvatarWidget(name: name, flag: flag, radius: 20),
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
                      const Icon(Icons.timer, size: 14, color: AppColors.textDim),
                      const SizedBox(width: 4),
                      Text(
                        clockText,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: active
                              ? Colors.white
                              : AppColors.textDim,
                        ),
                      ),
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
