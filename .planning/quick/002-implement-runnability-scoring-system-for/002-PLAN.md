---
phase: quick-002
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - tools/enrich_runnability.py
  - assets/curated_songs.json
  - lib/features/curated_songs/domain/curated_song.dart
  - lib/features/bpm_lookup/domain/bpm_song.dart
  - lib/features/song_quality/domain/song_quality_scorer.dart
  - lib/features/playlist/domain/playlist_generator.dart
  - lib/features/playlist/providers/playlist_providers.dart
  - test/features/song_quality/domain/song_quality_scorer_test.dart
autonomous: true

must_haves:
  truths:
    - "Every song in curated_songs.json has a runnability score (0-100)"
    - "Songs with high crowd signal (source_count >= 10) get runnability >= 80"
    - "Songs without crowd data get feature-estimated runnability from genre + danceability + BPM"
    - "SongQualityScorer uses runnability as a scoring dimension replacing curated bonus + genre runnability"
    - "All existing tests pass, new runnability tests pass"
  artifacts:
    - path: "tools/enrich_runnability.py"
      provides: "Python script computing runnability for all curated songs"
    - path: "assets/curated_songs.json"
      provides: "Curated songs with runnability field"
      contains: "runnability"
    - path: "lib/features/song_quality/domain/song_quality_scorer.dart"
      provides: "Runnability scoring dimension"
      contains: "_runnabilityScore"
    - path: "test/features/song_quality/domain/song_quality_scorer_test.dart"
      provides: "Runnability scoring tests"
      contains: "Runnability"
  key_links:
    - from: "tools/enrich_runnability.py"
      to: "assets/curated_songs.json"
      via: "reads extracted_songs.json crowd data, writes runnability to curated_songs"
    - from: "lib/features/curated_songs/domain/curated_song.dart"
      to: "lib/features/bpm_lookup/domain/bpm_song.dart"
      via: "runnability field flows CuratedSong -> BpmSong"
    - from: "lib/features/playlist/domain/playlist_generator.dart"
      to: "lib/features/song_quality/domain/song_quality_scorer.dart"
      via: "passes song.runnability to scorer"
---

<objective>
Implement a runnability scoring system (0-100) for all curated songs, combining crowd signal data (source_count from 2,611 extracted running playlist songs) with feature-based estimation (genre, danceability, BPM), then integrate this as a primary quality signal in SongQualityScorer.

Purpose: Replace the coarse curated bonus (+5 flat) and genre runnability tiers (0-6) with a single, data-driven runnability dimension that captures both crowd wisdom and audio features. This makes playlist quality scoring significantly more nuanced -- a song recommended by 40 running playlists scores much higher than one from 2.

Output: All 5,066 curated songs enriched with runnability scores, scorer updated with new dimension, tests passing.
</objective>

<execution_context>
@/Users/tijmen/.claude/get-shit-done/workflows/execute-plan.md
@/Users/tijmen/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@lib/features/song_quality/domain/song_quality_scorer.dart
@lib/features/curated_songs/domain/curated_song.dart
@lib/features/bpm_lookup/domain/bpm_song.dart
@lib/features/playlist/domain/playlist_generator.dart
@lib/features/playlist/providers/playlist_providers.dart
@test/features/song_quality/domain/song_quality_scorer_test.dart
@test/features/playlist/domain/playlist_generator_test.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Compute runnability scores and enrich curated_songs.json</name>
  <files>
    tools/enrich_runnability.py
    assets/curated_songs.json
  </files>
  <action>
Create `tools/enrich_runnability.py` that computes a runnability score (0-100) for every song in `assets/curated_songs.json`.

**Data sources:**
1. Crowd signal: Load `/private/tmp/claude-501/-Users-tijmen-running-playlist-ai/d4738303-92e4-4aa7-a132-232dbf10fcb2/scratchpad/extracted_songs.json` which has 2,611 songs with `{title, artistName, genre, source_count}` format. Build a lookup map by `artist.lower().strip()|title.lower().strip()`.
2. Feature data: Each curated song already has `genre`, `danceability` (0-100, nullable), and `bpm` (nullable).

**Runnability formula (0-100):**

For songs WITH crowd data (matched by lookup key):
- `crowd_score = min(source_count / 15.0, 1.0) * 60` (0-60 points, saturates at 15 sources)
  - This means: 1 source = 4pts, 5 sources = 20pts, 10 sources = 40pts, 15+ sources = 60pts
