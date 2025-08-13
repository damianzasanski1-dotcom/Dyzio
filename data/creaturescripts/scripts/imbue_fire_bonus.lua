local FIRE_BONUS_AID = 83001

function onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType)
	-- Only apply when attacker is a player with a marked weapon
	if attacker and attacker:isPlayer() then
		local weapon = attacker:getWeapon()
		if weapon and weapon:getActionId() == FIRE_BONUS_AID then
			-- Add 10% of final physical damage as extra fire secondary damage
			local base = 0
			if primaryDamage < 0 then
				base = -primaryDamage
			elseif secondaryDamage < 0 then
				base = -secondaryDamage
			end
			if base > 0 then
				local extra = math.floor(base * 0.10 + 0.5)
				secondaryDamage = secondaryDamage - extra -- damages are negative numbers
				secondaryType = COMBAT_FIREDAMAGE
			end
		end
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end