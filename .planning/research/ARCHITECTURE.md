# Architecture Patterns: v1.2 Polish & Profiles

**Domain:** Multi taste profiles, onboarding flow, regeneration fix
**Researched:** 2026-02-06
**Overall confidence:** HIGH (based on direct codebase analysis of all relevant files)

---

## Current Architecture Snapshot

### Application Structure

```
lib/
  app/
    app.dart           -- MaterialApp.router with Riverpod
    router.dart        -- GoRouter, flat routes, no auth guard
  features/
    {feature}/
      data/            -- SharedPreferences static wrappers
      domain/          -- Pure Dart models, enums, calculators
      presentation/    -- Flutter screens and widgets
      providers/       -- Riverpod StateNotifier + state classes
```

**State management:** Riverpod 2.x manual providers (no code-gen). StateNotifier pattern throughout. Async load in constructor, sync mutations that fire-and-forget persistence.

**Persistence:** SharedPreferences via static wrapper classes. JSON serialization with `toJson()`/`fromJson()`. No database, no ORM.

**Navigation:** GoRouter with flat routes at `/`. Query parameters for route behavior (`?auto=true`, `?id=xxx`). No shell routes, no auth guard.

**Provider wiring:** `PlaylistGenerationNotifier` reads other providers via `ref.read()` at generation time. No cross-provider invalidation chains. Convenience alias providers wrap library providers (e.g., `tasteProfileNotifierProvider` -> `selectedProfile`).

### Provider Dependency Graph (Relevant to v1.2)

```
playlistGenerationProvider
  |-- reads runPlanNotifierProvider (convenience -> runPlanLibraryProvider.selectedPlan)
  |-- reads tasteProfileNotifierProvider (convenience -> tasteProfileLibraryProvider.selectedProfile)
  |-- reads getSongBpmClientProvider
  |-- reads curatedRunnabilityProvider
  |-- reads playlistHistoryProvider (for auto-save)

runPlanLibraryProvider
  |-- RunPlanLibraryNotifier (self-loading from RunPlanPreferences)

tasteProfileLibraryProvider
  |-- TasteProfileLibraryNotifier (self-loading from TasteProfilePreferences)

strideNotifierProvider
  |-- StrideNotifier (self-loading from StridePreferences)
```

---

## Critical Discovery: Multi Taste Profile Library Already Exists

Direct code examination reveals the taste profile library pattern is **already fully implemented**. This was shipped as part of v1.1 UX refinements.

### Existing Components (Already Built)

| Component | File | Status |
|-----------|------|--------|
| `TasteProfile` domain model | `taste_profile.dart` | Has `id`, `name`, all fields, `copyWith`, JSON serialization |
| `TasteProfileLibraryState` | `taste_profile_providers.dart` | `List<TasteProfile> profiles` + `String? selectedId` + `selectedProfile` getter |
| `TasteProfileLibraryNotifier` | `taste_profile_providers.dart` | `addProfile`, `updateProfile`, `selectProfile`, `deleteProfile` |
| `TasteProfilePreferences` | `taste_profile_preferences.dart` | Library persistence (`taste_profile_library` key) + legacy migration from single `taste_profile` key |
| `TasteProfileLibraryScreen` | `taste_profile_library_screen.dart` | ListView with select, edit (via `?id=`), delete, FAB to create |
| `TasteProfileScreen` | `taste_profile_screen.dart` | Create/edit mode with `profileId` parameter, profile name field |
| `_TasteProfileSelector` | `playlist_screen.dart` (private widget) | Bottom sheet picker integrated in playlist generation screen |
| Backward-compat provider | `taste_profile_providers.dart` | `tasteProfileNotifierProvider` -> `tasteProfileLibraryProvider.selectedProfile` |

### What This Means for v1.2 Scope

The "Multi Taste Profiles" feature is **architecturally complete**. The v1.2 work should focus on:
1. Verifying the flow works correctly end-to-end (create -> select -> generate -> shuffle)
2. Adding test coverage for the library notifier and preferences
3. Polishing any UX gaps

