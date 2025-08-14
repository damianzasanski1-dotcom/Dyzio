function Player:onBrowseField(position)
	return true
end

function Player:onLook(thing, position, distance)
	local description = "You see " .. thing:getDescription(distance)
	if self:getGroup():getAccess() then
		if thing:isItem() then
			description = string.format("%s\nItemID: [%d]", description, thing:getId())

			local actionId = thing:getActionId()
			if actionId ~= 0 then
				description = string.format("%s, ActionID: [%d]", description, actionId)
			end
			
			local uniqueId = thing:getAttribute(ITEM_ATTRIBUTE_UNIQUEID)
			if uniqueId > 0 and uniqueId < 65536 then
				description = string.format("%s, UniqueId: [%d]", description, uniqueId)
			end
			
			description = description .. "."
			local itemType = thing:getType()
			
			local transformEquipId = itemType:getTransformEquipId()
			local transformDeEquipId = itemType:getTransformDeEquipId()
			if transformEquipId ~= 0 then
				description = string.format("%s\nTransformTo: [%d] (onEquip).", description, transformEquipId)
			elseif transformDeEquipId ~= 0 then
				description = string.format("%s\nTransformTo: [%d] (onDeEquip).", description, transformDeEquipId)
			end

			local decayId = itemType:getDecayId()
			if decayId ~= -1 then
				description = string.format("%s\nDecayTo: [%d]", description, decayId)
			end
		elseif thing:isCreature() then
			local str = "%s\nHealth: [%d / %d]"
			if thing:getMaxMana() > 0 then
				str = string.format("%s, Mana: [%d / %d]", str, thing:getMana(), thing:getMaxMana())
			end
			description = string.format(str, description, thing:getHealth(), thing:getMaxHealth()) .. "."
		end
		
		local position = thing:getPosition()
		description = string.format(
			"%s\nPosition: [X: %d] [Y: %d] [Z: %d].",
			description, position.x, position.y, position.z
		)
		
		if thing:isCreature() then
			if thing:isPlayer() then
				description = string.format("%s\nIP: [%s].", description, Game.convertIpToString(thing:getIp()))
			end
		end
	end
	self:sendTextMessage(MESSAGE_INFO_DESCR, description)
end

function Player:onLookInBattleList(creature, distance)
	local description = "You see " .. creature:getDescription(distance)
	if self:getGroup():getAccess() then
		local str = "%s\nHealth: [%d / %d]"
		if creature:getMaxMana() > 0 then
			str = string.format("%s, Mana: [%d / %d]", str, creature:getMana(), creature:getMaxMana())
		end
		description = string.format(str, description, creature:getHealth(), creature:getMaxHealth()) .. "."

		local position = creature:getPosition()
		description = string.format(
			"%s\nPosition: [X: %d] [Y: %d] [Z: %d].",
			description, position.x, position.y, position.z
		)
		
		if creature:isPlayer() then
			description = string.format("%s\nIP: [%s].", description, Game.convertIpToString(creature:getIp()))
		end
	end
	self:sendTextMessage(MESSAGE_INFO_DESCR, description)
end

function Player:onLookInTrade(partner, item, distance)
	self:sendTextMessage(MESSAGE_INFO_DESCR, "You see " .. item:getDescription(distance))
end

function Player:onLookInShop(itemType, count)
	return true
end

function Player:onMoveItem(item, count, fromPosition, toPosition)
	return true
end

function Player:onMoveCreature(creature, fromPosition, toPosition)
	return true
end

function Player:onTurn(direction)
	return true
end

function Player:onTradeRequest(target, item)
	return true
end

function Player:onTradeAccept(target, item, targetItem)
	return true
end

-- BONUS EXP: integrowane tutaj, aby na pewno zadzialalo
local STG_EXP_BONUS_UNTIL = 53000
local STG_EXP_BONUS_RATE  = 53001

