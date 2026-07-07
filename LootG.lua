local addonName, L = ...
local LootG = L
_G[addonName] = LootG

local LSM = LibStub("LibSharedMedia-3.0")

-- Read helpers that shield the rest of the file from AceDB shape drift.
-- LootG.db is initialized in LootG:InitializeConfig() during ADDON_LOADED,
-- so anything reached before that (script scope) must not call these.
local function LootCfg()  return LootG.db and LootG.db.profile.loot        end
local function CSCfg()    return LootG.db and LootG.db.profile.combatState end

-- ======= Loot Notification =======

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("LOOT_READY")
f:RegisterEvent("LOOT_SLOT_CLEARED")
f:RegisterEvent("LOOT_CLOSED")
f:RegisterEvent("CHAT_MSG_SKILL")
f:RegisterEvent("PLAYER_MONEY")
f:RegisterEvent("SHOW_LOOT_TOAST")
f:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
f:RegisterEvent("CHAT_MSG_LOOT")
f:RegisterEvent("CHAT_MSG_CURRENCY")
f:RegisterEvent("CHAT_MSG_MONEY")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("MAIL_SHOW")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("AUCTION_HOUSE_SHOW")

local activeMessages = {}
local messagePool = {}
local lootCache = {}
local previousMoney = nil
local isLooting = false
local lootMoneyCopper = 0 -- 缓存拾取窗口中的金币数额（铜币），避免与其他来源混淆
local recentlyShown = {} -- 去重：记录已由 LOOT_SLOT_CLEARED 显示的物品
local lastMoneyShownTime = 0 -- 去重：PLAYER_MONEY 与 CHAT_MSG_MONEY 之间
local pendingMoneyGain = nil -- 延迟显示的 PLAYER_MONEY 金额（铜币），等待 CHAT_MSG_MONEY 覆盖
local pendingMoneyTimer = nil -- 延迟显示的定时器
local RECENTLY_SHOWN_WINDOW = 5
local Util = LootG.Util

-- Detaint a secret string by rebuilding it from raw bytes
local function DetaintString(rawMsg)
    if type(rawMsg) ~= "string" then return rawMsg end
    -- Byte-level copy to produce a clean, untainted string
    -- string.format("%s", ...) does NOT reliably detaint secret strings
    local ok, result = pcall(function()
        local len = #rawMsg
        if len == 0 then return nil end
        return string.char(string.byte(rawMsg, 1, len))
    end)
    if ok and result then return result end
    return nil
end

-- 构建本地化无关的聊天消息匹配模式
local function BuildPattern(globalString)
    local pattern = globalString:gsub("%%%d*%$?s", "\001"):gsub("%%%d*%$?d", "\002")
    pattern = pattern:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    pattern = pattern:gsub("\001", "(.+)"):gsub("\002", "(%%d+)")
    return pattern
end

-- CHAT_MSG_LOOT 物品拾取模式
local PATTERN_LOOT_SELF_MULTI = BuildPattern(LOOT_ITEM_SELF_MULTIPLE)
local PATTERN_LOOT_SELF = BuildPattern(LOOT_ITEM_SELF)
local PATTERN_LOOT_PUSHED_SELF_MULTI = BuildPattern(LOOT_ITEM_PUSHED_SELF_MULTIPLE)
local PATTERN_LOOT_PUSHED_SELF = BuildPattern(LOOT_ITEM_PUSHED_SELF)
-- CHAT_MSG_CURRENCY 通货获得模式
local CURRENCY_CHAT_PATTERNS = {}
local function AddCurrencyChatPattern(globalString)
    if type(globalString) == "string" and globalString ~= "" then
        tinsert(CURRENCY_CHAT_PATTERNS, BuildPattern(globalString))
    end
end
AddCurrencyChatPattern(CURRENCY_GAINED_MULTIPLE)
AddCurrencyChatPattern(CURRENCY_GAINED)
AddCurrencyChatPattern(CURRENCY_GAINED_MULTIPLE_BONUS)
-- CHAT_MSG_MONEY 金币拾取模式
local PATTERN_YOU_LOOT_MONEY = BuildPattern(YOU_LOOT_MONEY)
local PATTERN_LOOT_MONEY_SPLIT = BuildPattern(LOOT_MONEY_SPLIT)
-- CHAT_MSG_SKILL 技能提升模式
local PATTERN_SKILL_UP = type(ERR_SKILL_UP_SI) == "string" and BuildPattern(ERR_SKILL_UP_SI) or nil

-- 统一动画驱动帧：单一 OnUpdate 循环驱动所有消息动画
local animContainer = CreateFrame("Frame", nil, UIParent)
animContainer:Hide()

