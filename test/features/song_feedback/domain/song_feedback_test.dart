import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/song_feedback/domain/song_feedback.dart';

void main() {
  group('SongKey.normalize', () {
    test('lowercases and trims artist and title', () {
      expect(
        SongKey.normalize('  Eminem ', ' Lose Yourself '),
        equals('eminem|lose yourself'),
      );
    });

    test('handles already normalized input', () {
      expect(
        SongKey.normalize('eminem', 'lose yourself'),
        equals('eminem|lose yourself'),
      );
    });

    test('produces identical keys for curated vs API format', () {
      // Curated data may have different whitespace/casing than API results.
      final curatedKey = SongKey.normalize('  The Chainsmokers', 'Closer ');
      final apiKey = SongKey.normalize('the chainsmokers', 'closer');
      expect(curatedKey, equals(apiKey));
    });
  });

  group('SongFeedback', () {
    SongFeedback _makeFeedback({
      bool isLiked = true,
      String? genre,
      DateTime? feedbackDate,
    }) {
      return SongFeedback(
        songKey: 'eminem|lose yourself',
        isLiked: isLiked,
        feedbackDate: feedbackDate ?? DateTime(2026, 2, 8),
        songTitle: 'Lose Yourself',
        songArtist: 'Eminem',
        genre: genre,
      );
    }

    test('toJson/fromJson round-trip preserves all fields', () {
      final original = _makeFeedback(genre: 'hip-hop');
      final json = original.toJson();
      final restored = SongFeedback.fromJson(json);

      expect(restored.songKey, original.songKey);
      expect(restored.isLiked, original.isLiked);
      expect(restored.feedbackDate, original.feedbackDate);
      expect(restored.songTitle, original.songTitle);
      expect(restored.songArtist, original.songArtist);
      expect(restored.genre, original.genre);
    });

    test('toJson excludes null genre', () {
      final feedback = _makeFeedback(genre: null);
      final json = feedback.toJson();
      expect(json.containsKey('genre'), isFalse);
    });

    test('toJson includes non-null genre', () {
      final feedback = _makeFeedback(genre: 'hip-hop');
      final json = feedback.toJson();
      expect(json.containsKey('genre'), isTrue);
      expect(json['genre'], 'hip-hop');
    });

    test('copyWith toggles isLiked', () {
      final liked = _makeFeedback(isLiked: true);
      final disliked = liked.copyWith(isLiked: false);

      expect(liked.isLiked, isTrue);
      expect(disliked.isLiked, isFalse);
      // Other fields unchanged.
      expect(disliked.songKey, liked.songKey);
      expect(disliked.songTitle, liked.songTitle);
    });

    test('copyWith updates feedbackDate', () {
      final original = _makeFeedback();
      final newDate = DateTime(2026, 3, 1);
      final updated = original.copyWith(feedbackDate: newDate);

      expect(updated.feedbackDate, newDate);
      expect(updated.isLiked, original.isLiked);
    });
  });
}
