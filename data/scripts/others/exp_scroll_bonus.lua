-- Revscriptsys: Exp Scroll +20% na 1h (ASCII only)

-- KONFIG
local SCROLL_ITEMID = 12345         -- PODMIEN na id swojego scrolla
local BONUS_PERCENT = 20            -- +20%
local DURATION_SECONDS = 60 * 60    -- 1 godzina

-- STORAGE
local STG_EXP_BONUS_UNTIL = 53000   -- timestamp do kiedy aktywne (os.time)
local STG_EXP_BONUS_RATE  = 53001   -- przechowujemy procent (np. 120)

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

-- Scroll jako Action w revscriptsys
local expScroll = Action()
function expScroll.onUse(player, item, fromPos, target, toPos, isHotkey)
  if item:getId() ~= SCROLL_ITEMID then
    return false
  end
  local now = os.time()
  local untilTs = player:getStorageValue(STG_EXP_BONUS_UNTIL)
  if untilTs ~= -1 and untilTs > now then
    local left = untilTs - now
    player:sendCancelMessage(string.format("Bonus exp juz aktywny. Pozostalo ok. %d min.", math.floor(left/60)))
    return true
  end

  local rate = 100 + BONUS_PERCENT
  player:setStorageValue(STG_EXP_BONUS_RATE, rate)
  player:setStorageValue(STG_EXP_BONUS_UNTIL, now + DURATION_SECONDS)
  item:remove(1)

  player:sendTextMessage(MESSAGE_INFO_DESCR, string.format("Aktywowano +%d%% exp na 1h.", BONUS_PERCENT))
  local pos = player:getPosition()
  pos:sendMagicEffect(CONST_ME_MAGIC_BLUE)
  return true
end
expScroll:id(SCROLL_ITEMID)
expScroll:register()

-- Events: Player:onGainExperience modyfikuje exp
local events = Events()
function events.onGainExperience(player, source, exp, rawExp)
  local rate = getActiveRate(player)
  if rate <= 100 then
    return exp
  end
  return math.floor(exp * rate / 100)
end

function events.onLogin(player)
  local rate = getActiveRate(player)
  if rate > 100 then
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, string.format("Aktywny bonus exp: +%d%%.", rate - 100))
  end
  return true
end

events:register()