- `feature_score` = genre_bonus + danceability_bonus + bpm_bonus (0-40 points, same as below but capped at 40)
- `runnability = round(crowd_score + feature_score)`

For songs WITHOUT crowd data (feature-only estimation):
- `genre_bonus` (0-20): Map genres to running suitability:
  - electronic/edm/house/drumAndBass: 20
  - pop/dance/kPop/hipHop: 16
  - rock/punk/latin/funk: 13
  - indie/rnb/metal: 10
  - unknown/other: 8
- `danceability_bonus` (0-12): `min(danceability / 100.0, 1.0) * 12` if available, else 6 (neutral)
- `bpm_bonus` (0-8): Based on running BPM research:
  - 120-149 BPM (prime running zone): 8
  - 150-179 BPM (fast running): 7
  - 90-119 BPM (could be double-time): 5
  - 80-89 BPM (half-time sweet spot): 4
  - else: 2
  - null BPM: 4 (neutral)
- `runnability = round(genre_bonus + danceability_bonus + bpm_bonus)` (max 40, meaning feature-only songs cap at 40)

KEY INSIGHT from research: Do NOT over-weight danceability. The crowd data shows top running songs actually have LOWER danceability (avg 58) than less-recommended ones (avg 65). Motivational quality and cultural association matter as much as rhythm. The formula above correctly handles this by making crowd signal dominant (60%) and keeping danceability as just one of three feature components.

**Script behavior:**
1. Load both JSON files
2. Build crowd lookup map (normalize keys: `artist.lower().strip()|title.lower().strip()`)
3. For each curated song, compute runnability using the formula above
4. Add `"runnability": N` field to each song in curated_songs.json
5. Write back to `assets/curated_songs.json` preserving existing field order (runnability goes after danceability)
6. Print summary stats: total songs, songs with crowd match, avg runnability, distribution histogram

Run: `python3 tools/enrich_runnability.py`

Verify the output looks sensible:
- "Lose Yourself" (Eminem, 40 sources) should get runnability ~90+
- "Eye of the Tiger" (Survivor, 36 sources) should get runnability ~90+
- A random song with 1-2 sources should get runnability ~30-50
- Songs without crowd data should get runnability ~15-40 depending on features
  </action>
  <verify>
Run `python3 tools/enrich_runnability.py` and confirm:
- Script completes without error
- Every song in curated_songs.json now has a `runnability` field (integer 0-100)
- Spot-check: `python3 -c "import json; d=json.load(open('assets/curated_songs.json')); print(len([s for s in d if 'runnability' in s]), '/', len(d)); print('Lose Yourself:', [s['runnability'] for s in d if s['title']=='Lose Yourself'])"` shows all songs have runnability and Lose Yourself scores high
  </verify>
  <done>All 5,066 songs in curated_songs.json have integer runnability scores. Songs with strong crowd signal score highest (80-100), feature-only songs score moderately (15-40).</done>
</task>

<task type="auto">
  <name>Task 2: Add runnability field to domain models and integrate into scorer</name>
  <files>
    lib/features/curated_songs/domain/curated_song.dart
    lib/features/bpm_lookup/domain/bpm_song.dart
    lib/features/song_quality/domain/song_quality_scorer.dart
    lib/features/playlist/domain/playlist_generator.dart
    lib/features/playlist/providers/playlist_providers.dart
    test/features/song_quality/domain/song_quality_scorer_test.dart
    test/features/playlist/domain/playlist_generator_test.dart
  </files>
  <action>
**Step 1: Add `runnability` field to CuratedSong** (`curated_song.dart`):
- Add `final int? runnability;` field
- Add to constructor: `this.runnability`
- Add to `fromJson`: `runnability: (json['runnability'] as num?)?.toInt()`
- Add to `fromSupabaseRow`: `runnability: (row['runnability'] as num?)?.toInt()`
- Add to `toJson`: `if (runnability != null) 'runnability': runnability`

**Step 2: Add `runnability` field to BpmSong** (`bpm_song.dart`):
- Add `final int? runnability;` field
- Add to constructor: `this.runnability`
- Add to `fromJson`: `runnability: (json['runnability'] as num?)?.toInt()`
- Add to `toJson`: `if (runnability != null) 'runnability': runnability`
- Add to `withMatchType`: include `runnability: runnability`
- Do NOT add to `fromApiJson` (API does not provide runnability)

