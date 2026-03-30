# Eikla's Feral Bleed Tracker

Feral bleed snapshot tracking for Midnight-style gameplay, with automatic spell-frame anchoring and an in-game settings panel.

## Features

- Tracks `Rake`, `Moonfire`, and `Rip` snapshot strength as percentage text.
- Optional `Primal Wrath` tracker with its own anchor and settings, disabled by default.
- Supports Blizzard/default cooldown viewers and other spell-frame UIs that expose spell IDs.
- Feral-only runtime behavior: the addon hides itself and skips tracking outside Feral spec.
- Per-tracker `attach to spell frame` or `free move` positioning.
- Blizzard Settings panel for enabling trackers, fonts, offsets, preview mode, and move mode.

## Install

1. Place the `EiklasFeralBleedTracker` folder in:
`World of Warcraft/_retail_/Interface/AddOns/`
2. Launch the game and enable the addon.
3. Use `/efbt` to open settings or `/efbt unlock` to move free-position trackers.

## Version

`0.0.2`
