-- 「달의 계승자」 — 2편의 도시 생활(shared/lune/sim/bond.luau · sim/voyage.luau — 2026-10-16): 만나면 열림 · 배 · 모험의 서 · 달조각 · 숨은 이야기 · 「만나기」.
--  사용자 2026-10-16: "대도시에 쓸데없이 포탈만 이리저리로 복잡하게 만들고 전혀 대도시같지않아요 … 호감도는 왜만드는거고 왜 대도시로 넘어갈때 배타는건 구현을 안합니까 왜 그냥 포탈이에요"
--   → 은달 항구 = 한 장(건물은 문 안의 방) · 마을 ↔ 항구 = 선장에게 말을 걸어 배(갑판에서 시간을 보낸다) · 호감도를 빼고 「만나면 열림」.
--  보는 것: 자료(사람 · 방 · 배 · 선물이 없다) · 만나면 열림(처음 인사 → 그 기능) · 「항구의 첫날」의 만나기 다섯 · 달조각 · 숨은 이야기 · 모험의 서 · 저장 ·
--   서버의 흐름(인사 · 인사 전에는 토벌 · 의뢰가 닫혀 있다 · 배에 오른다 → 갑판 → 때가 되면 닿는다 · 돌아오는 배) · 모험의 서 창
local Bond = req("ReplicatedStorage/shared/lune/sim/bond")
local Voyage = req("ReplicatedStorage/shared/lune/sim/voyage")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local D = Bond.DATA
local V = Voyage.DATA
local function routeOf(id: string)
	for _, r in V.routes do
		if r.id == id then
			return r
		end
	end
	return nil
end
local TOWN_CT, CT_TOWN, CT_SEAT, CT_PORT = routeOf("town_ct"), routeOf("ct_town"), routeOf("ct_seat"), routeOf("ct_port")

local function npcIn(key: string, id: string)
	for _, n in (SCENES.scenes[key] or {}).npcs or {} do
		if n.id == id then
			return n
		end
	end
	return nil
end
local function standsSomewhere(id: string): string?
	for key, sc in SCENES.scenes do
		for _, n in sc.npcs or {} do
			if n.id == id then
				return key
			end
		end
	end
	return nil
end

