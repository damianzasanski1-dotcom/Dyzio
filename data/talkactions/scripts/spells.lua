function onSay(cid, words, param)
	local count = getPlayerInstantSpellCount(cid)
	local spellsText = ""
	local collected = {}

	for i = 0, count - 1 do
		local spell = getPlayerInstantSpellInfo(cid, i)
		if spell.level ~= 0 then
			if spell.manapercent and spell.manapercent > 0 then
				spell.mana = spell.manapercent .. "%"
			end
			collected[#collected + 1] = spell
		end
	end

	table.sort(collected, function(a, b)
		return a.level < b.level
	end)

	if #collected == 0 then
		Player(cid):sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Nie znasz żadnych czarów.")
		return false
	end

	local previousLevel = -1
	for i, spell in ipairs(collected) do
		local line = ""
		if previousLevel ~= spell.level then
			if i ~= 1 then
				line = "\n"
			end
			line = line .. "Spells for Level " .. spell.level .. "\n"
			previousLevel = spell.level
		end
		spellsText = spellsText .. line .. "  " .. spell.words .. " - " .. spell.name .. " : " .. spell.mana .. "\n"
	end

	-- 2175 is the classic spellbook item id; used only as a dialog skin here
	Player(cid):showTextDialog(2175, spellsText)
	return false
end