local addonName, L = ...
local LootG = L
_G[addonName] = LootG

-- ======= Loot Notification =======

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("LOOT_READY")
f:RegisterEvent("LOOT_SLOT_CLEARED")
f:RegisterEvent("LOOT_CLOSED")
f:RegisterEvent("PLAYER_MONEY")
f:RegisterEvent("SHOW_LOOT_TOAST")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

local activeMessages = {}
local messagePool = {}
local lootCache = {}
local previousMoney = nil
local isLooting = false

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
    frame:SetScript("OnUpdate", nil)
    tinsert(messagePool, frame)
    -- Remove from active list
    for i, msg in ipairs(activeMessages) do
        if msg == frame then
            table.remove(activeMessages, i)
            break
        end
    end
end

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

    -- Push existing messages
    local offsetStep = (LootGDB.fontSize + 10) * frame.direction
    for _, active in ipairs(activeMessages) do
        active.baseOffset = active.baseOffset + offsetStep
    end

    table.insert(activeMessages, frame)

    frame:SetScript("OnUpdate", function(self, elapsed)
        local currTime = GetTime() - self.startTime

        -- Linear continuous scrolling (No distance limit)
        -- Speed derived from settings: traverse 100 pixels in 'scrollTime' seconds
        local speed = 100 / self.duration
        local animationOffset = speed * currTime

        local currentY = (animationOffset * self.direction) + self.baseOffset

        self:SetPoint("CENTER", anchor, "CENTER", 0, currentY)

        -- Fading
        if currTime > self.displayTime then
            local fadeProgress = (currTime - self.displayTime) / self.fadeSpeed
            if fadeProgress >= 1 then
                RecycleMessageFrame(self)
            else
                self:SetAlpha(1 - fadeProgress)
            end
        end
    end)
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
            csFrame:SetAlpha(1 - fadeProgress)
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
        local alpha = 1 - fadeProgress

        if alpha <= 0 then
            csFrame:SetAlpha(0)
            csFrame:Hide()
            csMode = nil
        else
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
        wipe(lootCache)
        for i = 1, GetNumLootItems() do
            local link = GetLootSlotLink(i)
            if link then
                local texture, _, quantity, _, quality = GetLootSlotInfo(i)
                local slotType = GetLootSlotType(i)
                lootCache[i] = {
                    link = link,
                    texture = texture,
                    quantity = quantity or 1,
                    quality = quality,
                    slotType = slotType,
                }
            end
        end
    elseif event == "LOOT_SLOT_CLEARED" then
        local slot = ...
        local cached = lootCache[slot]
        if not cached or not cached.link then return end

        local isCurrency = (cached.slotType == Enum.LootSlotType.Currency)
        ShowItemLoot(cached.link, cached.quantity, cached.texture, cached.quality, isCurrency)
        lootCache[slot] = nil
    elseif event == "LOOT_CLOSED" then
        isLooting = false
        wipe(lootCache)
    elseif event == "PLAYER_MONEY" then
        local currentMoney = GetMoney()
        if previousMoney and isLooting and currentMoney > previousMoney then
            local gained = currentMoney - previousMoney
            local moneyText = GetCoinTextureString(gained)
            local icon = "Interface\\Icons\\INV_Misc_Coin_02"
            CreateScrollingMessage(moneyText, icon)
        end
        previousMoney = currentMoney
    elseif event == "SHOW_LOOT_TOAST" then
        local typeIdentifier, link, quantity = ...
        if not link or link == "" then return end
        if typeIdentifier == "money" then return end

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
    if msg == "test" then
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
