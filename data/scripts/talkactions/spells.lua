local talk = TalkAction("!spells")

local function sendChunkedList(player, header, items, maxLen)
    maxLen = maxLen or 220
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, header)
    if #items == 0 then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "- brak")
        return
    end
    local line = ""
    for _, name in ipairs(items) do
        local part = (line == "" and name or ", " .. name)
        if (#line + #part) > maxLen then
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, line)
            line = name
        else
            line = line .. part
        end
    end
    if line ~= "" then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, line)
    end
end

function talk.onSay(player, words, param)
    -- Enumerate all instant spells available to this player (by vocation or learned)
    local count = getPlayerInstantSpellCount(player:getId())

    local collected = {}
    for i = 0, count - 1 do
        local spell = getPlayerInstantSpellInfo(player:getId(), i)
        if spell and spell.level ~= 0 then
            local manaStr = tostring(spell.mana)
            if spell.manapercent and spell.manapercent > 0 then
                manaStr = tostring(spell.manapercent) .. "%"
            end
            table.insert(collected, {
                level = spell.level or 0,
                name = spell.name or "",
                words = spell.words or "",
                mlevel = spell.mlevel or 0,
                manaStr = manaStr,
            })
        end
    end

    table.sort(collected, function(a, b)
        if a.level ~= b.level then
            return a.level < b.level
        end
        if a.name ~= b.name then
            return a.name:lower() < b.name:lower()
        end
        return a.words:lower() < b.words:lower()
    end)

    local items = {}
    for _, s in ipairs(collected) do
        table.insert(items, string.format("%s - %s (lvl %d, ml %d, mana %s)", s.words, s.name, s.level, s.mlevel, s.manaStr))
    end

    if #items == 0 then
        player:sendTextMessage(MESSAGE_INFO_DESCR, "Brak dostępnych zaklęć.")
        return false
    end

    sendChunkedList(player, string.format("Dostępne zaklęcia (%d):", #items), items)
    return false
end

talk:separator(" ")
talk:register()