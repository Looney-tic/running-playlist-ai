import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:running_playlist_ai/features/bpm_lookup/domain/bpm_song.dart';

/// Exception thrown when the GetSongBPM API returns an error.
class BpmApiException implements Exception {
  const BpmApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'BpmApiException: $message (status: $statusCode)';
}

/// Client for the GetSongBPM API.
///
/// Makes GET requests to the `/tempo/` endpoint to find songs by BPM.
/// Accepts an [http.Client] for testability (inject `MockClient` in tests).
class GetSongBpmClient {
  GetSongBpmClient({
    required String apiKey,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _httpClient = httpClient ?? http.Client();

  final String _apiKey;
  final http.Client _httpClient;

  static const _baseUrl = 'api.getsong.co';
  static const _timeout = Duration(seconds: 10);

  /// Fetches songs at the given [bpm] from the GetSongBPM API.
  ///
  /// Returns a list of [BpmSong] objects with the given [matchType].
  /// Throws [BpmApiException] on non-200 API responses.
  /// Throws [SocketException] on network connectivity errors.
  /// Throws [TimeoutException] if the request exceeds 10 seconds.
  /// Throws [FormatException] if the response body is not valid JSON.
  Future<List<BpmSong>> fetchSongsByBpm(
    int bpm, {
    BpmMatchType matchType = BpmMatchType.exact,
  }) async {
    final uri = Uri.https(_baseUrl, '/tempo/', {
      'api_key': _apiKey,
      'bpm': bpm.toString(),
    });

    final response = await _httpClient.get(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw BpmApiException(
        'API returned status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final tempoList = body['tempo'] as List<dynamic>? ?? [];

    return tempoList
        .map(
          (item) => BpmSong.fromApiJson(
            item as Map<String, dynamic>,
            matchType: matchType,
          ),
        )
        .toList();
  }

  /// Disposes the underlying HTTP client.
  void dispose() {
    _httpClient.close();
  }
}