-- ---- 1) 자료 ----
local meetN = 0
for id, m in D.meet do
	meetN += 1
	expect(typeof(m.opens) == "string" and #m.lines >= 2, "만나면 열리는 것과 인사의 말 " .. id)
	expect(Items.data.NPCDO[id] ~= nil, "만나면 기능이 열린다(NPCDO) " .. id)
	expect(standsSomewhere(id) ~= nil, "어딘가에 서 있다 " .. id)
end
eq(meetN, 5, "만나면 열리는 사람 다섯(대장장이 · 창고지기 · 경매사 · 의뢰 접수원 · 토벌대장)")
for id, f in D.folk do
	expect(standsSomewhere(id) ~= nil, "2편의 사람이 서 있다 " .. id)
	expect(f.likes == nil and f.talk == nil and f.rewards == nil, "호감도의 것(선물 · 단계의 말 · 보상)이 없다 " .. id)
end
expect(D.rapport == nil and D.gifts == nil, "호감도 · 선물의 자료가 없다(사용자 2026-10-16 \"호감도는 왜만드는거고\")")
for _, g in { "gift_flower", "gift_cookie", "gift_pin", "gift_coin" } do
	expect(Items.goods(g) == nil, "선물은 물건이 아니다 " .. g)
end
-- 은달 항구 = 한 장: 문은 방(건물) · 도시 밖으로만 · 방의 문은 도시로
local ct = SCENES.scenes.ct
expect(ct ~= nil and ct.w >= 120, "은달 항구는 한 장의 큰 맵")
for _, k in { "ct1", "ct2", "ct3", "ct4", "ct5", "ct6" } do
	expect(rawget(SCENES.scenes, k) == nil, "예전의 쪼갠 도시 맵이 없다 " .. k)
end
local rooms = 0
for _, p in ct.portals do
	local to = SCENES.scenes[p.to]
	expect(to ~= nil, "문이 닿는 곳이 있다 " .. p.to)
	if to and to.indoor then
		rooms += 1
		local back = false
		for _, q in to.portals do
			back = back or q.to == "ct"
		end
		expect(back, "방의 문은 도시로 " .. p.to)
	else
		expect(p.to == "r2t", "도시를 걸어 나가는 문은 성문(반달 나루) 하나 " .. p.to) -- 물마루 마을 · 등불 포구는 탈것(2026-10-16 밤)
	end
end
eq(rooms, 18, "건물 열여덟(사용자 2026-10-16 밤 「모든 건물」 — 테라스는 성 안의 문으로)")
-- 성: 홀 → 테라스(둘째 문) · 테라스의 문은 홀로 · 테라스에 경관
local castle, terrace = SCENES.scenes.ct_castle, SCENES.scenes.ct_terrace
local toTerrace, toHall = false, false
for _, q in castle.portals do
	toTerrace = toTerrace or q.to == "ct_terrace"
end
for _, q in terrace.portals do
	toHall = toHall or q.to == "ct_castle"
end
expect(toTerrace and toHall, "성의 홀 ↔ 테라스")
expect(terrace.vista ~= nil and typeof(terrace.vista.img) == "string" and terrace.vista.title == "은달 항구" and terrace.vista.x > 60 and terrace.vista.x < 324, "테라스의 경관(그림 · 이름 · ↑ 자리)")
expect(castle.vista == nil, "경관은 테라스에만")
-- 사람은 제 집 · 일터 안
for id, room in { cityhost = "ct_inn", nurung = "ct_inn", dolsoe = "ct_harbor", galmae = "ct_fisher", galgi = "ct_stable", dahong = "ct_spice", hangyeol = "ct_scribe", saebyeok = "ct_castle", solgae = "ct_tower" } do
	expect(npcIn(room, id) ~= nil and npcIn("ct", id) == nil, ("%s는 %s 안에(거리에는 없다)"):format(id, room))
end
expect(npcIn("ct_smith", "citysmith") and npcIn("ct_storage", "citykeeper") and npcIn("ct_auction", "auctioneer") and npcIn("ct_office", "clerk") and npcIn("ct_office", "warden"), "그 사람은 제 건물 안에")
-- 배
expect(V.time >= 5 and V.time <= 20, "바다를 건너는 시간 10초쯤(사용자 2026-10-16 \"배타는 시간 더 짧게 10초정도\") — " .. V.time)
eq(#V.routes, 6, "탈것 여섯(마을 ↔ 항구 배 · 항구 ↔ 물마루 마을 배 · 항구 ↔ 등불 포구 비행선)")
for _, r in V.routes do
	local ship = SCENES.scenes[r.ship]
	expect(ship ~= nil and ship.ship == true and #ship.portals == 0, "갑판(문이 없다) " .. r.ship)
	expect(npcIn(r.ship, r.npc) ~= nil, "갑판에 그 사람 " .. r.ship)
	expect(npcIn(r.from, r.npc) ~= nil, "떠나는 곳에 그 사람 " .. r.id)
	local back = nil
	for _, q in V.routes do
		if q.from == r.to and q.to == r.from and q.npc == r.npc then
			back = q
		end
	end
	expect(SCENES.scenes[r.to] ~= nil and back ~= nil, "닿는 곳에서 같은 사람이 돌아오는 길을 태운다 " .. r.id)
	local r2, from = Voyage.onShip(r.ship)
	expect(r2 == r and from == r.from, "갑판 → 그 탈것의 길 " .. r.ship)
	expect(#r.lines >= 1, "오를 때의 말 " .. r.id)
	expect(Voyage.route(r.from, r.npc) == r, "그 곳 · 그 사람 → 그 탈것 " .. r.id)
end
expect(CT_PORT.kind == "airship" and SCENES.scenes[CT_PORT.ship].ship, "꼭대기의 비행선(갑판)")
expect(npcIn("ct", "ferryman") and npcIn("ct", "skyhand") and npcIn("ct", "captain"), "은달 항구에 선장 · 뱃사공 · 승강장 일꾼")
for _, k in { "seat", "port" } do
	for _, q in SCENES.scenes[k].portals do
		expect(q.to ~= "ct", k .. "에서 은달 항구로 가는 문(포탈)이 없다 — 탈것으로")
	end
end
for key, sc in SCENES.scenes do
	if sc.region == "r1" or key == "town" then
		for _, p in sc.portals do
			expect(string.sub(p.to, 1, 2) ~= "ct", ("1지역에서 도시로 가는 문이 없다(배로만) %s → %s"):format(key, p.to))
		end
	end
end
eq(Voyage.leftText(TOWN_CT, 42.3), "은달 항구까지 43초", "위의 판의 글")
expect(Voyage.route("r1a1") == nil and Voyage.route("ship_out") == nil, "배가 없는 곳 · 갑판에서는 떠나는 배가 없다")
-- 달조각 · 숨은 이야기
for _, s in D.shards do
	local sc = SCENES.scenes[s.scene]
	expect(sc ~= nil and s.x > 8 and s.x < sc.w * 16 - 8 and s.y > 0 and s.y <= sc.h * 16, "달조각이 맵 안에 " .. s.id)
end
for _, st in D.stories do
	local sc = SCENES.scenes[st.scene]
	expect(sc ~= nil and #st.text >= 2, "숨은 이야기의 맵과 글 " .. st.id)
	for _, p in sc.portals do
		expect(math.abs(p.x - st.x) > 60 or math.abs(p.y - st.y) > 48, ("숨은 이야기가 문과 겹치지 않는다 %s · %s"):format(st.id, p.label))
	end
	for _, n in sc.npcs or {} do
		expect(math.abs(n.x - st.x) > 60 or math.abs(n.y - st.y) > 48, ("숨은 이야기가 주민과 겹치지 않는다 %s · %s"):format(st.id, n.id))
	end
end

-- ---- 2) 만나면 열림 ----
local h = Hero.new(54, "riven")
h.level = 35
local NOW = 1760000000
expect(Bond.isMeet("citysmith") and not Bond.isMeet("baram"), "대장장이는 만나는 사람 · 안내인은 아니다")
expect(not Bond.opened(h.bond, "citysmith"), "처음에는 닫혀 있다")
expect(Bond.opened(h.bond, "merchant") and Bond.opened(h.bond, "baram"), "만나는 사람이 아니면 늘 열려 있다")
eq(Bond.meet(h.bond, "citysmith"), true, "처음 인사")
expect(Bond.opened(h.bond, "citysmith"), "인사하면 열린다")
eq(Bond.meet(h.bond, "citysmith"), false, "두 번째는 처음이 아니다")
eq(Bond.meet(h.bond, "baram"), false, "만나는 사람이 아니면 아무 일도 없다")

-- ---- 3) 「항구의 첫날」: 만나기 다섯 → 모험의 서 ----
local h4 = Hero.new(57, "reaper")
h4.level = 30
h4.quests.r1m9 = { done = true, c = {} }
h4.quests.cq01 = { done = true, c = {} }
expect(Quests.accept(h4.quests, 30, "cq02"), "「항구의 첫날」을 받는다")
local cq02 = Quests.def("cq02")
local meets = 0
for _, st in cq02.steps do
	if st.type == "meet" then
		meets += 1
		expect(Bond.isMeet(st.npc), "만날 사람은 만나면 열리는 사람 " .. st.npc)
	end
end
eq(meets, #cq02.steps, "할 일이 모두 만나기")
eq(Quests.stepText(cq02.steps[1], 0), cq02.steps[1].name .. " 만나기", "만나기의 글(아직)")
eq(Quests.stepText(cq02.steps[1], 1), cq02.steps[1].name .. " 만나기 ✓", "만나기의 글(했다)")
local hint = Quests.stepHint(cq02, cq02.steps[1])
expect(string.find(hint, SCENES.scenes.ct_smith.name, 1, true) ~= nil, "길잡이는 그 사람이 선 건물을 적는다: " .. hint)
eq(#Quests.onMeet(h4.quests, "baram"), 0, "안내인은 만날 사람이 아니다")
for i = 1, #cq02.steps - 1 do
	eq(#Quests.onMeet(h4.quests, cq02.steps[i].npc), 1, "만났다 " .. cq02.steps[i].npc)
end
expect(not Quests.isReady(h4.quests, "cq02"), "아직 한 사람이 남았다")
eq(#Quests.onMeet(h4.quests, cq02.steps[1].npc), 0, "다시 만나도 그대로")
Quests.onMeet(h4.quests, cq02.steps[#cq02.steps].npc)
expect(Quests.isReady(h4.quests, "cq02"), "다섯을 다 만났다")
expect(not h4.bond.open, "아직 모험의 서가 없다")
local reward = Hero.questDone(h4, "cq02")
expect(reward ~= nil and h4.bond.open, "돌려주면 모험의 서가 열린다")

-- ---- 4) 달조각 · 숨은 이야기 · 몬스터 · 모험의 서 ----
local sh = D.shards[1]
eq(Bond.touchShard(h4.bond, sh.scene, sh.x + 40, sh.y), nil, "멀면 줍지 않는다")
eq(Bond.touchShard(h4.bond, sh.scene, sh.x + 5, sh.y), sh.id, "닿으면 줍는다")
eq(Bond.touchShard(h4.bond, sh.scene, sh.x, sh.y), nil, "한 번만")
local st = D.stories[1]
local first, w2 = Bond.read(h4.bond, st.id, st.scene, st.x + 200, st.y)
expect(first == nil and w2 ~= nil, "그 앞이 아니면 못 읽는다")
eq((Bond.read(h4.bond, st.id, st.scene, st.x, st.y)), true, "처음 읽었다")
eq((Bond.read(h4.bond, st.id, st.scene, st.x, st.y)), false, "다시 읽어도 된다(처음은 아니다)")
for _ = 1, 150 do
	Bond.onKill(h4.bond, "stump")
end
eq(h4.bond.kill.stump, D.tome.mobNeed, "몬스터는 모험의 서의 몫까지만 센다")
local cityArea = Bond.area(h4.bond, h4.quests, "city")
local r2Area = Bond.area(h4.bond, h4.quests, "r2")
expect(cityArea.parts.quest[1] >= 1 and cityArea.parts.shard[1] == 1, "은달 항구: 퀘스트 · 달조각이 찼다")
expect(cityArea.parts.rapport == nil, "모험의 서에 호감도의 칸이 없다")
eq(r2Area.parts.mob[1], 1, "수정 숲: 몬스터 한 종류")
expect(cityArea.pct >= 0 and cityArea.pct <= 100 and cityArea.total > 15, "은달 항구의 칸 수 " .. cityArea.total)
local okT, whyT = Bond.claimTome(h4, h4.quests, "city", 100)
expect(okT == nil and whyT ~= nil, "100%가 안 되면 못 받는다")
for _, sid in D.tome.areas[1].shards do
	h4.bond.shard[sid] = true
end
for _, sid in D.tome.areas[1].stories do
	h4.bond.story[sid] = true
end
local okT10 = Bond.claimTome(h4, h4.quests, "city", 10)
expect(okT10 ~= nil, "10%를 받는다 — " .. Bond.area(h4.bond, h4.quests, "city").pct .. "%")
expect(Bond.claimTome(h4, h4.quests, "city", 10) == nil, "두 번은 안 받는다")
Bond.meet(h4.bond, "warden")
local v = Bond.view(h4, NOW)
expect(v.open and v.tome[1].got["10"] == true and v.met.warden == true, "보낸 꼴: 받은 % · 만난 사람")
-- 저장
local back = Bond.unpack(Bond.pack(h4.bond))
expect(back.open and back.met.warden and back.shard[sh.id] and back.story[st.id] and back.kill.stump == D.tome.mobNeed and back.tome.city["10"], "저장했다 되살린다")
local bad = Bond.unpack({ pts = { baram = 50 }, met = { baram = true, warden = "yes", clerk = true }, shard = { nope = true }, kill = { stump = 9e9 } })
expect(bad.pts == nil and bad.met.baram == nil and bad.met.warden == nil and bad.met.clerk == true and next(bad.shard) == nil and bad.kill.stump == nil, "이상한 저장 · 예전 호감도는 버린다")
local hs = Hero.unpack(h4.id, Hero.pack(h4))
if hs then
	expect(hs.bond.open == true and hs.bond.met.warden == true, "캐릭터의 저장에 들어 있다")
end

-- ---- 5) 서버의 흐름 ----
local handlers, sent = {}, {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		table.insert(sent, { name = name, player = player, args = { ... } })
	end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
expect(handlers.Bond ~= nil and handlers.Sail ~= nil, "서버가 도시 생활 · 배를 듣는다")
local p = { UserId = 5401, Name = "길손5401", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
handlers.Ready(p)
local made = handlers.Chars(p, "create", "도시시험", "riven")
local entered = handlers.Chars(p, "enter", made.id)
expect(entered and entered.bond ~= nil, "들어오면 도시 생활의 꼴이 온다")
local s = World.session(p)
local hh = s.hero
hh.level = 35
local function sentOf(name: string)
	local out = {}
	for _, m in sent do
		if m.name == name then
			table.insert(out, m.args[1])
		end
	end
	return out
end
local TICK = 1 / 20
local function tickFor(sec: number)
	for _ = 1, math.floor(sec / TICK + 0.5) do
		World.tick(TICK)
	end
end
-- 배: 「불타는 마을」 전에는 태우지 않는다 → 끝낸 뒤 「탑승」 → 갑판 → 때가 되면 은달 항구의 부두
World.jump(p, "town")
local cap = npcIn("town", "captain")
expect(cap ~= nil, "마을의 포구에 선장")
hh.x, hh.y = cap.x + 200, cap.y
local res = handlers.Sail(p, "captain")
expect(res and res.ok == false, "선장 앞이 아니면 못 탄다")
hh.x, hh.y = cap.x + 10, cap.y
res = handlers.Sail(p, "captain")
expect(res and res.ok == false and res.why == TOWN_CT.locked, "「불타는 마을」 전에는 태우지 않는다")
hh.quests.r1m9 = { done = true, c = {} }
table.clear(sent)
res = handlers.Sail(p, "captain")
expect(res and res.ok and res.time == V.time, "배에 오른다")
eq(s.scene, TOWN_CT.ship, "갑판으로 옮겼다")
local vs = sentOf("Voyage")
expect(#vs == 1 and vs[1].left == V.time and vs[1].dest == TOWN_CT.dest, "화면에 「○○까지 n초」를 알린다")
res = handlers.Sail(p, "captain")
expect(res and res.ok == false, "갑판에서는 다시 오르지 못한다(선장은 말만 한다)")
tickFor(V.time - 2)
eq(s.scene, TOWN_CT.ship, "아직 바다 위")
table.clear(sent)
tickFor(3)
eq(s.scene, "ct", "때가 되어 은달 항구에 닿았다")
eq(hh.x, TOWN_CT.at[1] * SCENES.tile, "부두의 내리는 자리(가로)")
eq(hh.y, TOWN_CT.at[2] * SCENES.tile, "부두의 내리는 자리(세로)")
vs = sentOf("Voyage")
expect(#vs == 1 and vs[1].arrived == "ct", "닿았다고 알린다")
expect(#sentOf("Revive") >= 1, "화면이 그 장면으로 옮긴다")
expect(s.voyage == nil, "배의 기록을 지웠다")
-- 만나면 열림: 항구 의뢰소의 토벌대장
World.jump(p, "ct_office")
local warden = npcIn("ct_office", "warden")
hh.x, hh.y = warden.x + 10, warden.y
res = handlers.Rift(p, "enter", "rf1")
expect(res and res.ok == false and res.why == "먼저 인사를 나눠야 한다", "인사 전에는 토벌에 들어가지 못한다")
hh.x, hh.y = warden.x + 200, warden.y
res = handlers.Bond(p, "meet", "warden")
expect(res and res.ok == false, "멀면 인사하지 못한다")
hh.quests.cq01 = { done = true, c = {} }
hh.x, hh.y = warden.x + 10, warden.y
table.clear(sent)
res = handlers.Bond(p, "meet", "warden")
expect(res and res.ok and res.note and res.note.kind == "meet" and res.note.first == true and res.note.opens == D.meet.warden.opens, "그 앞이면 인사 → 열린다")
expect(hh.bond.met.warden == true and res.view.met.warden == true, "캐릭터의 기록 · 보낸 꼴")
res = handlers.Bond(p, "meet", "warden")
expect(res and res.ok and res.note.first == false, "두 번째 인사는 처음이 아니다")
res = handlers.Bond(p, "meet", "baram")
expect(res and res.ok == false, "만나는 사람이 아니면 인사가 없다")
res = handlers.Rift(p, "view")
expect(res ~= nil and res.left ~= nil, "토벌의 꼴")
-- 의뢰 접수원: 인사 전에는 의뢰를 받지 못한다
local clerk = npcIn("ct_office", "clerk")
hh.x, hh.y = clerk.x + 10, clerk.y
local dr = handlers.Daily(p, "accept", "r2", 1)
expect(dr and dr.ok == false and dr.why == "먼저 인사를 나눠야 한다", "인사 전에는 의뢰를 받지 못한다 — " .. tostring(dr and dr.why))
handlers.Bond(p, "meet", "clerk")
expect(hh.bond.met.clerk == true, "의뢰 접수원과 인사했다")
-- 「항구의 첫날」: 받기 전에 만난 사람도 센다(서버의 accept)
hh.quests.cq02 = nil
local okA = Quests.accept(hh.quests, hh.level, "cq02")
expect(okA, "「항구의 첫날」을 받는다(서버 밖)")
for npc in hh.bond.met do
	Quests.onMeet(hh.quests, npc)
end
local have = 0
for i, step in Quests.def("cq02").steps do
	if (hh.quests.cq02.c[i] or 0) >= step.n then
		have += 1
	end
end
eq(have, 2, "토벌대장 · 의뢰 접수원은 이미 만났다")
-- 달조각: 자리 보고로 줍는다(도시의 것)
local shc = nil
for _, x in D.shards do
	if x.scene == "ct" then
		shc = x
	end
end
if shc then
	table.clear(sent)
	World.jump(p, "ct")
	s.stale, s.jumped = nil, true -- (옮긴 직후의 늦은 보고 거르기를 끈다 — 화면이 연 뒤처럼)
	hh.x, hh.y = shc.x - 30, shc.y
	handlers.Move(p, shc.x, shc.y, 1)
	local found = false
	for _, m in sent do
		if m.name == "BondView" and m.args[2] and m.args[2].kind == "shard" and m.args[2].id == shc.id then
			found = true
		end
	end
	expect(found, "도시의 달조각을 주웠다(서버가 알린다)")
	expect(hh.bond.shard[shc.id] == true, "캐릭터의 기록에")
	eq(s.acct.ach.c.shard, 1, "업적: 달조각 한 개(계정)")
end
-- 숨은 이야기
local stc = nil
for _, x in D.stories do
	if x.scene == "ct" then
		stc = x
	end
end
if stc then
	World.jump(p, "ct")
	hh.x, hh.y = stc.x, stc.y
	res = handlers.Bond(p, "read", stc.id)
	expect(res and res.ok and res.note.first == true, "숨은 이야기를 읽었다")
	eq(s.acct.ach.c.story, 1, "업적: 숨은 이야기 하나")
	handlers.Bond(p, "read", stc.id)
	eq(s.acct.ach.c.story, 1, "두 번 읽어도 하나")
end
-- 돌아오는 배: 부두의 선장 → 갑판 → 초승달 마을(선장 곁)
World.jump(p, "ct")
local cap2 = npcIn("ct", "captain")
hh.x, hh.y = cap2.x + 10, cap2.y
res = handlers.Sail(p, "captain")
expect(res and res.ok, "부두에서 돌아오는 배에 오른다")
eq(s.scene, CT_TOWN.ship, "돌아오는 배의 갑판")
tickFor(V.time + 1)
eq(s.scene, "town", "초승달 마을에 닿았다")
expect(math.abs(hh.x - cap.x) <= 48, "포구의 선장 곁에 내린다")
-- 물마루 마을의 배 · 등불 포구의 비행선(2026-10-16 밤): 부두의 뱃사공 · 꼭대기의 승강장 일꾼
for _, r in { CT_SEAT, CT_PORT } do
	World.jump(p, "ct")
	local who = npcIn("ct", r.npc)
	hh.x, hh.y = who.x + 300, who.y
	res = handlers.Sail(p, r.npc)
	expect(res and res.ok == false, "그 사람 앞이 아니면 못 탄다 " .. r.id)
	hh.x, hh.y = who.x + 10, who.y
	res = handlers.Sail(p, r.npc)
	expect(res and res.ok and s.scene == r.ship, "오른다 " .. r.id)
	tickFor(V.time + 1)
	eq(s.scene, r.to, "닿았다 " .. r.id)
	local there = npcIn(r.to, r.npc)
	expect(there ~= nil and math.abs(hh.x - there.x) <= 48, "그 사람 곁에 내린다 " .. r.id)
	hh.x, hh.y = there.x + 10, there.y
	res = handlers.Sail(p, r.npc)
	expect(res and res.ok, "돌아오는 길 " .. r.id)
	tickFor(V.time + 1)
	eq(s.scene, "ct", "은달 항구로 돌아왔다 " .. r.id)
	expect(math.abs(hh.x - who.x) <= 48, "부두 · 꼭대기의 그 사람 곁 " .. r.id)
end
World.jump(p, "ct")
local fm = npcIn("ct", "ferryman")
hh.x, hh.y = fm.x + 10, fm.y
res = handlers.Sail(p, "captain")
expect(res and res.ok == false, "뱃사공 앞에서 선장의 배로는 못 탄다")
World.jump(p, "town")
-- 배 위에서 다른 길로 내리면(귀환 주문서 · 쓰러짐) 배의 기록이 사라진다
hh.x, hh.y = cap.x + 10, cap.y
handlers.Sail(p, "captain")
expect(s.voyage ~= nil, "다시 배 위")
World.jump(p, "town")
expect(s.voyage == nil, "다른 길로 내리면 배의 기록을 지운다")
tickFor(V.time + 1)
eq(s.scene, "town", "그 뒤에 배가 데려가지 않는다")
World.removePlayer(p)

-- ---- 6) 모험의 서 창(화면 없이) ----
local texts, buttons, tabs = {}, {}, {}
local function frame(name)
	local f = { Name = name, Visible = true, BackgroundTransparency = 0, ImageTransparency = 0 }
	function f:Destroy() end
	return f
end
local COLOR = setmetatable({}, { __index = function(_, k) return k end })
MOCK("Client/lune/ui/ui", {
	COLOR = COLOR,
	M = { small = 10, smallLine = 14, body = 12, button = 26 },
	measure = function(t) return #t * 3 end,
	text = function(_, value, x, y, width, opts)
		local t = { value = value, x = x, y = y, width = width, shown = true }
		function t.set(_, val) t.value = val end
		function t.color(_, c) t.tint = c end
		function t.move(_, nx, ny) t.x, t.y = nx, ny end
		function t.show(_, on) t.shown = on end
		table.insert(texts, t)
		return t
	end,
	group = function(_, x, y, w, hgt, name) return frame(name) end,
	box = function() return frame("Box") end,
	line = function() return frame("Line") end,
	slot = function() local it = { frame = frame("Slot"), on = false }; function it.setOn(_, on) it.on = on end; return it end,
	smallIcon = function(_, name) local f = frame("Icon"); f.icon = name; return f end,
	setWorldIcon = function(label, name) label.icon = name end,
	hit = function() return { Activated = { Connect = function() end } } end,
	button = function(_, label, x, y, w, fn, opts)
		local b = { frame = frame("Button"), label = label, click = fn, enabled = true }
		function b.setEnabled(_, on) b.enabled = on end
		function b.setText(_, val) b.label = val end
		table.insert(buttons, b)
		return b
	end,
	bar = function() local b = { frame = frame("Bar"), ratio = 0 }; function b.set(_, r) b.ratio = r end; function b.setColor(_, c) b.tint = c end; return b end,
	tab = function(_, label, x, y, fn) local t = { frame = frame("Tab"), label = label, click = fn, width = #label * 3, on = false }; function t.setOn(_, on) t.on = on end; table.insert(tabs, t); return t end,
	scroll = function() local sc = frame("Scroll"); sc.CanvasSize = UDim2.fromOffset(0, 0); sc.CanvasPosition = Vector2.new(0, 0); sc.ScrollingEnabled = true; sc.ScrollBarThickness = 3; return sc end,
})
local TomeWindow = req("Client/lune/ui/tomeWindow")
local tw, th = TomeWindow.size()
expect(th + 44 + 14 + 16 <= 432, ("모험의 서 창이 스마트폰의 화면 틀(432)에 들어간다 — %d"):format(th + 74))
local view4 = Bond.view(h4, NOW)
local ctx = {
	bond = function() return view4 end,
	bag = function() return Bag.view(h4) end,
	me = function() return { level = 35 } end,
	nearNpc = function() return true end,
	bondDo = function(action, a, b)
		return { ok = true, view = view4, note = { kind = action, reward = { money = 10 } } }
	end,
}
local tv = TomeWindow.build(frame("Body2"), ctx, tw, th)
local headShown, rapportShown = false, false
for _, t in texts do
	if typeof(t.value) == "string" then
		headShown = headShown or string.find(t.value, "모험의 서", 1, true) ~= nil
		rapportShown = rapportShown or string.find(t.value, "호감도", 1, true) ~= nil
	end
end
expect(headShown, "모험의 서의 머리글")
expect(not rapportShown, "창에 호감도의 글이 없다")
tv.refresh()
