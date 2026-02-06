# Project Research Summary

**Project:** Running Playlist AI - v1.2 Profile Management & Onboarding
**Domain:** Multi-profile taste management, user onboarding, playlist regeneration reliability
**Researched:** 2026-02-06
**Confidence:** HIGH

## Executive Summary

v1.2 represents a UX refinement milestone building on top of fully functional v1.1 multi-profile infrastructure. The research reveals a critical discovery: the multi-profile architecture (TasteProfileLibraryNotifier, profile CRUD, selection, persistence, library UI) is already shipped. This dramatically reduces scope—v1.2 is not about building multi-profile support, but about polishing what exists and adding first-run onboarding to guide new users through the app's 3-step setup sequence (stride → run plan → taste profile → generate).

The recommended approach is zero new dependencies. Flutter + Riverpod 2.x manual providers + GoRouter + SharedPreferences handles everything v1.2 needs. Onboarding uses GoRouter redirect with a pre-loaded flag from main.dart. Regeneration reliability is fixed by adding a shufflePlaylist() method that reuses the stored songPool instead of re-fetching from the API. The taste profile library needs only UX polish (better empty state copy, delete confirmation dialogs).

Key risks center on async initialization race conditions: providers load asynchronously from SharedPreferences while screens consume them synchronously. This causes intermittent failures when users navigate to /playlist?auto=true before RunPlanLibraryNotifier finishes loading. The fix is straightforward—either persist generation inputs across cold starts or add explicit readiness guards—but must be addressed before onboarding, since the onboarding completion flow leads directly to playlist generation.

## Key Findings

### Recommended Stack

**No new dependencies required.** All v1.2 features build on the existing stack.

The existing Flutter 3.38 + Dart 3.10 + Riverpod 2.x + GoRouter 17.x + SharedPreferences 2.5.4 stack is comprehensive and stable. Adding libraries for onboarding (smooth_page_indicator, introduction_screen) or profile management (uuid, drift, freezed) would create maintenance burden for zero functional gain.

**Core technologies:**
- **GoRouter 17.x redirect** — First-run onboarding gate; synchronous redirect callback checks pre-loaded flag
- **SharedPreferences** — All persistence (onboarding_complete bool, profile library JSON, run plan library JSON)
- **Flutter PageView** — Built-in onboarding step-through UI with LinearProgressIndicator for progress
- **Riverpod StateNotifier** — Existing TasteProfileLibraryNotifier already implements full multi-profile CRUD

**Critical discovery:** Multi-profile infrastructure is not v1.2 scope—it's already done. TasteProfileLibraryNotifier, TasteProfilePreferences (with legacy migration), TasteProfileLibraryScreen, profile selector on playlist screen, and parallel RunPlanLibraryNotifier all shipped in v1.1. v1.2 is UX refinement, not architecture.

### Expected Features

**Must have (table stakes):**
- **Taste profile library polish** — Backend complete, needs visual consistency with run plan library cards, better empty state guidance
- **Profile selector on playlist screen** — Already implemented (_TasteProfileSelector widget), verify selection state propagates correctly
- **Reliable regeneration** — Fix async initialization race where generatePlaylist() reads null providers before load completes
- **Delete confirmation dialogs** — Both libraries allow destructive delete with single tap, need confirmation for profile/plan deletion

**Should have (competitive advantage):**
- **First-launch onboarding flow** — 4-screen action-oriented flow (welcome → pace → genres → auto-generate first playlist in under 60 seconds)
- **Smart home screen** — Context-aware content based on setup state (no profiles → onboarding prompt; profiles exist → regenerate card)
- **Profile templates/presets** — Pre-populated profiles ("High Energy Pop," "Chill Electronic," "Hip-Hop Power") reduce cold-start friction
- **Quick-switch profile chips** — Lift existing selector widgets to home screen for one-tap profile switching

**Defer (v2+):**
- **Account system/cloud sync** — App is intentionally local-first; export/import JSON is simpler bridge if needed
- **Spotify profile import** — Brittle OAuth flow, API restrictions make this unreliable (Nov 2024 changes)
- **Complex onboarding analytics** — Premature optimization; validate with 3-5 real user tests instead

