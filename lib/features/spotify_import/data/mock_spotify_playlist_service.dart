/// Mock implementation of [SpotifyPlaylistService] for development.
///
/// Returns hardcoded playlists and per-playlist tracks after simulated
/// network delay. Used while Spotify Developer Dashboard is unavailable
/// for new app registrations.
///
/// Includes tracks that overlap with the curated catalog (e.g. "Lose
/// Yourself" by "Eminem") for deduplication testing in Plan 02.
library;

import 'package:running_playlist_ai/features/spotify_import/domain/spotify_playlist_service.dart';

/// Mock [SpotifyPlaylistService] with realistic hardcoded data.
///
/// Replace with [RealSpotifyPlaylistService] when Spotify Developer
/// Dashboard credentials are available.
class MockSpotifyPlaylistService implements SpotifyPlaylistService {
  @override
  Future<List<SpotifyPlaylistInfo>> getUserPlaylists() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const [
      SpotifyPlaylistInfo(
        id: 'mock_pl_1',
        name: 'Running Hits',
        description: 'High energy songs for your run',
        imageUrl: 'https://example.com/running-hits.jpg',
        trackCount: 25,
        ownerName: 'Test User',
      ),
      SpotifyPlaylistInfo(
        id: 'mock_pl_2',
        name: 'Morning Run',
        description: 'Start your day right',
        imageUrl: 'https://example.com/morning-run.jpg',
        trackCount: 15,
        ownerName: 'Test User',
      ),
      SpotifyPlaylistInfo(
        id: 'mock_pl_3',
        name: 'Discover Weekly',
        description: 'Your weekly mixtape of fresh music',
        imageUrl: 'https://example.com/discover-weekly.jpg',
        trackCount: 30,
        ownerName: 'Spotify',
      ),
      SpotifyPlaylistInfo(
        id: 'mock_pl_4',
        name: 'Workout Mix',
        description: 'Intense beats for intense workouts',
        imageUrl: 'https://example.com/workout-mix.jpg',
        trackCount: 40,
        ownerName: 'Test User',
      ),
      SpotifyPlaylistInfo(
        id: 'mock_pl_5',
        name: 'Chill Run',
        description: 'Easy pace, easy vibes',
        imageUrl: 'https://example.com/chill-run.jpg',
        trackCount: 12,
        ownerName: 'Test User',
      ),
    ];
  }

  @override
  Future<List<SpotifyPlaylistTrack>> getPlaylistTracks(
    String playlistId,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _mockTracks[playlistId] ?? _defaultTracks;
  }

  /// Per-playlist mock track data for realistic testing.
  static const _mockTracks = <String, List<SpotifyPlaylistTrack>>{
    'mock_pl_1': [
      // Curated catalog overlaps for dedup testing
      SpotifyPlaylistTrack(
        title: 'Lose Yourself',
        artist: 'Eminem',
        spotifyUri: 'spotify:track:mock_lose_yourself',
        durationMs: 326000,
        albumName: '8 Mile Soundtrack',
        imageUrl: 'https://example.com/8mile.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        spotifyUri: 'spotify:track:mock_blinding_lights',
        durationMs: 200000,
        albumName: 'After Hours',
        imageUrl: 'https://example.com/afterhours.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Run the World',
        artist: 'Beyonce',
        spotifyUri: 'spotify:track:mock_run_world',
        durationMs: 236000,
        albumName: '4',
        imageUrl: 'https://example.com/beyonce4.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Stronger',
        artist: 'Kanye West',
        spotifyUri: 'spotify:track:mock_stronger',
        durationMs: 311000,
        albumName: 'Graduation',
        imageUrl: 'https://example.com/graduation.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'HUMBLE.',
        artist: 'Kendrick Lamar',
        spotifyUri: 'spotify:track:mock_humble',
        durationMs: 177000,
        albumName: 'DAMN.',
        imageUrl: 'https://example.com/damn.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Physical',
        artist: 'Dua Lipa',
        spotifyUri: 'spotify:track:mock_physical',
        durationMs: 194000,
        albumName: 'Future Nostalgia',
        imageUrl: 'https://example.com/future_nostalgia.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Levitating',
        artist: 'Dua Lipa',
        spotifyUri: 'spotify:track:mock_levitating',
        durationMs: 203000,
        albumName: 'Future Nostalgia',
        imageUrl: 'https://example.com/future_nostalgia.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Shake It Off',
        artist: 'Taylor Swift',
        spotifyUri: 'spotify:track:mock_shake_it_off',
        durationMs: 219000,
        albumName: '1989',
        imageUrl: 'https://example.com/1989.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Uptown Funk',
        artist: 'Mark Ronson, Bruno Mars',
        spotifyUri: 'spotify:track:mock_uptown_funk',
        durationMs: 270000,
        albumName: 'Uptown Special',
        imageUrl: 'https://example.com/uptown_special.jpg',
      ),
      SpotifyPlaylistTrack(
        title: "Can't Hold Us",
        artist: 'Macklemore, Ryan Lewis',
        spotifyUri: 'spotify:track:mock_cant_hold_us',
        durationMs: 258000,
        albumName: 'The Heist',
        imageUrl: 'https://example.com/the_heist.jpg',
      ),
    ],
    'mock_pl_2': [
      SpotifyPlaylistTrack(
        title: 'Good Morning',
        artist: 'Kanye West',
        spotifyUri: 'spotify:track:mock_good_morning',
        durationMs: 199000,
        albumName: 'Graduation',
        imageUrl: 'https://example.com/graduation.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Walking on Sunshine',
        artist: 'Katrina and the Waves',
        spotifyUri: 'spotify:track:mock_walking_sunshine',
        durationMs: 239000,
        albumName: 'Walking on Sunshine',
        imageUrl: 'https://example.com/walking.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Feeling Good',
        artist: 'Nina Simone',
        spotifyUri: 'spotify:track:mock_feeling_good',
        durationMs: 177000,
        albumName: "I Put a Spell on You",
        imageUrl: 'https://example.com/spell.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Here Comes the Sun',
        artist: 'The Beatles',
        spotifyUri: 'spotify:track:mock_here_comes_sun',
        durationMs: 185000,
        albumName: 'Abbey Road',
        imageUrl: 'https://example.com/abbey_road.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Happy',
        artist: 'Pharrell Williams',
        spotifyUri: 'spotify:track:mock_happy',
        durationMs: 232000,
        albumName: 'Despicable Me 2',
        imageUrl: 'https://example.com/despicable.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Sunrise',
        artist: 'Norah Jones',
        spotifyUri: 'spotify:track:mock_sunrise',
        durationMs: 207000,
        albumName: 'Feels Like Home',
        imageUrl: 'https://example.com/feels_like_home.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Beautiful Day',
        artist: 'U2',
        spotifyUri: 'spotify:track:mock_beautiful_day',
        durationMs: 248000,
        albumName: 'All That You Can\'t Leave Behind',
        imageUrl: 'https://example.com/u2.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Mr. Blue Sky',
        artist: 'Electric Light Orchestra',
        spotifyUri: 'spotify:track:mock_blue_sky',
        durationMs: 303000,
        albumName: 'Out of the Blue',
        imageUrl: 'https://example.com/out_blue.jpg',
      ),
    ],
    'mock_pl_3': [
      SpotifyPlaylistTrack(
        title: 'Heat Waves',
        artist: 'Glass Animals',
        spotifyUri: 'spotify:track:mock_heat_waves',
        durationMs: 238000,
        albumName: 'Dreamland',
        imageUrl: 'https://example.com/dreamland.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'As It Was',
        artist: 'Harry Styles',
        spotifyUri: 'spotify:track:mock_as_it_was',
        durationMs: 167000,
        albumName: "Harry's House",
        imageUrl: 'https://example.com/harrys_house.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Anti-Hero',
        artist: 'Taylor Swift',
        spotifyUri: 'spotify:track:mock_anti_hero',
        durationMs: 201000,
        albumName: 'Midnights',
        imageUrl: 'https://example.com/midnights.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Shivers',
        artist: 'Ed Sheeran',
        spotifyUri: 'spotify:track:mock_shivers',
        durationMs: 207000,
        albumName: '=',
        imageUrl: 'https://example.com/equals.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Stay',
        artist: 'The Kid LAROI, Justin Bieber',
        spotifyUri: 'spotify:track:mock_stay',
        durationMs: 141000,
        albumName: 'F*CK LOVE 3+',
        imageUrl: 'https://example.com/fuck_love.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Peaches',
        artist: 'Justin Bieber',
        spotifyUri: 'spotify:track:mock_peaches',
        durationMs: 198000,
        albumName: 'Justice',
        imageUrl: 'https://example.com/justice.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Montero',
        artist: 'Lil Nas X',
        spotifyUri: 'spotify:track:mock_montero',
        durationMs: 137000,
        albumName: 'Montero',
        imageUrl: 'https://example.com/montero.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Kiss Me More',
        artist: 'Doja Cat, SZA',
        spotifyUri: 'spotify:track:mock_kiss_me_more',
        durationMs: 209000,
        albumName: 'Planet Her',
        imageUrl: 'https://example.com/planet_her.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Good 4 U',
        artist: 'Olivia Rodrigo',
        spotifyUri: 'spotify:track:mock_good_4_u',
        durationMs: 178000,
        albumName: 'SOUR',
        imageUrl: 'https://example.com/sour.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Save Your Tears',
        artist: 'The Weeknd',
        spotifyUri: 'spotify:track:mock_save_tears',
        durationMs: 215000,
        albumName: 'After Hours',
        imageUrl: 'https://example.com/afterhours.jpg',
      ),
    ],
    'mock_pl_4': [
      SpotifyPlaylistTrack(
        title: 'Eye of the Tiger',
        artist: 'Survivor',
        spotifyUri: 'spotify:track:mock_eye_tiger',
        durationMs: 245000,
        albumName: 'Eye of the Tiger',
        imageUrl: 'https://example.com/eye_tiger.jpg',
      ),
      SpotifyPlaylistTrack(
        title: "Gonna Fly Now",
        artist: 'Bill Conti',
        spotifyUri: 'spotify:track:mock_gonna_fly',
        durationMs: 177000,
        albumName: 'Rocky',
        imageUrl: 'https://example.com/rocky.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Power',
        artist: 'Kanye West',
        spotifyUri: 'spotify:track:mock_power',
        durationMs: 292000,
        albumName: 'My Beautiful Dark Twisted Fantasy',
        imageUrl: 'https://example.com/mbdtf.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Work It',
        artist: 'Missy Elliott',
        spotifyUri: 'spotify:track:mock_work_it',
        durationMs: 244000,
        albumName: 'Under Construction',
        imageUrl: 'https://example.com/under_construction.jpg',
      ),
      SpotifyPlaylistTrack(
        title: "'Till I Collapse",
        artist: 'Eminem, Nate Dogg',
        spotifyUri: 'spotify:track:mock_till_collapse',
        durationMs: 297000,
        albumName: 'The Eminem Show',
        imageUrl: 'https://example.com/eminem_show.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Jump Around',
        artist: 'House of Pain',
        spotifyUri: 'spotify:track:mock_jump_around',
        durationMs: 215000,
        albumName: 'House of Pain',
        imageUrl: 'https://example.com/house_pain.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Pump It',
        artist: 'The Black Eyed Peas',
        spotifyUri: 'spotify:track:mock_pump_it',
        durationMs: 213000,
        albumName: 'Monkey Business',
        imageUrl: 'https://example.com/monkey_business.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Thunderstruck',
        artist: 'AC/DC',
        spotifyUri: 'spotify:track:mock_thunderstruck',
        durationMs: 292000,
        albumName: 'The Razors Edge',
        imageUrl: 'https://example.com/razors_edge.jpg',
      ),
    ],
    'mock_pl_5': [
      SpotifyPlaylistTrack(
        title: 'Midnight City',
        artist: 'M83',
        spotifyUri: 'spotify:track:mock_midnight_city',
        durationMs: 243000,
        albumName: 'Hurry Up, We\'re Dreaming',
        imageUrl: 'https://example.com/hurry_up.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'On Melancholy Hill',
        artist: 'Gorillaz',
        spotifyUri: 'spotify:track:mock_melancholy_hill',
        durationMs: 234000,
        albumName: 'Plastic Beach',
        imageUrl: 'https://example.com/plastic_beach.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Electric Feel',
        artist: 'MGMT',
        spotifyUri: 'spotify:track:mock_electric_feel',
        durationMs: 229000,
        albumName: 'Oracular Spectacular',
        imageUrl: 'https://example.com/oracular.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Stolen Dance',
        artist: 'Milky Chance',
        spotifyUri: 'spotify:track:mock_stolen_dance',
        durationMs: 312000,
        albumName: 'Sadnecessary',
        imageUrl: 'https://example.com/sadnecessary.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Intro',
        artist: 'The xx',
        spotifyUri: 'spotify:track:mock_intro_xx',
        durationMs: 128000,
        albumName: 'xx',
        imageUrl: 'https://example.com/xx.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Breathe',
        artist: 'Telepopmusik',
        spotifyUri: 'spotify:track:mock_breathe',
        durationMs: 279000,
        albumName: 'Genetic World',
        imageUrl: 'https://example.com/genetic_world.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Daylight',
        artist: 'Matt and Kim',
        spotifyUri: 'spotify:track:mock_daylight',
        durationMs: 178000,
        albumName: 'Grand',
        imageUrl: 'https://example.com/grand.jpg',
      ),
      SpotifyPlaylistTrack(
        title: 'Tongue Tied',
        artist: 'Grouplove',
        spotifyUri: 'spotify:track:mock_tongue_tied',
        durationMs: 200000,
        albumName: 'Never Trust a Happy Song',
        imageUrl: 'https://example.com/never_trust.jpg',
      ),
    ],
  };

  /// Default tracks returned for unknown playlist IDs.
  static const _defaultTracks = <SpotifyPlaylistTrack>[
    SpotifyPlaylistTrack(
      title: 'Stronger',
      artist: 'Kanye West',
      spotifyUri: 'spotify:track:mock_stronger_default',
      durationMs: 311000,
      albumName: 'Graduation',
    ),
    SpotifyPlaylistTrack(
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      spotifyUri: 'spotify:track:mock_blinding_default',
      durationMs: 200000,
      albumName: 'After Hours',
    ),
    SpotifyPlaylistTrack(
      title: 'Levitating',
      artist: 'Dua Lipa',
      spotifyUri: 'spotify:track:mock_levitating_default',
      durationMs: 203000,
      albumName: 'Future Nostalgia',
    ),
    SpotifyPlaylistTrack(
      title: 'Lose Yourself',
      artist: 'Eminem',
      spotifyUri: 'spotify:track:mock_lose_default',
      durationMs: 326000,
      albumName: '8 Mile Soundtrack',
    ),
    SpotifyPlaylistTrack(
      title: 'Runaway Baby',
      artist: 'Bruno Mars',
      spotifyUri: 'spotify:track:mock_runaway_baby',
      durationMs: 163000,
      albumName: 'Doo-Wops & Hooligans',
    ),
  ];
}
