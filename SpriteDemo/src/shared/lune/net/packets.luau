-- 「달의 계승자」의 네트워크 패킷 정의(단 하나의 출처). 짜임은 shared/net/packets.luau와 같다.
--  Direction: "ClientToServer" / "ServerToClient" · Kind: "Event" / "Function"
--  Args · RateLimit은 ClientToServer만 — net.luau가 인자 형식과 빈도를 검사한 뒤에야 핸들러를 부른다.
--  원칙: 클라이언트는 "하고 싶다"만 보낸다. 체력 · 경험치 · 돈 · 졸개 · 떨어진 것의 진실은 서버가 갖는다.
local t = {}

function t.number(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function t.string(value: any): boolean
	return typeof(value) == "string" and #value <= 64
end

function t.dir(value: any): boolean
	return value == 1 or value == -1
end

function t.table(value: any): boolean
	return typeof(value) == "table"
end

function t.any(_value: any): boolean
	return true -- 꼴은 받는 쪽이 본다(없어도 된다)
end

local packets = {
	-- ===== 클라이언트 → 서버 =====
	-- 들어와서 처음 한 번: 내 상태와 지금 방을 받는다. 돌려주는 값 { self, scene, x, y, room } — 캐릭터가 아직 없으면 { choose = true }
	Ready = { Kind = "Function", Direction = "ClientToServer", Args = {}, RateLimit = { PerSecond = 1, Burst = 3 } },
	-- 직업을 고른다(캐릭터가 없을 때만). 돌려주는 값은 Ready와 같다
	Choose = { Kind = "Function", Direction = "ClientToServer", Args = { t.string }, RateLimit = { PerSecond = 1, Burst = 2 } },
	-- 능력치에 점수를 찍는다(능력치 이름, 점수) · 남은 점수를 모두 주 능력치에
	StatAdd = { Kind = "Event", Direction = "ClientToServer", Args = { t.string, t.number }, RateLimit = { PerSecond = 10, Burst = 20 } },
	StatAuto = { Kind = "Event", Direction = "ClientToServer", Args = {}, RateLimit = { PerSecond = 2, Burst = 3 } },
	-- 스킬을 한 레벨 올린다(스킬 id) · 남은 포인트를 추천대로
	SkillUp = { Kind = "Event", Direction = "ClientToServer", Args = { t.string }, RateLimit = { PerSecond = 10, Burst = 20 } },
	SkillAuto = { Kind = "Event", Direction = "ClientToServer", Args = {}, RateLimit = { PerSecond = 2, Burst = 3 } },
	-- 물건을 다룬다: 하는 일(equip · unequip · dismantle · buy · enhance · transfer · restore · grow · storeIn · storeOut)과 그 대상 둘(번호 · 부위 · 수 등)
	Item = { Kind = "Event", Direction = "ClientToServer", Args = { t.string, t.any, t.any }, RateLimit = { PerSecond = 8, Burst = 12 } },
	-- 파티: 하는 일(invite · accept · decline · leave)과 대상(초대할 사람의 번호)
	Party = { Kind = "Event", Direction = "ClientToServer", Args = { t.string, t.any }, RateLimit = { PerSecond = 4, Burst = 6 } },
	-- 퀘스트: 하는 일(accept · complete · drop)과 퀘스트 id — 받기와 돌려주기는 그 주민 앞에서만
	Quest = { Kind = "Event", Direction = "ClientToServer", Args = { t.string, t.any }, RateLimit = { PerSecond = 4, Burst = 6 } },
	-- 바꾼 키를 저장한다 { [하는 일] = 키 이름 } — 꼴은 서버가 다시 본다
	Keys = { Kind = "Event", Direction = "ClientToServer", Args = { t.table }, RateLimit = { PerSecond = 2, Burst = 4 } },
	-- 퀵슬롯을 바꿨다: 칸들 전체 { "potion" · 스킬의 이름표 · false … } — 꼴과 놓아도 되는 스킬인지는 서버가 다시 본다. 돌려주는 값 = 서버가 가진 칸들(받아들였으면 보낸 것, 아니면 예전 것)
	Slots = { Kind = "Function", Direction = "ClientToServer", Args = { t.table }, RateLimit = { PerSecond = 4, Burst = 8 } },
	-- 스마트폰의 단추 배치를 바꿨다: 같은 꼴(칸들 전체) — PC의 퀵슬롯과 따로 저장한다. 돌려주는 값 = 서버가 가진 배치
	TouchSlots = { Kind = "Function", Direction = "ClientToServer", Args = { t.table }, RateLimit = { PerSecond = 4, Burst = 8 } },
	-- 내 자리(도트)와 보는 쪽. 움직임은 클라이언트가 셈하고 서버는 말이 되는지만 본다.
	Move = { Kind = "Event", Direction = "ClientToServer", Args = { t.number, t.number, t.dir }, RateLimit = { PerSecond = 20, Burst = 30 } },
	-- 문으로 다른 장면에 간다. 돌려주는 값 { scene, x, y, room } 또는 nil(문 앞이 아님)
	Travel = { Kind = "Function", Direction = "ClientToServer", Args = { t.string }, RateLimit = { PerSecond = 2, Burst = 3 } },
	-- 기술을 쓴다: 기술 id, 몇째 구간, 쓴 자리(x, y), 보는 쪽
	Skill = { Kind = "Event", Direction = "ClientToServer", Args = { t.string, t.number, t.number, t.number, t.dir }, RateLimit = { PerSecond = 8, Burst = 10 } },
	-- 떨어진 것을 줍는다(물건 번호)
	Pickup = { Kind = "Event", Direction = "ClientToServer", Args = { t.number }, RateLimit = { PerSecond = 10, Burst = 15 } },
	-- 확인용(Studio에서만 듣는다): "xp" 경험치를 준다 · "money" 달돈을 준다 · "hp" 체력을 정한다 · "reset" 캐릭터를 지운다(직업 고르기부터 다시)
	Debug = { Kind = "Event", Direction = "ClientToServer", Args = { t.string, t.number }, RateLimit = { PerSecond = 5, Burst = 5 } },
	-- 물약을 마신다
	Potion = { Kind = "Event", Direction = "ClientToServer", Args = {}, RateLimit = { PerSecond = 3, Burst = 3 } },

	-- ===== 서버 → 클라이언트 =====
	Self = { Kind = "Event", Direction = "ServerToClient", Doc = "내 상태(sim/hero.luau의 view)" },
	Snap = { Kind = "Event", Direction = "ServerToClient", Doc = "장면 이름, 졸개 목록 { id, x, dir, 상태, 상태가 된 뒤 흐른 시간, 체력 }" },
	Hits = { Kind = "Event", Direction = "ServerToClient", Doc = "누가(userId), 맞은 졸개 목록 { mob, dmg, hp, dead }" },
	Hurt = { Kind = "Event", Direction = "ServerToClient", Doc = "내가 맞았다 { dmg, hp, from, dead }" },
	Gain = { Kind = "Event", Direction = "ServerToClient", Doc = "경험치를 얻었다 { xp, ups, level }" },
	DropAdd = { Kind = "Event", Direction = "ServerToClient", Doc = "떨어진 것 { id, kind(money · gear · dust), amount, x, y, item }" },
	Heroes = { Kind = "Event", Direction = "ServerToClient", Doc = "장면 이름, 그 방 사람들의 자리 { id, x, y, dir, 살아 있는가 } — 초당 10번" },
	Who = { Kind = "Event", Direction = "ServerToClient", Doc = "장면 이름, 그 방 사람들의 이름표 { id, name, class, level } — 들고 날 때 · 레벨이 오를 때" },
	Act = { Kind = "Event", Direction = "ServerToClient", Doc = "다른 사람이 기술을 쓴다: 누구, 기술, 구간, x, y, 보는 쪽" },
	PartyInfo = { Kind = "Event", Direction = "ServerToClient", Doc = "내 파티 { leader, members = { { id, name, class, level, hp, maxHp, scene } … } } — 파티가 없으면 members가 비어 있다" },
	PartyAsk = { Kind = "Event", Direction = "ServerToClient", Doc = "파티 초대 { from, name } — 초대가 사라졌으면 from = false" },
	Quests = { Kind = "Event", Direction = "ServerToClient", Doc = "내 퀘스트의 상태 { [id] = { done, c = { 할 일마다의 수 } } } — 바뀔 때마다. 둘째 값 = 방금 끝낸 퀘스트의 id(없으면 nil)" },
	Bag = { Kind = "Event", Direction = "ServerToClient", Doc = "가방 · 장비 · 창고 · 달가루(sim/bag.luau의 view) — 바뀔 때마다" },
	ItemDone = { Kind = "Event", Direction = "ServerToClient", Doc = "물건을 다룬 결과 { action, ok, why, result }" },
	DropGone = { Kind = "Event", Direction = "ServerToClient", Doc = "물건 번호, 주운 사람(userId — 사라진 것이면 nil), 양" },
	Shot = { Kind = "Event", Direction = "ServerToClient", Doc = "화살 { id, x, y, dir, speed, range }" },
	ShotEnd = { Kind = "Event", Direction = "ServerToClient", Doc = "화살 번호" },
	Burst = { Kind = "Event", Direction = "ServerToClient", Doc = "폭탄병이 터짐 { mob, x, y }" },
	Revive = { Kind = "Event", Direction = "ServerToClient", Doc = "쓰러졌다가 마을에서 일어남 { scene, x, y, room }" },
}

return packets