This significantly reduces the v1.2 scope.

---

## Feature Analysis: Regeneration Fix

### Current Behavior (Two Distinct Methods)

**`generatePlaylist()` -- "Generate":**
```dart
// Reads CURRENT selections from providers
final runPlan = ref.read(runPlanNotifierProvider);        // live selection
final tasteProfile = ref.read(tasteProfileNotifierProvider); // live selection

// Fetches songs from API/cache
var songsByBpm = await _fetchAllSongs(runPlan);

// Generates and stores everything
state = PlaylistGenerationState.loaded(
  playlist,
  songPool: songsByBpm,     // stored for replacements
  runPlan: runPlan,          // stored for regeneration
  tasteProfile: tasteProfile, // stored for regeneration
);
```

**`regeneratePlaylist()` -- "Shuffle":**
```dart
// Uses STORED state from last generation, NOT current selections
final storedPlan = state.runPlan;
final tasteProfile = state.tasteProfile;

// RE-FETCHES songs (expensive, 300ms per unique BPM)
var songsByBpm = await _fetchAllSongs(storedPlan);

// Regenerates
state = PlaylistGenerationState.loaded(playlist, ...);
```

### Identified Issues

**Issue 1: Shuffle re-fetches songs unnecessarily.** The `state.songPool` is already stored from the previous generation. Shuffling should reuse this pool with a new Random seed, making it near-instant instead of waiting for API calls.

**Issue 2: Shuffle ignores provider changes.** If the user changes the selected taste profile or run plan via the inline selectors on the playlist screen, then taps "Shuffle," the old stored plan/profile are used. This is likely the "bug" -- the UX lets users change selections, but Shuffle does not respect those changes.

**Issue 3: The `songPool` is already stored in state.** `PlaylistGenerationState.loaded` already carries `songPool`, `runPlan`, and `tasteProfile`. The infrastructure for pool-reuse exists but `regeneratePlaylist()` does not use it.

### Recommended Architecture: Two Distinct Actions

**`shufflePlaylist()` (new method) -- Fast, reuses pool:**
```
Uses state.songPool (no API calls)
Uses state.runPlan (stored from generation)
Uses state.tasteProfile (stored from generation)
Calls PlaylistGenerator.generate() with new Random seed
Result: Different song selection from same pool, instant
```

**`generatePlaylist()` (existing) -- Fresh fetch, reads live providers:**
```
Reads runPlanNotifierProvider (current selection)
Reads tasteProfileNotifierProvider (current selection)
Fetches songs via API/cache
Calls PlaylistGenerator.generate()
Result: Fresh songs based on current selections
```

**UI mapping:**
- "Shuffle" button (on loaded playlist view) -> `shufflePlaylist()`
- "Generate Playlist" button (on idle view, or after changing selections) -> `generatePlaylist()`
- Home screen quick-regenerate card -> `generatePlaylist()` (respects current selections)

### Components Modified

| Component | Change | Lines Affected |
|-----------|--------|---------------|
| `PlaylistGenerationNotifier` | Add `shufflePlaylist()` method | New ~25-line method |
| `playlist_screen.dart` | Wire "Shuffle" to `shufflePlaylist()` | ~2 lines in `_PlaylistView` |

### Components NOT Modified

| Component | Why Unchanged |
|-----------|--------------|
| `PlaylistGenerationState` | Already stores `songPool`, `runPlan`, `tasteProfile` |
| `PlaylistGenerator` | Already accepts `Random? random` parameter for deterministic testing |
| `generatePlaylist()` | Existing behavior is correct for fresh generation |

---

## Feature Analysis: Onboarding Flow

### Current State

No onboarding exists. App launches directly to `HomeScreen` at `/`. New users see navigation buttons with no guidance. The `PlaylistScreen` handles missing data gracefully (shows "No Run Plan" with redirect to `/my-runs`).

### Architecture Decision: GoRouter Redirect

**Chosen approach: GoRouter redirect guard with pre-loaded flag.**

