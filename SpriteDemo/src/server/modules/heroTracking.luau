-- 플레이어 추적(서버): 각 플레이어가 "지금 어느 씬의 어디에 있는지". 캐릭터는 엔진 공식 패턴대로 client-authoritative
-- (클라이언트가 직접 만들고 조작)이고, 그 위치는 클라이언트가 NetworkingService로 복제해 보내는 요청(ReplicationRequest)에
-- 이미 들어 있다 — server/modules/replication.luau가 그 요청 내용에서 위치를 읽어 여기(OnHeroReplicated)로 넘긴다.
-- 따라서 위치를 따로 보고받는 패킷은 없다(공격 · 인술 · 투척의 기준 위치도 여기 저장된 서버가 아는 위치를 쓴다).
-- 이동 위치를 매번 거절하는 것은 엔진 공식 문서가 비권장이라(오탐/지연) 하지 않는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local scenes = require(ReplicatedStorage.shared.config.scenes)

-- UserId -> Vector2(화면 좌표계 Position.Offset)
local positions = {}
-- UserId -> 그 플레이어가 지금 있는 씬 이름. 서버가 소유한다(접속 시 마을, 이후 서버가 승인한 이동/사망 리스폰으로만 바뀜). 서버는 몬스터가
-- 있는 씬과 플레이어의 씬이 같은지 알아야 한다 — 좌표만 보면 마을에 있는 플레이어가 사냥터
-- 몬스터의 어그로/공격 대상이 돼버린다.
local playerScenes = {}

local exports = {}

function exports.GetPlayerScene(userId: number)
	return playerScenes[userId]
end

-- UserId -> 그 플레이어의 "현재" 캐릭터 오브젝트 Id(씬을 옮길 때마다 새 캐릭터가 만들어져서 바뀐다).
local heroObjectIds = {}

-- 플레이어의 씬을 바꾼다. 씬이 바뀌면 서로 다른 씬에 있게 된 플레이어들의 캐릭터 사본을 상대 클라이언트에서 지운다 —
-- 안 지우면 마지막 위치에 멈춘 유령 캐릭터가 남는다(둘이 접속해 한 명이 포탈을 탔을 때 실측).
-- 씬이 바뀔 때 알림을 받는다(예: 몬스터 기여도 초기화) — callback(userId, 이전 씬 이름?, 새 씬 이름)
local sceneChangedCallbacks = {}
function exports.OnSceneChanged(callback: (number, string?, string) -> ())
	table.insert(sceneChangedCallbacks, callback)
end

function exports.SetPlayerScene(userId: number, sceneName: string)
	local previous = playerScenes[userId]
	playerScenes[userId] = sceneName
	if previous ~= sceneName then
		for _, callback in sceneChangedCallbacks do
			task.spawn(callback, userId, previous, sceneName)
		end
	end
	for _, other in Players:GetPlayers() do
		if other.UserId == userId then
			continue
		end
		local otherScene = playerScenes[other.UserId]
		if otherScene ~= sceneName then
			-- 이동한 플레이어의 캐릭터를 상대가 지우고, 상대의 캐릭터를 이동한 플레이어가 지운다.
			local movedPlayer = Players:GetPlayerByUserId(userId)
			if heroObjectIds[userId] then
				Net.FireClient("RemoveReplicated", other, userId, heroObjectIds[userId])
			end
			if movedPlayer and heroObjectIds[other.UserId] then
				Net.FireClient("RemoveReplicated", movedPlayer, other.UserId, heroObjectIds[other.UserId])
			end
		end
	end
end

function exports.GetHeroObjectId(userId: number): string?
	return heroObjectIds[userId]
end

-- 지금 그 씬에 있는 플레이어 목록(탑다운 씬 공유 상태를 그 씬 사람들에게만 보낼 때)
function exports.PlayersInScene(sceneName: string): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if playerScenes[player.UserId] == sceneName then
			table.insert(list, player)
		end
	end
	return list
end

function exports.GetPosition(userId: number): Vector2?
	return positions[userId]
end

-- replication.luau가 히어로 복제 요청을 받을 때마다 호출한다(약 15Hz). position은 UDim2.
-- 반환값: 이 요청을 처리해도(다른 클라이언트에 전달해도) 되는가. 이미 교체된(은퇴한) 옛 캐릭터의 늦게 도착한 갱신이면 false —
-- 그걸 전달하면 상대 클라이언트가 방금 지운 옛 캐릭터를 새 오브젝트로 착각해 다시 만들어 유령이 된다(사망/씬 이동 직후 실측).
local retiredHeroIds = {}

function exports.OnHeroReplicated(userId: number, position: UDim2, objectId: string): boolean
	if retiredHeroIds[objectId] then
		return false
	end
	positions[userId] = Vector2.new(position.X.Offset, position.Y.Offset)
	local previous = heroObjectIds[userId]
	if previous ~= objectId then
		heroObjectIds[userId] = objectId
		if previous then
			retiredHeroIds[previous] = true
			-- 캐릭터가 새로 만들어졌다(씬 이동 등) — 옛 캐릭터는 클라이언트에서 이미 사라졌으므로 서버 캐시와 모든 클라이언트의
			-- 옛 사본을 지운다.
			NetworkingService.RequestsCache[userId][previous] = nil
			Net.FireAllClients("RemoveReplicated", userId, previous)
		end
	end
	return true
end

function exports.load()
	-- 게임은 항상 마을에서 시작한다.
	local function onPlayerAdded(player: Player)
		playerScenes[player.UserId] = scenes.TOWN
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		positions[player.UserId] = nil
		playerScenes[player.UserId] = nil
		heroObjectIds[player.UserId] = nil
	end)
end

function exports.start() end
function exports.unload() end

return exports
