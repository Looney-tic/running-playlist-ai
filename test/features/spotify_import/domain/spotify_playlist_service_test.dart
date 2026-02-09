import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/spotify_import/data/mock_spotify_playlist_service.dart';
import 'package:running_playlist_ai/features/spotify_import/domain/spotify_playlist_service.dart';

void main() {
  group('MockSpotifyPlaylistService', () {
    late MockSpotifyPlaylistService service;

    setUp(() {
      service = MockSpotifyPlaylistService();
    });

    group('getUserPlaylists', () {
      test('returns 5 playlists with valid data', () async {
        final playlists = await service.getUserPlaylists();

        expect(playlists, hasLength(5));

        for (final playlist in playlists) {
          expect(playlist.id, isNotEmpty);
          expect(playlist.name, isNotEmpty);
          expect(playlist.trackCount, isNotNull);
          expect(playlist.trackCount, greaterThan(0));
          expect(playlist.ownerName, isNotEmpty);
        }
      });

      test('includes expected playlist names', () async {
        final playlists = await service.getUserPlaylists();
        final names = playlists.map((p) => p.name).toList();

        expect(names, contains('Running Hits'));
        expect(names, contains('Morning Run'));
        expect(names, contains('Discover Weekly'));
        expect(names, contains('Workout Mix'));
        expect(names, contains('Chill Run'));
      });

      test('Discover Weekly is owned by Spotify', () async {
        final playlists = await service.getUserPlaylists();
        final discoverWeekly = playlists.firstWhere(
          (p) => p.name == 'Discover Weekly',
        );

        expect(discoverWeekly.ownerName, 'Spotify');
      });
    });

    group('getPlaylistTracks', () {
      test('returns tracks for known playlist IDs', () async {
        final playlists = await service.getUserPlaylists();

        for (final playlist in playlists) {
          final tracks = await service.getPlaylistTracks(playlist.id);
          expect(tracks, isNotEmpty,
              reason: '${playlist.name} should have tracks');
          expect(tracks.length, greaterThanOrEqualTo(5),
              reason: '${playlist.name} should have at least 5 tracks');
        }
      });

      test('returns default tracks for unknown playlist IDs', () async {
        final tracks = await service.getPlaylistTracks('unknown_id_xyz');

        expect(tracks, isNotEmpty);
        // Default tracks include known songs
        final titles = tracks.map((t) => t.title).toSet();
        expect(titles, contains('Stronger'));
      });

      test('all tracks have non-empty title and artist', () async {
        final playlists = await service.getUserPlaylists();

        for (final playlist in playlists) {
          final tracks = await service.getPlaylistTracks(playlist.id);
          for (final track in tracks) {
            expect(track.title, isNotEmpty,
                reason:
                    'Track in ${playlist.name} should have non-empty title');
            expect(track.artist, isNotEmpty,
                reason:
                    'Track in ${playlist.name} should have non-empty artist');
          }
        }
      });

      test('tracks include Spotify URIs', () async {
        final tracks = await service.getPlaylistTracks('mock_pl_1');

        for (final track in tracks) {
          expect(track.spotifyUri, isNotNull);
          expect(track.spotifyUri, startsWith('spotify:track:'));
        }
      });

      test('includes curated catalog overlaps for dedup testing', () async {
        final tracks = await service.getPlaylistTracks('mock_pl_1');
        final titles = tracks.map((t) => t.title).toSet();

        expect(titles, contains('Lose Yourself'));
        expect(titles, contains('Blinding Lights'));
      });
    });
  });

  group('SpotifyPlaylistInfo', () {
    test('const constructor creates immutable instance', () {
      const info = SpotifyPlaylistInfo(
        id: 'test_id',
        name: 'Test Playlist',
        description: 'A test playlist',
        imageUrl: 'https://example.com/image.jpg',
        trackCount: 10,
        ownerName: 'Test User',
      );

      expect(info.id, 'test_id');
      expect(info.name, 'Test Playlist');
      expect(info.description, 'A test playlist');
      expect(info.trackCount, 10);
    });

    test('nullable fields default to null', () {
      const info = SpotifyPlaylistInfo(
        id: 'test_id',
        name: 'Test Playlist',
      );

      expect(info.description, isNull);
      expect(info.imageUrl, isNull);
      expect(info.trackCount, isNull);
      expect(info.ownerName, isNull);
    });
  });

  group('SpotifyPlaylistTrack', () {
    test('const constructor creates immutable instance', () {
      const track = SpotifyPlaylistTrack(
        title: 'Test Song',
        artist: 'Test Artist',
        spotifyUri: 'spotify:track:abc123',
        durationMs: 200000,
        albumName: 'Test Album',
        imageUrl: 'https://example.com/album.jpg',
      );

      expect(track.title, 'Test Song');
      expect(track.artist, 'Test Artist');
      expect(track.spotifyUri, 'spotify:track:abc123');
      expect(track.durationMs, 200000);
    });

    test('nullable fields default to null', () {
      const track = SpotifyPlaylistTrack(
        title: 'Test Song',
        artist: 'Test Artist',
      );

      expect(track.spotifyUri, isNull);
      expect(track.durationMs, isNull);
      expect(track.albumName, isNull);
      expect(track.imageUrl, isNull);
    });
  });
}
