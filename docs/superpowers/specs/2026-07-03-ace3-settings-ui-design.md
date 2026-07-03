# LootG Ace3 Settings UI Redesign

**Date:** 2026-07-03
**Status:** Design approved, pending implementation plan

## Motivation

Optimize LootG's settings UI to match the style and quality of the reference project `MythicPlusBox`. Also fix a bug: on English clients the "Enter Combat" / "Leave Combat" default text does not always render in English (it can freeze at whatever locale seeded the SavedVariables on first install).

## Goals

- Adopt Ace3 ecosystem (AceGUI + AceConfig + AceDB + AceDBOptions + LibSharedMedia) for the settings UI.
- Standalone floating options window with tabs, matching MythicPlusBox's `Options.lua` structure.
- Add profile support (multiple characters/accounts, copy/reset/import via AceDBOptions).
- Add LibSharedMedia font support (any user-installed font, not just the 4 hardcoded ones).
- Fix combat text default localization bug.
- Auto-migrate existing `LootGDB` to the new AceDB structure without user data loss.

## Non-Goals

- Adding a minimap icon (LibDBIcon). The Defaults reserve `global.minimap` for future use, but no button is created and LibDBIcon is not bundled.
- Adding a full anchor point / relative point control. Keep current X/Y offset model; do not expand the position data model.
- Refactoring loot notification / combat state runtime logic beyond what is needed to read the new DB paths and LSM font names.

## Architecture

### File layout

```
LootG/
  LootG.toc              (updated: Libs + Options.lua + LootGAceDB)
  Libs/                  (new: copied from ../MythicPlusBox/MythicPlusBox/Libs)
    LibStub/
    CallbackHandler-1.0/
    AceDB-3.0/
    AceDBOptions-3.0/
    AceGUI-3.0/
    AceConfig-3.0/
    LibSharedMedia-3.0/
    AceGUI-3.0-SharedMediaWidgets/
  Locales.lua            (updated: new option/tab/section keys)
  Config.lua             (rewritten: Defaults + AceDB init + LootGDB migration)
  Options.lua            (new: AceGUI panel builder, ~200 lines)
  LootGUtils.lua         (updated: DB references)
  LootG.lua              (updated: DB references, LSM font fetch, OpenOptions)
```

Load order in `LootG.toc`: libraries first, then `Locales.lua`, `Config.lua`, `Options.lua`, `LootGUtils.lua`, `LootG.lua`.

### Data model (AceDB defaults)

```lua
LootG.Defaults = {
    profile = {
        loot = {
            enabled         = true,
            locked          = true,
            showIcon        = true,
            anchorX         = 0,
            anchorY         = 0,
            scrollDirection = "UP",
            displayTime     = 3,
            scrollTime      = 1.5,
            fadeSpeed       = 0.5,
            fontSize        = 20,
            fontShadow      = true,
            fontOutline     = "OUTLINE",
            font            = "Friz Quadrata TT",   -- LSM name, not a path
        },
        combatState = {
            enabled         = true,
            locked          = true,
            posX            = 0,
            posY            = 250,
            displayMode     = "SCROLL",
            scrollDirection = "UP",
            displayTime     = 0.6,
            fadeTime        = 0.1,
            scrollSpeed     = 1.5,
            fontSize        = 38,
            fontShadow      = true,
            fontOutline     = "OUTLINE",
            font            = "Friz Quadrata TT",
            enterCombatText = "",   -- empty = use localized L["ENTER_COMBAT"]
            leaveCombatText = "",
        },
    },
    global = {
        minimap = { hide = false },   -- reserved, currently unused
    },
}
```

The runtime accesses `LootG.db.profile.loot.*` and `LootG.db.profile.combatState.*`.

### Legacy font path → LSM name map

```lua
LEGACY_FONT_MAP = {
    ["Fonts\\FRIZQT__.TTF"]  = "Friz Quadrata TT",
    ["Fonts\\ARIALN.TTF"]    = "Arial Narrow",
    ["Fonts\\skurri.ttf"]    = "Skurri",
    ["Fonts\\MORPHEUS.TTF"]  = "Morpheus",
}
```

### LootGDB → AceDB migration

On `ADDON_LOADED` (after `AceDB:New`):

