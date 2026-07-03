local addonName, L = ...

-- Default (English)
local Locales = {
    -- Runtime strings (kept — read by LootG.lua at combat state flash time)
    ["ENTER_COMBAT"] = "Enter Combat",
    ["LEAVE_COMBAT"] = "Leave Combat",
    ["Loot"]         = "Loot",
    ["LootG"]        = "LootG",
    ["Combat State"] = "Combat State",

    -- Font display names shown in the LSM font dropdown fallback.
    -- Only referenced when Fonts\ paths surface in a legacy DB before migration.
    ["Fonts\\FRIZQT__.TTF"] = "Standard (Friz Quadrata)",
    ["Fonts\\ARIALN.TTF"]   = "Chat (Arial Narrow)",
    ["Fonts\\skurri.ttf"]   = "Damage (Skurri)",
    ["Fonts\\MORPHEUS.TTF"] = "Quest (Morpheus)",

    -- Subcategory / tab labels
    ["TAB_LOOT"]     = "Loot Notification",
    ["TAB_COMBAT"]   = "Combat State",
    ["TAB_PROFILES"] = "Profiles",

    -- Section headings
    ["SECTION_GENERAL"]     = "General",
    ["SECTION_FONT"]        = "Font",
    ["SECTION_ANIMATION"]   = "Animation",
    ["SECTION_POSITION"]    = "Position",
    ["SECTION_COMBAT_TEXT"] = "Combat Text",
    ["SECTION_DISPLAY"]     = "Display",

    -- Option labels
    ["OPT_ENABLED"]           = "Enabled",
    ["OPT_LOCKED"]            = "Lock Position",
    ["OPT_SHOW_ICON"]         = "Show Icon",
    ["OPT_FONT"]              = "Font",
    ["OPT_FONT_SIZE"]         = "Font Size",
    ["OPT_FONT_OUTLINE"]      = "Font Outline",
    ["OPT_FONT_SHADOW"]       = "Font Shadow",
    ["OPT_X_OFFSET"]          = "X Offset",
    ["OPT_Y_OFFSET"]          = "Y Offset",
    ["OPT_SCROLL_DIRECTION"]  = "Scroll Direction",
    ["OPT_DISPLAY_TIME"]      = "Display Time (s)",
    ["OPT_SCROLL_TIME"]       = "Scroll Time (s)",
    ["OPT_FADE_SPEED"]        = "Fade Speed (s)",
    ["OPT_DISPLAY_MODE"]      = "Display Mode",
    ["OPT_SCROLL_SPEED"]      = "Scroll Speed",
    ["OPT_FADE_TIME"]         = "Fade Time (s)",
    ["OPT_ENTER_COMBAT_TEXT"] = "Enter Combat Text",
    ["OPT_LEAVE_COMBAT_TEXT"] = "Leave Combat Text",
    ["OPT_ENTER_COMBAT_HINT"] = "Leave empty to use the localized default.",

    -- Direction / mode / outline enum labels
    ["DIR_UP"]         = "Up",
    ["DIR_DOWN"]       = "Down",
    ["DIR_LEFT"]       = "Left",
    ["DIR_RIGHT"]      = "Right",
    ["MODE_SCROLL"]    = "Scroll",
    ["MODE_STATIC"]    = "Static",
    ["OUTLINE_NONE"]         = "None",
    ["OUTLINE_OUTLINE"]      = "Thin Outline",
    ["OUTLINE_THICKOUTLINE"] = "Thick Outline",
    ["OUTLINE_MONOCHROME"]   = "Monochrome",

    -- Blizzard stub category (interface-options entry)
    ["BLIZZARD_STUB_HINT"]   = "Type /lootg to open the LootG options window.",
    ["BLIZZARD_STUB_BUTTON"] = "Open LootG Options",
}

local gameLocale = GetLocale()

