/// Pure-Dart chess rules engine (no Flutter dependency).
///
/// Board: 64 squares, index = rank * 8 + file, rank 0 == rank "1" (white home).
/// Pieces: P=1 N=2 B=3 R=4 Q=5 K=6, white positive, black negative, 0 empty.
///
/// Covers: pseudo-legal + legal move generation, castling, en passant,
/// promotion, check / checkmate / stalemate, fifty-move rule, threefold
/// repetition, insufficient material, FEN parse/emit, basic SAN.
library;

// ---------------------------------------------------------------------------
// Move
// ---------------------------------------------------------------------------

class ChessMove {
  final int from;
  final int to;
  /// 0 = none, else piece type 2..5 (N, B, R, Q).
  final int promotion;

  const ChessMove(this.from, this.to, [this.promotion = 0]);

  /// UCI-ish string, e.g. "e2e4", "g7g8q".
  String toUci() {
    const promoChar = {knight: 'n', bishop: 'b', rook: 'r', queen: 'q'};
    return '${_sqName(from)}${_sqName(to)}${promotion == 0 ? '' : promoChar[promotion] ?? ''}';
  }

  static String _sqName(int sq) =>
      '${String.fromCharCode(97 + (sq & 7))}${(sq >> 3) + 1}';

  @override
  bool operator ==(Object other) =>
      other is ChessMove &&
      from == other.from &&
      to == other.to &&
      promotion == other.promotion;

  @override
  int get hashCode => from * 64 * 8 + to * 8 + promotion;

  @override
  String toString() => toUci();
}

// ---------------------------------------------------------------------------
// Piece helpers
// ---------------------------------------------------------------------------

const int empty = 0;
const int pawn = 1;
const int knight = 2;
const int bishop = 3;
const int rook = 4;
const int queen = 5;
const int king = 6;

int fileOf(int sq) => sq & 7;
int rankOf(int sq) => sq >> 3;
bool onBoard(int f, int r) => f >= 0 && f < 8 && r >= 0 && r < 8;

// ---------------------------------------------------------------------------
// Game state
// ---------------------------------------------------------------------------

enum GamePhase { ongoing, checkmate, stalemate, draw }

class _Snapshot {
  final List<int> board;
  final bool whiteToMove;
  final bool wk, wq, bk, bq;
  final int ep;
  final int half;
  final int full;
  final Map<String, int> posCounts;
  final int sanLength;
  _Snapshot(
    this.board,
    this.whiteToMove,
    this.wk,
    this.wq,
    this.bk,
    this.bq,
    this.ep,
    this.half,
    this.full,
    this.posCounts,
    this.sanLength,
  );
}

/// Internal (search) undo record — lighter than [_Snapshot].
class _Undo {
  final ChessMove move;
  final int captured;
  final bool wk, wq, bk, bq;
  final int ep;
  final int half;
  _Undo(this.move, this.captured, this.wk, this.wq, this.bk, this.bq, this.ep,
      this.half);
}

class ChessGame {
  List<int> board = List<int>.filled(64, 0);
  bool whiteToMove = true;
  bool wk = true, wq = true, bk = true, bq = true;
  int ep = -1; // en-passant target square or -1
  int halfmove = 0;
  int fullmove = 1;

  /// SAN history of moves actually played (for UI + undo pairing).
  final List<String> sanHistory = [];
  final List<ChessMove> moveHistory = [];

  final List<_Snapshot> _history = [];
  final List<_Undo> _searchStack = [];
  final List<String> _searchKeys = [];
  bool trackSearchKeys = false;
  Map<String, int> _posCounts = {};

  ChessGame();

  factory ChessGame.startingPosition() =>
      ChessGame.fromFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');

