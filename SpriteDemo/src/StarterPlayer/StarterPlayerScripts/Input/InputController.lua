-- Unified input abstraction — keyboard, gamepad, and touch (via
-- TouchControls.lua) all funnel through this one API. Nothing else in the
-- client should ever touch UserInputService directly: GetMoveAxis() for
-- movement, PollJumpForServer()/PollJumpForPrediction() for jump intent, and
-- the JumpPressed/AttackPressed/WavePressed signals for one-shot actions.
-- Adding a new input source later (Phase 8 already covers the three that
-- matter on Roblox) never touches gameplay code, only this module.

local UserInputService = game:GetService("UserInputService")

local InputController = {}
InputController.__index = InputController

function InputController.new()
	local self = setmetatable({}, InputController)
	self._pressed = {}
	self._gamepadMoveAxis = 0
	self._touchMoveAxis = 0
	-- Two independent edge-triggered jump queues: NetworkClient consumes one
	-- (throttled, ~24Hz) to tell the server; the local prediction step
	-- consumes the other (every RenderStepped) to jump immediately on
	-- screen. Same press, two consumers, so a press is never "used up" by
	-- one before the other gets to see it.
	self._jumpQueuedForServer = false
	self._jumpQueuedForPrediction = false

	self.JumpPressed = Instance.new("BindableEvent")
	self.AttackPressed = Instance.new("BindableEvent")
	self.WavePressed = Instance.new("BindableEvent")

	self._beganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		self._pressed[input.KeyCode] = true

		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			self:TriggerJump()
		elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX then
			self:TriggerAttack()
		elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonY then
			self:TriggerWave()
		end
	end)

	self._endedConn = UserInputService.InputEnded:Connect(function(input)
		self._pressed[input.KeyCode] = false
	end)

	self._gamepadConn = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick1 then
			self._gamepadMoveAxis = input.Position.X
		end
	end)

	return self
end

-- ===== called by TouchControls' virtual buttons =====
function InputController:SetTouchMoveAxis(axis)
	self._touchMoveAxis = axis
end

function InputController:TriggerJump()
	self._jumpQueuedForServer = true
	self._jumpQueuedForPrediction = true
	self.JumpPressed:Fire()
end

function InputController:TriggerAttack()
	self.AttackPressed:Fire()
end

function InputController:TriggerWave()
	self.WavePressed:Fire()
end

-- ===== read API used by the render/network loop =====
function InputController:GetMoveAxis()
	local dx = 0
	if self._pressed[Enum.KeyCode.A] or self._pressed[Enum.KeyCode.Left] then dx -= 1 end
	if self._pressed[Enum.KeyCode.D] or self._pressed[Enum.KeyCode.Right] then dx += 1 end
	if dx ~= 0 then
		return dx
	end

	if math.abs(self._gamepadMoveAxis) > 0.2 then
		return self._gamepadMoveAxis
	end

	return self._touchMoveAxis
end

-- Edge-triggered: returns true (once) for a jump press queued since the last
-- call, then clears. Never dropped between calls — only ever consumed.
function InputController:PollJumpForServer()
	if self._jumpQueuedForServer then
		self._jumpQueuedForServer = false
		return true
	end
	return false
end

function InputController:PollJumpForPrediction()
	if self._jumpQueuedForPrediction then
		self._jumpQueuedForPrediction = false
		return true
	end
	return false
end

return InputController
