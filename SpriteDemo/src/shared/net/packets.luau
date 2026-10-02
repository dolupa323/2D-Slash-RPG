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
		-- 목적지 씬 이름. 탑다운 씬이 여러 개라 이름 목록을 고정하지 않고, 실제로 갈 수 있는지는 서버 travelService가 포탈 위치로 검증한다.
		Args = { t.string },
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
	-- ===== 탑다운 씬(온라인 공유) =====
	-- 지금 씬의 몬스터·월드 드랍 전체 목록(씬에 들어왔을 때 한 번). 돌려주는 값: { scene, monsters, drops }
	GetTownState = {
		Kind = "Function",
		Direction = "ClientToServer",
		Args = {},
		RateLimit = { PerSecond = 2, Burst = 4 },
	},
	-- 기본 공격: 바라보는 방향만 보낸다(공격 동작의 판정 프레임에). 위치는 서버가 아는 위치, 간격도 서버가 검증한다.
	-- 펫(M3): 상자 번호에 대한 행동 — Add(함께 다니기) · Remove(상자로) · Lead(대표로 = 파티 1번) · Release(놓아주기, 사라짐)
	PetAction = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("Add", "Remove", "Lead", "Release"), t.number },
		RateLimit = { PerSecond = 6, Burst = 6 },
	},
	-- 소비 단축칸에 아이템 놓기(칸 번호 1~3, 아이템 id 또는 ""=비우기) — 서버가 소비 아이템인지 검사
	SetQuickSlot = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.number, t.string },
		RateLimit = { PerSecond = 6, Burst = 6 },
	},
	-- 소비 단축칸 쓰기(칸 번호, 바라보는 방향) — 물약: 회복 / 방울: 그 방향으로 던지기(포획 시도)
	UseQuickSlot = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.number, t.oneOf("up", "down", "left", "right") },
		RateLimit = { PerSecond = 6, Burst = 6 },
	},
	TownAttack = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("up", "down", "left", "right") },
		RateLimit = { PerSecond = 6, Burst = 6 },
	},
	-- 가방: 같은 탭 안에서 칸 옮기기(드래그 앤 드롭) — 탭, 보낸 칸, 받는 칸. 받는 칸에 아이템이 있으면 서로 바꾸고, 같은 아이템이면 합친다.
	MoveItem = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("Equip", "Use", "Etc", "Cash", "Key"), t.number, t.number },
		RateLimit = { PerSecond = 8, Burst = 10 },
	},
	-- 가방: 버리기(탭, 칸) → 서버가 가방에서 빼고 발밑에 월드 드랍으로 떨어뜨린다.
	DropItem = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("Equip", "Use", "Etc", "Cash", "Key"), t.number },
		RateLimit = { PerSecond = 3, Burst = 5 },
	},
	-- 가게(NPC 근처에서만 — 서버가 지금 씬의 그 가게 NPC와 거리를 확인): 사기(가게 id, 아이템, 개수) / 팔기(탭, 칸, 개수)
	ShopBuy = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.string, t.string, t.number },
		RateLimit = { PerSecond = 5, Burst = 6 },
	},
	ShopSell = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("Equip", "Use", "Etc", "Cash", "Key"), t.number, t.number },
		RateLimit = { PerSecond = 5, Burst = 6 },
	},
	-- 소비 아이템 사용(탭, 칸) — 물약: 서버가 체력을 회복하고 1개 줄인다(체력이 가득하면 안 쓴다).
	UseItem = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("Equip", "Use", "Etc", "Cash", "Key"), t.number },
		RateLimit = { PerSecond = 4, Burst = 4 },
	},
	-- 땅의 아이템 줍기(드랍 id) — 서버가 같은 씬·거리·가방 자리를 검증한다. 먼저 주운 사람이 가져간다.
	PickupDrop = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.number },
		RateLimit = { PerSecond = 5, Burst = 6 },
	},
	-- 치료사에게 회복 요청: 서버가 지금 씬에 치료사가 있고 플레이어가 그 가까이에 있는지 확인한 뒤 체력을 가득 채운다.
	RequestHeal = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = {},
		RateLimit = { PerSecond = 1, Burst = 2 },
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
	-- 탑다운 씬 공유 상태(같은 씬 플레이어에게만 보낸다 — 첫 인자는 항상 씬 키: 씬을 옮기는 순간 늦게 온 것은 버린다)
	TownMonsterMoves = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, { {id, x, y, facingLeft, moving} } (10Hz)" },
	TownMonsterSpawned = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, { id, row, level, hp, maxHp, x, y }" },
	TownMonsterHit = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, id, hp, damage, attackerUserId, source(무기 id | \"pet:<종 id>\")" },
	TownMonsterAttack = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, id — 몬스터가 반격하는 순간(연출용, 피해는 PlayerHealthChanged)" },
	TownMonsterDied = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, id" },
	WorldDropSpawned = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, { id, itemId, count, x, y, expiresIn }" },
	WorldDropRemoved = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, id, pickedByUserId?" },
	-- 도감: 처음 쓰러뜨린 몬스터(종류 줄 번호) — "새 친구!" 팝업 + 알림
	DexDiscovered = { Kind = "Event", Direction = "ServerToClient", Doc = "row" },
	-- 포획(M2): 방울 던지기(같은 씬 모두에게 날아가는 연출) / 맞은 몬스터의 포획 결과(연출 — 결과는 capture.RevealTime(딸랑 횟수) 뒤 적용)
	BellThrown = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, userId, x, y, dirX, dirY, distance, tier, hitMonsterId(0 = 빗나감)" },
	TownCapture = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, id, tier, result(\"success\"|\"fail\"|\"blocked\"), dings(딸랑 횟수 0~3)" },
	-- 펫 스킬 발동(M4, 같은 씬 모두에게 연출용 — 피해는 TownMonsterHit "pet:<종 id>", 회복은 PlayerHealthChanged). x, y = 대상 몬스터(없으면 주인 발) 위치(도트)
	PetSkill = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, ownerUserId, partySlot, speciesId, pattern, targetMonsterId(0 = 없음), x, y" },
	-- 펫 상자·파티가 바뀜(잡음·편성·놓아주기)
	PetsUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "{ Box, Party, Paid }" },
	-- 소비 단축칸 1·2·3(아이템 id, 빈 칸 = "")
	QuickSlotsUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "{ id1, id2, id3 }" },
	-- 짧은 알림(화면 위 토스트): 가방이 가득 찼어요 등
	Notify = { Kind = "Event", Direction = "ServerToClient", Doc = "text" },
}

return packets
