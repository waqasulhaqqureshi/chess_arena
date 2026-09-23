/// Opponent assignment — the product backbone:
///
/// 1. **Online first**: try to open a real channel via Supabase. While the
///    lobby is not live (fresh Play Store launch, zero players) this
///    returns null immediately.
/// 2. **Simulated-human fallback**: seat a bot that is indistinguishable
///    from a person — random realistic name, random country flag (rendered
///    via `country_pickers`), deterministic avatar (`random_avatar` seeds
///    off the name), rating near the player's, and strength derived from
///    that rating (plus a nudge for the player's recent form).
library;

import 'dart:math';

import '../data/remote/supabase_service.dart';

class OpponentIdentity {
  final String name;
  final String flagIso; // ISO-3166 alpha-2, rendered via country_pickers
  final int rating;
  const OpponentIdentity(this.name, this.flagIso, this.rating);
}

class MatchmakingService {
  static const _names = [
    'Aarav Sharma', 'Fatima Khan', 'Liam Carter', 'Sofia Reyes',
    'Mateusz Kowalski', 'Yusuf Demir', 'Chen Wei', 'Diego Torres',
    'Aisha Bello', 'Ivan Petrov', 'Lucas Silva', 'Emma Müller',
    'Noah Kim', 'Zainab Ali', 'Omar Hassan', 'Priya Nair',
    'Hassan Raza', 'Maria Gonzalez', 'Jan Novak', 'Elif Yilmaz',
    'Ravi Patel', 'Nadia Hussain', 'Tom Becker', 'Leila Farahani',
    'Carlos Mendes', 'Anna Kowalczyk', 'Bilal Sheikh', 'Sara Ali',
    'Viktor Orlov', 'Mei Lin', 'Ahmed Mansour', 'Julia Santos',
    'Kwame Mensah', 'Tariq Aziz', 'Elena Popescu', 'Marco Rossi',
    'Hugo Dubois', 'Ines Martinez', 'Faisal Iqbal', 'Dana Haddad',
  ];

  static const _flags = [
    'IN', 'PK', 'US', 'GB', 'DE', 'FR', 'ES', 'IT',
    'BR', 'RU', 'MX', 'PL', 'TR', 'MA', 'NO', 'CA',
    'AU', 'NL', 'PT', 'AR', 'EG', 'BD', 'UA', 'PH',
  ];

  static final Random _rng = Random();

  /// Priority #1: a real online opponent. Null until the lobby ships.
  static Future<OpponentIdentity?> tryOnline(int nearRating) async {
    if (!SupabaseService.isReady) return null;
    // Real matchmaking channel lands with the online update; until then
    // we never block the player — the fallback seats someone instantly.
    return null;
  }

  /// Priority #2: a believable human stand-in.
  static OpponentIdentity simulatedHuman(
    int nearRating, {
    int formBoost = 0,
  }) {
    final name = _names[_rng.nextInt(_names.length)];
    final flag = _flags[_rng.nextInt(_flags.length)];
    final elo =
        (nearRating + _rng.nextInt(301) - 150 + formBoost).clamp(400, 2400);
    return OpponentIdentity(name, flag, elo);
  }

  /// Winning streak → slightly tougher opponents; losing streak → gentler.
  static int formBoostFor(List<String> form) {
    final last = form.length > 5 ? form.sublist(form.length - 5) : form;
    var d = 0;
    for (final r in last) {
      if (r == 'w') { d += 1; } else if (r == 'l') { d -= 1; } }
    return (d * 20).clamp(-60, 60);
  }
}
