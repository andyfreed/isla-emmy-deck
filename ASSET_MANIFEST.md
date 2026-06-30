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

## Scale & proportions (the #1 thing)
- **Target resolution:** 1280×800 (16:10, Steam Deck). Backgrounds / full-screen UI to this.
- **Ground tiles** render **~512px on screen** (~2.5 across the width). Source 1024² is
  perfect — engine displays at half. Draw grass/path detail to read at that size.
- **Proportion reference = the SISTER (≈170px tall on screen = 1.0 unit).** Keep
  everything proportional to her:

  | Object | × sister | ≈ px on screen |
  |---|---|---|
  | Sister (Isla/Emmy) | 1.0 | 170 |
  | Enemy (overworld) | ~1.6 | 270 |
  | Tree | ~1.95 | 330 |
  | Store (building) | ~2.6 | 440 |
  | Balloon station | ~3.0 | 520 |
  | Bush | ~0.7 | 120 |
  | Rock | ~0.55 | 95 |
  | Well | ~0.9 | 150 |
  | Signpost | ~0.8 | 140 |
  | Lamp | ~1.2 | 200 |
  | Market stall | ~1.4 | 240 |
  | Barrel | ~0.6 | 100 |
  | Flowerbed | ~0.5 | 85 |
  | Fence (1 segment) | ~0.7 tall | 120 |

  The engine sets each object's final height to these values, so exact source
  canvas size doesn't matter (assets are autocropped + scaled) — keep the
  **proportions** in this ballpark. Generate big things (store/balloon) at higher
  res (~1536) to stay crisp. Battle view reuses the same sprites scaled up — no
  separate battle art needed.

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