-- 统一去重操作，保证 toast/chat/loot 共享同一套规则
-- source 参数标识事件来源，相同来源的多次触发视为不同拾取，不互相去重
local function RememberShown(link, source)
    return Util.MarkRecentlyShown(recentlyShown, link, GetTime(), source, RECENTLY_SHOWN_WINDOW)
end

local function WasShownRecently(link, source)
    return Util.WasRecentlyShown(recentlyShown, link, GetTime(), RECENTLY_SHOWN_WINDOW, source)
end

-- Anchor Frame for positioning
local anchor = CreateFrame("Frame", "LootGAnchor", UIParent, "BackdropTemplate")
anchor:SetSize(200, 40)
anchor:SetMovable(true)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")
anchor:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
anchor:SetBackdropColor(0, 0.5, 1, 0.5)
anchor.text = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
anchor.text:SetPoint("CENTER")
anchor.text:SetText(L["LootG"])

anchor:SetScript("OnDragStart", anchor.StartMoving)
anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Calculate offset relative to screen center to ensure consistency
    local centerX, centerY = self:GetCenter()
    local screenX, screenY = UIParent:GetCenter()
    local xOfs = centerX - screenX
    local yOfs = centerY - screenY

    -- Round to 1 decimal place for cleaner display
    xOfs = math.floor(xOfs * 10 + 0.5) / 10
    yOfs = math.floor(yOfs * 10 + 0.5) / 10

    LootCfg().anchorX = xOfs
    LootCfg().anchorY = yOfs

    if LootG.RefreshOptionsUI then LootG:RefreshOptionsUI() end

    LootG:ResetAnchor() -- Re-anchor strictly to CENTER
end)

function LootG:UpdateAnchorVisibility()
    if LootCfg().locked then
        anchor:Hide()
    else
        anchor:Show()
    end
end

function LootG:ResetAnchor()
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", UIParent, "CENTER", LootCfg().anchorX or 0, LootCfg().anchorY or 0)
end

-- Helper to get a frame from the pool or create a new one
local function GetMessageFrame()
    local frame = tremove(messagePool)
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        frame:SetSize(600, 40)

        frame.text = frame:CreateFontString(nil, "OVERLAY")
        frame.text:SetPoint("CENTER")
        frame.text:SetJustifyH("CENTER")
    end
    frame:SetAlpha(1)
    frame:Show()
    return frame
end

