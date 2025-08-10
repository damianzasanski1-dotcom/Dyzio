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
    local resultId = db.storeQuery("SELECT name FROM player_spells WHERE player_id = " .. player:getGuid())
    if not resultId then
        player:sendTextMessage(MESSAGE_INFO_DESCR, "Nie masz żadnych nauczonych zaklęć.")
        return false
    end

    local spells = {}
    repeat
        local spellName = result.getString(resultId, "name")
        if spellName and spellName ~= "" then
            table.insert(spells, spellName)
        end
    until not result.next(resultId)
    result.free(resultId)

    table.sort(spells, function(a, b) return a:lower() < b:lower() end)
    sendChunkedList(player, string.format("Nauczone zaklęcia (%d):", #spells), spells)
    return false
end

talk:separator(" ")
talk:register()