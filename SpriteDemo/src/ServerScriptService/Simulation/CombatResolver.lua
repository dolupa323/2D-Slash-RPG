-- Validates and resolves RequestAttack. Never trusts the client for hit
-- position or facing — both are re-derived from the player's own
-- authoritative PlayerState. The client's request payload carries no data at
-- all; it's just "I pressed the button."

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local SpatialHash = require(ReplicatedStorage.Shared.SpatialHash)

local PlayerState = require(script.Parent.PlayerState)
local EnemyState = require(script.Parent.EnemyState)
local EnemyAI = require(script.Parent.EnemyAI)

local CombatResolver = {}

function CombatResolver.init(remotes)
	remotes.RequestAttack.OnServerEvent:Connect(function(player)
		local state = PlayerState.get(player)
		if not state then
			return
		end

		local cfg = GameConfig.Player
		local now = os.clock()
		if (now - state.lastAttackTime) < cfg.attackCooldown then
			return -- cooldown enforced server-side; extra client requests are ignored
		end
		state.lastAttackTime = now

		local facingDx = state.facingLeft and -1 or 1
		local hitX = state.x + facingDx * (cfg.attackRange / 2)
		-- Horizontal-only hit-test: collapse everything onto Y=0 before
		-- hashing/querying. Player and enemy sprite boxes have very
		-- different heights/paddings (see EnemyAI's findNearestPlayer
		-- comment), so a true 2D circular distance would make melee range
		-- effectively never connect even when standing right next to each
		-- other on the shared ground line.
		local hitPoint = Vector2.new(hitX, 0)

		-- Build a fresh hash of current enemy positions for the hit-test.
		-- (Small enemy counts today; if this ever gets hot, EnemyAI's own
		-- separationHash could be reused directly instead of rebuilt here.)
		local hitHash = SpatialHash.new(cfg.attackRange)
		for id, enemy in pairs(EnemyState.all()) do
			hitHash:insert(id, Vector2.new(enemy.x, 0))
		end

		for _, id in ipairs(hitHash:queryRadius(hitPoint, cfg.attackRange)) do
			local enemy = EnemyState.get(id)
			if enemy then
				enemy.hp -= cfg.attackDamage
				if enemy.hp <= 0 then
					EnemyState.remove(id)
					EnemyAI.forget(id)

					local enemyCfg = GameConfig.Enemy
					state.xp += enemyCfg.xpReward
					while state.xp >= state.xpToNext do
						state.xp -= state.xpToNext
						state.level += 1
						state.maxHp += 15
						state.hp = state.maxHp
						state.xpToNext = cfg.xpToLevel(state.level)
					end
				end
			end
		end
	end)
end

return CombatResolver
