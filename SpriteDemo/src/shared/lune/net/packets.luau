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
	-- 들어와서 처음 한 번: 캐릭터 고르기 화면에 놓을 것 { select = { chars = { { id, name, class, level } … }, max, last } }.
	--  이미 캐릭터로 들어가 있으면(다시 물었을 때) 내 상태와 지금 방 { self, scene, x, y, room … }
	Ready = { Kind = "Function", Direction = "ClientToServer", Args = {}, RateLimit = { PerSecond = 1, Burst = 3 } },
	-- 캐릭터 고르기 화면의 일(하는 일, 대상 둘): check(이름) · create(이름, 직업) · name(번호, 이름) · delete(번호, 이름) · enter(번호) · leave()
	--  돌려주는 값: { ok, why, select … } — enter는 Ready의 뒤쪽과 같은 것(내 상태와 방). server/lune/modules/world.luau의 onChars
	Chars = { Kind = "Function", Direction = "ClientToServer", Args = { t.string, t.any, t.any }, RateLimit = { PerSecond = 2, Burst = 5 } },
	-- 명예의 전당: 순위판 셋의 위 열 줄 { level = { { name, class, value } … }, power = …, robux = … }
	Rank = { Kind = "Function", Direction = "ClientToServer", Args = {}, RateLimit = { PerSecond = 1, Burst = 3 } },
	-- 능력치에 점수를 찍는다(능력치 이름, 점수) · 남은 점수를 모두 주 능력치에
	StatAdd = { Kind = "Event", Direction = "ClientToServer", Args = { t.string, t.number }, RateLimit = { PerSecond = 10, Burst = 20 } },
	StatAuto = { Kind = "Event", Direction = "ClientToServer", Args = {}, RateLimit = { PerSecond = 2, Burst = 3 } },
	-- 스킬을 한 레벨 올린다(스킬 id) · 남은 포인트를 추천대로
	SkillUp = { Kind = "Event", Direction = "ClientToServer", Args = { t.string }, RateLimit = { PerSecond = 10, Burst = 20 } },
	SkillAuto = { Kind = "Event", Direction = "ClientToServer", Args = {}, RateLimit = { PerSecond = 2, Burst = 3 } },
	-- 전직하며 받은 공짜 초기화를 쓴다(스킬 창의 「초기화」 — 찍은 스킬을 모두 되돌린다)
	SkillReset = { Kind = "Event", Direction = "ClientToServer", Args = {}, RateLimit = { PerSecond = 1, Burst = 2 } },
	StatReset = { Kind = "Event", Direction = "ClientToServer", Args = {}, RateLimit = { PerSecond = 1, Burst = 2 } }, -- 찍은 능력치를 모두 되돌린다(공짜 — 2026-10-21)
	Coupon = { Kind = "Function", Direction = "ClientToServer", Args = { t.string }, RateLimit = { PerSecond = 1, Burst = 2 } }, -- 쿠폰 번호를 적었다 → { ok, why?, pet? }(2026-10-21 · 서버 modules/cash.luau의 CashServer.coupon)
	-- 물건을 다룬다: 하는 일(equip · unequip · dismantle · buy · enhance · transfer · restore · grow · storeIn · storeOut)과 그 대상 둘(번호 · 부위 · 수 등)
	Item = { Kind = "Event", Direction = "ClientToServer", Args = { t.string, t.any, t.any, t.any, t.any }, RateLimit = { PerSecond = 8, Burst = 12 } },
	-- 파티: 하는 일(invite · accept · decline · leave)과 대상(초대할 사람의 번호)
	Party = { Kind = "Event", Direction = "ClientToServer", Args = { t.string, t.any }, RateLimit = { PerSecond = 4, Burst = 6 } },
	-- 퀘스트: 하는 일(accept · complete · drop)과 퀘스트 id — 받기와 돌려주기는 그 주민 앞에서만
	Quest = { Kind = "Event", Direction = "ClientToServer", Args = { t.string, t.any }, RateLimit = { PerSecond = 4, Burst = 6 } },
	-- 바꾼 키를 저장한다 { [하는 일] = 키 이름 } — 꼴은 서버가 다시 본다
	Keys = { Kind = "Event", Direction = "ClientToServer", Args = { t.table }, RateLimit = { PerSecond = 2, Burst = 4 } },
	-- 일일 의뢰: 하는 일(view 보기 · accept 받기 · turn 내기)과 지역 · 몇째 의뢰. 받기와 내기는 그 게시판 앞에서만.
	--  돌려주는 값 { ok, why, reward = { xp, money, dust, all, name }, view = sim/daily.luau의 view }
	Daily = { Kind = "Function", Direction = "ClientToServer", Args = { t.string, t.any, t.any }, RateLimit = { PerSecond = 4, Burst = 8 } },
	-- 출석(2026-10-15): "view" = 판 { view, fresh(오늘 처음 들어와 칸이 찼다 — 창을 한 번 띄운다) } · "claim" = 받지 않은 칸을 모두 받는다 { view, got, why }
	Attend = { Kind = "Function", Direction = "ClientToServer", Args = { t.string }, RateLimit = { PerSecond = 2, Burst = 4 } },
	-- 업적(2026-10-15): "view" = { view = { score, rows = { [id] = { have, need, st } } } } · "claim" id = 그 업적의 보상 · "all" = 받을 것을 모두 { view, got, why }
	Achieve = { Kind = "Function", Direction = "ClientToServer", Args = { t.string, t.any }, RateLimit = { PerSecond = 3, Burst = 6 } },
	-- 2편의 도시 생활(2026-10-16): "view" · "talk" 사람 · "gift" 사람, 선물 · "claim" 사람 · "read" 이야기 · "tome" 곳, % — 돌려주는 값 { ok, why, view, note } (server/lune/modules/world.luau의 onBond · 셈은 sim/bond.luau)
	Bond = { Kind = "Function", Direction = "ClientToServer", Args = { t.string, t.any, t.any }, RateLimit = { PerSecond = 6, Burst = 12 } },
	-- 수정 틈 토벌(2026-10-16): "view" · "enter" 단계 — 돌려주는 값 { ok, why, left, clears } (world.luau의 onRift · 셈은 sim/rift.luau)
	-- 탈것(2026-10-16): 그 사람(선장 · 뱃사공 · 승강장 일꾼 — 이름표) 앞에서 오른다 — 돌려주는 값 { ok, why, time, dest } (world.luau의 onSail · 셈은 sim/voyage.luau)
	Sail = { Kind = "Function", Direction = "ClientToServer", Args = { t.string }, RateLimit = { PerSecond = 2, Burst = 4 } },
	Rift = { Kind = "Function", Direction = "ClientToServer", Args = { t.string, t.any }, RateLimit = { PerSecond = 4, Burst = 8 } },
	-- 경매장(메이플 옥션 방식 — 메뉴에서 어디서나): "mine" 내 것(판매 · 완료 탭) · "browse" 분류의 목록과 시세(장부의 이름, 새로 고침) · "list" 올리기(탭, 칸, 수, { 개당 값, 시간 }) ·
	--  "buy" 사기(장부, 줄, 수, 본 값) · "settle" 내 것 하나(번호, "take" 수령 · "collect" 대금 수령 · "back" 취소 / 반환 · "relist" 재등록) · "all" 모두 받기
	--  돌려주는 값 { ok, why, msg, rows(목록) · trades(시세) · board, mine(내 것), used · max(판매 수), now } — server/lune/modules/world.luau의 onMarket · 셈은 sim/market.luau
	Market = { Kind = "Function", Direction = "ClientToServer", Args = { t.string, t.any, t.any, t.any, t.any }, RateLimit = { PerSecond = 3, Burst = 6 } },
	-- 유료 상품의 창(2026-10-20): "view" · "buy"(상품) · "take"(보관함의 줄) · "rename"(새 이름) — 산 것은 로블록스의 ProcessReceipt가 준다(server/lune/modules/cash.luau)
	Cash = { Kind = "Function", Direction = "ClientToServer", Args = { t.string, t.any }, RateLimit = { PerSecond = 3, Burst = 6 } },
	-- 소리 설정을 저장한다 { music = 0~10, sfx = 0~10, on = 켰는가 } — 꼴은 서버가 다시 본다(계정에 저장 — sim/account.luau의 setSound)
	Sound = { Kind = "Event", Direction = "ClientToServer", Args = { t.table }, RateLimit = { PerSecond = 4, Burst = 12 } },
	-- 퀵슬롯을 바꿨다: 칸들 전체 { "potion" · 스킬의 이름표 · false … } — 꼴과 놓아도 되는 스킬인지는 서버가 다시 본다. 돌려주는 값 = 서버가 가진 칸들(받아들였으면 보낸 것, 아니면 예전 것)
	Slots = { Kind = "Function", Direction = "ClientToServer", Args = { t.table }, RateLimit = { PerSecond = 4, Burst = 8 } },
	-- 스마트폰의 단추 배치를 바꿨다: 같은 꼴(칸들 전체) — PC의 퀵슬롯과 따로 저장한다. 돌려주는 값 = 서버가 가진 배치
	TouchSlots = { Kind = "Function", Direction = "ClientToServer", Args = { t.table }, RateLimit = { PerSecond = 4, Burst = 8 } },
	-- 내 자리(도트)와 보는 쪽. 움직임은 클라이언트가 셈하고 서버는 말이 되는지만 본다.
	Move = { Kind = "Event", Direction = "ClientToServer", Args = { t.number, t.number, t.dir }, RateLimit = { PerSecond = 20, Burst = 30 } },
	-- 문으로 다른 장면에 간다. 돌려주는 값 { scene, x, y, room } 또는 nil(문 앞이 아님)
	Travel = { Kind = "Function", Direction = "ClientToServer", Args = { t.string }, RateLimit = { PerSecond = 2, Burst = 3 } },
	-- 튜토리얼 「달빛 꿈」(2026-10-14): "done" n = 화면만 아는 n째 미션을 끝냈다(돌려주는 값 = 내 튜토리얼 상태) · "skip" = 꿈을 건너뛴다(이 계정의 캐릭터가 한 번 끝낸 뒤에만 — 돌려주는 값은 Travel과 같다)
	Tut = { Kind = "Function", Direction = "ClientToServer", Args = { t.string, t.any }, RateLimit = { PerSecond = 4, Burst = 6 } },
	-- 간이 포탈(2026-10-15): 사냥터 안의 그 포탈(id)로 짝의 자리에 간다 — 서버가 옮기고 Warp로 알린다(같은 맵 · 막 없이)
	Hop = { Kind = "Event", Direction = "ClientToServer", Args = { t.string }, RateLimit = { PerSecond = 2, Burst = 3 } },
	-- 퀘스트 연출(2026-10-15 — shared/lune/cine.luau): "on" = 장면이 시작됐다(그동안 맞지 않는다 — 90초 뒤 저절로 풀린다) · "off" = 끝났다 · "seen" id = 그 장면을 봤다(다시 틀지 않게 캐릭터에 적는다)
	Cine = { Kind = "Event", Direction = "ClientToServer", Args = { t.string, t.any }, RateLimit = { PerSecond = 4, Burst = 8 } },
	-- 기술을 쓴다: 기술 id, 몇째 구간, 쓴 자리(x, y), 보는 쪽
	Skill = { Kind = "Event", Direction = "ClientToServer", Args = { t.string, t.number, t.number, t.number, t.dir }, RateLimit = { PerSecond = 8, Burst = 10 } },
	-- 떨어진 것을 줍는다(물건 번호)
	Pickup = { Kind = "Event", Direction = "ClientToServer", Args = { t.number }, RateLimit = { PerSecond = 10, Burst = 15 } },
	-- 내 펫이 떨어진 것에 닿았다(물건 번호 — 2026-10-20). 서버가 펫을 꺼내 두었는지 · 영웅에게서 가까운지 · 주인을 확인하고 줍는다(펫은 0.3초에 하나)
	PetPick = { Kind = "Event", Direction = "ClientToServer", Args = { t.number }, RateLimit = { PerSecond = 6, Burst = 8 } },
	-- 확인용(Studio에서만 듣는다): "xp" 경험치를 준다 · "money" 달돈을 준다 · "hp" 체력을 정한다 · "reset" 캐릭터를 지운다(직업 고르기부터 다시)
	Debug = { Kind = "Event", Direction = "ClientToServer", Args = { t.string, t.number }, RateLimit = { PerSecond = 5, Burst = 5 } },
	-- 관리자의 시험용 명령(하는 일, 값 셋). 서버가 보낸 사람의 계정 번호로 관리자인지 올 때마다 다시 가린다 — 관리자가 아니면 아무 일도 하지 않고 nil(server/lune/modules/admin.luau)
	Admin = { Kind = "Function", Direction = "ClientToServer", Args = { t.string, t.any, t.any, t.any }, RateLimit = { PerSecond = 6, Burst = 10 } },
	-- 물약을 마신다
	Potion = { Kind = "Event", Direction = "ClientToServer", Args = { t.any }, RateLimit = { PerSecond = 3, Burst = 3 } }, -- 소비 아이템을 쓴다: 그 아이템의 이름표(안 주면 지금 마실 수 있는 가장 좋은 물약)

	-- ===== 서버 → 클라이언트 =====
	Self = { Kind = "Event", Direction = "ServerToClient", Doc = "내 상태(sim/hero.luau의 view)" },
	CashGot = { Kind = "Event", Direction = "ServerToClient", Doc = "유료 상품을 받았다(구매 보관함이 바뀌었다) — 상품 이름표(2026-10-20)" },
	Snap = { Kind = "Event", Direction = "ServerToClient", Doc = "장면 이름, 졸개 목록 { id, x, dir, 상태, 상태가 된 뒤 흐른 시간, 체력 }" },
	Hits = { Kind = "Event", Direction = "ServerToClient", Doc = "누가(userId), 맞은 졸개 목록 { mob, dmg, hp, dead, big, crit, proc(사출기 · 장치의 타), sx, sy(그것이 날아오는 자리), mark(표식의 남은 초) }" },
	Hurt = { Kind = "Event", Direction = "ServerToClient", Doc = "내가 맞았다 { dmg, hp, from, dead }" },
	Gain = { Kind = "Event", Direction = "ServerToClient", Doc = "경험치를 얻었다 { xp, ups, level }" },
	DropAdd = { Kind = "Event", Direction = "ServerToClient", Doc = "떨어진 것 { id, kind(money · gear · dust), amount, x, y, item }" },
	Heroes = { Kind = "Event", Direction = "ServerToClient", Doc = "장면 이름, 그 방 사람들의 자리 { id, x, y, dir, 살아 있는가 } — 초당 10번" },
	Who = { Kind = "Event", Direction = "ServerToClient", Doc = "장면 이름, 그 방 사람들의 이름표 { id, name, class, level } — 들고 날 때 · 레벨이 오를 때" },
	Buffs = { Kind = "Event", Direction = "ServerToClient", Doc = "방의 누군가에게 걸린 버프가 바뀌었다: 누구, { { id, t, dur, x, y } … }(건 차례) — 그 사람의 몸에 버프의 모습이 보인다" },
	Act = { Kind = "Event", Direction = "ServerToClient", Doc = "다른 사람이 기술을 쓴다: 누구, 기술, 구간, x, y, 보는 쪽, 모은 단계(힘 모으기 — 없으면 0)" },
	PartyInfo = { Kind = "Event", Direction = "ServerToClient", Doc = "내 파티 { leader, members = { { id, name, class, level, hp, maxHp, scene } … } } — 파티가 없으면 members가 비어 있다" },
	PartyAsk = { Kind = "Event", Direction = "ServerToClient", Doc = "파티 초대 { from, name } — 초대가 사라졌으면 from = false" },
	Quests = { Kind = "Event", Direction = "ServerToClient", Doc = "내 퀘스트의 상태 { [id] = { done, c = { 할 일마다의 수 } } } — 바뀔 때마다. 둘째 값 = 방금 끝낸 퀘스트의 id(없으면 nil)" },
	DailyView = { Kind = "Event", Direction = "ServerToClient", Doc = "일일 의뢰의 상태(sim/daily.luau의 view) — 잡은 수가 오를 때마다" },
	AchDone = { Kind = "Event", Direction = "ServerToClient", Doc = "새로 해낸 업적들의 id { … } — 화면 위의 띠 「업적 달성 · 이름」(2026-10-15)" },
	Voyage = { Kind = "Event", Direction = "ServerToClient", Doc = "배: { left = 닿기까지 초, dest } 갑판에 올랐다 · { arrived = 장면, dest } 닿았다(2026-10-16)" },
	RiftView = { Kind = "Event", Direction = "ServerToClient", Doc = "토벌의 방의 상태(sim/rift.luau의 view — 물결 · 남은 몬스터 · 시간 · 완료 · 실패, 2026-10-16)" },
	RiftPay = { Kind = "Event", Direction = "ServerToClient", Doc = "토벌 완료의 보상 { xp, money, dust, gear(장비의 꼴 · 없으면 nil), full(가방이 차서 장비를 못 받았다), none(오늘 보상을 다 받았다), left }" },
	BondView = { Kind = "Event", Direction = "ServerToClient", Doc = "2편의 도시 생활(sim/bond.luau의 view)과 알림 { kind = shard · quest · open, … } — 달조각을 주웠다 · 퀘스트로 호감도가 올랐다 · 모험의 서가 열렸다(2026-10-16)" },
	AttendNew = { Kind = "Event", Direction = "ServerToClient", Doc = "게임 중에 자정이 지나 출석 칸이 찼다 — 출석 창을 띄운다(2026-10-15)" },
	Bag = { Kind = "Event", Direction = "ServerToClient", Doc = "가방 · 장비 · 창고 · 달가루(sim/bag.luau의 view) — 바뀔 때마다" },
	ItemDone = { Kind = "Event", Direction = "ServerToClient", Doc = "물건을 다룬 결과 { action, ok, why, result }" },
	DropGone = { Kind = "Event", Direction = "ServerToClient", Doc = "물건 번호, 주운 사람(userId — 사라진 것이면 nil), 양" },
	Shot = { Kind = "Event", Direction = "ServerToClient", Doc = "화살 { id, x, y, dir, speed, range, kind(쏜 졸개의 종류 — 제 그림이 있는 것은 그 그림으로 날아간다) }" },
	MobCast = { Kind = "Event", Direction = "ServerToClient", Doc = "몬스터의 마법이 뜸 { id, kind(쓴 몬스터의 종류), x, y, dir(쓴 몬스터가 보던 쪽 — 앞으로 뻗는 마법은 그쪽으로 그린다) } — 그 종류의 마법 그림(cast)이 그 자리에서 한 번 돈다. 맞는 것은 서버가 예고 뒤에 따로 알린다(Hurt)" },
	ShotEnd = { Kind = "Event", Direction = "ServerToClient", Doc = "화살 번호" },
	Sold = { Kind = "Event", Direction = "ServerToClient", Doc = "경매장에 올린 내 물건이 팔렸다 { name(물건 이름), n(팔린 수) } — 획득 알림 한 줄 · 「경매」 단추의 점(2026-10-18)" },
	Elite = { Kind = "Event", Direction = "ServerToClient", Doc = "사냥터 정예가 나옴 { room(그 맵), mob(졸개 번호), kind, x · y(나온 자리 — 그 자리에 분홍 기운이 솟는다 · 높이 — 그 자리로 옮겨 그린다) } — 화면 위 가운데에 알림(2026-10-18)" },
	Burst = { Kind = "Event", Direction = "ServerToClient", Doc = "폭탄병이 터짐 { mob, x, y }" },
	Crystal = { Kind = "Event", Direction = "ServerToClient", Doc = "무니의 달 수정 { add = { { id, owner, x, y, life } … }, gone = { id … } }" },
	Dodge = { Kind = "Event", Direction = "ServerToClient", Doc = "내가 피했다(리븐의 날랜 몸)" },
	Return = { Kind = "Event", Direction = "ClientToServer", Args = {}, RateLimit = { PerSecond = 1, Burst = 3 }, Doc = "쓰러진 뒤 마을로 돌아간다(「마을로 돌아갈까요?」 상자의 단추) — 쓰러지고 조금 지난 뒤부터 받는다" },
	Raise = { Kind = "Event", Direction = "ServerToClient", Doc = "소생을 받아 그 자리에서 일어났다 { hp }" },
	Warp = { Kind = "Event", Direction = "ServerToClient", Doc = "서버가 내 자리를 바로잡는다: x, y — 너무 멀리 간 자리 보고를 받지 않았을 때(그대로 두면 서버가 아는 자리와 영영 어긋난다)" },
	Healed = { Kind = "Event", Direction = "ServerToClient", Doc = "체력을 되찾았다: 양(누군가의 회복 스킬 — 무니의 달빛 치유)" },
	Cool = { Kind = "Event", Direction = "ServerToClient", Doc = "스킬의 다시 쓰기가 바뀌었다: 스킬, 남은 초(0 = 바로 다시 쓴다 — 리븐의 종결이 적을 쓰러뜨렸다)" },
	Revive = { Kind = "Event", Direction = "ServerToClient", Doc = "쓰러졌다가 마을에서 일어남 { scene, x, y, room }" },
}

return packets
