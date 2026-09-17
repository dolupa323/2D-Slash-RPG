-- 포탈 공용 구현. village/portal.luau, Backfield/portal.luau 등 여러 씬에서 그대로
-- 재사용하려고 modules/ 루트(씬 폴더 밖)로 뺐다 — heroController.luau와 같은 이유·같은
-- 방식이다(각 씬 폴더의 portal.luau는 이 모듈을 그대로 반환하는 얇은 래퍼).
--
-- 씬 안에 플러그인으로 배치된 포탈 오브젝트를 찾아서, 캐릭터가 그 위에 서 있는 동안
-- 상호작용 입력(키보드 스페이스바, 모바일 전용 상호작용 버튼)을 누르면 그 포탈이
-- 가리키는 씬으로 전환한다.
--
-- 포탈 식별: 오브젝트 이름이 "Portal_"로 시작하면 포탈로 간주하고, 그 뒤에 붙은 부분을
-- 목적지 씬 이름으로 쓴다 — 예: "Portal_Backfield"는 SceneManager:FindByName("Backfield")로
-- 전환한다.
--
-- "포탈은 통로다" 개념: 마을↔사냥터1↔사냥터2처럼 씬 A와 B를 잇는 통로는 A에
-- "Portal_B", B에 "Portal_A"가 항상 쌍으로 있어야 한다. 포탈을 타면 "어디서 왔는지"
-- (travelState.fromScene)를 남겨두고, 도착한 씬의 heroController.luau가 그 씬 안에서
-- "Portal_<출발 씬 이름>"을 찾아 그 포탈의 좌표에 스폰시킨다 — 즉 되돌아가는 포탈
-- 자체가 입구이자 출구가 된다(별도 스폰 마커 불필요). 게임을 처음 시작할 때처럼
-- "어디서 왔는지"가 없는 경우는 heroController.luau가 대신 "Spawn"이라는 이름의
-- 안전 스폰 오브젝트를 찾아 쓴다.
--
-- "포탈 위에 서 있는지"는 엔진의 Collision/CollisionEnd 이벤트로 잡으려 했었는데, 디버깅
-- 결과 플러그인에서 만들어진 포탈 오브젝트가 PhysicalObject 생성자를 제대로 거치지
-- 않아서(ClassNameHistory에 "PhysicalObject"가 빠져 있고 CollisionBlacklist/Hitbox 등
-- 필수 필드가 전부 nil) 엔진 충돌 시스템에 억지로 태우면 매 프레임 에러가 났다. 그래서
-- 엔진 충돌 시스템을 아예 안 쓰고, 이미 정상적으로 읽히는
-- Instance.AbsolutePosition/AbsoluteSize만으로 직접 사각형 겹침(AABB) 판정을 한다 —
-- 이 방식은 오브젝트가 완전한 PhysicalObject가 아니어도 안전하게 동작한다.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local SceneManager = UpsideEngine.GetService("SceneManager")
local travelState = require(script.Parent.travelState)

local PORTAL_PREFIX = "Portal_"

local exports = {}

local function isOverlapping(a: GuiObject, b: GuiObject): boolean
	local aPos, aSize = a.AbsolutePosition, a.AbsoluteSize
	local bPos, bSize = b.AbsolutePosition, b.AbsoluteSize

	return aPos.X < bPos.X + bSize.X
		and aPos.X + aSize.X > bPos.X
		and aPos.Y < bPos.Y + bSize.Y
		and aPos.Y + aSize.Y > bPos.Y
end

function exports.load(scene: Scene)
	local currentSceneName = scene.Name

	local portals = {}
	for _, object in scene.Objects do
		local name = object.Name
		if name and name:sub(1, #PORTAL_PREFIX) == PORTAL_PREFIX then
			local destination = name:sub(#PORTAL_PREFIX + 1)
			if destination ~= "" then
				table.insert(portals, { object = object, destination = destination, occupied = false })
			end
		end
	end

	if #portals == 0 then
		exports.portals = portals
		exports.connections = {}
		return
	end

	local connections = {}

	-- 매 프레임 히어로와 각 포탈의 화면상 사각형이 겹치는지 직접 검사한다.
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function()
			local character = CrossPlatformService.Character
			if not character or not character.Instance then
				return
			end

			for _, portal in portals do
				local portalInstance = portal.object.Instance
				portal.occupied = portalInstance ~= nil and isOverlapping(character.Instance, portalInstance)
			end
		end)
	)

	table.insert(
		connections,
		CrossPlatformService:On("InputBegin", function(input)
			-- "Up"은 이미 점프에 쓰여서 겹치므로, 포탈은 전용 액션 "Interact"를 쓴다
			-- (키보드 스페이스바 / 모바일 전용 상호작용 버튼 — mobileControls.luau 참고).
			local action = input.Action and input.Action:lower()
			if action ~= "interact" then
				return
			end

			for _, portal in portals do
				if portal.occupied then
					local destinationScene = SceneManager:FindByName(portal.destination)
					if destinationScene then
						-- 도착한 씬의 heroController.luau가 이 값을 읽어서
						-- "Portal_<currentSceneName>"(되돌아가는 포탈) 위치에 스폰시킨다.
						travelState.fromScene = currentSceneName
						destinationScene:Enable()
					else
						warn(
							('portal: 목적지 씬 "%s"을(를) 찾을 수 없습니다(아직 안 만들어졌을 수 있음) — "%s"'):format(
								portal.destination,
								portal.object.Name
							)
						)
					end
					break
				end
			end
		end)
	)

	exports.portals = portals
	exports.connections = connections
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	if exports.connections then
		for _, connection in exports.connections do
			connection:Disconnect()
		end
		exports.connections = nil
	end
	exports.portals = nil
end

return exports
