local addonName, L = ...
local LootG = L

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
    fontShadow = true,
    fontOutline = "OUTLINE",
}

LootG.CombatStateDefaults = {
    enabled = true,
    locked = true,
    posX = 0,
    posY = 250,
    displayTime = 0.6,
    fadeTime = 0.1,
    scrollSpeed = 1.5,
    scrollDirection = "UP",
    displayMode = "SCROLL",
    fontPath = "Fonts\\FRIZQT__.TTF",
    fontSize = 38,
    fontOutline = "OUTLINE",
    fontShadow = true,
    enterCombatText = L["ENTER_COMBAT"],
    leaveCombatText = L["LEAVE_COMBAT"],
}

-- Shared data
local fonts = {
    { path = "Fonts\\FRIZQT__.TTF", name = "Fonts\\FRIZQT__.TTF" },
    { path = "Fonts\\ARIALN.TTF", name = "Fonts\\ARIALN.TTF" },
    { path = "Fonts\\skurri.ttf", name = "Fonts\\skurri.ttf" },
    { path = "Fonts\\MORPHEUS.TTF", name = "Fonts\\MORPHEUS.TTF" },
}

local outlines = {
    { key = "", display = "None" },
    { key = "OUTLINE", display = "OUTLINE" },
    { key = "THICKOUTLINE", display = "THICKOUTLINE" },
    { key = "MONOCHROME", display = "MONOCHROME" },
}

------------------------------------------------------------
-- Reusable UI Factory Functions
------------------------------------------------------------

local dropdownCounter = 0

local function CreateConfigCheckbox(parent, label, dbTable, dbKey, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb.Text:SetText(label)
    cb:SetScript("OnClick", function(self)
        dbTable[dbKey] = self:GetChecked()
        if onChange then onChange(self:GetChecked()) end
    end)
    cb.Refresh = function()
        cb:SetChecked(dbTable[dbKey])
    end
    return cb
end

local function CreateConfigSlider(parent, label, dbTable, dbKey, minVal, maxVal, step)
    dropdownCounter = dropdownCounter + 1
    local name = "LootG_Slider_" .. dropdownCounter .. "_" .. dbKey
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(180)
    slider:SetHeight(17)

    if _G[name .. "Text"] then _G[name .. "Text"]:SetText(label) end
    if _G[name .. "Low"] then _G[name .. "Low"]:SetText(minVal) end
    if _G[name .. "High"] then _G[name .. "High"]:SetText(maxVal) end

    local valueText = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, -2)

    local function UpdateText(val)
        valueText:SetText(string.format("%.1f", val))
    end

    slider.isRefreshing = false

    slider:SetScript("OnValueChanged", function(self, value)
        if not self.isRefreshing then
            dbTable[dbKey] = value
        end
        UpdateText(value)
    end)

    slider.Refresh = function()
        slider.isRefreshing = true
        local val = dbTable[dbKey] or minVal
        slider:SetValue(val)
        UpdateText(val)
        slider.isRefreshing = false
    end

    return slider
end

local function CreateLabeledEditBox(parent, label, dbTable, dbKey, syncControls, syncKey, onCommit)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(300, 30)

    local fs = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("LEFT", 0, 0)
    fs:SetText(label)

    local eb = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    eb:SetSize(80, 20)
    eb:SetPoint("LEFT", fs, "RIGHT", 10, 0)
    eb:SetAutoFocus(false)

    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetSize(40, 22)
    btn:SetText("OK")
    btn:SetPoint("LEFT", eb, "RIGHT", 5, 0)
    btn:Hide()

    local function UpdateDisplay()
        local val = dbTable[dbKey] or 0
        eb:SetText(string.format("%.1f", val))
        eb:SetCursorPosition(0)
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
            dbTable[dbKey] = val
            if onCommit then onCommit() end
        end
        eb:ClearFocus()
        btn:Hide()
    end

    eb:SetScript("OnEnterPressed", Commit)
    btn:SetScript("OnClick", Commit)

    if syncControls and syncKey then
        syncControls[syncKey] = {
            SetValue = function(self, val)
                if not eb:HasFocus() then
                    eb:SetText(string.format("%.1f", val))
                    eb:SetCursorPosition(0)
                end
            end
        }
    end

    frame.Refresh = UpdateDisplay
    return frame
end

