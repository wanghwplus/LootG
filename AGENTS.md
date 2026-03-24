# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

LootG is a World of Warcraft addon that displays loot notifications as scrolling text and combat state indicators. Written in Lua using WoW's native API with no external library dependencies.

**Target WoW Interface:** 12.0.x (The War Within)

## Architecture

Three files loaded in order (defined in `LootG.toc`):

1. **Locales.lua** — Localization strings (en, zhCN, zhTW). Table-based system using `GetLocale()` detection. Strings passed to other files via addon varargs `local addonName, L = ...`
2. **Config.lua** — Settings UI and database initialization. Uses WoW 11+ Settings API (`Settings.RegisterCanvasLayoutCategory`). Defines `LootG.Defaults` table and initializes `LootGDB` (SavedVariables). Exposes `LootG:InitializeConfig()`.
3. **LootG.lua** — Main logic with two subsystems:
   - **Loot Notification** (top half): Event-driven loot display with frame pooling (`GetMessageFrame`/`RecycleMessageFrame`), scrolling animation via `OnUpdate`, and draggable anchor frame.
   - **Combat State** (bottom half): Enter/leave combat flash text with independent anchor, supporting SCROLL and STATIC display modes.

## Key Data Flow

```
WoW Event → OnEvent handler → ShowItemLoot() or CreateScrollingMessage()
                                    ↓
                            GetMessageFrame() (pooled)
                                    ↓
                            OnUpdate animation loop → fade → RecycleMessageFrame()
```

**Deduplication:** `LOOT_SLOT_CLEARED` records displayed items in `recentlyShown` table; `SHOW_LOOT_TOAST` checks this table to avoid duplicate notifications for the same item within 5 seconds.

## SavedVariables

`LootGDB` — persisted settings. Top-level keys for loot notification, nested `combatState` table for combat display. See `LootG.Defaults` in Config.lua for full schema.

## Testing

Python unit tests cover the packaging script:
- `python3 -m unittest tests/test_package.py` — verify `scripts/package.py` packaging and release flows

Manual addon testing:
- `/lootg test` — display a test loot notification
- `/lootg debug` — print debug state
- Right-click the addon compartment button for test display

## Slash Commands

- `/lootg` — open settings panel
- `/lootg test` — test notification
- `/lootg debug` — debug info

## Development Notes

- All icon references use numeric **fileID** values (e.g., `236681` for Achievement_Reputation_01), not string texture paths.
- `GetCoinTextureString()` returns text with inline coin icons — do not add a separate icon parameter when displaying money.
- The addon uses WoW's frame pooling pattern to avoid GC pressure during rapid loot events.
- Localization keys must be added to all three language blocks in Locales.lua (en default, zhCN, zhTW).
- Release packaging is handled by `scripts/package.py`:
  - `python3 scripts/package.py package` builds a zip from the current `LootG.toc` version
  - `python3 scripts/package.py release <version>` updates version/changelog and then builds the zip
- Release zips are written as `LootG-<version>.zip`, and zip contents are nested under a top-level `LootG/` directory.
- `*.zip` is gitignored; generated release archives should not be committed.
- Language: code comments and commit messages are in Chinese.
