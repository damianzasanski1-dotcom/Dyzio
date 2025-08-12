dofile('data/lib/tasks.lua')

function onModalWindow(player, modalWindowId, buttonId, choiceId)
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