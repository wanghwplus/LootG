local addonName, L = ...
local LootG = L

local AceGUI          = LibStub("AceGUI-3.0")
local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions    = LibStub("AceDBOptions-3.0")
local LSM             = LibStub("LibSharedMedia-3.0")

-- ==========================================================================
-- Refresh: reapply runtime state to on-screen frames. Every set-callback in
-- this panel calls it so preview is instant.
-- ==========================================================================
function LootG:RefreshAll()
    if self.ResetAnchor              then self:ResetAnchor()              end
    if self.UpdateAnchorVisibility   then self:UpdateAnchorVisibility()   end
    if self.ResetCSAnchor            then self:ResetCSAnchor()            end
    if self.UpdateCSAnchorVisibility then self:UpdateCSAnchorVisibility() end
end

-- ==========================================================================
-- Small AceGUI helpers modelled on MythicPlusBox/Options.lua.
-- Every setter triggers LootG:RefreshAll for instant preview.
-- ==========================================================================
local function AddSeparator(container, text)
    local h = AceGUI:Create("Heading")
    h:SetText(text or " ")
    h:SetFullWidth(true)
    container:AddChild(h)
    return h
end

local function AddCheckbox(container, label, getValue, setValue)
    local w = AceGUI:Create("CheckBox")
    w:SetLabel(label)
    w:SetValue(getValue())
    w:SetCallback("OnValueChanged", function(_, _, val)
        setValue(val)
        LootG:RefreshAll()
    end)
    container:AddChild(w)
    return w
end

local function AddSlider(container, label, minV, maxV, step, getValue, setValue)
    local w = AceGUI:Create("Slider")
    w:SetLabel(label)
    w:SetSliderValues(minV, maxV, step)
    w:SetValue(getValue())
    w:SetCallback("OnValueChanged", function(_, _, val)
        setValue(val)
        LootG:RefreshAll()
    end)
    container:AddChild(w)
    return w
end

local function AddDropdown(container, label, values, order, getValue, setValue)
    local w = AceGUI:Create("Dropdown")
    w:SetLabel(label)
    w:SetList(values, order)
    w:SetValue(getValue())
    w:SetCallback("OnValueChanged", function(_, _, val)
        setValue(val)
        LootG:RefreshAll()
    end)
    container:AddChild(w)
    return w
end

local function AddLSMFontDropdown(container, label, getValue, setValue)
    local fonts = LSM:HashTable("font")
    local order = {}
    for k in pairs(fonts) do table.insert(order, k) end
    table.sort(order)
    local w = AceGUI:Create("LSM30_Font")
    w:SetLabel(label)
    w:SetList(fonts, order)
    w:SetValue(getValue() or LSM:GetDefault("font"))
    w:SetCallback("OnValueChanged", function(_, _, val)
        setValue(val)
        LootG:RefreshAll()
    end)
    container:AddChild(w)
    return w
end

local function AddEditBox(container, label, getValue, setValue)
    local w = AceGUI:Create("EditBox")
    w:SetLabel(label)
    w:SetText(getValue() or "")
    w:SetFullWidth(true)
    w:SetCallback("OnEnterPressed", function(_, _, val)
        setValue(val)
        LootG:RefreshAll()
    end)
    container:AddChild(w)
    return w
end

local function AddHint(container, text)
    local w = AceGUI:Create("Label")
    w:SetText(text)
    w:SetFullWidth(true)
    container:AddChild(w)
    return w
end

-- ==========================================================================
-- Enum tables (values : L-key display names)
-- ==========================================================================
local function DirectionValues(includeHorizontal)
    local v = { UP = L["DIR_UP"], DOWN = L["DIR_DOWN"] }
    if includeHorizontal then
        v.LEFT  = L["DIR_LEFT"]
        v.RIGHT = L["DIR_RIGHT"]
    end
    return v
end

local DIRECTION_ORDER_UD  = { "UP", "DOWN" }
local DIRECTION_ORDER_ALL = { "UP", "DOWN", "LEFT", "RIGHT" }

local MODE_VALUES = { SCROLL = L["MODE_SCROLL"], STATIC = L["MODE_STATIC"] }
local MODE_ORDER  = { "SCROLL", "STATIC" }

local OUTLINE_VALUES = {
    [""]             = L["OUTLINE_NONE"],
    OUTLINE          = L["OUTLINE_OUTLINE"],
    THICKOUTLINE     = L["OUTLINE_THICKOUTLINE"],
    MONOCHROME       = L["OUTLINE_MONOCHROME"],
}
local OUTLINE_ORDER = { "", "OUTLINE", "THICKOUTLINE", "MONOCHROME" }

