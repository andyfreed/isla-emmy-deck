# Steam library art brief — hand to your ComfyUI assistant

Same soft storybook style + style block as ART_BRIEF.md. These are for the Steam
Deck library presentation of "Isla & Emmy: Funky Islands" (added as a non-Steam
game). Generate at the listed sizes (or larger, same aspect, then downscale).

## Pieces needed
1. **Capsule / box art** — portrait **600×900** (rounded to e.g. 1024×1536 then downscale).
   > SUBJECT: cover art — both sisters Isla (blonde, pink overalls) and Emmy
   > (brunette, teal outfit) together, smiling, standing on a colorful floating
   > grassy island in the sky with a few more islands behind, warm sunny sky,
   > leave clear space at the TOP for a title logo. Full storybook scene, opaque.

2. **Hero banner** — wide **1920×620**.
   > SUBJECT: wide banner — Isla & Emmy on their floating island with the island
   > chain and hot-air balloon in the distance, cheerful, lots of sky, characters
   > on the left third, open space on the right. Opaque.

3. **Logo** — transparent PNG, title treatment of **"Isla & Emmy: Funky Islands"**.
   > Hand-lettered playful bubbly title, thick wobbly ink outline matching the
   > game's storybook style, warm colors, slight bounce/arch to the letters,
   > transparent background. (If text rendering is unreliable, generate a blank
   > decorative banner/ribbon and we'll set the text in a font.)

4. **Icon** — square **512×512**, transparent: a simple emblem (e.g. the two
   sisters' heads, or a single zodiac symbol + island).

## Fallback for the logo font (if not hand-drawn)
Chunky friendly fonts that fit: **Fredoka**, **Baloo 2**, **Luckiest Guy**,
**Titan One** (all free, Google Fonts).

## Setting the art on the Deck
Right-click the game in the Steam library → **Manage → Set Custom Artwork**, then
pick: the portrait for the grid, the hero, the logo, the icon. (Can also be
automated by dropping files into Steam's `userdata/<id>/config/grid/` — ask if you
want that wired into install.sh later.)
