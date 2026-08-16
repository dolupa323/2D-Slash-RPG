-- Authoritative per-player state. The server is the only writer of
-- x/y/velocityY/grounded/facingLeft — client input only ever supplies
-- *intent* (moveX, jumpRequested), never position.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local PlayerState = {}
PlayerState._byPlayer = {} -- Player -> state table

function PlayerState.create(player)
	local cfg = GameConfig.Player
	local world = GameConfig.World
	local half = cfg.displaySize / 2
	local groundOffset = cfg.displaySize * cfg.visualBottomPad

	local state = {
		player = player,
		-- Flips true once the client's ClientReady fires (its NetworkClient
		-- has connected WorldSnapshot.OnClientEvent). InterestManager skips
		-- players who aren't ready yet, so the engine never has cause to log
		-- an UnreliableRemoteEvent "discarded event" warning for them — see
		-- RemoteSetup.lua's ClientReady comment.
		ready = false,
		x = world.width / 2,
		y = world.groundY - half + groundOffset,
		velocityY = 0,
		grounded = true,
		facingLeft = false,
		hp = cfg.maxHp,
		maxHp = cfg.maxHp,
		level = 1,
		xp = 0,
		xpToNext = cfg.xpToLevel(1),
		lastAttackTime = 0,
		-- latest input intent, written by InputHandler, consumed by PhysicsStep
		moveX = 0,
		jumpRequested = false,
	}

	PlayerState._byPlayer[player] = state
	return state
end

function PlayerState.remove(player)
	PlayerState._byPlayer[player] = nil
end

function PlayerState.get(player)
	return PlayerState._byPlayer[player]
end

function PlayerState.all()
	return PlayerState._byPlayer
end

return PlayerState
