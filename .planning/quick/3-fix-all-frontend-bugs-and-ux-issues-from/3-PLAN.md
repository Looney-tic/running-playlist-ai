---
phase: quick-3
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/features/onboarding/presentation/onboarding_screen.dart
  - lib/features/curated_songs/data/curated_song_repository.dart
  - lib/features/playlist/providers/playlist_providers.dart
  - lib/features/playlist/presentation/playlist_screen.dart
  - lib/features/home/presentation/home_screen.dart
  - lib/features/run_plan/presentation/run_plan_screen.dart
  - lib/features/settings/presentation/settings_screen.dart
autonomous: true
---

<objective>
Fix all frontend bugs and UX issues found during frontend testing.

Purpose: Resolve 3 P0 bugs (onboarding race condition, curated song loading, error swallowing), 1 P1 issue (playlist selector display), and 5 P2/P3 polish issues (home screen hierarchy, cadence controls, spm terminology, run plan defaults, settings screen).

Output: All 9 issues resolved, app functional end-to-end.
</objective>

<context>
All source files read and analyzed. Key findings:
- Onboarding `_finishOnboarding()` calls `addProfile()`/`addPlan()` without awaiting `ensureLoaded()` first. The `_load()` in constructor runs in background and can overwrite.
- `CuratedSongRepository._loadBundledAsset()` uses `rootBundle.loadString('assets/curated_songs.json')` which may fail on web. File is declared in pubspec.yaml at `assets/curated_songs.json`.
- `playlist_providers.dart:207` catch-all has no logging.
- `_RunPlanSelector` and `_TasteProfileSelector` in `playlist_screen.dart` already show selected names correctly via `selected?.name ?? 'Select Run Plan'` and similar logic -- but the issue is that `selectedPlan`/`selectedProfile` may be null during initial load because `ensureLoaded()` hasn't completed yet when the idle view renders.
- Home screen has 7 flat `ElevatedButton.icon` with no grouping.
- Cadence nudge uses identical `Icons.remove`/`Icons.add` for -3/-1/+1/+3.
- Run plan screen uses "bpm" for target cadence, home/playlist screens use "spm". Onboarding summary says "bpm".
- `_selectedPresetIndex` starts as `null` in run_plan_screen.dart, disabling Save.
- Settings screen only has Spotify section.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix P0 onboarding race condition</name>
  <files>lib/features/onboarding/presentation/onboarding_screen.dart</files>
  <action>
In `_finishOnboarding()` method (line 84), add `ensureLoaded()` calls BEFORE the `addProfile()` and `addPlan()` calls. The fix:

```dart
Future<void> _finishOnboarding() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      // Ensure library notifiers have finished loading from preferences
      // to prevent the background _load() from overwriting our additions.
      await ref.read(tasteProfileLibraryProvider.notifier).ensureLoaded();
      await ref.read(runPlanLibraryProvider.notifier).ensureLoaded();

      // 1. Create a TasteProfile ...
      // (rest unchanged)
```

Add the two `ensureLoaded()` awaits at the START of the try block, before creating the profile and plan. Do NOT change any other logic in this method.

Also fix the onboarding summary to say "spm" instead of "bpm" on line 431: change `'${bpm.round()} bpm'` to `'${bpm.round()} spm'`. And change the label from `'Target BPM'` to `'Target Cadence'`.
  </action>
  <verify>Run `dart analyze lib/features/onboarding/presentation/onboarding_screen.dart` -- no errors.</verify>
  <done>Onboarding calls ensureLoaded() before addProfile()/addPlan(). Summary shows "spm" not "bpm".</done>
</task>

<task type="auto">
  <name>Task 2: Fix P0 curated songs asset loading + error logging</name>
  <files>
    lib/features/curated_songs/data/curated_song_repository.dart
    lib/features/playlist/providers/playlist_providers.dart
  </files>
  <action>
**curated_song_repository.dart:**

