-- Top-down character using the "Tiny Questers" Warrior (full build) atlas sheets.
-- Source: Assets/Topdown/tiny-questers-free-starter-pack/warrior_free/full/png/atlas
-- 64x49 canvas per frame, shared feet-center pivot (AnchorPoint bottom-center keeps
-- the ground contact point fixed even if a future state uses a taller canvas).
-- No idle_left/idle_right in this pack — the first walk_left/walk_right frame is
-- reused as the idle pose for those two facings.
--
-- Uses the engine's own cross-platform input/animation system
-- (Runtime/CrossPlatformTracker.luau) instead of a hand-rolled Heartbeat loop:
-- SetSpriteSheet registers each named clip, and the tracker calls hero:Play(name)
-- every frame based on its own `actions` state (keyboard AND mobile thumbstick AND
-- gamepad, unified) — animation names must be exactly "idle_down"/"idle_up"/
-- "idle_left"/"idle_right" for standing, and "down"/"up"/"left"/"right" (no "walk_"
-- prefix) for moving, because that's what CrossPlatformTracker.animationPlayer()
-- hard-codes. This also fixes the walk-plays-out-before-idle lag from the previous
-- hand-rolled version: the tracker switches the moment an action key/thumbstick
-- direction releases, it does not wait for velocity to decay under a threshold.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")

local FRAME_WIDTH = 64
local FRAME_HEIGHT = 49
local DISPLAY_SCALE = 2
local SECONDS_PER_FRAME = 1 / 6.67 -- matches the pack's ~6.67fps preview timing
local SPAWN_POSITION = UDim2.fromOffset(0, 0)

local SHEETS = {
	idle_down = { url = "rbxassetid://98281587393781", cols = 5 },
	idle_up = { url = "rbxassetid://114640386374566", cols = 5 },
	idle_left = { url = "rbxassetid://116053659809327", cols = 1 }, -- first walk_left frame, held
	idle_right = { url = "rbxassetid://126882683270120", cols = 1 }, -- first walk_right frame, held
	down = { url = "rbxassetid://133126029788292", cols = 4 },
	up = { url = "rbxassetid://131893663751579", cols = 4 },
	left = { url = "rbxassetid://116053659809327", cols = 4 },
	right = { url = "rbxassetid://126882683270120", cols = 4 },
}

local exports = {}

function exports.load(scene: Scene)
	local hero = UpsideEngine.new("Character")
	hero:SetScene(scene)

	hero.Anchored = false
	hero.HitboxScale = 0.6
	hero.GravityScale = 0
	hero.WalkSpeed = 80 -- default is 150; slowed down further
	hero.SecondsPerFrame = SECONDS_PER_FRAME

	local instance = hero.Instance
	instance.AnchorPoint = Vector2.new(0.5, 1) -- feet-center pivot: keeps ground contact fixed
	instance.Position = SPAWN_POSITION
	instance.Size = UDim2.fromOffset(FRAME_WIDTH * DISPLAY_SCALE, FRAME_HEIGHT * DISPLAY_SCALE)
	instance.ImageRectSize = Vector2.new(FRAME_WIDTH, FRAME_HEIGHT)
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.ZIndex = 10

	for name, sheet in SHEETS do
		hero:SetSpriteSheet(name, sheet.url, Vector2.new(sheet.cols, 1))
	end
	hero:Play("idle_down")

	CrossPlatformService.SideView = false
	CrossPlatformService.DefaultControllersEnabled = true
	CrossPlatformService:SetPlayerCharacter(hero)

	exports.hero = hero
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	exports.hero = nil
end

return exports
