# Requirements: v1.2 Polish & Profiles

**Defined:** 2026-02-06
**Core Value:** A runner opens the app, enters their run plan, and gets a playlist where every song's beat matches their footstrike cadence

## v1.2 Requirements

Requirements for v1.2 milestone. Each maps to roadmap phases.

### Regeneration Reliability

- [x] **REGEN-01**: Shuffle/regenerate reuses stored song pool with a new random seed — instant, no API re-fetch
- [x] **REGEN-02**: Playlist generation works reliably on cold start without null state crashes (race condition fix)
- [x] **REGEN-03**: When user changes run plan or taste profile via inline selector, next generate uses the updated selection

### Profile Polish

- [x] **PROF-01**: Deleting a taste profile shows a confirmation dialog before removal
- [x] **PROF-02**: All enum deserializers (RunningGenre, EnergyLevel, etc.) have orElse fallbacks to prevent crash on corrupt/unknown data
- [x] **PROF-03**: Multi-profile flows (create, edit, delete, switch, persist) verified with integration test coverage

### Onboarding

- [x] **ONBD-01**: First-run users see a guided flow: welcome → pick genres → set pace → auto-generate first playlist
- [x] **ONBD-02**: User can skip any onboarding step and proceed with sensible defaults
- [x] **ONBD-03**: Home screen adapts based on whether user has profiles and run plans configured (context-aware empty states)

## Future (v1.3+)

- Spotify OAuth + playlist export (when Developer Dashboard available)
- Apple Music integration via MusicKit
- Song feedback loop (heart/flag per song → scoring integration)
- Playlist freshness tracking (penalize recently played songs)
- Profile templates (pre-built profiles like "Chill Long Run", "HIIT Intervals")
- Social playlist sharing

## Out of Scope

| Feature | Reason |
|---------|--------|
| Spotify playlist export | Developer Dashboard still blocked as of 2026-02-06 |
| Apple Music export | Defer to v1.3 — Spotify is higher priority when available |
| Built-in music player | External links to Spotify/YouTube are sufficient |
| Tutorial slideshow onboarding | Research shows action-oriented onboarding is more effective |
| AsyncNotifier migration | Patch with guards instead — lighter change, same reliability |
| Profile templates | Nice to have but not essential for v1.2 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| REGEN-01 | Phase 19 | Done |
| REGEN-02 | Phase 19 | Done |
| REGEN-03 | Phase 19 | Done |
| PROF-01 | Phase 20 | Done |
| PROF-02 | Phase 20 | Done |
| PROF-03 | Phase 20 | Done |
| ONBD-01 | Phase 21 | Done |
| ONBD-02 | Phase 21 | Done |
| ONBD-03 | Phase 21 | Done |

**Coverage:**
- v1.2 requirements: 9 total
- Mapped to phases: 9
- Unmapped: 0

---
*Requirements defined: 2026-02-06*
*Last updated: 2026-02-06 after Phase 21 complete*
