-- Revscriptsys: Task system (lista -> szczegoly + nagrody -> accept) + kill + login
-- ASCII only messages

-- Modal IDs
local TASK_LIST_MODAL_ID = 2000
local TASK_DETAILS_MODAL_ID = 2001

-- Storages
local STG_ACTIVE_TASK = 51000
local STG_TASK_KILLS = 51001
local STG_TASK_DONE_BASE = 52000 -- per-task completion flag: STG_TASK_DONE_BASE + task.id

-- Konfiguracja taskow i nagrod
-- rewards.experience: liczba exp
-- rewards.money: liczba gold (zlota) do przeliczenia na monety (gold/platinum/crystal)
-- rewards.items: lista przedmiotow { id = (number|string), count = number }
local TASKS = {
  { id = 1, name = "Rats",      killsRequired = 25, monsters = { "Rat" }, rewards = {
      experience = 5000, money = 1000, items = { { id = 2160, count = 1 } } -- 1x crystal coin
  }},
  { id = 2, name = "Rotworms",  killsRequired = 50, monsters = { "Rotworm" }, rewards = {
      experience = 20000, money = 5000, items = { { id = "plate armor", count = 1 } }
  }},
  { id = 3, name = "Cyclops",   killsRequired = 30, monsters = { "Cyclops" }, rewards = {
      experience = 30000, money = 108765, items = { { id = 2152, count = 50 } } -- 50x platinum coin
  }},
}

local function getTaskById(choiceId)
  for _, task in ipairs(TASKS) do
    if task.id == choiceId then
      return task
    end
  end
  return nil
end

local function isMonsterOfTask(monsterName, task)
  if not monsterName or not task or not task.monsters then
    return false
  end
  local lower = string.lower
  local nameLower = lower(monsterName)
  for _, allowed in ipairs(task.monsters) do
    if lower(allowed) == nameLower then
      return true
    end
  end
  return false
end

local function formatNumber(n)
  local s = tostring(math.floor(n))
  local left, num, right = string.match(s, "^([^%d]*%d)(%d*)(.-)$")
  return left .. (num:reverse():gsub("(%d%d%d)", "%1 "):reverse()) .. right
end

local function itemEntryToLabel(entry)
  if type(entry.id) == "string" then
    return string.format("%s x%d", entry.id, entry.count or 1)
  else
    return string.format("itemId %d x%d", entry.id, entry.count or 1)
  end
end

