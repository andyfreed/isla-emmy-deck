#!/usr/bin/env bash
# Isla & Emmy: Funky Islands — ONE-TIME Steam Deck setup.
#
# Run this once in Desktop Mode (Konsole). It installs the self-updating
# launcher and registers a desktop entry so the game shows up in Steam's
# "Add a Non-Steam Game" list with its icon — just tick it and add.
#
#   curl -sL https://raw.githubusercontent.com/andyfreed/isla-emmy-deck/main/deck/install.sh | bash
set -euo pipefail

REPO="andyfreed/isla-emmy-deck"
RAW="https://raw.githubusercontent.com/$REPO/main"
DIR="$HOME/Games/isla-emmy"
APPS="$HOME/.local/share/applications"

echo "==> Installing Isla & Emmy launcher into $DIR"
mkdir -p "$DIR" "$APPS"

curl -fsSL -o "$DIR/launch.sh" "$RAW/deck/launch.sh"
chmod +x "$DIR/launch.sh"

# icon for the Steam entry
curl -fsSL -o "$DIR/icon.png" "$RAW/icon.png" || true

# Steam library artwork (capsule / banner / icon / logo) for Set Custom Artwork
mkdir -p "$DIR/art"
for f in capsule banner icon logo; do
    curl -fsSL -o "$DIR/art/$f.png" "$RAW/steam/$f.png" || true
done

# desktop entry -> appears in Steam's Add-Non-Steam-Game list
cat > "$APPS/isla-emmy.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Isla & Emmy: Funky Islands
Comment=Co-op explorer for Isla and Emmy
Exec=$DIR/launch.sh
Icon=$DIR/icon.png
Terminal=false
Categories=Game;
EOF
chmod +x "$APPS/isla-emmy.desktop"
update-desktop-database "$APPS" 2>/dev/null || true

# pre-fetch the current build so the first launch is instant (optional)
echo "==> Pre-downloading the current game build..."
"$DIR/launch.sh" >/dev/null 2>&1 &
sleep 1; kill %1 2>/dev/null || true

cat <<'DONE'

==========================================================
  ✅  Installed!  Two clicks left (no typing):

  1. Open Steam (Desktop Mode) → bottom-left "Add a Game"
     → "Add a Non-Steam Game".
  2. In the list, tick  "Isla & Emmy: Funky Islands"
     → "Add Selected Programs".

  Now switch to Game Mode — it's in your library under
  NON-STEAM. Launch it like any game; it auto-updates
  itself from GitHub every time you open it.

  OPTIONAL — pretty Steam library art:
  Right-click the game -> Manage -> Set Custom Artwork,
  and pick from  ~/Games/isla-emmy/art/  :
    capsule.png (grid)  banner.png (hero)
    logo.png (logo)     icon.png (icon)
==========================================================
DONE
