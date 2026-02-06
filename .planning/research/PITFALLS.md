# Domain Pitfalls

**Domain:** Adding multi-profile management, onboarding flow, and regeneration reliability to an existing Flutter/Riverpod running playlist app (v1.2)
**Researched:** 2026-02-06
**Confidence:** HIGH (grounded in existing codebase analysis, documented Flutter/Riverpod issues, and proven patterns from run plan library)

---

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or fundamental UX breakage.

### Pitfall 1: Regeneration Race Condition -- Reading Provider State Before Async Load Completes

**What goes wrong:**
`generatePlaylist()` calls `ref.read(runPlanNotifierProvider)` which reads from `RunPlanLibraryNotifier`, whose constructor fires `_load()` asynchronously. Between the notifier's construction (state = empty `RunPlanLibraryState`) and `_load()` completing (state populated from SharedPreferences), `runPlanNotifierProvider` returns `null`. If `generatePlaylist()` is called during this window -- which happens with auto-generate via `?auto=true` -- the user sees "No run plan saved. Please create a run plan first." despite having a saved run plan.

The current mitigation in `PlaylistScreen` is a `_autoGenTriggered` flag with a condition `runPlan != null && !generationState.isLoading`, which polls via Riverpod rebuilds until the run plan becomes non-null. This works for the initial auto-generate, but `regeneratePlaylist()` has a different path: it checks `state.runPlan` (the stored plan from the last generation), and falls back to `generatePlaylist()` when that is null. After a hot restart or cold start, `state.runPlan` is always null because `PlaylistGenerationState` is not persisted.

**Why it happens:**
`StateNotifier` constructors cannot be `async`. The pattern `_load()` (fire-and-forget async in constructor) creates a temporal gap where state is in its initial empty/default value. This is a well-known Riverpod pitfall. The notifier *will* eventually have the right data, but any code that `ref.read()` during the gap gets stale data.

**Consequences:**
- "Shuffle" button after cold start fails silently (falls through to `generatePlaylist()` which may see null run plan)
- Home screen quick-regenerate card (`/playlist?auto=true`) intermittently fails on slow devices
- The error message ("No run plan saved") is misleading -- the plan exists, it just hasn't loaded yet

**Prevention:**
1. **Store the run plan and taste profile in `PlaylistGenerationState` and persist them.** When the user taps "Shuffle," the regeneration should use the stored plan from the last generation, not re-read from providers. This is partially implemented (state has `runPlan` and `tasteProfile` fields) but the state is not persisted across cold starts.
2. **Guard `generatePlaylist()` with an async readiness check.** Before reading `runPlanNotifierProvider`, await the library load. This can be done by converting to `AsyncNotifierProvider` or by adding a `Future<void> ensureLoaded()` method to the library notifiers.
3. **Show a loading state, not an error, when providers are still initializing.** The playlist screen should distinguish "no run plan exists" from "run plan hasn't loaded yet."

**Warning signs:**
- "No run plan saved" error appears after app restart even though run plans exist
- Intermittent failures on slow devices or in debug mode
- Tests pass because they pre-seed provider state, masking the async gap

**Detection:**
Add a cold-start integration test: restart app, immediately navigate to `/playlist?auto=true`, verify playlist generates successfully.

**Phase to address:**
Regeneration reliability phase -- this must be fixed before onboarding or profile management, because onboarding completion leads directly to playlist generation, which will hit this same race condition.

**Confidence:** HIGH -- the race condition is visible in the current code: `RunPlanLibraryNotifier` constructor calls `_load()` without awaiting, and `generatePlaylist()` calls `ref.read()` synchronously.

---

### Pitfall 2: Onboarding Redirect Loop or Flash When go_router Redirect Depends on Async State

**What goes wrong:**
The onboarding flow needs to redirect first-time users (no taste profile, no run plan) to an onboarding screen instead of the home screen. The natural implementation adds a `redirect` callback to `GoRouter` that checks SharedPreferences for an `onboarding_completed` flag. But SharedPreferences is async, and go_router's redirect fires synchronously on every navigation event.

