import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/app/app.dart';
import 'package:running_playlist_ai/features/onboarding/data/onboarding_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Pre-load onboarding flag so GoRouter redirect can read it synchronously.
  await OnboardingPreferences.preload();

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