### Architecture Approach

The app follows a clean feature-based architecture with Riverpod 2.x manual providers (code-gen broken with Dart 3.10). Each feature has data/domain/presentation/providers layers. Persistence uses SharedPreferences with JSON serialization via static wrapper classes. Navigation uses GoRouter with flat routes and query parameters for behavior (?auto=true, ?id=xxx).

**Major components:**
1. **TasteProfileLibraryNotifier** (EXISTING) — Full CRUD + selection for multiple named profiles; loads asynchronously from SharedPreferences in constructor via fire-and-forget _load()
2. **Onboarding flow** (NEW) — GoRouter redirect guard + OnboardingFlowScreen coordinator that checks provider state (profiles.isEmpty? → create step) and reuses existing screens
3. **PlaylistGenerationNotifier.shufflePlaylist()** (NEW) — Fast regeneration reusing state.songPool with new Random seed instead of re-fetching from API

**Key architectural decisions:**
- **Onboarding flag pre-loaded in main.dart** — GoRouter redirect is synchronous; pre-load SharedPreferences bool before ProviderScope initialization to avoid async redirect pitfalls
- **Reuse existing screens during onboarding** — TasteProfileScreen, RunPlanScreen already have full UX; onboarding shell controls navigation, no simplified "onboarding versions"
- **Shuffle vs Generate separation** — shufflePlaylist() reuses stored songPool (instant), generatePlaylist() fetches fresh (respects current provider selections)

### Critical Pitfalls

1. **Regeneration race condition** — PlaylistGenerationNotifier reads runPlanNotifierProvider/tasteProfileNotifierProvider before their async _load() completes. On cold start, providers return null, causing "No run plan saved" error despite data existing. Fix by persisting generation inputs (runPlan, tasteProfile, songPool) across cold starts, or add explicit readiness guard before generatePlaylist().

2. **Onboarding redirect loop/flash** — GoRouter redirect is synchronous but SharedPreferences is async. Checking onboarding_complete flag inside redirect causes flash (shows home screen while loading) or infinite loop (redirect fires for /onboarding and sees stale false value). Fix by pre-loading flag in main.dart before GoRouter initialization and passing via provider override.

3. **Taste profile JSON migration drops data** — RunningGenre.fromJson() and EnergyLevel.fromJson() use firstWhere without orElse, throwing StateError on unknown enum values (version mismatch, future upgrade/downgrade). Fix by adding orElse fallbacks to ALL enum deserializers and wrapping loadAll() in try-catch.

4. **Onboarding cold-start latency** — First playlist generation after onboarding requires async load of just-saved profile, async load of just-saved plan, network fetch from GetSongBPM API, curated repository load (3-tier), and runnability data load. Multiple async operations compound, making worst first impression. Fix by pre-fetching curated data during onboarding setup or passing onboarding data directly to generator instead of save-then-reload roundtrip.

5. **Silent error swallowing in _load()** — Both RunPlanLibraryNotifier and TasteProfileLibraryNotifier call _load() fire-and-forget in constructor with no error handling. If SharedPreferences throws or JSON parse fails, error is silently consumed and app behaves as if user has no data. Fix by adding try-catch inside _load() with error state field or migrate to AsyncNotifier with built-in error handling.

## Implications for Roadmap

Based on research, v1.2 should be structured in 3 phases, not 4. The multi-profile implementation is complete—verification and polish can merge into a single phase.

### Phase 1: Regeneration Reliability Fix
**Rationale:** Smallest scope (one new method + UI wire), no dependencies, fixes only actual bug in v1.2 scope. Good confidence builder before larger onboarding work.

**Delivers:**
- shufflePlaylist() method that reuses state.songPool with new Random seed (instant shuffle, no API calls)
- generatePlaylist() verification that it reads current provider selections correctly
- Fix for intermittent "No run plan" error on auto-generate after cold start

**Addresses:** Table stakes "reliable regeneration" feature

**Avoids:** Pitfall #1 (race condition) and Pitfall #5 (silent error swallowing in _load())