local function RecycleMessageFrame(frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame.expired = true
    tinsert(messagePool, frame)
end

-- 统一动画更新：驱动所有活跃消息的位置、碰撞避免和渐隐
-- 复用暂存表做碰撞排序，避免每帧分配临时表带来的 GC 压力
local sortScratch = {}
local function AnimUpdate(self, elapsed)
    local now = GetTime()

    -- 第一遍：计算位置和渐隐，同时收集存活帧到暂存表
    local aliveCount = 0
    for _, frame in ipairs(activeMessages) do
        if not frame.expired then
            local currTime = now - frame.startTime
            -- 与 combatState 相同的速度语义：100 px/s 乘以倍率
            local speed = 100 * frame.scrollSpeed
            local animationOffset = speed * currTime
            frame.currentY = (animationOffset * frame.direction) + frame.baseOffset

            -- 渐隐处理
            if currTime > frame.displayTime then
                local fadeProgress = (currTime - frame.displayTime) / frame.fadeTime
                if fadeProgress >= 1 then
                    RecycleMessageFrame(frame)
                else
                    -- 二次缓出：先慢后快，更自然
                    local alpha = (1 - fadeProgress)
                    alpha = alpha * alpha
                    frame:SetAlpha(alpha)
                end
            end

            if not frame.expired then
                aliveCount = aliveCount + 1
                sortScratch[aliveCount] = frame
            end
        end
    end
    -- 清掉上一帧遗留的尾部引用，保证 #sortScratch == aliveCount
    for i = #sortScratch, aliveCount + 1, -1 do
        sortScratch[i] = nil
    end

    -- 第二遍：碰撞检测（仅多消息时执行）
    if aliveCount > 1 then
        local sorted = sortScratch
        -- 按 currentY 排序，用 startTime 做平局裁决避免抖动
        table.sort(sorted, function(a, b)
            if a.currentY == b.currentY then
                return a.startTime < b.startTime
            end
            return a.currentY < b.currentY
        end)

        local cfg = LootCfg()
        local minSpacing = ((cfg and cfg.fontSize) or 20) + 6
        -- 方向感知：UP 时推更高的帧上移，DOWN 时推更低的帧下移
        local dirUp = (cfg and cfg.scrollDirection == "UP")
        if dirUp then
            -- 从低到高扫描，保证高位帧与低位帧间距足够
            for i = 2, #sorted do
                local gap = sorted[i].currentY - sorted[i - 1].currentY
                if gap < minSpacing then
                    local push = minSpacing - gap
                    sorted[i].baseOffset = sorted[i].baseOffset + push
                    sorted[i].currentY = sorted[i].currentY + push
                end
            end
        else
            -- DOWN：从高到低扫描，保证低位帧与高位帧间距足够
            for i = #sorted - 1, 1, -1 do
                local gap = sorted[i + 1].currentY - sorted[i].currentY
                if gap < minSpacing then
                    local push = minSpacing - gap
                    sorted[i].baseOffset = sorted[i].baseOffset - push
                    sorted[i].currentY = sorted[i].currentY - push
                end
            end
        end
    end

    -- 第三遍：应用最终位置（sortScratch 已是全部存活帧）
    for i = 1, aliveCount do
        local frame = sortScratch[i]
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", anchor, "CENTER", 0, frame.currentY)
    end

    -- 反向遍历清理 expired 帧
    for i = #activeMessages, 1, -1 do
        if activeMessages[i].expired then
            table.remove(activeMessages, i)
        end
    end

    -- 无活跃消息时停止 OnUpdate
    if #activeMessages == 0 then
        animContainer:Hide()
    end
end

animContainer:SetScript("OnUpdate", AnimUpdate)

local function CreateScrollingMessage(text, icon)
    local cfg = LootCfg()
    if not cfg then return end

    local frame = GetMessageFrame()
    local fontName = cfg.font
    local fontPath = (fontName and LSM:Fetch("font", fontName))
                  or LSM:Fetch("font", LSM:GetDefault("font"))
                  or STANDARD_TEXT_FONT

    -- Apply font outline setting
    local outline = cfg.fontOutline or "OUTLINE"
    frame.text:SetFont(fontPath, cfg.fontSize, outline)

    -- Apply font shadow setting
    if cfg.fontShadow then
        frame.text:SetShadowColor(0, 0, 0, 1)
        frame.text:SetShadowOffset(1, -1)
    else
        frame.text:SetShadowOffset(0, 0)
    end

    local displayText = text
    local iconSize = (cfg.fontSize or 20) - 2
    if icon and cfg.showIcon then
        displayText = "|T" .. icon .. ":" .. iconSize .. ":" .. iconSize .. ":0:0|t " .. text
    end
    frame.text:SetText(displayText)

    -- Animation Data
    frame.startTime = GetTime()
    frame.scrollSpeed = cfg.scrollSpeed or 1
    frame.displayTime = cfg.displayTime
    frame.fadeTime = cfg.fadeTime or 0.1
    frame.direction = cfg.scrollDirection == "UP" and 1 or -1
    frame.baseOffset = 0
    frame.expired = false
    frame.currentY = 0

    -- Push existing messages（碰撞检测会动态保证间距，步长减小）
    local offsetStep = (cfg.fontSize + 6) * frame.direction
    for _, active in ipairs(activeMessages) do
        if not active.expired then
            active.baseOffset = active.baseOffset + offsetStep
        end
    end

    table.insert(activeMessages, frame)

    -- 启动统一动画循环
    animContainer:Show()
end

-- Helper to display a looted item or currency
local function ShowItemLoot(link, quantity, texture, quality, isCurrency)
    local nameColor = nil

    if isCurrency then
        if not texture or not quality then
            local currencyInfo = C_CurrencyInfo.GetCurrencyInfoFromLink(link)
            if currencyInfo then
                texture = texture or currencyInfo.iconFileID
                quality = quality or currencyInfo.quality
            end
        end
    else
        if not texture or not quality then
            local _, _, q, _, _, _, _, _, _, t = GetItemInfo(link)
            texture = texture or t
            quality = quality or q
        end
    end

    if quality then
        local r, g, b, hex = GetItemQualityColor(quality)
        nameColor = "|c" .. hex
    end

    local function ShowMessage(iconToUse, colorCode)
        local displayLink = link
        displayLink = displayLink:gsub("(|h)%[(.-)%](|h)", "%1%2%3")

        if colorCode then
            if not displayLink:find("^|c") then
                displayLink = colorCode .. displayLink .. "|r"
            end
        end

        local displayText = L["Loot"] .. " " .. displayLink .. " x" .. quantity

        if not isCurrency then
            local bagCount = GetItemCount(link)
            if bagCount and bagCount > 0 then
                displayText = displayText .. " (" .. bagCount .. ")"
            end
        else
            local currencyInfo = C_CurrencyInfo.GetCurrencyInfoFromLink(link)
            if currencyInfo and currencyInfo.quantity and currencyInfo.quantity > 0 then
                displayText = displayText .. " (" .. currencyInfo.quantity .. ")"
            end
        end

        CreateScrollingMessage(displayText, iconToUse)
    end

    if texture then
        ShowMessage(texture, nameColor)
    elseif not isCurrency and link:find("|Hitem:", 1, true) then
        -- 物品信息未缓存时异步加载；Item:CreateFromItemLink 只接受
        -- item 链接，battlepet/keystone 等其他链接类型会直接报错
        local item = Item:CreateFromItemLink(link)
        item:ContinueOnItemLoad(function()
            local _, _, q, _, _, _, _, _, _, loadedTexture = GetItemInfo(link)
            local color = nil
            if q then
                local r, g, b, hex = GetItemQualityColor(q)
                color = "|c" .. hex
            end
            ShowMessage(loadedTexture, color)
        end)
    else
        ShowMessage(nil, nameColor)
    end
end

-- ======= Combat State =======

--------------------------------------------------
-- Helper: Get settings from LootG.db.profile.combatState
--------------------------------------------------
local function GetCSSetting(key, default)
    local cfg = CSCfg()
    if cfg and cfg[key] ~= nil then
        return cfg[key]
    end
    return default
end

--------------------------------------------------
-- Combat Display Frame
--------------------------------------------------
local csFrame = CreateFrame("Frame", "CombatStateFrame", UIParent)
csFrame:SetSize(260, 60)
csFrame:SetPoint("CENTER", 0, 250)
csFrame:SetAlpha(0)
csFrame:Hide()

--------------------------------------------------
-- Text
--------------------------------------------------
-- 只锚定中心、不约束宽度，让 FontString 按文字内容自适应，
-- 否则长文本超出 csFrame 固定宽度时会被截断成省略号
local csText = csFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
csText:SetPoint("CENTER")
csText:SetJustifyH("CENTER")

--------------------------------------------------
-- State
--------------------------------------------------
local csTimer = 0
local csMode = nil  -- "show" or "fade"
local startX, startY = 0, 0
-- FlashCombat 触发时快照动画参数，避免 OnUpdate 每帧查询配置表
local csDisplayTime, csFadeTime, csScrollSpeed, csDirection = 1, 0.1, 1.5, "UP"

--------------------------------------------------
-- Independent Anchor Frame (red background)
--------------------------------------------------
local csAnchor = CreateFrame("Frame", "CombatStateAnchor", UIParent, "BackdropTemplate")
csAnchor:SetSize(200, 40)
csAnchor:SetMovable(true)
csAnchor:EnableMouse(true)
csAnchor:RegisterForDrag("LeftButton")
csAnchor:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
csAnchor:SetBackdropColor(1, 0.3, 0.3, 0.5)
csAnchor.text = csAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
csAnchor.text:SetPoint("CENTER")
csAnchor.text:SetText(L["Combat State"])

csAnchor:SetScript("OnDragStart", csAnchor.StartMoving)
csAnchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local centerX, centerY = self:GetCenter()
    local screenX, screenY = UIParent:GetCenter()
    local xOfs = centerX - screenX
    local yOfs = centerY - screenY

    xOfs = math.floor(xOfs * 10 + 0.5) / 10
    yOfs = math.floor(yOfs * 10 + 0.5) / 10

    CSCfg().posX = xOfs
    CSCfg().posY = yOfs

    if LootG.RefreshOptionsUI then LootG:RefreshOptionsUI() end

    LootG:ResetCSAnchor()
end)

