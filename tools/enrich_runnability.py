#!/usr/bin/env python3
"""Compute runnability scores (0-100) for all curated songs.

Combines crowd signal data (source_count from 2,611 extracted running playlist
songs) with feature-based estimation (genre, danceability, BPM) to produce a
single runnability score for each of the 5,066 curated songs.

Usage:
    python3 tools/enrich_runnability.py
"""

import json
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

CURATED_PATH = os.path.join(PROJECT_ROOT, "assets", "curated_songs.json")
EXTRACTED_PATH = (
    "/private/tmp/claude-501/-Users-tijmen-running-playlist-ai/"
    "d4738303-92e4-4aa7-a132-232dbf10fcb2/scratchpad/extracted_songs.json"
)

# ── Genre bonus mapping (0-20) ──
GENRE_BONUS = {
    "electronic": 20, "edm": 20, "house": 20, "drumAndBass": 20,
    "pop": 16, "dance": 16, "kPop": 16, "hipHop": 16,
    "rock": 13, "punk": 13, "latin": 13, "funk": 13,
    "indie": 10, "rnb": 10, "metal": 10,
}
DEFAULT_GENRE_BONUS = 8


def bpm_bonus(bpm):
    """Compute BPM bonus (0-8) based on running BPM research."""
    if bpm is None:
        return 4  # neutral
    if 120 <= bpm <= 149:
        return 8  # prime running zone
    if 150 <= bpm <= 179:
        return 7  # fast running
    if 90 <= bpm <= 119:
        return 5  # could be double-time
    if 80 <= bpm <= 89:
        return 4  # half-time sweet spot
    return 2


def danceability_bonus(danceability):
    """Compute danceability bonus (0-12)."""
    if danceability is None:
        return 6  # neutral
    return min(danceability / 100.0, 1.0) * 12


def feature_score(genre, danceability, bpm):
    """Compute feature-based score (0-40)."""
    g = GENRE_BONUS.get(genre, DEFAULT_GENRE_BONUS)
    d = danceability_bonus(danceability)
    b = bpm_bonus(bpm)
    return min(g + d + b, 40)


def main():
    # Load data
    with open(EXTRACTED_PATH) as f:
        extracted = json.load(f)
    with open(CURATED_PATH) as f:
        curated = json.load(f)

    # Build crowd lookup: normalized key -> source_count
    crowd_map = {}
    for song in extracted:
        key = f"{song['artistName'].lower().strip()}|{song['title'].lower().strip()}"
        # Keep the highest source_count if duplicates exist
        if key not in crowd_map or song.get("source_count", 0) > crowd_map[key]:
            crowd_map[key] = song.get("source_count", 0)

    print(f"Loaded {len(extracted)} extracted songs -> {len(crowd_map)} unique lookup keys")
    print(f"Loaded {len(curated)} curated songs")

    # Compute runnability for each curated song
    crowd_matched = 0
    scores = []

    for song in curated:
        key = f"{song['artistName'].lower().strip()}|{song['title'].lower().strip()}"
        source_count = crowd_map.get(key)

        genre = song.get("genre")
        danceability = song.get("danceability")
        bpm = song.get("bpm")

        feat = feature_score(genre, danceability, bpm)

        if source_count is not None:
            # Crowd + feature scoring
            crowd_matched += 1
            crowd_score = min(source_count / 15.0, 1.0) * 60
            runnability = round(crowd_score + feat)
        else:
            # Feature-only scoring (caps at 40)
            runnability = round(feat)

        # Clamp to 0-100
        runnability = max(0, min(100, runnability))
        song["runnability"] = runnability
        scores.append(runnability)

    # Write back
    with open(CURATED_PATH, "w") as f:
        json.dump(curated, f, indent=2)
        f.write("\n")

    # Print summary
    print(f"\nResults:")
    print(f"  Total songs:       {len(curated)}")
    print(f"  Crowd matched:     {crowd_matched}")
    print(f"  Feature-only:      {len(curated) - crowd_matched}")
    print(f"  Avg runnability:   {sum(scores) / len(scores):.1f}")
    print(f"  Min runnability:   {min(scores)}")
    print(f"  Max runnability:   {max(scores)}")

    # Distribution histogram
    print(f"\nDistribution:")
    buckets = [0] * 10  # 0-9, 10-19, ..., 90-100
    for s in scores:
        bucket = min(s // 10, 9)
        buckets[bucket] += 1
    for i, count in enumerate(buckets):
        lo = i * 10
        hi = lo + 9 if i < 9 else 100
        bar = "#" * (count // 10)
        print(f"  {lo:3d}-{hi:3d}: {count:5d} {bar}")

    # Spot checks
    print(f"\nSpot checks:")
    for name in ["Lose Yourself", "Eye of the Tiger", "Stronger"]:
        matches = [s for s in curated if s["title"] == name]
        for m in matches:
            print(f"  {m['title']} ({m['artistName']}): runnability={m['runnability']}")


if __name__ == "__main__":
    main()
