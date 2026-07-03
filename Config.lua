local addonName, L = ...
local LootG = L
local AceDB = LibStub and LibStub("AceDB-3.0", true)

-- ==========================================================================
-- Defaults
-- ==========================================================================
-- Font values are LibSharedMedia names, resolved to paths at draw time via
-- LSM:Fetch("font", cfg.font). enterCombatText / leaveCombatText default to
-- the empty string so that GetEnterCombatText / GetLeaveCombatText in
-- LootG.lua fall back to L["ENTER_COMBAT"] / L["LEAVE_COMBAT"] each call,
-- respecting the current client locale rather than snapshotting one.
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
            font            = "Friz Quadrata TT",
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
            enterCombatText = "",
            leaveCombatText = "",
        },
    },
    global = {
        minimap = { hide = false },
    },
}

-- ==========================================================================
-- Legacy font path → LSM name
-- ==========================================================================
LootG.LEGACY_FONT_MAP = {
    ["Fonts\\FRIZQT__.TTF"]  = "Friz Quadrata TT",
    ["Fonts\\ARIALN.TTF"]    = "Arial Narrow",
    ["Fonts\\skurri.ttf"]    = "Skurri",
    ["Fonts\\MORPHEUS.TTF"]  = "Morpheus",
}

-- Any of these values in enterCombatText / leaveCombatText indicates the
-- user never customized it — the value was seeded from L at Config.lua load
-- time under the old scheme. We zero those out during migration so the new
-- dynamic-localization fallback path kicks in.
local LEGACY_ENTER_DEFAULTS = {
    ["Enter Combat"] = true,
    ["进入战斗"]      = true,
    ["進入戰鬥"]      = true,
}
local LEGACY_LEAVE_DEFAULTS = {
    ["Leave Combat"] = true,
    ["脱离战斗"]      = true,
    ["脫離戰鬥"]      = true,
}

-- ==========================================================================
-- Migration: legacy LootGDB (flat + combatState subtable) → new AceDB shape
-- ==========================================================================
local FLAT_LOOT_KEYS = {
    "enabled", "locked", "showIcon", "anchorX", "anchorY",
    "scrollDirection", "displayTime", "scrollTime", "fadeSpeed",
    "fontSize", "fontShadow", "fontOutline",
}

function LootG._MigrateLegacyDB(db, legacy)
    if db.global._migrated then return db end

    if type(legacy) == "table" then
        for _, key in ipairs(FLAT_LOOT_KEYS) do
            if legacy[key] ~= nil then
                db.profile.loot[key] = legacy[key]
            end
        end
        if type(legacy.fontPath) == "string" then
            local mapped = LootG.LEGACY_FONT_MAP[legacy.fontPath]
            if mapped then db.profile.loot.font = mapped end
        end

        if type(legacy.combatState) == "table" then
            for k, v in pairs(legacy.combatState) do
                if k == "fontPath" then
                    local mapped = LootG.LEGACY_FONT_MAP[v]
                    if mapped then db.profile.combatState.font = mapped end
                elseif k == "enterCombatText" then
                    if type(v) == "string" and not LEGACY_ENTER_DEFAULTS[v] then
                        db.profile.combatState.enterCombatText = v
                    end
                elseif k == "leaveCombatText" then
                    if type(v) == "string" and not LEGACY_LEAVE_DEFAULTS[v] then
                        db.profile.combatState.leaveCombatText = v
                    end
                else
                    db.profile.combatState[k] = v
                end
            end
        end
    end

    db.global._migrated = true
    return db
end

-- ==========================================================================
-- InitializeConfig: create AceDB, run one-shot migration.
-- Called from LootG.lua's ADDON_LOADED handler after all addon files load.
-- ==========================================================================
function LootG:InitializeConfig()
    if not AceDB then
        error("LootG: AceDB-3.0 not loaded — check Libs load order in LootG.toc")
    end

    -- AceDB:New creates the SavedVariable if missing and merges profile with
    -- Defaults.profile lazily on access.
    LootG.db = AceDB:New("LootGAceDB", LootG.Defaults, true)

    -- 切换/复制/重置 profile 后立即把新配置应用到屏幕上的锚点框架，
    -- 否则锚点位置和锁定状态会停留在旧 profile 的值
    LootG.db.RegisterCallback(LootG, "OnProfileChanged", "RefreshAll")
    LootG.db.RegisterCallback(LootG, "OnProfileCopied", "RefreshAll")
    LootG.db.RegisterCallback(LootG, "OnProfileReset", "RefreshAll")

    LootG._MigrateLegacyDB(LootG.db, _G.LootGDB)
    if _G.LootGDB then
        -- 置 nil 后 WoW 在登出时不再写出该 SavedVariable，等效于删除旧存档
        _G.LootGDB = nil
    end
end
