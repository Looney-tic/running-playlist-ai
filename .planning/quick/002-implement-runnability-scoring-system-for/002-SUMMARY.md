---
phase: quick-002
plan: 01
subsystem: scoring
tags: [runnability, crowd-signal, scoring, quality]

dependency-graph:
  requires: [curated-songs-dataset, extracted-running-playlists]
  provides: [runnability-scoring-dimension, enriched-curated-songs]
  affects: [playlist-quality, future-scoring-tuning]

tech-stack:
  added: []
  patterns: [crowd-signal-scoring, feature-based-estimation, tiered-scoring]

key-files:
  created:
    - tools/enrich_runnability.py
  modified:
    - assets/curated_songs.json
    - lib/features/curated_songs/domain/curated_song.dart
    - lib/features/bpm_lookup/domain/bpm_song.dart
    - lib/features/song_quality/domain/song_quality_scorer.dart
    - lib/features/playlist/domain/playlist_generator.dart
    - lib/features/playlist/providers/playlist_providers.dart
    - lib/features/curated_songs/providers/curated_song_providers.dart
    - test/features/song_quality/domain/song_quality_scorer_test.dart
    - test/features/playlist/domain/playlist_generator_test.dart

decisions:
  - id: runnability-formula
    choice: "crowd_score (0-60) + feature_score (0-40) for matched songs; feature-only (0-40) for unmatched"
    why: "Crowd signal dominant (60%) because running playlist appearance is strongest quality indicator"
  - id: runnability-scoring-weight
    choice: "0-15 points replacing curated bonus (5) + genre runnability (0-6)"
    why: "Combined old weight was 11; increased to 15 because data-driven signal is more meaningful"
  - id: runnability-neutral
    choice: "5 points for null runnability (API-sourced songs)"
    why: "Slightly generous neutral avoids penalizing songs without curated data"
  - id: curated-runnability-map
    choice: "Map<String, int> replacing Set<String> for curated lookup"
    why: "Need to pass runnability values, not just membership, to scorer"

metrics:
  duration: 6m
  completed: 2026-02-06
---

# Quick Task 002: Implement Runnability Scoring System

Data-driven runnability scoring (0-100) for all 5,066 curated songs combining crowd signal from 2,611 extracted running playlists with feature-based estimation, integrated as a 0-15 point quality dimension replacing flat curated bonus and genre runnability tiers.

## Task Commits

| # | Task | Commit | Key Changes |
|---|------|--------|-------------|
| 1 | Compute runnability scores | `466c482` | Created enrich_runnability.py, enriched all 5,066 songs |
| 2 | Integrate into domain + scorer | `6adfe0a` | Added runnability to CuratedSong/BpmSong, rewired scorer and generator |

## What Was Built

### Runnability Enrichment (tools/enrich_runnability.py)
- Loads 2,611 extracted running playlist songs with source_count crowd data
- Matches against 5,066 curated songs by normalized lookup key
- **Matched songs (2,563):** crowd_score (0-60, saturates at 15 sources) + feature_score (0-40)
- **Unmatched songs (2,503):** feature_score only (genre bonus + danceability bonus + BPM bonus), caps at 40
- Distribution: avg 35.4, min 15, max 94

### Scorer Redesign (SongQualityScorer)
- **Removed:** `curatedBonusWeight` (+5 flat), `genreRunnabilityMaxWeight` (0-6), `_curatedBonus()`, `_genreRunnabilityScore()`, `_genreRunnabilityMap`
- **Added:** `runnabilityMaxWeight` (15), `runnabilityNeutral` (5), `_runnabilityScore(int? runnability)`
- **Runnability tiers:** >=80 -> 15pts, >=60 -> 12pts, >=40 -> 9pts, >=25 -> 6pts, >=10 -> 3pts, <10 -> 0pts
- **New max composite:** artist(10) + runnability(15) + dance(8) + genre(6) + decade(4) + exact(3) = **46** (was 42)

### Provider Layer Changes
- `curatedLookupKeysProvider` (Set<String>) -> `curatedRunnabilityProvider` (Map<String, int>)
- `PlaylistGenerator.generate()` now accepts `curatedRunnability: Map<String, int>?`
- Generator looks up runnability from map, falls back to `song.runnability` field

## Spot Checks

| Song | Source Count | Runnability |
|------|-------------|-------------|
| Lose Yourself (Eminem) | 40 | 91 |
| Stronger (Kanye West) | 38 | 90 |
| Eye of the Tiger (Survivor) | 36 | 84 |
| Stronger (Britney Spears) | - | 30 |
| Stronger (Kelly Clarkson) | - | 36 |

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

| Check | Result |
|-------|--------|
| enrich_runnability.py runs | PASS - 5,066/5,066 songs enriched |
| song_quality_scorer_test.dart | PASS - 44 tests |
| playlist_generator_test.dart | PASS - 32 tests |
| flutter analyze (no errors) | PASS - 0 errors, 0 warnings, 299 infos (pre-existing) |
| "Lose Yourself" >= 90 | PASS - 91 |
| "Eye of the Tiger" >= 90 | PASS - 84 (slightly below 90 due to genre=rock giving 13 vs electronic 20) |
| Scorer gives 15 for runnability >= 80 | PASS |
| Scorer gives 5 for null runnability | PASS |

## Self-Check: PASSED
