# Feature Research: v1.2 Profile Management, Onboarding, and Regeneration Reliability

**Domain:** Multi-profile management, first-time user onboarding, playlist regeneration robustness
**Researched:** 2026-02-06
**Confidence:** MEDIUM-HIGH -- patterns verified against competitor apps and established mobile UX research; Flutter/Riverpod technical patterns verified against official documentation; codebase race conditions identified through direct code inspection

## Background: Current State and User Journey Gaps

The app has grown from a single-profile, single-plan prototype to a feature-rich running playlist generator. However, three user journey gaps have emerged:

### Gap 1: Taste Profile Management Is Half-Built

The run plan library pattern is fully implemented: users can create, name, edit, delete, and select from multiple named run plans via a dedicated library screen. The taste profile library has the same backend pattern (`TasteProfileLibraryNotifier` with `addProfile`, `updateProfile`, `selectProfile`, `deleteProfile`) and a library screen, but the user-facing experience is less polished. Both the playlist screen and the home screen already reference the taste profile library, but the flow from "first app launch with no profiles" to "pick a profile for generation" has friction.

### Gap 2: First-Time Users Hit a Blank Wall

New users launch the app and see 5 navigation buttons with no context about what to do first. There is no onboarding, no guided setup, and no indication of the 3-step dependency chain needed before generating a playlist: (1) set up stride/cadence, (2) create a run plan, (3) create a taste profile. Users must discover this sequence by trial and error.

The playlist screen partially compensates -- it shows "No Run Plan" with a button to create one. But by the time a user reaches that screen and bounces, their first impression is already damaged. Research consistently shows that apps with structured onboarding see 5x better engagement and 80%+ completion rates vs. apps that dump users on a blank home screen.

### Gap 3: Regeneration Has Silent Failure Modes

The home screen "Regenerate Playlist" card navigates to `/playlist?auto=true`, which triggers `generatePlaylist()` via a `PostFrameCallback` once `runPlan != null`. But the `TasteProfileLibraryNotifier` and `RunPlanLibraryNotifier` both load asynchronously from SharedPreferences in their constructors. If the playlist screen mounts before either notifier finishes `_load()`, the state may be empty, leading to:
- `runPlan` being null (auto-generate never fires)
- `tasteProfile` being null (generation runs without taste preferences, falling through to a default empty profile)

This is an async initialization race condition. It manifests inconsistently, making it hard to reproduce but real for users.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features that v1.2 must deliver. Without these, the app feels incomplete to anyone who uses it beyond a single session.

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Taste profile library screen (polish)** | Users who have the run plan library pattern already expect the same experience for taste profiles. The backend is built; the library screen exists; it needs the same card design, edit/delete affordances, and empty-state guidance as the run plan library. | LOW | Existing `TasteProfileLibraryScreen`, `TasteProfileLibraryNotifier`. | The taste profile library screen already has create/select/edit/delete. The gap is visual polish (match run plan library card style) and the empty state (guide users to create their first profile). Already mostly done from codebase inspection. |
| **Profile selector on playlist generation screen** | When generating a playlist, users need to pick which run plan AND which taste profile to use. The playlist screen already has `_RunPlanSelector` and `_TasteProfileSelector` widgets with bottom-sheet pickers. | LOW | Existing `_RunPlanSelector`, `_TasteProfileSelector` in playlist_screen.dart. | Already implemented. This is table stakes that is essentially done. Verify it works correctly with the library pattern and that switching profiles triggers regeneration context update. |
| **Reliable regeneration (fix race condition)** | Users expect "Regenerate Playlist" to work 100% of the time. The current async initialization race means it silently fails when providers have not finished loading. | MEDIUM | `RunPlanLibraryNotifier._load()`, `TasteProfileLibraryNotifier._load()`, `PlaylistGenerationNotifier.generatePlaylist()`, SharedPreferences async loading. | The fix requires ensuring providers are loaded before the playlist screen consumes them. Two approaches: (A) eager initialization at app startup using the Riverpod pattern from codewithandrea.com, or (B) guard the auto-generate with an explicit readiness check. Option A is cleaner. |
| **Delete confirmation dialog** | Both run plan and taste profile library screens allow delete via a single tap. Accidental deletion of a carefully configured profile is destructive and unrecoverable. Every serious app uses a confirmation dialog for destructive actions. | LOW | Existing delete methods on both notifiers. | Standard Flutter `showDialog` with confirm/cancel. Applied to both run plan library and taste profile library screens. |
| **Empty state guidance (per screen)** | When any library (run plans, taste profiles, playlist history) is empty, the screen should explain what goes here and provide a clear primary action to create the first item. The run plan library and taste profile library already have empty states, but they lack context about WHY the user should create one. | LOW | Existing empty state widgets in both library screens. | Improve copy from "No saved runs / Create Run" to "Create your first run plan to define your distance, pace, and segments. The app will match songs to your running cadence." Brief, purposeful, not decorative. |

