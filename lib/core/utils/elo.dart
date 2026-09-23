import 'dart:math';

/// Standard ELO rating helpers.
class Elo {
  /// Expected score of player A (rating [a]) vs player B (rating [b]).
  static double expected(double a, double b) =>
      1.0 / (1.0 + pow(10.0, (b - a) / 400.0));

  /// New rating after a game. [score]: 1.0 win, 0.5 draw, 0.0 loss.
  /// K = 40 for provisional players (< 30 games), else 32.
  static int newRating({
    required int mine,
    required int opponent,
    required double score,
    int gamesPlayed = 100,
  }) {
    final k = gamesPlayed < 30 ? 40 : 32;
    final exp = expected(mine.toDouble(), opponent.toDouble());
    return (mine + k * (score - exp)).round();
  }

  /// Rating delta (can be negative) for display.
  static int delta({
    required int mine,
    required int opponent,
    required double score,
    int gamesPlayed = 100,
  }) =>
      newRating(
        mine: mine,
        opponent: opponent,
        score: score,
        gamesPlayed: gamesPlayed,
      ) -
      mine;
}