local function rewardsToMessage(rew)
  if not rew then return "Brak nagrod." end
  local parts = {}
  if rew.experience and rew.experience > 0 then
    parts[#parts+1] = "- Experience: " .. formatNumber(rew.experience)
  end
  if rew.money and rew.money > 0 then
    parts[#parts+1] = "- Gold razem: " .. formatNumber(rew.money) .. " (zostanie wydane w monetach)"
  end
  if rew.items and #rew.items > 0 then
    parts[#parts+1] = "- Przedmioty:"
    for _, it in ipairs(rew.items) do
      parts[#parts+1] = "  * " .. itemEntryToLabel(it)
    end
  end
  if #parts == 0 then
    return "Brak nagrod."
  end
  return table.concat(parts, "\n")
end

-- Konwersja zlota na monety: 100 gold = 1 platinum (2152), 100 platinum = 1 crystal (2160)
local function giveMoneyAsCoins(player, goldAmount)
  if not goldAmount or goldAmount <= 0 then return end
  local cc = math.floor(goldAmount / 10000)
  local rest = goldAmount % 10000
  local plat = math.floor(rest / 100)
  local gold = rest % 100
  if cc > 0 then player:addItem(2160, cc) end -- crystal coin
  if plat > 0 then player:addItem(2152, plat) end -- platinum coin
  if gold > 0 then player:addItem(2148, gold) end -- gold coin
end

local function giveRewards(player, rew)
  if not rew then return end
  if rew.experience and rew.experience > 0 then
    player:addExperience(rew.experience)
  end
  if rew.money and rew.money > 0 then
    giveMoneyAsCoins(player, rew.money)
  end
  if rew.items then
    for _, it in ipairs(rew.items) do
      local id = it.id
      local count = it.count or 1
      player:addItem(id, count)
    end
  end
end

-- TalkAction: !task -> okno listy taskow
local taskTalk = TalkAction("!task")
function taskTalk.onSay(player, words, param)
  local window = ModalWindow(TASK_LIST_MODAL_ID, "Taski", "Wybierz task z listy, potem zobacz nagrody i zaakceptuj.")
  for _, task in ipairs(TASKS) do
    -- jesli task juz ukonczony, pokaz status
    local done = player:getStorageValue(STG_TASK_DONE_BASE + task.id) > 0
    local status = done and "(UKONCZONY)" or ""
    local label = string.format("%s [%d zabojstw] %s", task.name, task.killsRequired, status)
    window:addChoice(task.id, label)
  end
  window:addButton(1, "Szczegoly")
  window:addButton(0, "Zamknij")
  window:setDefaultEnterButton(1)
  window:setDefaultEscapeButton(0)
  window:setPriority(true)
  window:sendToPlayer(player)
  return false
end

taskTalk:register()

-- CreatureEvent: obsluga dwoch okien (lista i szczegoly)
local taskModal = CreatureEvent("TaskModal")
function taskModal.onModalWindow(player, modalWindowId, buttonId, choiceId)
  -- Okno listy -> pokaz okno szczegolow
  if modalWindowId == TASK_LIST_MODAL_ID then
    if buttonId ~= 1 or not choiceId or choiceId == 0 then
      return true
    end
    local task = getTaskById(choiceId)
    if not task then
      player:sendCancelMessage("Nieprawidlowy wybor tasku.")
      return true
    end
    local done = player:getStorageValue(STG_TASK_DONE_BASE + task.id) > 0
    local activeId = player:getStorageValue(STG_ACTIVE_TASK)
    local alreadyActive = activeId > 0 and activeId == task.id

    local header = string.format("Task: %s\nWymagane zabojstwa: %d", task.name, task.killsRequired)
    local progress = ""
    if alreadyActive then
      local kills = player:getStorageValue(STG_TASK_KILLS)
      if kills < 0 then kills = 0 end
      progress = string.format("\nPostep: %d/%d", kills, task.killsRequired)
    end

    local status = done and "\nStatus: UKONCZONY" or (alreadyActive and "\nStatus: AKTYWNY" or "")
    local msg = string.format(
      "%s%s\n\nNagrody:\n%s",
      header, progress .. status, rewardsToMessage(task.rewards)
    )

    local win = ModalWindow(TASK_DETAILS_MODAL_ID, "Task - Szczegoly", msg)
    win:addChoice(task.id, task.name) -- trzymamy id w choice
    if done then
      win:addButton(0, "Wstecz")
      win:setDefaultEnterButton(0)
      win:setDefaultEscapeButton(0)
    elseif activeId > 0 and not alreadyActive then
      win:addButton(0, "Wstecz")
      win:setDefaultEnterButton(0)
      win:setDefaultEscapeButton(0)
    else
      win:addButton(1, "Accept")
      win:addButton(0, "Wstecz")
      win:setDefaultEnterButton(1)
      win:setDefaultEscapeButton(0)
    end
    win:setPriority(true)
    win:sendToPlayer(player)
    return true
  end

  -- Okno szczegolow -> Accept lub Wstecz
  if modalWindowId == TASK_DETAILS_MODAL_ID then
    if buttonId ~= 1 or not choiceId or choiceId == 0 then
      return true
    end
    local task = getTaskById(choiceId)
    if not task then
      player:sendCancelMessage("Nieprawidlowy wybor tasku.")
      return true
    end
    -- blokada: task tylko raz
    if player:getStorageValue(STG_TASK_DONE_BASE + task.id) > 0 then
      player:sendCancelMessage("Ten task zostal juz ukonczony.")
      return true
    end
    -- blokada: tylko jeden aktywny naraz
    if player:getStorageValue(STG_ACTIVE_TASK) > 0 then
      player:sendCancelMessage("Masz juz aktywny task.")
      return true
    end
    player:setStorageValue(STG_ACTIVE_TASK, task.id)
    player:setStorageValue(STG_TASK_KILLS, 0)
    player:sendTextMessage(MESSAGE_INFO_DESCR, string.format("Aktywowano task: %s (%d zabojstw).", task.name, task.killsRequired))
    return true
  end

  return true
end

taskModal:register()

-- CreatureEvent: zliczanie zabojstw i wyplata nagrod
local taskKill = CreatureEvent("TaskKill")
function taskKill.onKill(creature, target)
  local player = Player(creature)
  if not player then return true end
  local monster = Monster(target)
  if not monster then return true end

  local activeId = player:getStorageValue(STG_ACTIVE_TASK)
  if activeId <= 0 then return true end

  local task = getTaskById(activeId)
  if not task then return true end
  if not isMonsterOfTask(monster:getName(), task) then return true end

  local kills = player:getStorageValue(STG_TASK_KILLS)
  if kills < 0 then kills = 0 end
  kills = kills + 1
  player:setStorageValue(STG_TASK_KILLS, kills)
  player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, string.format("Task %s: %d/%d", task.name, kills, task.killsRequired))

  if kills >= task.killsRequired then
    -- wyplata nagrod (monety w przelicznikach)
    giveRewards(player, task.rewards)
    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Ukonczyles task: %s! Nagrody zostaly przyznane.", task.name))
    -- oznacz task jako ukonczony i wyczysc aktywny
    player:setStorageValue(STG_TASK_DONE_BASE + task.id, 1)
    player:setStorageValue(STG_ACTIVE_TASK, -1)
  end
  return true
end

taskKill:register()

-- CreatureEvent: login -> rejestracja eventow
local taskLogin = CreatureEvent("TaskLogin")
function taskLogin.onLogin(player)
  player:registerEvent("TaskModal")
  player:registerEvent("TaskKill")
  return true
end

taskLogin:register()