local function CreateTextEditBox(parent, label, dbTable, dbKey)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(400, 30)

    local fs = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("LEFT", 0, 0)
    fs:SetText(label)

    local eb = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    eb:SetSize(180, 20)
    eb:SetPoint("LEFT", fs, "RIGHT", 10, 0)
    eb:SetAutoFocus(false)

    local function UpdateDisplay()
        eb:SetText(dbTable[dbKey] or "")
        eb:SetCursorPosition(0)
    end

    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        UpdateDisplay()
    end)

    eb:SetScript("OnEnterPressed", function(self)
        dbTable[dbKey] = self:GetText()
        self:ClearFocus()
    end)

    frame.Refresh = UpdateDisplay
    return frame
end

local function CreateFontDropdown(parent, dbTable, dbKey, uniqueId)
    dropdownCounter = dropdownCounter + 1
    local dropFrame = CreateFrame("Frame", nil, parent)
    dropFrame:SetSize(400, 40)

    local fontLabel = dropFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fontLabel:SetPoint("LEFT", 0, 0)
    fontLabel:SetText(L["Font"])

    local ddName = "LootG_FontDD_" .. uniqueId .. "_" .. dropdownCounter
    local dropdown = CreateFrame("Frame", ddName, dropFrame, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", fontLabel, "RIGHT", 10, -2)
    UIDropDownMenu_SetWidth(dropdown, 180)

    local function Initialize(self, level)
        local currentFont = dbTable[dbKey] or fonts[1].path
        for i, fontData in ipairs(fonts) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = L[fontData.name] or fontData.name
            info.value = fontData.path
            info.func = function(self)
                dbTable[dbKey] = self.value
                UIDropDownMenu_SetSelectedValue(dropdown, self.value)
                UIDropDownMenu_SetText(dropdown, L[self.value] or self.value)
            end
            info.checked = (currentFont == fontData.path)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, Initialize)

    dropFrame.Refresh = function()
        local currentFont = dbTable[dbKey] or fonts[1].path
        UIDropDownMenu_SetSelectedValue(dropdown, currentFont)
        UIDropDownMenu_SetText(dropdown, L[currentFont] or currentFont)
        UIDropDownMenu_Initialize(dropdown, Initialize)
    end

    return dropFrame
end

local function CreateOutlineDropdown(parent, dbTable, dbKey, uniqueId)
    dropdownCounter = dropdownCounter + 1
    local dropFrame = CreateFrame("Frame", nil, parent)
    dropFrame:SetSize(400, 40)

    local outlineLabel = dropFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    outlineLabel:SetPoint("LEFT", 0, 0)
    outlineLabel:SetText(L["Font Outline"])

    local ddName = "LootG_OutlineDD_" .. uniqueId .. "_" .. dropdownCounter
    local dropdown = CreateFrame("Frame", ddName, dropFrame, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", outlineLabel, "RIGHT", 10, -2)
    UIDropDownMenu_SetWidth(dropdown, 180)

    local function Initialize(self, level)
        local currentOutline = dbTable[dbKey] or "OUTLINE"
        for i, outlineData in ipairs(outlines) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = L[outlineData.display] or outlineData.display
            info.value = outlineData.key
            info.func = function(self)
                dbTable[dbKey] = self.value
                UIDropDownMenu_SetSelectedValue(dropdown, self.value)
                for _, data in ipairs(outlines) do
                    if data.key == self.value then
                        UIDropDownMenu_SetText(dropdown, L[data.display] or data.display)
                        break
                    end
                end
            end
            info.checked = (currentOutline == outlineData.key)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, Initialize)

    dropFrame.Refresh = function()
        local current = dbTable[dbKey] or "OUTLINE"
        UIDropDownMenu_SetSelectedValue(dropdown, current)
        for _, outlineData in ipairs(outlines) do
            if outlineData.key == current then
                UIDropDownMenu_SetText(dropdown, L[outlineData.display] or outlineData.display)
                break
            end
        end
        UIDropDownMenu_Initialize(dropdown, Initialize)
    end

    return dropFrame
end

