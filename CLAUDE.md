# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LootG is a World of Warcraft addon that displays loot notifications as scrolling text and combat state indicators. Written in Lua on the Ace3 library stack (bundled under `Libs/`: AceDB, AceGUI, AceConfig, AceDBOptions, LibSharedMedia, CallbackHandler, LibStub).

**Target WoW Interface:** 12.0.x (The War Within)

## Architecture

Load order (defined in `LootG.toc`, after the `Libs/` stack):

1. **Locales.lua** — Localization strings (en, zhCN, zhTW). Table-based system using `GetLocale()` detection. Strings merged into the shared addon table via varargs `local addonName, L = ...`
2. **Config.lua** — Database layer. Defines `LootG.Defaults` (AceDB defaults with `profile.loot` / `profile.combatState`), `LootG:InitializeConfig()` (creates the `LootGAceDB` AceDB database and registers profile-change callbacks), and `LootG._MigrateLegacyDB` (one-shot migration from the legacy flat `LootGDB` SavedVariable).
3. **Options.lua** — Standalone AceGUI options window (`LootG:OpenOptions()`), tabbed: Loot Notification / Combat State / Profiles (AceDBOptions). Every setter calls `LootG:RefreshAll()` for instant preview.
4. **LootGUtils.lua** — Pure-Lua helpers (`LootG.Util`): link ID extraction, recently-shown dedup bookkeeping, currency chat-message parsing. WoW-API-free so it can be unit-tested standalone.
5. **LootG.lua** — Main logic with two subsystems:
   - **Loot Notification** (top half): Event-driven loot display with frame pooling (`GetMessageFrame`/`RecycleMessageFrame`), a single shared `OnUpdate` animation loop, and a draggable anchor frame.
   - **Combat State** (bottom half): Enter/leave combat flash text with independent anchor, supporting SCROLL and STATIC display modes.
   Also registers a minimal Blizzard Settings stub category (`RegisterBlizzardStub`) that just points users to `/lootg`.

## Key Data Flow

```
WoW Event → OnEvent handler → ShowItemLoot() or CreateScrollingMessage()
                                    ↓
                            GetMessageFrame() (pooled)
                                    ↓
                            OnUpdate animation loop → fade → RecycleMessageFrame()
```

**Deduplication:** every display path (`LOOT_SLOT_CLEARED`, `CHAT_MSG_LOOT`, `CHAT_MSG_CURRENCY`, `SHOW_LOOT_TOAST`) records shown items in the `recentlyShown` table keyed by item/currency ID. A different event source for the same ID within 5 seconds is skipped; the same source is treated as a new pickup. Expired entries are lazily swept inside `Util.MarkRecentlyShown`.

## SavedVariables

`LootGAceDB` — AceDB database with per-profile settings (`profile.loot`, `profile.combatState`). See `LootG.Defaults` in Config.lua for the full schema.

`LootGDB` — legacy flat SavedVariable, kept in the `.toc` only so `_MigrateLegacyDB` can read it once and then nil it out.

## Testing

Standalone Lua specs (no WoW client needed), run from the repo root:
- `lua tests/lootg_utils_spec.lua` — dedup/util logic in LootGUtils.lua
- `lua tests/lootg_migration_spec.lua` — `LootG:_MigrateLegacyDB` SavedVariables migration

Manual in-game testing:
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
- Release packaging: `bash release.sh` reads the version from `LootG.toc` and builds `LootG-v<version>.zip` with a top-level `LootG/` folder; release zips are gitignored and must not be committed.
- Language: code comments and commit messages are in Chinese.
