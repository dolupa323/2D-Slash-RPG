-- Sends throttled PlayerInput/attack requests and receives WorldSnapshot.
--
-- The LOCAL player is never read from here for rendering — the client
-- predicts its own position locally (see HeroSpriteDemo.client.lua) and only
-- uses `getLocalState()` as the reconciliation reference (the server's most
-- recent opinion of where the local player actually is).
--
-- Every OTHER entity (remote players, enemies) has no local input to predict
-- from, so they're rendered via interpolation instead: we keep the previous
-- and current full snapshots with their receipt timestamps, and
-- getInterpolatedPlayers()/getInterpolatedEnemies() blend between them based
-- on how much time has passed since the current one arrived. This trades a
-- small fixed rendering delay (~one broadcast interval) for smooth motion
-- instead of visibly stepping between sparse updates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local NetworkClient = {}
NetworkClient.__index = NetworkClient

function NetworkClient.new(inputController)
	local self = setmetatable({}, NetworkClient)
	self.localPlayer = Players.LocalPlayer
	self.inputController = inputController
	self._sendAccumulator = 0
	self._sendInterval = 1 / GameConfig.Net.inputSendRate

	-- interpolation buffers
	self._prevPlayers, self._prevPlayersTime = {}, 0
	self._currPlayers, self._currPlayersTime = {}, 0
	self._prevEnemies, self._prevEnemiesTime = {}, 0
	self._currEnemies, self._currEnemiesTime = {}, 0

	local remotesFolder = ReplicatedStorage.Shared:WaitForChild("Remotes")
	self.remotes = {
		ClientReady = remotesFolder:WaitForChild("ClientReady"),
		PlayerInput = remotesFolder:WaitForChild("PlayerInput"),
		WorldSnapshot = remotesFolder:WaitForChild("WorldSnapshot"),
		RequestAttack = remotesFolder:WaitForChild("RequestAttack"),
		RequestWave = remotesFolder:WaitForChild("RequestWave"),
	}

	self.remotes.WorldSnapshot.OnClientEvent:Connect(function(snapshot)
		if type(snapshot) ~= "table" then
			return
		end
		local now = os.clock()

		if type(snapshot.players) == "table" then
			self._prevPlayers, self._prevPlayersTime = self._currPlayers, self._currPlayersTime
			self._currPlayers, self._currPlayersTime = snapshot.players, now
		end
		if type(snapshot.enemies) == "table" then
			self._prevEnemies, self._prevEnemiesTime = self._currEnemies, self._currEnemiesTime
			self._currEnemies, self._currEnemiesTime = snapshot.enemies, now
		end
	end)

	-- Only NOW is it safe for the server to start firing WorldSnapshot at us
	-- — OnClientEvent is connected above. Firing this earlier would just
	-- have the server sending into the void before we could ever listen.
	self.remotes.ClientReady:FireServer()

	return self
end

function NetworkClient:update(dt)
	self._sendAccumulator += dt
	if self._sendAccumulator < self._sendInterval then
		return
	end
	self._sendAccumulator = 0

	local moveX = self.inputController:GetMoveAxis()
	local jumpPressed = self.inputController:PollJumpForServer()
	self.remotes.PlayerInput:FireServer({ moveX = moveX, jumpPressed = jumpPressed })
end

function NetworkClient:requestAttack()
	self.remotes.RequestAttack:FireServer()
end

function NetworkClient:requestWave()
	self.remotes.RequestWave:FireServer()
end

-- Reconciliation reference only — NOT for rendering directly (that would
-- reintroduce the input-lag problem prediction exists to solve).
function NetworkClient:getLocalState()
	return self._currPlayers[tostring(self.localPlayer.UserId)]
end

local function interpolateMap(prevMap, prevTime, currMap, currTime, now)
	local span = currTime - prevTime
	local alpha = 1
	if span > 0 then
		alpha = math.clamp((now - currTime) / span, 0, 1)
	end

	local result = {}
	for id, curr in pairs(currMap) do
		local prev = prevMap[id]
		if prev then
			local blended = {}
			for key, value in pairs(curr) do
				if type(value) == "number" and (key == "x" or key == "y") and type(prev[key]) == "number" then
					blended[key] = prev[key] + (value - prev[key]) * alpha
				else
					blended[key] = value -- non-positional fields (hp, facingLeft, attackTick...) take the latest value as-is
				end
			end
			result[id] = blended
		else
			result[id] = curr -- just appeared; nothing to interpolate from yet
		end
	end
	return result
end

function NetworkClient:getInterpolatedPlayers(now)
	return interpolateMap(self._prevPlayers, self._prevPlayersTime, self._currPlayers, self._currPlayersTime, now)
end

function NetworkClient:getInterpolatedEnemies(now)
	return interpolateMap(self._prevEnemies, self._prevEnemiesTime, self._currEnemies, self._currEnemiesTime, now)
end

return NetworkClient
