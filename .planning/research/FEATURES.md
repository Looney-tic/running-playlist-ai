# Feature Landscape

**Domain:** Running playlist / BPM-matching apps
**Researched:** 2026-02-01
**Overall confidence:** MEDIUM — based on web research of competitor apps; Spotify API deprecation details verified across multiple sources

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| BPM-to-cadence matching | Core value prop of every app in this space. RockMyRun, Weav, PaceDJ, Running Beats all do this. | Med | Spotify deprecated audio-features API (Nov 2024). Must use alternative BPM source (ReccoBeats, AcousticBrainz, or own detection). This is the single biggest technical risk. |
| Pace/cadence input | Every competitor lets users set target BPM manually. PaceDJ has tap-to-measure. | Low | Support both manual entry (target pace -> calculated cadence) and direct BPM input. |
| Genre/taste preferences | RockMyRun filters by genre, mood, activity. Running Beats uses existing Spotify playlists as taste signal. | Low | Your approach (Spotify import + fine-tuning) is stronger than most competitors. |
| Playlist export to Spotify | Running Beats and similar tools push playlists to Spotify. Users expect to play via Spotify, not a custom player. | Low | Spotify Web API playlist creation endpoints still work fine. |
| Warm-up / cool-down support | RockMyRun stations "build in BPM." Weav has workout structure. PaceDJ has interval templates. | Med | Need playlist segments with ascending/descending BPM. Depends on having enough songs at each BPM range. |
| Multiple run types | Steady pace, intervals, progressive — PaceDJ and Weav both support structured workouts. | Med | Interval training requires segment-based playlist generation with distinct BPM targets per segment. |
| Cross-platform access | Web + mobile is baseline expectation for modern apps. | Med | Flutter covers this. Web is important since playlist generation doesn't require device sensors. |

## Differentiators

Features that set the product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Run-detail-driven generation** (distance + pace + type -> playlist) | No competitor takes full run parameters and generates a complete playlist. RockMyRun reacts in real-time; PaceDJ filters existing library. Your approach of pre-generating a structured playlist from run details is unique. | Med | This is your core differentiator. Lean into it. |
| **Taste profile from Spotify import + manual tuning** | Running Beats uses raw Spotify playlists. RockMyRun has its own library. Nobody combines Spotify listening history analysis with manual taste refinement for running-specific playlists. | Med | Spotify API still provides top tracks, saved tracks, playlist contents. Use these as taste signals since audio-features is gone. |
| **Stride rate calculation from pace + distance** | Most apps require users to know their cadence. Calculating it from pace/distance (which runners actually know) removes friction. | Low | Simple biomechanics formula. Low complexity, high UX value. |
| **BPM range tolerance with half/double tempo** | PaceDJ supports half/double tempo matching (a 170 BPM target can use 85 BPM songs). This dramatically expands available song pool. | Low | Important for less common cadences. Should be table stakes for you. |
| **Pre-run playlist generation** (not real-time) | RockMyRun and Weav require the app running during your workout. Pre-generating a Spotify playlist means users can run with any player/watch. | Low | Major UX advantage: works with any Spotify client, Apple Watch, Garmin, etc. No battery drain from your app during run. |
| **Interval training with BPM-matched segments** | PaceDJ has basic interval support. Your approach can generate playlists where songs match each interval's target effort/pace. | High | Requires mapping interval structure to BPM segments and finding songs that fit each segment duration. |

## Anti-Features

Features to deliberately NOT build. Common mistakes in this domain.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Built-in music player** | RockMyRun built their own player and it locks users into their ecosystem. Massive engineering cost. Users want Spotify. | Push playlists to Spotify. Let Spotify handle playback. |
| **Real-time cadence detection during runs** | Weav and RockMyRun do this but it requires foreground app, accelerometer access, battery drain. Complex cross-platform sensor work. | Pre-generate playlists before the run. The playlist IS the pacing tool. |
| **Own music library / DJ mixes** | RockMyRun licenses DJ mixes. Enormous cost, licensing complexity, limited catalog. | Use Spotify's catalog via API. Users get music they already love. |
| **Heart rate integration** | RockMyRun supports HR-based tempo. Requires Bluetooth sensor pairing, real-time processing, health data permissions. | Cadence/pace is sufficient. HR adds complexity without proportional value for playlist generation. |
| **Social features / sharing** | RockMyRun added "shared earbuds." Low engagement, high complexity. | Keep it single-player. Share via Spotify's built-in sharing. |
| **GPS run tracking** | RockMyRun and Weav include run tracking. Strava/Nike Run Club already do this well. | Integrate with Strava/Apple Health via links, don't rebuild tracking. |
| **Real-time tempo manipulation of audio** | Weav's core tech (100-240 BPM adaptive playback). Patent-protected, extremely complex audio DSP. | Match songs at their native BPM. A song at 172 BPM works fine for a 170 BPM target (+/- tolerance). |

