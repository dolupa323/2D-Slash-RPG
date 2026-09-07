local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local uis = game:GetService("UserInputService")

local runService = game:GetService("RunService")
local upsideEngine = script.Parent.Parent

local crossPlatformService = require(upsideEngine.Services).CrossPlatformService
local util = require(upsideEngine.Lib.Util)

local configs = crossPlatformService.Configs
local wrap = util.Wrap

local actions = {
	up = false,
	left = false,
	right = false,
	down = false,
}

local lastAction = ""

local function resetActions()
	for action in actions do
		actions[action] = false
	end

	lastAction = ""
end

local directions = {
	up = Vector2.new(0, -1),
	left = Vector2.new(-1, 0),
	right = Vector2.new(1, 0),
	down = Vector2.new(0, 1),
}

local function onUserInput(state, input)
	local controlsEnabled = crossPlatformService.DefaultControllersEnabled
	local character = crossPlatformService.Character
	local action = input.Action:lower()

	local isValid = not character or not character.Sprites or not directions[action]
	local begin = state == "Begin"

	if not controlsEnabled or isValid then
		return
	end

	actions[action] = begin
	return
end

local function getStickDirection(position, config)
	local action, smaller = "idle", 10
	local direction = position.Unit

	for _, keyword in config do
		keyword = keyword:lower()

		local vector = directions[keyword]
		local magnitude = (vector - direction).Magnitude

		if magnitude < smaller then
			smaller = magnitude
			action = keyword
		end
	end

	return action
end

local function inputDetector(input, gpe)
	local inputType = input.UserInputType.Name
	local keyName = input.KeyCode.Name

	local device = inputType:match("Gamepad") and "Gamepad" or inputType:match("InputMethod") and "Mobile" or "Keyboard"
	local config = configs[device][keyName]

	if not config or inputType == "Keyboard" and gpe then
		return
	end

	local sensibility = crossPlatformService.StickSensibility
	local inputState = "Input" .. input.UserInputState.Name

	local position = Vector2.new(input.Position.X, input.Position.Y)
	local action = typeof(config) ~= "table" and config or getStickDirection(position * sensibility, config)

	crossPlatformService:Fire(inputState, {
		Action = action,
		Position = position,
		KeyCode = input.KeyCode,
	})
end

local function inputSetup(obj, func)
	for _, event in { "Began", "Changed", "Ended" } do
		obj["Input" .. event]:Connect(func)
	end
end

local function mobileSetup()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local touchControlFrame = playerGui:WaitForChild("TouchGui"):WaitForChild("TouchControlFrame")
	local thumbstick = touchControlFrame:WaitForChild("ThumbstickFrame")

	local stick = thumbstick:WaitForChild("StickImage")
	local jumpButton = touchControlFrame:WaitForChild("JumpButton")

	local jumpKeyCode = {
		Name = "JumpButton",
		EnumType = "KeyCode",
		Value = 5,
	}

	inputSetup(jumpButton, function()
		inputDetector({
			Position = Vector2.zero,
			UserInputState = Enum.UserInputState.Begin,
			UserInputType = Enum.UserInputType.InputMethod,
			KeyCode = jumpKeyCode,
		})
	end)

	local changed = false
	local base = Vector2.new(17, 17)
	runService.Heartbeat:Connect(function()
		local position = Vector2.new(stick.Position.X.Offset, stick.Position.Y.Offset)
		position = position - base
		position = Vector2.new(position.X, -position.Y)

		if position.X == 0 and changed then
			changed = false
			inputDetector({
				Position = Vector2.zero,
				UserInputState = Enum.UserInputState.End,
				UserInputType = Enum.UserInputType.InputMethod,
				KeyCode = Enum.KeyCode.Thumbstick1,
			})
		elseif position.X ~= 0 then
			changed = true
			inputDetector({
				Position = position,
				UserInputState = Enum.UserInputState.Begin,
				UserInputType = Enum.UserInputType.InputMethod,
				KeyCode = Enum.KeyCode.Thumbstick1,
			})
		end
	end)
end