**Why this approach:**
- Fits existing GoRouter setup without restructuring
- Onboarding is a standalone route, testable independently
- Redirect cost is negligible (one boolean check per navigation)
- Pre-loading in `main.dart` avoids async complexity in redirect

**Rejected alternatives:**

| Alternative | Why Not |
|-------------|---------|
| Conditional widget in HomeScreen | Couples onboarding to home screen, harder to test independently |
| Initial route override | GoRouter `initialLocation` is set at provider creation; requires async await before router construction |
| FutureProvider for flag | GoRouter redirect is synchronous; FutureProvider introduces flash of wrong content |

### Onboarding Flow Design

The onboarding guides new users through the minimum steps to reach their first playlist:

```
App launch -> GoRouter redirect -> /onboarding

/onboarding (welcome screen)
  "Let's set up your first running playlist"
  [Get Started]
       |
       v
Navigate to /taste-profile (existing screen, create mode)
  User creates first taste profile
  Pops back to onboarding on save
       |
       v
Navigate to /run-plan (existing screen)
  User creates first run plan
  Pops back to onboarding on save
       |
       v
Navigate to /playlist?auto=true (existing screen, auto-generate)
  First playlist generates automatically
       |
       v
Set onboarding_complete = true
Navigate to / (home screen)
```

**Key design principle: Reuse existing screens.** The taste profile screen, run plan screen, and playlist screen already have full UX. The onboarding shell controls navigation between them. No simplified "onboarding versions" of these screens are needed.

### Async Challenge: Pre-loading the Flag

GoRouter's redirect is synchronous, but SharedPreferences is async. Solution:

```dart
// main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Supabase.initialize(...);

  // NEW: Pre-load onboarding flag
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  runApp(
    ProviderScope(
      overrides: [
        // Pass pre-loaded flag to router
        onboardingCompleteProvider.overrideWithValue(onboardingComplete),
      ],
      child: const App(),
    ),
  );
}
```

This approach is clean because:
- `SharedPreferences.getInstance()` is already implicitly awaited by other providers loading in constructors
- No new async patterns introduced
- The override makes the flag synchronously available to the router

### New Components

| Component | Layer | Location | Purpose |
|-----------|-------|----------|---------|
| `OnboardingPreferences` | data | `lib/features/onboarding/data/` | Read/write `onboarding_complete` boolean |
| `onboardingCompleteProvider` | providers | `lib/features/onboarding/providers/` | Expose flag to router + UI |
| `OnboardingWelcomeScreen` | presentation | `lib/features/onboarding/presentation/` | Welcome page with "Get Started" |
| `OnboardingFlowScreen` | presentation | `lib/features/onboarding/presentation/` | Step tracker + navigation coordinator |

### Modified Components

| Component | Modification | Reason |
|-----------|-------------|--------|
| `router.dart` | Add redirect guard + `/onboarding` route | Gate new users |
| `main.dart` | Pre-load onboarding flag, pass as provider override | Sync redirect check |

### Router Changes

```dart
// router.dart
final routerProvider = Provider<GoRouter>((ref) {
  final onboardingComplete = ref.watch(onboardingCompleteProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (!onboardingComplete && state.matchedLocation == '/') {
        return '/onboarding';
      }
      // Allow navigation to onboarding sub-routes
      if (!onboardingComplete && state.matchedLocation.startsWith('/onboarding')) {
        return null;
      }
      // Allow navigation to screens used during onboarding
      if (!onboardingComplete) {
        final allowedDuringOnboarding = [
          '/taste-profile', '/run-plan', '/playlist', '/stride',
        ];
        if (allowedDuringOnboarding.any(
          (r) => state.matchedLocation.startsWith(r)
        )) {
          return null;
        }
        return '/onboarding';
      }
      return null;
    },
    routes: [
      // ... existing routes ...
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingFlowScreen(),
      ),
    ],
  );
});
```

**Note:** The redirect guard needs to allow navigation to screens used during onboarding (`/taste-profile`, `/run-plan`, `/playlist`). Otherwise the onboarding flow cannot navigate to existing screens.

### Onboarding Completion Tracking