--------------------------------------------------
-- Exposed Functions to LootG namespace
--------------------------------------------------
function LootG:ResetCSAnchor()
    local posX = GetCSSetting("posX", 0)
    local posY = GetCSSetting("posY", 250)
    csAnchor:ClearAllPoints()
    csAnchor:SetPoint("CENTER", UIParent, "CENTER", posX, posY)
end

function LootG:UpdateCSAnchorVisibility()
    if GetCSSetting("locked", true) then
        csAnchor:Hide()
    else
        csAnchor:Show()
    end
end

--------------------------------------------------
-- OnUpdate - Scroll Mode (continuous, no distance limit)
--------------------------------------------------
local function OnUpdate_Scroll(self, elapsed)
    if not csMode then return end

    csTimer = csTimer + elapsed

    -- Continuous scrolling: 100 pixels per second * scrollSpeed
    local speed = 100 * csScrollSpeed
    local dist = speed * csTimer
    local offsetX, offsetY = 0, 0
    if csDirection == "UP" then
        offsetY = dist
    elseif csDirection == "DOWN" then
        offsetY = -dist
    elseif csDirection == "LEFT" then
        offsetX = -dist
    elseif csDirection == "RIGHT" then
        offsetX = dist
    end

    csFrame:ClearAllPoints()
    csFrame:SetPoint("CENTER", startX + offsetX, startY + offsetY)

    -- Fading
    if csTimer > csDisplayTime then
        local fadeProgress = (csTimer - csDisplayTime) / csFadeTime
        if fadeProgress >= 1 then
            csFrame:SetAlpha(0)
            csFrame:Hide()
            csMode = nil
        else
            -- 二次缓出：先慢后快，更自然
            local alpha = (1 - fadeProgress)
            alpha = alpha * alpha
            csFrame:SetAlpha(alpha)
        end
    end
