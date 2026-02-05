import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:running_playlist_ai/features/auth/providers/auth_providers.dart';

/// Login screen with Spotify OAuth button.
///
/// After successful login, GoRouter redirect handles navigation
/// to the home screen automatically -- no manual navigation needed.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Running Playlist AI',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Music that matches your stride',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await ref.read(authRepositoryProvider).signInWithSpotify();
                } on Exception catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Login failed: $error'),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.music_note),
              label: const Text('Log in with Spotify'),
            ),
          ],
        ),
      ),
    );
  }
}
