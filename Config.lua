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
            anchorY         = 250,
            scrollDirection = "UP",
            displayTime     = 1.5,
            scrollSpeed     = 0.7,
            fadeTime        = 0.1,
            fontSize        = 14,
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
            displayTime     = 1,
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

-- ==========================================================================
-- Shape migration: 旧版 loot 动画参数 → 与 combatState 统一的语义
-- ==========================================================================
-- 旧版 scrollTime 是"滚动 100px 所需秒数"（越大越慢），fadeSpeed 名为速度
-- 实为秒数。统一为 scrollSpeed（100px/s 的倍率，越大越快）与 fadeTime（秒），
-- 换算 scrollSpeed = 1/scrollTime，按滑块步长取整并夹到滑块范围内。
-- 对已存在的 LootGAceDB profile 同样需要执行（每个 profile 切换时各跑一次）。
function LootG._MigrateLootShape(loot)
    if type(loot) ~= "table" then return end
    if type(loot.scrollTime) == "number" and loot.scrollTime > 0 then
        local speed = math.floor(1 / loot.scrollTime * 10 + 0.5) / 10
        loot.scrollSpeed = math.min(5, math.max(0.1, speed))
    end
    loot.scrollTime = nil
    if type(loot.fadeSpeed) == "number" then
        loot.fadeTime = loot.fadeSpeed
    end
    loot.fadeSpeed = nil
end

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

    -- 切换/复制/重置 profile 后：目标 profile 可能还是旧参数形态，先做
    -- shape 迁移，再把新配置应用到屏幕上的锚点框架
    LootG.db.RegisterCallback(LootG, "OnProfileChanged", "HandleProfileChanged")
    LootG.db.RegisterCallback(LootG, "OnProfileCopied", "HandleProfileChanged")
    LootG.db.RegisterCallback(LootG, "OnProfileReset", "HandleProfileChanged")

    LootG._MigrateLegacyDB(LootG.db, _G.LootGDB)
    LootG._MigrateLootShape(LootG.db.profile.loot)
    if _G.LootGDB then
        -- 置 nil 后 WoW 在登出时不再写出该 SavedVariable，等效于删除旧存档
        _G.LootGDB = nil
    end
end

function LootG:HandleProfileChanged()
    LootG._MigrateLootShape(LootG.db.profile.loot)
    if LootG.RefreshAll then LootG:RefreshAll() end
end
