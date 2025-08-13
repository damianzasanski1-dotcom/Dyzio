local FIRE_BONUS_AID = 83001

function onUse(player, item, fromPosition, target, toPosition, isHotkey)
	-- must use on a weapon in inventory
	if not target or target.uid == 0 then
		player:sendCancelMessage("Use this item on a weapon.")
		return true
	end

	local targetItem = Item(target.uid)
	if not targetItem then
		return true
	end

	local weaponType = targetItem:getType():getWeaponType()
	if weaponType ~= WEAPON_SWORD and weaponType ~= WEAPON_CLUB and weaponType ~= WEAPON_AXE and weaponType ~= WEAPON_DISTANCE then
		player:sendCancelMessage("You can only imbue weapons.")
		return true
	end

	-- prevent stacking or reapplying
	if targetItem:getActionId() == FIRE_BONUS_AID then
		player:sendCancelMessage("This weapon already has fire bonus.")
		return true
	end

	targetItem:setActionId(FIRE_BONUS_AID)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Your weapon has been imbued with +10% fire damage.")
	item:remove(1)
	return true
end