if gameLocale == "zhCN" then
    Locales["ENTER_COMBAT"] = "进入战斗"
    Locales["LEAVE_COMBAT"] = "脱离战斗"
    Locales["Loot"]         = "拾取"
    Locales["Combat State"] = "战斗状态"

    Locales["Fonts\\FRIZQT__.TTF"] = "标准 (Friz Quadrata)"
    Locales["Fonts\\ARIALN.TTF"]   = "聊天 (Arial Narrow)"
    Locales["Fonts\\skurri.ttf"]   = "伤害 (Skurri)"
    Locales["Fonts\\MORPHEUS.TTF"] = "任务 (Morpheus)"

    Locales["TAB_LOOT"]     = "拾取通知"
    Locales["TAB_COMBAT"]   = "战斗状态"
    Locales["TAB_PROFILES"] = "配置文件"

    Locales["SECTION_GENERAL"]     = "通用"
    Locales["SECTION_FONT"]        = "字体"
    Locales["SECTION_ANIMATION"]   = "动画"
    Locales["SECTION_POSITION"]    = "位置"
    Locales["SECTION_COMBAT_TEXT"] = "战斗文本"
    Locales["SECTION_DISPLAY"]     = "显示"

    Locales["OPT_ENABLED"]           = "启用"
    Locales["OPT_LOCKED"]            = "锁定位置"
    Locales["OPT_SHOW_ICON"]         = "显示图标"
    Locales["OPT_FONT"]              = "字体"
    Locales["OPT_FONT_SIZE"]         = "字号"
    Locales["OPT_FONT_OUTLINE"]      = "字体描边"
    Locales["OPT_FONT_SHADOW"]       = "字体阴影"
    Locales["OPT_X_OFFSET"]          = "X 偏移"
    Locales["OPT_Y_OFFSET"]          = "Y 偏移"
    Locales["OPT_SCROLL_DIRECTION"]  = "滚动方向"
    Locales["OPT_DISPLAY_TIME"]      = "显示时长 (秒)"
    Locales["OPT_SCROLL_TIME"]       = "滚动时长 (秒)"
    Locales["OPT_FADE_SPEED"]        = "渐隐速度 (秒)"
    Locales["OPT_DISPLAY_MODE"]      = "显示模式"
    Locales["OPT_SCROLL_SPEED"]      = "滚动速度"
    Locales["OPT_FADE_TIME"]         = "渐隐时间 (秒)"
    Locales["OPT_ENTER_COMBAT_TEXT"] = "进入战斗文本"
    Locales["OPT_LEAVE_COMBAT_TEXT"] = "脱离战斗文本"
    Locales["OPT_ENTER_COMBAT_HINT"] = "留空以使用本地化默认值。"

    Locales["DIR_UP"]    = "向上"
    Locales["DIR_DOWN"]  = "向下"
    Locales["DIR_LEFT"]  = "向左"
    Locales["DIR_RIGHT"] = "向右"
    Locales["MODE_SCROLL"] = "滚动"
    Locales["MODE_STATIC"] = "静态"
    Locales["OUTLINE_NONE"]         = "无"
    Locales["OUTLINE_OUTLINE"]      = "细描边"
    Locales["OUTLINE_THICKOUTLINE"] = "粗描边"
    Locales["OUTLINE_MONOCHROME"]   = "单色"

    Locales["BLIZZARD_STUB_HINT"]   = "输入 /lootg 打开 LootG 设置窗口。"
    Locales["BLIZZARD_STUB_BUTTON"] = "打开 LootG 设置"

elseif gameLocale == "zhTW" then
    Locales["ENTER_COMBAT"] = "進入戰鬥"
    Locales["LEAVE_COMBAT"] = "脫離戰鬥"
    Locales["Loot"]         = "拾取"
    Locales["Combat State"] = "戰鬥狀態"

    Locales["Fonts\\FRIZQT__.TTF"] = "標準 (Friz Quadrata)"
    Locales["Fonts\\ARIALN.TTF"]   = "聊天 (Arial Narrow)"
    Locales["Fonts\\skurri.ttf"]   = "傷害 (Skurri)"
    Locales["Fonts\\MORPHEUS.TTF"] = "任務 (Morpheus)"

    Locales["TAB_LOOT"]     = "拾取通知"
    Locales["TAB_COMBAT"]   = "戰鬥狀態"
    Locales["TAB_PROFILES"] = "設定檔"

    Locales["SECTION_GENERAL"]     = "通用"
    Locales["SECTION_FONT"]        = "字體"
    Locales["SECTION_ANIMATION"]   = "動畫"
    Locales["SECTION_POSITION"]    = "位置"
    Locales["SECTION_COMBAT_TEXT"] = "戰鬥文字"
    Locales["SECTION_DISPLAY"]     = "顯示"

    Locales["OPT_ENABLED"]           = "啟用"
    Locales["OPT_LOCKED"]            = "鎖定位置"
    Locales["OPT_SHOW_ICON"]         = "顯示圖示"
    Locales["OPT_FONT"]              = "字體"
    Locales["OPT_FONT_SIZE"]         = "字號"
    Locales["OPT_FONT_OUTLINE"]      = "字體描邊"
    Locales["OPT_FONT_SHADOW"]       = "字體陰影"
    Locales["OPT_X_OFFSET"]          = "X 偏移"
    Locales["OPT_Y_OFFSET"]          = "Y 偏移"
    Locales["OPT_SCROLL_DIRECTION"]  = "滾動方向"
    Locales["OPT_DISPLAY_TIME"]      = "顯示時長 (秒)"
    Locales["OPT_SCROLL_TIME"]       = "滾動時長 (秒)"
    Locales["OPT_FADE_SPEED"]        = "漸隱速度 (秒)"
    Locales["OPT_DISPLAY_MODE"]      = "顯示模式"
    Locales["OPT_SCROLL_SPEED"]      = "滾動速度"
    Locales["OPT_FADE_TIME"]         = "漸隱時間 (秒)"
    Locales["OPT_ENTER_COMBAT_TEXT"] = "進入戰鬥文字"
    Locales["OPT_LEAVE_COMBAT_TEXT"] = "脫離戰鬥文字"
    Locales["OPT_ENTER_COMBAT_HINT"] = "留空以使用本地化預設值。"

    Locales["DIR_UP"]    = "向上"
    Locales["DIR_DOWN"]  = "向下"
    Locales["DIR_LEFT"]  = "向左"
    Locales["DIR_RIGHT"] = "向右"
    Locales["MODE_SCROLL"] = "滾動"
    Locales["MODE_STATIC"] = "靜態"
    Locales["OUTLINE_NONE"]         = "無"
    Locales["OUTLINE_OUTLINE"]      = "細描邊"
    Locales["OUTLINE_THICKOUTLINE"] = "粗描邊"
    Locales["OUTLINE_MONOCHROME"]   = "單色"

    Locales["BLIZZARD_STUB_HINT"]   = "輸入 /lootg 打開 LootG 設定視窗。"
    Locales["BLIZZARD_STUB_BUTTON"] = "打開 LootG 設定"
end

for k, v in pairs(Locales) do
    L[k] = v
end
