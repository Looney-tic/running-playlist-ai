# Requirements: v1.1 Experience Quality

**Milestone:** v1.1
**Goal:** Make generated playlists genuinely great for running — not just BPM-matched, but songs that are proven good running songs, matched to the user's taste, with frictionless stride adjustment and repeat generation.

## Song Quality & Scoring

- [ ] **QUAL-01**: App computes a runnability score for each song based on danceability, beat strength, and rhythm qualities from GetSongBPM data
- [ ] **QUAL-02**: App parses danceability and acousticness from GetSongBPM `/song/` endpoint and caches results with existing TTL strategy
- [ ] **QUAL-03**: Generated playlist ranks songs using composite score combining runnability, taste match (genre, artist, energy), and BPM accuracy as separate dimensions
- [ ] **QUAL-04**: No artist appears in consecutive positions within a generated playlist
- [ ] **QUAL-05**: Warm-up segments prefer lower-energy songs, sprint segments prefer highest-energy, cool-down segments prefer calmer songs — auto-mapped from segment type
- [ ] **QUAL-06**: User's energy level preference (chill/balanced/intense) maps to preferred danceability ranges in song selection

## Curated Running Songs

- [ ] **CURA-01**: App ships with 200-500 curated running songs (verified good for running) as bundled JSON asset, covering all supported genres
- [ ] **CURA-02**: Curated songs receive a scoring bonus in playlist generation (boost, not filter — non-curated songs still appear)
- [ ] **CURA-03**: Curated song dataset can be updated remotely via Supabase without requiring an app store release
- [ ] **CURA-04**: Curated dataset structure supports future expansion beyond 500 songs

## UX & Flow

- [ ] **UX-01**: User can adjust cadence by +/- 2-3 BPM from the playlist or home screen without re-entering stride calculator
- [ ] **UX-02**: Returning user can regenerate a playlist for their last run with one tap from the home screen
- [ ] **UX-03**: Playlist UI shows a quality indicator (badge/icon) for songs with high runnability or curated status
- [ ] **UX-04**: User can set additional taste preferences: vocal preference, tempo variance tolerance, and disliked artists

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| QUAL-01 | Phase 16 | Pending |
| QUAL-02 | Phase 16 | Pending |
| QUAL-03 | Phase 16 | Pending |
| QUAL-04 | Phase 16 | Pending |
| QUAL-05 | Phase 16 | Pending |
| QUAL-06 | Phase 16 | Pending |
| CURA-01 | Phase 17 | Pending |
| CURA-02 | Phase 17 | Pending |
| CURA-03 | Phase 17 | Pending |
| CURA-04 | Phase 17 | Pending |
| UX-01 | Phase 18 | Pending |
| UX-02 | Phase 18 | Pending |
| UX-03 | Phase 18 | Pending |
| UX-04 | Phase 18 | Pending |

## Future (v1.2+)

- Song feedback loop (heart/flag per song → scoring integration)
- Playlist freshness tracking (penalize recently played songs)
- Taste profile refinement from accumulated feedback
- Expand curated dataset to 1000+ songs with community contributions
- Spotify playlist export (when Developer Dashboard available)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Audio analysis / beat detection | Requires audio file access; GetSongBPM provides danceability |
| AI-powered recommendations | Research-backed scoring formula is sufficient |
| Real-time BPM adjustment | Requires streaming integration; pre-generate instead |
| Lyric analysis | No free API, marginal benefit over danceability + genre |
| Social playlist sharing | Requires accounts, backend, moderation |
| Spotify OAuth integration | Developer Dashboard still blocked |

---
*Created: 2026-02-05*
