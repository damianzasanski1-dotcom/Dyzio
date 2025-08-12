-- Tasks configuration and shared helpers

-- Unique modal window ID for tasks (must not equal offline training window id)
TASK_MODAL_ID = 2000

-- Player storages used by tasks
STG_ACTIVE_TASK = 51000
STG_TASK_KILLS = 51001

-- Define available tasks
-- id: internal choice id used in modal
-- name: task display name
-- killsRequired: number of kills to finish
-- monsters: list of monster names that count for this task
TASKS = {
  { id = 1, name = "Rats",      killsRequired = 25, monsters = { "Rat" } },
  { id = 2, name = "Rotworms",  killsRequired = 50, monsters = { "Rotworm" } },
  { id = 3, name = "Cyclops",   killsRequired = 30, monsters = { "Cyclops" } }
}

function getTaskByChoiceId(choiceId)
  for _, task in ipairs(TASKS) do
    if task.id == choiceId then
      return task
    end
  end
  return nil
end

function isMonsterOfTask(monsterName, task)
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