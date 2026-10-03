-- 씬 이동(포탈) 승인 서비스. 플레이어가 어느 씬에 있는지의 진실은 서버(heroTracking)가 갖는다 — 클라이언트가 제멋대로
-- 씬을 바꿔도 서버의 씬 정보는 그대로라서 몬스터 어그로/공격/드롭 등 서버 로직에는 영향이 없고, 정상적인 이동은 이 서비스의
-- 승인을 거쳐야 한다. 검증: (1) 지금 씬에 그 목적지로 가는 포탈(townWorld 씬 데이터의 portals)이 있는가 (2) 서버가 아는
-- 플레이어 발 위치가 그 포탈 칸 근처인가. 통과하면 서버 씬을 바꾸고 TravelApproved를 보내 클라이언트가 실제 씬 전환을 하게 한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)

local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")

-- 탑다운 씬 포탈 판정 여유(도트): 발이 포탈 칸에서 이만큼 벗어나 있어도 인정(복제 지연 보정).
local TOWN_PORTAL_PAD = 12

-- 탑다운 씬(공방에서 만든 씬) 사이 이동 검증: 지금 씬에 목적지로 가는 포탈이 있고, 서버가 아는 발 위치가 그 포탈 칸 근처인가.
-- 서버가 아는 위치는 캐릭터 Position(화면 px = 도트 × scale, 발 기준)이다.
local function townTravelAllowed(currentScene: string, destination: string, position: Vector2): boolean
	local fromKey = townWorld.KeyOf(currentScene)
	local toKey = townWorld.KeyOf(destination)
	if not fromKey or not toKey then
		return false
	end
	local scale = townWorld.data.scale
	local x, y = position.X / scale, position.Y / scale
	for _, p in townWorld.Get(fromKey).portals do
		if p.to == toKey
			and x > p.x0 - TOWN_PORTAL_PAD and x < p.x1 + TOWN_PORTAL_PAD
			and y > p.y0 - TOWN_PORTAL_PAD and y < p.y1 + TOWN_PORTAL_PAD
		then
			return true
		end
	end
	return false
end

local exports = {}

function exports.load()
	Net.OnServer("RequestTravel", function(player: Player, destination)
		local currentScene = heroTracking.GetPlayerScene(player.UserId)
		local position = heroTracking.GetPosition(player.UserId)
		if not currentScene or not position or currentScene == destination then
			return
		end

		if not townTravelAllowed(currentScene, destination, position) then
			return
		end
		heroTracking.SetPlayerScene(player.UserId, destination)
		NetworkingService:ResyncClient(player) -- 관심 영역이 바뀌었으니(relevancy.luau) 새 씬의 다른 플레이어를 전체 내용으로 다시 받게 한다
		Net.FireClient("TravelApproved", player, destination)
	end)
end

function exports.start() end
function exports.unload() end

return exports
