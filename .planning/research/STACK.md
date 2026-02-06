# Technology Stack: v1.2 Profile Management & Onboarding

**Project:** Running Playlist AI
**Milestone:** v1.2 Profile Management & Onboarding
**Researched:** 2026-02-06
**Overall confidence:** HIGH

---

## Scope: What This Document Covers

This STACK.md covers **only the additions and changes** needed for v1.2 features. The existing stack (Flutter 3.38, Dart 3.10, Riverpod 2.x manual providers, GoRouter 17.x, SharedPreferences 2.5.4, http, supabase_flutter, url_launcher, GetSongBPM API) is validated and stable. Do not re-evaluate it.

v1.2 features that drive stack decisions:
1. Multiple taste profiles with naming, selection, and switching
2. First-run onboarding flow (detection, guided setup, completion tracking)
3. Playlist regeneration reliability (state consistency, error recovery)

---

## Critical Discovery: Multi-Profile Infrastructure Already Exists

Before recommending any new stack additions, a thorough codebase review reveals that **the multi-profile architecture is already implemented and shipped in v1.1**:

| Capability | Status | Location |
|-----------|--------|----------|
| Multiple taste profiles (list) | DONE | `TasteProfileLibraryNotifier` in `taste_profile_providers.dart` |
| Named profiles | DONE | `TasteProfile.name` field exists and is editable |
| Profile selection/switching | DONE | `selectProfile(String id)` method + `selectedProfile` getter |
| Profile CRUD (add/edit/delete) | DONE | Full CRUD in `TasteProfileLibraryNotifier` |
| Library UI with cards | DONE | `TasteProfileLibraryScreen` with selection, edit, delete |
| Profile selector on playlist screen | DONE | `_TasteProfileSelector` widget with bottom sheet picker |
| Legacy single-profile migration | DONE | `TasteProfilePreferences.loadAll()` auto-migrates |
| Persistence of profile library | DONE | JSON array in SharedPreferences under `taste_profile_library` key |
| Run plan library (parallel pattern) | DONE | Identical pattern in `RunPlanLibraryNotifier` |

**This means v1.2's "multi-profile" work is NOT a new architecture effort.** It is refinement of existing infrastructure: better naming UX, onboarding to create a first profile, and ensuring selection state propagates correctly to generation.

**Confidence:** HIGH (verified by direct codebase inspection)

---

## Recommended Stack Additions

### No New Dependencies Required

All three v1.2 features can be built with the existing stack. No new pub.dev packages needed.

| Feature | Stack Approach | New Dependencies |
|---------|---------------|-----------------|
| Multi-profile refinement | Extend existing `TasteProfileLibraryNotifier` + UI polish | None |
| Onboarding flow | GoRouter `redirect` + SharedPreferences bool flag + new screen widgets | None |
| Regeneration reliability | Fix state management in `PlaylistGenerationNotifier` | None |

**Rationale:** The existing stack is comprehensive. Onboarding is a navigation + state detection problem (GoRouter redirect + SharedPreferences). Profile management is already implemented. Regeneration reliability is a bug fix in existing provider logic. Adding libraries would create maintenance burden for zero functional gain.

---

## Feature 1: Onboarding Flow

### First-Run Detection

**Decision: SharedPreferences boolean flag with GoRouter redirect**

The standard Flutter pattern for first-run detection uses a boolean flag in SharedPreferences, checked in a GoRouter `redirect` callback.

```dart
// Key for tracking onboarding completion
static const _onboardingCompleteKey = 'onboarding_complete';
```

**Why GoRouter redirect (not manual navigation):**
- GoRouter 17.x supports `redirect` as a top-level parameter on the `GoRouter` constructor
- The redirect fires on every navigation event, ensuring the onboarding gate cannot be bypassed
- The current router (`routerProvider`) can be extended with a redirect without restructuring existing routes
- GoRouter's `refreshListenable` can be used to re-evaluate the redirect when onboarding completes, automatically navigating to home

**Implementation pattern:**
```dart
GoRouter(
  redirect: (context, state) {
    final isOnboarded = ref.read(onboardingCompleteProvider);
    final isOnboardingRoute = state.matchedLocation == '/onboarding';

    if (!isOnboarded && !isOnboardingRoute) return '/onboarding';
    if (isOnboarded && isOnboardingRoute) return '/';
    return null; // no redirect
  },
  refreshListenable: onboardingListenable,
  // ... existing routes
);
```

