# Art Generation Brief — "Isla & Emmy: Funky Islands"
### Hand this whole file to your ComfyUI assistant.

You are helping generate game art for a small **2D top-down explorer game** (Godot
4.7, runs on Steam Deck). The game is a gentle, no-lose co-op-style toy for two
young sisters; single-player with a character select between two heroes, **Isla**
and **Emmy**. I am not an artist — I need you to drive the ComfyUI side. We will
work in a loop: you generate, I bring results back to my coding assistant who
wires them into the game, and we refine.

The #1 requirement is **STYLE CONSISTENCY** across every asset.

---

## 1. Target style
**Edmund McMillen / "Mewgenics" hand-drawn cartoon style — the cute, charming end of it.**

- Thick, slightly wobbly hand-inked **black outlines**.
- Big expressive cartoon **eyes**, exaggerated **large-head** cute proportions.
- **Textured, hand-painted shading** with subtle paper grain — NOT flat clean vector.
- Warm, slightly muted **storybook palette** with bright pops of color.
- Whimsical, full of personality, **cute and friendly** (important: avoid the
  gross/creepy/horror side of this artist's work — this is for kids).
- Simple readable shapes, painterly texture, indie-cartoon-game feel.

**Reusable STYLE BLOCK** (paste into the positive prompt of every generation,
only changing the SUBJECT line):

> hand-drawn indie cartoon illustration in the style of Edmund McMillen and
> Mewgenics, thick wobbly black ink outlines, big expressive cartoon eyes,
> cute exaggerated large-head proportions, textured hand-painted shading with
> subtle paper grain, warm muted storybook palette with bright color pops,
> whimsical charming and friendly, simple bold shapes, high quality game art

**Negative prompt** (every generation):

> photorealistic, 3d render, anime, smooth vector gradients, realistic
> proportions, scary, creepy, gross, gore, blood, horror, text, watermark,
> signature, extra limbs, cropped, blurry

---

## 2. Consistency strategy (please set this up)
Apply as many of these as my setup supports, in priority order:

1. **Lock the pipeline.** Pick ONE checkpoint and ONE set of sampler settings and
   reuse them for EVERY asset. Don't change models mid-project. Suggested:
   an SDXL-based illustration/cartoon checkpoint. If I have a Pony/Illustrious
   model, those are great for characters.
2. **Style LoRA.** If a hand-drawn / grungy-cartoon / McMillen-ish / Binding-of-
   Isaac-style LoRA is available (Civitai), load it and keep it on for all assets.
   Tell me what to download if I don't have one.
3. **IPAdapter for character identity.** Once we approve the first hero image, use
   it as an **IPAdapter style/face reference** so the same character stays
   on-model across poses and so both sisters share one look.
4. **Fixed seed discipline.** Use a fixed seed while dialing a look; only
   randomize once the pipeline is locked.

---

## 3. Technical output specs (must follow — these go into a game engine)
- **Format:** PNG.
- **Transparency:** characters, items, and UI MUST have a **transparent
  background (clean alpha)**. Best: use **LayerDiffuse** for native transparent
  output. If unavailable, generate on a flat solid background and remove it with
  a background-removal node (RMBG / rembg / SAM).
- **Framing:** ONE subject, **centered**, **full body fully visible** with a small
  margin — nothing cropped at the edges.
- **View:** front-facing or slight 3/4 view (this is a top-down-ish game; the
  character is seen from the front/above).
- **Canvas:** square **1024×1024** for characters and items (I'll downscale in
  engine). Backgrounds/environment can be **1536×1024** or larger, opaque.
- **Lighting:** soft, even, top-light. No dramatic shadows. Consistent across all.
- **Naming:** save files exactly as the `filename:` given per asset below.

---

## 4. Asset list (generate in this order)

> Build the SUBJECT line into the STYLE BLOCK from section 1. Generate **Isla
> first**, we approve the look, THEN do the rest using her as the IPAdapter
> reference so everything matches.

**A. Isla (hero 1)** — `filename: isla.png` — transparent
> SUBJECT: a cute little girl hero named Isla, around 6 years old, round friendly
> face, big eyes, short bob or pigtails, wearing a **pink** dress or overalls,
> standing happily, full body, facing the viewer

**B. Emmy (hero 2)** — `filename: emmy.png` — transparent (use Isla as reference)
> SUBJECT: a cute girl hero named Emmy, around 9 years old, slightly taller,
> friendly face, big eyes, medium-length hair, wearing a **teal / turquoise**
> outfit, standing happily, full body, facing the viewer — same art style and
> sister to the pink-dressed girl

**C. Mystery present** — `filename: present.png` — transparent
> SUBJECT: a single whimsical wrapped gift box with a big bow, bright and
> inviting, slightly bouncy cartoon shape, centered

**D. Snack (health pickup)** — `filename: snack.png` — transparent
> SUBJECT: a single cute yummy snack (a big cookie or ice-cream cone), appetizing
> and charming, centered

**E. Heart (health icon)** — `filename: heart.png` — transparent
> SUBJECT: a single plump cartoon heart icon, glossy and friendly, centered

**F. Island ground / background** — `filename: island_bg.png` — opaque, 1536×1024
> SUBJECT: a top-down friendly grassy floating-island ground, warm and inviting,
> scattered with a few flowers and small rocks, soft and cozy, no characters

---

## 5. Workflow / what to deliver
1. First, set up the locked pipeline (checkpoint + style LoRA + transparent-output
   method). Tell me what models/LoRAs/nodes you're using or what I need to install.
2. Generate **Isla** (asset A) a few times; show me the best. We lock the look here.
3. After I approve, wire Isla in as an **IPAdapter reference** and generate the
   rest (B–F) so they all match.
4. Deliver the PNGs named exactly as above. I'll drop them into the game's
   `assets/` folder and they replace the placeholders 1:1.

If anything in my setup is missing (no transparent-output node, no suitable LoRA,
etc.), tell me exactly what to download or which node to add.
