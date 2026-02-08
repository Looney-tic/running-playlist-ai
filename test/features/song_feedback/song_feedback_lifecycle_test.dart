import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/song_feedback/domain/song_feedback.dart';
import 'package:running_playlist_ai/features/song_feedback/providers/song_feedback_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SongFeedbackNotifier lifecycle', () {
    late ProviderContainer container;

    SongFeedback _makeFeedback({
      required String artist,
      required String title,
      bool isLiked = true,
    }) {
      final key = SongKey.normalize(artist, title);
      return SongFeedback(
        songKey: key,
        isLiked: isLiked,
        feedbackDate: DateTime(2026, 2, 8),
        songTitle: title,
        songArtist: artist,
      );
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    Future<SongFeedbackNotifier> _notifier() async {
      final notifier = container.read(songFeedbackProvider.notifier);
      await notifier.ensureLoaded();
      return notifier;
    }

    Map<String, SongFeedback> _state() {
      return container.read(songFeedbackProvider);
    }

    test('starts with empty map', () async {
      await _notifier();
      expect(_state(), isEmpty);
    });

    test('addFeedback stores entry', () async {
      final notifier = await _notifier();
      final feedback = _makeFeedback(artist: 'Eminem', title: 'Lose Yourself');

      await notifier.addFeedback(feedback);

      expect(_state(), hasLength(1));
      expect(_state().values.first.isLiked, isTrue);
    });

    test('addFeedback updates existing entry', () async {
      final notifier = await _notifier();
      final liked =
          _makeFeedback(artist: 'Eminem', title: 'Lose Yourself', isLiked: true);
      final disliked =
          _makeFeedback(artist: 'Eminem', title: 'Lose Yourself', isLiked: false);

      await notifier.addFeedback(liked);
      await notifier.addFeedback(disliked);

      expect(_state(), hasLength(1));
      expect(_state().values.first.isLiked, isFalse);
    });

    test('removeFeedback removes entry', () async {
      final notifier = await _notifier();
      final feedback = _makeFeedback(artist: 'Eminem', title: 'Lose Yourself');

      await notifier.addFeedback(feedback);
      expect(_state(), hasLength(1));

      await notifier.removeFeedback(feedback.songKey);
      expect(_state(), isEmpty);
    });

    test('removeFeedback ignores missing key', () async {
      final notifier = await _notifier();

      // Should not crash.
      await notifier.removeFeedback('nonexistent|key');
      expect(_state(), isEmpty);
    });

    test('getFeedback returns null for unknown key', () async {
      final notifier = await _notifier();
      expect(notifier.getFeedback('nonexistent|key'), isNull);
    });

    test('getFeedback returns entry for known key', () async {
      final notifier = await _notifier();
      final feedback = _makeFeedback(artist: 'Eminem', title: 'Lose Yourself');

      await notifier.addFeedback(feedback);

      final result = notifier.getFeedback(feedback.songKey);
      expect(result, isNotNull);
      expect(result!.isLiked, isTrue);
      expect(result.songArtist, 'Eminem');
    });
  });

  group('Persistence round-trip', () {
    late ProviderContainer container;

    SongFeedback _makeFeedback({
      required String artist,
      required String title,
      bool isLiked = true,
    }) {
      final key = SongKey.normalize(artist, title);
      return SongFeedback(
        songKey: key,
        isLiked: isLiked,
        feedbackDate: DateTime(2026, 2, 8),
        songTitle: title,
        songArtist: artist,
      );
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    Future<SongFeedbackNotifier> _notifier() async {
      final notifier = container.read(songFeedbackProvider.notifier);
      await notifier.ensureLoaded();
      return notifier;
    }

    Map<String, SongFeedback> _state() {
      return container.read(songFeedbackProvider);
    }

    test('feedback survives dispose and reload', () async {
      final notifier = await _notifier();

      // Add two feedbacks: one liked, one disliked.
      await notifier.addFeedback(
        _makeFeedback(artist: 'Eminem', title: 'Lose Yourself', isLiked: true),
      );
      await notifier.addFeedback(
        _makeFeedback(
            artist: 'Nickelback', title: 'Photograph', isLiked: false),
      );

      expect(_state(), hasLength(2));

      // Dispose first container.
      container.dispose();

      // Create fresh container -- DO NOT call setMockInitialValues again
      // so SharedPreferences still has the persisted data.
      container = ProviderContainer();
      final notifier2 = await _notifier();

      final reloadedState = _state();
      expect(reloadedState, hasLength(2));

      final eminemFeedback =
          notifier2.getFeedback(SongKey.normalize('Eminem', 'Lose Yourself'));
      expect(eminemFeedback, isNotNull);
      expect(eminemFeedback!.isLiked, isTrue);

      final nickelbackFeedback =
          notifier2.getFeedback(SongKey.normalize('Nickelback', 'Photograph'));
      expect(nickelbackFeedback, isNotNull);
      expect(nickelbackFeedback!.isLiked, isFalse);
    });

    test('empty state persists as empty', () async {
      await _notifier();
      expect(_state(), isEmpty);

      // Dispose and reload.
      container.dispose();
      container = ProviderContainer();
      await _notifier();

      expect(_state(), isEmpty);
    });
  });
}
