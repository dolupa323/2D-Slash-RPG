-- 「달의 계승자」 — 달빛 상점의 공간 · 마을에서만(2026-10-21 사용자: "달빛상점은 메뉴탭 안에 숨어있는게 아니라, 장비 , 능력치처럼 빠른버튼으로 앞에 나와야하고
--  ui 처럼 열리는 방식이아니라 메이플스토리 캐시샵처럼 아예 무적공간으로 들어가버리는 형태여야합니다 … 캐시샵은 마을에서만 갈수있구요 경매장도 마을에서만 갈수있어야하구요").
--  보는 것: ① 마을인가(Town.is — 마을 · 작은 마을 · 마을 안의 건물은 그렇다, 사냥터 · 쉼터 · 사당 지하 · 꿈 · 배는 아니다)
--   ② 서버: 마을이 아니면 들어가지 못한다 · 쓰러졌으면 못 들어간다 · 들어가면 그 맵의 이름표에서 빠진다(다른 사람에게 사라진다) · 몬스터가 노리는 사람 목록에서도
--   ③ 안에서는 움직임 · 기술 · 줍기 · 물약 · 경매장을 받지 않는다 · 사는 것(buy)은 안에서만 ④ 나오면 들어간 자리(장면 · x · y)로 다시(Revive)
--   ⑤ 단추 줄에 「상점」(월드맵 자리) · 키 ` · 글이 칸에 들어간다
local Town = req("ReplicatedStorage/shared/lune/sim/town")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local BM = req("ReplicatedStorage/shared/lune/data/bm.generated")
local SP = BM.shop.space

-- ① 마을인가
for _, k in { "town", "ct", "port", "r1bv", "seat", "in_store", "in_forge", "ct_auction", "ct_store" } do
	expect(Town.is(k), "마을: " .. k)
end
for _, k in { "r1a1", "hunt", "dream", "in_cellar", "r1af", "ship_out", "rf1", "nowhere" } do
	expect(not Town.is(k), "마을이 아니다: " .. k)
end
expect(not Town.is(nil), "장면이 없으면 아니다")
for key in SCENES.homes do
	expect(Town.is(key), "돌아가는 곳(homes)은 모두 마을: " .. key)
end

-- ⑤ 단추 줄 · 키 · 글
local row = UI.layout.menu.row
expect(table.find(row, "cash") ~= nil, "단추 줄에 달빛 상점")
expect(table.find(row, "map") == nil, "월드맵은 단추 줄에서 빠지고(M 키 · 「메뉴」 안)")
eq(#row + 1, UI.layout.menu.max, "단추 줄 + 「메뉴」 = 여덟 칸")
eq(UI.layout.menu.labels.cash, "상점", "단추의 이름 「상점」")
local cashWin
for _, w in UI.windows do
	if w.id == "cash" then
		cashWin = w
	end
end
expect(cashWin and cashWin.key == "Backquote" and cashWin.menu == false, "달빛 상점의 키 `(메이플 캐시샵의 기본 키) · 「메뉴」 안이 아니다")
expect(SP.bg == "shop_bg.png" and SP.minLoad > 0 and SP.minLoad <= 1, "공간의 배경 그림 · 「…가는 중」을 보이는 시간(1초 안)")
for _, k in { "title", "leave", "loading", "back", "townOnly", "preview", "hint" } do
	expect(typeof(SP.words[k]) == "string" and #SP.words[k] > 0, "공간의 글: " .. k)
end
expect(not string.find(SP.words.leave, "다$"), "단추 「" .. SP.words.leave .. "」에 「~다」를 쓰지 않는다")

-- ②~④ 서버
local function json(v)
	if typeof(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = json(x)
	end
	return out
end
local disk = {}
local handlers, fired = {}, {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		table.insert(fired, { name = name, player = player, args = { ... } })
	end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("MessagingService", { PublishAsync = function() end, SubscribeAsync = function() end })
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local names = {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return json(disk[id]) end,
	saveAccount = function(id, value)
		disk[id] = json(value)
		return true
	end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id)
		if names[key] ~= nil and names[key] ~= id then
			return false
		end
		names[key] = id
		return true
	end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end,
	rankRaise = function() end,
	rankRemove = function() end,
	rankTop = function() return {} end,
	rankInfoSet = function() end,
	rankInfoGet = function() return nil end,
	rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, json(fn(nil)) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
local MWHY = req("ReplicatedStorage/shared/lune/sim/market").WHY
World.start()
local function enter(id: number, name: string, class: string)
	local p = { UserId = id, Name = "user" .. id, DisplayName = "user" .. id, attrs = {} }
	p.SetAttribute = function(self, k, v) self.attrs[k] = v end
	p.Kick = function() end
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, class)
	expect(made and made.ok, "캐릭터를 만든다 " .. name)
	expect(handlers.Chars(p, "enter", made.id) ~= nil, "들어간다 " .. name)
	return p, World.session(p)
end
local pa, sa = enter(9201, "상점손님", "axion")
local pb, sb = enter(9202, "옆손님", "riven")

local function whoOf(key)
	for i = #fired, 1, -1 do
		local f = fired[i]
		if f.name == "Who" and f.player == pb and f.args[1] == key then
			return f.args[2]
		end
	end
	return nil
end
local function hasMe(list)
	for _, w in list or {} do
		if w.id == sa.hero.id then
			return true
		end
	end
	return false
end

-- 마을 밖 · 꿈에서는 못 들어간다
sa.scene = "r1a1"
local r = handlers.Cash(pa, "enter")
expect(r and r.ok == false and r.why == SP.words.townOnly, "사냥터에서는 달빛 상점에 들어가지 못한다")
eq(sa.shop, nil, "(들어가지 않았다)")
sa.scene = "dream"
expect(handlers.Cash(pa, "enter").ok == false, "꿈(튜토리얼)에서도")
-- 마을: 둘이 같은 마을 · 같은 자리 근처
for _, s in { sa, sb } do
	s.scene = "town"
end
sa.hero.x, sa.hero.y = 300, 176
sa.hero.alive = false
expect(handlers.Cash(pa, "enter").ok == false, "쓰러졌으면 못 들어간다")
sa.hero.alive = true
expect(handlers.Cash(pb, "buy", "starter").ok == false, "밖에서는 사지 못한다(사는 것은 달빛 상점 안에서)")
table.clear(fired)
r = handlers.Cash(pa, "enter")
expect(r and r.ok == true and r.list ~= nil, "마을에서는 들어간다(상점의 지금 것을 같이 받는다)")
expect(sa.shop ~= nil, "들어가 있다")
local list = whoOf("town")
expect(list ~= nil and not hasMe(list), "같은 맵의 다른 사람 화면에서 사라진다")
expect(hasMe(nil) == false, "(목록 검사)")
-- 안에서는 받지 않는다
local x0 = sa.hero.x
handlers.Move(pa, x0 + 40, 176, 1)
eq(sa.hero.x, x0, "안에서는 움직임을 받지 않는다")
expect(handlers.Market(pa, "mine").why == MWHY.town, "안에서는 경매장을 쓰지 못한다")
expect(handlers.Skill(pa, "ax_slam", 1, x0, 176, 1) == nil, "기술을 받지 않는다")
expect(handlers.Pickup(pa, 1) == nil and handlers.PetPick(pa, 1) == nil, "줍지 않는다")
-- 다시 들어가도 그대로(한 번)
expect(handlers.Cash(pa, "enter").ok == true, "두 번 눌러도 그대로 안에")
-- 나온다: 들어간 자리로 다시(Revive)
table.clear(fired)
expect(handlers.Cash(pa, "leave").ok == true, "나온다")
eq(sa.shop, nil, "밖에 있다")
local revive
for _, f in fired do
	if f.name == "Revive" and f.player == pa then
		revive = f.args[1]
	end
end
expect(revive ~= nil and revive.scene == "town" and revive.x == x0 and revive.y == 176, "들어간 자리(초승달 마을 · 같은 x · y)로 다시")
expect(hasMe(whoOf("town")), "다른 사람 화면에 다시 보인다")
expect(handlers.Cash(pa, "leave").ok == true and sa.shop == nil, "밖에서 나오기는 아무 일도 아니다")