local function CreateScrollDirectionDropdown(parent, dbTable, dbKey, uniqueId, directions)
    dropdownCounter = dropdownCounter + 1
    local dropFrame = CreateFrame("Frame", nil, parent)
    dropFrame:SetSize(400, 40)

    local dirLabel = dropFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dirLabel:SetPoint("LEFT", 0, 0)
    dirLabel:SetText(L["Scroll Direction"])

    local ddName = "LootG_DirDD_" .. uniqueId .. "_" .. dropdownCounter
    local dropdown = CreateFrame("Frame", ddName, dropFrame, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", dirLabel, "RIGHT", 10, -2)
    UIDropDownMenu_SetWidth(dropdown, 120)

    local function Initialize(self, level)
        local current = dbTable[dbKey] or "UP"
        for _, dir in ipairs(directions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = L[dir.display] or dir.display
            info.value = dir.value
            info.func = function(self)
                dbTable[dbKey] = self.value
                UIDropDownMenu_SetSelectedValue(dropdown, self.value)
                for _, d in ipairs(directions) do
                    if d.value == self.value then
                        UIDropDownMenu_SetText(dropdown, L[d.display] or d.display)
                        break
                    end
                end
            end
            info.checked = (current == dir.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, Initialize)

    dropFrame.Refresh = function()
        local current = dbTable[dbKey] or "UP"
        UIDropDownMenu_SetSelectedValue(dropdown, current)
        for _, dir in ipairs(directions) do
            if dir.value == current then
                UIDropDownMenu_SetText(dropdown, L[dir.display] or dir.display)
                break
            end
        end
        UIDropDownMenu_Initialize(dropdown, Initialize)
    end

    return dropFrame
end

------------------------------------------------------------
-- InitializeConfig
------------------------------------------------------------
function LootG:InitializeConfig()
    if not LootGDB then
        LootGDB = CopyTable(LootG.Defaults)
    end

    -- Ensure all top-level loot keys exist
    for k, v in pairs(LootG.Defaults) do
        if LootGDB[k] == nil then
            LootGDB[k] = v
        end
    end

    -- Initialize combatState sub-table
    if not LootGDB.combatState then
        LootGDB.combatState = CopyTable(LootG.CombatStateDefaults)
    else
        for k, v in pairs(LootG.CombatStateDefaults) do
            if LootGDB.combatState[k] == nil then
                LootGDB.combatState[k] = v
            end
        end
    end

    LootG.SettingsControls = LootG.SettingsControls or {}
    LootG.CSSettingsControls = LootG.CSSettingsControls or {}

    ------------------------------------------------------------
    -- Main Canvas (Plugin Intro)
    ------------------------------------------------------------
    local mainCanvas = CreateFrame("Frame", addonName .. "MainCanvas")

    local mainTitle = mainCanvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    mainTitle:SetPoint("TOPLEFT", mainCanvas, "TOPLEFT", 16, -16)
    mainTitle:SetText("LootG")

    local mainVersion = mainCanvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    mainVersion:SetPoint("TOPLEFT", mainTitle, "BOTTOMLEFT", 0, -8)
    mainVersion:SetText("v1.0.0")

    local mainDesc = mainCanvas:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    mainDesc:SetPoint("TOPLEFT", mainVersion, "BOTTOMLEFT", 0, -16)
    mainDesc:SetPoint("RIGHT", mainCanvas, "RIGHT", -16, 0)
    mainDesc:SetJustifyH("LEFT")
    mainDesc:SetJustifyV("TOP")
    mainDesc:SetText(L["LootG_Intro"])

    local category = Settings.RegisterCanvasLayoutCategory(mainCanvas, L["LootG"])
    LootG.SettingsCategory = category

    ------------------------------------------------------------
    -- Loot Notification Subcategory Canvas
    ------------------------------------------------------------
    local lootCanvas = CreateFrame("Frame", addonName .. "LootCanvas")
    lootCanvas:SetScript("OnShow", function(self)
        if self.Refresh then self:Refresh() end
        if LootG.HideLockPopup then LootG:HideLockPopup() end
    end)
    lootCanvas:SetScript("OnHide", function(self)
        if LootG.ShowLockPopup then LootG:ShowLockPopup() end
    end)

    -- Layout helpers for loot canvas
    local lootLastObject = nil
    local lootSliderRowAnchor = nil

    local function LootAddTop(obj, offset)
        obj:SetPoint("TOPLEFT", lootCanvas, "TOPLEFT", 16, offset or -16)
        lootLastObject = obj
    end
    local function LootAddNext(obj, offset)
        obj:SetPoint("TOPLEFT", lootLastObject, "BOTTOMLEFT", 0, offset or -16)
        lootLastObject = obj
    end
    local function LootAddSliderLeft(slider, offset)
        if lootSliderRowAnchor then
            slider:SetPoint("TOPLEFT", lootSliderRowAnchor, "BOTTOMLEFT", 0, offset or -45)
        else
            slider:SetPoint("TOPLEFT", lootLastObject, "BOTTOMLEFT", 0, offset or -45)
        end
        lootSliderRowAnchor = slider
    end
    local function LootAddSliderRight(slider)
        slider:SetPoint("TOPLEFT", lootSliderRowAnchor, "TOPLEFT", 240, 0)
    end

    -- Title
    local lootTitle = lootCanvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    lootTitle:SetText(L["Loot Notification"])
    LootAddTop(lootTitle)

    -- Enabled Checkbox
    local lootEnabledCB = CreateConfigCheckbox(lootCanvas, L["Enabled"], LootGDB, "enabled")
    LootAddNext(lootEnabledCB, -20)

    -- Locked Checkbox
    local lootLockedCB = CreateConfigCheckbox(lootCanvas, L["Locked"], LootGDB, "locked", function(checked)
        if LootG.UpdateAnchorVisibility then LootG:UpdateAnchorVisibility() end
    end)
    LootAddNext(lootLockedCB, -10)

    -- Show Icon Checkbox
    local lootIconCB = CreateConfigCheckbox(lootCanvas, L["Show Icon"], LootGDB, "showIcon")
    LootAddNext(lootIconCB, -10)

    -- X Offset
    local lootXFrame = CreateLabeledEditBox(lootCanvas, L["X Offset"], LootGDB, "anchorX", LootG.SettingsControls, "AnchorX", function()
        if LootG.ResetAnchor then LootG:ResetAnchor() end
    end)
    LootAddNext(lootXFrame, -10)

    -- Y Offset
    local lootYFrame = CreateLabeledEditBox(lootCanvas, L["Y Offset"], LootGDB, "anchorY", LootG.SettingsControls, "AnchorY", function()
        if LootG.ResetAnchor then LootG:ResetAnchor() end
    end)
    LootAddNext(lootYFrame, -5)

    -- Scroll Direction Dropdown (UP/DOWN)
    local lootDirDropdown = CreateScrollDirectionDropdown(lootCanvas, LootGDB, "scrollDirection", "loot", {
        { value = "UP", display = "Up" },
        { value = "DOWN", display = "Down" },
    })
    LootAddNext(lootDirDropdown, -5)

    -- Sliders Row 1: Display Time | Scroll Time
    local ls1 = CreateConfigSlider(lootCanvas, L["displayTime"], LootGDB, "displayTime", 0.5, 10, 0.5)
    LootAddSliderLeft(ls1, -45)

    local ls2 = CreateConfigSlider(lootCanvas, L["scrollTime"], LootGDB, "scrollTime", 0.1, 5, 0.1)
    LootAddSliderRight(ls2)

    -- Sliders Row 2: Fade Speed | Font Size
    local ls3 = CreateConfigSlider(lootCanvas, L["fadeSpeed"], LootGDB, "fadeSpeed", 0.1, 2, 0.1)
    LootAddSliderLeft(ls3, -45)

    local ls4 = CreateConfigSlider(lootCanvas, L["fontSize"], LootGDB, "fontSize", 8, 48, 1)
    LootAddSliderRight(ls4)

    -- Update lastObject after sliders
    lootLastObject = lootSliderRowAnchor

    -- Font Dropdown
    local lootFontDropdown = CreateFontDropdown(lootCanvas, LootGDB, "fontPath", "loot")
    LootAddNext(lootFontDropdown, -35)

    -- Outline Dropdown
    local lootOutlineDropdown = CreateOutlineDropdown(lootCanvas, LootGDB, "fontOutline", "loot")
    LootAddNext(lootOutlineDropdown, -5)

    -- Font Shadow Checkbox (same line as outline dropdown)
    local lootShadowCB = CreateConfigCheckbox(lootCanvas, L["Font Shadow"], LootGDB, "fontShadow")
    lootShadowCB:SetPoint("TOPLEFT", lootOutlineDropdown, "TOPLEFT", 300, 0)

    -- Refresh Function for Loot Canvas
    lootCanvas.Refresh = function()
        lootEnabledCB.Refresh()
        lootLockedCB.Refresh()
        lootIconCB.Refresh()
        lootShadowCB.Refresh()
        lootXFrame.Refresh()
        lootYFrame.Refresh()
        ls1.Refresh()
        ls2.Refresh()
        ls3.Refresh()
        ls4.Refresh()
        lootDirDropdown.Refresh()
        lootFontDropdown.Refresh()
        lootOutlineDropdown.Refresh()
    end

    lootCanvas.Refresh()

    local lootSubCat = Settings.RegisterCanvasLayoutSubcategory(category, lootCanvas, L["Loot Notification"])

    ------------------------------------------------------------
    -- Combat State Subcategory Canvas
    ------------------------------------------------------------
    local csCanvas = CreateFrame("Frame", addonName .. "CSCanvas")
    csCanvas:SetHeight(800)
    csCanvas:SetScript("OnShow", function(self)
        if self.Refresh then self:Refresh() end
        if LootG.HideCSLockPopup then LootG:HideCSLockPopup() end
    end)
    csCanvas:SetScript("OnHide", function(self)
        if LootG.ShowCSLockPopup then LootG:ShowCSLockPopup() end
    end)

    local csDB = LootGDB.combatState

    -- Layout helpers for CS canvas
    local csLastObject = nil
    local csSliderRowAnchor = nil

    local function CSAddTop(obj, offset)
        obj:SetPoint("TOPLEFT", csCanvas, "TOPLEFT", 16, offset or -16)
        csLastObject = obj
    end
    local function CSAddNext(obj, offset)
        obj:SetPoint("TOPLEFT", csLastObject, "BOTTOMLEFT", 0, offset or -16)
        csLastObject = obj
    end
    local function CSAddSliderLeft(slider, offset)
        if csSliderRowAnchor then
            slider:SetPoint("TOPLEFT", csSliderRowAnchor, "BOTTOMLEFT", 0, offset or -45)
        else
            slider:SetPoint("TOPLEFT", csLastObject, "BOTTOMLEFT", 0, offset or -45)
        end
        csSliderRowAnchor = slider
    end
    local function CSAddSliderRight(slider)
        slider:SetPoint("TOPLEFT", csSliderRowAnchor, "TOPLEFT", 240, 0)
    end

    -- Title
    local csTitle = csCanvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    csTitle:SetText(L["Combat State"])
    CSAddTop(csTitle)

    -- Enabled Checkbox
    local csEnabledCB = CreateConfigCheckbox(csCanvas, L["Enabled"], csDB, "enabled")
    CSAddNext(csEnabledCB, -20)

    -- Locked Checkbox
    local csLockedCB = CreateConfigCheckbox(csCanvas, L["Locked"], csDB, "locked", function(checked)
        if LootG.UpdateCSAnchorVisibility then LootG:UpdateCSAnchorVisibility() end
    end)
    CSAddNext(csLockedCB, -10)

    -- X Offset
    local csXFrame = CreateLabeledEditBox(csCanvas, L["X Offset"], csDB, "posX", LootG.CSSettingsControls, "PosX", function()
        if LootG.ResetCSAnchor then LootG:ResetCSAnchor() end
    end)
    CSAddNext(csXFrame, -10)

    -- Y Offset
    local csYFrame = CreateLabeledEditBox(csCanvas, L["Y Offset"], csDB, "posY", LootG.CSSettingsControls, "PosY", function()
        if LootG.ResetCSAnchor then LootG:ResetCSAnchor() end
    end)
    CSAddNext(csYFrame, -5)

    -- Enter Combat Text
    local csEnterTextBox = CreateTextEditBox(csCanvas, L["CS Enter Text"], csDB, "enterCombatText")
    CSAddNext(csEnterTextBox, -10)

    -- Leave Combat Text
    local csLeaveTextBox = CreateTextEditBox(csCanvas, L["CS Leave Text"], csDB, "leaveCombatText")
    CSAddNext(csLeaveTextBox, -5)

    -- Display Mode Dropdown (SCROLL/STATIC)
    dropdownCounter = dropdownCounter + 1
    local csModeDropFrame = CreateFrame("Frame", nil, csCanvas)
    csModeDropFrame:SetSize(400, 40)

    local csModeLabel = csModeDropFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    csModeLabel:SetPoint("LEFT", 0, 0)
    csModeLabel:SetText(L["CS Display Mode"])

    local csModeDDName = "LootG_ModeDD_" .. dropdownCounter
    local csModeDropdown = CreateFrame("Frame", csModeDDName, csModeDropFrame, "UIDropDownMenuTemplate")
    csModeDropdown:SetPoint("LEFT", csModeLabel, "RIGHT", 10, -2)
    UIDropDownMenu_SetWidth(csModeDropdown, 120)

    local displayModes = {
        { value = "SCROLL", display = "Scroll" },
        { value = "STATIC", display = "Static" },
    }

    local function ModeDropdown_Initialize(self, level)
        local current = csDB.displayMode or "SCROLL"
        for _, modeData in ipairs(displayModes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = L[modeData.display] or modeData.display
            info.value = modeData.value
            info.func = function(self)
                csDB.displayMode = self.value
                UIDropDownMenu_SetSelectedValue(csModeDropdown, self.value)
                for _, d in ipairs(displayModes) do
                    if d.value == self.value then
                        UIDropDownMenu_SetText(csModeDropdown, L[d.display] or d.display)
                        break
                    end
                end
            end
            info.checked = (current == modeData.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(csModeDropdown, ModeDropdown_Initialize)

    csModeDropFrame.Refresh = function()
        local current = csDB.displayMode or "SCROLL"
        UIDropDownMenu_SetSelectedValue(csModeDropdown, current)
        for _, modeData in ipairs(displayModes) do
            if modeData.value == current then
                UIDropDownMenu_SetText(csModeDropdown, L[modeData.display] or modeData.display)
                break
            end
        end
        UIDropDownMenu_Initialize(csModeDropdown, ModeDropdown_Initialize)
    end

    CSAddNext(csModeDropFrame, -5)

    -- Scroll Direction Dropdown (UP/DOWN/LEFT/RIGHT)
    local csDirDropdown = CreateScrollDirectionDropdown(csCanvas, csDB, "scrollDirection", "cs", {
        { value = "UP", display = "Up" },
        { value = "DOWN", display = "Down" },
        { value = "LEFT", display = "Left" },
        { value = "RIGHT", display = "Right" },
    })
    CSAddNext(csDirDropdown, -5)

    -- Sliders Row 1: Display Time | Scroll Speed
    local css1 = CreateConfigSlider(csCanvas, L["displayTime"], csDB, "displayTime", 0.1, 3, 0.1)
    CSAddSliderLeft(css1, -45)

    local css2 = CreateConfigSlider(csCanvas, L["scrollSpeed"], csDB, "scrollSpeed", 0.1, 5, 0.1)
    CSAddSliderRight(css2)

    -- Sliders Row 2: Fade Time | Font Size
    local css3 = CreateConfigSlider(csCanvas, L["fadeTime"], csDB, "fadeTime", 0.1, 3, 0.1)
    CSAddSliderLeft(css3, -45)

    local css4 = CreateConfigSlider(csCanvas, L["fontSize"], csDB, "fontSize", 8, 72, 1)
    CSAddSliderRight(css4)

    -- Update lastObject after sliders
    csLastObject = csSliderRowAnchor

    -- Font Dropdown
    local csFontDropdown = CreateFontDropdown(csCanvas, csDB, "fontPath", "cs")
    CSAddNext(csFontDropdown, -35)

    -- Outline Dropdown
    local csOutlineDropdown = CreateOutlineDropdown(csCanvas, csDB, "fontOutline", "cs")
    CSAddNext(csOutlineDropdown, -5)

    -- Font Shadow Checkbox (same line as outline dropdown)
    local csShadowCB = CreateConfigCheckbox(csCanvas, L["Font Shadow"], csDB, "fontShadow")
    csShadowCB:SetPoint("TOPLEFT", csOutlineDropdown, "TOPLEFT", 300, 0)

    -- Refresh Function for CS Canvas
    csCanvas.Refresh = function()
        csEnabledCB.Refresh()
        csLockedCB.Refresh()
        csXFrame.Refresh()
        csYFrame.Refresh()
        csModeDropFrame.Refresh()
        csDirDropdown.Refresh()
        css1.Refresh()
        css2.Refresh()
        css3.Refresh()
        css4.Refresh()
        csFontDropdown.Refresh()
        csOutlineDropdown.Refresh()
        csShadowCB.Refresh()
        csEnterTextBox.Refresh()
        csLeaveTextBox.Refresh()
    end

    csCanvas.Refresh()

    local csSubCat = Settings.RegisterCanvasLayoutSubcategory(category, csCanvas, L["Combat State"])

    -- Register the main category
    Settings.RegisterAddOnCategory(category)
end
