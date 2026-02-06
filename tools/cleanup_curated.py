#!/usr/bin/env python3
"""Clean curated_songs.json: keep only verified data, strip made-up fields.

- Removes songs not found on Deezer (167)
- Replaces BPM with Deezer value (or null if Deezer BPM=0)
- Replaces duration with Deezer value
- Derives decade from Deezer release_date
- Strips: danceability, energyLevel, runnability (all made up)
- Keeps: genre (unverified but no API source available — kept for scoring)

Re-fetches Deezer track data for release_date. Saves progress.
"""

import json
import os
import subprocess
import sys
import time
import urllib.parse

CURATED_PATH = os.path.join(
    os.path.dirname(__file__), '..', 'assets', 'curated_songs.json'
)
VERIFICATION_PATH = os.path.join(os.path.dirname(__file__), 'bpm_verification.json')
TRACK_CACHE_PATH = os.path.join(os.path.dirname(__file__), 'deezer_tracks.json')
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), 'curated_songs_clean.json')
REPORT_PATH = os.path.join(os.path.dirname(__file__), 'cleanup_report.txt')

API_DELAY = 0.35
SAVE_INTERVAL = 50


def _curl_json(url):
    try:
        result = subprocess.run(
            ['curl', '-s', '--max-time', '10', url],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode != 0:
            return None
        return json.loads(result.stdout)
    except (subprocess.TimeoutExpired, json.JSONDecodeError, OSError):
        return None


def release_date_to_decade(release_date):
    """Convert '2005-11-21' to '2000s'."""
    if not release_date:
        return None
    try:
        year = int(release_date[:4])
        decade_start = (year // 10) * 10
        return f'{decade_start}s'
    except (ValueError, IndexError):
        return None


def main():
    with open(CURATED_PATH) as f:
        songs = json.load(f)
    with open(VERIFICATION_PATH) as f:
        verification = json.load(f)

    # Load track cache (for release_date)
    if os.path.exists(TRACK_CACHE_PATH):
        with open(TRACK_CACHE_PATH) as f:
            track_cache = json.load(f)
    else:
        track_cache = {}

    print(f'Loaded {len(songs)} curated songs')
    print(f'Track cache: {len(track_cache)} entries')

    def make_key(s):
        return f"{s['artistName'].lower().strip()}|{s['title'].lower().strip()}"

    # Phase 1: Fetch full track data for release_date where we have deezer_id
    need_fetch = []
    for song in songs:
        key = make_key(song)
        v = verification.get(key, {})
        if v.get('status') != 'ok':
            continue
        deezer_id = str(v.get('deezer_id', ''))
        if deezer_id and deezer_id not in track_cache:
            need_fetch.append((key, deezer_id))

    print(f'Need to fetch {len(need_fetch)} tracks for release_date')

    for i, (key, deezer_id) in enumerate(need_fetch):
        data = _curl_json(f'https://api.deezer.com/track/{deezer_id}')
        time.sleep(API_DELAY)

        if data and 'error' not in data:
            track_cache[deezer_id] = {
                'release_date': data.get('release_date'),
                'bpm': data.get('bpm', 0),
                'duration': data.get('duration', 0),
            }

        if (i + 1) % SAVE_INTERVAL == 0:
            with open(TRACK_CACHE_PATH, 'w') as f:
                json.dump(track_cache, f)
            print(f'  [{i+1}/{len(need_fetch)}] fetched')

    # Final save
    with open(TRACK_CACHE_PATH, 'w') as f:
        json.dump(track_cache, f)

    # Phase 2: Build clean dataset
    clean = []
    removed_not_found = 0
    bpm_from_deezer = 0
    bpm_null = 0
    decade_from_deezer = 0
    decade_kept_original = 0
    duration_from_deezer = 0

    for song in songs:
        key = make_key(song)
        v = verification.get(key, {})

        # Remove songs not found on Deezer
        if v.get('status') != 'ok':
            removed_not_found += 1
            continue

        deezer_id = str(v.get('deezer_id', ''))
        track = track_cache.get(deezer_id, {})

        # BPM: use Deezer value, or null if unavailable
        dz_bpm = v.get('deezer_bpm', 0)
        if dz_bpm and dz_bpm > 0:
            bpm = round(dz_bpm)
            bpm_from_deezer += 1
        else:
            bpm = None
            bpm_null += 1

        # Duration: use Deezer value
        dz_dur = v.get('deezer_duration', 0)
        if dz_dur and dz_dur > 0:
            duration = dz_dur
            duration_from_deezer += 1
        else:
            duration = song.get('durationSeconds')

        # Decade: derive from Deezer release_date
        release_date = track.get('release_date')
        decade = release_date_to_decade(release_date)
        if decade:
            decade_from_deezer += 1
        else:
            decade = song.get('decade')
            if decade:
                decade_kept_original += 1

        entry = {
            'title': song['title'],
            'artistName': song['artistName'],
            'genre': song['genre'],
        }
        if bpm is not None:
            entry['bpm'] = bpm
        if duration is not None:
            entry['durationSeconds'] = duration
        if decade is not None:
            entry['decade'] = decade

        clean.append(entry)

    with open(OUTPUT_PATH, 'w') as f:
        json.dump(clean, f, indent=2, ensure_ascii=False)

    # Report
    report_lines = [
        'Curated Songs Cleanup Report',
        '============================',
        f'Original songs:      {len(songs)}',
        f'Clean songs:         {len(clean)}',
        f'Removed (not found): {removed_not_found}',
        '',
        'BPM:',
        f'  From Deezer:       {bpm_from_deezer}',
        f'  Null (no data):    {bpm_null}',
        '',
        'Duration:',
        f'  From Deezer:       {duration_from_deezer}',
        '',
        'Decade:',
        f'  From Deezer:       {decade_from_deezer}',
        f'  Kept original:     {decade_kept_original}',
        '',
        'Removed fields: danceability, energyLevel, runnability',
        'Kept unverified: genre (no API source available)',
    ]
    report = '\n'.join(report_lines)
    print(f'\n{report}')

    with open(REPORT_PATH, 'w') as f:
        f.write(report + '\n')

    print(f'\nClean dataset: {OUTPUT_PATH}')
    print(f'Report: {REPORT_PATH}')


if __name__ == '__main__':
    main()