The onboarding tracks step completion implicitly by checking whether the required data exists:

```dart
// Can proceed past taste profile step?
final hasProfile = ref.watch(tasteProfileLibraryProvider).profiles.isNotEmpty;

// Can proceed past run plan step?
final hasPlan = ref.watch(runPlanLibraryProvider).plans.isNotEmpty;

// Auto-advance: if user already has both, skip to playlist generation
```

This is more robust than tracking a step counter because:
- If the user creates a profile/plan via any route, onboarding advances
- If the user kills the app mid-onboarding and returns, progress is preserved
- No separate "onboarding step" state to get out of sync with actual data

---

## Integration Points Summary

### Existing Components Modified

| Component | File | Modification |
|-----------|------|-------------|
| `PlaylistGenerationNotifier` | `playlist_providers.dart` | Add `shufflePlaylist()` method |
| `_PlaylistView` | `playlist_screen.dart` | Wire Shuffle button to `shufflePlaylist()` |
| `router.dart` | `router.dart` | Add redirect guard + onboarding route |
| `main.dart` | `main.dart` | Pre-load onboarding flag |

### New Components

| Component | File | Purpose |
|-----------|------|---------|
| `OnboardingPreferences` | `lib/features/onboarding/data/onboarding_preferences.dart` | Persist completion flag |
| `onboarding_providers.dart` | `lib/features/onboarding/providers/onboarding_providers.dart` | Provider for completion state |
| `OnboardingWelcomeScreen` | `lib/features/onboarding/presentation/onboarding_welcome_screen.dart` | Welcome/intro page |
| `OnboardingFlowScreen` | `lib/features/onboarding/presentation/onboarding_flow_screen.dart` | Step coordinator |

### Components NOT Modified

| Component | Why Unchanged |
|-----------|--------------|
| `TasteProfileLibraryNotifier` | Already fully implements CRUD + selection |
| `TasteProfilePreferences` | Already supports library with legacy migration |
| `TasteProfileLibraryScreen` | Already has list/select/edit/delete/create |
| `TasteProfileScreen` | Already supports create + edit via profileId |
| `RunPlanLibraryNotifier` | No changes needed |
| `RunPlanPreferences` | No changes needed |
| `PlaylistGenerator` | Pure domain logic, already accepts Random parameter |
| `PlaylistGenerationState` | Already stores songPool, runPlan, tasteProfile |
| `SongQualityScorer` | Unchanged |

---

## Data Flow Changes

### Current: Generate Playlist

```
User taps "Generate"
  -> PlaylistGenerationNotifier.generatePlaylist()
  -> ref.read(runPlanNotifierProvider)         -- reads CURRENT selection
  -> ref.read(tasteProfileNotifierProvider)    -- reads CURRENT selection
  -> _fetchAllSongs(runPlan)                   -- API + cache (slow)
  -> PlaylistGenerator.generate(...)           -- pure domain
  -> state = loaded(playlist, songPool, runPlan, tasteProfile)
  -> auto-save to history
```
**No change.** This flow is correct.

### Current: Shuffle (PROBLEMATIC)

```
User taps "Shuffle"
  -> PlaylistGenerationNotifier.regeneratePlaylist()
  -> uses state.runPlan (stored)              -- IGNORES current selection
  -> uses state.tasteProfile (stored)          -- IGNORES current selection
  -> _fetchAllSongs(storedPlan)                -- RE-FETCHES (wasteful)
  -> PlaylistGenerator.generate(...)
  -> state = loaded(...)
```

### Proposed: Shuffle (FIXED)

```
User taps "Shuffle"
  -> PlaylistGenerationNotifier.shufflePlaylist()
  -> uses state.songPool (REUSES -- no API calls, instant)
  -> uses state.runPlan (stored from generation)
  -> uses state.tasteProfile (stored from generation)
  -> PlaylistGenerator.generate(..., random: Random())  -- new seed
  -> state = loaded(...)
  -> auto-save to history
```

### Proposed: Onboarding

