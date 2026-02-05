import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/playlist/domain/song_link_builder.dart';

void main() {
  group('SongLinkBuilder.spotifySearchUrl', () {
    test('builds correct Spotify search URL', () {
      final url =
          SongLinkBuilder.spotifySearchUrl('Lose Yourself', 'Eminem');
      expect(url, startsWith('https://open.spotify.com/search/'));
      expect(url, contains('Lose'));
      expect(url, contains('Eminem'));
    });

    test('encodes special characters', () {
      final url = SongLinkBuilder.spotifySearchUrl(
        "Don't Stop",
        'Fleetwood Mac',
      );
      expect(url, startsWith('https://open.spotify.com/search/'));
      // Should be URI encoded (no raw spaces)
      expect(url.contains(' '), isFalse);
    });

    test('handles ampersands and symbols', () {
      final url =
          SongLinkBuilder.spotifySearchUrl('Rock & Roll', 'AC/DC');
      expect(url, startsWith('https://open.spotify.com/search/'));
      expect(url.contains(' '), isFalse);
    });
  });

  group('SongLinkBuilder.youtubeMusicSearchUrl', () {
    test('builds correct YouTube Music search URL', () {
      final url = SongLinkBuilder.youtubeMusicSearchUrl(
        'Lose Yourself',
        'Eminem',
      );
      expect(url, startsWith('https://music.youtube.com/search'));
      expect(url, contains('q='));
      expect(url, contains('Lose'));
      expect(url, contains('Eminem'));
    });

    test('encodes special characters', () {
      final url = SongLinkBuilder.youtubeMusicSearchUrl(
        "Don't Stop",
        'Fleetwood Mac',
      );
      expect(url, startsWith('https://music.youtube.com/search'));
      // Query parameter value should not have raw spaces
      final queryPart = Uri.parse(url).queryParameters['q']!;
      expect(queryPart, contains("Don't Stop"));
      expect(queryPart, contains('Fleetwood Mac'));
    });
  });
}
