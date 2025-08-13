-- Upgrade Fire Swing: transforms weapon to upgraded id, adds fire damage, reverts after N hits
-- Configure per weapon id in weapons.xml by script="upgrade_fire_swing.lua"

-- CONFIG
local UPGRADED_WEAPON_ID = 0        -- if 0, will infer from Item attribute 'upgrade_to'
local HITS_LIMIT = 10
local EXTRA_DAMAGE_MIN = 0
local EXTRA_DAMAGE_MAX = 0
local EXTRA_PERCENT_OF_SKILL = 0.3  -- 30% of normal skill damage as fire

-- INTERNAL STATE: counts by player id
local hitCount = {}

local fireCombat = Combat()
fireCombat:setParameter(COMBAT_PARAM_TYPE, COMBAT_FIREDAMAGE)
fireCombat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_HITBYFIRE)

local function getAttackerAndTarget(var)
  local targetId = var:getNumber()
  return targetId ~= 0 and Creature(targetId) or nil
end

local function getHeldWeapon(player)
  local tool = player:getWeapon(true)
  return tool
end

local function ensureTransformed(player, tool)
  if not tool then return end
  local toId = UPGRADED_WEAPON_ID
  if toId == 0 then
    local attr = tool:getAttribute("description") -- use description to encode, or use charges as store
    local to = tool:getAttribute("upgrade_to")
    if type(to) == "number" and to > 0 then
      toId = to
    end
  end
  if toId and toId > 0 and tool:getID() ~= toId then
    tool:transform(toId)
  end
end

local function maybeRevert(player, tool, count, originalId)
  if count >= HITS_LIMIT and tool then
    if originalId and originalId > 0 and tool:getID() ~= originalId then
      tool:transform(originalId)
    end
    hitCount[player:getId()] = 0
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, "Upgrade wygasl - bron powrocila do poprzedniej postaci.")
    local pos = player:getPosition()
    pos:sendMagicEffect(CONST_ME_POFF)
  end
end

function onUseWeapon(cid, var)
  local player = Player(cid)
  if not player then
    return LUA_ERROR
  end

  local tool = getHeldWeapon(player)
  local originalId = tool and tool:getID() or 0

  -- 1) wykona standardowe obrazenia fizyczne zgodnie z XML (domyslne zachowanie)
  local ok = doCombat(cid, createCombatObject(), var) -- placeholder: engine normal melee is called by default before script; if needed, rely only on extra fire

  -- 2) dopal: transformacja i dodatkowe obrazenia ognia
  ensureTransformed(player, tool)

  -- extra fire damage based on skill percent: approximate by flat min/max if needed
  -- here just apply 0 damage to trigger effect if configured 0
  if EXTRA_DAMAGE_MIN ~= 0 or EXTRA_DAMAGE_MAX ~= 0 then
    fireCombat:setFormula(COMBAT_FORMULA_DAMAGE, 0, -EXTRA_DAMAGE_MIN, 0, -EXTRA_DAMAGE_MAX)
    fireCombat:execute(cid, var)
  else
    fireCombat:execute(cid, var)
  end

  -- 3) licznik trafien i ewentualny revert
  local pid = player:getId()
  hitCount[pid] = (hitCount[pid] or 0) + 1
  maybeRevert(player, tool, hitCount[pid], originalId)

  return ok
end