  factory ChessGame.fromFen(String fen) {
    final g = ChessGame();
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 4) {
      throw ArgumentError('Bad FEN: $fen');
    }
    final rows = parts[0].split('/');
    if (rows.length != 8) throw ArgumentError('Bad FEN board: $fen');
    for (var r = 0; r < 8; r++) {
      final rank = 7 - r; // FEN starts at rank 8
      var file = 0;
      for (var i = 0; i < rows[r].length; i++) {
        final c = rows[r][i];
        final digit = int.tryParse(c);
        if (digit != null) {
          file += digit;
        } else {
          final lower = c.toLowerCase();
          var type = 0;
          switch (lower) {
            case 'p':
              type = pawn;
              break;
            case 'n':
              type = knight;
              break;
            case 'b':
              type = bishop;
              break;
            case 'r':
              type = rook;
              break;
            case 'q':
              type = queen;
              break;
            case 'k':
              type = king;
              break;
            default:
              throw ArgumentError('Bad FEN piece: $c');
          }
          final isWhite = c == c.toUpperCase();
          g.board[rank * 8 + file] = isWhite ? type : -type;
          file++;
        }
      }
    }
    g.whiteToMove = parts[1] == 'w';
    final castling = parts[2];
    g.wk = castling.contains('K');
    g.wq = castling.contains('Q');
    g.bk = castling.contains('k');
    g.bq = castling.contains('q');
    g.ep = parts[3] == '-' ? -1 : _parseSquare(parts[3]);
    if (parts.length > 4) g.halfmove = int.tryParse(parts[4]) ?? 0;
    if (parts.length > 5) g.fullmove = int.tryParse(parts[5]) ?? 1;
    g._posCounts[g._positionKey()] = 1;
    return g;
  }

  static int _parseSquare(String s) {
    final f = s.codeUnitAt(0) - 97;
    final r = s.codeUnitAt(1) - 49;
    return r * 8 + f;
  }

  String toFen() {
    final sb = StringBuffer();
    for (var r = 7; r >= 0; r--) {
      var empties = 0;
      for (var f = 0; f < 8; f++) {
        final p = board[r * 8 + f];
        if (p == 0) {
          empties++;
        } else {
          if (empties > 0) {
            sb.write(empties);
            empties = 0;
          }
          const names = '.pnbrqk';
          final ch = names[p.abs()];
          sb.write(p > 0 ? ch.toUpperCase() : ch);
        }
      }
      if (empties > 0) sb.write(empties);
      if (r > 0) sb.write('/');
    }
    sb.write(whiteToMove ? ' w ' : ' b ');
    var c = '';
    if (wk) c += 'K';
    if (wq) c += 'Q';
    if (bk) c += 'k';
    if (bq) c += 'q';
    sb.write(c.isEmpty ? '- ' : '$c ');
    sb.write(ep == -1
        ? '-'
        : '${String.fromCharCode(97 + fileOf(ep))}${rankOf(ep) + 1}');
    sb.write(' $halfmove $fullmove');
    return sb.toString();
  }

  String _positionKey() {
    // Board + side + castling + ep (for threefold repetition).
    final sb = StringBuffer();
    for (final p in board) {
      sb.writeCharCode(p + 100); // shift to stay positive
    }
    sb.write(whiteToMove ? 'w' : 'b');
    sb.write(wk ? 'K' : '');
    sb.write(wq ? 'Q' : '');
    sb.write(bk ? 'k' : '');
    sb.write(bq ? 'q' : '');
    sb.write('e$ep');
    return sb.toString();
  }

  ChessGame clone() {
    final g = ChessGame()
      ..board = List<int>.from(board)
      ..whiteToMove = whiteToMove
      ..wk = wk
      ..wq = wq
      ..bk = bk
      ..bq = bq
      ..ep = ep
      ..halfmove = halfmove
      ..fullmove = fullmove
      .._posCounts = Map<String, int>.from(_posCounts);
    g.sanHistory.addAll(sanHistory);
    g.moveHistory.addAll(moveHistory);
    return g;
  }

  // -------------------------------------------------------------------------
  // Attack detection
  // -------------------------------------------------------------------------

  bool isSquareAttacked(int sq, bool byWhite) {
    final f = fileOf(sq), r = rankOf(sq);
    // Pawns: white pawn attacks from one rank below the target.
    final pr = byWhite ? r - 1 : r + 1;
    if (pr >= 0 && pr < 8) {
      for (final df in [-1, 1]) {
        final pf = f + df;
        if (pf >= 0 && pf < 8) {
          final p = board[pr * 8 + pf];
          if (p == (byWhite ? pawn : -pawn)) return true;
        }
      }
    }
    // Knights.
    const kofs = [
      [1, 2],
      [2, 1],
      [2, -1],
      [1, -2],
      [-1, -2],
      [-2, -1],
      [-2, 1],
      [-1, 2]
    ];
    for (final o in kofs) {
      final nf = f + o[0], nr = r + o[1];
      if (onBoard(nf, nr) &&
          board[nr * 8 + nf] == (byWhite ? knight : -knight)) {
        return true;
      }
    }
    // King.
    for (var df = -1; df <= 1; df++) {
      for (var dr = -1; dr <= 1; dr++) {
        if (df == 0 && dr == 0) continue;
        final nf = f + df, nr = r + dr;
        if (onBoard(nf, nr) &&
            board[nr * 8 + nf] == (byWhite ? king : -king)) {
          return true;
        }
      }
    }
    // Sliders.
    const bishopDirs = [
      [1, 1],
      [1, -1],
      [-1, 1],
      [-1, -1]
    ];
    const rookDirs = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1]
    ];
    for (final o in bishopDirs) {
      var nf = f + o[0], nr = r + o[1];
      while (onBoard(nf, nr)) {
        final p = board[nr * 8 + nf];
        if (p != 0) {
          if (byWhite
              ? (p == bishop || p == queen)
              : (p == -bishop || p == -queen)) return true;
          break;
        }
        nf += o[0];
        nr += o[1];
      }
    }
    for (final o in rookDirs) {
      var nf = f + o[0], nr = r + o[1];
      while (onBoard(nf, nr)) {
        final p = board[nr * 8 + nf];
        if (p != 0) {
          if (byWhite
              ? (p == rook || p == queen)
              : (p == -rook || p == -queen)) return true;
          break;
        }
        nf += o[0];
        nr += o[1];
      }
    }
    return false;
  }

  int _kingSquare(bool white) {
    final want = white ? king : -king;
    for (var i = 0; i < 64; i++) {
      if (board[i] == want) return i;
    }
    return -1;
  }

  bool inCheck([bool? white]) {
    final w = white ?? whiteToMove;
    final ksq = _kingSquare(w);
    if (ksq < 0) return false;
    return isSquareAttacked(ksq, !w);
  }

  // -------------------------------------------------------------------------
  // Move generation
  // -------------------------------------------------------------------------

  /// All legal moves for the side to move.
  List<ChessMove> legalMoves() {
    final pseudo = _pseudoMoves();
    final out = <ChessMove>[];
    for (final m in pseudo) {
      final undo = _doMove(m);
      final movedWhite = !whiteToMove;
      final ksq = _kingSquare(movedWhite);
      final ok = ksq < 0 || !isSquareAttacked(ksq, whiteToMove);
      _undoMove(undo);
      if (ok) out.add(m);
    }
    return out;
  }

  /// Legal moves starting from [sq].
  List<ChessMove> legalMovesFrom(int sq) =>
      legalMoves().where((m) => m.from == sq).toList();

  List<ChessMove> _pseudoMoves() {
    final moves = <ChessMove>[];
    for (var sq = 0; sq < 64; sq++) {
      final p = board[sq];
      if (p == 0) continue;
      if (whiteToMove != (p > 0)) continue;
      final f = fileOf(sq), r = rankOf(sq);
      switch (p.abs()) {
        case pawn:
          _pawnMoves(moves, sq, f, r, p > 0);
          break;
        case knight:
          _jumpMoves(moves, sq, f, r, p > 0, const [
            [1, 2],
            [2, 1],
            [2, -1],
            [1, -2],
            [-1, -2],
            [-2, -1],
            [-2, 1],
            [-1, 2]
          ]);
          break;
        case bishop:
          _slideMoves(moves, sq, f, r, p > 0, const [
            [1, 1],
            [1, -1],
            [-1, 1],
            [-1, -1]
          ]);
          break;
        case rook:
          _slideMoves(moves, sq, f, r, p > 0, const [
            [1, 0],
            [-1, 0],
            [0, 1],
            [0, -1]
          ]);
          break;
        case queen:
          _slideMoves(moves, sq, f, r, p > 0, const [
            [1, 1],
            [1, -1],
            [-1, 1],
            [-1, -1],
            [1, 0],
            [-1, 0],
            [0, 1],
            [0, -1]
          ]);
          break;
        case king:
          _jumpMoves(moves, sq, f, r, p > 0, const [
            [1, 1],
            [1, 0],
            [1, -1],
            [0, 1],
            [0, -1],
            [-1, 1],
            [-1, 0],
            [-1, -1]
          ]);
          _castleMoves(moves, p > 0);
          break;
      }
    }
    return moves;
  }

  void _pawnMoves(List<ChessMove> out, int sq, int f, int r, bool white) {
    final dir = white ? 1 : -1;
    final startRank = white ? 1 : 6;
    final promoRank = white ? 7 : 0;
    final oneR = r + dir;
    if (oneR >= 0 && oneR < 8) {
      final one = oneR * 8 + f;
      if (board[one] == 0) {
        if (oneR == promoRank) {
          for (final pr in [queen, rook, bishop, knight]) {
            out.add(ChessMove(sq, one, pr));
          }
        } else {
          out.add(ChessMove(sq, one));
        }
        if (r == startRank) {
          final two = (r + 2 * dir) * 8 + f;
          if (board[two] == 0) out.add(ChessMove(sq, two));
        }
      }
      for (final df in [-1, 1]) {
        final nf = f + df;
        if (nf < 0 || nf > 7) continue;
        final target = oneR * 8 + nf;
        final tp = board[target];
        if (tp != 0 && (tp > 0) != white) {
          if (oneR == promoRank) {
            for (final pr in [queen, rook, bishop, knight]) {
              out.add(ChessMove(sq, target, pr));
            }
          } else {
            out.add(ChessMove(sq, target));
          }
        } else if (target == ep) {
          out.add(ChessMove(sq, target)); // en passant capture
        }
      }
    }
  }

  void _jumpMoves(List<ChessMove> out, int sq, int f, int r, bool white,
      List<List<int>> offsets) {
    for (final o in offsets) {
      final nf = f + o[0], nr = r + o[1];
      if (!onBoard(nf, nr)) continue;
      final tp = board[nr * 8 + nf];
      if (tp == 0 || (tp > 0) != white) out.add(ChessMove(sq, nr * 8 + nf));
    }
  }

  void _slideMoves(List<ChessMove> out, int sq, int f, int r, bool white,
      List<List<int>> dirs) {
    for (final d in dirs) {
      var nf = f + d[0], nr = r + d[1];
      while (onBoard(nf, nr)) {
        final tp = board[nr * 8 + nf];
        if (tp == 0) {
          out.add(ChessMove(sq, nr * 8 + nf));
        } else {
          if ((tp > 0) != white) out.add(ChessMove(sq, nr * 8 + nf));
          break;
        }
        nf += d[0];
        nr += d[1];
      }
    }
  }

  void _castleMoves(List<ChessMove> out, bool white) {
    if (white) {
      if (board[4] != king) return;
      if (inCheck(true)) return;
      if (wk &&
          board[5] == 0 &&
          board[6] == 0 &&
          board[7] == rook &&
          !isSquareAttacked(5, false) &&
          !isSquareAttacked(6, false)) {
        out.add(const ChessMove(4, 6));
      }
      if (wq &&
          board[3] == 0 &&
          board[2] == 0 &&
          board[1] == 0 &&
          board[0] == rook &&
          !isSquareAttacked(3, false) &&
          !isSquareAttacked(2, false)) {
        out.add(const ChessMove(4, 2));
      }
    } else {
      if (board[60] != -king) return;
      if (inCheck(false)) return;
      if (bk &&
          board[61] == 0 &&
          board[62] == 0 &&
          board[63] == -rook &&
          !isSquareAttacked(61, true) &&
          !isSquareAttacked(62, true)) {
        out.add(const ChessMove(60, 62));
      }
      if (bq &&
          board[59] == 0 &&
          board[58] == 0 &&
          board[57] == 0 &&
          board[56] == -rook &&
          !isSquareAttacked(59, true) &&
          !isSquareAttacked(58, true)) {
        out.add(const ChessMove(60, 58));
      }
    }
  }

  // -------------------------------------------------------------------------
  // Make / unmake (internal, no history bookkeeping except position state)
  // -------------------------------------------------------------------------

  _Undo _doMove(ChessMove m) {
    final prevWk = wk;
    final prevWq = wq;
    final prevBk = bk;
    final prevBq = bq;
    final prevEp = ep;
    final prevHalf = halfmove;
    final piece = board[m.from];
    final white = piece > 0;
    var captured = board[m.to];
    final isEp = piece.abs() == pawn && m.to == ep && captured == 0;
    if (isEp) {
      captured = board[fileOf(m.to) + rankOf(m.from) * 8];
      board[fileOf(m.to) + rankOf(m.from) * 8] = 0;
    }
    board[m.from] = 0;
    // Castling rook hop.
    if (piece.abs() == king && (m.to - m.from).abs() == 2) {
      if (m.to > m.from) {
        board[m.from + 1] = board[m.from + 3];
        board[m.from + 3] = 0;
      } else {
        board[m.from - 1] = board[m.from - 4];
        board[m.from - 4] = 0;
      }
    }
    board[m.to] = m.promotion == 0
        ? piece
        : (white ? m.promotion : -m.promotion);
    // Castling rights.
    if (piece == king) {
      wk = false;
      wq = false;
    } else if (piece == -king) {
      bk = false;
      bq = false;
    } else if (piece == rook) {
      if (m.from == 0) wq = false;
      if (m.from == 7) wk = false;
    } else if (piece == -rook) {
      if (m.from == 56) bq = false;
      if (m.from == 63) bk = false;
    }
    if (m.to == 0 && captured == rook) wq = false;
    if (m.to == 7 && captured == rook) wk = false;
    if (m.to == 56 && captured == -rook) bq = false;
    if (m.to == 63 && captured == -rook) bk = false;

    ep = -1;
    if (piece.abs() == pawn && (m.to - m.from).abs() == 16) {
      ep = (m.from + m.to) ~/ 2;
    }
    halfmove =
        (piece.abs() == pawn || captured != 0) ? 0 : halfmove + 1;
    if (!white) fullmove++;
    whiteToMove = !whiteToMove;
    if (trackSearchKeys) _searchKeys.add(_positionKey());
    final record =
        _Undo(m, captured, prevWk, prevWq, prevBk, prevBq, prevEp, prevHalf);
    _searchStack.add(record);
    return record;
  }

  void _undoMove(_Undo u) {
    whiteToMove = !whiteToMove; // restores the side that made the move
    if (!whiteToMove) {
      // we reverted black's move, which had incremented fullmove
      fullmove--;
    }
    final m = u.move;
    final moved = board[m.to];
    board[m.to] = 0;
    board[m.from] =
        m.promotion == 0 ? moved : (moved > 0 ? pawn : -pawn);
    // restore captured (incl. en passant square)
    if (u.captured != 0) {
      if (board[m.from].abs() == pawn && m.to == u.ep) {
        // it was en passant
        board[fileOf(m.to) + rankOf(m.from) * 8] = u.captured;
      } else {
        board[m.to] = u.captured;
      }
    }
    // undo castling rook hop
    if (moved.abs() == king && (m.to - m.from).abs() == 2) {
      if (m.to > m.from) {
        board[m.from + 3] = board[m.from + 1];
        board[m.from + 1] = 0;
      } else {
        board[m.from - 4] = board[m.from - 1];
        board[m.from - 1] = 0;
      }
    }
    wk = u.wk;
    wq = u.wq;
    bk = u.bk;
    bq = u.bq;
    ep = u.ep;
    halfmove = u.half;
    if (trackSearchKeys && _searchKeys.isNotEmpty) {
      _searchKeys.removeLast();
    }
    _searchStack.removeLast();
  }

  // -------------------------------------------------------------------------
  // Public make / undo (with history, repetition, SAN pairing)
  // -------------------------------------------------------------------------

  /// Plays [m] if legal. Returns SAN of the move, or null if illegal.
  /// Callers that need promotion choice should use [findMoves].
  String? playMove(ChessMove m) {
    final legal = legalMoves();
    ChessMove? match;
    for (final lm in legal) {
      if (lm == m) {
        match = lm;
        break;
      }
    }
    if (match == null) return null;
    final san = toSan(match);
    _history.add(_Snapshot(
      List<int>.from(board),
      whiteToMove,
      wk,
      wq,
      bk,
      bq,
      ep,
      halfmove,
      fullmove,
      Map<String, int>.from(_posCounts),
      sanHistory.length,
    ));
    _doMove(match);
    _searchStack.clear(); // public moves don't use search stack
    _searchKeys.clear();
    sanHistory.add(san);
    moveHistory.add(match);
    _posCounts[_positionKey()] = (_posCounts[_positionKey()] ?? 0) + 1;
    return san;
  }

  /// All legal moves from [from] to [to] (multiple = promotion choice).
  List<ChessMove> findMoves(int from, int to) => legalMoves()
      .where((m) => m.from == from && m.to == to)
      .toList();

  bool get canUndo => _history.isNotEmpty;

  /// Undoes one ply. Returns false if no history.
  bool undo() {
    if (_history.isEmpty) return false;
    final s = _history.removeLast();
    board = s.board;
    whiteToMove = s.whiteToMove;
    wk = s.wk;
    wq = s.wq;
    bk = s.bk;
    bq = s.bq;
    ep = s.ep;
    halfmove = s.half;
    fullmove = s.full;
    _posCounts = s.posCounts;
    while (sanHistory.length > s.sanLength) {
      sanHistory.removeLast();
      moveHistory.removeLast();
    }
    return true;
  }

  /// Undoes a full round (two plies) — used for takebacks vs CPU.
  void undoFullRound() {
    undo();
    undo();
  }

  // -------------------------------------------------------------------------
  // Game end
  // -------------------------------------------------------------------------

  GamePhase get phase {
    final moves = legalMoves();
    if (moves.isNotEmpty) {
      if (halfmove >= 100) return GamePhase.draw;
      if ((_posCounts[_positionKey()] ?? 0) >= 3) return GamePhase.draw;
      if (_insufficientMaterial()) return GamePhase.draw;
      return GamePhase.ongoing;
    }
    return inCheck() ? GamePhase.checkmate : GamePhase.stalemate;
  }

  bool get isGameOver => phase != GamePhase.ongoing;

  /// 'w' | 'b' | null (draw/ongoing).
  String? get winner {
    if (phase != GamePhase.checkmate) return null;
    return whiteToMove ? 'b' : 'w'; // side to move is mated
  }

  String resultText() {
    switch (phase) {
      case GamePhase.checkmate:
        return whiteToMove ? 'Checkmate · Black wins' : 'Checkmate · White wins';
      case GamePhase.stalemate:
        return 'Draw · Stalemate';
      case GamePhase.draw:
        if (halfmove >= 100) return 'Draw · Fifty-move rule';
        if ((_posCounts[_positionKey()] ?? 0) >= 3) {
          return 'Draw · Threefold repetition';
        }
        return 'Draw · Insufficient material';
      case GamePhase.ongoing:
        return inCheck() ? 'Check!' : 'Ongoing';
    }
  }

  bool _insufficientMaterial() {
    var minors = 0;
    for (final p in board) {
      final a = p.abs();
      if (a == pawn || a == rook || a == queen) return false;
      if (a == bishop || a == knight) minors++;
    }
    return minors <= 1; // K vs K, or K+minor vs K
  }

  // -------------------------------------------------------------------------
  // SAN
  // -------------------------------------------------------------------------

  /// SAN for [m] — must be called BEFORE the move is played.
  String toSan(ChessMove m) {
    if (m.promotion == 0) {
      final piece = board[m.from];
      if (piece.abs() == king && (m.to - m.from).abs() == 2) {
        final oo = m.to > m.from ? 'O-O' : 'O-O-O';
        return oo + _checkSuffix(m);
      }
    }
    final piece = board[m.from];
    final isPawn = piece.abs() == pawn;
    final isCapture = board[m.to] != 0 || (isPawn && m.to == ep);
    final sb = StringBuffer();
    if (!isPawn) {
      const names = ['', '', 'N', 'B', 'R', 'Q', 'K'];
      sb.write(names[piece.abs()]);
      // Disambiguation.
      final others = <ChessMove>[];
      for (final lm in legalMoves()) {
        if (lm.to == m.to &&
            lm.from != m.from &&
            board[lm.from] == piece) {
          others.add(lm);
        }
      }
      if (others.isNotEmpty) {
        final sameFile =
            others.any((o) => fileOf(o.from) == fileOf(m.from));
        final sameRank =
            others.any((o) => rankOf(o.from) == rankOf(m.from));
        if (!sameFile) {
          sb.writeCharCode(97 + fileOf(m.from));
        } else if (!sameRank) {
          sb.write(rankOf(m.from) + 1);
        } else {
          sb.writeCharCode(97 + fileOf(m.from));
          sb.write(rankOf(m.from) + 1);
        }
      }
    } else if (isCapture) {
      sb.writeCharCode(97 + fileOf(m.from));
    }
    if (isCapture) sb.write('x');
    sb.writeCharCode(97 + fileOf(m.to));
    sb.write(rankOf(m.to) + 1);
    if (m.promotion != 0) {
      const names = ['', '', 'N', 'B', 'R', 'Q'];
      sb.write('=${names[m.promotion]}');
    }
    return sb.toString() + _checkSuffix(m);
  }

  String _checkSuffix(ChessMove m) {
    final u = _doMove(m);
    String s;
    if (inCheck()) {
      s = legalMoves().isEmpty ? '#' : '+';
    } else {
      s = '';
    }
    _undoMove(u);
    return s;
  }

  // -------------------------------------------------------------------------
  // Search API (used by the AI in chess_ai.dart)
  // -------------------------------------------------------------------------

  /// Makes [m] without history bookkeeping; returns an opaque undo token.
  /// The move MUST be legal (from [legalMoves]).
  Object doSearchMove(ChessMove m) => _doMove(m);

  /// Undoes a move made with [doSearchMove]. Tokens are stack-ordered.
  void undoSearchMove(Object token) => _undoMove(token as _Undo);

  bool get hasInsufficientMaterial => _insufficientMaterial();

  /// Key of the current position (for repetition bookkeeping).
  String get positionKey => _positionKey();

  /// How often [key] occurred in the real game history.
  int positionCount(String key) => _posCounts[key] ?? 0;

  /// True when the current position already occurred twice before
  /// (game history + active search path) — i.e. a drawable repetition.
  bool searchRepeatsDraw() {
    final key = _positionKey();
    var n = _posCounts[key] ?? 0;
    if (trackSearchKeys) {
      for (final k in _searchKeys) {
        if (k == key) n++;
      }
    }
    return n >= 3;
  }

  // -------------------------------------------------------------------------
  // Debug / testing helper
  // -------------------------------------------------------------------------

  /// Counts leaf nodes to [depth] (perft). Used by tests to verify movegen.
  int perft(int depth) {
    if (depth == 0) return 1;
    var nodes = 0;
    for (final m in legalMoves()) {
      final u = _doMove(m);
      nodes += perft(depth - 1);
      _undoMove(u);
    }
    return nodes;
  }
}