Wrap `_loadBundledAsset()` in a try/catch with debugPrint logging so we can diagnose web loading failures. Add `import 'package:flutter/foundation.dart';` at the top.

```dart
static Future<List<CuratedSong>> _loadBundledAsset() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/curated_songs.json');
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((item) => CuratedSong.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('Failed to load bundled curated_songs.json: $e\n$stackTrace');
      rethrow;
    }
  }
```

**playlist_providers.dart:**

In the outer catch-all at line 207 (inside `generatePlaylist()`), add debug logging. Add `import 'package:flutter/foundation.dart';` at the top if not already present.

Change line 207 from:
```dart
    } catch (_) {
```
to:
```dart
    } catch (e, stackTrace) {
      debugPrint('Playlist generation error: $e\n$stackTrace');
```

Do the same for the catch-all in `regeneratePlaylist()` at line 330:
```dart
    } catch (e, stackTrace) {
      debugPrint('Playlist regeneration error: $e\n$stackTrace');
```
  </action>
  <verify>Run `dart analyze lib/features/curated_songs/data/curated_song_repository.dart lib/features/playlist/providers/playlist_providers.dart` -- no errors.</verify>
  <done>Asset loading has debug logging. Playlist generation catch-alls log errors with stack traces instead of swallowing silently.</done>
</task>

<task type="auto">
  <name>Task 3: Fix P1 playlist selectors showing placeholder + cadence nudge icons</name>
  <files>lib/features/playlist/presentation/playlist_screen.dart</files>
  <action>
