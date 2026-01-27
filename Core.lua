local addonName, L = ...
local LootG = L
_G[addonName] = LootG

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_LOOT")
f:RegisterEvent("CHAT_MSG_MONEY")
f:RegisterEvent("CHAT_MSG_CURRENCY")

local activeMessages = {}
local messagePool = {}

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
        
        -- Shadow/Glow effect for premium look (REMOVED per user request)
        -- frame.bg = frame:CreateTexture(nil, "BACKGROUND")
        -- frame.bg:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") 
        -- frame.bg:SetAllPoints()
        -- frame.bg:SetColorTexture(0, 0, 0, 0.3) 
        
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

f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            LootG:InitializeConfig()
            LootG:ResetAnchor()
            LootG:UpdateAnchorVisibility()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "CHAT_MSG_MONEY" then
        local message = ...
        -- Money message is usually plain text like "You loot 1 Gold 40 Silver."
        -- We just display it with a coin icon.
        local icon = "Interface\\Icons\\INV_Misc_Coin_02"
        CreateScrollingMessage(message, icon)
        
    elseif event == "CHAT_MSG_CURRENCY" or event == "CHAT_MSG_LOOT" then
        local message, _, _, _, _, _, _, _, _, _, _, guid = ...
        
        -- Only show player's own loot, skip party/raid member loot
        if guid and guid ~= "" then
            local playerGUID = UnitGUID("player")
            if guid ~= playerGUID then
                -- This is another player's loot, skip it
                return
            end
        end
        
        -- Try Item Link
        local link = string.match(message, "(|Hitem:.-|h%[.-%]|h)")
        local isCurrency = false
        
        if not link then
            -- Try Currency Link
            link = string.match(message, "(|Hcurrency:.-|h%[.-%]|h)")
            isCurrency = true
        end
        
        if link then
            local texture = nil
            local nameColor = nil
            
            if isCurrency then
                 local currencyInfo = C_CurrencyInfo.GetCurrencyInfoFromLink(link)
                 if currencyInfo then
                     texture = currencyInfo.iconFileID
                     local quality = currencyInfo.quality
                     if quality then
                         local r, g, b, hex = GetItemQualityColor(quality)
                         nameColor = "|c" .. hex
                     end
                 end
            else
                 local _, _, quality, _, _, _, _, _, _, itemTexture = GetItemInfo(link)
                 texture = itemTexture
                 if quality then
                     local r, g, b, hex = GetItemQualityColor(quality)
                     nameColor = "|c" .. hex
                 end
            end
            
            local function ShowMessage(iconToUse, colorCode)
                -- Parsing Quantity
                local quantity = string.match(message, "x(%d+)%.") or string.match(message, "x(%d+)") or string.match(message, "数量: (%d+)") 
                quantity = quantity or "1"
                
                -- Formatting Display
                local displayLink = link
                displayLink = displayLink:gsub("(|h)%[(.-)%](|h)", "%1%2%3")
                
                -- Specific coloring for Currency (or items missing color tags)
                if colorCode then
                    if not displayLink:find("^|c") then
                        displayLink = colorCode .. displayLink .. "|r"
                    end
                end
                
                local displayText = L["Loot"] .. " " .. displayLink .. " x" .. quantity
                
                -- Bag Count (Only for Items, not Currency usually)
                -- Only show bag count if count > 0
                if not isCurrency then
                     local bagCount = GetItemCount(link)
                     if bagCount and bagCount > 0 then
                         displayText = displayText .. " (" .. bagCount .. ")"
                     end
                else
                     -- For currency, show total amount if > 0
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
                        local _, _, quality, _, _, _, _, _, _, loadedTexture = GetItemInfo(link)
                        ShowMessage(loadedTexture)
                    end)
                else
                    ShowMessage(nil) -- Fallback for currency if no info (rare)
                end
            end
        end
    end
end)

-- Slash Command for Testing
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
