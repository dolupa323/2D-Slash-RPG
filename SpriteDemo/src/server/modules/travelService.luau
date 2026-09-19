-- 씬 이동(포탈) 승인 서비스. 플레이어가 어느 씬에 있는지의 진실은 서버(heroTracking)가 갖는다 — 클라이언트가 제멋대로
-- 씬을 바꿔도 서버의 씬 정보는 그대로라서 몬스터 어그로/공격/드롭 등 서버 로직에는 영향이 없고, 정상적인 이동은 이 서비스의
-- 승인을 거쳐야 한다. 검증: (1) 지금 씬에 그 목적지로 가는 포탈("Portal_<목적지>")이 있는가 (2) 서버가 아는 플레이어 위치가
-- 그 포탈 근처인가. 통과하면 서버 씬을 바꾸고 TravelApproved를 보내 클라이언트가 실제 씬 전환(화면/캐릭터)을 하게 한다.
-- (서버는 렌더링이 없어 AbsolutePosition을 못 쓰므로 포탈의 Position/Size/AnchorPoint 오프셋으로 직접 계산한다.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local scenes = require(ReplicatedStorage.shared.config.scenes)
local balance = require(ReplicatedStorage.shared.config.balance)

local sceneBootstrap = require(script.Parent.sceneBootstrap)
local heroTracking = require(script.Parent.heroTracking)
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")

local PORTAL_PREFIX = "Portal_"

local exports = {}

-- 씬의 포탈 사각형(left, top, right, bottom)을 찾는다.
local function findPortalRect(sceneName: string, destination: string)
	local scene = sceneBootstrap.GetScene(sceneName)
	if not scene then
		return nil
	end
	for _, object in scene.Objects do
		local instance = object.Instance
		if instance and object.Name == PORTAL_PREFIX .. destination then
			local w, h = instance.Size.X.Offset, instance.Size.Y.Offset
			local left = instance.Position.X.Offset - instance.AnchorPoint.X * w
			local top = instance.Position.Y.Offset - instance.AnchorPoint.Y * h
			return left, top, left + w, top + h
		end
	end
	return nil
end

function exports.load()
	Net.OnServer("RequestTravel", function(player: Player, destination)
		local currentScene = heroTracking.GetPlayerScene(player.UserId)
		local position = heroTracking.GetPosition(player.UserId)
		if not currentScene or not position or currentScene == destination then
			return
		end

		local left, top, right, bottom = findPortalRect(currentScene, destination)
		if not left then
			return -- 지금 씬에 그 목적지로 가는 포탈이 없다.
		end

		-- 히어로는 발밑 중앙이 기준점이다. 히트박스(가로 폭 x 키)와 포탈 사각형이 (여유를 두고) 겹치는지 본다.
		local pad = balance.TRAVEL_PORTAL_PADDING
		local heroLeft = position.X - balance.HERO_WIDTH / 2
		local heroRight = position.X + balance.HERO_WIDTH / 2
		local heroTop = position.Y - balance.HERO_HEIGHT
		local heroBottom = position.Y
		local overlapping = heroRight + pad > left and heroLeft - pad < right and heroBottom + pad > top and heroTop - pad < bottom
		if not overlapping then
			return
		end

		heroTracking.SetPlayerScene(player.UserId, destination)
		-- 관심 영역이 바뀌었으니(relevancy.luau) 새 씬의 서버 오브젝트(몬스터 등)를 전체 내용으로 다시 받게 한다.
		NetworkingService:ResyncClient(player)
		Net.FireClient("TravelApproved", player, destination)
	end)
end

function exports.start() end
function exports.unload() end

return exports
