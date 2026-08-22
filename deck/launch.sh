#!/usr/bin/env bash
# Isla & Emmy: Funky Islands — self-updating launcher for Steam Deck.
#
# This is what you add to Steam ONCE as a non-Steam game. Every time you launch
# it from your Steam library, it checks GitHub for a newer build, downloads it
# if there is one, and runs the game. No keyboard, no reinstalling — ever.
#
# NOTE: the repo must stay PUBLIC — these downloads are unauthenticated, and a
# private repo turns every check into a silent 404 (learned the hard way).
set -uo pipefail

REPO="andyfreed/isla-emmy-deck"
DIR="$HOME/Games/isla-emmy"
BIN="$DIR/isla-emmy.x86_64"
URL="https://github.com/$REPO/releases/latest/download/isla-emmy.x86_64"
SELF="$DIR/launch.sh"
SELF_URL="https://raw.githubusercontent.com/$REPO/main/deck/launch.sh"

mkdir -p "$DIR"

# keep the launcher itself fresh, so launcher fixes reach installed Decks too
if [ "${1:-}" != "--updated" ] && [ -f "$SELF" ]; then
    if curl -fsL --connect-timeout 5 -z "$SELF" -o "$SELF.new" "$SELF_URL" \
            && [ -s "$SELF.new" ] && head -1 "$SELF.new" | grep -q bash; then
        chmod +x "$SELF.new"
        mv "$SELF.new" "$SELF"
        exec "$SELF" --updated
    fi
    rm -f "$SELF.new"
fi

echo "[isla-emmy] checking for updates..."
ZOPT=()
[ -f "$BIN" ] && ZOPT=(-z "$BIN")            # only download if remote is newer
CODE="$(curl -fL --connect-timeout 10 "${ZOPT[@]}" -o "$BIN.new" -w "%{http_code}" "$URL")" || CODE=000
if [ "$CODE" = "200" ] && [ -s "$BIN.new" ]; then
    mv "$BIN.new" "$BIN"
    chmod +x "$BIN"
    echo "[isla-emmy] updated to latest build."
else
    rm -f "$BIN.new"
    if [ "$CODE" = "304" ]; then
        echo "[isla-emmy] already up to date."
    else
        # a real failure (offline, 404, ...) must NOT masquerade as "current"
        echo "[isla-emmy] WARNING: update check failed (HTTP $CODE) — running the installed build."
    fi
fi

if [ ! -x "$BIN" ]; then
    echo "[isla-emmy] ERROR: no game binary and could not download one (HTTP $CODE). Are you online?"
    sleep 5
    exit 1
fi

exec "$BIN"
