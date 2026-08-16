-- Authoritative enemy table (position/hp owned entirely by the server now —
-- Nature2D's old client-only role is gone; separation runs through
-- ReplicatedStorage.Shared.SpatialHash inside EnemyAI.lua instead).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local EnemyState = {}
EnemyState._enemies = {} -- id -> state
EnemyState._nextId = 1
EnemyState.spawnTimer = 0

function EnemyState.countAlive()
	local n = 0
	for _ in pairs(EnemyState._enemies) do
		n += 1
	end
	return n
end

function EnemyState.spawn()
	local cfg = GameConfig.Enemy
	local world = GameConfig.World
	local size = cfg.displaySize
	local groundOffset = size * cfg.visualBottomPad

	local id = EnemyState._nextId
	EnemyState._nextId += 1

	EnemyState._enemies[id] = {
		id = id,
		x = math.random(size, world.width - size),
		y = world.groundY - size / 2 + groundOffset,
		hp = cfg.maxHp,
		maxHp = cfg.maxHp,
		facingLeft = false,
		lastContactTime = 0,
		attackTick = 0, -- incremented on each contact hit; client edge-detects this to play the attack animation
	}
	return id
end

function EnemyState.remove(id)
	EnemyState._enemies[id] = nil
end

function EnemyState.get(id)
	return EnemyState._enemies[id]
end

function EnemyState.all()
	return EnemyState._enemies
end

-- Spawns up to GameConfig.Enemy.maxAlive at spawnIntervalSeconds; called once
-- per Heartbeat from Main.server.lua.
function EnemyState.updateSpawning(dt)
	local cfg = GameConfig.Enemy
	EnemyState.spawnTimer += dt
	if EnemyState.spawnTimer >= cfg.spawnIntervalSeconds and EnemyState.countAlive() < cfg.maxAlive then
		EnemyState.spawnTimer = 0
		EnemyState.spawn()
	end
end

return EnemyState
