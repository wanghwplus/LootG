local addonName, L = ...

-- Default (English)
local Locales = {
    ["Enabled"] = "Enabled",
    ["Enable Addon"] = "Enable or disable the scrolling loot messages.",
    ["Display Time"] = "Display Duration (s)",
    ["Scroll Direction"] = "Scroll Direction",
    ["Scroll Time"] = "Movement Duration (s)",
    ["Fade Speed"] = "Fade Out Speed (s)",
    ["Font Path"] = "Font File Path",
    ["Font Size"] = "Font Size",
    ["Up"] = "Up",
    ["Down"] = "Down",
    ["Left"] = "Left",
    ["Right"] = "Right",
    ["Settings"] = "LootG Settings",
    ["LootG_Desc"] = "Configuration for LootG scrolling loot messages.",
    ["LootG"] = "LootG",
    ["Locked"] = "Lock Position",
    ["Unlock_Desc"] = "Unlock to drag the anchor point to change message position.",
    ["X Offset"] = "X Coordinate",
    ["Y Offset"] = "Y Coordinate",
    ["Font"] = "Font",
    ["Fonts\\FRIZQT__.TTF"] = "Standard (Friz Quadrata)",
    ["Fonts\\ARIALN.TTF"] = "Chat (Arial Narrow)",
    ["Fonts\\skurri.ttf"] = "Damage (Skurri)",
    ["Fonts\\MORPHEUS.TTF"] = "Quest (Morpheus)",
    ["Show Icon"] = "Show Icon",
    ["Font Shadow"] = "Font Shadow",
    ["Shadow Offset X"] = "Shadow Offset X",
    ["Shadow Offset Y"] = "Shadow Offset Y",
    ["Shadow Color"] = "Shadow Color",
    ["Shadow Opacity"] = "Shadow Opacity",
    ["Show Party Loot"] = "Show Party/Raid Loot",
    ["Show Player Name"] = "Show Player Name",
    ["Font Outline"] = "Font Outline",
    ["None"] = "None",
    ["OUTLINE"] = "Thin Outline",
    ["THICKOUTLINE"] = "Thick Outline",
    ["MONOCHROME"] = "Monochrome",
    ["Loot"] = "Loot",
    -- Subcategory names
    ["Loot Notification"] = "Loot Notification",
    ["Combat State"] = "Combat State",
    -- Plugin intro
    ["LootG_Intro"] = "LootG is a lightweight loot notification and combat state display addon.\n\n- Scrolling loot messages in the center of the screen\n- Combat enter/leave flash text\n- Fully customizable fonts, positions, and animations\n\nType /lootg to open settings, /lootg test to test loot display.",
    -- Combat State locales
    ["ENTER_COMBAT"] = "Enter Combat",
    ["LEAVE_COMBAT"] = "Leave Combat",
    ["CS Display Mode"] = "Display Mode",
    ["Scroll"] = "Scroll",
    ["Static"] = "Static",
    ["CS Display Time"] = "Flash Duration (s)",
    ["CS Fade Time"] = "Fade Time (s)",
    ["CS Scroll Speed"] = "Scroll Speed",
    ["CS Scroll Distance"] = "Scroll Distance",
    ["CS Font Size"] = "Font Size",
    ["CS Enter Text"] = "Enter Combat Text",
    ["CS Leave Text"] = "Leave Combat Text",
    -- Slider labels
    ["displayTime"] = "Display Time",
    ["scrollTime"] = "Scroll Time",
    ["fadeSpeed"] = "Fade Speed",
    ["fontSize"] = "Font Size",
    ["fadeTime"] = "Fade Time",
    ["scrollSpeed"] = "Scroll Speed",
}

local gameLocale = GetLocale()

if gameLocale == "zhCN" then
    Locales["Enabled"] = "启用"
    Locales["Enable Addon"] = "启用或禁用拾取滚动消息。"
    Locales["Display Time"] = "显示持续时间 (秒)"
    Locales["Scroll Direction"] = "滚动方向"
    Locales["Scroll Time"] = "滚动时间 (秒)"
    Locales["Fade Speed"] = "渐隐速度 (秒)"
    Locales["Font Path"] = "字体路径"
    Locales["Font Size"] = "字号"
    Locales["Up"] = "向上"
    Locales["Down"] = "向下"
    Locales["Left"] = "向左"
    Locales["Right"] = "向右"
    Locales["Settings"] = "LootG 设置"
    Locales["LootG_Desc"] = "LootG 拾取物品滚动显示设置。"
    Locales["Locked"] = "锁定位置"
    Locales["Unlock_Desc"] = "取消锁定以拖动锚点改变显示位置。"
    Locales["X Offset"] = "X 坐标"
    Locales["Y Offset"] = "Y 坐标"
    Locales["Font"] = "字体"
    Locales["Fonts\\FRIZQT__.TTF"] = "标准 (Friz Quadrata)"
    Locales["Fonts\\ARIALN.TTF"] = "聊天 (Arial Narrow)"
    Locales["Fonts\\skurri.ttf"] = "伤害 (Skurri)"
    Locales["Fonts\\MORPHEUS.TTF"] = "任务 (Morpheus)"
    Locales["Show Icon"] = "显示图标"
    Locales["Font Shadow"] = "字体阴影"
    Locales["Shadow Offset X"] = "阴影偏移 X"
    Locales["Shadow Offset Y"] = "阴影偏移 Y"
    Locales["Shadow Color"] = "阴影颜色"
    Locales["Shadow Opacity"] = "阴影透明度"
    Locales["Show Party Loot"] = "显示队伍/团队拾取"
    Locales["Show Player Name"] = "显示玩家名字"
    Locales["Font Outline"] = "字体描边"
    Locales["None"] = "无"
    Locales["OUTLINE"] = "细描边"
    Locales["THICKOUTLINE"] = "粗描边"
    Locales["MONOCHROME"] = "单色"
    Locales["Loot"] = "拾取"
    -- Subcategory names
    Locales["Loot Notification"] = "拾取通知"
    Locales["Combat State"] = "战斗状态"
    -- Plugin intro
    Locales["LootG_Intro"] = "LootG 是一个轻量级的拾取通知和战斗状态显示插件。\n\n- 屏幕中央滚动显示拾取物品\n- 进入/脱离战斗闪烁文字提示\n- 完全自定义字体、位置和动画效果\n\n输入 /lootg 打开设置，/lootg test 测试拾取显示。"
    -- Combat State locales
    Locales["ENTER_COMBAT"] = "进入战斗"
    Locales["LEAVE_COMBAT"] = "脱离战斗"
    Locales["CS Display Mode"] = "显示模式"
    Locales["Scroll"] = "滚动"
    Locales["Static"] = "静态"
    Locales["CS Display Time"] = "闪烁时长 (秒)"
    Locales["CS Fade Time"] = "渐隐时间 (秒)"
    Locales["CS Scroll Speed"] = "滚动速度"
    Locales["CS Scroll Distance"] = "滚动距离"
    Locales["CS Font Size"] = "字号"
    Locales["CS Enter Text"] = "进入战斗文字"
    Locales["CS Leave Text"] = "脱离战斗文字"
    -- Slider labels
    Locales["displayTime"] = "显示时间"
    Locales["scrollTime"] = "滚动时间"
    Locales["fadeSpeed"] = "渐隐速度"
    Locales["fontSize"] = "字号"
    Locales["fadeTime"] = "渐隐时间"
    Locales["scrollSpeed"] = "滚动速度"
