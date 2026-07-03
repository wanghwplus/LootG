-- Test harness for LootG:_MigrateLegacyDB. Runs standalone via `lua tests/lootg_migration_spec.lua`.

package.path = package.path .. ";./?.lua"

local addon = {}

-- Minimal L stub with English defaults. Migration uses L only to inspect the
-- current-locale ENTER/LEAVE strings so it can spot "user never changed it".
addon.L = { ENTER_COMBAT = "Enter Combat", LEAVE_COMBAT = "Leave Combat" }

-- Load Config.lua in the addon-file style (`local addonName, L = ...`).
assert(loadfile("Config.lua"))("LootG", addon)

local function assert_equal(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s\nexpected: %s\nactual: %s", msg, tostring(expected), tostring(actual)))
    end
end

local function make_db()
    -- Simulate the shape AceDB:New produces: profile + global tables initialized from Defaults.
    local function deepcopy(t)
        if type(t) ~= "table" then return t end
        local out = {}
        for k, v in pairs(t) do out[k] = deepcopy(v) end
        return out
    end
    return deepcopy(addon.Defaults)
end

-- Case 1: no legacy table → migration is a no-op, defaults intact.
do
    local db = make_db()
    addon._MigrateLegacyDB(db, nil)
    assert_equal(db.profile.loot.fontSize, 20, "no legacy → loot.fontSize default preserved")
    assert_equal(db.profile.combatState.enterCombatText, "", "no legacy → enterCombatText default empty")
    assert_equal(db.global._migrated, true, "no legacy → still marks _migrated to skip next run")
end

-- Case 2: legacy flat fields → copied into profile.loot, font path mapped to LSM name.
do
    local db = make_db()
    local legacy = {
        enabled         = false,
        locked          = false,
        showIcon        = false,
        anchorX         = 42,
        anchorY         = -17,
        scrollDirection = "DOWN",
        displayTime     = 7,
        scrollTime      = 2.5,
        fadeSpeed       = 1.0,
        fontSize        = 30,
        fontShadow      = false,
        fontOutline     = "THICKOUTLINE",
        fontPath        = "Fonts\\ARIALN.TTF",
    }
    addon._MigrateLegacyDB(db, legacy)
    assert_equal(db.profile.loot.enabled, false, "loot.enabled copied")
    assert_equal(db.profile.loot.anchorX, 42, "loot.anchorX copied")
    assert_equal(db.profile.loot.anchorY, -17, "loot.anchorY copied")
    assert_equal(db.profile.loot.scrollDirection, "DOWN", "loot.scrollDirection copied")
    assert_equal(db.profile.loot.fontSize, 30, "loot.fontSize copied")
    assert_equal(db.profile.loot.fontOutline, "THICKOUTLINE", "loot.fontOutline copied")
    assert_equal(db.profile.loot.font, "Arial Narrow", "fontPath mapped to LSM name")
end

-- Case 3: legacy combatState with user-untouched enter/leave text → wiped to "" so
-- the runtime falls back to the current-locale L string.
do
    local db = make_db()
    local legacy = {
        combatState = {
            enabled         = true,
            posX            = 10,
            posY            = 200,
            fontPath        = "Fonts\\MORPHEUS.TTF",
            enterCombatText = "进入战斗",   -- old zhCN default seeded by legacy Config.lua
            leaveCombatText = "Leave Combat",
        },
    }
    addon._MigrateLegacyDB(db, legacy)
    assert_equal(db.profile.combatState.posX, 10, "combatState.posX copied")
    assert_equal(db.profile.combatState.font, "Morpheus", "combatState fontPath mapped")
    assert_equal(db.profile.combatState.enterCombatText, "",
        "zhCN default enterCombatText wiped so localization kicks in")
    assert_equal(db.profile.combatState.leaveCombatText, "",
        "English default leaveCombatText wiped so localization kicks in")
end

-- Case 4: user's genuine custom combat text is preserved.
do
    local db = make_db()
    local legacy = {
        combatState = {
            enterCombatText = "!! FIGHT !!",
            leaveCombatText = "-- peace --",
        },
    }
    addon._MigrateLegacyDB(db, legacy)
    assert_equal(db.profile.combatState.enterCombatText, "!! FIGHT !!", "custom enter text preserved")
    assert_equal(db.profile.combatState.leaveCombatText, "-- peace --", "custom leave text preserved")
end

-- Case 5: idempotency — running again with _migrated=true is a no-op.
do
    local db = make_db()
    db.global._migrated = true
    local legacy = { enabled = false, fontSize = 99 }
    addon._MigrateLegacyDB(db, legacy)
    assert_equal(db.profile.loot.enabled, true, "second call skipped when _migrated is set")
    assert_equal(db.profile.loot.fontSize, 20, "second call skipped when _migrated is set")
end

print("lootg_migration_spec: ok")
