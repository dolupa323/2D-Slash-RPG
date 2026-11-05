-- 「달의 계승자」 — 보스 주화 장비 · 최초 격파(2026-11-05).
--  사용자: "퍼클 이벤트도 들어가야해 최초 격파 3 파티까지야 3인이 아니고 3파티 퍼클 칭호 깨자마자 바로 지급되어야하고, 전 서버에 메시지 송출된다 누구,누구, 누구가 잡았다고
--   그리고 보상 설계도 … 메이플 스우, 데미안처럼 150제 장비를 만들수있는 코어를 드롭할거고 … 사냥하면 나오는 보조 코어랑 보스잡아서 나오는 코어랑 합쳐서 코인을 만들고 그걸로 150제 장비를 구할수 있는거야"
--  보는 것: ① 자료(화심 세트 — 핵 둘 · 주화 · 장비 아홉: 무기 다섯(직업마다) · 방어구 넷 — Lv.150 · 빼어난) · 용암 거인의 보상에 심장핵 · 숯돌 = coinshop
--   ② 벼리기(심장핵 1 + 불씨핵 20 → 주화 1 · 모자라면 까닭) · 교환(주화 → 내 직업의 무기 · 방어구 — 남의 직업 무기는 아니다) · 받은 장비가 맞는 꼴 · 제 그림 · 이름
--   ③ 경매장: 심장핵 · 주화 · 화심 장비는 못 올린다 · 불씨핵은 올린다
--   ④ 불씨핵 = 화산 기슭 · 갈라진 비탈 · 분화구 가장자리의 몬스터만(약 2%) · 다른 떨어지는 것의 흐름은 그대로 · 다른 맵 · 보스는 아니다
--   ⑤ 최초 격파의 셈(sim/firstClear.luau): 세 파티까지 · 이미 기록에 있는 사람이 섞인 파티는 아니다 · 이름들
--   ⑥ 서버의 흐름(World.firstClear → server modules/firstClear.luau): 자리를 얻으면 그 자리에서 칭호 · 이 서버의 모두에게 FirstClear(차례 · 이름들) · 기록에 없는 캐릭터의 칭호는 뺀다
local TICK = 1 / 20
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local BossCoin = req("ReplicatedStorage/shared/lune/sim/bosscoin")
local Market = req("ReplicatedStorage/shared/lune/sim/market")
local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")
local FirstClear = req("ReplicatedStorage/shared/lune/sim/firstClear")
local Titles = req("ReplicatedStorage/shared/lune/sim/titles")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")

-- ---- ① 자료 ----
local set = BossCoin.set("fireheart")
expect(set ~= nil and set.boss == "lavagiant" and set.npc == "firesmith", "화심 세트 = 용암 거인 · 숯돌")
eq(Items.data.NPCDO.firesmith, "coinshop", "숯돌 = 숯돌의 화로")
for _, id in { set.core, set.sub.id, set.coin.id } do
	local g = Items.goods(id)
	expect(g ~= nil and g.tab == "etc", "기타 아이템 " .. id)
