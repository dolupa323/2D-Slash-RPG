-- Prototype-only test scene for evaluating UpsideEngine (notreux/UpsideEngine)
-- as a possible replacement for the hand-rolled GUI/Camera/PhysicsStep stack.
-- Does not touch HeroSpriteDemo.client.lua or GameConfig.lua. Safe to delete
-- once the evaluation is done either way.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local packages = ReplicatedStorage.packages
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local UpsideEngine = require(packages.UpsideEngine)
local crossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local networkingService = UpsideEngine.GetService("NetworkingService")

local screen = Instance.new("ScreenGui")
screen.Name = "UpsideTestGui"
screen.IgnoreGuiInset = true
screen.Parent = playerGui

local scene = UpsideEngine.new("Scene")
scene.Instance.Parent = screen
scene:SetName("UpsideTest")
scene:Enable()

-- Floor (Anchored PhysicalObject, plain color box)
local floor = UpsideEngine.new("PhysicalObject")
floor.Anchored = true
floor:SetScene(scene)
floor.Instance.BackgroundColor3 = Color3.fromRGB(90, 70, 50)
floor.Instance.BackgroundTransparency = 0
floor.Instance.Size = UDim2.fromOffset(1600, 100)
floor.Instance.Position = UDim2.fromOffset(0, 700)

-- One elevated platform to sanity-check landing/collision
local platform = UpsideEngine.new("PhysicalObject")
platform.Anchored = true
platform:SetScene(scene)
platform.Instance.BackgroundColor3 = Color3.fromRGB(150, 120, 70)
platform.Instance.BackgroundTransparency = 0
platform.Instance.Size = UDim2.fromOffset(300, 40)
platform.Instance.Position = UDim2.fromOffset(500, 500)

-- Character using our own hero2 sprite sheet (idle row only, for this test)
local character = UpsideEngine.new("Character")
character:SetScene(scene)
character.Instance.Position = UDim2.fromOffset(200, 400)
character.Instance.Size = UDim2.fromOffset(200, 200)
character.Instance.ImageRectSize = Vector2.new(256, 256)
character.Mass = 50
character.WalkSpeed = 220
character.JumpPower = 100

character:SetSpriteSheet("idle", "rbxassetid://124840409867821", Vector2.new(4, 1))
character:Play("idle")

crossPlatformService.SideView = true
crossPlatformService:SetPlayerCharacter(character)
scene.Camera:SetSubject(character)

-- Server-authoritative objects (created by the server's own Scene, e.g.
-- UpsideEngineTest.server.lua's "ServerWorld" marker) arrive here — this
-- client just needs to attach them to ITS local scene to render them.
print("UpsideEngineTest(client): waiting for Build events...")
networkingService:On("Build", function(object)
	print("UpsideEngineTest(client): received Build event for", object.ClassName)
	object:SetScene(scene)
end)

-- Avoid falling forever if physics misbehaves
RunService.Heartbeat:Connect(function()
	if character.Instance.Position.Y.Offset > 1500 then
		character.Instance.Position = UDim2.fromOffset(200, 400)
	end
end)
