local addonName, L = ...
local LootG = L
_G[addonName] = LootG

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

local activeMessages = {}
local messagePool = {}
local lootCache = {}
local previousMoney = nil
local isLooting = false
local lootMoneyCopper = 0 -- 缓存拾取窗口中的金币数额（铜币），避免与其他来源混淆
local recentlyShown = {} -- 去重：记录已由 LOOT_SLOT_CLEARED 显示的物品
local lastMoneyShownTime = 0 -- 去重：PLAYER_MONEY 与 CHAT_MSG_MONEY 之间

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
local PATTERN_CURRENCY_MULTI = BuildPattern(CURRENCY_GAINED_MULTIPLE)
local PATTERN_CURRENCY = BuildPattern(CURRENCY_GAINED)
-- CHAT_MSG_MONEY 金币拾取模式
local PATTERN_YOU_LOOT_MONEY = BuildPattern(YOU_LOOT_MONEY)
local PATTERN_LOOT_MONEY_SPLIT = BuildPattern(LOOT_MONEY_SPLIT)

-- 统一动画驱动帧：单一 OnUpdate 循环驱动所有消息动画
local animContainer = CreateFrame("Frame", nil, UIParent)
animContainer:Hide()

-- 从物品/货币链接中提取稳定的ID用于去重（忽略bonus ID等实例差异）
local function GetIDFromLink(link)
    if not link then return nil end
    return link:match("item:(%d+)") or link:match("currency:(%d+)")
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

    LootGDB.anchorX = xOfs
    LootGDB.anchorY = yOfs

    -- Sync with Settings Panel if open
    if LootG.SettingsControls and LootG.SettingsControls.AnchorX then
        LootG.SettingsControls.AnchorX:SetValue(xOfs)
    end
    if LootG.SettingsControls and LootG.SettingsControls.AnchorY then
        LootG.SettingsControls.AnchorY:SetValue(yOfs)
    end

    LootG:ResetAnchor() -- Re-anchor strictly to CENTER
end)

-- Lock Button Popup Frame
local lockPopup = CreateFrame("Frame", "LootGLockPopup", UIParent, "BackdropTemplate")
lockPopup:SetSize(120, 40)
lockPopup:SetPoint("TOP", anchor, "BOTTOM", 0, -10)
lockPopup:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
lockPopup:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
lockPopup:Hide()
lockPopup:SetFrameStrata("DIALOG")

local lockBtn = CreateFrame("Button", nil, lockPopup, "UIPanelButtonTemplate")
lockBtn:SetSize(100, 26)
lockBtn:SetPoint("CENTER")
lockBtn:SetText(L["Locked"])
lockBtn:SetScript("OnClick", function()
    LootGDB.locked = true
    LootG:UpdateAnchorVisibility()
    lockPopup:Hide()
end)

function LootG:ShowLockPopup()
    if not LootGDB.locked then
        lockPopup:ClearAllPoints()
        lockPopup:SetPoint("TOP", anchor, "BOTTOM", 0, -10)
        lockPopup:Show()
    end
end

function LootG:HideLockPopup()
    lockPopup:Hide()
end

function LootG:UpdateAnchorVisibility()
    if LootGDB.locked then
        anchor:Hide()
        lockPopup:Hide()
    else
        anchor:Show()
    end
end