**Complexity:** Low (~30 lines of new code + test coverage)

### Phase 2: Multi-Profile Verification & Polish
**Rationale:** Infrastructure exists but needs quality assurance and UX polish. Merges "verification" and "polish" into one phase since the backend is proven and only needs surface-level improvements.

**Delivers:**
- Test coverage for TasteProfileLibraryNotifier (add, update, select, delete) and TasteProfilePreferences (persistence, legacy migration)
- Integration tests verifying profile selection propagates correctly to playlist generation
- Delete confirmation dialogs for both taste profiles and run plans
- Improved empty state copy with contextual guidance
- Verification that profile switching on playlist screen triggers correct regeneration context

**Uses:** Existing TasteProfileLibraryNotifier, TasteProfileLibraryScreen, RunPlanLibraryNotifier

**Implements:** UX polish layer on top of completed multi-profile architecture

**Addresses:** Table stakes "profile library polish," "delete confirmation," "empty state guidance"

**Avoids:** Pitfall #3 (JSON migration edge cases), Pitfall #7 (copyWith null clearing), Pitfall #10 (profile deletion while active)

**Complexity:** Low-Medium (mostly test writing, may surface minor bugs)

### Phase 3: Onboarding Flow
**Rationale:** Most new code, depends on profile/plan creation working correctly (Phase 2), introduces new feature directory and router modifications. Must come last since onboarding completion leads directly to playlist generation (depends on Phase 1 reliability fix).

**Delivers:**
- OnboardingPreferences (SharedPreferences wrapper for completion flag)
- onboarding_providers.dart (StateProvider for completion state)
- main.dart modification to pre-load flag before GoRouter initialization
- router.dart redirect guard + /onboarding route with allow-list for onboarding sub-routes
- OnboardingWelcomeScreen (welcome page)
- OnboardingFlowScreen (step coordinator checking provider states: profiles.isEmpty? → create step)
- Profile templates/presets (optional quick-start)
- Smart home screen with context-aware content (no profiles → setup prompt, profiles exist → regenerate card)

**Addresses:** Differentiators "first-launch onboarding," "smart home screen," "profile templates"

**Avoids:** Pitfall #2 (redirect loop/flash), Pitfall #4 (cold-start latency), Pitfall #6 (onboarding flag desync), Pitfall #9 (partial state on back nav)

**Complexity:** Medium (~150-200 lines across 4-5 new files)

### Phase Ordering Rationale

- **Regeneration fix first** because it's the only actual bug, has no dependencies, and validates the shufflePlaylist pattern before more complex work
- **Profile verification second** because onboarding depends on profile creation working reliably; testing multi-profile edge cases uncovers issues before building on top
- **Onboarding last** because it's the largest feature, introduces new architectural patterns (redirect guard, pre-loaded state), and its completion flow exercises both Phase 1 (generation) and Phase 2 (profile creation)

This ordering follows dependency chain (reliability → data layer → presentation layer) and risk profile (simple fix → testing → new feature).

### Research Flags

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Regeneration):** Well-understood Riverpod StateNotifier pattern; shufflePlaylist is straightforward method addition
- **Phase 2 (Profile Polish):** All infrastructure exists; this is QA and UI tweaks, not greenfield development
- **Phase 3 (Onboarding):** GoRouter redirect pattern is documented; SharedPreferences pre-loading in main.dart is proven pattern (CodeWithAndrea article); no novel patterns

**No phases need /gsd:research-phase during planning.** All patterns are documented (GoRouter redirect, Riverpod StateNotifier, SharedPreferences pre-load, PageView onboarding). The technical approach is proven by existing run plan library pattern.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Direct codebase analysis confirms all dependencies present and stable; no new packages needed |
| Features | MEDIUM-HIGH | Table stakes verified against existing run plan library; differentiators validated against competitor apps (Spotify, RockMyRun, PaceDJ); some features (onboarding time-to-first-playlist) estimated not measured |
| Architecture | HIGH | Multi-profile infrastructure discovered via direct code inspection; GoRouter redirect pattern documented; SharedPreferences pre-load pattern proven in community articles |
| Pitfalls | HIGH | Race conditions identified through direct code review (RunPlanLibraryNotifier._load() visible); GoRouter async redirect issues documented in GitHub issues #133746, #118061; JSON deserialization risks visible in taste_profile.dart |