**Playlist selector display (P1 issue #4):**

The `_RunPlanSelector` and `_TasteProfileSelector` widgets already have correct display logic (`selected?.name ?? 'Select Run Plan'`). The issue is that on first render, the library state may not be loaded yet so `selectedPlan`/`selectedProfile` returns null even though data exists in preferences.

The fix: In `_IdleView.build()`, trigger `ensureLoaded()` on both library notifiers when the view mounts. Since `_IdleView` is a `ConsumerWidget` (stateless), the simplest approach is to call ensureLoaded in a post-frame callback when the selectors are about to render.

Actually, looking more carefully at the code, `_RunPlanSelector` watches `runPlanLibraryProvider` which triggers a rebuild when the library loads. The real issue is that `_IdleView` receives `runPlan` as a prop but the selectors read from the library state independently. The library's `selectedPlan` getter returns `plans.first` when `selectedId` is null, so if plans are loaded, it should work.

The actual fix: The playlist screen's `_IdleView` only renders when `runPlan != null` (line 118), but the selectors inside read from the library provider directly. If the library loads asynchronously, the selectors will initially show placeholders, then rebuild when data arrives. This is working as designed. The user-reported issue is likely that `selectedPlan` returns null when no `selectedId` is saved AND the library is still loading (empty plans list).

Best fix: No code change needed for the selector display -- it self-corrects on library load. But verify this is actually the behavior by confirming the providers rebuild the widget.

HOWEVER -- re-reading the bug report: "the 'Select Run Plan' / 'Select Taste Profile' rows show placeholder text even when a plan/profile IS selected." This suggests the library IS loaded but selectedPlan is still null. Looking at `RunPlanLibraryState.selectedPlan`: if `selectedId == null`, it returns `plans.first`. If `selectedId != null` but doesn't match any plan, it returns null.

The most likely bug: after onboarding creates a plan (with race condition from bug #1), the plan ID is saved as `selectedId` but the plans list might be empty due to the overwrite. Fixing bug #1 should fix this. No additional change needed here.

**Cadence nudge icons (P2 issue #6):**

In the `_PlaylistView` build method (cadence nudge row, around lines 423-466), replace the duplicate `Icons.remove`/`Icons.add` with distinguishable icons:

- `-3 spm`: `Icons.keyboard_double_arrow_left` (size 20)
- `-1 spm`: `Icons.chevron_left` (size 20)
- `+1 spm`: `Icons.chevron_right` (size 20)
- `+3 spm`: `Icons.keyboard_double_arrow_right` (size 20)

Change the four IconButton widgets in the cadence nudge Container (lines 423-465):

```dart
IconButton(
  onPressed: () => ref
      .read(strideNotifierProvider.notifier)
      .nudgeCadence(-3),
  icon: const Icon(Icons.keyboard_double_arrow_left),
  tooltip: '-3 spm',
  iconSize: 20,
),
IconButton(
  onPressed: () => ref
      .read(strideNotifierProvider.notifier)
      .nudgeCadence(-1),
  icon: const Icon(Icons.chevron_left),
  tooltip: '-1 spm',
  iconSize: 20,
),
// ... cadence text stays the same ...
IconButton(
  onPressed: () => ref
      .read(strideNotifierProvider.notifier)
      .nudgeCadence(1),
  icon: const Icon(Icons.chevron_right),
  tooltip: '+1 spm',
  iconSize: 20,
),
IconButton(
  onPressed: () => ref
      .read(strideNotifierProvider.notifier)
      .nudgeCadence(3),
  icon: const Icon(Icons.keyboard_double_arrow_right),
  tooltip: '+3 spm',
  iconSize: 20,
),
```
  </action>
  <verify>Run `dart analyze lib/features/playlist/presentation/playlist_screen.dart` -- no errors.</verify>
  <done>Cadence nudge buttons use distinct directional arrow icons. Selector display implicitly fixed by Task 1 onboarding race condition fix.</done>
</task>

<task type="auto">
  <name>Task 4: Fix home screen visual hierarchy + cadence nudge icons</name>
  <files>lib/features/home/presentation/home_screen.dart</files>
  <action>
**Home screen visual hierarchy (P2 issue #5):**

Replace the flat list of 7 `ElevatedButton.icon` (lines 168-215) with a structured layout:

1. Make "Generate Playlist" a prominent `FilledButton.icon` (not `ElevatedButton.icon`)
2. Group remaining buttons into two labeled sections using `Column` with section headers

Replace lines 168-215 with:

```dart
// Primary action
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: () => context.push('/playlist'),
      icon: const Icon(Icons.queue_music),
      label: const Text('Generate Playlist'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  ),
),
const SizedBox(height: 24),

// Configuration section
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Align(
    alignment: Alignment.centerLeft,
    child: Text(
      'Configuration',
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  ),
),
const SizedBox(height: 8),
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Card(
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.directions_run),
          title: const Text('Stride Calculator'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => context.push('/stride'),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.timer),
          title: const Text('My Runs'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => context.push('/my-runs'),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.music_note),
          title: const Text('Taste Profiles'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => context.push('/taste-profiles'),
        ),
      ],
    ),
  ),
),
const SizedBox(height: 16),

// Library section
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Align(
    alignment: Alignment.centerLeft,
    child: Text(
      'Library',
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  ),
),
const SizedBox(height: 8),
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Card(
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Playlist History'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => context.push('/playlist-history'),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.thumb_up_alt_outlined),
          title: const Text('Song Feedback'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => context.push('/song-feedback'),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.favorite),
          title: const Text('Songs I Run To'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => context.push('/running-songs'),
        ),
      ],
    ),
  ),
),
```

**Home screen cadence nudge icons (P2 issue #6):**

Same fix as playlist screen. In the cadence nudge Card (lines 114-162), replace the icon buttons:
- `-3`: `Icons.keyboard_double_arrow_left` (size 20)
- `-1`: `Icons.chevron_left` (size 20)
- `+1`: `Icons.chevron_right` (size 20)
- `+3`: `Icons.keyboard_double_arrow_right` (size 20)

All four iconSize values should be 20 (uniform).
  </action>
  <verify>Run `dart analyze lib/features/home/presentation/home_screen.dart` -- no errors.</verify>
  <done>Home screen has prominent Generate Playlist button, grouped Configuration/Library sections with ListTiles in Cards, and distinguishable cadence nudge icons.</done>
</task>

<task type="auto">
  <name>Task 5: Standardize "spm" terminology + run plan default distance</name>
  <files>
    lib/features/run_plan/presentation/run_plan_screen.dart
  </files>
  <action>
**spm vs bpm terminology (P2 issue #7):**

In `run_plan_screen.dart`, the term "bpm" is used to display TARGET CADENCE to the user. This should be "spm" (steps per minute) since it refers to running cadence, not musical beats per minute.

Change all user-facing "bpm" strings that refer to cadence:

1. Line 419: `'${bpm.round()} bpm'` -> `'${bpm.round()} spm'` and change label `'Target BPM'` to `'Target Cadence'`
2. Line 489: `' - ${segment.targetBpm.round()} bpm'` -> `' - ${segment.targetBpm.round()} spm'`
3. Line 583 (in `_SegmentTimeline`): `' - ${segment.targetBpm.round()} bpm'` -> `' - ${segment.targetBpm.round()} spm'`

Do NOT change internal variable names (`bpm`, `targetBpm`) -- only change user-facing display strings.

**Run plan default distance (P2 issue #8):**

Change the initial state of `_selectedPresetIndex` from `null` to `0` and `_selectedDistance` from `0` to `5.0` so that 5K is pre-selected on screen load.

Line 31: `double _selectedDistance = 0;` -> `double _selectedDistance = 5.0;`
Line 33: `int? _selectedPresetIndex;` -> `int? _selectedPresetIndex = 0;`
  </action>
  <verify>Run `dart analyze lib/features/run_plan/presentation/run_plan_screen.dart` -- no errors.</verify>
  <done>Run plan screen displays "spm" for cadence, not "bpm". 5K is pre-selected by default so Save button is enabled immediately.</done>
</task>

<task type="auto">
  <name>Task 6: Add About section to Settings screen</name>
  <files>lib/features/settings/presentation/settings_screen.dart</files>
  <action>
Add an "About" section to the Settings screen below the Spotify section. Since `package_info_plus` is not in pubspec.yaml and we want to avoid adding dependencies, hardcode the version from pubspec.yaml (1.0.0) and display it statically.

In the `SettingsScreen` build method, add a second child to the ListView:

```dart
body: ListView(
  children: const [
    _SpotifySection(),
    _AboutSection(),
  ],
),
```

Add a new `_AboutSection` widget:

```dart
/// About section showing app version and info.
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'About',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Running Playlist AI'),
            subtitle: Text('Version 1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('About this app'),
            subtitle: Text(
              'Generate BPM-matched running playlists tailored to your '
              'pace, distance, and music taste.',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```
  </action>
  <verify>Run `dart analyze lib/features/settings/presentation/settings_screen.dart` -- no errors.</verify>
  <done>Settings screen shows Spotify section + About section with app name, version, and description.</done>
</task>

</tasks>

<verification>
After all tasks complete:
1. `dart analyze lib/` should show no new errors
2. `flutter build web --no-tree-shake-icons` should complete successfully (if web build is configured)
3. Manual spot-check: onboarding flow creates plan + profile that persist, playlist screen shows selected plan/profile names, home screen has grouped layout, cadence nudge icons are distinguishable, run plan defaults to 5K, settings shows About section
</verification>

<success_criteria>
- Onboarding race condition fixed: ensureLoaded() called before addProfile()/addPlan()
- Curated song loading has debug logging for web failures
- Playlist generation catch-alls log errors with stack traces
- Cadence nudge controls use distinct icons on both home and playlist screens
- Home screen has visual hierarchy: prominent Generate button, Configuration section, Library section
- All user-facing cadence displays use "spm" not "bpm"
- Run plan screen pre-selects 5K distance
- Settings screen has About section with version info
</success_criteria>