Three failure modes emerge:
1. **Flash of wrong screen:** The redirect returns `null` (no redirect) while SharedPreferences loads, showing the home screen briefly before redirecting to onboarding.
2. **Infinite redirect loop:** The redirect checks `onboardingCompleted == false` and redirects to `/onboarding`, but the redirect fires again for the `/onboarding` route and sees the same false value (still loading), creating a loop. go_router has a redirect limit (default 5) and throws `RangeError`.
3. **Black screen:** When using `async` redirect, go_router may show a black/empty screen while waiting for the async operation to complete.

**Why it happens:**
go_router's `redirect` callback was not designed for async initialization checks. It runs on every navigation, including the initial route resolution. Combining it with async SharedPreferences creates a timing dependency that is easy to get wrong.

**Prevention:**
1. **Load onboarding status before `GoRouter` initializes.** In `main()`, read the onboarding flag from SharedPreferences and pass it as a parameter to the router provider. This eliminates the async dependency inside redirect.
   ```dart
   // In main():
   final prefs = await SharedPreferences.getInstance();
   final onboardingDone = prefs.getBool('onboarding_completed') ?? false;
   ```
2. **Use a splash/loading screen as the initial route** that waits for all async state to settle, then navigates to either onboarding or home. This avoids redirect entirely for the initial routing decision.
3. **Exempt the onboarding route from redirect.** Always check `if (state.matchedLocation == '/onboarding') return null;` first in the redirect callback to prevent loops.
4. **Use `refreshListenable`** on a `ChangeNotifier` that fires when onboarding state changes, rather than checking SharedPreferences inside redirect.

**Warning signs:**
- Users report seeing the home screen flash before onboarding appears
- Crash logs show `RangeError` with "too many redirects" message
- Black screen on app launch in release mode (not visible in hot reload)

**Detection:**
Test on a fresh install with `SharedPreferences.clear()` before launch. Verify no screen flash. Test with simulated slow SharedPreferences (add delay in test).

**Phase to address:**
Onboarding phase -- this is the core architectural decision for the onboarding flow. Must be decided before building any onboarding UI.

