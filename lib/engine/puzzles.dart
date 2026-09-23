/// Bundled tactical puzzles (all mate-in-1, hand-verified).
///
/// The controller accepts ANY mating move, so alternate solutions also win.
/// [solutionUci] is the canonical solution used for Hint/Solution buttons.
library;

class Puzzle {
  final int id;
  final String title;
  final String fen;
  final String solutionUci; // e.g. "e1e8", "g7g8q"
  final String hint;

  const Puzzle({
    required this.id,
    required this.title,
    required this.fen,
    required this.solutionUci,
    required this.hint,
  });

  bool get whiteToMove => fen.split(' ').length > 1 && fen.split(' ')[1] == 'w';
}

const List<Puzzle> kPuzzles = [
  Puzzle(
    id: 1,
    title: 'Back Rank Basics',
    fen: '6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1',
    solutionUci: 'e1e8',
    hint: 'The rook belongs on the 8th rank.',
  ),
  Puzzle(
    id: 2,
    title: 'Queen Takes Pawn',
    fen: '7k/7p/8/8/4B2Q/8/8/5K2 w - - 0 1',
    solutionUci: 'h4h7',
    hint: 'The bishop guards your queen. Capture on h7!',
  ),
  Puzzle(
    id: 3,
    title: 'Pawn Shield Mate',
    fen: '5rk1/5p2/5P1Q/8/8/8/5PPP/6K1 w - - 0 1',
    solutionUci: 'h6g7',
    hint: 'The pawn on f6 protects the mating square.',
  ),
  Puzzle(
    id: 4,
    title: 'Bishop Battery',
    fen: '6k1/5p1p/5B1Q/8/8/8/8/6K1 w - - 0 1',
    solutionUci: 'h6g7',
    hint: 'Queen to g7 — the bishop has it covered.',
  ),
  Puzzle(
    id: 5,
    title: 'Black Strikes Back',
    fen: '4r1k1/8/8/8/8/8/5PPP/6K1 b - - 0 1',
    solutionUci: 'e8e1',
    hint: 'You are Black. Slide down the e-file!',
  ),
  Puzzle(
    id: 6,
    title: 'Promote to Win',
    fen: 'R5nk/5P1p/8/8/8/8/8/6K1 w - - 0 1',
    solutionUci: 'f7g8q',
    hint: 'Take on g8 and promote — queen or rook both mate.',
  ),
  Puzzle(
    id: 7,
    title: 'Cornered King',
    fen: 'k7/pp6/8/3Q4/8/8/8/R5K1 w - - 0 1',
    solutionUci: 'd5d8',
    hint: 'Two mates exist here — find either one.',
  ),
  Puzzle(
    id: 8,
    title: 'Long Rook Trip',
    fen: '7k/5ppp/8/8/8/8/8/R5K1 w - - 0 1',
    solutionUci: 'a1a8',
    hint: 'All the way from a1 to a8!',
  ),
  Puzzle(
    id: 9,
    title: 'Black Back Rank',
    fen: 'r6k/8/8/8/8/8/5PPP/6K1 b - - 0 1',
    solutionUci: 'a8a1',
    hint: 'You are Black. Mirror of puzzle 8!',
  ),
  Puzzle(
    id: 10,
    title: 'Queen to the Corner',
    fen: '6k1/5ppp/4Q3/8/8/8/8/6K1 w - - 0 1',
    solutionUci: 'e6e8',
    hint: 'e8 seals every escape square.',
  ),
  Puzzle(
    id: 11,
    title: "Scholar's Mate",
    fen: '3qk3/3ppp2/8/7Q/2B5/8/8/4K3 w - - 0 1',
    solutionUci: 'h5f7',
    hint: 'The classic! Queen to f7, guarded by the bishop.',
  ),
  Puzzle(
    id: 12,
    title: 'Reversed Scholar',
    fen: 'k7/8/8/2b5/7q/8/1n3PP1/4K3 b - - 0 1',
    solutionUci: 'h4f2',
    hint: 'You are Black. Capture on f2 — bishop and knight cover all.',
  ),
];

/// Daily puzzle selector (rotates through the pack).
Puzzle dailyPuzzle(DateTime date) {
  final dayIndex =
      date.difference(DateTime(date.year, 1, 1)).inDays.abs();
  return kPuzzles[dayIndex % kPuzzles.length];
}