**Step 3: Update playlist_providers.dart** `_buildSongsFromCurated`:
- In the BpmSong constructor call inside `_buildSongsFromCurated`, add: `runnability: song.runnability`
- This ensures runnability flows from curated dataset through to the scorer when using offline/curated fallback

**Step 4: Redesign SongQualityScorer** (`song_quality_scorer.dart`):
Replace the `curatedBonusWeight` (+5 flat) and `genreRunnabilityMaxWeight` (0-6 tiers) dimensions with a single `runnability` dimension.

New scoring dimensions (9 dimensions, new max = 46):
1. Artist match: +10 (unchanged)
2. **Runnability: +0..15** (NEW - replaces curated bonus +5 and genre runnability 0-6, combined weight = 11 -> increased to 15 because this is now data-driven and more meaningful)
3. Danceability: +0..8 (unchanged)
4. Genre match: +6 (unchanged)
5. Decade match: +4 (unchanged)
6. BPM match: +1..3 (unchanged)
7. Artist diversity: -5 (unchanged)
8. Disliked artist: -15 (unchanged)

Changes to make:
- Remove `curatedBonusWeight` constant (was 5)
- Remove `genreRunnabilityMaxWeight` constant (was 6)
- Remove `genreRunnabilityNeutral` constant (was 2)
- Add `runnabilityMaxWeight = 15` constant
- Add `runnabilityNeutral = 5` constant (for songs without runnability data - slightly generous neutral)
- Remove `_curatedBonus` method
- Remove `_genreRunnabilityScore` method
- Remove `_genreRunnabilityMap` constant
- Add `_runnabilityScore(int? runnability)` method:
  ```dart
  static int _runnabilityScore(int? runnability) {
    if (runnability == null) return runnabilityNeutral;
    // Scale 0-100 runnability to 0-15 scoring points
    if (runnability >= 80) return runnabilityMaxWeight; // 15
    if (runnability >= 60) return 12;
    if (runnability >= 40) return 9;
    if (runnability >= 25) return 6;
    if (runnability >= 10) return 3;
    return 0;
  }
  ```
- Update `score()` method:
  - Remove `isCurated` parameter
  - Add `int? runnability` parameter
  - Remove call to `_curatedBonus(isCurated)`
  - Remove call to `_genreRunnabilityScore(songGenres)`
  - Add call to `_runnabilityScore(runnability)`
- Update doc comments: total max is now artist(10) + runnability(15) + dance(8) + genre(6) + decade(4) + exact(3) = 46

**Step 5: Update PlaylistGenerator** (`playlist_generator.dart`):
- In `_scoreAndRank`, update the `SongQualityScorer.score()` call:
  - Remove `isCurated: isCurated` parameter
  - Add `runnability: song.runnability` parameter
  - Keep the `isCurated` local variable computation but use it to set runnability:
    Actually, rethink this. The runnability is now baked into the song data from curated_songs.json. For curated songs accessed offline, `song.runnability` will be populated. For API-sourced songs, it will be null (neutral score). The `isCurated` check is no longer needed for scoring but we still need it to LOOK UP runnability.
  - Actually the cleanest approach: Keep `curatedLookupKeys` but instead of a boolean isCurated flag, look up the runnability value. BUT the current curatedLookupKeys is just a Set<String>, not a map. We need a Map<String, int> for runnability lookup.

  **Revised approach for runnability lookup in generator:**
  - The `curatedLookupKeys` parameter in `PlaylistGenerator.generate()` needs to change from `Set<String>?` to `Map<String, int>?` named `curatedRunnability` -- mapping lookup keys to runnability scores.
  - In `_scoreAndRank`, look up the song's runnability: `final runnability = curatedRunnability?[lookupKey]` where lookupKey = `'${song.artistName.toLowerCase().trim()}|${song.title.toLowerCase().trim()}'`
  - Pass runnability (which will be null for non-curated songs) to `SongQualityScorer.score(runnability: runnability)`
  - For API-sourced songs with no curated match: `runnability` will be null, scorer gives neutral 5 points
  - For API-sourced songs that happen to also be in curated dataset: their runnability will be looked up and applied