end
eq(set.coin.core, 1, "주화 = 심장핵 하나")
eq(set.coin.sub, 20, "+ 불씨핵 스물(메이플의 앱솔랩스 코인처럼)")
local all = BossCoin.gear(set, nil)
eq(#all, 25, "장비 스물다섯(부위 다섯 x 직업 다섯 — 무기 · 방어구 모두 직업 전용: 2026-11-05)")
local weapons, armor = 0, 0
for _, u in all do
	eq(u.stage, 150, u.name .. " — Lv.150")
	expect(u.bound == true and u.icon ~= nil and u.cost > 0 and u.who ~= nil and u.roll == true, u.name .. " — 교환 불가 · 제 그림 · 값 · 직업 · 성능을 굴린다")
	if u.slot == "weapon" then
		weapons += 1
		eq(u.cost, 5, "무기 = 주화 5")
	else
		armor += 1
		eq(u.cost, 2, "방어구 = 주화 2")
	end
end
expect(weapons == 5 and armor == 20, "무기 다섯 · 방어구 스물(직업마다 넷)")
eq(#BossCoin.gear(set, "riven"), 5, "리븐에게 보이는 것 = 제 무기 하나 + 제 방어구 넷")
for _, u in BossCoin.gear(set, "mooni") do
	eq(u.who, "mooni", "무니에게 보이는 것은 모두 무니의 것 — " .. u.name)
end
local lava = Weekly.boss("lavagiant")
local heartPay = nil
for _, g in lava.pay.normal.goods do
	if g.id == set.core then
		heartPay = g
	end
end
expect(heartPay ~= nil and heartPay.n == 1, "용암 거인의 보상에 심장핵 하나(받는 사람마다)")
expect(lava.first ~= nil and lava.first.parties == 3 and Titles.def(lava.first.title) ~= nil, "최초 격파 = 세 파티 · 칭호가 있다")
eq(Titles.def(lava.first.title).rule, "firstClear", "칭호의 규칙 = firstClear")

-- ---- ② 벼리기 · 교환 ----
local h = Hero.new(1, "riven")
h.level = 150
local why0 = BossCoin.canMake(h, set, 1)
expect(why0 ~= nil, "아무것도 없으면 벼리지 못한다: " .. tostring(why0))
Bag.give(h, set.core, 1)
Bag.give(h, set.sub.id, 19)
local why1 = BossCoin.canMake(h, set, 1)
expect(why1 ~= nil and string.find(why1, Items.goods(set.sub.id).name, 1, true) ~= nil, "불씨핵이 열아홉이면 모자란다 — 까닭에 그 이름: " .. tostring(why1))
Bag.give(h, set.sub.id, 1)
eq(BossCoin.maxMake(h, set), 1, "벼릴 수 있는 수 = 하나")
expect(BossCoin.make(h, "fireheart", 1) == true, "벼린다")
expect(Bag.count(h, set.core) == 0 and Bag.count(h, set.sub.id) == 0 and Bag.count(h, set.coin.id) == 1, "핵 둘이 빠지고 주화 하나")
local spear = BossCoin.gear(set, "riven")[1]
eq(spear.slot, "weapon", "리븐의 첫 줄 = 무기")
local _, wShort = BossCoin.buy(h, "fireheart", spear.id)
expect(wShort ~= nil, "주화 하나로는 무기를 못 산다: " .. tostring(wShort))
Bag.give(h, set.coin.id, 6)
local axeId = nil
for _, u in all do
	if u.who == "axion" and u.slot == "weapon" then
		axeId = u.id
	end
end
local _, wClass = BossCoin.buy(h, "fireheart", axeId, Random.new(1))
eq(wClass, "내 직업의 장비가 아니다", "남의 직업 무기는 바꾸지 못한다")
local got = BossCoin.buy(h, "fireheart", spear.id, Random.new(3))
expect(got ~= nil and got.u == spear.id and got.who == "riven" and got.stage == 150, "주화 다섯 → 화심 창")
expect(Items.valid(got), "받은 장비의 꼴이 맞다(저장 · 불러오기)")
local qn = Items.data.QUALITY[got.q].name
eq(Items.name(got), if got.q == Items.data.NORMAL then spear.name else qn .. " " .. spear.name, "이름 = (성능) 화심 창")
eq(Bag.count(h, set.coin.id), 2, "주화 일곱 - 다섯 = 둘")
local helm = nil
for _, u in BossCoin.gear(set, "riven") do
	if u.slot == "hat" then
		helm = u
	end
end
local gotHelm = BossCoin.buy(h, "fireheart", helm.id, Random.new(4))
expect(gotHelm ~= nil and Bag.count(h, set.coin.id) == 0, "주화 둘 → 화심 투구")
local wrong = table.clone(got)
wrong.who = "axion"
expect(not Items.valid(wrong), "직업이 바뀐 화심 창은 꼴이 틀렸다")
expect(Items.valid(gotHelm), "화심 투구의 꼴이 맞다")
eq(Items.classOf(gotHelm), "riven", "화심 투구(리븐)의 직업 = 리븐")
local hm = Hero.new(5, "mooni")
hm.level = 150
local okW, whyW = Bag.canWear(hm, gotHelm)
expect(not okW and whyW == "다른 직업의 장비다", "무니는 리븐의 화심 투구를 끼지 못한다 — " .. tostring(whyW))
expect(Bag.canWear(h, gotHelm), "리븐은 낀다")
-- 성능은 교환할 때 굴린다(사냥터 드롭과 같은 비율 — 낡은 10 · 허름한 20 · 보통 40 · 좋은 22 · 빼어난 8%)
do
	local seen = {}
	local rng = Random.new(11)
	local hb = Hero.new(6, "riven")
	hb.level = 150
	for _ = 1, 600 do
		Bag.give(hb, set.coin.id, 2)
		local it = BossCoin.buy(hb, "fireheart", helm.id, rng)
		if it then
			seen[it.q] = (seen[it.q] or 0) + 1
			Bag.dismantle(hb, it.id)
		end
	end
	local Q = Items.data.QUALITY
	for qi, q in Q do
		local n = seen[qi] or 0
		expect(n > 600 * q.pct / 100 * 0.5 and n < 600 * q.pct / 100 * 1.6, ("%s이 약 %d%%(600번에 %d)"):format(q.name, q.pct, n))
	end
end
-- 세기: 150제 18성 ≈ 140제 22성(무기 공격력 · 방어구 올스탯 — 2026-11-05 사용자 "140제 22성수치가 150제 18성정도로")
do
	local w150 = Items.makeUnique(spear.id, Items.data.NORMAL)
	w150.star = 18
	local w140 = Items.make("weapon", 140, Items.data.NORMAL, "riven")
	w140.star = 22
	local a, b = Items.options(w150).total.atk, Items.options(w140).total.atk
	expect(math.abs(a - b) / b < 0.02, ("무기: 150제 18성 %d ≈ 140제 22성 %d"):format(a, b))
	local h150 = Items.makeUnique(helm.id, Items.data.NORMAL)
	h150.star = 18
	local h140 = Items.make("hat", 140, Items.data.NORMAL)
	h140.star = 22
	local c, d = Items.options(h150).total.stat, Items.options(h140).total.stat
	expect(math.abs(c - d) / d < 0.02, ("방어구: 150제 18성 올스탯 %d ≈ 140제 22성 %d"):format(c, d))
	local s22 = Items.makeUnique(spear.id, Items.data.NORMAL)
	s22.star = 22
	expect(Items.options(s22).total.atk > b, "같은 22성이면 150제가 더 세다")
	eq(Items.sum({ w150 }).atk, a, "장착한 것의 합(Items.sum)도 같은 셈")
end
-- 세트 효과(보스 전리품 · 화심)
do
	local hs = Hero.new(7, "riven")
	local function u(id)
		return Items.makeUnique(id, Items.data.NORMAL)
	end
	local list = {}
	local fh = BossCoin.gear(set, "riven")
	eq(Items.setBonus({ u(fh[1].id) }).stat, 0, "화심 하나 = 세트 효과 없음")
	table.insert(list, u(fh[1].id))
	table.insert(list, u(fh[2].id))
	local b2 = Items.setBonus(list)
	local G = Items.gearSet("fireheart")
	expect(G ~= nil and b2.stat == (G.steps[1].stat or 0), "화심 둘 = 2세트(올스탯)")
	for i = 3, 5 do
		table.insert(list, u(fh[i].id))
	end
	local b5 = Items.setBonus(list)
	local want = { stat = 0, atk = 0, def = 0 }
	for _, st in G.steps do
		want.stat += st.stat or 0
		want.atk += st.atk or 0
		want.def += st.def or 0
	end
	expect(b5.stat == want.stat and b5.atk == want.atk and b5.def == want.def, ("화심 다섯 = 모든 단계(올스탯 +%d · 공격력 +%d · 방어력 +%d)"):format(want.stat, want.atk, want.def))
	expect(b5.atk > 0 and b5.atk < Items.options(list[1]).total.atk * 0.15, "너무 세지 않다(무기 공격력의 15% 아래)")
	local mixed = { u(fh[1].id), u(BossCoin.gear(set, "mooni")[2].id) }
	eq(Items.setBonus(mixed).stat, G.steps[1].stat, "직업이 달라도 같은 세트로 센다")
	local acc = { u("archer_eye"), u("vice_pauldron") }
	local A = Items.gearSet("bossacc")
	expect(A ~= nil and Items.setBonus(acc).stat == A.steps[1].stat, "보스 전리품 둘 = 2세트")
	table.insert(acc, u("thief_belt"))
	table.insert(acc, u("lava_ring"))
	local a4 = Items.setBonus(acc)
	expect(a4.stat > Items.setBonus({ u("archer_eye"), u("vice_pauldron"), u("thief_belt") }).stat, "넷이면 더")
	local plain = Items.sum({ u("archer_eye") }).stat
	local withSet = Items.sum({ u("archer_eye"), u("vice_pauldron") }).stat
	expect(withSet > plain * 2, "Items.sum에 세트 효과가 든다")
	local _ = hs
end

-- ---- ③ 경매장 ----
expect(Market.sellable({ item = set.core, n = 1 }) == nil, "심장핵은 경매장에 올리지 못한다")
expect(Market.sellable({ item = set.coin.id, n = 1 }) == nil, "주화도")
expect(Market.sellable(got) == nil, "화심 장비도")
expect(Market.sellable({ item = set.sub.id, n = 5 }) == true, "불씨핵은 올린다(사냥하는 사람이 판다)")

-- ---- ④ 불씨핵 드롭 ----
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Event = req("ReplicatedStorage/shared/lune/sim/event")
Event.clock = function()
	return 1798761600 -- 2027-01-01(이벤트 밖 — 사탕이 섞이지 않게)
end
local function embers(scene: string, boss: boolean?): (number, number)
	local room = Room.new(scene, SCENES.scenes[scene], Random.new(7))
	local hh = Hero.new(2, "axion")
	hh.weak = 0
	local mob = room.mobs[1]
	mob.boss = boss
	local n, other = 0, 0
	for _ = 1, 3000 do
		for _, d in room:lootFor(hh, mob) do
			if d.goods == set.sub.id then
				n += 1
			else
				other += 1
			end
		end
	end
	return n, other
end
for _, m in set.sub.maps do
	local n = embers(m)
	expect(n > 3000 * set.sub.pct / 100 * 0.55 and n < 3000 * set.sub.pct / 100 * 1.5, ("%s: 불씨핵 약 %d%%(3000마리에 %d)"):format(m, set.sub.pct, n))
end
eq((embers("r4a1")), 0, "다른 맵(외성 밖 들판)은 떨어뜨리지 않는다")
eq((embers("r3d1", true)), 0, "보스는 아니다")

-- ---- ⑤ 최초 격파의 셈 ----
local function party(...)
	local ms = {}
	for _, k in { ... } do
		table.insert(ms, { key = k, name = "n" .. k, class = "riven" })
	end
	return { at = 1, members = ms }
end
local l1, r1 = FirstClear.add(nil, party("a", "b"), 3)
expect(l1 ~= nil and r1 == 1, "첫 파티 = 1")
local lx, rx, wx = FirstClear.add(l1, party("b", "c"), 3)
expect(lx == nil and rx == nil and wx == "already", "이미 기록에 있는 사람이 섞이면 아니다")
local l2, r2 = FirstClear.add(l1, party("c"), 3)
local l3, r3 = FirstClear.add(l2, party("d", "e", "f", "g"), 3)
expect(r2 == 2 and r3 == 3, "둘째 · 셋째")
local _, r4, w4 = FirstClear.add(l3, party("h"), 3)
expect(r4 == nil and w4 == "full", "세 파티가 차면 끝")
eq(FirstClear.rankOf(l3, "e"), 3, "e = 셋째 파티")
eq(FirstClear.names(party("x", "y", "z")), "nx, ny, nz", "알림의 이름들 「A, B, C」")

-- ---- ⑥ 서버의 흐름 ----
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
local published = {}
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal(), IsStudio = function() return false end })
SERVICE("MessagingService", { PublishAsync = function(_, topic, data) table.insert(published, { topic = topic, data = data }) end, SubscribeAsync = function() end })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names, fcDisk = {}, {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end, rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	goldKingGet = function() return true, nil end, goldKingSettle = function(_, rec) return rec end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
	firstMaxGet = function() return nil end, firstMaxClaim = function(rec) return true, rec end,
	classFirstGet = function() return true, nil end, classFirstClaim = function(_, rec) return rec end,
	maxTenGet = function() return {} end, maxTenAdd = function() return {} end,
	firstClearGet = function(boss) return true, fcDisk[boss] or {} end,
	firstClearAdd = function(boss, entry, cap)
		local new, rank = FirstClear.add(fcDisk[boss], entry, cap)
		if new then
			fcDisk[boss] = new
		end
		return rank, fcDisk[boss] or {}
	end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local function run(seconds)
	for _ = 1, math.floor(seconds / TICK + 0.5) do
		World.tick(TICK)
	end
end
local function join(uid, name, cls)
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, cls)
	handlers.Chars(p, "enter", made.id)
	World.jump(p, "town")
	return p, World.session(p)