**Onboarding state provider pattern:**
```dart
// Simple bool provider backed by SharedPreferences
final onboardingCompleteProvider = StateNotifierProvider<OnboardingNotifier, bool>(
  (ref) => OnboardingNotifier(),
);
```

This follows the exact same async-init-in-constructor pattern used by `TasteProfileLibraryNotifier` and `RunPlanLibraryNotifier` -- call `_load()` from the constructor without awaiting.

**Confidence:** HIGH (GoRouter redirect is documented, standard pattern; SharedPreferences bool flag is trivial)

### Onboarding UI: No Third-Party Packages Needed

**Decision: Use Flutter's built-in `PageView` + `PageController` for the step-through flow**

The onboarding flow is 3-4 steps:
1. Welcome / app purpose
2. Create first taste profile (reuse existing `TasteProfileScreen` widgets)
3. Create first run plan (reuse existing `RunPlanScreen` widgets)
4. Confirm and start

**Why NOT `smooth_page_indicator` or `introduction_screen`:**
- The app already uses Material 3 design. A `LinearProgressIndicator` or `Stepper` widget from Flutter Material is sufficient for step progress indication.
- `smooth_page_indicator` (latest: 2.0.1) adds dot-style indicators that are suited for image carousels, not form-heavy onboarding steps where a progress bar is more appropriate.
- The onboarding screens are form-heavy (genre chips, artist input, distance picker), not swipeable image cards. A `PageView` with locked `physics: NeverScrollableScrollPhysics()` and explicit Next/Back buttons is the right UX pattern.
- Adding a package for a few dots is not justified when `LinearProgressIndicator(value: step / totalSteps)` works.

**Confidence:** HIGH (Flutter built-in widgets are well-documented and sufficient)

### Onboarding Completion Criteria

**Decision: Onboarding completes when at least one taste profile AND one run plan exist**

This means the onboarding flow does not need its own separate completion state independent from the actual data. The check can be:

```dart
bool get isOnboardingComplete {
  final hasProfile = tasteProfileLibrary.profiles.isNotEmpty;
  final hasRunPlan = runPlanLibrary.plans.isNotEmpty;
  return hasProfile && hasRunPlan;
}
```

However, a separate `onboarding_complete` flag in SharedPreferences is still recommended because:
- Users who delete all profiles should NOT be re-shown onboarding (they are not "first-run" users)
- Checking two separate async-loading providers for redirect creates a race condition on cold start
- A single bool flag loads faster than waiting for both libraries to deserialize

**Confidence:** HIGH (well-established UX pattern)

---

## Feature 2: Multi-Profile Management Refinement

### What Already Works (Do Not Rebuild)

The entire multi-profile data layer and library UI is shipped. v1.2 work here is UX polish only:

| Component | Status | v1.2 Work Needed |
|-----------|--------|-----------------|
| `TasteProfile` domain model with `id`, `name` | Complete | None |
| `TasteProfilePreferences` persistence | Complete (library pattern with migration) | None |
| `TasteProfileLibraryNotifier` state management | Complete (add, update, delete, select) | None |
| `TasteProfileLibraryScreen` UI | Complete | Polish: default names, empty state messaging |
| `TasteProfileScreen` editor | Complete (edit + new modes) | Polish: guided prompts for first profile |
| Profile selector on playlist screen | Complete (`_TasteProfileSelector`) | None |

### Profile Naming Strategy

**Decision: Auto-generate meaningful default names**

Current behavior: profiles without a name show `"{first genre} Mix"` or `"Taste Profile"`. This is good enough but can be improved:

```dart
String defaultProfileName(TasteProfile profile) {
  if (profile.genres.isNotEmpty) {
    final energy = profile.energyLevel == EnergyLevel.intense
        ? 'High Energy'
        : profile.energyLevel == EnergyLevel.chill
            ? 'Chill'
            : '';
    final genre = profile.genres.first.displayName;
    return '$energy $genre Mix'.trim();
  }
  return 'My Profile';
}
```

**No new packages needed.** This is pure presentation logic.

**Confidence:** HIGH (trivial string formatting)

### ID Generation