## Feature Dependencies

```
Spotify Auth -> Taste Profile Import -> Playlist Generation -> Spotify Playlist Export
                                              ^
                                              |
                                     BPM Data Source (external API or database)
                                              ^
                                              |
Run Input (distance, pace, type) -> Cadence Calculation -> BPM Target(s)
                                              |
                                    Interval/Structure Definition
                                              |
                                    Segment-based BPM Targets
```

Key dependency chain:
- `Spotify OAuth` is prerequisite for everything (taste import + playlist export)
- `BPM data source` is the critical technical dependency — without reliable BPM data for Spotify tracks, the core product doesn't work
- `Cadence calculation` from run parameters is simple math, no external dependency
- `Taste profile` depends on Spotify auth but can start simple (use top tracks) and add sophistication later
- `Interval training` depends on basic steady-pace generation working first

## MVP Recommendation

For MVP, prioritize:
1. **Spotify auth + basic taste import** (top tracks, saved tracks) — table stakes foundation
2. **BPM data pipeline** — solve the hardest technical problem first. Evaluate ReccoBeats API, AcousticBrainz, or build a BPM lookup/cache layer. This is existential.
3. **Steady-pace playlist generation** — distance + pace -> cadence -> BPM-matched playlist from user's taste profile
4. **Spotify playlist export** — push generated playlist to user's Spotify account
5. **Warm-up/cool-down** — first structural feature, natural extension of steady pace

Defer to post-MVP:
- **Interval training:** High complexity, requires segment-based generation and good UX for defining intervals
- **Advanced taste tuning:** Manual fine-tuning of taste profile (start with Spotify-derived taste, add tuning later)
- **Half/double tempo matching:** Nice to have, expands song pool, but not required for v1

## Critical Technical Risk

**The Spotify audio-features API deprecation (Nov 2024) is the #1 risk for this project.** Every BPM-matching app in this space either (a) had pre-existing API access grandfathered in, (b) uses its own music library, or (c) is broken/degraded. Your app needs a reliable BPM source for Spotify tracks. Options:

1. **ReccoBeats API** — free, claims to replicate Spotify audio features. MEDIUM confidence (single source, unverified reliability at scale).
2. **AcousticBrainz / MusicBrainz** — open data, but requires mapping Spotify track IDs to MusicBrainz IDs. Coverage may be incomplete.
3. **Build/buy a BPM database** — pre-computed BPM data from datasets or audio analysis. Most reliable but highest effort.
4. **Client-side BPM detection** — analyze Spotify preview clips (30s) using Web Audio API. Feasible but adds latency and may be inaccurate.

**Recommendation:** Start with ReccoBeats as primary, AcousticBrainz as fallback, and cache all BPM data aggressively. Validate coverage against real Spotify libraries early.

## Sources

- [RockMyRun official site](https://www.rockmyrun.com/) — Body-Driven Music, DJ mixes, genre filtering
- [RockMyRun myBeat feature](https://www.rockmyrun.com/myBeat.php) — real-time step/HR matching
- [Weav Run on Product Hunt](https://www.producthunt.com/products/weav-run) — adaptive music technology
- [Weav Music voice coaching announcement](https://musically.com/2020/07/01/weav-music-adds-voice-coaching-to-adaptive-music-running-app/)
- [PaceDJ App Store listing](https://apps.apple.com/us/app/pacedj-bpm-running-music/id446225183) — local file BPM scanning, interval workouts
- [PaceDJ official site FAQ](https://www.pacedj.com/faq/) — half/double tempo, BPM shifting
- [Running Beats developer page](https://adriaanpardoel.com/projects/running-beats) — Spotify playlist generation for running
- [Spotify Running feature retirement](https://community.spotify.com/t5/iOS-iPhone-iPad/Where-is-the-Spotify-Running-option-for-playlist-based-on/td-p/1244891)
- [Spotify API deprecation details](https://medium.com/@soundnet717/spotify-audio-analysis-has-been-deprecated-what-now-4808aadccfcb) — audio-features and audio-analysis endpoints deprecated Nov 2024
- [Spotify API restriction analysis (2026)](https://voclr.it/news/why-spotify-has-restricted-its-api-access-what-changed-and-why-it-matters-in-2026/)
- [TrailMix App Store listing](https://apps.apple.com/us/app/trailmix-step-to-the-beat/id647651691) — cadence tracker + music player (iOS only)
- [Drmare: Spotify Running alternatives](https://www.drmare.com/spotify-music/spotify-running-alternative.html) — comparison of BPM apps
- [ReccoBeats as Spotify alternative](https://community.spotify.com/t5/Spotify-for-Developers/Finding-BPMs-of-songs/td-p/6569820) — community discussion