local function getActiveRate(player)
	local now = os.time()
	local untilTs = player:getStorageValue(STG_EXP_BONUS_UNTIL)
	local rate = player:getStorageValue(STG_EXP_BONUS_RATE)
	if untilTs ~= -1 and untilTs > now and rate and rate > 100 then
		return rate
	end
	player:setStorageValue(STG_EXP_BONUS_UNTIL, -1)
	player:setStorageValue(STG_EXP_BONUS_RATE, -1)
	return 100
end

function Player:onGainExperience(source, exp, rawExp)
	-- exp scroll bonus
	local rate = getActiveRate(self)
	if rate > 100 then
		exp = math.floor(exp * rate / 100)
	end
	-- weapon XP fallback: award XP per monster kill exp gain
	if source and source:isMonster() then
		local tool = self:getSlotItem(CONST_SLOT_LEFT) or self:getSlotItem(CONST_SLOT_RIGHT)
		if tool then
			local it = tool:getType()
			if it and it.getWeaponType and (it:getWeaponType()==WEAPON_SWORD or it:getWeaponType()==WEAPON_AXE or it:getWeaponType()==WEAPON_CLUB) then
				-- read state
				local function decode(s)
					if not s or s=="" or not s:find("^WXP;") then return nil end
					local w={level=0,xp=0,cap=100,elem="",baseAtk=0,baseDef=0,l10=""}
					w.level=tonumber(s:match("l=(%d+)")or"0")or 0
					w.xp   =tonumber(s:match("x=(%d+)")or"0")or 0
					w.cap  =tonumber(s:match("c=(%d+)")or"0")or 100
					w.elem =s:match("e=([%a]+)") or ""
					w.baseAtk=tonumber(s:match("a=(%d+)")or"0")or 0
					w.baseDef=tonumber(s:match("d=(%d+)")or"0")or 0
					w.l10  =s:match("t=([%w_,%-]+)") or ""
					return w
				end
				local t = tool:getAttribute("text")
				local w = decode(t)
				if not w then
					local it2=ItemType(tool:getId())
					w={level=0,xp=0,cap=100,elem="",baseAtk=it2:getAttack(),baseDef=it2:getDefense(),l10=""}
				end
				if (w.level or 0) < 10 then
					w.xp = (w.xp or 0) + 1
					local function defaultCapForLevel(lvl)
						local cap=100; for i=2,lvl do cap=math.floor(cap*1.25+0.5) end; return cap
					end
					if (w.xp or 0) >= (w.cap or 100) then
						w.level = math.min(10,(w.level or 0)+1)
						w.xp = 0
						w.cap = defaultCapForLevel((w.level or 0)+1)
						tool:setAttribute("text", string.format("WXP;l=%d;x=%d;c=%d;e=%s;a=%d;d=%d;t=%s", w.level,w.xp,w.cap,w.elem or "",w.baseAtk or 0,w.baseDef or 0,w.l10 or ""))
						tool:setAttribute("description", (ItemType(tool:getId()):getName() or "Weapon").."\nUpgrade: +"..(w.level or 0).."\n"..(((w.level or 0) < 10) and ("Exp "..(w.xp or 0).."/"..(w.cap or 100)) or "Max level"))
						-- try apply real atk/def
						if tool.setAttribute then
							tool:setAttribute("attack", (w.baseAtk or 0)+(w.level or 0))
							tool:setAttribute("defense",(w.baseDef or 0)+(w.level or 0))
							tool:transform(tool:getId()); tool:transform(tool:getId())
						end
					else
						tool:setAttribute("text", string.format("WXP;l=%d;x=%d;c=%d;e=%s;a=%d;d=%d;t=%s", w.level,w.xp,w.cap,w.elem or "",w.baseAtk or 0,w.baseDef or 0,w.l10 or ""))
						local itn=ItemType(tool:getId()):getName(); if itn=="" then itn="Weapon" end
						tool:setAttribute("description", itn.."\nUpgrade: +"..(w.level or 0).."\nExp "..(w.xp or 0).."/"..(w.cap or 100))
					end
				end
			end
		end
	end
	return exp
end

function Player:onLoseExperience(exp)
	return exp
end