The current ID generation uses `DateTime.now().millisecondsSinceEpoch.toString()`. This is sufficient for a single-user local app where profiles are created seconds apart. No need to add the `uuid` package.

**Confidence:** HIGH

---

## Feature 3: Playlist Regeneration Reliability

### Current Regeneration Issues Identified

Reading the `PlaylistGenerationNotifier` code reveals the following reliability concerns:

**Issue 1: `regeneratePlaylist()` re-fetches songs from API instead of reusing cached pool**

The `regeneratePlaylist()` method calls `_fetchAllSongs(storedPlan)` which makes fresh API calls. When the user just wants a different shuffle of the same song pool, this is wasteful and can fail if the API is down. The `state.songPool` is already available from the previous generation.

**Fix approach:** Add a `shufflePlaylist()` method that reuses `state.songPool` and only calls `PlaylistGenerator.generate()` with the existing pool. Reserve `regeneratePlaylist()` for when the user changes run plan or taste profile (requiring new songs).

**Issue 2: State reads stale providers during regeneration**

`generatePlaylist()` reads `runPlanNotifierProvider` and `tasteProfileNotifierProvider` at call time. If the user changed their selected profile between generating and regenerating, `regeneratePlaylist()` uses the OLD stored plan/profile from `state.runPlan` / `state.tasteProfile`, while `generatePlaylist()` uses the CURRENT selection from providers. This inconsistency can lead to confusing behavior.

**Fix approach:** Both methods should consistently read from providers for the current selection, with `state.runPlan/tasteProfile` serving only as fallback. Alternatively, regenerate should explicitly accept parameters.

**Issue 3: No error recovery for partial API failure**

If the API fails mid-fetch (e.g., 3 out of 6 BPM queries succeed), the entire generation falls through to the curated-only path. Songs from successful API calls are discarded.

**Fix approach:** Merge API results with curated fallback rather than either/or. This is a domain logic change, not a stack change.

**All three issues are fixable within existing Riverpod StateNotifier pattern. No new packages needed.**

**Confidence:** HIGH (issues identified by direct code review; fixes are straightforward state management changes)

---

## What NOT to Add

| Technology | Why Not Add |
|-----------|-------------|
| **smooth_page_indicator** ^2.0.1 | Onboarding flow uses form-heavy steps, not swipeable cards. Flutter's built-in `LinearProgressIndicator` or `Stepper` is appropriate. |
| **introduction_screen** | Over-engineered for our needs. Our onboarding must reuse existing taste profile and run plan form widgets, not display intro images. |
| **uuid** | `DateTime.now().millisecondsSinceEpoch` is sufficient for local single-user ID generation. UUIDs add a dependency for no practical benefit at this scale. |
| **drift / SQLite / Hive** | Data volume has not changed. SharedPreferences handles profile library (JSON array) easily. |
| **flutter_secure_storage** (activate it) | Already in pubspec.yaml but unused. Profile data is not sensitive enough to warrant encrypted storage. |
| **Supabase (activate it beyond init)** | Cross-device profile sync would be nice but is out of scope for v1.2. All data remains local. |
| **auto_route** | GoRouter 17.x is already in use and supports redirect-based onboarding. No reason to switch routing packages. |
| **riverpod_generator** (activate it) | Code-gen is broken with Dart 3.10 (documented in project memory). Continue with manual providers. |
| **freezed** (for new models) | Existing models use hand-written `copyWith`, `fromJson`, `toJson`. This pattern is established and works. Adding freezed for new classes while existing ones are manual creates inconsistency. |

---

## Existing Stack: Confirmed Sufficient

| Package | Version | v1.2 Usage |
|---------|---------|-----------|
| `flutter_riverpod` | ^2.6.1 | Onboarding state provider, generation state fixes |
| `go_router` | ^17.0.1 | `redirect` callback for onboarding gate, new `/onboarding` route |
| `shared_preferences` | ^2.5.4 | `onboarding_complete` bool flag |
| `http` | ^1.6.0 | Unchanged |
| `url_launcher` | ^6.3.2 | Unchanged |
| `supabase_flutter` | ^2.12.0 | Unchanged (init only) |
| `flutter_dotenv` | ^6.0.0 | Unchanged |