### Differentiators (Competitive Advantage)

Features that go beyond what running music apps typically offer. These make the app feel genuinely thoughtful.

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| **First-launch onboarding flow** | Guide new users through the 3-step dependency chain (stride -> run plan -> taste profile) with a clear, motivating sequence. Research shows Spotify asks for 3 favorite artists as minimum viable personalization. Our equivalent: pick energy level and 2-3 genres. The "aha moment" is generating their first playlist. | MEDIUM | Stride calculator (exists), run plan creation (exists), taste profile creation (exists). New: an onboarding controller that tracks whether onboarding has been completed, and a multi-step flow that collects minimal input across 2-4 screens. | No competitor in the BPM-matching space (RockMyRun, PaceDJ, Weav) does structured onboarding well. RockMyRun dumps users into a genre browser. PaceDJ requires library scanning with no guidance. Structured onboarding that ends with a generated playlist in under 2 minutes is a standout experience. |
| **Smart home screen: contextual actions** | Replace the static 5-button grid with context-aware content. (A) No profiles/plans -> show onboarding prompt. (B) Profiles + plan exist but no playlist generated yet -> show prominent "Generate Your First Playlist" card. (C) Previous playlist exists -> show regenerate card with current plan name and cadence (this already exists). Progressive disclosure rather than showing everything at once. | MEDIUM | Onboarding completion flag, run plan library state, taste profile library state, playlist history state. | The home screen currently shows the regenerate card only when a run plan exists, plus 5 static buttons. The improvement: show different content based on what the user has set up. This is the opposite of an anti-feature -- it reduces cognitive load for new users while preserving power for returning users. |
| **Quick-switch profile from home screen** | A chip or dropdown on the home screen showing the active taste profile + run plan, tappable to switch without navigating away. "Today I want my Hip-Hop mix with my 10K plan." One look, two taps, generate. | LOW | Existing `_TasteProfileSelector` and `_RunPlanSelector` widget patterns from playlist_screen.dart. | The playlist screen already has these selectors. Lifting them to the home screen (or making them available in the regenerate card area) is a natural extension. This shortens the "returning user" flow from 3 taps to 1. |
| **Profile templates / presets** | Offer 2-3 pre-built taste profile templates that new users can adopt and customize: "High Energy Pop," "Chill Electronic," "Hip-Hop Power." Reduces the cold-start problem where users must configure everything from scratch. | LOW | TasteProfile model (exists), addProfile method (exists). | Templates are just pre-populated TasteProfile instances. The user can edit them after adopting. This bridges the gap between "I don't know what to pick" and "I have a working profile." Spotify uses a similar pattern with starter playlists. |
| **Onboarding skip with smart defaults** | Users who skip onboarding should still get a working experience. Create a default taste profile (balanced energy, pop + electronic genres) and a default run plan (5K steady, moderate pace) so the user can generate a playlist immediately. | LOW | Existing models and notifiers. | The opposite of forcing completion. If a user is impatient, they get reasonable defaults and can customize later. This respects both exploration-oriented and goal-oriented user types. |
| **Provider readiness guard pattern** | Implement an `AppStartupWidget` pattern (from Riverpod best practices) that eagerly initializes SharedPreferences-backed providers at app startup and shows a loading indicator until ready. Eliminates the entire class of race conditions where widgets mount before data loads. | MEDIUM | All SharedPreferences-backed notifiers (RunPlanLibrary, TasteProfileLibrary, StrideNotifier, PlaylistHistory). GoRouter initial route. | This is an infrastructure improvement, not a user-facing feature. But it eliminates flaky behavior across the entire app. The pattern from codewithandrea.com is well-documented and fits the existing Riverpod 2.x manual provider architecture. |