1. If `LootGAceDB.global._migrated` is true, skip.
2. If global `LootGDB` is a table:
   - Copy loot flat keys (`enabled`, `locked`, `showIcon`, `anchorX`, `anchorY`, `scrollDirection`, `displayTime`, `scrollTime`, `fadeSpeed`, `fontSize`, `fontShadow`, `fontOutline`) into `profile.loot.*`.
   - If `LootGDB.fontPath` matches `LEGACY_FONT_MAP`, set `profile.loot.font` to the mapped LSM name.
   - Copy `LootGDB.combatState.*` into `profile.combatState.*`, with two special cases:
     - `fontPath` → `font` via `LEGACY_FONT_MAP`.
     - `enterCombatText` / `leaveCombatText`: if the value equals any known locale's default string (`Enter Combat`, `Leave Combat`, `进入战斗`, `脱离战斗`, `進入戰鬥`, `脫離戰鬥`), leave the profile field empty (so the dynamic localization path kicks in). Otherwise preserve the user's custom string.
3. Set `LootGAceDB.global._migrated = true`.
4. `LootGDB = nil` — WoW clears the old SavedVariable on next logout.

### Combat text bug fix

Root cause: `LootG.Defaults.combatState.enterCombatText = L["ENTER_COMBAT"]` snapshots the locale-specific string at Config.lua load time and persists it in SavedVariables. Once persisted, changing client locale (or the migration case above) leaves stale text.

Fix: default to `""`. `LootG.lua`'s existing helpers already handle the empty case:

```lua
local function GetEnterCombatText()
    local customText = GetCSSetting("enterCombatText", "")
    if customText and customText ~= "" then return customText end
    return L["ENTER_COMBAT"] or "Enter Combat"
end
```

Empty → `L["ENTER_COMBAT"]`, which respects the current client locale every call.

## UI structure

### Top-level frame

Reuses MythicPlusBox's pattern (`AceGUI:Create("Frame")` + `TabGroup` + per-tab `ScrollFrame`).

- Size: 720 × 560.
- Title: "LootG"; StatusText: version string from toc.
- OnClose: force `profile.loot.locked = true` and `profile.combatState.locked = true`, refresh anchors, release AceGUI frame, clear cached refs.

Tabs:

| Value      | Label (L key)     | Content                                    |
|------------|-------------------|--------------------------------------------|
| `loot`     | `TAB_LOOT`        | Loot notification settings                 |
| `combat`   | `TAB_COMBAT`      | Combat state settings                      |
| `profiles` | `TAB_PROFILES`    | `AceDBOptions:GetOptionsTable` embedded    |

### Reusable helpers (Options.lua top scope)

Mirrors MPBox's `AddCheckbox` / `AddSlider` / `AddDropdown` / `AddLSMFontDropdown` / `AddEditBox` / `AddSeparator`. Each set-callback triggers `LootG:RefreshAll()` which re-applies runtime state to the on-screen frames (anchor reset, font reapply, visibility toggle).

### Tab: Loot Notification

```
[Heading: General]
  ☐ Enabled
  ☐ Lock Position
  ☐ Show Icon

[Heading: Font]
  <LSM Font dropdown> | <FontSize slider 8-48> | <Outline dropdown> | ☐ Font Shadow

[Heading: Animation]
  <Scroll Direction dropdown: Up/Down>
  <Display Time slider 0.5-10> | <Scroll Time slider 0.1-5>
  <Fade Speed slider 0.1-2>

[Heading: Position]
  <X Offset slider -800..800> | <Y Offset slider -600..600>
```

### Tab: Combat State

```
[Heading: General]
  ☐ Enabled
  ☐ Lock Position

[Heading: Combat Text]
  Enter Combat Text: [edit box]   (hint: leave empty for localized default)
  Leave Combat Text: [edit box]

[Heading: Font]
  <LSM Font dropdown> | <FontSize slider 8-72> | <Outline dropdown> | ☐ Font Shadow

[Heading: Display]
  <Display Mode dropdown: Scroll/Static>
  <Scroll Direction dropdown: Up/Down/Left/Right>
  <Display Time slider 0.1-3> | <Scroll Speed slider 0.1-5>
  <Fade Time slider 0.1-3>

[Heading: Position]
  <X Offset slider -800..800> | <Y Offset slider -600..600>
```

### Tab: Profiles

Register `AceDBOptions:GetOptionsTable(LootG.db)` once, then `AceConfigDialog:Open("LootG_Profiles", container)` on tab select.

### Lock / anchor interaction

- Selecting a tab reveals the drag anchor if that module's `locked` is false.
- Closing the options window forces `locked = true` for both modules to avoid stray drags.
- Dragging an anchor mutates `anchorX/anchorY` (or `posX/posY`) and calls `LootG:RefreshOptionsUI()`, which re-selects the current tab so the sliders pick up the new values (same trick MPBox uses).

### Blizzard interface-options entry

Retained as a stub category "LootG" registered via `Settings.RegisterCanvasLayoutCategory` on `PLAYER_LOGIN`. Contents:

