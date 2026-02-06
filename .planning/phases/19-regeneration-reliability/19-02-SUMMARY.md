# Plan 19-02 Summary

**Status:** Complete
**Commit:** 19c1244
**Duration:** ~2m

## What Was Done

1. **_PlaylistView dual callbacks** -- Changed from single `onRegenerate` to separate `onShuffle` and `onGenerate` callbacks.
2. **Shuffle button wired** -- The "Shuffle" button in the summary header now calls `shufflePlaylist()` (instant, no spinner, no API).
3. **Generate button added** -- New "Generate" button placed next to the run plan + taste profile selectors. Calls `generatePlaylist()` for a fresh fetch with current selections.
4. **Empty state** -- "Try Again" in empty-songs view calls `onGenerate` (full regeneration).

## UX Flow

- **Shuffle**: Re-arrange current songs instantly (same pool, new order)
- **Generate**: Fetch fresh songs from API/curated with current selector values
- **Selectors**: Change run plan or taste profile, then tap Generate

## Artifacts

| File | Change |
|------|--------|
| playlist_screen.dart | Dual callbacks, Generate button, Shuffle wiring |
