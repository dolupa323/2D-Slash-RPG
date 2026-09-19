-- 서버 권위 몬스터(monsterAI.luau 등)가 어그로/피격 판정을 하려면 "플레이어가 지금 어디 있는지", "언제 어느 방향으로
-- 공격했는지"를 알아야 한다. 히어로는 엔진 공식 패턴대로 client-authoritative(클라이언트가 직접 만들고 조작)이고,
-- 그 위치는 클라이언트가 NetworkingService로 복제해 보내는 요청(ReplicationRequest)에 이미 들어 있다 —
-- server/modules/replication.luau가 그 요청 내용에서 위치를 읽어 여기(OnHeroReplicated)로 넘긴다. 따라서 위치를 따로
-- 보고받는 RemoteEvent는 없다(공격 위치도 클라이언트가 보낸 값이 아니라 여기 저장된 서버가 아는 위치를 쓴다).
-- 서버가 검증하는 "중요 행동"은 공격 간격(balance.ATTACK_COOLDOWN)이다. 이동 위치를 매번 거절하는 것은 엔진 공식
-- 문서가 비권장이라(오탐/지연) 하지 않는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local balance = require(ReplicatedStorage.shared.config.balance)
local scenes = require(ReplicatedStorage.shared.config.scenes)

-- UserId -> Vector2(화면 좌표계 Position.Offset)
local positions = {}
-- 공격 신고를 구독하는 콜백들: function(player, x, y)
local attackListeners = {}

-- UserId -> 마지막 공격을 받아들인 시각(os.clock) — 공격 간격 검증용.
local lastAttackAt = {}

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
function exports.SetPlayerScene(userId: number, sceneName: string)
	playerScenes[userId] = sceneName
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

function exports.GetPosition(userId: number): Vector2?
	return positions[userId]
end

-- 몬스터 AI가 매 프레임 순회할 수 있게 원본 테이블을 그대로 노출한다(읽기 전용으로
-- 쓸 것 — 몬스터 쪽에서 이 테이블 자체를 수정하면 안 된다).
function exports.GetPositions()
	return positions
end

-- 여러 몬스터 모듈이 각자 구독할 수 있게 리스너 목록에 추가한다.
function exports.OnAttack(callback: (Player, number, number, string) -> ())
	table.insert(attackListeners, callback)
end

-- 몬스터 모듈이 "이 몬스터(Id)는 이제 완전히 없앨 것"이라고 모든 클라이언트에 알릴 때
-- 쓴다 — 죽는 페이드 애니메이션이 다 끝난 뒤, 실제로 Destroy()하기 직전에 호출해야 한다.
function exports.NotifyMonsterDespawned(monsterId: string)
	Net.FireAllClients("MonsterDespawned", monsterId)
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
	-- 인자 타입/빈도 검사는 Net이 이미 끝냈다(shared/net/packets.luau의 정의) — 핸들러는 통과한 값만 받는다.
	Net.OnServer("ReportHeroAttack", function(player: Player, facing)
		local now = os.clock()
		local last = lastAttackAt[player.UserId]
		if last and now - last < balance.ATTACK_COOLDOWN then
			return -- 공격 간격 검증: 너무 빠른 연속 공격은 무시(같은 스윙의 중복 신고도 여기서 걸러진다).
		end
		local position = positions[player.UserId]
		if not position then
			return -- 아직 서버가 이 플레이어의 위치를 모른다.
		end
		lastAttackAt[player.UserId] = now
		for _, callback in attackListeners do
			task.spawn(callback, player, position.X, position.Y, facing)
		end
	end)

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
		lastAttackAt[player.UserId] = nil
		heroObjectIds[player.UserId] = nil
	end)
end

function exports.start() end
function exports.unload() end

return exports
