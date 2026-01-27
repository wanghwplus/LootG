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
    -- New settings
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
    -- New settings
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
    -- New settings
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
end

for k, v in pairs(Locales) do
    L[k] = v
end
