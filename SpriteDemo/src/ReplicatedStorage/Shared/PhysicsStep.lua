-- Gravity/jump/horizontal-move integration for one player state per tick.
-- SHARED between server (authoritative) and client (local prediction) —
-- both must run the exact same formula or the client's predicted position
-- would constantly drift from and fight the server's reconciliation
-- corrections. The server's copy of `state` is truth; the client's is a
-- local guess reconciled against server snapshots (see NetworkClient.lua).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local PhysicsStep = {}

function PhysicsStep.update(state, dt)
	local cfg = GameConfig.Player
	local world = GameConfig.World
	local physics = GameConfig.Physics
	local half = cfg.displaySize / 2
	local groundOffset = cfg.displaySize * cfg.visualBottomPad

	-- horizontal movement (left/right only, MapleStory-style)
	local moveX = state.moveX
	if moveX ~= 0 then
		state.x = math.clamp(state.x + moveX * cfg.moveSpeed * dt, half, world.width - half)
		state.facingLeft = moveX < 0
	end

	-- jump (edge-triggered: consumed once per request, only while grounded)
	if state.jumpRequested then
		state.jumpRequested = false
		if state.grounded then
			state.velocityY = physics.jumpVelocity
			state.grounded = false
		end
	end

	-- gravity + one-way platform landing: only checked while falling, so
	-- jumping up through a platform from below always passes through.
	-- Among all platforms whose x-range contains us and whose surface was
	-- crossed this tick (prevY <= standingY <= newY), land on the highest
	-- one (smallest standingY) — that's the first surface we'd hit falling.
	local prevY = state.y
	state.velocityY += physics.gravity * dt
	state.y += state.velocityY * dt

	state.grounded = false
	if state.velocityY >= 0 then
		local bestStandingY = nil
		for _, platform in ipairs(world.platforms) do
			if state.x >= platform.x1 and state.x <= platform.x2 then
				local standingY = platform.y - half + groundOffset
				if prevY <= standingY and state.y >= standingY then
					if not bestStandingY or standingY < bestStandingY then
						bestStandingY = standingY
					end
				end
			end
		end
		if bestStandingY then
			state.y = bestStandingY
			state.velocityY = 0
			state.grounded = true
		end
	end
end

return PhysicsStep
