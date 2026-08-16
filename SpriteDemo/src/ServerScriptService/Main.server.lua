-- Bootstraps the server-authoritative simulation: creates remotes, tracks
-- per-player state, steps player physics + enemy AI/combat every Heartbeat,
-- and broadcasts a throttled, per-player interest-filtered WorldSnapshot.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PhysicsStep = require(ReplicatedStorage.Shared.PhysicsStep)
local RemoteSetup = require(script.Parent.Net.RemoteSetup)
local InputHandler = require(script.Parent.Net.InputHandler)
local PlayerState = require(script.Parent.Simulation.PlayerState)
local EnemyState = require(script.Parent.Simulation.EnemyState)
local EnemyAI = require(script.Parent.Simulation.EnemyAI)
local CombatResolver = require(script.Parent.Simulation.CombatResolver)
local InterestManager = require(script.Parent.Interest.InterestManager)

local remotes = RemoteSetup.init()
InputHandler.init(remotes)
CombatResolver.init(remotes)

remotes.ClientReady.OnServerEvent:Connect(function(player)
	local state = PlayerState.get(player)
	if state then
		state.ready = true
	end
end)

Players.PlayerAdded:Connect(function(player)
	PlayerState.create(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerState.remove(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	PlayerState.create(player)
end

local broadcastInterval = 1 / GameConfig.Net.broadcastRate
local broadcastAccumulator = 0

RunService.Heartbeat:Connect(function(dt)
	for _, state in pairs(PlayerState.all()) do
		PhysicsStep.update(state, dt)
	end

	EnemyState.updateSpawning(dt)
	EnemyAI.update(dt)

	broadcastAccumulator += dt
	if broadcastAccumulator < broadcastInterval then
		return
	end
	broadcastAccumulator = 0

	InterestManager.broadcast(remotes)
end)
