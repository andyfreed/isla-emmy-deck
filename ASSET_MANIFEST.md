# Art Asset Manifest — Isla & Emmy: Funky Islands

Hand-drawn storybook cartoon style, consistent across every asset, PNG. The project
is aligned to this manifest — drop files at the paths below and they load with no
code changes. More assets coming (areas, enemies, UI, animation); handling is built
to extend (new area = new `assets/<area>/` folder).

## Where files go in this repo
| Manifest group | Drop into |
|---|---|
| Characters + pickup items | `assets/` (isla, emmy, present, snack, heart, logo) |
| Home island ground/landmarks/props/edges | `assets/home_island/` |
| Enemies | `assets/enemies/` (e.g. grumpy.png; more to come) |
| Steam store art (NOT in game) | `steam/` (capsule, banner, icon, logo) |

## Conventions (implemented in engine)
- **Ground tiles** = opaque, seamless/tileable 1024×1024, flat top-down; used as a
  repeating texture fill for the island.
- **Sprites** (characters/items/props/landmarks) = transparent, one object centered,
  drawn front-on at a slight 3/4 angle with a soft base shadow baked in. Engine
  anchors them **bottom-center** and **Y-sorts** them (lower on screen = in front).
- **cliff_edge.png** = transparent, tiles HORIZONTALLY along the island rim (~1536×640).
- Sizes are source res; engine downscales (stays crisp on Deck).

## Files
**Characters (`assets/`)** — transparent, full-body, face viewer:
`isla.png` (hero 1, blonde/pink), `emmy.png` (hero 2, brown/teal).
(Idle/walk animation frames: not made yet — request when needed.)

**Pickup/UI items (`assets/`)** — transparent:
`present.png`, `snack.png`, `heart.png`.

**Home island ground (`assets/home_island/`)** — opaque seamless tileable 1024×1024:
`grass.png`, `path.png`, `plaza.png`, `dirt.png`, `pond.png`.

**Home island landmarks (`assets/home_island/`)** — transparent ~1024², bottom-center:
`store.png` (enter-store zone), `balloon_station.png` (use-balloon zone).

**Home island props (`assets/home_island/`)** — transparent ~768², bottom-center, base shadow:
`tree.png`, `bush.png`, `rock.png`, `fence.png` (one segment — repeat for runs),
`signpost.png`, `lamp.png`, `flowerbed.png`, `market_stall.png`, `barrel.png`, `well.png`.

**Home island edge/extras (`assets/home_island/`)** — transparent:
`cliff_edge.png` (~1536×640, tiles horizontally), `island_chunk.png` (optional distant island).

**Steam store (`steam/`)** — store listing only, not in world:
`capsule.png` (600×900), `banner.png` (1920×620), `icon.png` (512×512), `logo.png`.

## Engine responsibilities (not art)
Organic island shape, scrolling camera, collision, enter-store / use-balloon trigger
zones, Y-sorting. Fence is one segment — repeated in code to build fence lines.
Need a new asset? Describe it; the art side produces it in this exact style.