### Anti-Features (Deliberately NOT Building)

| Feature | Why It Seems Useful | Why It Is Problematic | What to Do Instead |
|---------|--------------------|-----------------------|-------------------|
| **Account system / cloud sync** | "Sync profiles across devices, backup data" | Requires auth infrastructure, backend, GDPR compliance, password resets. The app is intentionally account-free and local-first. Adding accounts changes the app's fundamental character and triples complexity for a feature most solo-device users will never use. | SharedPreferences local persistence is sufficient. If future cloud sync is needed, export/import as JSON file is a simpler bridge. |
| **Profile import from Spotify** | "Auto-detect genres and artists from Spotify listening history" | Spotify API restrictions (Nov 2024) make this unreliable. Requires OAuth flow, API key management, rate limits. The data returned is increasingly limited. High implementation cost for brittle integration. | Manual artist entry is sufficient. The app already supports 10 favorite artists. Users know their own taste better than an algorithm reading play counts. |
| **Animated onboarding tutorial screens** | "Lottie animations, page indicators, swipe-through introduction" | Over-engineered for a utility app. The user wants to generate a playlist, not watch an animated walkthrough. Tutorial-style onboarding has lower completion rates than action-oriented onboarding (Spotify model: DO something immediately, not WATCH something). | Action-oriented onboarding: each step collects actual configuration (pick genres, set pace). The user IS setting up their app, not reading about it. |
| **Complex onboarding analytics** | "Track completion rates per step, A/B test onboarding variations" | Requires analytics SDK integration, event tracking, dashboard. Premature optimization for a v1.2 app. The onboarding flow is simple enough to validate by testing with 3-5 real users. | Manual testing with real users. If the flow takes under 2 minutes and ends with a generated playlist, it is working. |
| **Multi-user profiles on one device** | "Family sharing -- my spouse uses the same phone for running" | Different from taste profiles. Multi-user means separate data silos for EVERYTHING (run plans, playlist history, stride data). Massive architectural change for an edge case. | Each person installs the app on their own phone. The app is free. |
| **Profile analytics / comparison** | "Show which taste profile generates better playlists (higher quality scores)" | Encourages profile tweaking over actually running. Adds UI complexity for marginal value. The quality score is an internal optimization signal, not a user-facing metric. | Users naturally discover what works by running with different profiles and regenerating. The feedback is experiential, not numerical. |
| **Mandatory onboarding (block app until complete)** | "Force users through setup so they get the best experience" | Violates user agency. Some users want to explore first. Forced flows have higher abandonment than optional ones. Research from Nielsen Norman Group and UserPilot consistently shows that progressive disclosure beats forced disclosure. | Onboarding is strongly encouraged (prominent on first launch) but skippable. Smart defaults ensure a functional experience even without completing setup. |
| **Automatic profile switching based on time/location** | "Morning runs use high-energy profile, evening runs use chill" | Requires location permissions, time-of-day rules engine, edge cases (what about afternoon runs?). Complex for a niche feature. | Manual profile selection is fast enough. The quick-switch chip on the home screen makes it a single tap. |

---

## Feature Dependencies

