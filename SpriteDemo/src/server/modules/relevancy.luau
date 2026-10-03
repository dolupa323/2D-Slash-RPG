-- 관심 영역(relevancy): 서버가 각 클라이언트에게 "같은 씬에 있는 플레이어의 캐릭터"만 복제한다(Ryzom의 Frontend Service가
-- 시야 안의 엔티티만 클라이언트에 보내는 것에 해당 — 여기서는 시야 대신 씬 단위).
--
-- 엔진의 NetworkingService에는 이런 필터가 없어서 엔진 사본(Runtime/Networking.luau)에 RelevancyFilter/ResyncClient 훅을
-- 추가했다. 이 모듈이 그 필터를 등록한다. 다른 플레이어의 캐릭터(클라이언트 소유)는 "소유자의 씬 = 보는 플레이어의 씬"일 때만
-- 전달한다. 씬 이동으로 관심 영역이 바뀌면 travelService가 ResyncClient로 새 씬의 캐릭터를 전체 내용으로 다시 받게 하고,
-- heroTracking.SetPlayerScene이 씬이 갈라진 플레이어들의 캐릭터 사본을 서로의 클라이언트에서 지운다(유령 방지).
-- (몬스터 · 땅의 아이템은 엔진 복제가 아니라 Net 패킷으로 같은 씬 사람에게만 보낸다 — townMonsters · worldDrops.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")

local heroTracking = require(script.Parent.heroTracking)

local exports = {}

function exports.load()
	NetworkingService.RelevancyFilter = function(player: Player, request): boolean
		if request.ClientId ~= 0 then
			-- 클라이언트 소유 오브젝트(플레이어 캐릭터): 소유자와 보는 사람이 같은 씬에 있을 때만 전달한다.
			local ownerScene = heroTracking.GetPlayerScene(request.ClientId)
			local viewer = heroTracking.GetPlayerScene(player.UserId)
			return ownerScene == nil or viewer == nil or ownerScene == viewer
		end

		return true -- 서버가 만든 오브젝트는 거르지 않는다(지금은 없다)
	end
end

function exports.start() end

function exports.unload()
	NetworkingService.RelevancyFilter = nil
end

return exports