-- ==========================================================================
-- Tab: Loot Notification
-- ==========================================================================
local function DrawLootTab(container)
    local cfg = LootG.db.profile.loot

    AddSeparator(container, L["SECTION_GENERAL"])
    AddCheckbox(container, L["OPT_ENABLED"],   function() return cfg.enabled  end, function(v) cfg.enabled  = v end)
    AddCheckbox(container, L["OPT_LOCKED"],    function() return cfg.locked   end, function(v) cfg.locked   = v end)
    AddCheckbox(container, L["OPT_SHOW_ICON"], function() return cfg.showIcon end, function(v) cfg.showIcon = v end)

    AddSeparator(container, L["SECTION_FONT"])
    AddLSMFontDropdown(container, L["OPT_FONT"],
        function() return cfg.font end,
        function(v) cfg.font = v end)
    AddSlider(container, L["OPT_FONT_SIZE"], 8, 48, 1,
        function() return cfg.fontSize end,
        function(v) cfg.fontSize = v end)
    AddDropdown(container, L["OPT_FONT_OUTLINE"], OUTLINE_VALUES, OUTLINE_ORDER,
        function() return cfg.fontOutline end,
        function(v) cfg.fontOutline = v end)
    AddCheckbox(container, L["OPT_FONT_SHADOW"],
        function() return cfg.fontShadow end,
        function(v) cfg.fontShadow = v end)

    AddSeparator(container, L["SECTION_DISPLAY"])
    AddDropdown(container, L["OPT_SCROLL_DIRECTION"], DirectionValues(false), DIRECTION_ORDER_UD,
        function() return cfg.scrollDirection end,
        function(v) cfg.scrollDirection = v end)
    AddSlider(container, L["OPT_DISPLAY_TIME"], 0.1, 10, 0.1,
        function() return cfg.displayTime end,
        function(v) cfg.displayTime = v end)
    AddSlider(container, L["OPT_SCROLL_SPEED"], 0.1, 5, 0.1,
        function() return cfg.scrollSpeed end,
        function(v) cfg.scrollSpeed = v end)
    AddSlider(container, L["OPT_FADE_TIME"], 0.1, 3, 0.1,
        function() return cfg.fadeTime end,
        function(v) cfg.fadeTime = v end)

    AddSeparator(container, L["SECTION_POSITION"])
    AddSlider(container, L["OPT_X_OFFSET"], -800, 800, 1,
        function() return cfg.anchorX end,
        function(v) cfg.anchorX = v end)
    AddSlider(container, L["OPT_Y_OFFSET"], -600, 600, 1,
        function() return cfg.anchorY end,
        function(v) cfg.anchorY = v end)
end

-- ==========================================================================
-- Tab: Combat State
-- ==========================================================================
local function DrawCombatTab(container)
    local cfg = LootG.db.profile.combatState

    AddSeparator(container, L["SECTION_GENERAL"])
    AddCheckbox(container, L["OPT_ENABLED"], function() return cfg.enabled end, function(v) cfg.enabled = v end)
    AddCheckbox(container, L["OPT_LOCKED"],  function() return cfg.locked  end, function(v) cfg.locked  = v end)

    AddSeparator(container, L["SECTION_COMBAT_TEXT"])
    -- 数据库里空串表示"跟随客户端语言取本地化默认值"，但输入框应显示
    -- 生效的文本；保存时若等于默认值或为空则仍存空串，保留动态回退行为
    local enterDefault = L["ENTER_COMBAT"] or "Enter Combat"
    local leaveDefault = L["LEAVE_COMBAT"] or "Leave Combat"
    AddEditBox(container, L["OPT_ENTER_COMBAT_TEXT"],
        function()
            local cur = cfg.enterCombatText
            return (cur and cur ~= "") and cur or enterDefault
        end,
        function(v) cfg.enterCombatText = (v == enterDefault) and "" or v end)
    AddEditBox(container, L["OPT_LEAVE_COMBAT_TEXT"],
        function()
            local cur = cfg.leaveCombatText
            return (cur and cur ~= "") and cur or leaveDefault
        end,
        function(v) cfg.leaveCombatText = (v == leaveDefault) and "" or v end)
    AddHint(container, L["OPT_ENTER_COMBAT_HINT"])

    AddSeparator(container, L["SECTION_FONT"])
    AddLSMFontDropdown(container, L["OPT_FONT"],
        function() return cfg.font end,
        function(v) cfg.font = v end)
    AddSlider(container, L["OPT_FONT_SIZE"], 8, 72, 1,
        function() return cfg.fontSize end,
        function(v) cfg.fontSize = v end)
    AddDropdown(container, L["OPT_FONT_OUTLINE"], OUTLINE_VALUES, OUTLINE_ORDER,
        function() return cfg.fontOutline end,
        function(v) cfg.fontOutline = v end)
    AddCheckbox(container, L["OPT_FONT_SHADOW"],
        function() return cfg.fontShadow end,
        function(v) cfg.fontShadow = v end)

    AddSeparator(container, L["SECTION_DISPLAY"])
    AddDropdown(container, L["OPT_DISPLAY_MODE"], MODE_VALUES, MODE_ORDER,
        function() return cfg.displayMode end,
        function(v) cfg.displayMode = v end)
    AddDropdown(container, L["OPT_SCROLL_DIRECTION"], DirectionValues(true), DIRECTION_ORDER_ALL,
        function() return cfg.scrollDirection end,
        function(v) cfg.scrollDirection = v end)
    AddSlider(container, L["OPT_DISPLAY_TIME"], 0.1, 3, 0.1,
        function() return cfg.displayTime end,
        function(v) cfg.displayTime = v end)
    AddSlider(container, L["OPT_SCROLL_SPEED"], 0.1, 5, 0.1,
        function() return cfg.scrollSpeed end,
        function(v) cfg.scrollSpeed = v end)
    AddSlider(container, L["OPT_FADE_TIME"], 0.1, 3, 0.1,
        function() return cfg.fadeTime end,
        function(v) cfg.fadeTime = v end)

    AddSeparator(container, L["SECTION_POSITION"])
    AddSlider(container, L["OPT_X_OFFSET"], -800, 800, 1,
        function() return cfg.posX end,
        function(v) cfg.posX = v end)
    AddSlider(container, L["OPT_Y_OFFSET"], -600, 600, 1,
        function() return cfg.posY end,
        function(v) cfg.posY = v end)
