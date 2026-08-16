-- Per-tick enemy chase + SpatialHash-based separation (the server-side twin
-- of the same algorithm the client used client-locally in Phase 1+2 — same
-- module, same math, now authoritative instead of cosmetic) + contact damage
-- against whichever player an enemy is currently touching.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local SpatialHash = require(ReplicatedStorage.Shared.SpatialHash)

local EnemyState = require(script.Parent.EnemyState)
local PlayerState = require(script.Parent.PlayerState)

local EnemyAI = {}

local cfg = GameConfig.Enemy
local SEPARATION_RADIUS = cfg.displaySize * 0.9
local SEPARATION_STRENGTH = 0.5
local separationHash = SpatialHash.new(SEPARATION_RADIUS)

-- Horizontal-only distance: player and enemy sprite boxes have very
-- different heights/paddings (hero's box is mostly transparent padding
-- above a small pixel-art figure — see visualTopPad in GameConfig), so their
-- box-center Y values differ by a lot even when both are standing on the
-- same ground line. A circular 2D distance check would make melee/aggro/
-- contact ranges effectively never trigger. Since every ground-walker shares
-- the same ground line anyway, X distance is the only one that means
-- anything here.
local function findNearestPlayer(enemyX)
	local nearestState, nearestDist = nil, math.huge
	for _, state in pairs(PlayerState.all()) do
		local dist = math.abs(state.x - enemyX)
		if dist < nearestDist then
			nearestDist = dist
			nearestState = state
		end
	end
	return nearestState, nearestDist
end

function EnemyAI.update(dt)
	local world = GameConfig.World
	local half = cfg.displaySize / 2
	local now = os.clock()

	-- chase + contact damage
	for id, enemy in pairs(EnemyState.all()) do
		local nearest, dist = findNearestPlayer(enemy.x)

		if nearest and dist <= cfg.aggroRange and math.abs(nearest.x - enemy.x) > 2 then
			local dirX = nearest.x > enemy.x and 1 or -1
			local step = math.min(cfg.moveSpeed * dt, math.abs(nearest.x - enemy.x))
			enemy.x = math.clamp(enemy.x + dirX * step, half, world.width - half)
			enemy.facingLeft = dirX < 0
		end

		if nearest and dist <= cfg.contactRange and (now - enemy.lastContactTime) >= cfg.contactCooldown then
			enemy.lastContactTime = now
			enemy.attackTick += 1
			nearest.hp = math.max(0, nearest.hp - cfg.contactDamage)
			if nearest.hp <= 0 then
				nearest.hp = nearest.maxHp -- simple respawn in place
			end
		end
	end

	-- SpatialHash separation (O(n) instead of all-pairs)
	for id, enemy in pairs(EnemyState.all()) do
		separationHash:update(id, Vector2.new(enemy.x, enemy.y))
	end
	for id, enemy in pairs(EnemyState.all()) do
		local pos = Vector2.new(enemy.x, enemy.y)
		local push = Vector2.new(0, 0)
		for _, otherId in ipairs(separationHash:queryRadius(pos, SEPARATION_RADIUS)) do
			if otherId ~= id then
				local otherPos = separationHash:getPosition(otherId)
				if otherPos then
					local delta = pos - otherPos
					local dist = delta.Magnitude
					if dist < SEPARATION_RADIUS and dist > 0.01 then
						push += delta.Unit * (SEPARATION_RADIUS - dist) * SEPARATION_STRENGTH
					end
				end
			end
		end
		if push.Magnitude > 0.01 then
			enemy.x = math.clamp(enemy.x + push.X, half, world.width - half)
			separationHash:update(id, Vector2.new(enemy.x, enemy.y))
		end
	end
end

-- Call when an enemy id is removed (death) so its stale cell entry doesn't
-- linger in the separation hash.
function EnemyAI.forget(id)
	separationHash:remove(id)
end

return EnemyAI
