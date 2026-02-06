import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/taste_profile/domain/taste_profile.dart';
import 'package:running_playlist_ai/features/taste_profile/providers/taste_profile_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TasteProfileLibraryNotifier lifecycle', () {
    late ProviderContainer container;

    TasteProfile _makeProfile({
      required String id,
      String? name,
      List<RunningGenre> genres = const [RunningGenre.pop],
    }) {
      return TasteProfile(
        id: id,
        name: name,
        genres: genres,
      );
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    Future<TasteProfileLibraryNotifier> _notifier() async {
      final notifier =
          container.read(tasteProfileLibraryProvider.notifier);
      await notifier.ensureLoaded();
      return notifier;
    }

    TasteProfileLibraryState _state() {
      return container.read(tasteProfileLibraryProvider);
    }

    test('create profile: adds to state and selects it', () async {
      final notifier = await _notifier();
      final p1 = _makeProfile(id: '1', name: 'Rock Mix');

      await notifier.addProfile(p1);

      final state = _state();
      expect(state.profiles, hasLength(1));
      expect(state.profiles.first.name, 'Rock Mix');
      expect(state.selectedProfile?.id, '1');
    });

    test('create second profile: has 2 profiles, second selected', () async {
      final notifier = await _notifier();
      final p1 = _makeProfile(id: '1', name: 'Rock Mix');
      final p2 = _makeProfile(id: '2', name: 'EDM Mix');

      await notifier.addProfile(p1);
      await notifier.addProfile(p2);

      final state = _state();
      expect(state.profiles, hasLength(2));
      expect(state.selectedProfile?.id, '2');
    });

    test('edit profile: updates name in state', () async {
      final notifier = await _notifier();
      final p1 = _makeProfile(id: '1', name: 'Rock Mix');

      await notifier.addProfile(p1);
      await notifier.updateProfile(p1.copyWith(name: 'Updated Mix'));

      final state = _state();
      expect(state.profiles.first.name, 'Updated Mix');
    });

    test('select profile: switches selected to specified id', () async {
      final notifier = await _notifier();
      final p1 = _makeProfile(id: '1', name: 'Rock Mix');
      final p2 = _makeProfile(id: '2', name: 'EDM Mix');

      await notifier.addProfile(p1);
      await notifier.addProfile(p2);
      // p2 is now selected (addProfile selects it)
      expect(_state().selectedProfile?.id, '2');

      await notifier.selectProfile('1');
      expect(_state().selectedProfile?.id, '1');
    });

    test('delete non-selected profile: keeps selection, removes target',
        () async {
      final notifier = await _notifier();
      final p1 = _makeProfile(id: '1', name: 'Rock Mix');
      final p2 = _makeProfile(id: '2', name: 'EDM Mix');

      await notifier.addProfile(p1);
      await notifier.addProfile(p2);
      await notifier.selectProfile('1');

      await notifier.deleteProfile('2');

      final state = _state();
      expect(state.profiles, hasLength(1));
      expect(state.profiles.first.id, '1');
      expect(state.selectedProfile?.id, '1');
    });

    test('delete selected profile: falls back to first remaining', () async {
      final notifier = await _notifier();
      final p1 = _makeProfile(id: '1', name: 'Rock Mix');
      final p2 = _makeProfile(id: '2', name: 'EDM Mix');

      await notifier.addProfile(p1);
      await notifier.addProfile(p2);
      // p2 is selected
      expect(_state().selectedProfile?.id, '2');

      await notifier.deleteProfile('2');

      final state = _state();
      expect(state.profiles, hasLength(1));
      expect(state.selectedProfile?.id, '1');
    });

    test('full lifecycle: create, edit, select, delete, verify', () async {
      final notifier = await _notifier();
      final p1 = _makeProfile(id: '1', name: 'Rock Mix');
      final p2 = _makeProfile(id: '2', name: 'EDM Mix');

      // Create two profiles
      await notifier.addProfile(p1);
      await notifier.addProfile(p2);
      expect(_state().profiles, hasLength(2));

      // Edit profile 1 name
      await notifier.updateProfile(p1.copyWith(name: 'Indie Rock'));

      // Select profile 1
      await notifier.selectProfile('1');
      expect(_state().selectedProfile?.id, '1');

      // Delete profile 2
      await notifier.deleteProfile('2');
      expect(_state().profiles, hasLength(1));

      // Verify profile 1 has updated name and is selected
      final state = _state();
      expect(state.selectedProfile?.id, '1');
      expect(state.selectedProfile?.name, 'Indie Rock');
    });

    test('persistence round-trip: data survives dispose and reload', () async {
      final notifier = await _notifier();
      final p1 = _makeProfile(id: '1', name: 'Rock Mix');
      final p2 = _makeProfile(id: '2', name: 'EDM Mix');

      await notifier.addProfile(p1);
      await notifier.addProfile(p2);
      await notifier.updateProfile(p1.copyWith(name: 'Indie Rock'));
      await notifier.selectProfile('1');
      await notifier.deleteProfile('2');

      // Dispose first container
      container.dispose();

      // Create fresh container -- DO NOT call setMockInitialValues again
      // so SharedPreferences still has the persisted data
      container = ProviderContainer();
      final notifier2 =
          container.read(tasteProfileLibraryProvider.notifier);
      await notifier2.ensureLoaded();

      final state = _state();
      expect(state.profiles, hasLength(1));
      expect(state.profiles.first.name, 'Indie Rock');
      expect(state.selectedProfile?.id, '1');
    });
  });
}
