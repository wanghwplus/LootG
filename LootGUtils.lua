local addonName, L = ...
local LootG = L

LootG.Util = LootG.Util or {}
local Util = LootG.Util

function Util.GetIDFromLink(link)
    if not link then return nil end
    return link:match("item:(%d+)") or link:match("currency:(%d+)")
end

function Util.MarkRecentlyShown(recentlyShown, link, now)
    local dedupKey = Util.GetIDFromLink(link)
    if dedupKey then
        recentlyShown[dedupKey] = now
    end
    return dedupKey
end

function Util.WasRecentlyShown(recentlyShown, link, now, windowSeconds)
    local dedupKey = Util.GetIDFromLink(link)
    if not dedupKey then
        return false, nil
    end

    local shownAt = recentlyShown[dedupKey]
    if shownAt and (now - shownAt) < (windowSeconds or 5) then
        return true, dedupKey
    end

    return false, dedupKey
end

local function FindMessageLink(message, linkType)
    local colorizedPattern = "(|c%x+|H" .. linkType .. ":[^|]+|h.-|h|r)"
    local plainPattern = "(|H" .. linkType .. ":[^|]+|h.-|h)"
    local startPos, endPos, link = message:find(colorizedPattern)

    if not link then
        startPos, endPos, link = message:find(plainPattern)
    end

    return link, startPos, endPos
end

function Util.ParseCurrencyChatMessage(message, patterns)
    if patterns then
        for _, pattern in ipairs(patterns) do
            local link, quantity = message:match(pattern)
            if link then
                return link, tonumber(quantity) or 1
            end
        end
    end

    local link, _, endPos = FindMessageLink(message, "currency")
    if not link then
        return nil, nil
    end

    local quantity = message:match("x(%d+)", endPos and (endPos + 1) or 1)
    if not quantity then
        quantity = message:match("x(%d+)")
    end

    return link, tonumber(quantity) or 1
end
