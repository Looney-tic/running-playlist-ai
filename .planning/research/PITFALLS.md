# Domain Pitfalls

**Domain:** Running playlist BPM-matching app (Flutter, Spotify integration)
**Researched:** 2026-02-01
**Overall confidence:** HIGH (multiple authoritative sources confirm key findings)

---

## Critical Pitfalls

Mistakes that cause rewrites or make the project infeasible.

### Pitfall 1: Spotify Audio Features API Is Deprecated -- No BPM Data From Spotify

**What goes wrong:** The entire project premise depends on knowing track BPM/tempo. Spotify's `GET /audio-features` endpoint (which returned tempo) was deprecated on November 27, 2024. New apps get 403 Forbidden. There is no replacement endpoint from Spotify.

**Why it happens:** Spotify removed Audio Features, Audio Analysis, and Recommendations endpoints to prevent AI model training on their data. Apps created after Nov 2024 cannot access these endpoints at all.

**Consequences:** Without an alternative BPM source, the app cannot function. This is an existential risk to the project.

**Prevention:**
- Use a third-party BPM data source from day one. Options include:
  - **SoundNet Track Analysis API** -- marketed as a drop-in replacement for Spotify Audio Features
  - **ReccoBeats API** (`reccobeats.com/docs/apis/get-track-audio-features`)
  - **ListenBrainz Labs API** -- open-source alternative with similar metadata
  - **MusicBrainz + AcousticBrainz** datasets
  - **Local BPM analysis** using libraries like Essentia (heavy, but no API dependency)
- Design the BPM data layer as a swappable abstraction from the start -- providers may disappear or change terms

**Detection:** You will discover this immediately when calling `/v1/audio-features/{id}` and receiving 403.

**Phase:** Must be resolved in Phase 1 (architecture/proof-of-concept). Do not proceed without confirming a working BPM data source.

**Confidence:** HIGH -- confirmed via Spotify developer blog, TechCrunch reporting, and community forums.