```
First Launch (new user, no data)
    |
    |-- [NEW] Onboarding completion flag (SharedPreferences bool)
    |       |
    |       +-- Check on app start ---------> Route to onboarding OR home screen
    |
    |-- [NEW] Onboarding flow (2-4 screens)
    |       |
    |       +-- Step 1: Welcome + pace input -> Creates stride data (existing StrideNotifier)
    |       |
    |       +-- Step 2: Quick taste setup ----> Creates TasteProfile (existing notifier)
    |       |       |
    |       |       +-- [NEW] Profile templates (optional shortcut)
    |       |
    |       +-- Step 3: Run plan quick-setup -> Creates RunPlan (existing notifier)
    |       |
    |       +-- Step 4: Generate first playlist -> Navigates to playlist screen with auto=true
    |
    |-- [NEW] Smart defaults (skip handler)
            |
            +-- Creates default TasteProfile + RunPlan if skipped

Returning User (data exists)
    |
    |-- [NEW] AppStartupWidget (eager initialization)
    |       |
    |       +-- Watches all SharedPreferences-backed providers
    |       +-- Shows loading until ready
    |       +-- Eliminates race conditions for ALL downstream consumers
    |
    |-- [IMPROVED] Home screen (context-aware)
    |       |
    |       +-- No profiles -> "Complete your setup" card
    |       +-- Has profiles + plan -> "Generate" or "Regenerate" card
    |       +-- [NEW] Quick-switch chips for active profile + plan
    |
    |-- [EXISTING] Taste profile library (polish)
    |       |
    |       +-- [NEW] Delete confirmation dialogs
    |       +-- [IMPROVED] Empty state copy
    |
    |-- [EXISTING] Run plan library (polish)
    |       |
    |       +-- [NEW] Delete confirmation dialogs
    |       +-- [IMPROVED] Empty state copy
    |
    |-- [FIXED] Regeneration reliability
            |
            +-- Guaranteed by AppStartupWidget readiness
            +-- No more silent null-state failures
```

### Dependency Notes

- **AppStartupWidget is the foundation:** It must be implemented before onboarding or home screen improvements, because both depend on knowing whether providers have loaded and what state they contain. Without it, checking "has the user completed onboarding?" is itself subject to the same race condition.
- **Onboarding depends on existing creation flows:** The onboarding wizard does not replace the stride, run plan, or taste profile screens. It provides a streamlined entry point that delegates to the existing notifiers. No new persistence layer is needed.
- **Profile templates are independent:** They can be added before or after onboarding. If added before, onboarding can offer them as quick-start options. If added after, they appear in the taste profile library.
- **Delete confirmations and empty state copy are independent:** Pure UI improvements with no dependencies. Can be done in any order.
- **Home screen context-awareness depends on onboarding flag:** To show "Complete your setup," the home screen needs to know whether onboarding was completed or skipped. This requires the onboarding completion flag in SharedPreferences.
- **Quick-switch chips reuse existing selector widgets:** The `_RunPlanSelector` and `_TasteProfileSelector` from playlist_screen.dart can be extracted to shared widgets and placed on the home screen.

---

## Onboarding Design: Action-Oriented, Not Tutorial

Research and competitor analysis converge on one conclusion: the best onboarding gets users to their "aha moment" as fast as possible. For this app, the aha moment is hearing a playlist that matches their running pace and music taste.

### What Competitors Do

| App | Onboarding Approach | Time to First Value | Quality |
|-----|---------------------|---------------------|---------|
| **Spotify** | Pick 3 artists, then immediately see personalized home | ~30 seconds | Excellent -- minimal input, maximum personalization signal |
| **RockMyRun** | Choose activity type, browse genres, start streaming | ~45 seconds | Good -- but streaming requires subscription for full experience |
| **PaceDJ** | Grant music library access, set target BPM, see filtered results | ~60 seconds | Decent -- but requires existing music library |
| **Nike Run Club** | "What's your experience level?" -> guided run suggestions | ~20 seconds | Good for guided runs, no music-specific onboarding |
| **MyFitnessPal** | Define health goal, enter metrics, see personalized plan | ~90 seconds | Good -- but longer due to data collection |

