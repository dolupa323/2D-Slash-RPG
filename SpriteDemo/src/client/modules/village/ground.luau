-- 횡스크롤 테스트용 바닥. 탑다운 타일들은 전부 StaticObject(충돌 없음)라서
-- 캐릭터가 설 곳이 없었다 — PhysicalObject(Anchored+CanCollide)로 만든 단순한
-- 발판을 하나 깔아서 중력/점프가 실제로 동작하는지 확인할 수 있게 한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))

local exports = {}

function exports.load(scene: Scene)
	local ground = UpsideEngine.new("PhysicalObject")
	ground:SetScene(scene)

	ground.Anchored = true
	ground.CanCollide = true

	local instance = ground.Instance
	instance.AnchorPoint = Vector2.new(0.5, 0)
	instance.Position = UDim2.fromOffset(0, 80)
	instance.Size = UDim2.fromOffset(2000, 60)
	instance.BackgroundTransparency = 0
	instance.BackgroundColor3 = Color3.fromRGB(90, 60, 40)
	instance.ZIndex = 5

	exports.ground = ground
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	exports.ground = nil
end

return exports