- Title `LootG`.
- Version string.
- Hint text `/lootg`.
- Button "Open LootG Options" — closes the Settings panel and calls `LootG:OpenOptions()`.

### Slash commands

- `/lootg` → `LootG:OpenOptions()` (was: `Settings.OpenToCategory`).
- `/lootg test` → unchanged.
- `/lootg debug` → unchanged.

## Locale keys

Add to all three locale blocks (en / zhCN / zhTW):

```
TAB_LOOT, TAB_COMBAT, TAB_PROFILES
SECTION_GENERAL, SECTION_FONT, SECTION_ANIMATION, SECTION_POSITION,
SECTION_COMBAT_TEXT, SECTION_DISPLAY
OPT_ENABLED, OPT_LOCKED, OPT_SHOW_ICON
OPT_FONT, OPT_FONT_SIZE, OPT_FONT_OUTLINE, OPT_FONT_SHADOW
OPT_X_OFFSET, OPT_Y_OFFSET
OPT_SCROLL_DIRECTION, OPT_DISPLAY_TIME, OPT_SCROLL_TIME, OPT_FADE_SPEED
OPT_DISPLAY_MODE, OPT_SCROLL_SPEED, OPT_FADE_TIME
OPT_ENTER_COMBAT_TEXT, OPT_LEAVE_COMBAT_TEXT
OPT_ENTER_COMBAT_HINT
BLIZZARD_STUB_HINT, BLIZZARD_STUB_BUTTON
```

Keep `L["ENTER_COMBAT"]` / `L["LEAVE_COMBAT"]` — these are still consumed by `GetEnterCombatText` / `GetLeaveCombatText` for dynamic localization.

Retire the old UI-only keys (`displayTime`, `scrollTime`, `fadeSpeed`, `fontSize`, `fadeTime`, `scrollSpeed`, `Enabled`, `Locked`, `X Offset`, `Y Offset`, `Font`, `Font Outline`, `Font Shadow`, `Show Icon`, `Up`, `Down`, `Left`, `Right`, `Scroll`, `Static`, `Scroll Direction`, `CS Display Mode`, `CS Enter Text`, `CS Leave Text`, and hardcoded `Fonts\...` name mappings). No consumer will remain after Options.lua replaces Config.lua's inline strings.

## toc changes

- `Version` bumped to `1.3.0`.
- `SavedVariables: LootGAceDB, LootGDB` — both listed to allow one-shot migration; `LootGDB` removed in a subsequent release once telemetry / user reports confirm migration.
- Libraries appended above `Locales.lua`.
- `Options.lua` appended after `Config.lua`.

## LootG.lua and LootGUtils.lua touch list

- Replace every read of `LootGDB.<flat_key>` with `LootG.db.profile.loot.<flat_key>`.
- Replace every read of `LootGDB.combatState.<key>` with `LootG.db.profile.combatState.<key>`.
- Font application: replace `SetFont(cfg.fontPath, size, outline)` with `SetFont(LSM:Fetch("font", cfg.font), size, outline)`. Import LSM once at file top: `local LSM = LibStub("LibSharedMedia-3.0")`.
- Rename `fontPath` field references to `font` in both modules.
- `LootG:OpenOptions()` (currently invoking Blizzard Settings) is removed from LootG.lua; the new implementation lives in Options.lua.
- Anchor refresh helper `LootG:RefreshOptionsUI` gets a new implementation in Options.lua (re-select the current tab, like MPBox does).

## Testing

Existing tests under `tests/` may reference the old DB shape. Update mocks so they simulate:

- `LootGAceDB` present and `_migrated` true → no migration runs.
- `LootGDB` present with legacy fields → migration populates `LootGAceDB.profile.*` correctly.
- `enterCombatText = "进入战斗"` in legacy DB → post-migration value is `""` and `GetEnterCombatText()` on enUS returns `"Enter Combat"`.

## Packaging (scripts/package.py)

- Add `"Options.lua"` to `RELEASE_FILES`.
- Extend the script to also copy the entire `Libs/` directory tree into the zip (`Libs/**`), preserving structure. `RELEASE_FILES` today is a flat tuple of top-level file names; introduce a second pass that walks `Libs/` recursively.
- Add a `1.3.0` entry to both `ENGLISH_RELEASE_NOTES` and `CHINESE_RELEASE_NOTES`.

## Rollout

Version `1.3.0`. Changelog:

- Rewrote settings UI on Ace3 (AceGUI/AceConfig/AceDB/LibSharedMedia).
- Added profile support (Profiles tab).
- Added LibSharedMedia font list.
- Fixed enter/leave combat default text not respecting client locale.
- Auto-migrated existing settings.