**Overall confidence:** HIGH

The research is grounded in direct codebase analysis (not inference), official documentation (GoRouter, Riverpod), and documented issues (GitHub issues, community articles). The critical discovery that multi-profile infrastructure already exists was verified by reading all relevant provider, persistence, and presentation files.

### Gaps to Address

**Gap 1: Onboarding completion analytics**
Competitor time-to-first-playlist metrics are estimates from flow descriptions, not measured. The 60-second target for our onboarding is reasonable (Spotify: 30s for 3 artists, RockMyRun: 45s genre browse, PaceDJ: 60s library scan) but should be validated with real users during Phase 3.

**Mitigation:** Manual testing with 3-5 users, stopwatch timing from app launch to first playlist generated. If > 90 seconds, add profile templates as default quick-start options.

**Gap 2: SharedPreferences async load timing on slow devices**
The race condition is confirmed but its frequency on real devices (especially older Android) is unknown. It may be rare enough that the current _autoGenTriggered polling pattern is sufficient, or it may be pervasive enough to require architecture change.

**Mitigation:** During Phase 1, add telemetry (debug logs) to measure time between provider creation and _load() completion. If > 500ms on test devices, prioritize persisting generation inputs (runPlan, tasteProfile, songPool) to SharedPreferences instead of lighter guard-based fixes.

**Gap 3: Legacy single-profile migration edge cases**
The migration from taste_profile (single) to taste_profile_library (array) is implemented and tested for happy path, but edge cases (corrupted JSON, concurrent load calls, unknown enum values) are identified but not verified in production.

**Mitigation:** During Phase 2, add comprehensive test coverage for all identified edge cases (truncated JSON, unknown enum strings, rapid successive loadAll() calls) and add orElse fallbacks to RunningGenre/EnergyLevel/MusicDecade.fromJson().

## Sources

### Primary (HIGH confidence)
- Direct codebase analysis: taste_profile_providers.dart, taste_profile_preferences.dart, taste_profile_library_screen.dart, taste_profile_screen.dart, playlist_providers.dart, playlist_screen.dart, router.dart, main.dart, run_plan_providers.dart, run_plan_library_screen.dart
- [GoRouter official docs v17.1.0](https://pub.dev/packages/go_router) — redirect callback, refreshListenable
- [SharedPreferences v2.5.4 changelog](https://pub.dev/packages/shared_preferences/changelog)
- [Flutter Riverpod StateNotifier pattern](https://riverpod.dev/docs/concepts/providers#statenotifierprovider)

### Secondary (MEDIUM confidence)
- [CodeWithAndrea: Robust App Initialization with Riverpod](https://codewithandrea.com/articles/robust-app-initialization-riverpod/) — AppStartupWidget pattern, eager initialization
- [VWO Mobile App Onboarding Guide 2026](https://vwo.com/blog/mobile-app-onboarding-guide/) — Action-oriented vs tutorial onboarding, engagement metrics
- [Plotline App Onboarding Examples 2026](https://www.plotline.so/blog/mobile-app-onboarding-examples) — Progressive disclosure patterns
- [CleverTap App Onboarding Examples](https://clevertap.com/blog/app-onboarding/) — Spotify 3-artist pattern, MyFitnessPal goal-first pattern
- [GoRouter onboarding redirect pattern](https://dev.to/kcl/onboarding-with-go-router-in-flutter-2jd6) — Community tutorial demonstrating pre-load pattern

### Tertiary (LOW confidence, needs validation)
- Competitor time-to-first-playlist estimates (Spotify 30s, RockMyRun 45s, PaceDJ 60s) — inferred from app descriptions, not measured
- Onboarding completion rate improvement (5x engagement, 80%+ completion) — cited from VWO research but not specific to running apps

---
*Research completed: 2026-02-06*
*Ready for roadmap: yes*
