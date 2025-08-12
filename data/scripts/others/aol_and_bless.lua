-- Revscriptsys: !AOL and !bless commands
-- ASCII-only messages

-- Coin item ids
local COIN_GOLD = 2148
local COIN_PLAT = 2152
local COIN_CRYS = 2160

-- AOL price: 5 crystal coins
local AOL_ITEM_ID = 2173 -- Amulet of Loss
local AOL_PRICE_GOLD = 5 * 10000 -- 5cc in gold units

local function getPlayerTotalGoldInGoldUnits(player)
  local gold = player:getItemCount(COIN_GOLD)
  local plat = player:getItemCount(COIN_PLAT)
  local crys = player:getItemCount(COIN_CRYS)
  return gold + plat * 100 + crys * 10000
end

local function removeGoldInGoldUnits(player, amount)
  if amount <= 0 then return true end
  local remaining = amount
  -- remove crystals first
  if remaining >= 10000 then
    local needC = math.floor(remaining / 10000)
    local haveC = player:getItemCount(COIN_CRYS)
    local takeC = math.min(needC, haveC)
    if takeC > 0 then
      player:removeItem(COIN_CRYS, takeC)
      remaining = remaining - takeC * 10000
    end
  end
  -- then platinum
  if remaining >= 100 then
    local needP = math.floor(remaining / 100)
    local haveP = player:getItemCount(COIN_PLAT)
    local takeP = math.min(needP, haveP)
    if takeP > 0 then
      player:removeItem(COIN_PLAT, takeP)
      remaining = remaining - takeP * 100
    end
  end
  -- then gold
  if remaining > 0 then
    local haveG = player:getItemCount(COIN_GOLD)
    local takeG = math.min(remaining, haveG)
    if takeG > 0 then
      player:removeItem(COIN_GOLD, takeG)
      remaining = remaining - takeG
    end
  end
  return remaining == 0
end

local function formatCoins(amount)
  local cc = math.floor(amount / 10000)
  local rest = amount % 10000
  local plat = math.floor(rest / 100)
  local gold = rest % 100
  local parts = {}
  if cc > 0 then table.insert(parts, cc .. " cc") end
  if plat > 0 then table.insert(parts, plat .. " plat") end
  if gold > 0 then table.insert(parts, gold .. " gold") end
  if #parts == 0 then return "0 gold" end
  return table.concat(parts, ", ")
end

-- Local bless cost (same as data/global.lua:getBlessingsCost)
local function blessCostForLevel(level)
  if level <= 30 then
    return 2000
  elseif level >= 120 then
    return 20000
  else
    return ((level - 20) * 200)
  end
end

-- !AOL: kupuje Amulet of Loss za 5cc
local aolTalk = TalkAction("!AOL")
function aolTalk.onSay(player, words, param)
  local totalGold = getPlayerTotalGoldInGoldUnits(player)
  if totalGold < AOL_PRICE_GOLD then
    player:sendCancelMessage("Potrzebujesz " .. formatCoins(AOL_PRICE_GOLD) .. ", a masz tylko " .. formatCoins(totalGold) .. ".")
    return false
  end
  if not removeGoldInGoldUnits(player, AOL_PRICE_GOLD) then
    player:sendCancelMessage("Nie udalo sie pobrac monet.")
    return false
  end
  player:addItem(AOL_ITEM_ID, 1)
  player:sendTextMessage(MESSAGE_INFO_DESCR, "Zakupiono Amulet of Loss za " .. formatCoins(AOL_PRICE_GOLD) .. ".")
  return false
end
aolTalk:register()

-- !bless: kupuje wszystkie blessy, cena zalezy od poziomu
local blessTalk = TalkAction("!bless")
function blessTalk.onSay(player, words, param)
  local level = player:getLevel()
  local perBless = blessCostForLevel(level)
  local numBless = 5 -- standardowe 5 blogoslawienstw
  local totalGold = perBless * numBless

  -- sprawdz, czy juz ma wszystkie
  local allHave = true
  for i = 1, numBless do
    if not player:hasBlessing(i) then
      allHave = false
      break
    end
  end
  if allHave then
    player:sendCancelMessage("Masz juz wszystkie blessy.")
    return false
  end

  local wallet = getPlayerTotalGoldInGoldUnits(player)
  if wallet < totalGold then
    player:sendCancelMessage("Potrzebujesz " .. formatCoins(totalGold) .. ", a masz tylko " .. formatCoins(wallet) .. ".")
    return false
  end

  if not removeGoldInGoldUnits(player, totalGold) then
    player:sendCancelMessage("Nie udalo sie pobrac monet.")
    return false
  end

  for i = 1, numBless do
    if not player:hasBlessing(i) then
      player:addBlessing(i)
    end
  end

  player:sendTextMessage(MESSAGE_INFO_DESCR, "Kupiono wszystkie blessy za " .. formatCoins(totalGold) .. ".")
  return false
end
blessTalk:register()