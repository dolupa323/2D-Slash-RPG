-- 네트워크 패킷(RemoteEvent/RemoteFunction) 정의의 "단 하나의 출처". 공식 멀티플레이 데모(shared/packets.luau,
-- Remo + t 라이브러리)와 같은 개념 — 리모트 이름/방향/인자 타입/요청 빈도 제한을 여기에만 적는다. 서버는 이 정의로
-- 리모트를 만들고, 클라이언트→서버 패킷은 net.luau가 인자 타입과 빈도를 자동으로 검사한 뒤에야 핸들러를 부른다.
--
-- Direction: "ClientToServer"(클라가 서버에 요청/보고) / "ServerToClient"(서버가 클라에 통지).
-- Kind: "Event"(RemoteEvent) / "Function"(RemoteFunction, 서버 핸들러가 값을 돌려줌).
-- Args: ClientToServer 패킷만 사용 — 위치 인자 검증 함수 목록(개수도 정확히 맞아야 통과).
-- RateLimit: ClientToServer 패킷만 사용 — 플레이어별 토큰 버킷(PerSecond: 초당 보충량, Burst: 최대 적립량).
-- ServerToClient의 Doc은 인자 설명용(검증하지 않음).
local scenes = require(script.Parent.Parent.config.scenes)

local t = {}

-- 유한한 숫자만(NaN/무한대는 좌표 조작에 쓰일 수 있어 거른다).
function t.number(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function t.string(value: any): boolean
	return typeof(value) == "string" and #value <= 64
end

function t.oneOf(...: string)
	local allowed = {}
	for _, value in { ... } do
		allowed[value] = true
	end
	return function(value: any): boolean
		return typeof(value) == "string" and allowed[value] == true
	end
end

function t.optional(check)
	return function(value: any): boolean
		return value == nil or check(value)
	end
end

function t.either(a, b)
	return function(value: any): boolean
		return a(value) or b(value)
	end
end

local packets = {
	-- ===== 클라이언트 -> 서버 =====
	-- 위치와 씬은 클라이언트가 보고하지 않는다 — 서버가 캐릭터 복제 요청(ReplicationRequest)의 내용에서 직접 읽는다.
	-- 씬 이동은 서버가 승인한다: 클라이언트는 "이 씬으로 가고 싶다"고 요청만 하고, 서버가 지금 씬/포탈 위치를 검증해서
	-- TravelApproved로 승인해야 실제로 이동한다. 플레이어가 어느 씬에 있는지의 진실은 서버가 갖는다.
	RequestTravel = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf(scenes.TOWN, scenes.HUNTING_GROUND) },
		RateLimit = { PerSecond = 2, Burst = 3 },
	},
	-- 공격은 "바라보는 방향"(의도)만 보낸다. 공격 위치는 서버가 알고 있는 캐릭터 위치를 쓰고, 공격 간격도 서버가 검증한다.
	ReportHeroAttack = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("left", "right") },
		RateLimit = { PerSecond = 30, Burst = 12 },
	},
	EquipAction = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("Equip", "Unequip"), t.either(t.number, t.string) }, -- 동작, 인벤토리 슬롯 번호 또는 장비 슬롯 이름
		RateLimit = { PerSecond = 5, Burst = 5 },
	},
	GetPlayerData = {
		Kind = "Function",
		Direction = "ClientToServer",
		Args = {},
		RateLimit = { PerSecond = 3, Burst = 8 },
	},

	-- ===== 서버 -> 클라이언트 =====
	-- 체력은 서버가 소유한다. 서버가 계산한 결과를 알려줄 뿐 클라이언트가 체력을 보고하지 않는다.
	-- 다른 플레이어의 (더는 유효하지 않은) 캐릭터 사본을 지우라는 통지: userId, objectId. 씬을 옮기거나 캐릭터를 새로 만든 플레이어의 옛 사본이 남는 유령을 막는다.
	RemoveReplicated = { Kind = "Event", Direction = "ServerToClient", Doc = "userId, objectId" },
	TravelApproved = { Kind = "Event", Direction = "ServerToClient", Doc = "destinationSceneName" },
	PlayerHealthChanged = { Kind = "Event", Direction = "ServerToClient", Doc = "health, maxHealth, damage, died" },
	MonsterDespawned = { Kind = "Event", Direction = "ServerToClient", Doc = "monsterId" },
	InventoryUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "{ {Slot, ItemId, Count} }" },
	StatsUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "level, experience, maxExperience, leveledUp" },
	ItemAcquired = { Kind = "Event", Direction = "ServerToClient", Doc = "itemId, count" },
	EquipmentUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "{ Weapon=ItemId?, Armor=ItemId? }" },
	GoldUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "gold" },
}

return packets