end
local function count(name, p)
	local n = 0
	for _, e in sent do
		if e.name == name and (p == nil or e.player == p) then
			n += 1
		end
	end
	return n
end
local function lastFirst(p)
	for i = #sent, 1, -1 do
		if sent[i].name == "FirstClear" and sent[i].player == p then
			return sent[i].args[1]
		end
	end
	return nil
end
local p1, s1 = join(7101, "달그림자", "riven")
local p2, s2 = join(7102, "수정바람", "axion")
local p3, s3 = join(7103, "은빛도끼", "mooni")
local p4, s4 = join(7104, "분홍불씨", "reaper")
local _p5, s5 = join(7105, "새벽별", "salamander")
local p6, s6 = join(7106, "구경꾼", "riven")
local Reveal = req("ReplicatedStorage/shared/lune/sim/reveal")
Reveal.at.lavagiant = Reveal.clock() - 1 -- (출현한 뒤처럼 — 모듈의 시계)
local boss = { id = "lavagiant", name = "용암 거인", first = { parties = 3, title = "fc_lavagiant" } }
eq(World.firstClear ~= nil, true, "World.firstClear가 있다")
local beforeTitle = count("TitleGot", p1)
World.firstClear(boss, { s1, s2 })
eq(#(fcDisk.lavagiant or {}), 1, "첫 파티가 세계 기록에 적혔다")
expect(s1.hero.titles.fc_lavagiant and s2.hero.titles.fc_lavagiant, "격파한 그 자리에서 칭호(둘 다)")
expect(count("TitleGot", p1) > beforeTitle, "칭호 알림(TitleGot)")
local news = lastFirst(p6)
expect(news ~= nil and news.n == 1 and news.max == 3 and news.boss == "용암 거인", "이 서버의 모두에게(같이 싸우지 않은 사람도) 「최초 격파 1/3 — 용암 거인」")
eq(news and news.names, "달그림자, 수정바람", "이름들")
expect(#published == 1 and published[1].topic == "LuneFirstClear", "다른 서버로 보냈다(MessagingService)")
expect(not s6.hero.titles.fc_lavagiant, "같이 싸우지 않은 사람은 칭호가 없다")
World.firstClear(boss, { s1, s3 })
eq(#fcDisk.lavagiant, 1, "기록에 있는 사람이 섞인 파티는 셈하지 않는다")
expect(not s3.hero.titles.fc_lavagiant, "그 파티의 새 사람도 받지 않는다")
World.firstClear(boss, { s3 })
World.firstClear(boss, { s4 })
eq(#fcDisk.lavagiant, 3, "셋째 파티까지")
eq(lastFirst(p6).n, 3, "알림 「3/3」")
expect(s3.hero.titles.fc_lavagiant and s4.hero.titles.fc_lavagiant, "둘째 · 셋째 파티도 칭호")
World.firstClear(boss, { s5 })
eq(#fcDisk.lavagiant, 3, "넷째 파티는 없다")
expect(not s5.hero.titles.fc_lavagiant, "넷째 파티는 칭호가 없다")
World.firstClear({ id = "lavagiant", name = "용암 거인", first = boss.first, dev = true }, { s5 })
eq(#fcDisk.lavagiant, 3, "퍼블리시하지 않은 보스(dev)는 셈하지 않는다")
-- 기록에 없는 캐릭터가 가진 칭호는 뺀다(Studio에서 시험한 것이 남지 않게)
Titles.give(s6.hero, "fc_lavagiant")
run(1.2)
expect(not s6.hero.titles.fc_lavagiant, "기록에 없는 사람의 「거인을 잠재운 자」는 빠진다")
expect(s1.hero.titles.fc_lavagiant, "기록에 있는 사람은 그대로")
local _ = p2
local __ = p3
local ___ = p4

-- ---- ⑦ 숯돌의 화로 창(client/lune/ui/coinWindow.luau)을 화면 없이 지어 본다 ----
local texts, buttons, icons = {}, {}, {}
local function frame(name)
	return { Name = name, Visible = true }
end
local COLOR = setmetatable({}, { __index = function(_, k)
	return k
end })
MOCK("Client/lune/ui/ui", {
	COLOR = COLOR,
	text = function(parent, value, x, y, width, opts)
		local t = { value = value, x = x, y = y, width = width, shown = true }
		function t.set(_, v)
			t.value = v
		end
		function t.color(_, c)
			t.tint = c
		end
		function t.show(_, on)
			t.shown = on
		end
		table.insert(texts, t)
		return t
	end,
	slot = function()
		return { frame = frame("Slot") }
	end,
	smallIcon = function()
		local l = { Visible = true }
		table.insert(icons, l)
		return l
	end,
	setWorldIcon = function(label, name)
		label.Visible = name ~= nil
		label.icon = name
	end,
	hit = function()
		return { Activated = { Connect = function() end } }
	end,
	button = function(parent, label, x, y, w, onClick, opts)
		local it = { frame = frame("Button"), text = label, x = x, w = w, click = onClick, enabled = true }
		function it.setEnabled(_, on)
			it.enabled = on
		end
		table.insert(buttons, it)
		return it
	end,
})
MOCK("Client/lune/ui/itemCell", {
	icon = function(it)
		local u = it.u and Items.unique(it.u)
		return if u then u.icon else "w_spear"
	end,
	color = function()
		return "gold"
	end,
	label = function(it)
		return Items.name(it)
	end,
})
MOCK("Client/lune/ui/itemDetail", { show = function() end, hide = function() end })
local CW = req("Client/lune/ui/coinWindow")
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
local cw, chh = CW.size()
eq(cw, Layout.COINSHOP.w, "창의 폭 = 공방의 치수")
local hb = Hero.new(3, "reaper")
hb.level = 150
Bag.give(hb, set.core, 1)
Bag.give(hb, set.sub.id, 25)
Bag.give(hb, set.coin.id, 3)
local bagView = { gear = {}, use = {}, etc = {}, equip = {} }
for i = 1, Bag.size(hb) do
	bagView.etc[i] = hb.etc[i]
end
local sentItem = {}
local ctx = {
	me = function()
		return { level = 150, class = "reaper" }
	end,
	bag = function()
		return bagView
	end,
	send = function(...)
		table.insert(sentItem, { ... })
	end,
	ui = {},
}
local okB, view = pcall(CW.build, frame("Body"), ctx, cw, chh, "fireheart")
expect(okB, "창을 짓는다 " .. tostring(view))
if okB then
	view.refresh()
	eq(buttons[1].text, BossCoin.WORDS.make, "첫 줄 = 벼리기")
	expect(buttons[1].enabled, "심장핵 1 · 불씨핵 25 → 벼리기가 켜진다")
	buttons[1].click()
	expect(sentItem[1] and sentItem[1][2] == "coinMake" and sentItem[1][3] == "fireheart", "벼리기 = 서버에 coinMake(세트)")
	local names = {}
	for _, t in texts do
		if t.shown and typeof(t.value) == "string" then
			names[t.value] = true
		end
	end
	expect(names["화심 낫"] and not names["화심 창"], "리퍼에게는 화심 낫(남의 무기는 보이지 않는다)")
	expect(names["화심 투구"] and names["화심 장화"], "방어구 넷")
	expect(not buttons[2].enabled, "주화 셋으로는 무기(5)를 못 바꾼다")
	expect(buttons[3].enabled, "주화 셋으로 방어구(2)는 바꾼다")
	for _, t in texts do
		if t.width then
			expect((t.x or 0) + t.width <= cw + 1, "글은 창의 폭 안: " .. tostring(t.value))
		end
	end
	for _, b in buttons do
		expect(b.x + b.w <= cw + 1, "단추는 창의 폭 안")
	end
	view.destroy()
end