**Step 6: Update curatedLookupKeysProvider** and provider wiring:
- In `curated_song_providers.dart`: Change `curatedLookupKeysProvider` from `FutureProvider<Set<String>>` to `FutureProvider<Map<String, int>>`. Build a map of lookupKey -> runnability:
  ```dart
  final curatedRunnabilityProvider = FutureProvider<Map<String, int>>((ref) async {
    final songs = await CuratedSongRepository.loadCuratedSongs();
    return {
      for (final s in songs)
        s.lookupKey: s.runnability ?? 20, // default 20 for songs without runnability
    };
  });
  ```
  Keep the old name but rename it to `curatedRunnabilityProvider` for clarity.

- In `playlist_providers.dart`: Update both `generatePlaylist()` and `regeneratePlaylist()`:
  - Change `curatedLookupKeys` variable to `curatedRunnability` of type `Map<String, int>`
  - Read from `curatedRunnabilityProvider` instead of `curatedLookupKeysProvider`
  - Pass `curatedRunnability: curatedRunnability.isNotEmpty ? curatedRunnability : null` to generator

**Step 7: Update tests** (`song_quality_scorer_test.dart`):
- Update the `_song` helper to accept `int? runnability` parameter (not needed -- runnability is passed separately to score())
- Remove all `isCurated` references from test calls, replace with `runnability` parameter
- Update "Curated bonus" test group -> rename to "Runnability scoring":
  - Test high runnability (>=80) adds +15
  - Test good runnability (60-79) adds +12
  - Test moderate runnability (40-59) adds +9
  - Test low runnability (25-39) adds +6
  - Test very low runnability (10-24) adds +3
  - Test null runnability adds neutral +5
  - Test runnabilityMaxWeight constant is 15
  - Test runnabilityNeutral constant is 5
- Update "Genre runnability scoring" group -> REMOVE entire group (genre runnability is now folded into runnability)
- Update composite scoring tests:
  - Best case: artist(10) + runnability(15) + dance(8) + genre(6) + decade(4) + exact(3) = 46
  - Worst case: recalculate with new dimensions
  - Graceful degradation (all nulls): exact(3) + danceability neutral(3) + runnability neutral(5) = 11
- Remove `genreRunnabilityMaxWeight` and `genreRunnabilityNeutral` constant tests
- Remove `curatedBonusWeight` constant test

Also update `playlist_generator_test.dart`:
- Update "curated songs rank higher" test: Change `curatedLookupKeys` to `curatedRunnability` (Map<String, int>), e.g. `curatedRunnability: {'artist b|curated song': 85}`
- Update "empty curatedLookupKeys" test: Use empty map and null map
  </action>
  <verify>
Run `cd /Users/tijmen/running-playlist-ai && flutter test test/features/song_quality/domain/song_quality_scorer_test.dart test/features/playlist/domain/playlist_generator_test.dart` and confirm all tests pass.
Run `flutter analyze --no-fatal-infos` and confirm no errors (warnings OK).
  </verify>
  <done>
Runnability field flows through domain models (CuratedSong -> BpmSong -> SongQualityScorer). Scorer uses runnability (0-15 points) as a primary quality signal replacing curated bonus and genre runnability tiers. All tests updated and passing. Max composite score is now 46 (was 42).
  </done>
</task>

</tasks>

<verification>
1. `python3 tools/enrich_runnability.py` runs without errors and all songs have runnability
2. `flutter test test/features/song_quality/domain/song_quality_scorer_test.dart` passes
3. `flutter test test/features/playlist/domain/playlist_generator_test.dart` passes
4. `flutter analyze --no-fatal-infos` shows no errors
5. Spot-check: "Lose Yourself" runnability >= 90, "Eye of the Tiger" runnability >= 90
6. Spot-check: Scorer gives 15 points for song with runnability >= 80, 5 points for null runnability
</verification>

<success_criteria>
- All 5,066 curated songs have integer runnability scores (0-100)
- Crowd-sourced songs dominate the top of the runnability distribution (top songs 80-100)
- Feature-only songs get moderate runnability (15-40 range)
- SongQualityScorer uses runnability as a 0-15 point dimension
- Old curated bonus (+5) and genre runnability tiers (0-6) are removed
- New max composite score is 46
- All existing test suites pass with updated assertions
- No Flutter analyze errors
</success_criteria>

<output>
After completion, create `.planning/quick/002-implement-runnability-scoring-system-for/002-SUMMARY.md`
</output>
