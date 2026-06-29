# Isla & Emmy: Funky Islands (Steam Deck edition)

A relaxed, no-lose single-player explorer for two sisters — play as **Isla** or
**Emmy**. Built in [Godot 4.7](https://godotengine.org). Runs natively on the
Steam Deck (Linux x86-64) and auto-updates itself from GitHub.

## How it gets onto the Deck (one-time, no $100 Steam fee)

1. Every push to `main` triggers **GitHub Actions** to export a Linux build and
   publish it as the `latest` release (`.github/workflows/build.yml`).
2. On the Deck, a self-updating launcher (`deck/launch.sh`) is added to Steam
   once as a *non-Steam game*. Each launch pulls the newest build, then runs it.

### Deck setup (run once, in Desktop Mode → Konsole)

```sh
curl -sL https://raw.githubusercontent.com/andyfreed/isla-emmy-deck/main/deck/install.sh | bash
```

Then: Steam → **Add a Non-Steam Game** → tick *Isla & Emmy* → Add. Switch to
Game Mode and launch it. From then on it updates automatically — no keyboard,
no reinstalling.

## Develop locally

Open the project in Godot 4.7 and press play. Art lives in `assets/` (the
character PNGs are placeholders, swap-in-place for AI art later). Game logic is
in `scripts/main.gd`.
