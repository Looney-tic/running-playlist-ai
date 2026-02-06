# Requirements: v1.3 Song Feedback & Freshness

**Defined:** 2026-02-06
**Core Value:** A runner opens the app, enters their run plan, and gets a playlist where every song's beat matches their footstrike cadence

## v1.3 Requirements

Requirements for v1.3 milestone. Each maps to roadmap phases.

### Song Feedback

- [ ] **FEED-01**: User can like or dislike any song in the generated playlist view via inline icons
- [ ] **FEED-02**: Song feedback persists across app restarts
- [ ] **FEED-03**: Disliked songs are hard-filtered from future playlist generation (never appear again)
- [ ] **FEED-04**: Liked songs receive a scoring boost in SongQualityScorer during playlist generation
- [ ] **FEED-05**: User can browse all liked and disliked songs in a dedicated feedback library screen
- [ ] **FEED-06**: User can change or remove feedback on any song from the feedback library
- [ ] **FEED-07**: User can review and rate songs from their most recent playlist in a post-run review screen

### Freshness

- [ ] **FRSH-01**: App tracks when each song last appeared in a generated playlist
- [ ] **FRSH-02**: Recently generated songs receive a time-decayed scoring penalty during playlist generation
- [ ] **FRSH-03**: User can toggle between "keep it fresh" mode (penalize recent songs) and "optimize for taste" mode (no freshness penalty)

### Taste Learning

- [ ] **LRNG-01**: App analyzes liked/disliked song patterns to detect implicit genre, artist, and BPM preferences
- [ ] **LRNG-02**: Learned preferences are surfaced as suggestions the user can accept or dismiss (not auto-applied)
- [ ] **LRNG-03**: Accepted taste suggestions update the user's active taste profile

## Future (v1.4+)

- Spotify OAuth + playlist export (when Developer Dashboard available)
- Apple Music integration via MusicKit
- Social playlist sharing
- Profile templates (pre-built profiles like "Chill Long Run", "HIIT Intervals")

## Out of Scope

| Feature | Reason |
|---------|--------|
| Auto-modify taste profile from feedback | Overfits, removes user agency; suggestion-based approach is better |
| ML-based recommendation engine | Single-user frequency counting outperforms ML at <4,000 data points |
| In-app music playback | External Spotify/YouTube links sufficient |
| Implicit feedback (play duration tracking) | Users don't listen in-app; can't measure listening behavior |
| Complex analytics dashboard | Premature; validate feedback loop with real users first |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FEED-01 | TBD | Pending |
| FEED-02 | TBD | Pending |
| FEED-03 | TBD | Pending |
| FEED-04 | TBD | Pending |
| FEED-05 | TBD | Pending |
| FEED-06 | TBD | Pending |
| FEED-07 | TBD | Pending |
| FRSH-01 | TBD | Pending |
| FRSH-02 | TBD | Pending |
| FRSH-03 | TBD | Pending |
| LRNG-01 | TBD | Pending |
| LRNG-02 | TBD | Pending |
| LRNG-03 | TBD | Pending |

**Coverage:**
- v1.3 requirements: 13 total
- Mapped to phases: 0
- Unmapped: 13

---
*Requirements defined: 2026-02-06*
*Last updated: 2026-02-06 after initial definition*
