# Home Island (village hub) art brief — hand to your ComfyUI assistant

The home island is a large SCROLLING village hub (~7 screens) where the sisters
start, level up, buy items, and launch the hot-air balloon. It's built in LAYERS:
a tileable ground that repeats to fill the world, plus separate transparent object
sprites (buildings, props, later NPCs) placed on top in the engine. So DON'T make
one giant image — make tileable ground + individual transparent pieces.

Use the same soft storybook style block as the rest of the game.

**Style block (prepend to each SUBJECT):**
> hand-drawn indie cartoon illustration, soft storybook watercolor with thick wobbly
> ink outlines, warm muted palette with bright color pops, whimsical and friendly,
> textured hand-painted shading with subtle paper grain, simple bold shapes

**Negative (every gen):** photorealistic, 3d render, anime, smooth vector gradients,
scary, creepy, gross, harsh shadows, text, watermark, blurry

**Perspective rule (important for consistency):**
- GROUND/terrain = flat **top-down**, even lighting, NO shadows, NO border.
- BUILDINGS & PROPS = drawn **front-on at a slight top-down (3/4) angle**, with a
  small soft shadow at the base, on a **transparent background**, single object
  centered — "as seen in a top-down storybook game."

---

## 1. Ground tiles (MUST be seamless/tileable — enable tiling mode in ComfyUI)
Each **1024×1024**, opaque, top-down, flat even light, no shadow, no border, edges
wrap seamlessly.
- `grass.png` > seamless tileable top-down grassy meadow ground, gentle painterly
  grass with subtle variation
- `path.png` > seamless tileable top-down worn dirt path / trail ground
- `plaza.png` > seamless tileable top-down cobblestone-and-wood town-square ground

## 2. Landmarks (transparent building sprites, ~1024×1024)
- `store.png` > a charming small cartoon GENERAL STORE building, front view at a
  slight top-down angle, wooden walls, striped awning, a hanging shop sign, door and
  window, barrels and crates out front, small soft shadow at the base
- `balloon_station.png` > a wooden hot-air-balloon LAUNCH platform/dock with a big
  colorful hot-air balloon tethered above it ready to ride, boarding ramp and ropes,
  small soft shadow at the base

## 3. Props (transparent, ~512–768, centered, slight 3/4 angle, small base shadow)
Generate each separately: `tree.png`, `bush.png`, `rock.png`, `fence.png` (one
straight segment), `signpost.png`, `lamp.png`, `flowerbed.png`, `market_stall.png`,
`barrel.png`, `well.png`.

## 4. Island edge (optional, for the floating look) — transparent
- `cliff_edge.png` > a floating-island cliff edge seen from the front: grassy top,
  brown rocky cliff underside tapering down, a few wisps of cloud below, **tileable
  horizontally** so edges can repeat along the island border

---

## Delivery
Save with the exact filenames above. Start with **grass.png + store.png +
balloon_station.png** so we can lay out a first walkable village; the props and path
tiles come next. The engine side (scrolling camera, world size, collision, enter-
store / use-balloon zones, NPC placement) is handled in code — these are just the
art pieces.
