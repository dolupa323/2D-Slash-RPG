-- Per-player interest filtering: builds one combined SpatialHash of every
-- player + enemy each broadcast tick, then sends each player only the
-- entities within INTEREST_RADIUS of them (via FireClient, not
-- FireAllClients — everyone gets a different payload). This is what keeps
-- WorldSnapshot bandwidth bounded by local entity density instead of total
-- world population as the player/enemy count grows.
--
-- Horizontal-only distance (Y collapsed to 0), matching the same reasoning
-- as EnemyAI/CombatResolver: player and enemy sprite boxes have very
-- different heights/paddings, so a true 2D distance would misjudge who's
-- actually "nearby" on the shared ground line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpatialHash = require(ReplicatedStorage.Shared.SpatialHash)

local PlayerState = require(script.Parent.Parent.Simulation.PlayerState)
local EnemyState = require(script.Parent.Parent.Simulation.EnemyState)

local InterestManager = {}

-- Generous vs any single viewport so camera lag/edge-of-screen never causes
-- visible pop-in right at the boundary.
local INTEREST_RADIUS = 1000

local function playerFields(state)
	return {
		x = state.x, y = state.y, facingLeft = state.facingLeft, grounded = state.grounded,
		hp = state.hp, maxHp = state.maxHp, level = state.level, xp = state.xp, xpToNext = state.xpToNext,
	}
end

local function enemyFields(enemy)
	return {
		x = enemy.x, y = enemy.y, hp = enemy.hp, maxHp = enemy.maxHp,
		facingLeft = enemy.facingLeft, attackTick = enemy.attackTick,
	}
end

function InterestManager.broadcast(remotes)
	local hash = SpatialHash.new(INTEREST_RADIUS)
	local playerByUserId = {}

	for player, state in pairs(PlayerState.all()) do
		local key = tostring(player.UserId)
		playerByUserId[key] = state
		hash:insert("player:" .. key, Vector2.new(state.x, 0))
	end
	for id, enemy in pairs(EnemyState.all()) do
		hash:insert("enemy:" .. tostring(id), Vector2.new(enemy.x, 0))
	end

	for player, state in pairs(PlayerState.all()) do
		if not state.ready then
			-- Client hasn't connected WorldSnapshot.OnClientEvent yet (see
			-- ClientReady in RemoteSetup.lua) — firing now would just be
			-- dropped by the engine with a "discarded event" warning. Skip
			-- silently; the next broadcast tick after they signal ready will
			-- deliver a fresh snapshot instead.
			continue
		end

		local nearbyIds = hash:queryRadius(Vector2.new(state.x, 0), INTEREST_RADIUS)
		local playersSnapshot, enemiesSnapshot = {}, {}

		for _, entityId in ipairs(nearbyIds) do
			local kind, idPart = entityId:match("^(%a+):(.+)$")
			if kind == "player" then
				local otherState = playerByUserId[idPart]
				if otherState then
					playersSnapshot[idPart] = playerFields(otherState)
				end
			elseif kind == "enemy" then
				local enemy = EnemyState.get(tonumber(idPart))
				if enemy then
					enemiesSnapshot[idPart] = enemyFields(enemy)
				end
			end
		end

		remotes.WorldSnapshot:FireClient(player, { players = playersSnapshot, enemies = enemiesSnapshot })
	end
end

return InterestManager