```
App launch
  -> main.dart: prefs.getBool('onboarding_complete') ?? false
  -> ProviderScope override: onboardingCompleteProvider = false
  -> GoRouter redirect: / -> /onboarding

/onboarding
  -> OnboardingFlowScreen checks:
     profiles.isEmpty? -> "Create Taste Profile" step
     plans.isEmpty?    -> "Create Run Plan" step
     both exist?       -> Navigate to /playlist?auto=true

After first playlist generates:
  -> OnboardingPreferences.setComplete(true)
  -> Update onboardingCompleteProvider state
  -> Navigate to / (home)
  -> Future redirects: onboarding check passes, no redirect
```

---

## Suggested Build Order

Based on dependency analysis, risk, and the discovery that multi-profiles already exist:

### Phase 1: Regeneration Fix

**Why first:** Smallest scope (one new method + one UI wire). No dependencies on other features. Immediately improves existing user experience. Good confidence builder.

**Scope:**
1. Add `shufflePlaylist()` to `PlaylistGenerationNotifier` -- reuses `state.songPool`
2. Wire "Shuffle" button in `_PlaylistView` to call `shufflePlaylist()`
3. Verify `generatePlaylist()` correctly reads current provider selections
4. Test: shuffle produces different results, no API calls, stored state preserved

**Estimated complexity:** Low. ~30 lines of new code + test coverage.

### Phase 2: Multi Taste Profile Verification

**Why second:** The infrastructure exists but needs verification and test coverage. This is quality assurance, not greenfield development.

**Scope:**
1. Write test coverage for `TasteProfileLibraryNotifier` (add, update, select, delete)
2. Write test coverage for `TasteProfilePreferences` (library persistence, legacy migration)
3. Integration test: change selected profile -> generate playlist -> verify correct profile used
4. Integration test: change profile on playlist screen -> generate -> verify new profile
5. Verify "Shuffle" uses stored profile (expected), "Generate" uses current selection (expected)
6. Fix any gaps discovered during testing

**Estimated complexity:** Low-Medium. Mostly test writing, may surface minor bugs.

### Phase 3: Onboarding Flow

**Why last:** Most new code. Depends on taste profile and run plan creation working correctly. Introduces new feature directory, router changes, and async startup modification.

**Scope:**
1. Create `lib/features/onboarding/` directory structure
2. Implement `OnboardingPreferences` (SharedPreferences wrapper for flag)
3. Implement `onboarding_providers.dart` (StateProvider for completion)
4. Modify `main.dart` to pre-load flag
5. Modify `router.dart` to add redirect guard + onboarding route
6. Build `OnboardingWelcomeScreen` (welcome page)
7. Build `OnboardingFlowScreen` (step coordinator checking provider states)
8. Test: new user -> onboarding -> first playlist -> home
9. Test: returning user -> skip onboarding -> home

**Estimated complexity:** Medium. ~150-200 lines of new code across 4-5 files.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Duplicating Screen Logic for Onboarding

**What:** Building simplified versions of TasteProfileScreen, RunPlanScreen for onboarding.
**Why bad:** Duplicates UI code, creates maintenance burden. The existing screens already have full UX including validation, persistence, and feedback.
**Instead:** Reuse existing screens. The onboarding shell controls navigation between them. At most, detect "came from onboarding" context to show a slightly different AppBar or hide the back button.

### Anti-Pattern 2: Complex Onboarding State Machine

**What:** Building an `OnboardingStep` enum with transition guards, undo capability, and persistent step tracking.
**Why bad:** Over-engineering for a linear 2-3 step flow. The actual steps are: have a taste profile? -> have a run plan? -> generate. Each step is a boolean check against existing provider state.
**Instead:** Check provider state directly. `profiles.isEmpty` -> show taste profile step. `plans.isEmpty` -> show run plan step. Both exist -> navigate to generate. No step counter needed.

### Anti-Pattern 3: Making Shuffle and Generate Identical