end

--------------------------------------------------
-- OnUpdate - Static Mode
--------------------------------------------------
local function OnUpdate_Static(self, elapsed)
    if not csMode then return end

    csTimer = csTimer + elapsed

    if csMode == "show" then
        if csTimer >= csDisplayTime then
            csTimer = 0
            csMode = "fade"
        end

    elseif csMode == "fade" then
        local fadeProgress = csTimer / csFadeTime

        if fadeProgress >= 1 then
            csFrame:SetAlpha(0)
            csFrame:Hide()
            csMode = nil
        else
            -- 二次缓出：先慢后快，更自然
            local alpha = (1 - fadeProgress)
            alpha = alpha * alpha
            csFrame:SetAlpha(alpha)
        end
    end
end

--------------------------------------------------
-- Set the appropriate OnUpdate handler
--------------------------------------------------
local function UpdateOnUpdateHandler()
    local displayMode = GetCSSetting("displayMode", "SCROLL")
    if displayMode == "STATIC" then
        csFrame:SetScript("OnUpdate", OnUpdate_Static)
    else
        csFrame:SetScript("OnUpdate", OnUpdate_Scroll)
    end
end

csFrame:SetScript("OnUpdate", OnUpdate_Scroll)

--------------------------------------------------
-- Trigger helper
--------------------------------------------------
local function FlashCombat(textLabel, r, g, b)
    UpdateOnUpdateHandler()

    -- 快照动画参数，本次闪现全程使用（与拾取消息在创建时快照的行为一致）
    csDisplayTime = GetCSSetting("displayTime", 1)
    csFadeTime    = GetCSSetting("fadeTime", 0.1)
    csScrollSpeed = GetCSSetting("scrollSpeed", 1.5)
    csDirection   = GetCSSetting("scrollDirection", "UP")

    local fontName = GetCSSetting("font", "Friz Quadrata TT")
    local fontPath = LSM:Fetch("font", fontName)
                  or LSM:Fetch("font", LSM:GetDefault("font"))
                  or STANDARD_TEXT_FONT
    local fontSize = GetCSSetting("fontSize", 38)
    local fontOutline = GetCSSetting("fontOutline", "OUTLINE")
    local fontShadow = GetCSSetting("fontShadow", true)
    local posX = GetCSSetting("posX", 0)
    local posY = GetCSSetting("posY", 250)

    csText:SetText(textLabel)
    csText:SetTextColor(r, g, b)
    csText:SetFont(fontPath, fontSize, fontOutline)

    if fontShadow then
        csText:SetShadowColor(0, 0, 0, 1)
        csText:SetShadowOffset(1, -1)
    else
        csText:SetShadowOffset(0, 0)
    end

    csFrame:ClearAllPoints()
    csFrame:SetPoint("CENTER", posX, posY)
    startX = posX
    startY = posY

    csFrame:SetAlpha(1)
    csFrame:Show()

    csTimer = 0
    csMode = "show"
end

--------------------------------------------------
-- Get display text (custom or localized default)
--------------------------------------------------
local function GetEnterCombatText()
    local customText = GetCSSetting("enterCombatText", "")
    if customText and customText ~= "" then
        return customText
    end
    return L["ENTER_COMBAT"] or "Enter Combat"
end

local function GetLeaveCombatText()
    local customText = GetCSSetting("leaveCombatText", "")
    if customText and customText ~= "" then
        return customText
    end
    return L["LEAVE_COMBAT"] or "Leave Combat"
end

-- ======= Event Handler =======

