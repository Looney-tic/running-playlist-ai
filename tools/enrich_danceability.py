#!/usr/bin/env python3
"""Enrich curated_songs.json with heuristic danceability scores.

Uses genre-based baselines from Spotify/academic research averages,
modulated by BPM proximity to the 120-130 danceability sweet spot.
Small per-song variance added using a deterministic seed (artist+title hash)
to avoid all songs in the same genre having identical scores.

This produces reasonable estimates that can be replaced with real audio
feature data when API access becomes available (e.g., GetSongBPM, ReccoBeats).

References:
- Karageorghis et al. (2012): rhythm regularity is the #1 predictor
- Spotify genre averages (pre-deprecation)
- Moelants (2002): 120-130 BPM = peak synchronization zone
"""

import json
import hashlib
import sys
from pathlib import Path

# Genre-based danceability baselines (0-100 scale)
# Derived from Spotify average danceability by genre tag
GENRE_DANCEABILITY = {
    "electronic": 70,
    "edm": 72,
    "house": 74,
    "drumAndBass": 62,  # fast breakbeat, less steady 4-on-floor
    "pop": 68,
    "dance": 75,
    "kPop": 70,
    "hipHop": 73,
    "rock": 48,
    "punk": 42,
    "latin": 72,
    "funk": 70,
    "rnb": 62,
    "metal": 35,
    "indie": 52,
}


def bpm_modifier(bpm: int | None) -> int:
    """BPM-based danceability modifier.

    Songs near the 120-130 BPM sweet spot get a boost.
    Very fast or very slow songs get a penalty.
    Based on Moelants (2002) peak synchronization zone.
    """
    if bpm is None:
        return 0
    if 115 <= bpm <= 135:
        return 5  # Sweet spot
    if 95 <= bpm <= 145:
        return 2  # Good zone
    if 80 <= bpm <= 160:
        return 0  # Acceptable
    return -5  # Far from danceability zone


def deterministic_variance(artist: str, title: str) -> int:
    """Deterministic per-song variance (-4 to +4) based on name hash.

    Ensures reproducibility while adding realistic spread.
    """
    key = f"{artist.lower().strip()}|{title.lower().strip()}"
    h = int(hashlib.md5(key.encode()).hexdigest()[:8], 16)
    return (h % 9) - 4  # -4 to +4


def compute_danceability(song: dict) -> int:
    """Compute heuristic danceability (0-100) for a curated song."""
    genre = song.get("genre", "")
    bpm = song.get("bpm")

    # Genre baseline (default 55 for unknown genres)
    baseline = GENRE_DANCEABILITY.get(genre, 55)

    # BPM modifier
    modifier = bpm_modifier(bpm)

    # Deterministic per-song variance
    variance = deterministic_variance(
        song.get("artistName", ""), song.get("title", "")
    )

    # Clamp to 0-100
    return max(0, min(100, baseline + modifier + variance))


def main():
    assets_path = Path(__file__).parent.parent / "assets" / "curated_songs.json"

    if not assets_path.exists():
        print(f"Error: {assets_path} not found", file=sys.stderr)
        sys.exit(1)

    with open(assets_path) as f:
        songs = json.load(f)

    print(f"Loaded {len(songs)} songs")

    # Stats tracking
    already_had = 0
    enriched = 0
    by_genre = {}

    for song in songs:
        if song.get("danceability") is not None:
            already_had += 1
            continue

        dance = compute_danceability(song)
        song["danceability"] = dance
        enriched += 1

        genre = song.get("genre", "unknown")
        by_genre.setdefault(genre, []).append(dance)

    # Print stats
    print(f"Already had danceability: {already_had}")
    print(f"Enriched: {enriched}")
    print(f"\nDanceability by genre (mean / min / max):")
    for genre in sorted(by_genre.keys()):
        vals = by_genre[genre]
        avg = sum(vals) / len(vals)
        print(f"  {genre:15s}: {avg:5.1f}  ({min(vals)}-{max(vals)})  [{len(vals)} songs]")

    # Write back
    with open(assets_path, "w") as f:
        json.dump(songs, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"\nWritten enriched data to {assets_path}")


if __name__ == "__main__":
    main()
