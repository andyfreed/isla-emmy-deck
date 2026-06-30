#!/usr/bin/env bash
# Sync finished art from the Dropbox FINAL folders into the game's assets.
# Run from the repo:  bash scripts/pull-art.sh   (then: git add -A && commit && push)
#
# Pulls ONLY from each area's FINAL/ folder (the art AI's "game-ready" set), so
# work-in-progress variants never leak into the game.
set -euo pipefail
SRC="$HOME/Dropbox/Andy/funky_islands"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

copy() {  # $1 = source FINAL dir, $2 = destination in repo
	if [ -d "$1" ] && ls "$1"/*.png >/dev/null 2>&1; then
		mkdir -p "$2"
		cp "$1"/*.png "$2"/
		echo "synced  $(ls "$1"/*.png | wc -l | tr -d ' ') file(s):  ${1#$SRC/} -> ${2#$REPO/}"
	else
		echo "skip (none):  ${1#$SRC/}"
	fi
}

copy "$SRC/FINAL"              "$REPO/assets"              # characters + UI items
copy "$SRC/home_island/FINAL"  "$REPO/assets/home_island"
copy "$SRC/enemies/FINAL"      "$REPO/assets/enemies"     # Moon-zodiac creatures
copy "$SRC/steam/FINAL"        "$REPO/steam"              # store art (not in-world)
echo "done — review with: git status"