function LootG:ResetAnchor()
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", UIParent, "CENTER", LootGDB.anchorX or 0, LootGDB.anchorY or 0)
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
local function AnimUpdate(self, elapsed)
    local now = GetTime()

    -- 第一遍：计算位置和渐隐
    for _, frame in ipairs(activeMessages) do
        if not frame.expired then
            local currTime = now - frame.startTime
            local speed = 100 / frame.duration
            local animationOffset = speed * currTime
            frame.currentY = (animationOffset * frame.direction) + frame.baseOffset

            -- 渐隐处理
            if currTime > frame.displayTime then
                local fadeProgress = (currTime - frame.displayTime) / frame.fadeSpeed
                if fadeProgress >= 1 then
                    RecycleMessageFrame(frame)
                else
                    -- 二次缓出：先慢后快，更自然
                    local alpha = (1 - fadeProgress)
                    alpha = alpha * alpha
                    frame:SetAlpha(alpha)
                end
            end
        end
    end

    -- 第二遍：碰撞检测（仅多消息时执行）
    local activeCount = 0
    for _, frame in ipairs(activeMessages) do
        if not frame.expired then
            activeCount = activeCount + 1
        end
    end

    if activeCount > 1 then
        -- 收集活跃帧并按 currentY 排序
        local sorted = {}
        for _, frame in ipairs(activeMessages) do
            if not frame.expired then
                tinsert(sorted, frame)
            end
        end
        -- 按 currentY 排序，用 startTime 做平局裁决避免抖动
        table.sort(sorted, function(a, b)
            if a.currentY == b.currentY then
                return a.startTime < b.startTime
            end
            return a.currentY < b.currentY
        end)

        local minSpacing = (LootGDB and LootGDB.fontSize or 20) + 6
        -- 方向感知：UP 时推更高的帧上移，DOWN 时推更低的帧下移
        local dirUp = (LootGDB and LootGDB.scrollDirection == "UP")
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

    -- 第三遍：应用最终位置
    for _, frame in ipairs(activeMessages) do
        if not frame.expired then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", anchor, "CENTER", 0, frame.currentY)
        end
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
    if not LootGDB then return end

    local frame = GetMessageFrame()
    local fontPath = LootGDB.fontPath
    if type(fontPath) ~= "string" then
        fontPath = "Fonts\\FRIZQT__.TTF"
    end

    -- Apply font outline setting
    local outline = LootGDB.fontOutline or "OUTLINE"
    frame.text:SetFont(fontPath, LootGDB.fontSize, outline)

    -- Apply font shadow setting
    if LootGDB.fontShadow then
        frame.text:SetShadowColor(0, 0, 0, 1)
        frame.text:SetShadowOffset(1, -1)
    else
        frame.text:SetShadowOffset(0, 0)
    end

    local displayText = text
    local iconSize = (LootGDB.fontSize or 20) - 2
    if icon and LootGDB.showIcon then
        displayText = "|T" .. icon .. ":" .. iconSize .. ":" .. iconSize .. ":0:0|t " .. text
    end
    frame.text:SetText(displayText)

    -- Animation Data
    frame.startTime = GetTime()
    frame.duration = LootGDB.scrollTime
    frame.displayTime = LootGDB.displayTime
    frame.fadeSpeed = LootGDB.fadeSpeed
    frame.direction = LootGDB.scrollDirection == "UP" and 1 or -1
    frame.baseOffset = 0
    frame.expired = false
    frame.currentY = 0

    -- Push existing messages（碰撞检测会动态保证间距，步长减小）
    local offsetStep = (LootGDB.fontSize + 6) * frame.direction
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
    else
        if not isCurrency then
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
end

-- ======= Combat State =======

--------------------------------------------------
-- Helper: Get settings from LootGDB.combatState
--------------------------------------------------
local function GetCSSetting(key, default)
    if LootGDB and LootGDB.combatState and LootGDB.combatState[key] ~= nil then
        return LootGDB.combatState[key]
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
local csText = csFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
csText:SetAllPoints()
csText:SetJustifyH("CENTER")
csText:SetJustifyV("MIDDLE")

--------------------------------------------------
-- State
--------------------------------------------------
local csTimer = 0
local csMode = nil  -- "show" or "fade"
local startX, startY = 0, 0

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
csAnchor.text:SetText(L["Combat State"] or "Combat State")

csAnchor:SetScript("OnDragStart", csAnchor.StartMoving)
csAnchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local centerX, centerY = self:GetCenter()
    local screenX, screenY = UIParent:GetCenter()
    local xOfs = centerX - screenX
    local yOfs = centerY - screenY

    xOfs = math.floor(xOfs * 10 + 0.5) / 10
    yOfs = math.floor(yOfs * 10 + 0.5) / 10

    LootGDB.combatState.posX = xOfs
    LootGDB.combatState.posY = yOfs

    -- Sync with Settings Panel if open
    if LootG.CSSettingsControls and LootG.CSSettingsControls.PosX then
        LootG.CSSettingsControls.PosX:SetValue(xOfs)
    end
    if LootG.CSSettingsControls and LootG.CSSettingsControls.PosY then
        LootG.CSSettingsControls.PosY:SetValue(yOfs)
    end

    LootG:ResetCSAnchor()
end)

-- Lock Button Popup for CS Anchor
local csLockPopup = CreateFrame("Frame", "CombatStateLockPopup", UIParent, "BackdropTemplate")
csLockPopup:SetSize(120, 40)
csLockPopup:SetPoint("TOP", csAnchor, "BOTTOM", 0, -10)
csLockPopup:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
csLockPopup:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
csLockPopup:Hide()
csLockPopup:SetFrameStrata("DIALOG")