**Note on SharedPreferences API:** The project uses the classic `SharedPreferences` API (synchronous reads after `getInstance()`). Version 2.5.4 also offers `SharedPreferencesAsync` and `SharedPreferencesWithCache`. No reason to migrate -- the classic API is not deprecated yet and the project's usage patterns are simple enough that the newer APIs provide no benefit. If migration happens, it should be a separate effort, not mixed with v1.2 feature work.

**Confidence:** HIGH (all versions verified against pub.dev, all patterns verified against codebase)

---

## Data Storage: No Changes to Strategy

| Data | Storage | v1.2 Changes |
|------|---------|-------------|
| Taste profile library | SharedPreferences (JSON array) | None -- already supports multiple profiles |
| Selected profile ID | SharedPreferences (string) | None -- already persisted |
| Run plan library | SharedPreferences (JSON array) | None |
| Onboarding completion | SharedPreferences (bool) | NEW -- single `onboarding_complete` key |
| BPM cache | SharedPreferences (JSON per BPM) | None |
| Playlist history | SharedPreferences (JSON array) | None |

**New SharedPreferences keys for v1.2:**
- `onboarding_complete` (bool) -- that is the only new key needed.

**Confidence:** HIGH

---

## Integration Points with Existing Code

| Existing File | What Changes | How |
|--------------|-------------|-----|
| `lib/app/router.dart` | Add `redirect` for onboarding gate + `/onboarding` route | Extend `GoRouter` constructor with redirect callback |
| `lib/features/playlist/providers/playlist_providers.dart` | Fix regeneration to reuse song pool, fix stale state reads | Modify `regeneratePlaylist()`, add `shufflePlaylist()` |
| `lib/features/taste_profile/presentation/taste_profile_library_screen.dart` | Polish empty state, improve default naming | Minor UI changes |
| `lib/features/home/presentation/home_screen.dart` | Update for first-run vs returning user messaging | Conditional UI based on onboarding state |
| `lib/main.dart` | No changes needed | GoRouter redirect handles onboarding detection |

**New files to create:**
| File | Purpose |
|------|---------|
| `lib/features/onboarding/data/onboarding_preferences.dart` | SharedPreferences wrapper for `onboarding_complete` flag |
| `lib/features/onboarding/providers/onboarding_providers.dart` | `OnboardingNotifier` StateNotifier for completion state |
| `lib/features/onboarding/presentation/onboarding_screen.dart` | Multi-step onboarding UI (PageView with embedded forms) |

**These follow the exact same `features/{name}/data|domain|presentation|providers` structure as every other feature module.**

---

## Architecture Decision Record: Why No New Packages

The v1.2 milestone is fundamentally a **UX refinement milestone**, not an infrastructure milestone. The multi-profile architecture shipped in v1.1. The onboarding pattern (bool flag + GoRouter redirect) is a 20-line addition to existing infrastructure. The regeneration fix is a state management bug fix.

Adding packages for any of these introduces:
- Version resolution conflicts with existing dependencies
- Build time increase (especially problematic with Dart 3.10 code-gen issues)
- Learning curve for maintainer
- Upgrade burden for future milestones

The existing Flutter + Riverpod + GoRouter + SharedPreferences stack handles everything v1.2 needs. **The right decision is zero new dependencies.**

---

## Sources

- [GoRouter redirect documentation](https://pub.dev/packages/go_router) - HIGH confidence (verified v17.1.0 changelog, redirect supported)
- [GoRouter onboarding redirect pattern](https://dev.to/kcl/onboarding-with-go-router-in-flutter-2jd6) - MEDIUM confidence (community tutorial, but pattern is standard)
- [SharedPreferences v2.5.4 changelog](https://pub.dev/packages/shared_preferences/changelog) - HIGH confidence (verified on pub.dev)
- [smooth_page_indicator v2.0.1](https://pub.dev/packages/smooth_page_indicator) - HIGH confidence (verified on pub.dev, decided NOT to use)
- [Flutter Riverpod async init pattern](https://codewithandrea.com/articles/robust-app-initialization-riverpod/) - MEDIUM confidence (community tutorial by reputable author)
- [Flutter onboarding with Riverpod + SharedPreferences + GoRouter](https://flutterexplained.com/p/flutter-onboarding-with-riverpod) - MEDIUM confidence (community tutorial, aligns with documented APIs)
- Existing codebase analysis (all files read directly) - HIGH confidence
