-- 관심 영역(relevancy): 서버가 각 클라이언트에게 "그 플레이어가 지금 있는 씬의 서버 오브젝트"만 복제한다. 예전에는 서버 몬스터 정보가
-- 마을에 있는 플레이어를 포함한 모든 클라이언트에 전송돼서, 씬/몬스터가 늘면 대역폭이 그대로 늘었다. Ryzom의 Frontend
-- Service가 시야 안의 엔티티만 클라이언트에 보내는 것에 해당한다(여기서는 시야 대신 씬 단위).
--
-- 엔진의 NetworkingService에는 이런 필터가 없어서 엔진 사본(Runtime/Networking.luau)에 RelevancyFilter/ResyncClient 훅을
-- 추가했다. 이 모듈이 그 필터를 등록한다. 서버 소유 오브젝트(몬스터 등)는 "그 오브젝트가 속한 씬 = 보는 플레이어의 씬"일 때만,
-- 다른 플레이어의 캐릭터(클라이언트 소유)는 "소유자의 씬 = 보는 플레이어의 씬"일 때만 전달한다. 씬 이동으로 관심 영역이 바뀌면
-- travelService가 ResyncClient로 새 씬의 오브젝트를 전체 내용으로 다시 받게 하고, heroTracking.SetPlayerScene이 씬이 갈라진
-- 플레이어들의 캐릭터 사본을 서로의 클라이언트에서 지운다(유령 방지).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local SceneManager = UpsideEngine.GetService("SceneManager")

local heroTracking = require(script.Parent.heroTracking)

-- sceneBootstrap가 서버 전용 씬에 붙이는 이름 접미사(클라이언트의 진짜 씬 이름과 충돌하지 않게 하려는 것).
local SERVER_ONLY_SUFFIX = "__ServerOnly"

local exports = {}

local function baseSceneName(scene): string
	local name = scene.Name
	if name:sub(-#SERVER_ONLY_SUFFIX) == SERVER_ONLY_SUFFIX then
		return name:sub(1, #name - #SERVER_ONLY_SUFFIX)
	end
	return name
end

function exports.load()
	NetworkingService.RelevancyFilter = function(player: Player, request): boolean
		if request.ClientId ~= 0 then
			-- 클라이언트 소유 오브젝트(플레이어 캐릭터): 소유자와 보는 사람이 같은 씬에 있을 때만 전달한다.
			local ownerScene = heroTracking.GetPlayerScene(request.ClientId)
			local viewer = heroTracking.GetPlayerScene(player.UserId)
			return ownerScene == nil or viewer == nil or ownerScene == viewer
		end

		local content = request.Content
		if not content or content.ClassName == "Scene" then
			return true -- 씬 자체는 항상 전달한다.
		end

		local viewerScene = heroTracking.GetPlayerScene(player.UserId)
		if not viewerScene then
			return true -- 아직 이 플레이어의 씬을 모르면 걸러내지 않는다(접속 직후).
		end

		local sceneId = content.ObjectProperties and content.ObjectProperties.Scene
		local scene = sceneId and SceneManager.Scenes[sceneId]
		if not scene then
			return true -- 어느 씬 소속인지 모르면 걸러내지 않는다(안전 쪽으로).
		end

		return baseSceneName(scene) == viewerScene
	end
end

function exports.start() end

function exports.unload()
	NetworkingService.RelevancyFilter = nil
end

return exports
