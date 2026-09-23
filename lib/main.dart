/// Chess Arena entrypoint.
///
/// Boot order: Hive (local-first) → Supabase (optional, hybrid) → app.
/// The app is fully playable offline; online features activate when
/// --dart-define SUPABASE_URL / SUPABASE_ANON_KEY are provided.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/local/database.dart';
import 'data/remote/supabase_service.dart';
import 'data/repository/arena_repository.dart';
import 'services/sound_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Database.init();
  await SupabaseService.init();
  SoundService.configure(enabled: Database.setting('sound', true));

  debugPrint(
      '[Boot] Supabase: ${SupabaseService.status} '
      '(${SupabaseService.isReady ? 'hybrid mode' : 'local-only mode'})');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ArenaRepository()),
        ChangeNotifierProvider(create: (_) => SettingsController()),
      ],
      child: const ChessArenaApp(),
    ),
  );
}