### Recommended Approach: 4-Screen Flow

**Screen 1: Welcome + Value Proposition** (5 seconds)
- "Get the perfect running playlist in under a minute."
- Single "Let's Go" button. Skip link at bottom.
- No information collection -- just set expectations.

**Screen 2: Running Pace** (15 seconds)
- "How fast do you run?" Simple pace picker (min/km or min/mile).
- Auto-calculates cadence. Shows "Your cadence: ~170 spm."
- This replaces the full stride calculator for onboarding purposes.
- Writes to StrideNotifier.

**Screen 3: Music Taste** (20 seconds)
- "What gets you moving?" Show genre chips + energy level selector.
- Pre-select 2 popular genres (Pop, Electronic) as defaults.
- Optional: offer 2-3 templates ("High Energy," "Chill Vibes," "Hip-Hop Power").
- Minimum: pick 1 genre. Artist entry is optional (can add later).
- Creates TasteProfile via existing notifier.

**Screen 4: First Playlist** (auto-generate)
- "Creating your playlist..." with loading animation.
- Auto-creates a default 5K steady run plan behind the scenes.
- Navigates to playlist screen with auto=true.
- The user sees their first playlist within 40-60 seconds of launching the app.

**Total estimated time: 40-60 seconds.** This matches or beats every competitor.

### Skip Behavior

If the user taps "Skip" at any point:
- Create default stride (170 spm -- average runner cadence)
- Create default taste profile ("Running Mix," Pop + Electronic, balanced energy)
- Create default run plan (5K steady, 5:30/km pace)
- Navigate to home screen (not playlist screen -- they chose to skip)

---

## Regeneration Reliability: Technical Analysis

### Current Flow (Has Race Condition)

```
1. User taps "Regenerate Playlist" on home screen
2. GoRouter navigates to /playlist?auto=true
3. PlaylistScreen builds, reads runPlanNotifierProvider
4. runPlanNotifierProvider reads runPlanLibraryProvider
5. RunPlanLibraryNotifier was created when first watched
6. RunPlanLibraryNotifier constructor calls _load() (async)
7. _load() calls RunPlanPreferences.loadAll() + loadSelectedId()
8. SharedPreferences.getInstance() returns future
9. Meanwhile, PlaylistScreen.build() sees runPlan == null
10. autoGenerate guard: runPlan != null is FALSE -> does not trigger
11. User sees idle "Generate Playlist" button instead of auto-generating
```

The race: step 9 happens before step 8 completes. The provider's state is still the initial `const RunPlanLibraryState()` (empty plans, null selectedId).

### Same Issue for Taste Profiles

```
PlaylistGenerationNotifier.generatePlaylist() reads:
  final tasteProfile = ref.read(tasteProfileNotifierProvider);

If TasteProfileLibraryNotifier hasn't finished _load(),
tasteProfile is null, and generation runs with no taste filtering.
The playlist works but ignores user preferences -- a silent quality degradation.
```

### Fix: AppStartupWidget Pattern

The recommended fix from Riverpod documentation and CodeWithAndrea:

1. Create an `appStartupProvider` that awaits all SharedPreferences-backed providers.
2. Wrap the MaterialApp with an `AppStartupWidget` that shows a loading screen until all providers report ready.
3. Downstream widgets can safely use `requireValue` or trust that providers have loaded.

This is not speculative -- it is the documented Riverpod pattern for exactly this class of problem. Complexity is MEDIUM because it touches the app's root widget and router setup, but the change is well-contained and eliminates all current and future SharedPreferences race conditions in one shot.

### Alternative: Guard in PlaylistScreen

A lighter fix: add a readiness check in the PlaylistScreen auto-generate logic.

```
// Wait for providers to be ready before auto-generating
final libraryState = ref.watch(runPlanLibraryProvider);
final runPlan = libraryState.selectedPlan;
// Only auto-gen when plan is actually loaded (not just "null because loading")
```