**Sources:**
- [Spotify Web API changes announcement](https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api)
- [TechCrunch coverage](https://techcrunch.com/2024/11/27/spotify-cuts-developer-access-to-several-of-its-recommendation-features/)
- [SoundNet alternative](https://medium.com/@soundnet717/spotify-audio-analysis-has-been-deprecated-what-now-4808aadccfcb)

---

### Pitfall 2: Spotify Extended Access Gate -- 250K MAU Requirement

**What goes wrong:** Since May 2025, Spotify requires apps to have 250,000+ monthly active users and be a registered business entity to get extended API access. Without extended access, apps are stuck in "development mode" with severe rate limits and a cap of 25 users.

**Why it happens:** Spotify tightened criteria to focus on apps that "drive Spotify's platform strategy forward."

**Consequences:** Your app cannot scale beyond 25 users without extended access approval. Getting approval as a new indie app is near-impossible under current criteria.

**Prevention:**
- Build and launch in development mode (25 users) first to validate the concept
- Apply for extended access early with a clear pitch about driving Spotify engagement
- Design the app so the Spotify integration adds playlists to user accounts (this "promotes artist discovery," aligning with Spotify's stated goals)
- Have a fallback plan: support exporting playlists as text lists that users can manually recreate, or support Apple Music as an alternative target

**Detection:** Warning signs: your extended access application is rejected or goes unanswered for weeks.

**Phase:** Phase 1 (apply immediately), but the constraint shapes the entire project timeline.

**Confidence:** HIGH -- confirmed via Spotify developer blog (April 2025) and community reports.

**Sources:**
- [Updated extended access criteria](https://developer.spotify.com/blog/2025-04-15-updating-the-criteria-for-web-api-extended-access)
- [Community discussion on restrictions](https://community.latenode.com/t/spotifys-updated-api-policies-are-blocking-independent-developers/20610)

---

### Pitfall 3: Spotify OAuth -- Implicit Grant Flow Removed

**What goes wrong:** As of November 27, 2025, Spotify removed support for implicit grant flow, HTTP redirect URIs, and localhost aliases. Many tutorials and packages still reference the old flow.

**Why it happens:** Security hardening. Implicit grant was vulnerable to token interception.

**Consequences:** Auth breaks entirely if using deprecated flow. Migration has been described as "a nightmare" by developers due to few working examples.

**Prevention:**
- Use **Authorization Code Flow with PKCE** from the start (required for mobile/web apps where client secret cannot be stored safely)
- Use HTTPS redirect URIs only (except `http://127.0.0.1` for local dev)
- Do not follow any tutorial that mentions implicit grant flow
- Test auth flow on all three platforms (web, Android, iOS) early -- redirect URI handling differs significantly per platform

**Detection:** Auth requests return errors immediately if using deprecated flows.

**Phase:** Phase 1 (auth setup). Get this right before building anything else.

**Confidence:** HIGH -- confirmed via official Spotify developer blog.

**Sources:**
- [OAuth migration reminder](https://developer.spotify.com/blog/2025-10-14-reminder-oauth-migration-27-nov-2025)
- [Spotify authorization docs](https://developer.spotify.com/documentation/web-api/concepts/authorization)

---

### Pitfall 4: BPM Half-Time / Double-Time Confusion

**What goes wrong:** A track at 140 BPM can be reported as 70 BPM (half-time) or 280 BPM (double-time). Both are technically correct. Running at 170 spm and getting matched to 85 BPM doom metal tracks ruins the experience.

**Why it happens:** Tempo is perceptually ambiguous. Algorithms detect pulse, but the "correct" pulse level depends on genre conventions. Hip-hop often sits at 70-85 BPM but feels double-time. Drum and bass at 170+ BPM is felt in half-time.

**Consequences:** Users get matched to completely wrong-feeling music. A runner at 160 spm could get 80 BPM ballads or 320 BPM speedcore.

**Prevention:**
- When matching BPM to cadence, also check BPM x2 and BPM /2 as candidates
- Filter by a sane BPM range for running (typically 120-200 BPM; reject anything outside 100-210)
- Use genre as a secondary signal: hip-hop tracks at 70-85 BPM should be treated as 140-170 effective BPM
- Apply log-Gaussian weighting to prefer moderate tempos (120-180) over extremes
- Let users report "this song feels wrong" and learn from corrections

**Detection:** Test with known tracks across genres. If your 170 BPM playlist includes slow jazz ballads, you have this bug.

**Phase:** Phase 2 (BPM matching logic). Build explicit half/double-time handling into the matching algorithm.

**Confidence:** HIGH -- this is extremely well-documented in music information retrieval literature.

**Sources:**
- [Essentia beat detection tutorial](https://essentia.upf.edu/tutorial_rhythm_beatdetection.html)
- [BPM detection accuracy analysis](https://www.swayzio.com/blog/bpm-detection-technology-how-accurate-tempo-analysis-transforms-music-production)

---

## Moderate Pitfalls

Mistakes that cause delays or technical debt.

### Pitfall 5: Flutter Web Performance and Bundle Size

**What goes wrong:** Flutter Web apps ship a large WASM runtime, have poor SEO, slow initial load times, and inconsistent rendering compared to mobile. The debugging experience on web is significantly worse than mobile.

**Why it happens:** Flutter renders everything to a canvas rather than using native DOM elements. The entire Skia/Impeller rendering engine must be downloaded.

**Prevention:**
- Treat web as a secondary target. Build and polish mobile first, then adapt for web.
- Keep the web version simple -- avoid complex animations or heavy scroll views
- Use deferred loading/lazy loading for non-critical features on web
- Set performance budgets for initial load time early
- Consider whether web is truly needed for v1 -- a mobile-only launch is simpler

**Detection:** First time you load the web build, note the blank screen duration and bundle size. If initial load exceeds 3 seconds on fast connection, you have a problem.

**Phase:** Phase 1 (project setup) -- decide web priority level. Phase 3+ for web-specific optimization.

**Confidence:** MEDIUM -- based on multiple developer experience reports; Flutter Web has improved with WASM compilation but fundamental issues remain.

**Sources:**
- [Flutter Web pros and cons](https://medium.com/@bartzalewski/cross-platform-development-with-flutter-web-pros-and-cons-7369fef60b54)
- [Critical Flutter Web analysis](https://suica.dev/en/blogs/fuck-off-flutter-web,-unless-you-slept-through-school,-you-know-flutter-web-is-a-bad-idea)

---

### Pitfall 6: Spotify Rate Limits Without Batching Strategy

**What goes wrong:** Generating a playlist requires: (1) searching/fetching tracks, (2) getting BPM data for each track, (3) creating a playlist, (4) adding tracks. Without batching, a single playlist generation can consume dozens of API calls, quickly hitting rate limits in development mode.

**Why it happens:** Spotify's rate limits are not publicly documented as exact numbers. Development mode has very low limits. There is no batch endpoint for fetching multiple playlists.

**Prevention:**
- Cache all track metadata aggressively (BPM doesn't change)
- Use batch endpoints where available (`/tracks?ids=` accepts up to 50 IDs)
- Implement exponential backoff on 429 responses with the `Retry-After` header
- Build a request queue that respects rate limits rather than firing calls in parallel
- Pre-fetch and cache BPM data for user's library rather than fetching on-demand

**Detection:** You start seeing 429 responses during testing, especially when loading a user's full library.

**Phase:** Phase 1 (API layer design). Bake caching and throttling into the HTTP client from the start.

**Confidence:** HIGH -- rate limit issues are extensively reported in Spotify developer forums.

**Sources:**
- [Spotify rate limits documentation](https://developer.spotify.com/documentation/web-api/concepts/rate-limits)
- [Community rate limit discussion](https://community.spotify.com/t5/Spotify-for-Developers/Getting-rate-limited-with-Spotify-Web-API-despite-using/td-p/7034479)

---

### Pitfall 7: Stride/Cadence Calculation Assumes Universal Constants

**What goes wrong:** Using a fixed formula like `stride_length = height * 0.415` or assuming 180 spm is ideal for all runners. These rules of thumb are wildly inaccurate for individuals.

**Why it happens:** The relationship between height, pace, cadence, and stride length is highly individual. Research shows that when runners increase pace by 33%, stride length increases ~28% while cadence increases only ~4%. The variables are deeply coupled to individual biomechanics.

**Consequences:** A tall runner with short strides or a short runner with long strides gets completely wrong BPM targets. Users lose trust in the app immediately.

**Prevention:**
- The core formula is: `speed = stride_length * cadence`. If you know any two, you can derive the third.
- Provide a calibration flow: let users input their actual cadence (from a running watch) or run a short calibration session using phone accelerometer
- Offer cadence presets by pace (e.g., "easy run at 10:00/mi" vs "tempo run at 7:30/mi") rather than computing from height alone
- Show cadence as a range, not a single number
- Let users manually override the target BPM

**Detection:** Ask 5 runners of different heights/speeds to test. If more than one says "this BPM feels completely wrong," the formula is too rigid.

**Phase:** Phase 2 (cadence logic). Build calibration before building the formula.

**Confidence:** HIGH -- the speed/cadence/stride relationship is well-established in exercise science.

**Sources:**
- [Science of cadence for runners](https://runningwritings.com/2026/01/science-of-cadence.html)
- [Stride frequency vs stride length](https://www.runningshoesguru.com/content/stride-frequency-cadence-vs-stride-length-for-run-speed/)

---

### Pitfall 8: Flutter State Management Complexity Creep

**What goes wrong:** Starting without a state management pattern and bolting one on later, or choosing an overly complex solution (BLoC with full event/state classes for simple screens) that slows development.

**Prevention:**
- Choose a state management approach in Phase 1 and stick with it
- For this app's complexity level, Riverpod or simple BLoC is appropriate -- avoid over-engineering
- The key state to manage well: auth tokens, cached track/BPM data, current playlist generation state, user preferences

**Detection:** If adding a new screen requires touching 5+ files of boilerplate, the state management is too heavy.

**Phase:** Phase 1 (project architecture).

**Confidence:** MEDIUM -- general Flutter development wisdom, widely reported.

---

## Minor Pitfalls

Mistakes that cause annoyance but are fixable.

### Pitfall 9: Unit Confusion in Pace/Cadence/Stride Calculations

**What goes wrong:** Mixing metric and imperial units. Pace is often min/mile or min/km. Cadence is steps/min (some systems use strides/min = steps/2). Stride length can be meters or feet.

**Prevention:**
- Internally, use SI units everywhere (meters, seconds, steps per minute)
- Convert to user's preferred units only at the display layer
- Be explicit: "cadence" means steps per minute (both feet), not strides per minute
- Document unit conventions in code comments at the calculation layer

**Detection:** Any test case where the output is exactly 2x or 0.5x the expected value likely has a steps-vs-strides or metric-vs-imperial bug.

**Phase:** Phase 2 (calculation logic).

**Confidence:** HIGH -- Garmin forums are full of exactly this class of bug.

**Sources:**
- [Garmin stride length calculation issues](https://forums.garmin.com/sports-fitness/running-multisport/f/forerunner-945/170741/stride-length-calculation-on-treadmill-way-off-after-upgrade-from-2-50-0-0-to-2-70-0-0)

---

### Pitfall 10: Platform-Specific Redirect URI Handling

**What goes wrong:** OAuth redirect URIs work differently on web (URL redirect), Android (deep link / app link), and iOS (universal link / custom scheme). A redirect URI that works on web fails on mobile or vice versa.

**Prevention:**
- Register separate redirect URIs per platform in the Spotify dashboard
- On mobile, use custom URL schemes (e.g., `myapp://callback`) or verified app links
- Test the full auth flow on each platform individually before building features on top of it
- Use a well-maintained Flutter OAuth/Spotify package that handles platform differences

**Detection:** Auth works on one platform but silently fails on another.

**Phase:** Phase 1 (auth setup).

**Confidence:** MEDIUM -- standard cross-platform OAuth challenge.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| Phase 1: Project setup | Flutter Web bundle size surprises | Measure baseline bundle size immediately; decide if web is v1 scope |
| Phase 1: Auth setup | OAuth implicit grant / HTTP redirect mistakes | Use PKCE + HTTPS from the start; test all 3 platforms |
| Phase 1: API layer | No BPM data from Spotify | Confirm third-party BPM source works before building anything else |
| Phase 1: API layer | Rate limits in dev mode (25 user cap) | Apply for extended access early; build aggressive caching |
| Phase 2: BPM matching | Half/double time mismatches | Check x2 and /2 candidates; filter to 100-210 BPM range |
| Phase 2: Cadence calc | Universal formula assumption | Build calibration flow; offer presets, not just formulas |
| Phase 2: Cadence calc | Unit confusion (steps vs strides, m vs ft) | Use SI internally; convert at display layer only |
| Phase 3+: Scaling | Extended access rejection | Have Apple Music fallback plan; align pitch with Spotify's artist-discovery goals |

---

## Key Takeaway

The single most critical finding: **Spotify's Audio Features API is deprecated and returns 403 for new apps.** The entire BPM-matching feature depends on getting tempo data from somewhere else. This must be the first thing validated -- before writing any other code. Design the BPM data layer as a pluggable abstraction so the source can be swapped without rewrites.
