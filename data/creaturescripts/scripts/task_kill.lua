dofile('data/lib/tasks.lua')

function onKill(cid, target)
  local player = Player(cid)
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
    -- Clear active task; you can trigger rewards here if desired
    player:setStorageValue(STG_ACTIVE_TASK, -1)
  end
  return true
end