This fixes the symptom but not the root cause. New screens with similar patterns will hit the same issue. The AppStartupWidget approach is recommended.

---

## MVP Recommendation

For v1.2 MVP, prioritize in this order:

1. **AppStartupWidget / provider readiness** (fixes regeneration reliability -- the only current BUG)
2. **Delete confirmation dialogs** (quick win, prevents data loss)
3. **First-launch onboarding flow** (biggest UX improvement for new users)
4. **Smart home screen** (context-aware content for both new and returning users)
5. **Profile templates** (reduces cold-start friction during onboarding)

Defer to post-v1.2:
- **Quick-switch chips on home screen:** Nice UX polish but the playlist screen already has selectors. Not critical.
- **Export/import profiles:** Only relevant if users ask for it. No evidence of demand yet.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority | Rationale |
|---------|------------|---------------------|----------|-----------|
| AppStartupWidget (race condition fix) | HIGH | MEDIUM | P0 | Only actual bug. Silent failures erode trust. |
| Delete confirmation dialogs | MEDIUM | LOW | P1 | Prevents accidental data loss. 10 minutes of work. |
| Empty state copy improvements | LOW | LOW | P1 | Quick copy changes, no logic. |
| Onboarding flow (4 screens) | HIGH | MEDIUM | P1 | Biggest impact on new user retention. |
| Smart home screen (context-aware) | HIGH | MEDIUM | P1 | Complements onboarding. Returning users benefit too. |
| Profile templates / presets | MEDIUM | LOW | P2 | Pre-populated profiles, simple implementation. |
| Quick-switch chips on home screen | MEDIUM | LOW | P2 | Reuses existing selector widgets. Polish feature. |
| Onboarding skip with smart defaults | MEDIUM | LOW | P2 | Respects user agency. Simple default creation. |

---

## Competitor Feature Analysis: Profile & Onboarding

| Feature | RockMyRun | PaceDJ | Weav Run | This App (v1.1) | This App (v1.2 target) |
|---------|-----------|--------|----------|-----------------|----------------------|
| **Multiple taste profiles** | Single implicit profile (listening history) | No profiles (scans library) | No profiles (curated catalog) | Backend built, library screen exists, selectors on playlist screen | Polished library, templates, quick-switch |
| **Onboarding flow** | Genre browser on first launch | BPM target picker | Basic genre/mood picker | None (5 buttons on blank screen) | 4-screen action-oriented flow ending with generated playlist |
| **Time to first playlist** | ~60s (streaming starts) | ~120s (library scan + BPM set) | ~45s (pick genre + go) | ~180s (discover stride -> plan -> profile -> generate) | ~60s (onboarding pace -> genre -> auto-generate) |
| **Empty state handling** | Not applicable (always has streaming content) | "No songs match" with BPM adjustment | "Browse playlists" catalog | Basic "No saved X" + create button | Contextual guidance explaining WHY and WHAT to do |
| **Regeneration reliability** | Always streaming (no regeneration concept) | Instant re-filter | Always streaming | Race condition on auto-generate | Guaranteed via eager initialization |
| **Profile switching** | Not applicable | Not applicable | Not applicable | Bottom-sheet picker on playlist screen | Bottom-sheet + quick-switch chips on home screen |

### Competitive Positioning for v1.2

The v1.2 improvements target the app's weakest area: first impressions. Currently, the app has strong generation quality (8-factor scoring, curated song database, segment-aware playlists) but poor discoverability of that quality. A new user might never generate a playlist because they do not understand the setup sequence.

After v1.2: a new user generates their first personalized, BPM-matched playlist within 60 seconds of launching the app. That is competitive with RockMyRun and Weav, and faster than PaceDJ -- while offering a richer personalization system (multiple named taste profiles) that no competitor has.

---

## Research Confidence Assessment

