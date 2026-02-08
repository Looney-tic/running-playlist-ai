# Requirements: v1.4 Smart Song Search & Spotify Foundation

## Song Search

- [ ] **SEARCH-01**: User can search curated song catalog with typeahead autocomplete (debounced, 2-char minimum)
- [ ] **SEARCH-02**: Search results highlight matching characters in song title and artist name
- [ ] **SEARCH-03**: Search abstraction supports multiple backends (curated now, Spotify when connected)

## Songs I Run To

- [ ] **SONGS-01**: User can add songs to "Songs I Run To" list from search results
- [ ] **SONGS-02**: User can view and remove songs from "Songs I Run To" list with empty state guidance
- [ ] **SONGS-03**: Running songs receive scoring boost in playlist generation (treated like liked songs)
- [ ] **SONGS-04**: Running songs are analyzed for taste patterns (genre/artist preferences fed to TastePatternAnalyzer)
- [ ] **SONGS-05**: Running songs show BPM compatibility indicator relative to current cadence target

## Spotify Foundation

- [ ] **SPOTIFY-01**: App supports Spotify OAuth PKCE authorization flow with secure token storage
- [ ] **SPOTIFY-02**: Token management handles expiry, refresh, and graceful degradation when unavailable
- [ ] **SPOTIFY-03**: User can search Spotify catalog when connected, extending local search results with dual-source UI
- [ ] **SPOTIFY-04**: User can browse their Spotify playlists when connected
- [ ] **SPOTIFY-05**: User can select songs from Spotify playlists to import into "Songs I Run To"

## Future Requirements

(None deferred — all proposed features selected for this milestone)

## Out of Scope

- **Spotify playback integration** — Requires Premium, adds SDK burden; external play links sufficient
- **Spotify playlist export/creation** — Wait for Dashboard access; clipboard copy is interim
- **Spotify "Liked Songs" bulk import** — Too broad; playlist-level import filters naturally
- **Background token refresh** — Over-engineering for foundation; on-demand refresh sufficient
- **Song recommendations from favorites** — Existing quality scorer handles via taste learning

## Traceability

| REQ-ID | Phase | Plan | Status |
|--------|-------|------|--------|
| SEARCH-01 | Phase 30 | — | Pending |
| SEARCH-02 | Phase 30 | — | Pending |
| SEARCH-03 | Phase 30 | — | Pending |
| SONGS-01 | Phase 28 | — | Pending |
| SONGS-02 | Phase 28 | — | Pending |
| SONGS-03 | Phase 29 | — | Pending |
| SONGS-04 | Phase 29 | — | Pending |
| SONGS-05 | Phase 29 | — | Pending |
| SPOTIFY-01 | Phase 31 | — | Pending |
| SPOTIFY-02 | Phase 31 | — | Pending |
| SPOTIFY-03 | Phase 32 | — | Pending |
| SPOTIFY-04 | Phase 33 | — | Pending |
| SPOTIFY-05 | Phase 33 | — | Pending |

---
*Created: 2026-02-08*
