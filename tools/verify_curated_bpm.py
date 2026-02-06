#!/usr/bin/env python3
"""Verify curated_songs.json BPM and duration against Deezer API.

Usage:
    python3 tools/verify_curated_bpm.py

Outputs:
    tools/bpm_report.txt        - Human-readable mismatch report
    tools/curated_songs_corrected.json - Corrected dataset (auto-fixed where Deezer has data)
    tools/bpm_verification.json - Full verification data (for debugging)

Rate limiting: ~300ms between API calls. ~3,084 songs = ~30 min total.
Saves progress every 50 songs so you can Ctrl+C and resume.
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
PROGRESS_PATH = os.path.join(os.path.dirname(__file__), 'bpm_progress.json')
REPORT_PATH = os.path.join(os.path.dirname(__file__), 'bpm_report.txt')
CORRECTED_PATH = os.path.join(os.path.dirname(__file__), 'curated_songs_corrected.json')
VERIFICATION_PATH = os.path.join(os.path.dirname(__file__), 'bpm_verification.json')

BPM_TOLERANCE = 3       # BPM difference to flag as mismatch
DURATION_TOLERANCE = 15  # seconds difference to flag
API_DELAY = 0.35         # seconds between API calls
SAVE_INTERVAL = 50       # save progress every N songs


def _curl_json(url: str) -> dict | None:
    """Fetch a URL with curl and parse as JSON."""
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


def deezer_search(artist: str, title: str) -> dict | None:
    """Search Deezer for a track, return first result or None."""
    query = f'{artist} {title}'
    url = f'https://api.deezer.com/search?q={urllib.parse.quote(query)}&limit=3'
    data = _curl_json(url)
    if data is None:
        return None
    results = data.get('data', [])
    if not results:
        return None

    # Try to find best match by checking artist name similarity
    artist_lower = artist.lower().strip()
    for r in results:
        r_artist = r.get('artist', {}).get('name', '').lower().strip()
        if artist_lower in r_artist or r_artist in artist_lower:
            return r
    # Fall back to first result
    return results[0]


def deezer_track(track_id: int) -> dict | None:
    """Get full track details including BPM."""
    url = f'https://api.deezer.com/track/{track_id}'
    data = _curl_json(url)
    if data is None or 'error' in data:
        return None
    return data


def load_progress() -> dict:
    """Load saved progress, or empty dict."""
    if os.path.exists(PROGRESS_PATH):
        with open(PROGRESS_PATH) as f:
            return json.load(f)
    return {}


def save_progress(progress: dict):
    with open(PROGRESS_PATH, 'w') as f:
        json.dump(progress, f)


def make_key(song: dict) -> str:
    return f"{song['artistName'].lower().strip()}|{song['title'].lower().strip()}"


def main():
    with open(CURATED_PATH) as f:
        songs = json.load(f)

    print(f'Loaded {len(songs)} curated songs')

    # Load any saved progress
    progress = load_progress()
    print(f'Resuming with {len(progress)} already verified')

    total = len(songs)
    mismatches = []
    no_data = []
    not_found = []
    verified_ok = []

    for i, song in enumerate(songs):
        key = make_key(song)

        # Skip if already verified
        if key in progress:
            result = progress[key]
        else:
            # Search + fetch from Deezer
            search_result = deezer_search(song['artistName'], song['title'])
            time.sleep(API_DELAY)

            if search_result is None:
                result = {'status': 'not_found'}
                progress[key] = result
            else:
                track = deezer_track(search_result['id'])
                time.sleep(API_DELAY)

                if track is None:
                    result = {'status': 'not_found'}
                else:
                    result = {
                        'status': 'ok',
                        'deezer_id': track.get('id'),
                        'deezer_title': track.get('title', ''),
                        'deezer_artist': track.get('artist', {}).get('name', ''),
                        'deezer_bpm': track.get('bpm', 0),
                        'deezer_duration': track.get('duration', 0),
                    }
                progress[key] = result

            # Save progress periodically
            if (i + 1) % SAVE_INTERVAL == 0:
                save_progress(progress)
                pct = (i + 1) / total * 100
                print(f'  [{i+1}/{total}] ({pct:.0f}%) - saved progress')

        # Categorize
        if result['status'] == 'not_found':
            not_found.append(song)
            continue

        dz_bpm = result.get('deezer_bpm', 0)
        dz_dur = result.get('deezer_duration', 0)

        if dz_bpm == 0:
            no_data.append({**song, '_deezer': result})
            continue

        bpm_diff = abs(song['bpm'] - round(dz_bpm))
        dur_diff = abs(song['durationSeconds'] - dz_dur) if dz_dur > 0 else 0

        if bpm_diff > BPM_TOLERANCE:
            mismatches.append({
                **song,
                '_deezer': result,
                '_bpm_diff': bpm_diff,
                '_dur_diff': dur_diff,
            })
        else:
            verified_ok.append(key)

    # Final save
    save_progress(progress)

    # --- Generate report ---
    print(f'\n=== VERIFICATION COMPLETE ===')
    print(f'Total songs:     {total}')
    print(f'Verified OK:     {len(verified_ok)}')
    print(f'BPM mismatch:    {len(mismatches)}')
    print(f'Deezer BPM=0:    {len(no_data)}')
    print(f'Not found:       {len(not_found)}')

    # Sort mismatches by severity
    mismatches.sort(key=lambda m: m['_bpm_diff'], reverse=True)

    with open(REPORT_PATH, 'w') as f:
        f.write(f'BPM Verification Report\n')
        f.write(f'=======================\n')
        f.write(f'Total songs:     {total}\n')
        f.write(f'Verified OK:     {len(verified_ok)} (within +/-{BPM_TOLERANCE} BPM)\n')
        f.write(f'BPM mismatch:    {len(mismatches)}\n')
        f.write(f'Deezer BPM=0:    {len(no_data)} (no BPM data on Deezer)\n')
        f.write(f'Not found:       {len(not_found)} (not found on Deezer)\n\n')

        f.write(f'--- BPM MISMATCHES (sorted by severity) ---\n\n')
        for m in mismatches:
            dz = m['_deezer']
            f.write(
                f'{m["artistName"]} - {m["title"]}\n'
                f'  Curated BPM: {m["bpm"]:>5}  |  Deezer BPM: {round(dz["deezer_bpm"]):>5}'
                f'  |  Diff: {m["_bpm_diff"]:>3}\n'
            )
            if m['_dur_diff'] > DURATION_TOLERANCE:
                f.write(
                    f'  Curated dur: {m["durationSeconds"]:>5}s |  Deezer dur: {dz["deezer_duration"]:>5}s'
                    f'  |  Diff: {m["_dur_diff"]:>3}s\n'
                )
            f.write(
                f'  Deezer match: {dz["deezer_artist"]} - {dz["deezer_title"]}\n\n'
            )

        if not_found:
            f.write(f'\n--- NOT FOUND ON DEEZER ({len(not_found)}) ---\n\n')
            for s in not_found:
                f.write(f'  {s["artistName"]} - {s["title"]}\n')

        if no_data:
            f.write(f'\n--- DEEZER BPM=0 ({len(no_data)}) ---\n\n')
            for s in no_data:
                f.write(f'  {s["artistName"]} - {s["title"]} (curated BPM: {s["bpm"]})\n')

    print(f'Report written to: {REPORT_PATH}')

    # --- Generate corrected JSON ---
    corrected = []
    corrections_made = 0
    mismatch_keys = {make_key(m): m for m in mismatches}

    for song in songs:
        key = make_key(song)
        result = progress.get(key, {})

        corrected_song = dict(song)

        if key in mismatch_keys:
            dz_bpm = result.get('deezer_bpm', 0)
            dz_dur = result.get('deezer_duration', 0)

            if dz_bpm > 0:
                corrected_song['bpm'] = round(dz_bpm)
                corrections_made += 1
            if dz_dur > 0 and abs(song['durationSeconds'] - dz_dur) > DURATION_TOLERANCE:
                corrected_song['durationSeconds'] = dz_dur

        corrected.append(corrected_song)

    with open(CORRECTED_PATH, 'w') as f:
        json.dump(corrected, f, indent=2, ensure_ascii=False)

    print(f'Corrected JSON written to: {CORRECTED_PATH} ({corrections_made} BPM corrections)')

    # Save full verification data
    with open(VERIFICATION_PATH, 'w') as f:
        json.dump(progress, f, indent=2)

    print(f'Full verification data: {VERIFICATION_PATH}')
    print(f'\nDone! Review {REPORT_PATH} then copy corrected JSON to assets/')


if __name__ == '__main__':
    main()