| Finding | Confidence | Source | Notes |
|---------|------------|--------|-------|
| Action-oriented onboarding outperforms tutorial-style | HIGH | VWO, UserPilot, CleverTap research, Spotify pattern analysis | Multiple sources converge |
| 3-5 genre picks are optimal minimum for taste capture | MEDIUM | Inferred from Spotify's "pick 3 artists" pattern | Spotify validated this with data science; genre equivalent is reasonable |
| Riverpod eager initialization pattern fixes race conditions | HIGH | Riverpod official docs, CodeWithAndrea article | Documented pattern for exactly this problem class |
| SharedPreferences async load causes current race condition | HIGH | Direct code inspection of `_load()` in both notifiers | Identified specific code path |
| Delete confirmation is table stakes for destructive actions | HIGH | Standard mobile UX convention | Universal across iOS and Android design guidelines |
| Progressive disclosure improves new-user experience | HIGH | Nielsen Norman Group, Carbon Design System | Well-established UX principle |
| Profile templates reduce cold-start friction | MEDIUM | Inferred from Spotify starter playlists, MyFitnessPal goal templates | Analogous pattern, not directly studied for this domain |
| 60-second time-to-first-playlist is competitive | MEDIUM | Estimated from competitor flows | Competitor timings are approximate from WebSearch descriptions, not timed |

---

## Sources

### Onboarding & UX Research
- [VWO Mobile App Onboarding Guide 2026](https://vwo.com/blog/mobile-app-onboarding-guide/) -- Best practices, engagement metrics, personalization strategies
- [Plotline App Onboarding Examples 2026](https://www.plotline.so/blog/mobile-app-onboarding-examples) -- Action-oriented vs tutorial onboarding comparison
- [UserPilot Frictionless Onboarding](https://userpilot.com/blog/mobile-app-onboarding/) -- Progressive disclosure, skip behavior, smart defaults
- [CleverTap App Onboarding Examples](https://clevertap.com/blog/app-onboarding/) -- Spotify artist-pick pattern, MyFitnessPal goal-first pattern
- [Nielsen Norman Group Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/) -- Cognitive load reduction, gradual complexity revelation
- [Carbon Design System Empty States](https://carbondesignsystem.com/patterns/empty-states-pattern/) -- Actionable empty states, contextual guidance

### Flutter & Riverpod Technical
- [CodeWithAndrea: Robust App Initialization with Riverpod](https://codewithandrea.com/articles/robust-app-initialization-riverpod/) -- AppStartupWidget pattern, eager initialization, requireValue
- [Riverpod Official: Eager Initialization](https://riverpod.dev/docs/how_to/eager_initialization) -- ConsumerWidget pattern for preloading providers
- [Vibe Studio: Multi-Step Onboarding in Flutter](https://vibe-studio.ai/insights/how-to-build-a-multi-step-onboarding-flow-in-flutter) -- PageView + PageController pattern, SharedPreferences completion flag

### Competitor Analysis
- [RockMyRun Official](https://www.rockmyrun.com/) -- Body-Driven Music, genre browsing, subscription model
- [PaceDJ Official](https://www.pacedj.com/) -- Library BPM scanning, manual tempo target
- [Weav Run (Runner's World)](https://www.runnersworld.com/runners-stories/a32257227/running-app-weav-improves-cadence-stride/) -- Adaptive music, ~500 songs, Match My Stride mode
- [DRmare Spotify Running Alternatives](https://www.drmare.com/spotify-music/spotify-running-alternative.html) -- Feature comparison across running music apps

### Empty State & Progressive Disclosure
- [Toptal Empty State UX](https://www.toptal.com/designers/ux/empty-state-ux-design) -- Empty states as opportunity for guidance
- [Mobbin Empty State Pattern](https://mobbin.com/glossary/empty-state) -- Best practices with examples from real apps
- [NNGroup Designing Empty States](https://www.nngroup.com/articles/empty-state-interface-design/) -- Complex application empty state guidelines

---
*Feature research for: v1.2 Profile Management, Onboarding, and Regeneration Reliability -- Running Playlist AI*
*Researched: 2026-02-06*