f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            LootG:InitializeConfig()
            LootG:ResetAnchor()
            LootG:UpdateAnchorVisibility()
            LootG:ResetCSAnchor()
            LootG:UpdateCSAnchorVisibility()
            previousMoney = GetMoney()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        LootG:RegisterBlizzardStub()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "LOOT_READY" then
        isLooting = true
        lootMoneyCopper = 0
        wipe(lootCache)
        for i = 1, GetNumLootItems() do
            local slotType = GetLootSlotType(i)
            if slotType == Enum.LootSlotType.Money then
                -- 缓存拾取窗口中金币槽的铜币数额
                local _, _, quantity = GetLootSlotInfo(i)
                if quantity then
                    lootMoneyCopper = lootMoneyCopper + quantity
                end
            else
                local texture, _, quantity, currencyID, quality = GetLootSlotInfo(i)
                local link = GetLootSlotLink(i)
                -- 通货槽位 GetLootSlotLink 可能返回 nil，用 currencyID 构建链接
                if not link and slotType == Enum.LootSlotType.Currency and currencyID then
                    link = C_CurrencyInfo.GetCurrencyLink(currencyID)
                end
                if link then
                    lootCache[i] = {
                        link = link,
                        texture = texture,
                        quantity = quantity or 1,
                        quality = quality,
                        slotType = slotType,
                    }
                end
            end
        end
    elseif event == "LOOT_SLOT_CLEARED" then
        local slot = ...
        local cached = lootCache[slot]
        if not cached or not cached.link then return end

        -- 去重：跳过已由 CHAT_MSG_CURRENCY 或 CHAT_MSG_LOOT 显示的物品
        if not WasShownRecently(cached.link, "LOOT_SLOT_CLEARED") then
            local isCurrency = (cached.slotType == Enum.LootSlotType.Currency)
            ShowItemLoot(cached.link, cached.quantity, cached.texture, cached.quality, isCurrency)
            RememberShown(cached.link, "LOOT_SLOT_CLEARED")
        end
        lootCache[slot] = nil
    elseif event == "LOOT_CLOSED" then
        isLooting = false
        lootMoneyCopper = 0
        wipe(lootCache)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "MAIL_SHOW"
        or event == "MERCHANT_SHOW" or event == "AUCTION_HOUSE_SHOW" then
        -- 同步 previousMoney，避免金币偏差混入后续差值计算
        previousMoney = GetMoney()
    elseif event == "PLAYER_MONEY" then
        local cfg = LootCfg()
        if not cfg or not cfg.enabled then
            previousMoney = GetMoney()
            return
        end
        local currentMoney = GetMoney()
        if previousMoney and currentMoney > previousMoney then
            local gained = currentMoney - previousMoney
            -- 拾取中且有缓存的拾取金币时，使用缓存金额避免混入其他来源的金币
            if isLooting and lootMoneyCopper > 0 then
                gained = lootMoneyCopper
                lootMoneyCopper = 0
                local moneyText = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString
                    and C_CurrencyInfo.GetCoinTextureString(gained)
                    or GetCoinTextureString(gained)
                CreateScrollingMessage(moneyText, nil)
                lastMoneyShownTime = GetTime()
            else
                -- 非拾取场景（邮件、拍卖行等）：延迟显示，优先让 CHAT_MSG_MONEY 提供精确金额
                -- 如果已有待显示的金额（连续出售等），先立即显示上一条，避免丢失
                if pendingMoneyGain then
                    local prevText = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString
                        and C_CurrencyInfo.GetCoinTextureString(pendingMoneyGain)
                        or GetCoinTextureString(pendingMoneyGain)
                    CreateScrollingMessage(prevText, nil)
                    lastMoneyShownTime = GetTime()
                end
                pendingMoneyGain = gained
                if pendingMoneyTimer then pendingMoneyTimer:Cancel() end
                pendingMoneyTimer = C_Timer.NewTimer(0.15, function()
                    -- 定时器触发前用户可能已关闭插件，重新检查开关
                    local cfgNow = LootCfg()
                    if pendingMoneyGain and cfgNow and cfgNow.enabled then
                        local moneyText = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString
                            and C_CurrencyInfo.GetCoinTextureString(pendingMoneyGain)
                            or GetCoinTextureString(pendingMoneyGain)
                        CreateScrollingMessage(moneyText, nil)
                        lastMoneyShownTime = GetTime()
                    end
                    pendingMoneyGain = nil
                    pendingMoneyTimer = nil
                end)
            end
        end
        previousMoney = currentMoney
    elseif event == "CHAT_MSG_LOOT" then
        local cfg = LootCfg()
        if not cfg or not cfg.enabled then return end
        local rawMsg = ...
        if not rawMsg then return end
        local message = DetaintString(rawMsg)
        if not message then return end
        local link, quantity
        -- 先匹配带数量的模式（x%d），再匹配单件模式
        link, quantity = string.match(message, PATTERN_LOOT_SELF_MULTI)
        if not link then link, quantity = string.match(message, PATTERN_LOOT_PUSHED_SELF_MULTI) end
        if not link then
            link = string.match(message, PATTERN_LOOT_SELF)
            if link then quantity = 1 end
        end
        if not link then
            link = string.match(message, PATTERN_LOOT_PUSHED_SELF)
            if link then quantity = 1 end
        end
        if not link then return end
        quantity = tonumber(quantity) or 1
        -- 去重：跳过已由 LOOT_SLOT_CLEARED 或 SHOW_LOOT_TOAST 显示的物品
        local wasShownRecently = WasShownRecently(link, "CHAT_MSG_LOOT")
        if wasShownRecently then return end
        local _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(link)
        ShowItemLoot(link, quantity, texture, quality, false)
        RememberShown(link, "CHAT_MSG_LOOT")
    elseif event == "CHAT_MSG_CURRENCY" then
        local cfg = LootCfg()
        if not cfg or not cfg.enabled then return end
        local rawMsg = ...
        if not rawMsg then return end
        local message = DetaintString(rawMsg)
        if not message then return end
        local link, quantity = Util.ParseCurrencyChatMessage(message, CURRENCY_CHAT_PATTERNS)
        if not link then return end
        quantity = tonumber(quantity) or 1
        -- 去重：跳过已由 LOOT_SLOT_CLEARED 显示的通货
        local wasShownRecently = WasShownRecently(link, "CHAT_MSG_CURRENCY")
        if wasShownRecently then return end
        local texture, quality
        local currencyInfo = C_CurrencyInfo.GetCurrencyInfoFromLink(link)
        if currencyInfo then
            texture = currencyInfo.iconFileID
            quality = currencyInfo.quality
        end
        ShowItemLoot(link, quantity, texture, quality, true)
        RememberShown(link, "CHAT_MSG_CURRENCY")
    elseif event == "CHAT_MSG_MONEY" then
        local cfg = LootCfg()
        if not cfg or not cfg.enabled then return end
        local rawMsg = ...
        if not rawMsg then return end
        local message = DetaintString(rawMsg)
        if not message then return end
        local moneyText = string.match(message, PATTERN_YOU_LOOT_MONEY)
        if not moneyText then moneyText = string.match(message, PATTERN_LOOT_MONEY_SPLIT) end
        if not moneyText then return end
        -- 取消待显示的 PLAYER_MONEY 延迟消息，使用 CHAT_MSG_MONEY 的精确金额
        if pendingMoneyGain then
            pendingMoneyGain = nil
            if pendingMoneyTimer then pendingMoneyTimer:Cancel(); pendingMoneyTimer = nil end
        end
        -- 去重：如果近期已显示过金币（拾取窗口场景），跳过
        if (GetTime() - lastMoneyShownTime) < 2 then return end
        CreateScrollingMessage(moneyText, nil)
        lastMoneyShownTime = GetTime()
    elseif event == "SHOW_LOOT_TOAST" then
        local cfg = LootCfg()
        if not cfg or not cfg.enabled then return end
        local typeIdentifier, link, quantity = ...
        if not link or link == "" then return end
        if typeIdentifier == "money" then return end
        -- 去重：跳过已由 LOOT_SLOT_CLEARED 显示的物品
        local wasShownRecently = WasShownRecently(link, "SHOW_LOOT_TOAST")
        if wasShownRecently then return end
        quantity = tonumber(quantity) or 1
        local isCurrency = (typeIdentifier == "currency")
        local texture, quality
        if isCurrency then
            local currencyInfo = C_CurrencyInfo.GetCurrencyInfoFromLink(link)
            if currencyInfo then
                texture = currencyInfo.iconFileID
                quality = currencyInfo.quality
            end
        else
            local _, _, q, _, _, _, _, _, _, t = GetItemInfo(link)
            texture = t
            quality = q
        end
        ShowItemLoot(link, quantity, texture, quality, isCurrency)
        RememberShown(link, "SHOW_LOOT_TOAST")
    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        local cfg = LootCfg()
        if not cfg or not cfg.enabled then return end
        local rawMsg = ...
        if not rawMsg then return end
        local message = DetaintString(rawMsg)
        if not message then return end
        local info = ChatTypeInfo["COMBAT_FACTION_CHANGE"]
        local colorCode = info and format("|cff%02x%02x%02x", info.r * 255, info.g * 255, info.b * 255) or "|cff00ffa0"
        CreateScrollingMessage(colorCode .. message .. "|r", 236681) -- Achievement_Reputation_01 fileID
    elseif event == "CHAT_MSG_SKILL" then
        local cfg = LootCfg()
        if not cfg or not cfg.enabled then return end
        local rawMsg = ...
        if not rawMsg then return end
        local message = DetaintString(rawMsg)
        if not message then return end
        local info = ChatTypeInfo["SKILL"]
        local colorCode = info and format("|cff%02x%02x%02x", info.r * 255, info.g * 255, info.b * 255) or "|cff5555ff"
        local skillName, skillLevel
        if PATTERN_SKILL_UP then
            skillName, skillLevel = string.match(message, PATTERN_SKILL_UP)
        end
        -- Try to find the profession icon matching skillName
        local skillIcon = 136830 -- INV_Misc_Book_11 fileID
        if skillName then
            local prof1, prof2, arch, fish, cook = GetProfessions()
            local profIDs = {prof1, prof2, arch, fish, cook}
            for i = 1, 5 do
                local profID = profIDs[i]
                if profID then
                    local profName, profIcon = GetProfessionInfo(profID)
                    if profName and (profName:find(skillName, 1, true) or skillName:find(profName, 1, true)) then
                        skillIcon = profIcon
                        break
                    end
                end
            end
        end

        local text
        if skillName and skillLevel then
            text = colorCode .. skillName .. " " .. skillLevel .. "|r"
        else
            text = colorCode .. message .. "|r"
        end
        CreateScrollingMessage(text, skillIcon)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if not GetCSSetting("enabled", true) then return end
        FlashCombat(GetEnterCombatText(), 1.0, 0.1, 0.1)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if not GetCSSetting("enabled", true) then return end
        FlashCombat(GetLeaveCombatText(), 0.1, 1.0, 0.1)
    end
