import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_playlist_ai/features/spotify_auth/data/mock_spotify_auth_repository.dart';
import 'package:running_playlist_ai/features/spotify_auth/data/spotify_token_storage.dart';
import 'package:running_playlist_ai/features/spotify_auth/domain/spotify_auth_service.dart';

/// In-memory fake of [FlutterSecureStorage] for unit testing.
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
  late MockSpotifyAuthRepository repo;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    tokenStorage = SpotifyTokenStorage(fakeStorage);
    repo = MockSpotifyAuthRepository(tokenStorage);
  });

  tearDown(() {
    repo.dispose();
  });

  group('MockSpotifyAuthRepository', () {
    test('initial status is disconnected', () {
      expect(repo.status, equals(SpotifyConnectionStatus.disconnected));
    });

    test('connect() transitions: disconnected -> connecting -> connected',
        () async {
      final statuses = <SpotifyConnectionStatus>[];
      repo.statusStream.listen(statuses.add);

      await repo.connect();
      // Allow stream events to be delivered.
      await Future<void>.delayed(Duration.zero);

      expect(statuses, [
        SpotifyConnectionStatus.connecting,
        SpotifyConnectionStatus.connected,
      ]);
      expect(repo.status, equals(SpotifyConnectionStatus.connected));
    });

    test('after connect(), getAccessToken() returns non-null token', () async {
      await repo.connect();
      final token = await repo.getAccessToken();
      expect(token, isNotNull);
      expect(token, startsWith('mock_'));
    });

    test('disconnect() clears token and sets status to disconnected',
        () async {
      await repo.connect();
      await repo.disconnect();

      expect(repo.status, equals(SpotifyConnectionStatus.disconnected));
      expect(await tokenStorage.hasCredentials, isFalse);
    });

    test('after disconnect(), getAccessToken() returns null', () async {
      await repo.connect();
      await repo.disconnect();

      final token = await repo.getAccessToken();
      expect(token, isNull);
    });

    test('restoreSession() with saved credentials sets status to connected',
        () async {
      // Pre-populate storage with credentials.
      await tokenStorage.saveCredentials(SpotifyCredentials(
        accessToken: 'restored-token',
        expiration: DateTime.now().add(const Duration(hours: 1)),
      ));

      await repo.restoreSession();
      expect(repo.status, equals(SpotifyConnectionStatus.connected));
    });

    test('restoreSession() without credentials stays disconnected', () async {
      await repo.restoreSession();
      expect(repo.status, equals(SpotifyConnectionStatus.disconnected));
    });

    test(
        'getAccessToken() with expired token simulates refresh (returns new token)',
        () async {
      // Save an expired credential.
      await tokenStorage.saveCredentials(SpotifyCredentials(
        accessToken: 'old-token',
        refreshToken: 'refresh-token',
        expiration: DateTime.now().subtract(const Duration(hours: 1)),
        codeVerifier: 'verifier',
      ));

      final newToken = await repo.getAccessToken();

      expect(newToken, isNotNull);
      expect(newToken, isNot(equals('old-token')));
      expect(newToken, startsWith('mock_'));

      // Verify the refreshed token is persisted.
      final loaded = await tokenStorage.loadCredentials();
      expect(loaded!.accessToken, equals(newToken));
    });

    test('statusStream emits status changes in order', () async {
      final statuses = <SpotifyConnectionStatus>[];
      repo.statusStream.listen(statuses.add);

      await repo.connect();
      await repo.disconnect();
      // Allow stream events to be delivered.
      await Future<void>.delayed(Duration.zero);

      expect(statuses, [
        SpotifyConnectionStatus.connecting,
        SpotifyConnectionStatus.connected,
        SpotifyConnectionStatus.disconnected,
      ]);
    });
  });
}