local csLockBtn = CreateFrame("Button", nil, csLockPopup, "UIPanelButtonTemplate")
csLockBtn:SetSize(100, 26)
csLockBtn:SetPoint("CENTER")
csLockBtn:SetText(L["Locked"] or "Lock Position")
csLockBtn:SetScript("OnClick", function()
    LootGDB.combatState.locked = true
    LootG:UpdateCSAnchorVisibility()
    csLockPopup:Hide()
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
        csLockPopup:Hide()
    else
        csAnchor:Show()
    end
end

function LootG:ShowCSLockPopup()
    if not GetCSSetting("locked", true) then
        csLockPopup:ClearAllPoints()
        csLockPopup:SetPoint("TOP", csAnchor, "BOTTOM", 0, -10)
        csLockPopup:Show()
    end
end

function LootG:HideCSLockPopup()
    csLockPopup:Hide()
end

--------------------------------------------------
-- OnUpdate - Scroll Mode (continuous, no distance limit)
--------------------------------------------------
local function OnUpdate_Scroll(self, elapsed)
    if not csMode then return end

    local displayTime = GetCSSetting("displayTime", 0.6)
    local fadeTime = GetCSSetting("fadeTime", 0.1)
    local scrollSpeed = GetCSSetting("scrollSpeed", 1.5)
    local direction = GetCSSetting("scrollDirection", "UP")

    csTimer = csTimer + elapsed

    -- Continuous scrolling: 100 pixels per second * scrollSpeed
    local speed = 100 * scrollSpeed
    local dist = speed * csTimer
    local offsetX, offsetY = 0, 0
    if direction == "UP" then
        offsetY = dist
    elseif direction == "DOWN" then
        offsetY = -dist
    elseif direction == "LEFT" then
        offsetX = -dist
    elseif direction == "RIGHT" then
        offsetX = dist
    end

    csFrame:ClearAllPoints()
    csFrame:SetPoint("CENTER", startX + offsetX, startY + offsetY)

    -- Fading
    if csTimer > displayTime then
        local fadeProgress = (csTimer - displayTime) / fadeTime
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

    local displayTime = GetCSSetting("displayTime", 0.6)
    local fadeTime = GetCSSetting("fadeTime", 0.1)

    csTimer = csTimer + elapsed

    if csMode == "show" then
        if csTimer >= displayTime then
            csTimer = 0
            csMode = "fade"
        end

    elseif csMode == "fade" then
        local fadeProgress = csTimer / fadeTime

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

    local fontPath = GetCSSetting("fontPath", "Fonts\\FRIZQT__.TTF")
    if type(fontPath) ~= "string" then
        fontPath = "Fonts\\FRIZQT__.TTF"
    end
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

        local isCurrency = (cached.slotType == Enum.LootSlotType.Currency)
        ShowItemLoot(cached.link, cached.quantity, cached.texture, cached.quality, isCurrency)
        local dedupKey = GetIDFromLink(cached.link)
        if dedupKey then
            recentlyShown[dedupKey] = GetTime()
        end
        lootCache[slot] = nil
    elseif event == "LOOT_CLOSED" then
        isLooting = false
        lootMoneyCopper = 0
        wipe(lootCache)
        -- 清理过期的去重记录
        local now = GetTime()
        for k, v in pairs(recentlyShown) do
            if now - v > 5 then
                recentlyShown[k] = nil
            end
        end
    elseif event == "PLAYER_MONEY" then
        if not LootGDB or not LootGDB.enabled then
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
            end
            local moneyText = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString
                and C_CurrencyInfo.GetCoinTextureString(gained)
                or GetCoinTextureString(gained)
            CreateScrollingMessage(moneyText, nil)
            lastMoneyShownTime = GetTime()
        end
        previousMoney = currentMoney
    elseif event == "CHAT_MSG_LOOT" then
        if not LootGDB or not LootGDB.enabled then return end
        local message = ...
        local link, quantity
        -- 先匹配带数量的模式（x%d），再匹配单件模式
        link, quantity = message:match(PATTERN_LOOT_SELF_MULTI)
        if not link then link, quantity = message:match(PATTERN_LOOT_PUSHED_SELF_MULTI) end
        if not link then
            link = message:match(PATTERN_LOOT_SELF)
            if link then quantity = 1 end
        end
        if not link then
            link = message:match(PATTERN_LOOT_PUSHED_SELF)
            if link then quantity = 1 end
        end
        if not link then return end
        quantity = tonumber(quantity) or 1
        -- 去重：跳过已由 LOOT_SLOT_CLEARED 或 SHOW_LOOT_TOAST 显示的物品
        local dedupKey = GetIDFromLink(link)
        if dedupKey and recentlyShown[dedupKey] and (GetTime() - recentlyShown[dedupKey]) < 5 then return end
        local _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(link)
        ShowItemLoot(link, quantity, texture, quality, false)
        if dedupKey then recentlyShown[dedupKey] = GetTime() end
    elseif event == "CHAT_MSG_CURRENCY" then
        if not LootGDB or not LootGDB.enabled then return end
        local message = ...
        local link, quantity
        link, quantity = message:match(PATTERN_CURRENCY_MULTI)
        if not link then
            link = message:match(PATTERN_CURRENCY)
            if link then quantity = 1 end
        end
        if not link then return end
        quantity = tonumber(quantity) or 1
        -- 去重：跳过已由 LOOT_SLOT_CLEARED 显示的通货
        local dedupKey = GetIDFromLink(link)
        if dedupKey and recentlyShown[dedupKey] and (GetTime() - recentlyShown[dedupKey]) < 5 then return end
        local texture, quality
        local currencyInfo = C_CurrencyInfo.GetCurrencyInfoFromLink(link)
        if currencyInfo then
            texture = currencyInfo.iconFileID
            quality = currencyInfo.quality
        end
        ShowItemLoot(link, quantity, texture, quality, true)
        if dedupKey then recentlyShown[dedupKey] = GetTime() end
    elseif event == "CHAT_MSG_MONEY" then
        if not LootGDB or not LootGDB.enabled then return end
        -- 去重：如果 PLAYER_MONEY 近期已显示过金币，跳过
        if (GetTime() - lastMoneyShownTime) < 2 then return end
        local message = ...
        local moneyText = message:match(PATTERN_YOU_LOOT_MONEY)
        if not moneyText then moneyText = message:match(PATTERN_LOOT_MONEY_SPLIT) end
        if not moneyText then return end
        CreateScrollingMessage(moneyText, nil)
        lastMoneyShownTime = GetTime()
    elseif event == "SHOW_LOOT_TOAST" then
        if not LootGDB or not LootGDB.enabled then return end
        local typeIdentifier, link, quantity = ...
        if not link or link == "" then return end
        if typeIdentifier == "money" then return end
        -- 去重：跳过已由 LOOT_SLOT_CLEARED 显示的物品
        local dedupKey = GetIDFromLink(link)
        if dedupKey and recentlyShown[dedupKey] and (GetTime() - recentlyShown[dedupKey]) < 5 then return end
        quantity = quantity or 1
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
    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        if not LootGDB or not LootGDB.enabled then return end
        local message = ...
        local info = ChatTypeInfo["COMBAT_FACTION_CHANGE"]
        local colorCode = info and format("|cff%02x%02x%02x", info.r * 255, info.g * 255, info.b * 255) or "|cff00ffa0"
        CreateScrollingMessage(colorCode .. message .. "|r", 236681) -- Achievement_Reputation_01 fileID
    elseif event == "CHAT_MSG_SKILL" then
        if not LootGDB or not LootGDB.enabled then return end
        local message = ...
        local info = ChatTypeInfo["SKILL"]
        local colorCode = info and format("|cff%02x%02x%02x", info.r * 255, info.g * 255, info.b * 255) or "|cff5555ff"
        local skillName, skillLevel
        if ERR_SKILL_UP_SI then
            local pattern = ERR_SKILL_UP_SI:gsub("%%%d*%$?s", "(.-)"):gsub("%%%d*%$?d", "(%%d+)")
            pattern = pattern:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
            -- Restore captures that were escaped
            pattern = ERR_SKILL_UP_SI:gsub("%%%d*%$?s", "\001"):gsub("%%%d*%$?d", "\002")
            pattern = pattern:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
            pattern = pattern:gsub("\001", "(.-)"):gsub("\002", "(%%d+)")
            skillName, skillLevel = message:match(pattern)
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

-- ======= Slash Command =======

SLASH_LOOTG1 = "/lootg"
SlashCmdList["LOOTG"] = function(msg)
    if msg == "debug" then
        print("|cff00ff00[LootG Debug]|r enabled = " .. tostring(LootGDB and LootGDB.enabled))
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
        -- Open settings
        if LootG.SettingsCategory then
            Settings.OpenToCategory(LootG.SettingsCategory:GetID())
        end
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
        if LootG.SettingsCategory then
            Settings.OpenToCategory(LootG.SettingsCategory:GetID())
        end
    end
end