end)

function LootG:RegisterBlizzardStub()
    if self._blizzardStubReady then return end
    self._blizzardStubReady = true

    local panel = CreateFrame("Frame")
    panel.name = L["LootG"] or "LootG"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["LootG"] or "LootG")

    local version = ""
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        version = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
    elseif GetAddOnMetadata then
        version = GetAddOnMetadata(addonName, "Version") or ""
    end

    local ver = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    ver:SetText(version ~= "" and ("v" .. version) or "")

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", ver, "BOTTOMLEFT", 0, -12)
    hint:SetText(L["BLIZZARD_STUB_HINT"] or "Type /lootg to open the LootG options window.")

    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -14)
    btn:SetSize(200, 24)
    btn:SetText(L["BLIZZARD_STUB_BUTTON"] or "Open LootG Options")
    btn:SetScript("OnClick", function()
        HideUIPanel(SettingsPanel or InterfaceOptionsFrame)
        HideUIPanel(GameMenuFrame)
        LootG:OpenOptions()
    end)

    if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, L["LootG"] or "LootG")
        Settings.RegisterAddOnCategory(category)
        LootG.SettingsCategory = category
    elseif _G.InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

-- ======= Slash Command =======

SLASH_LOOTG1 = "/lootg"
SlashCmdList["LOOTG"] = function(msg)
    if msg == "debug" then
        local cfg = LootCfg()
        print("|cff00ff00[LootG Debug]|r enabled = " .. tostring(cfg and cfg.enabled))
        print("|cff00ff00[LootG Debug]|r ERR_SKILL_UP_SI = " .. tostring(ERR_SKILL_UP_SI))
        local money = GetMoney()
        print("|cff00ff00[LootG Debug]|r GetMoney() = " .. tostring(money) .. " copper")
        print("|cff00ff00[LootG Debug]|r GetCoinTextureString(10000) = " .. tostring(GetCoinTextureString(10000)))
        if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
            print("|cff00ff00[LootG Debug]|r C_CurrencyInfo(10000) = " .. tostring(C_CurrencyInfo.GetCoinTextureString(10000)))
        end
        return
    elseif msg == "test" then
        local testItem = "|cff0070dd|Hitem:124112::::::::110:::::|h[Test Item]|h|r"
        testItem = testItem:gsub("(|h)%[(.-)%](|h)", "%1%2%3")
        local testIcon = 134400 -- A generic icon
        CreateScrollingMessage(testItem, testIcon)
    else
        LootG:OpenOptions()
    end
end

-- Addon Compartment Click Handler
function LootG_OnCompartmentClick(addonName, button)
    if button == "RightButton" then
        local testItem = "|cff0070dd|Hitem:124112::::::::110:::::|h[Test Item]|h|r"
        testItem = testItem:gsub("(|h)%[(.-)%](|h)", "%1%2%3")
        local testIcon = 134400
        CreateScrollingMessage(testItem, testIcon)
    else
        LootG:OpenOptions()
    end
end