end

-- ==========================================================================
-- Tab: Profiles (AceDBOptions embedded)
-- ==========================================================================
local function RegisterProfileOptions()
    if LootG._profileOptionsRegistered then return end
    LootG._profileOptionsRegistered = true
    AceConfig:RegisterOptionsTable("LootG_Profiles", AceDBOptions:GetOptionsTable(LootG.db))
end

-- ==========================================================================
-- Tab content dispatcher
-- ==========================================================================
-- AceGUI 回调签名为 (widget, 事件名, 值)，tab 值在第 3 个参数
local function BuildTabContent(container, _, group)
    container:ReleaseChildren()

    if group == "profiles" then
        -- AceConfigDialog:Open renders directly into the container.
        RegisterProfileOptions()
        AceConfigDialog:Open("LootG_Profiles", container)
        return
    end

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    container:AddChild(scroll)

    if group == "loot" then
        DrawLootTab(scroll)
    elseif group == "combat" then
        DrawCombatTab(scroll)
    end
end

-- ==========================================================================
-- Public entry: LootG:OpenOptions
-- ==========================================================================
function LootG:OpenOptions()
    if self._optionsFrame then
        self._optionsFrame:Show()
        return
    end

    local version = ""
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        version = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
    elseif GetAddOnMetadata then
        version = GetAddOnMetadata(addonName, "Version") or ""
    end

    local f = AceGUI:Create("Frame")
    f:SetTitle(L["LootG"] or "LootG")
    f:SetStatusText(version ~= "" and ("v" .. version) or "")
    f:SetLayout("Fill")
    f:SetWidth(720)
    f:SetHeight(560)
    f:SetCallback("OnClose", function(widget)
        -- Frames unlocked to reposition should not stay unlocked after the
        -- options window closes — otherwise a stray click drags them again.
        LootG.db.profile.loot.locked        = true
        LootG.db.profile.combatState.locked = true
        LootG:RefreshAll()
        AceGUI:Release(widget)
        LootG._optionsFrame = nil
        LootG._optionsTab   = nil
    end)
    self._optionsFrame = f

    local tab = AceGUI:Create("TabGroup")
    tab:SetLayout("Fill")
    tab:SetFullWidth(true)
    tab:SetFullHeight(true)
    tab:SetTabs({
        { text = L["TAB_LOOT"],     value = "loot"     },
        { text = L["TAB_COMBAT"],   value = "combat"   },
        { text = L["TAB_PROFILES"], value = "profiles" },
    })
    tab:SetCallback("OnGroupSelected", BuildTabContent)
    tab:SelectTab("loot")
    f:AddChild(tab)
    self._optionsTab = tab
end

-- ==========================================================================
-- Called from LootG.lua's anchor drag-stop so X/Y sliders pick up the
-- dragged values. AceGUI TabGroup writes to status or localstatus depending
-- on whether SetStatusTable was called (we don't); read both.
-- ==========================================================================
function LootG:RefreshOptionsUI()
    local tab = self._optionsTab
    if not tab then return end
    local status = tab.status or tab.localstatus
    if not status or not status.selected then return end
    tab:SelectTab(status.selected)
end
