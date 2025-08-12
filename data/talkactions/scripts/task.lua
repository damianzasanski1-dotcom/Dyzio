dofile('data/lib/tasks.lua')

function onSay(cid, words, param)
  local player = Player(cid)
  if not player then
    return false
  end

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