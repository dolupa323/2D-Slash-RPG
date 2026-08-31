-- 2D side-scroller character using Luneblade "Little Axion" frame images.
-- Source pack: C:\Users\tjrwl\OneDrive\바탕 화면\character\Luneblade - Little Axion (Premium)\Sprite Sheet
-- The source sheets were sliced into 144x144 individual frame images before Roblox upload.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

local FRAME_SIZE = Vector2.new(144, 144)
local DISPLAY_SCALE = 2
local SECONDS_PER_FRAME = 0.08
local RUN_SPEED_THRESHOLD = 20
local AIR_SPEED_THRESHOLD = 90
local SPAWN_POSITION = UDim2.fromOffset(0, 0)

local FRAMES = {
	idle_left = {
		"rbxassetid://134285491649186",
		"rbxassetid://137114705666321",
		"rbxassetid://111987246167308",
		"rbxassetid://135025423392083",
		"rbxassetid://126322038101802",
		"rbxassetid://122626164138158",
		"rbxassetid://118865360527888",
	},
	idle_right = {
		"rbxassetid://110595634307251",
		"rbxassetid://139696014847562",
		"rbxassetid://119855396290085",
		"rbxassetid://100317355740609",
		"rbxassetid://87002501045061",
		"rbxassetid://71934223452638",
		"rbxassetid://134939445695719",
	},
	run_left = {
		"rbxassetid://137565581235083",
		"rbxassetid://102223103552996",
		"rbxassetid://103300825542257",
		"rbxassetid://96848748657319",
		"rbxassetid://84213320367114",
		"rbxassetid://114452352968400",
		"rbxassetid://113683717128321",
		"rbxassetid://138931071387360",
	},
	run_right = {
		"rbxassetid://140104151952945",
		"rbxassetid://111993056149471",
		"rbxassetid://105779281690657",
		"rbxassetid://87463465280776",
		"rbxassetid://113126159726107",
		"rbxassetid://83635723828096",
		"rbxassetid://118750071623615",
		"rbxassetid://113773296438733",
	},
	jump_left = {
		"rbxassetid://94353826316506",
		"rbxassetid://79042821305975",
		"rbxassetid://131142098000722",
		"rbxassetid://93662875465072",
	},
	jump_right = {
		"rbxassetid://76883436908612",
		"rbxassetid://73948710202250",
		"rbxassetid://104040887723189",
		"rbxassetid://80056725580351",
	},
	fall_left = {
		"rbxassetid://81405797311530",
		"rbxassetid://130677725796776",
		"rbxassetid://97357384738116",
		"rbxassetid://82988255975110",
	},
	fall_right = {
		"rbxassetid://79691688871391",
		"rbxassetid://111957921048022",
		"rbxassetid://119513483701995",
		"rbxassetid://88442081677508",
	},
}

local exports = {}

local function animationFor(hero: Character, facing: string, moving: boolean): string
	local velocity = hero.Velocity or Vector2.zero

	if velocity.Y < -AIR_SPEED_THRESHOLD then
		return "jump_" .. facing
	elseif velocity.Y > AIR_SPEED_THRESHOLD then
		return "fall_" .. facing
	elseif moving then
		return "run_" .. facing
	end

	return "idle_" .. facing
end

function exports.load(scene: Scene)
	local hero = UpsideEngine.new("Character")
	hero:SetScene(scene)

	hero.Anchored = false
	hero.HitboxScale = 0.22

	local instance = hero.Instance
	instance.Image = FRAMES.idle_right[1]
	instance.Position = SPAWN_POSITION
	instance.Size = UDim2.fromOffset(FRAME_SIZE.X * DISPLAY_SCALE, FRAME_SIZE.Y * DISPLAY_SCALE)
	instance.ImageRectSize = Vector2.zero
	instance.ImageRectOffset = Vector2.zero
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.ZIndex = 10

	CrossPlatformService.SideView = true
	CrossPlatformService.DefaultControllersEnabled = true
	CrossPlatformService:SetPlayerCharacter(hero)

	exports.hero = hero
end

function exports.start(scene: Scene)
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local hero = exports.hero
	if not hero then
		return
	end

	local facing = "right"
	local currentAnimation = "idle_right"
	local currentFrame = 1
	local frameClock = 0

	exports.connection = RunService.Heartbeat:Connect(function(delta)
		local instance = hero.Instance
		if instance.Position.Y.Offset >= 1000 then
			instance.Position = SPAWN_POSITION
		end

		local velocity = hero.Velocity or Vector2.zero
		local leftHeld = UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)
		local rightHeld = UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right)
		local moving = leftHeld ~= rightHeld

		if leftHeld and not rightHeld then
			facing = "left"
		elseif rightHeld and not leftHeld then
			facing = "right"
		elseif velocity.X < -RUN_SPEED_THRESHOLD then
			facing = "left"
			moving = true
		elseif velocity.X > RUN_SPEED_THRESHOLD then
			facing = "right"
			moving = true
		end

		local nextAnimation = animationFor(hero, facing, moving)
		if nextAnimation ~= currentAnimation then
			currentAnimation = nextAnimation
			currentFrame = 1
			frameClock = 0
		else
			frameClock += delta
			while frameClock >= SECONDS_PER_FRAME do
				frameClock -= SECONDS_PER_FRAME
				currentFrame += 1
			end
		end

		local frames = FRAMES[currentAnimation]
		if currentFrame > #frames then
			currentFrame = 1
		end

		instance.Image = frames[currentFrame]
		instance.ImageRectSize = Vector2.zero
		instance.ImageRectOffset = Vector2.zero
	end)
end

function exports.unload(scene: Scene)
	if exports.connection then
		exports.connection:Disconnect()
	end

	exports.connection = nil
	exports.hero = nil
end

return exports
