-- Receives PlayerInput from clients and writes sanitized intent into
-- PlayerState. Never trusts raw values: moveX is clamped to {-1,0,1},
-- malformed payloads are dropped. jumpPressed is OR'd into a request flag
-- rather than overwritten, so a jump press landing between two physics
-- ticks is never silently lost (PhysicsStep consumes and clears it).

local PlayerState = require(script.Parent.Parent.Simulation.PlayerState)

local InputHandler = {}

function InputHandler.init(remotes)
	remotes.PlayerInput.OnServerEvent:Connect(function(player, payload)
		local state = PlayerState.get(player)
		if not state or type(payload) ~= "table" then
			return
		end

		if type(payload.moveX) == "number" then
			state.moveX = math.clamp(payload.moveX, -1, 1)
		end
		if payload.jumpPressed == true then
			state.jumpRequested = true
		end
	end)
end

return InputHandler
