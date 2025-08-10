function onSay(cid, words, param)
	local count = getPlayerInstantSpellCount(cid) or 0
	local text = ""
	local t = {}
	for i = 0, (count - 1) do
		local spell = getPlayerInstantSpellInfo(cid, i)
		if spell and type(spell) == "table" and spell.level and spell.level ~= 0 then
			if spell.manapercent and spell.manapercent > 0 then
				spell.mana = spell.manapercent .. "%"
			end
			t[#t+1] = spell
		end
	end
	
	table.sort(t, function(a, b) return (a.level or 0) < (b.level or 0) end)
	local prevLevel = -1
	for i, s in ipairs(t) do
		local line = ""
		local lvl = s.level or 0
		if prevLevel ~= lvl then
			if i ~= 1 then
				line = "\n"
			end
			line = line .. "Spells for Level " .. lvl .. "\n"
			prevLevel = lvl
		end
		local words = s.words or ""
		local name = s.name or ""
		local mana = s.mana or "?"
		text = text .. line .. "  " .. words .. " - " .. name .. " : " .. mana .. "\n"
	end
	
	if text == "" then
		text = "Brak dostępnych zaklęć."
	end
	
	Player(cid):showTextDialog(2175, text)
	return false
end