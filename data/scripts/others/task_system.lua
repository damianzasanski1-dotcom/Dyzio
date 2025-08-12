-- Revscriptsys: Task system (TalkAction + ModalWindow + Kill + Login)

-- Unique modal window ID for tasks
local TASK_MODAL_ID = 2000

-- Storages
local STG_ACTIVE_TASK = 51000
local STG_TASK_KILLS = 51001

-- Tasks definition
local TASKS = {
  { id = 1, name = "Rats",      killsRequired = 25, monsters = { "Rat" } },
  { id = 2, name = "Rotworms",  killsRequired = 50, monsters = { "Rotworm" } },
  { id = 3, name = "Cyclops",   killsRequired = 30, monsters = { "Cyclops" } },
}

local function getTaskByChoiceId(choiceId)
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
  for _, allowedName in ipairs(task.monsters) do
    if lower(allowedName) == nameLower then
      return true
    end
  end
  return false
end

-- TalkAction: !task
local taskTalk = TalkAction("!task")
function taskTalk.onSay(player, words, param)
  local window = ModalWindow(TASK_MODAL_ID, "Taski", "Wybierz task do rozpoczęcia:")
  for _, task in ipairs(TASKS) do
    local label = string.format("%s [%d]", task.name, task.killsRequired)
    window:addChoice(task.id, label)
  end
  window:addButton(1, "Wybierz")
  window:addButton(0, "Anuluj")
  window:setDefaultEnterButton(1)
  window:setDefaultEscapeButton(0)
  window:setPriority(true)
  window:sendToPlayer(player)
  return false
end

taskTalk:register()

-- CreatureEvent: ModalWindow handler
local taskModal = CreatureEvent("TaskModal")
function taskModal.onModalWindow(player, modalWindowId, buttonId, choiceId)
  if modalWindowId ~= TASK_MODAL_ID then
    return true
  end
  if buttonId ~= 1 then
    player:sendCancelMessage("Anulowano.")
    return true
  end
  local task = getTaskByChoiceId(choiceId)
  if not task then
    player:sendCancelMessage("Nieprawidłowy wybór tasku.")
    return true
  end
  player:setStorageValue(STG_ACTIVE_TASK, task.id)
  player:setStorageValue(STG_TASK_KILLS, 0)
  player:sendTextMessage(MESSAGE_INFO_DESCR, string.format("Wybrano task: %s (%d zabójstw).", task.name, task.killsRequired))
  return true
end

taskModal:register()

-- CreatureEvent: Kill handler
local taskKill = CreatureEvent("TaskKill")
function taskKill.onKill(creature, target)
  local player = Player(creature)
  if not player then
    return true
  end
  local monster = Monster(target)
  if not monster then
    return true
  end
  local activeId = player:getStorageValue(STG_ACTIVE_TASK)
  if activeId <= 0 then
    return true
  end
  local task = getTaskByChoiceId(activeId)
  if not task then
    return true
  end
  if not isMonsterOfTask(monster:getName(), task) then
    return true
  end
  local kills = player:getStorageValue(STG_TASK_KILLS)
  if kills < 0 then kills = 0 end
  kills = kills + 1
  player:setStorageValue(STG_TASK_KILLS, kills)
  player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, string.format("Task %s: %d/%d", task.name, kills, task.killsRequired))
  if kills >= task.killsRequired then
    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Ukończyłeś task: %s!", task.name))
    -- Add rewards here if needed, e.g.: player:addItem(2160, 1)
    player:setStorageValue(STG_ACTIVE_TASK, -1)
  end
  return true
end

taskKill:register()

-- CreatureEvent: Login to register handlers for player
local taskLogin = CreatureEvent("TaskLogin")
function taskLogin.onLogin(player)
  player:registerEvent("TaskModal")
  player:registerEvent("TaskKill")
  return true
end

taskLogin:register()