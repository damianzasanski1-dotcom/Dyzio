-- Training Dummy creaturescript
-- ASCII only messages

-- Konfiguracja
local DUMMY_NAMES = {
  ["Training Dummy"] = true,
  ["Target Dummy"] = true
}

-- Ile zredukowac obrazenia do malych (wizualny feedback)
local FEEDBACK_MIN = 0
local FEEDBACK_MAX = 0

-- Dodawanie prob skilla: ile prob na jedno trafienie
local SKILL_TRIES_PER_HIT = 1

local function isDummy(creature)
  if not creature then return false end
  local name = creature:getName()
  if not name then return false end
  return DUMMY_NAMES[name] == true
end

function onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
  if not attacker or not creature then
    return primaryDamage, primaryType, secondaryDamage, secondaryType
  end

  -- Tylko gdy bije gracz i celem jest dummy
  local player = Player(attacker)
  if not player or not isDummy(creature) then
    return primaryDamage, primaryType, secondaryDamage, secondaryType
  end

  -- Dodaj proby skilla zalezne od trzymanej broni
  local tool = player:getWeapon()
  if tool then
    local wtype = tool:getWeaponType()
    if wtype == WEAPON_SWORD then
      player:addSkillTries(SKILL_SWORD, SKILL_TRIES_PER_HIT)
    elseif wtype == WEAPON_AXE then
      player:addSkillTries(SKILL_AXE, SKILL_TRIES_PER_HIT)
    elseif wtype == WEAPON_CLUB then
      player:addSkillTries(SKILL_CLUB, SKILL_TRIES_PER_HIT)
    elseif wtype == WEAPON_DISTANCE then
      player:addSkillTries(SKILL_DISTANCE, SKILL_TRIES_PER_HIT)
    elseif wtype == WEAPON_SHIELD then
      player:addSkillTries(SKILL_SHIELD, SKILL_TRIES_PER_HIT)
    end
  end

  -- Zredukuj obrazenia (brak realnego DMG)
  local p = math.max(FEEDBACK_MIN, math.min(primaryDamage, FEEDBACK_MAX))
  local s = math.max(FEEDBACK_MIN, math.min(secondaryDamage, FEEDBACK_MAX))
  return p, primaryType, s, secondaryType
end