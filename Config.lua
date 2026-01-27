local addonName, L = ...
local LootG = L
-- _G[addonName] is not defined yet when this file loads if Core.lua is after it.
-- We use the shared namespace 'L' as the addon object.

LootG.Defaults = {
    displayTime = 3,
    scrollDirection = "UP",
    scrollTime = 1.5,
    fadeSpeed = 0.5,
    fontPath = "Fonts\\FRIZQT__.TTF",
    fontSize = 20,
    enabled = true,
    locked = true,
    showIcon = true,
    anchorX = 0,
    anchorY = 0,
    -- Font Shadow Setting
    fontShadow = true,
    -- Font Outline Setting
    fontOutline = "OUTLINE",
}

function LootG:InitializeConfig()
    if not LootGDB then
        LootGDB = CopyTable(LootG.Defaults)
    end
    
    -- Ensure all keys exist
    for k, v in pairs(LootG.Defaults) do
        if LootGDB[k] == nil then
            LootGDB[k] = v
        end
    end

    -- Create Canvas Frame for Manual Layout (Most robust way to handle custom UI requirements)
    local canvas = CreateFrame("Frame", addonName .. "ConfigCanvas")
    canvas:SetScript("OnShow", function(self)
        -- Refresh values when opened
        if self.Refresh then self:Refresh() end
        -- Hide lock popup when settings panel is open
        if LootG.HideLockPopup then LootG:HideLockPopup() end
    end)
    canvas:SetScript("OnHide", function(self)
        -- Show lock popup if unlocked when settings panel closes
        if LootG.ShowLockPopup then LootG:ShowLockPopup() end
    end)
    
    local category = Settings.RegisterCanvasLayoutCategory(canvas, L["LootG"])
    LootG.SettingsCategory = category
    Settings.RegisterAddOnCategory(category)
    
    -- Layout Helpers
    local lastObject = nil
    local leftColumnX = 16
    local rightColumnX = 280
    local currentColumn = "left"
    
    local function AddTop(obj, offset)
        obj:SetPoint("TOPLEFT", canvas, "TOPLEFT", leftColumnX, offset or -16)
        lastObject = obj
    end
    local function AddNext(obj, offset)
        obj:SetPoint("TOPLEFT", lastObject, "BOTTOMLEFT", 0, offset or -16)
        lastObject = obj
    end
    
    -- For two-column slider layout
    local sliderRowAnchor = nil
    local function AddSliderLeft(slider, offset)
        if sliderRowAnchor then
            slider:SetPoint("TOPLEFT", sliderRowAnchor, "BOTTOMLEFT", 0, offset or -45)
        else
            slider:SetPoint("TOPLEFT", lastObject, "BOTTOMLEFT", 0, offset or -45)
        end
        sliderRowAnchor = slider
    end
    local function AddSliderRight(slider, offset)
        slider:SetPoint("TOPLEFT", sliderRowAnchor, "TOPLEFT", 240, 0)
    end

    -- Title
    local title = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetText(L["LootG"])
    AddTop(title)

    -- Locked Checkbox
    local lockedCB = CreateFrame("CheckButton", nil, canvas, "InterfaceOptionsCheckButtonTemplate")
    lockedCB.Text:SetText(L["Locked"])
    lockedCB:SetScript("OnClick", function(self)
        LootGDB.locked = self:GetChecked()
        if LootG.UpdateAnchorVisibility then LootG:UpdateAnchorVisibility() end
    end)
    AddNext(lockedCB, -20)

    -- Show Icon Checkbox
    local iconCB = CreateFrame("CheckButton", nil, canvas, "InterfaceOptionsCheckButtonTemplate")
    iconCB.Text:SetText(L["Show Icon"])
    iconCB:SetScript("OnClick", function(self)
        LootGDB.showIcon = self:GetChecked()
    end)
    AddNext(iconCB, -10)
    
    -- Custom EditBox Creator
    local function CreateLabeledEditBox(label, dbKey, syncKey)
        local frame = CreateFrame("Frame", nil, canvas)
        frame:SetSize(300, 30)
        
        local fs = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fs:SetPoint("LEFT", 0, 0)
        fs:SetText(label)
        
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(40, 22)
        btn:SetText("OK")
        btn:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
        btn:Hide()
        
        local eb = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        eb:SetSize(120, 20)
        eb:SetPoint("RIGHT", btn, "LEFT", -10, 0)
        eb:SetAutoFocus(false)
        
        local function UpdateDisplay()
            local val = LootGDB[dbKey] or 0
            eb:SetText(string.format("%.1f", val))
            btn:Hide()
        end
        
        eb:SetScript("OnTextChanged", function(self)
            if not self:HasFocus() then return end
            btn:Show()
        end)
        
        eb:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            UpdateDisplay()
        end)
        
        local function Commit()
            local val = tonumber(eb:GetText())
            if val then
                LootGDB[dbKey] = val
                if LootG.ResetAnchor then LootG:ResetAnchor() end
            end
            eb:ClearFocus()
            btn:Hide()
        end
        
        eb:SetScript("OnEnterPressed", Commit)
        btn:SetScript("OnClick", Commit)
        
        -- Register for external sync
        LootG.SettingsControls = LootG.SettingsControls or {}
        LootG.SettingsControls[syncKey] = {
            SetValue = function(self, val)
                if not eb:HasFocus() then
                     eb:SetText(string.format("%.1f", val))
                end
            end
        }
        
        frame.Refresh = UpdateDisplay
        return frame
    end

    -- X Offset
    local xFrame = CreateLabeledEditBox(L["X Offset"], "anchorX", "AnchorX")
    AddNext(xFrame, -10)
    
    -- Y Offset
    local yFrame = CreateLabeledEditBox(L["Y Offset"], "anchorY", "AnchorY")
    AddNext(yFrame, -5)

    -- Sliders (compact width for 2 columns)
    local function CreateConfigSlider(label, dbKey, minVal, maxVal, step)
        local name = "LootG_Slider_" .. dbKey
        local slider = CreateFrame("Slider", name, canvas, "OptionsSliderTemplate")
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        slider:SetWidth(180)
        slider:SetHeight(17)
        
        -- Safe access to template regions
        if _G[name .. "Text"] then _G[name .. "Text"]:SetText(label) end
        if _G[name .. "Low"] then _G[name .. "Low"]:SetText(minVal) end
        if _G[name .. "High"] then _G[name .. "High"]:SetText(maxVal) end
        
        local valueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        valueText:SetPoint("TOP", slider, "BOTTOM", 0, -2)
        
        local function UpdateText(val)
            valueText:SetText(string.format("%.1f", val))
        end
        
        -- Flag to prevent OnValueChanged from saving during refresh
        slider.isRefreshing = false
        
        slider:SetScript("OnValueChanged", function(self, value)
            if not self.isRefreshing then
                LootGDB[dbKey] = value
            end
            UpdateText(value)
        end)
        
        slider.Refresh = function()
            slider.isRefreshing = true
            local val = LootGDB[dbKey] or minVal
            slider:SetValue(val)
            UpdateText(val)
            slider.isRefreshing = false
        end
        
        return slider
    end

    -- Row 1: Display Time | Scroll Time
    local s1 = CreateConfigSlider(L["Display Time"], "displayTime", 0.5, 10, 0.5)
    AddSliderLeft(s1, -45)
    
    local s2 = CreateConfigSlider(L["Scroll Time"], "scrollTime", 0.1, 5, 0.1)
    AddSliderRight(s2)

    -- Row 2: Fade Speed | Font Size
    local s3 = CreateConfigSlider(L["Fade Speed"], "fadeSpeed", 0.1, 2, 0.1)
    AddSliderLeft(s3, -45)
    
    local s4 = CreateConfigSlider(L["Font Size"], "fontSize", 8, 48, 1)
    AddSliderRight(s4)
    
    -- Update lastObject for next section
    lastObject = sliderRowAnchor

    -- Font Selector using UIDropDownMenu
    local fonts = {
        { path = "Fonts\\FRIZQT__.TTF", name = "Fonts\\FRIZQT__.TTF" },
        { path = "Fonts\\ARIALN.TTF", name = "Fonts\\ARIALN.TTF" },
        { path = "Fonts\\skurri.ttf", name = "Fonts\\skurri.ttf" },
        { path = "Fonts\\MORPHEUS.TTF", name = "Fonts\\MORPHEUS.TTF" },
    }
    
    local fontDropFrame = CreateFrame("Frame", nil, canvas)
    fontDropFrame:SetSize(400, 40)
    
    local fontLabel = fontDropFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fontLabel:SetPoint("LEFT", 0, 0)
    fontLabel:SetText(L["Font"])
    
    local fontDropdown = CreateFrame("Frame", "LootG_FontDropdown", fontDropFrame, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("LEFT", fontLabel, "RIGHT", 10, -2)
    UIDropDownMenu_SetWidth(fontDropdown, 180)
    
    local function FontDropdown_Initialize(self, level)
        local currentFont = LootGDB and LootGDB.fontPath or fonts[1].path
        for i, fontData in ipairs(fonts) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = L[fontData.name] or fontData.name
            info.value = fontData.path
            info.func = function(self)
                LootGDB.fontPath = self.value
                UIDropDownMenu_SetSelectedValue(fontDropdown, self.value)
                UIDropDownMenu_SetText(fontDropdown, L[self.value] or self.value)
            end
            info.checked = (currentFont == fontData.path)
            UIDropDownMenu_AddButton(info, level)
        end
    end
    
    UIDropDownMenu_Initialize(fontDropdown, FontDropdown_Initialize)
    
    fontDropFrame.Refresh = function()
        local currentFont = LootGDB.fontPath or fonts[1].path
        UIDropDownMenu_SetSelectedValue(fontDropdown, currentFont)
        UIDropDownMenu_SetText(fontDropdown, L[currentFont] or currentFont)
        -- Re-initialize to update checked states
        UIDropDownMenu_Initialize(fontDropdown, FontDropdown_Initialize)
    end
    
    AddNext(fontDropFrame, -35)
    
    -- Font Outline Dropdown using UIDropDownMenu
    local outlines = {
        { key = "", display = "None" },
        { key = "OUTLINE", display = "OUTLINE" },
        { key = "THICKOUTLINE", display = "THICKOUTLINE" },
        { key = "MONOCHROME", display = "MONOCHROME" },
    }
    
    local outlineDropFrame = CreateFrame("Frame", nil, canvas)
    outlineDropFrame:SetSize(400, 40)
    
    local outlineLabel = outlineDropFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    outlineLabel:SetPoint("LEFT", 0, 0)
    outlineLabel:SetText(L["Font Outline"])
    
    local outlineDropdown = CreateFrame("Frame", "LootG_OutlineDropdown", outlineDropFrame, "UIDropDownMenuTemplate")
    outlineDropdown:SetPoint("LEFT", outlineLabel, "RIGHT", 10, -2)
    UIDropDownMenu_SetWidth(outlineDropdown, 180)
    
    local function OutlineDropdown_Initialize(self, level)
        local currentOutline = LootGDB and LootGDB.fontOutline or "OUTLINE"
        for i, outlineData in ipairs(outlines) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = L[outlineData.display] or outlineData.display
            info.value = outlineData.key
            info.func = function(self)
                LootGDB.fontOutline = self.value
                UIDropDownMenu_SetSelectedValue(outlineDropdown, self.value)
                for _, data in ipairs(outlines) do
                    if data.key == self.value then
                        UIDropDownMenu_SetText(outlineDropdown, L[data.display] or data.display)
                        break
                    end
                end
            end
            info.checked = (currentOutline == outlineData.key)
            UIDropDownMenu_AddButton(info, level)
        end
    end
    
    UIDropDownMenu_Initialize(outlineDropdown, OutlineDropdown_Initialize)
    
    outlineDropFrame.Refresh = function()
        local current = LootGDB.fontOutline or "OUTLINE"
        UIDropDownMenu_SetSelectedValue(outlineDropdown, current)
        for _, outlineData in ipairs(outlines) do
            if outlineData.key == current then
                UIDropDownMenu_SetText(outlineDropdown, L[outlineData.display] or outlineData.display)
                break
            end
        end
        -- Re-initialize to update checked states
        UIDropDownMenu_Initialize(outlineDropdown, OutlineDropdown_Initialize)
    end
    
    AddNext(outlineDropFrame, -5)
    
    -- Font Shadow Checkbox (after font settings)
    local shadowCB = CreateFrame("CheckButton", nil, canvas, "InterfaceOptionsCheckButtonTemplate")
    shadowCB.Text:SetText(L["Font Shadow"])
    shadowCB:SetScript("OnClick", function(self)
        LootGDB.fontShadow = self:GetChecked()
    end)
    AddNext(shadowCB, -10)

    -- Refresh Function for Canvas
    canvas.Refresh = function()
        lockedCB:SetChecked(LootGDB.locked)
        iconCB:SetChecked(LootGDB.showIcon)
        shadowCB:SetChecked(LootGDB.fontShadow)
        xFrame.Refresh()
        yFrame.Refresh()
        s1.Refresh()
        s2.Refresh()
        s3.Refresh()
        s4.Refresh()
        fontDropFrame.Refresh()
        outlineDropFrame.Refresh()
    end
    
    -- Initial refresh to set correct values
    canvas.Refresh()
    
    -- Legacy / Fallback registration
    if InterfaceOptions_AddCategory then
         -- pass
    end
end