elseif gameLocale == "zhTW" then
    Locales["Enabled"] = "啟用"
    Locales["Enable Addon"] = "啟用或禁用拾取滾動消息。"
    Locales["Display Time"] = "顯示持續時間 (秒)"
    Locales["Scroll Direction"] = "滾動方向"
    Locales["Scroll Time"] = "滾動時間 (秒)"
    Locales["Fade Speed"] = "漸隱速度 (秒)"
    Locales["Font Path"] = "字體路徑"
    Locales["Font Size"] = "字號"
    Locales["Up"] = "向上"
    Locales["Down"] = "向下"
    Locales["Left"] = "向左"
    Locales["Right"] = "向右"
    Locales["Settings"] = "LootG 設置"
    Locales["LootG_Desc"] = "LootG 拾取物品滾動顯示設置。"
    Locales["Locked"] = "鎖定位置"
    Locales["Unlock_Desc"] = "取消鎖定以拖動錨點改變顯示位置。"
    Locales["X Offset"] = "X 座標"
    Locales["Y Offset"] = "Y 座標"
    Locales["Font"] = "字體"
    Locales["Fonts\\FRIZQT__.TTF"] = "標準 (Friz Quadrata)"
    Locales["Fonts\\ARIALN.TTF"] = "聊天 (Arial Narrow)"
    Locales["Fonts\\skurri.ttf"] = "傷害 (Skurri)"
    Locales["Fonts\\MORPHEUS.TTF"] = "任務 (Morpheus)"
    Locales["Show Icon"] = "顯示圖標"
    Locales["Font Shadow"] = "字體陰影"
    Locales["Shadow Offset X"] = "陰影偏移 X"
    Locales["Shadow Offset Y"] = "陰影偏移 Y"
    Locales["Shadow Color"] = "陰影顏色"
    Locales["Shadow Opacity"] = "陰影透明度"
    Locales["Show Party Loot"] = "顯示隊伍/團隊拾取"
    Locales["Show Player Name"] = "顯示玩家名字"
    Locales["Font Outline"] = "字體描邊"
    Locales["None"] = "無"
    Locales["OUTLINE"] = "細描邊"
    Locales["THICKOUTLINE"] = "粗描邊"
    Locales["MONOCHROME"] = "單色"
    Locales["Loot"] = "拾取"
    -- Subcategory names
    Locales["Loot Notification"] = "拾取通知"
    Locales["Combat State"] = "戰鬥狀態"
    -- Plugin intro
    Locales["LootG_Intro"] = "LootG 是一個輕量級的拾取通知和戰鬥狀態顯示插件。\n\n- 螢幕中央滾動顯示拾取物品\n- 進入/脫離戰鬥閃爍文字提示\n- 完全自定義字體、位置和動畫效果\n\n輸入 /lootg 打開設置，/lootg test 測試拾取顯示。"
    -- Combat State locales
    Locales["ENTER_COMBAT"] = "進入戰鬥"
    Locales["LEAVE_COMBAT"] = "脫離戰鬥"
    Locales["CS Display Mode"] = "顯示模式"
    Locales["Scroll"] = "滾動"
    Locales["Static"] = "靜態"
    Locales["CS Display Time"] = "閃爍時長 (秒)"
    Locales["CS Fade Time"] = "漸隱時間 (秒)"
    Locales["CS Scroll Speed"] = "滾動速度"
    Locales["CS Scroll Distance"] = "滾動距離"
    Locales["CS Font Size"] = "字號"
    Locales["CS Enter Text"] = "進入戰鬥文字"
    Locales["CS Leave Text"] = "脫離戰鬥文字"
    -- Slider labels
    Locales["displayTime"] = "顯示時間"
    Locales["scrollTime"] = "滾動時間"
    Locales["fadeSpeed"] = "漸隱速度"
    Locales["fontSize"] = "字號"
    Locales["fadeTime"] = "漸隱時間"
    Locales["scrollSpeed"] = "滾動速度"
end

for k, v in pairs(Locales) do
    L[k] = v
end