-- BUGFIX(local): mobileSetup()은 로블록스 기본 3D 캐릭터가 만들어주는 TouchGui에 기대는데,
-- 이 프로젝트는 CharacterAutoLoads=false라 TouchGui가 절대 생기지 않는다. 그래서 이 함수를
-- 켜두면 WaitForChild("TouchGui")가 영원히 멈춰서 매번 "Infinite yield possible" 경고만
-- 찍었다. 자체 모바일 버튼(client/modules/globals/mobileControls.luau)이 CrossPlatformService
-- 를 직접 Fire해서 대체하므로 이 경로는 더 이상 필요 없어 비활성화한다.
-- if uis.TouchEnabled then
-- 	coroutine.wrap(pcall)(mobileSetup)
-- end

game.StarterPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Thumbstick
inputSetup(uis, inputDetector)

crossPlatformService:On("InputBegin", wrap(onUserInput, "Begin"))
crossPlatformService:On("InputChange", wrap(onUserInput, "Begin"))
crossPlatformService:On("InputEnd", wrap(onUserInput, "Ended"))
crossPlatformService:On("CharacterDestroy", resetActions)

local function animationPlayer(character, sideView)
	local defaultIdle = if sideView then "idle_right" else "idle_down"
	local action = "none"
	local animation = "idle"

	for control, enabled in actions do
		if not enabled then
			continue
		end

		action = control
		animation = control
	end

	if action == lastAction then --or sideView and character.IsJumping and lastAction == "up" then
		return
	elseif action == "none" and not lastAction:match("idle") then
		-- BUGFIX(local): lastAction은 접속 직후 ""(한 번도 입력 없음)로 시작한다. 이 값을 그대로
		-- ("idle_%s"):format(lastAction)에 넣으면 "idle_"(방향 없는 이름)가 만들어지는데, 어떤
		-- 캐릭터의 SHEETS에도 없는 이름이라 character:Play("idle_")가 SpritePlayer에서 매 프레임
		-- 조용히 스킵되고, lastAction이 "none"으로 저장돼버려서 입력이 들어오기 전까진 영원히
		-- Instance.Image가 비어있게 된다(접속 직후 캐릭터가 안 보이는 버그). lastAction이 아직
		-- 없을 때는 일반 "idle"로 폴백시켜 아래에서 defaultIdle로 정규화되게 한다.
		animation = if lastAction == "" then "idle" else ("idle_%s"):format(lastAction)
	end

	animation = if animation == "idle" then defaultIdle else animation
	-- BUGFIX(local): the previous unconditional "if lastAction was left/right,
	-- force idle_{lastAction}" here was redundant with the action=="none" branch
	-- above (which already generalizes idle_{lastAction} to all 4 directions) AND
	-- it incorrectly fired when switching directly from one active direction to a
	-- NEW active direction (not going idle at all) whenever the previous direction
	-- happened to be left/right — e.g. holding Left then switching to Down would
	-- get its freshly-computed "down" animation overwritten back to "idle_left".
	-- Removed; the action=="none" branch above already covers the intended
	-- (side-view and top-down) "show idle facing last direction" behavior.
	lastAction = action

	character:Play(animation)
end

local function characterController(character, sideView)
	local velocity = Vector2.zero
	if actions.up and sideView and character.IsGrounded then
		character:Jump()
	end

	for key, direction in directions do
		local active = actions[key]
		if not active or key == "up" and sideView then
			continue
		end

		velocity += direction
	end

	velocity = if velocity ~= Vector2.zero then velocity.Unit else velocity
	velocity = velocity * character.WalkSpeed * 5

	if velocity == Vector2.zero then
		return
	end

	character.Velocity = if not character.IsGrounded and sideView
		then Vector2.new(velocity.X, character.Velocity.Y)
		else velocity
end

RunService.Heartbeat:Connect(function()
	local character = crossPlatformService.Character
	local sideView = crossPlatformService.SideView

	if not character or not character.Instance then
		return
	end

	animationPlayer(character, sideView)
	characterController(character, sideView)
end)

return {}
