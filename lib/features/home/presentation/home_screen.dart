import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Home hub screen with navigation to all app features.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Running Playlist AI'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'What would you like to do?',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/stride'),
              icon: const Icon(Icons.directions_run),
              label: const Text('Stride Calculator'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/run-plan'),
              icon: const Icon(Icons.timer),
              label: const Text('Plan Run'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/taste-profile'),
              icon: const Icon(Icons.music_note),
              label: const Text('Taste Profile'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/playlist'),
              icon: const Icon(Icons.queue_music),
              label: const Text('Generate Playlist'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/playlist-history'),
              icon: const Icon(Icons.history),
              label: const Text('Playlist History'),
            ),
          ],
        ),
      ),
    );
  }
}
