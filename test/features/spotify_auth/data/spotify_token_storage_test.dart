import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/spotify_auth/data/spotify_token_storage.dart';

/// In-memory fake of [FlutterSecureStorage] for unit testing.
///
/// Stores values in a plain [Map] -- no platform channel needed.
class FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _store[key] = value;
    } else {
      _store.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      Map.unmodifiable(_store);
}

void main() {
  late FakeSecureStorage fakeStorage;
  late SpotifyTokenStorage tokenStorage;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    tokenStorage = SpotifyTokenStorage(fakeStorage);
  });

  group('SpotifyTokenStorage', () {
    test('saveCredentials + loadCredentials round-trip returns same values',
        () async {
      final expiration = DateTime.utc(2026, 3, 1, 12, 0, 0);
      final creds = SpotifyCredentials(
        accessToken: 'access-abc',
        refreshToken: 'refresh-xyz',
        expiration: expiration,
        scopes: ['user-read-email', 'playlist-modify-public'],
        codeVerifier: 'verifier-123',
      );

      await tokenStorage.saveCredentials(creds);
      final loaded = await tokenStorage.loadCredentials();

      expect(loaded, isNotNull);
      expect(loaded!.accessToken, equals('access-abc'));
      expect(loaded.refreshToken, equals('refresh-xyz'));
      expect(loaded.expiration, equals(expiration));
      expect(loaded.scopes, equals(['user-read-email', 'playlist-modify-public']));
      expect(loaded.codeVerifier, equals('verifier-123'));
    });

    test('loadCredentials returns null when nothing saved', () async {
      final loaded = await tokenStorage.loadCredentials();
      expect(loaded, isNull);
    });

    test('clearAll removes all spotify keys', () async {
      await tokenStorage.saveCredentials(const SpotifyCredentials(
        accessToken: 'token',
        refreshToken: 'refresh',
        codeVerifier: 'verifier',
      ));

      await tokenStorage.clearAll();

      final loaded = await tokenStorage.loadCredentials();
      expect(loaded, isNull);

      // Verify the underlying store has no spotify keys.
      final allEntries = await fakeStorage.readAll();
      final spotifyKeys =
          allEntries.keys.where((k) => k.startsWith('spotify_'));
      expect(spotifyKeys, isEmpty);
    });

    test('hasCredentials returns true after save, false after clear', () async {
      expect(await tokenStorage.hasCredentials, isFalse);

      await tokenStorage.saveCredentials(
          const SpotifyCredentials(accessToken: 'token'));
      expect(await tokenStorage.hasCredentials, isTrue);

      await tokenStorage.clearAll();
      expect(await tokenStorage.hasCredentials, isFalse);
    });

    test('handles null optional fields', () async {
      // Save credentials with only the required accessToken.
      const creds = SpotifyCredentials(accessToken: 'only-token');

      await tokenStorage.saveCredentials(creds);
      final loaded = await tokenStorage.loadCredentials();

      expect(loaded, isNotNull);
      expect(loaded!.accessToken, equals('only-token'));
      expect(loaded.refreshToken, isNull);
      expect(loaded.expiration, isNull);
      expect(loaded.scopes, isNull);
      expect(loaded.codeVerifier, isNull);
    });
  });

  group('SpotifyCredentials', () {
    test('isExpired returns true when expiration is in the past', () {
      final creds = SpotifyCredentials(
        accessToken: 'token',
        expiration: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(creds.isExpired, isTrue);
    });

    test('isExpired returns false when expiration is in the future', () {
      final creds = SpotifyCredentials(
        accessToken: 'token',
        expiration: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(creds.isExpired, isFalse);
    });

    test('isExpired returns false when expiration is null', () {
      const creds = SpotifyCredentials(accessToken: 'token');
      expect(creds.isExpired, isFalse);
    });
  });
}
