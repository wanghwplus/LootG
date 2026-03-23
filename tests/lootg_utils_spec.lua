local addon = {}

assert(loadfile("LootGUtils.lua"))("LootG", addon)

local util = assert(addon.Util, "LootG.Util 未初始化")

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s\nexpected: %s\nactual: %s", message, tostring(expected), tostring(actual)))
    end
end

local function assert_truthy(value, message)
    if not value then
        error(message)
    end
end

do
    local standardMessage = "你获得了：|cff1eff00|Hcurrency:2815:0|h[共鸣水晶]|h|r x12。"
    local sourceMessage = "你获得了：|cff1eff00|Hcurrency:3008:0|h[鎏金宝匣硬币]|h|r x7。（宏伟宝库）"
    local patterns = {
        "^你获得了：(.+) x(%d+)。$",
        "^你获得了：(.+)。$",
    }

    local link, quantity = util.ParseCurrencyChatMessage(standardMessage, patterns)
    assert_equal(link, "|cff1eff00|Hcurrency:2815:0|h[共鸣水晶]|h|r", "标准通货消息应提取完整链接")
    assert_equal(quantity, 12, "标准通货消息应提取数量")

    link, quantity = util.ParseCurrencyChatMessage(sourceMessage, patterns)
    assert_equal(link, "|cff1eff00|Hcurrency:3008:0|h[鎏金宝匣硬币]|h|r", "带来源后缀的通货消息应回退到链接提取")
    assert_equal(quantity, 7, "带来源后缀的通货消息应从链接后提取数量")
end

do
    local shown = {}
    local now = 123.5

    util.MarkRecentlyShown(shown, "|cff0070dd|Hitem:235499::::::::80:::::|h[宝箱装备]|h|r", now)
    util.MarkRecentlyShown(shown, "|cff1eff00|Hcurrency:3008:0|h[鎏金宝匣硬币]|h|r", now)

    assert_equal(shown["235499"], now, "物品去重应记录稳定 itemID")
    assert_equal(shown["3008"], now, "通货去重应记录稳定 currencyID")

    local skipped, key = util.WasRecentlyShown(shown, "|cff0070dd|Hitem:235499::::::::80:::::|h[宝箱装备]|h|r", now + 1, 5)
    assert_truthy(skipped, "5 秒窗口内的同一物品应命中去重")
    assert_equal(key, "235499", "去重返回值应暴露稳定 key")

    skipped = util.WasRecentlyShown(shown, "|cff1eff00|Hcurrency:3008:0|h[鎏金宝匣硬币]|h|r", now + 6, 5)
    assert_equal(skipped, false, "超出去重窗口后不应继续拦截")
end

print("lootg_utils_spec: ok")
