#!/usr/bin/env bash
# Isla & Emmy: Funky Islands — self-updating launcher for Steam Deck.
#
# This is what you add to Steam ONCE as a non-Steam game. Every time you launch
# it from your Steam library, it checks GitHub for a newer build, downloads it
# if there is one, and runs the game. No keyboard, no reinstalling — ever.
set -uo pipefail

REPO="andyfreed/isla-emmy-deck"
DIR="$HOME/Games/isla-emmy"
BIN="$DIR/isla-emmy.x86_64"
URL="https://github.com/$REPO/releases/latest/download/isla-emmy.x86_64"

mkdir -p "$DIR"

echo "[isla-emmy] checking for updates..."
ZOPT=()
[ -f "$BIN" ] && ZOPT=(-z "$BIN")            # only download if remote is newer
if curl -fL --connect-timeout 10 "${ZOPT[@]}" -o "$BIN.new" "$URL" && [ -s "$BIN.new" ]; then
    mv "$BIN.new" "$BIN"
    chmod +x "$BIN"
    echo "[isla-emmy] updated to latest build."
else
    rm -f "$BIN.new"
    echo "[isla-emmy] no update (offline or already current)."
fi

if [ ! -x "$BIN" ]; then
    echo "[isla-emmy] ERROR: no game binary and could not download one. Are you online?"
    sleep 5
    exit 1
fi

exec "$BIN"
