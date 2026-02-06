---
phase: 21
plan: 02
subsystem: onboarding
tags: [home-screen, empty-states, context-aware-ui, taste-profile, run-plan]
requires:
  - 21-01 (onboarding flow creates profiles and plans)
provides:
  - Context-aware home screen that guides users to complete missing setup
  - Active profile name display on regenerate card
affects: []
tech-stack:
  added: []
  patterns:
    - Context-aware empty state pattern with conditional setup cards
key-files:
  created: []
  modified:
    - lib/features/home/presentation/home_screen.dart
key-decisions:
  - Setup cards use secondaryContainer color to visually distinguish from regenerate card
  - Profile name shown inline in regenerate card subtitle (not separate widget)
  - Extracted reusable _SetupCard private widget for DRY setup prompts
patterns-established:
  - Conditional empty-state cards above persistent navigation buttons
duration: 1m
completed: 2026-02-06
---

# Phase 21 Plan 02: Home Screen Context-Aware States Summary

Context-aware empty states on home screen using conditional setup cards for missing taste profile / run plan, with active profile name in regenerate card

## Performance

- Duration: ~1 minute
- Tasks: 1/1 completed
- Deviations: 0

## Accomplishments

1. **Taste profile watch** -- Added `tasteProfileNotifierProvider` watch to HomeScreen for null-checking profile existence
2. **Setup cards** -- Two conditional cards (music taste + run plan) shown when respective data is missing, using `secondaryContainer` color and arrow_forward_ios trailing icon
3. **Profile name display** -- When both profile and plan exist, regenerate card subtitle shows "Profile: {name}" (or "Unnamed" for null names)
4. **Reusable _SetupCard widget** -- Extracted private StatelessWidget for consistent setup card styling across both prompts
5. **All states covered** -- Fresh (no profile + no plan), partial (one missing), and complete (both exist) states all handled correctly

## Task Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Add context-aware empty states to home screen | 9f40171 | home_screen.dart |

## Files Modified

- `lib/features/home/presentation/home_screen.dart` -- Added tasteProfile watch, conditional setup cards, profile name in regenerate subtitle, extracted _SetupCard widget (67 lines added, 4 removed)

## Decisions Made

1. **secondaryContainer color for setup cards**: Visually distinguishes setup prompts from the default-colored regenerate card, making it clear these are action items.
2. **Inline profile name in subtitle**: Rather than adding a separate row/widget, the profile name is appended to the regenerate card subtitle with a newline. Keeps the UI compact.
3. **_SetupCard extraction**: Both setup cards share identical structure, so a private widget avoids duplication and ensures consistent styling.

## Deviations from Plan

None -- plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

- Phase 21 (onboarding) is now complete -- both plans delivered
- Home screen correctly shows context-aware states based on profile/plan existence
- No blockers or concerns

## Self-Check: PASSED
