# Milestones: Running Playlist AI

## Completed

### v1.2: Polish & Profiles (Shipped: 2026-02-06)

**Delivered:** Reliable playlist regeneration with readiness guards, safe multi-profile management with delete confirmation and corrupt-data resilience, and a 4-step onboarding flow guiding new users to their first generated playlist.

**Phases completed:** 19-21 (6 plans total)

**Key accomplishments:**
- Instant shuffle/regenerate with Completer-based ensureLoaded() readiness guards
- Safe enum deserialization with orElse fallbacks surviving corrupt JSON
- Delete confirmation dialogs + 8-test multi-profile lifecycle coverage
- 4-step onboarding flow guiding new users to their first playlist
- Context-aware home screen empty states adapting to profile/plan existence

**Stats:**
- 37 files created/modified
- +3,066/-154 lines changed
- ~7,618 LOC Dart (lib), ~5,830 LOC tests
- 3 phases, 6 plans
- 9 requirements delivered (100% coverage)

**Git range:** `feat(19-01)` -> `feat(21-02)`

**What's next:** TBD -- run `/gsd:new-milestone` to plan next milestone

---

### v1.1: Experience Quality (Shipped: 2026-02-06)

**Delivered:** Song quality scoring with 8-dimension runnability system, 5,066 curated running songs with metadata, extended taste profiling, cadence nudge controls, and one-tap regeneration from home screen.

**Phases completed:** 16-18 (6 plans total)

**Git range:** `feat(16-01)` -> `feat(18-02)`

---

### v1.0: Standalone Playlist Generator (Shipped: 2026-02-05)

**Delivered:** Full BPM-matched playlist generation from run plan input, with taste profiling, BPM discovery via GetSongBPM API, external play links, and playlist history -- all without Spotify integration.

**Phases completed:** 11-15 (10 plans total)

**Key accomplishments:**
- Removed Spotify auth gate, built home hub with navigation to all features
- Questionnaire-based taste profile (genres, artists, energy level) with SharedPreferences persistence
- GetSongBPM API integration with local cache (7-day TTL) and half/double-time BPM matching
- Playlist generation algorithm that scores songs by taste profile and assigns to run segments
- PlaylistScreen UI with 5-state pattern, external Spotify/YouTube links, clipboard copy
- Playlist history with auto-save, swipe-to-delete, and detail view with shared widgets

**Stats:**
- 70 files created/modified
- 4,282 lines of Dart (lib), 3,924 lines of test
- 5 phases, 10 plans
- 229 tests passing
- 18 requirements delivered (100% coverage)

**Git range:** `feat(11-01)` -> `feat(15-02)`

**What's next:** TBD -- run `/gsd:new-milestone` to plan next milestone

---

### v0.1: Foundation (Shipped: 2026-02-05)

**Goal:** Project skeleton with core domain logic for stride calculation and run planning.

**Delivered:**
- Flutter project scaffold (web, Android, iOS) with Riverpod, GoRouter, Supabase
- Stride calculator: pace -> cadence with height refinement and real-world calibration
- Run plan engine: steady, warm-up/cool-down, and interval plans with per-segment BPM targets
- Run plan UI with segment timeline visualization

**Phases completed:** 1 (Foundation), 5 (Stride), 6 (Steady Run), 8 (Structured Runs)
**Last phase number:** 10 (original roadmap had 10 phases)

**What didn't ship:**
- Spotify OAuth (blocked on Developer Dashboard)
- BPM data pipeline (depended on Spotify auth)
- Taste profile (depended on Spotify library import)
- Playlist generation (depended on above)

**Pivot decision:** Build without Spotify integration. Use GetSongBPM API for BPM data and questionnaire-based taste profile instead.

---
*Last updated: 2026-02-06*
