local addonName, L = ...
local LootG = L

LootG.Util = LootG.Util or {}
local Util = LootG.Util

function Util.GetIDFromLink(link)
    if not link then return nil end
    return string.match(link, "item:(%d+)") or string.match(link, "currency:(%d+)")
end

-- 记录新条目时顺带惰性清理过期条目，避免无拾取窗口的场景
-- （任务推送、邮件开箱等）让记录表无限增长
function Util.MarkRecentlyShown(recentlyShown, link, now, source, windowSeconds)
    local window = windowSeconds or 5
    for key, entry in pairs(recentlyShown) do
        if (now - entry.time) >= window then
            recentlyShown[key] = nil
        end
    end

    local dedupKey = Util.GetIDFromLink(link)
    if dedupKey then
        recentlyShown[dedupKey] = { time = now, source = source }
    end
    return dedupKey
end

function Util.WasRecentlyShown(recentlyShown, link, now, windowSeconds, source)
    local dedupKey = Util.GetIDFromLink(link)
    if not dedupKey then
        return false, nil
    end

    local entry = recentlyShown[dedupKey]
    if entry and (now - entry.time) < (windowSeconds or 5) and entry.source ~= source then
        return true, dedupKey
    end

    return false, dedupKey
end

local function FindMessageLink(message, linkType)
    local colorizedPattern = "(|c%x+|H" .. linkType .. ":[^|]+|h.-|h|r)"
    local plainPattern = "(|H" .. linkType .. ":[^|]+|h.-|h)"
    local startPos, endPos, link = string.find(message, colorizedPattern)

    if not link then
        startPos, endPos, link = string.find(message, plainPattern)
    end

    return link, startPos, endPos
end

function Util.ParseCurrencyChatMessage(message, patterns)
    if type(message) ~= "string" then return nil, nil end

    if patterns then
        for _, pattern in ipairs(patterns) do
            local ok, link, quantity = pcall(string.match, message, pattern)
            if ok and link then
                return link, tonumber(quantity) or 1
            end
        end
    end

    local ok, link, _, endPos = pcall(FindMessageLink, message, "currency")
    if not ok or not link then
        return nil, nil
    end

    local ok2, quantity = pcall(string.match, message, "x(%d+)", endPos and (endPos + 1) or 1)
    if not ok2 or not quantity then
        local ok3, q = pcall(string.match, message, "x(%d+)")
        if ok3 then quantity = q end
    end

    return link, tonumber(quantity) or 1
end