**Confidence:** HIGH -- documented in [go_router issue #133746](https://github.com/flutter/flutter/issues/133746) (black screen), [issue #118061](https://github.com/flutter/flutter/issues/118061) (infinite loops), and [issue #105808](https://github.com/flutter/flutter/issues/105808) (async redirect support).

---

### Pitfall 3: Taste Profile Migration Silently Drops Data for Edge-Case JSON Shapes

**What goes wrong:**
The migration from legacy single-profile (`taste_profile` key) to multi-profile (`taste_profile_library` key) already exists in `TasteProfilePreferences.loadAll()`. It works for the standard case. But edge cases cause silent data loss:

1. **Profile without `id` field:** Legacy profiles saved before the `id` field was added deserialize with `DateTime.now().millisecondsSinceEpoch.toString()` as the ID. If `loadAll()` is called twice quickly (e.g., two providers read simultaneously), two different IDs are generated for the same profile. The `selectedId` stored in SharedPreferences points to the first ID, but the second load created a profile with a different ID, so `selectedProfile` returns `null`.

2. **Profile with new enum values:** If a future version adds a new `RunningGenre` enum value and then the user downgrades the app, `RunningGenre.fromJson()` calls `firstWhere` with no `orElse` -- it throws `StateError` ("No element"), crashing the entire profile load. `EnergyLevel.fromJson()` has the same pattern. (Note: `VocalPreference.fromJson()` and `TempoVarianceTolerance.fromJson()` correctly have `orElse` fallbacks.)

3. **Corrupted JSON in SharedPreferences:** If `saveAll()` is interrupted (app killed during write), the JSON may be truncated. `jsonDecode()` throws `FormatException`, and the entire profile library returns empty. No fallback to the legacy key (which was already deleted during migration).

**Why it happens:**
Migration code is tested with the happy path (one valid profile, clean JSON). Edge cases around concurrent access, version mismatches, and storage corruption are rarely tested.

**Consequences:**
- User's taste profile silently disappears after app update
- Playlist generates with `null` taste profile (no genre/artist preferences), producing generic results
- User does not realize preferences are lost until they see unfamiliar songs

**Prevention:**
1. **Add `orElse` fallbacks to ALL `fromJson` enum deserializers.** `RunningGenre.fromJson()`, `EnergyLevel.fromJson()`, and `MusicDecade.fromJson()` should all have `orElse` clauses that skip unknown values rather than throwing.
2. **Wrap `loadAll()` in try-catch.** If JSON parsing fails, return `[]` rather than crashing. Log the error for debugging.
3. **Do not delete the legacy key until the new key is confirmed written.** Move the `prefs.remove(_legacyKey)` to after `saveAll()` succeeds.
4. **Cache the parsed profiles in memory** so `loadAll()` called multiple times returns the same objects with the same IDs.

**Warning signs:**
- User reports "my profile is gone" after an app update
- Analytics show taste profile is null during playlist generation for users who previously had profiles
- `selectedProfile` returns null despite `profiles` being non-empty (ID mismatch)

**Detection:**
Unit test: serialize a profile with an unknown enum value string, verify `fromJson` does not throw. Integration test: call `loadAll()` twice in rapid succession, verify IDs match.

**Phase to address:**
Profile management phase -- must be fixed as part of the multi-profile implementation, before any new profile features are added.

**Confidence:** HIGH -- the vulnerable code is visible in `taste_profile.dart` lines 12 and 41 (`fromJson` without `orElse`), and `taste_profile_preferences.dart` line 29 (legacy key deleted before save confirmation).

---

### Pitfall 4: Onboarding Creates a "Cold Start" for Playlist Generation That Feels Broken

**What goes wrong:**
A well-designed onboarding collects a taste profile and run plan. The user completes onboarding and expects to immediately generate a playlist. But the first generation requires:
1. Async load of the just-saved taste profile from SharedPreferences
2. Async load of the just-saved run plan from SharedPreferences
3. Network fetch of songs from GetSongBPM API (or curated fallback)
4. Curated song repository load (3-tier: cache, Supabase, bundled JSON)
5. Runnability data load from Supabase

The user waits through multiple async operations on their very first interaction with the core feature. If any operation fails (network timeout, Supabase not initialized), they see an error on their first ever playlist generation. This is the worst possible first impression.

**Why it happens:**
Each async operation works fine in isolation. The onboarding flow and playlist generation are designed as separate features. Nobody tests the end-to-end flow: complete onboarding then immediately generate. The async operations compound, and the "happy path" in development (warm caches, fast network) masks the cold-start latency.

**Consequences:**
- User completes onboarding, taps "Generate," waits 5-10 seconds, then sees an error
- First-run experience is the worst experience (opposite of what onboarding should achieve)
- User abandons the app before ever seeing a playlist

**Prevention:**
1. **Pre-fetch during onboarding.** While the user fills in their taste profile (which takes 30-60 seconds), start loading curated songs and runnability data in the background. By the time they finish onboarding, the data is cached.
2. **Pass onboarding data directly to the generator.** Instead of saving to SharedPreferences and then re-reading, pass the `TasteProfile` and `RunPlan` objects directly to the playlist generation screen via navigation parameters or a shared provider. This eliminates the save-then-load roundtrip.
3. **Use curated-only generation for the first playlist.** Skip the GetSongBPM API call entirely and generate from the bundled curated dataset. This eliminates network dependency for the first impression. Future generations can use the API.
4. **Show contextual loading.** Instead of a generic spinner, show "Finding songs in Pop, Electronic..." (using their chosen genres) to make the wait feel productive.

**Warning signs:**
- First playlist generation takes noticeably longer than subsequent ones
- Error rate is highest on first generation
- Onboarding completion rate is high but playlist generation rate is low

**Detection:**
End-to-end test: clear all data, complete onboarding, immediately generate. Measure time and success rate. Compare to generation with warm caches.

**Phase to address:**
Onboarding phase -- the generation flow immediately post-onboarding must be designed as part of the onboarding feature, not as an afterthought.

**Confidence:** HIGH -- the async chain is visible in `PlaylistGenerationNotifier.generatePlaylist()` (lines 101-163), which sequentially reads run plan, taste profile, fetches songs, loads curated data, and loads runnability.

---

## Moderate Pitfalls

Mistakes that cause delays, confusing behavior, or technical debt.

### Pitfall 5: Multiple Taste Profiles Without Clear "Active Profile" Indicator in Generation Flow

**What goes wrong:**
The app already supports multiple taste profiles with a `selectedProfile`. But the playlist generation screen (`_IdleView` and `_PlaylistView`) shows selectors for run plan and taste profile that are small, subtle UI elements. When a user creates a second taste profile during onboarding or later, they may not realize which profile is active when generating. They get a playlist that doesn't match their expectations because Profile A was selected when they thought they were using Profile B.

The existing `_TasteProfileSelector` widget shows the profile name (or first 2 genres) in a compact row. After adding multi-profile management, users will switch between profiles more frequently, and the subtle selector becomes a source of confusion.

**Why it happens:**
The selector pattern was designed when there was effectively one profile. Multi-profile support was added to the data layer (providers, persistence) but the UI was not redesigned around the multi-profile workflow.

**Prevention:**
1. **Show the active profile name prominently** on the playlist generation idle screen -- not just in a selector row but as a heading or card.
2. **Confirm profile selection when generating.** On the idle view, show which run plan + taste profile will be used, with both visible and tappable.
3. **Auto-select the most recently edited profile** when the user returns from the taste profile editor. The current code already does this in `addProfile()` (selects new profile), but `updateProfile()` does not change selection -- this is correct for editing but confusing when the user edits Profile B while Profile A is selected.

**Warning signs:**
- User creates a "Metal" profile but gets Pop songs (because their "Pop" profile was still selected)
- Bug reports about "taste profile not working" that are actually selection confusion
- Users always re-select the same profile before generating

**Detection:**
Usability test: ask a user to create two profiles, switch between them, and generate. Observe whether they correctly identify which profile is active.

**Phase to address:**
Profile management phase -- the UI for profile selection must be updated when adding multi-profile management.

**Confidence:** MEDIUM -- based on UX analysis of the existing selector widget. No user feedback data to confirm the confusion pattern, but the selector is objectively subtle (13px font, buried in a row of two selectors).

---

### Pitfall 6: Onboarding State Stored Separately From the Data It Guards

**What goes wrong:**
A common pattern stores an `onboarding_completed` boolean in SharedPreferences, separate from the actual taste profile and run plan data. This creates a state desync: the boolean says onboarding is done, but the taste profile or run plan may not actually exist (deleted, migration failure, SharedPreferences corruption). Or conversely, the user has a taste profile from a previous version but the `onboarding_completed` flag was never set, so they see onboarding again.

**Why it happens:**
It feels clean to have a single boolean flag. The alternative (checking whether a taste profile and run plan actually exist) feels like an implementation detail leaking into the routing layer.

**Prevention:**
**Derive onboarding status from the data, not from a separate flag.** Instead of:
```dart
final onboardingDone = prefs.getBool('onboarding_completed') ?? false;
```

Use:
```dart
final hasProfile = (await TasteProfilePreferences.loadAll()).isNotEmpty;
final hasRunPlan = (await RunPlanPreferences.loadAll()).isNotEmpty;
final onboardingDone = hasProfile && hasRunPlan;
```

This is always consistent with the actual app state. If the user deletes all their profiles, they see the onboarding again (which is the correct behavior). If an existing user upgrades from v1.1 (has data, no onboarding flag), they skip onboarding correctly.

**Warning signs:**
- Existing v1.1 users see onboarding after upgrading to v1.2 despite having profiles
- User completes onboarding, data fails to save, but the boolean was set -- they never see onboarding again and have an empty app
- Edge case: user manually clears app data in Settings but `onboarding_completed` persists (or vice versa)

**Detection:**
Test: set `onboarding_completed = true` but clear all profile/plan data. Verify the app handles the state correctly (shows onboarding or empty state, not a broken home screen).

**Phase to address:**
Onboarding phase -- this is the first design decision for the onboarding architecture.

**Confidence:** HIGH -- this is a general best practice for derived state (proven pattern), and the existing codebase already uses this pattern: `runPlanNotifierProvider` returns null when no plans exist, and the playlist screen shows "No Run Plan" accordingly.

---

### Pitfall 7: Taste Profile `copyWith` Doesn't Allow Clearing Optional Fields

**What goes wrong:**
`TasteProfile.copyWith()` uses the pattern `name: name ?? this.name`. This means you cannot set `name` back to `null` once it has a value. If a user creates a profile with a name and then wants to remove the name (leaving it auto-generated), calling `copyWith(name: null)` keeps the old name.

The same issue applies to any future nullable field added to TasteProfile. This is a well-known Dart `copyWith` limitation.

**Why it happens:**
The standard Dart `copyWith` pattern cannot distinguish between "parameter not provided" (should keep current value) and "parameter explicitly set to null" (should clear value). Since Dart uses `null` for both cases, the `??` fallback always preserves the existing value.

**Prevention:**
For fields that need to be clearable, use a sentinel value or a wrapper:
```dart
TasteProfile copyWith({
  Object? name = _sentinel,
  // ...
}) {
  return TasteProfile(
    name: name == _sentinel ? this.name : name as String?,
    // ...
  );
}
const _sentinel = Object();
```

Alternatively, since the taste profile editor screen uses local state and constructs a new `TasteProfile` from scratch (not via `copyWith`), this is only a pitfall if future code starts using `copyWith` for profile updates.

**Warning signs:**
- User cannot remove a profile name through the UI
- Future code uses `profile.copyWith(name: null)` and the name persists unexpectedly

**Detection:**
Unit test: create profile with name "Test", call `copyWith(name: null)`, verify name is null.

**Phase to address:**
Profile management phase -- fix when adding profile editing capabilities.

**Confidence:** HIGH -- the code is visible at `taste_profile.dart` line 198-221.

---

### Pitfall 8: StateNotifier `_load()` Fire-and-Forget Creates Silent Error Swallowing

**What goes wrong:**
Both `RunPlanLibraryNotifier` and `TasteProfileLibraryNotifier` call `_load()` in their constructors without any error handling:
```dart
RunPlanLibraryNotifier() : super(const RunPlanLibraryState()) {
    _load();
}
```

If `_load()` throws (SharedPreferences failure, JSON parse error, platform channel error), the error is silently swallowed. The notifier stays in its initial empty state (`plans: [], selectedId: null`), and the app behaves as if the user has no saved data.

**Why it happens:**
Fire-and-forget async calls in constructors have no caller to propagate errors to. The Dart runtime logs the error to the console but the app continues with the wrong state.

**Prevention:**
1. **Add try-catch inside `_load()`** with explicit error handling -- at minimum, log the error and set an error flag in state.
2. **Better: migrate to `AsyncNotifier`** which has built-in error state via `AsyncValue.error()`. Callers can then check `state.hasError` and show a retry option.
3. **If staying with StateNotifier:** add a `loadError` field to the state class so the UI can distinguish "no data" from "load failed."

**Warning signs:**
- Users report "empty" app state after a crash or forced stop
- No error reporting when SharedPreferences fails
- Debugging becomes impossible because errors are silently consumed

**Detection:**
Unit test: mock SharedPreferences to throw, verify the notifier handles the error (does not leave state in a misleading "empty" condition).

**Phase to address:**
Regeneration reliability phase -- when fixing the async load race condition, also add error handling to `_load()`.

**Confidence:** HIGH -- the fire-and-forget pattern is visible in both notifiers' constructors.

---

## Minor Pitfalls

Mistakes that cause annoyance but are fixable without major rework.

### Pitfall 9: Onboarding "Back" Navigation Leaves Partial State

**What goes wrong:**
If onboarding is a multi-step flow (e.g., step 1: taste profile, step 2: run plan), and the user completes step 1 but presses "Back" on step 2, a taste profile exists but no run plan. The onboarding is incomplete but step 1's data is already saved.

On next launch, the derived onboarding check (`hasProfile && hasRunPlan`) sees no run plan and shows onboarding again. But the taste profile step is already done, so:
- If onboarding shows all steps, the user re-does the taste profile (annoying)
- If onboarding skips completed steps, the user sees only the run plan step (confusing -- "where's my taste profile setup?")

**Prevention:**
1. **Save onboarding data only at the end.** Keep taste profile and run plan as in-memory state during onboarding, and persist both together when the user completes the final step.
2. **Or: make each step independently valuable.** If a user backs out after creating a taste profile, that's fine -- they can use the app with a taste profile and no run plan (current app handles this with "No Run Plan" view on the playlist screen).

**Detection:**
Test: start onboarding, complete step 1, back out at step 2, relaunch app. Verify behavior is sensible.

**Phase to address:**
Onboarding phase.

**Confidence:** MEDIUM -- depends on the chosen onboarding architecture (single-screen vs. multi-step).

---

### Pitfall 10: Profile Deletion While It's the Active Profile for a Generated Playlist

**What goes wrong:**
The user generates a playlist with Profile A, then navigates to Taste Profiles, deletes Profile A. The `deleteProfile()` method selects the first remaining profile. But the playlist screen still shows a playlist generated with Profile A's preferences. If the user taps "Shuffle" (regenerate), the regeneration uses `state.tasteProfile` (Profile A, still in the generation state) but the providers now point to Profile B. The regenerated playlist mixes Profile A's stored state with Profile B's current provider state, depending on the code path.

Currently, `regeneratePlaylist()` uses `state.tasteProfile` (the stored profile from last generation), so this is partially safe. But if the stored profile is null (cold start), it falls back to `ref.read(tasteProfileNotifierProvider)` which now returns Profile B. The behavior is inconsistent.

**Prevention:**
1. **Clear playlist generation state when the active profile changes.** Watch for profile selection changes and reset to idle state.
2. **Or: always use the stored profile for regeneration** and only use the provider for fresh generation. This is almost the current behavior but needs the null-fallback case handled.

**Detection:**
Test: generate playlist, switch profile, tap Shuffle. Verify the regeneration uses the correct profile (either the original or the newly selected, but not a mix).

**Phase to address:**
Profile management phase.

**Confidence:** MEDIUM -- the code paths are visible but the impact depends on how often users switch profiles after generating.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Regeneration reliability | Race condition: providers not loaded when `generatePlaylist()` reads them (#1) | Add async readiness guard or persist generation inputs across cold starts |
| Regeneration reliability | Silent error swallowing in `_load()` (#8) | Add error handling to fire-and-forget async loads |
| Onboarding flow | Redirect loop or flash when checking async onboarding state (#2) | Load onboarding state in `main()` before router init, or use splash screen |
| Onboarding flow | Cold-start latency for first playlist generation (#4) | Pre-fetch curated data during onboarding, pass data directly to generator |
| Onboarding flow | Separate onboarding flag desyncs from actual data (#6) | Derive onboarding status from data existence, not separate boolean |
| Onboarding flow | Back navigation leaves partial state (#9) | Save all onboarding data at end, or make each step independently valuable |
| Profile management | JSON deserialization crash on unknown enum values (#3) | Add `orElse` to all enum `fromJson` methods |
| Profile management | Unclear which profile is active during generation (#5) | Make active profile prominent in generation UI |
| Profile management | `copyWith` cannot clear nullable fields (#7) | Use sentinel pattern or construct new objects |
| Profile management | Profile deletion while playlist uses that profile (#10) | Clear generation state on profile change |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Regeneration fix:** "Shuffle" button works after generation, but fails on cold start because `state.runPlan` is null -- test by force-stopping app and tapping Shuffle immediately
- [ ] **Onboarding:** Redirect works in debug mode (SharedPreferences is instant) but flashes in release on slow devices -- test with simulated delay
- [ ] **Onboarding:** First-time user completes onboarding and generates a playlist, but the generation uses empty provider state because save-then-read hasn't completed -- test end-to-end fresh install flow
- [ ] **Profile migration:** Legacy single-profile users upgrade smoothly, but users with corrupted JSON see empty profile list without error -- test with truncated JSON in SharedPreferences
- [ ] **Profile migration:** `RunningGenre.fromJson` and `EnergyLevel.fromJson` crash on unknown values instead of using fallbacks -- test with unrecognized enum string
- [ ] **Multi-profile:** Selecting a different taste profile updates the provider state, but a previously generated playlist still displays using the old profile's scoring -- verify playlist screen re-reads on profile switch
- [ ] **Onboarding skip:** User who presses "Skip" on onboarding should reach a functional app state, not a broken state with no run plan and no taste profile -- verify skip path leads to usable home screen
- [ ] **Back navigation:** Pressing back during multi-step onboarding does not corrupt partial state -- verify each step's state is properly managed

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Regeneration race condition (#1) | LOW | Add null check + retry with delay; or persist last-used run plan/profile to SharedPreferences |
| Onboarding redirect loop (#2) | LOW | Add route guard check for onboarding path; move async check to `main()` |
| Profile data loss from JSON parsing (#3) | MEDIUM | Add fallback `orElse` to all enum deserializers; add try-catch wrapper around `loadAll()`; cannot recover already-lost data |
| Cold-start first generation (#4) | LOW | Add curated-only fast path for first generation; pre-warm caches during onboarding |
| Profile selection confusion (#5) | LOW | UI change only; make profile name more prominent on generation screen |
| Onboarding flag desync (#6) | LOW | Switch to derived state check; remove separate boolean flag |
| copyWith null clearing (#7) | LOW | Use sentinel pattern in copyWith, or construct new objects directly |
| Silent error in _load() (#8) | LOW | Add try-catch in `_load()`; optionally add error field to state |
| Partial onboarding state (#9) | LOW | Persist data only at end of flow; or accept partial state gracefully |
| Profile deletion mid-playlist (#10) | LOW | Clear generation state when active profile changes |

## Sources

- [Riverpod issue #57: Initialize StateNotifierProvider with async data](https://github.com/rrousselGit/riverpod/issues/57) -- canonical discussion of async initialization patterns
- [Riverpod issue #2506: Race condition with AutoDisposeAsyncNotifierProvider](https://github.com/rrousselGit/riverpod/issues/2506) -- documented race condition in provider lifecycle
- [go_router issue #133746: Black screen with async redirect](https://github.com/flutter/flutter/issues/133746) -- async redirect causes unwanted black screen
- [go_router issue #118061: Infinite redirect loops](https://github.com/flutter/flutter/issues/118061) -- redirect loop causing stack overflow
- [go_router issue #105808: Support asynchronous redirects](https://github.com/flutter/flutter/issues/105808) -- async redirect support discussion
- [Flutter Explained: Onboarding with Riverpod, SharedPreferences, and GoRouter](https://flutterexplained.com/p/flutter-onboarding-with-riverpod) -- onboarding implementation pattern (with pitfalls noted)
- [Code with Andrea: Robust App Initialization Flow with Riverpod](https://codewithandrea.com/articles/robust-app-initialization-riverpod/) -- async initialization best practices
- [Code with Andrea: Loading/Error States with StateNotifier](https://codewithandrea.com/articles/loading-error-states-state-notifier-async-value/) -- AsyncValue pattern for StateNotifier
- [Flutter issue #95013: SharedPreferences race condition on Android](https://github.com/flutter/flutter/issues/95013) -- data loss from concurrent SharedPreferences writes
- [Flutter issue #53414: SharedPreferences value lost on app restart](https://github.com/flutter/flutter/issues/53414) -- persistence reliability issues

---
*Pitfalls research for: v1.2 Profile Management, Onboarding, and Regeneration Reliability -- Running Playlist AI*
*Researched: 2026-02-06*
