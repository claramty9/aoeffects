-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or nil
Game = Game or nil
InAction = InAction or false

Logs = Logs or {}

colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m",
  gray = "\27[90m"
}

function addLog(msg, text) -- Function definition commented for performance, can be used for debugging
  Logs[msg] = Logs[msg] or {}
  table.insert(Logs[msg], text)
end

-- Checks if two points are within a given range.
-- @param x1, y1: Coordinates of the first point.
-- @param x2, y2: Coordinates of the second point.
-- @param range: The maximum allowed distance between the points.
-- @return: Boolean indicating if the points are within the specified range.
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end
-- Determines whether to return attack based on player's health and damage taken
function shouldReturnAttack(playerHealth, damageTaken)
  -- A simple heuristic could be to return attack if health is above a certain threshold
  local healthThreshold = 50
  return playerHealth > healthThreshold
end

-- Calculates the amount of energy to use for retaliation based on damage taken and current energy
function calculateRetaliationEnergy(playerEnergy, damageTaken)
  -- Use a higher proportion of energy if the damage taken is significant
  local retaliationFactor = damageTaken / playerEnergy
  local retaliationEnergy = math.floor(playerEnergy * retaliationFactor)
  -- Ensure the retaliation energy is within the player's current energy limits
  return math.min(retaliationEnergy, playerEnergy)
end

-- Finds the direction that maximizes distance from the nearest player
function findSafestDirection(playerState)
  local maxDistance = 0
  local safestDirection = nil
  local directionMap = {
    Up = {x = 0, y = -1}, Down = {x = 0, y = 1},
    Left = {x = -1, y = 0}, Right = {x = 1, y = 0},
    UpRight = {x = 1, y = -1}, UpLeft = {x = -1, y = -1},
    DownRight = {x = 1, y = 1}, DownLeft = {x = -1, y = 1}
  }

  -- Check each direction to find the safest one
  for direction, vector in pairs(directionMap) do
    local newX = (playerState.x + vector.x - 1) % Width + 1
    local newY = (playerState.y + vector.y - 1) % Height + 1
    local nearestOpponentDistance = findNearestOpponentDistance(newX, newY)

    if nearestOpponentDistance > maxDistance then
      maxDistance = nearestOpponentDistance
      safestDirection = direction
    end
  end

  return safestDirection
end

-- Finds the distance to the nearest opponent from a given position
function findNearestOpponentDistance(x, y)
  local minDistance = math.huge
  for _, opponentState in pairs(LatestGameState.Players) do
    local distance = calculateDistance(x, y, opponentState.x, opponentState.y)
    if distance < minDistance then
      minDistance = distance
    end
  end
  return minDistance
end

-- Calculates the distance between two points
function calculateDistance(x1, y1, x2, y2)
  return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- Determines proximity between two points.
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

-- Evaluates the best move based on the current game state.
function decideNextAction()
  local player = LatestGameState.Players[ao.id]
  local targetInRange, closestTarget = findClosestTarget(player)

  if player.energy > 5 and targetInRange then
    print("Target in range. Preparing to attack.")
    ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = calculateAttackEnergy(player, closestTarget)})
  else
    print("No target in range or insufficient energy. Considering strategic move.")
    ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = determineBestMove(player)})
  end
end

-- Finds the closest target within a specified range.
function findClosestTarget(player)
  local minDistance = math.huge
  local closestTarget = nil
  for target, state in pairs(LatestGameState.Players) do
      if target ~= ao.id then
          local distance = calculateDistance(player.x, player.y, state.x, state.y)
          if distance < minDistance then
              minDistance = distance
              closestTarget = target
          end
      end
  end
  return inRange(player.x, player.y, LatestGameState.Players[closestTarget].x, LatestGameState.Players[closestTarget].y, 1), closestTarget
end

-- Calculates the optimal attack energy based on the player's and target's state.
function calculateAttackEnergy(player, target)
  -- Implement logic to determine the optimal amount of energy to use for an attack
end

-- Determines the best move based on the player's position and the positions of others.
function determineBestMove(player)
  -- Implement logic to choose the best direction to move based on strategic considerations
end

-- Calculates the distance between two points.
function calculateDistance(x1, y1, x2, y2)
  return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end
-- Handler to print game announcements and trigger game state updates.
Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    if msg.Event == "Started-Waiting-Period" then
      ao.send({Target = ao.id, Action = "AutoPay"})
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
      InAction = true
      -- print("Getting game state...")
      ao.send({Target = Game, Action = "GetGameState"})
    elseif InAction then
      print("Previous action still in progress. Skipping.")
    end
    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
  end
)

-- Handler to trigger game state updates.
Handlers.add(
  "GetGameStateOnTick",
  Handlers.utils.hasMatchingTag("Action", "Tick"),
  function ()
    if not InAction then
      InAction = true
      print(colors.gray .. "Getting game state..." .. colors.reset)
      ao.send({Target = Game, Action = "GetGameState"})
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)

-- Handler to automate payment confirmation when waiting period starts.
Handlers.add(
  "AutoPay",
  Handlers.utils.hasMatchingTag("Action", "AutoPay"),
  function (msg)
    print("Auto-paying confirmation fees.")
    ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1"})
  end
)

-- Handler to update the game state upon receiving game state information.
Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function (msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({Target = ao.id, Action = "UpdatedGameState"})
    print("Game state updated. Print \'LatestGameState\' for detailed view.")
  end
)

-- Handler to decide the next best action.
Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function ()
    if LatestGameState.GameMode ~= "Playing" then 
      InAction = false
      return 
    end
    print("Deciding next action.")
    decideNextAction()
    ao.send({Target = ao.id, Action = "Tick"})
  end
)
-- Handler to automatically attack when hit by another player.
Handlers.add(
  "ReturnAttack",
  Handlers.utils.hasMatchingTag("Action", "Hit"),
  function (msg)
    if not InAction then
      InAction = true
      local playerState = LatestGameState.Players[ao.id]
      local playerEnergy = playerState.energy
      local playerHealth = playerState.health
      local attackerId = msg.From
      local damageTaken = tonumber(msg.Tags.Damage)

      -- Check if the player's energy is undefined or zero
      if playerEnergy == undefined then
        print("Unable to read energy.")
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy."})
      elseif playerEnergy == 0 then
        print("Player has insufficient energy.")
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Player has no energy."})
      else
        -- Decide whether to return attack or take a defensive action
        if shouldReturnAttack(playerHealth, damageTaken) then
          local attackEnergy = calculateRetaliationEnergy(playerEnergy, damageTaken)
          print("Returning attack with energy: " .. attackEnergy)
          ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(attackEnergy)})
        else
          print("Taking defensive action.")
          local safestDirection = findSafestDirection(playerState)
          ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = safestDirection})
        end
      end
      InAction = false
      ao.send({Target = ao.id, Action = "Tick"})
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)