**What:** Removing `regeneratePlaylist()` and always calling `generatePlaylist()`.
**Why bad:** Generate re-fetches from API (300ms per unique BPM, potentially 5-15 BPMs = 1.5-4.5 seconds). Shuffle should be instant -- same pool, different picks. Users expect "Shuffle" to be fast.
**Instead:** `shufflePlaylist()` reuses stored `songPool` with new Random seed. `generatePlaylist()` fetches fresh. UI labels should communicate the difference.

### Anti-Pattern 4: Async GoRouter Redirect

**What:** Making the redirect handler async, or using a `FutureProvider` that returns a loading state.
**Why bad:** GoRouter redirect is synchronous. Async approaches cause a flash of the wrong screen or require complex loading states that hurt perceived performance.
**Instead:** Pre-load the flag in `main.dart` before `runApp()`. Pass it synchronously to the router via provider override.

### Anti-Pattern 5: Onboarding Checks at Every Route

**What:** Adding onboarding completion checks to individual screens.
**Why bad:** Scatters onboarding logic across the codebase. Each screen would need "am I in onboarding mode?" logic.
**Instead:** Single redirect guard in the router. Onboarding is contained in one feature directory. Existing screens are unaware of onboarding.

---

## Component Boundaries

```
+-------------------------------------------------------------------------+
|                        PRESENTATION LAYER                               |
|                                                                         |
|  HomeScreen  PlaylistScreen  TasteProfileScreen  RunPlanScreen          |
|              (has selectors  (create/edit mode)   (creates plans)        |
|               for both)                                                 |
|  OnboardingWelcomeScreen  OnboardingFlowScreen  <-- NEW                 |
|  (welcome page)           (step coordinator)                            |
|                                                                         |
+----+--------------------+------------------+----------------------------+
     |                    |                  |
+----+--------------------+------------------+----------------------------+
|                        PROVIDER LAYER                                   |
|                                                                         |
|  playlistGenerationProvider (+ new shufflePlaylist)                      |
|  tasteProfileLibraryProvider (EXISTING -- already has CRUD)             |
|  tasteProfileNotifierProvider (convenience -> selectedProfile)          |
|  runPlanLibraryProvider                                                 |
|  runPlanNotifierProvider (convenience -> selectedPlan)                   |
|  onboardingCompleteProvider  <-- NEW                                    |
|  routerProvider (+ redirect guard)                                      |
|                                                                         |
+----+--------------------+------------------+----------------------------+
     |                    |                  |
+----+--------------------+------------------+----------------------------+
|                        DATA LAYER                                       |
|                                                                         |
|  TasteProfilePreferences (EXISTING -- already has library persistence)  |
|  RunPlanPreferences (EXISTING)                                          |
|  OnboardingPreferences  <-- NEW                                         |
|                                                                         |
+-------------------------------------------------------------------------+
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Onboarding redirect interferes with deep links | Low | Medium | Allow-list routes during onboarding |
| Shuffle produces identical results to previous | Low | Low | New `Random()` seed on each call; verify with test |
| Provider override in main.dart not reactive | Medium | Low | After completing onboarding, update the provider state directly (not just SharedPreferences) |
| Existing taste profile library has untested edge cases | Medium | Medium | Write test coverage in Phase 2 before building on it |
| User kills app during onboarding | Low | Low | Onboarding checks actual data state, not step counter -- resumes correctly |

---

## Sources

- Direct codebase analysis: `taste_profile_providers.dart`, `taste_profile_preferences.dart`, `taste_profile_library_screen.dart`, `taste_profile_screen.dart`, `playlist_providers.dart`, `playlist_screen.dart`, `router.dart`, `main.dart`, `home_screen.dart`, `run_plan_providers.dart`, `run_plan_preferences.dart`, `run_plan_library_screen.dart`, `run_plan_screen.dart`, `playlist_generator.dart`, `playlist.dart`, `stride_providers.dart`, `app.dart` -- **HIGH confidence** (primary source, direct examination)
- GoRouter redirect pattern -- **HIGH confidence** (standard GoRouter pattern, consistent with existing codebase's GoRouter usage)
- SharedPreferences pre-loading -- **HIGH confidence** (already used implicitly by all existing provider constructors)
