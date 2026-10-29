-- 「달의 계승자」 — 기간 이벤트 「달빛 할로윈」(2026-10-29 — 공방 design/event.js · sim/event.luau · sim/room.luau의 lootFor · server world.luau의 EventTrade).
--  사용자: "할로윈 날짜 1주전후로 할로윈 이벤트 자동발동되게 할로윈 이벤트 만들고"
--  보는 것: ① 10월 24일 0시 ~ 11월 7일 23:59:59(한국 시간)에만 켜진다 · 해마다 ② 마을(집) 일곱에 호박 마녀(event) · 다른 맵에는 없다
--   ③ 켜져 있을 때만 사냥터의 보통 몬스터가 호박 사탕을 떨어뜨린다(보스 · 날파리는 아니다) · 다른 떨어지는 것의 흐름은 그대로
--   ④ 바꾸기: 사탕을 덜고 물약(내 레벨) · 주문서 · 칭호를 준다 · 모자라면 · 마녀 곁이 아니면 · 기간 밖이면 · 이미 받은 칭호면 안 된다 ⑤ 경매장에 올릴 수 없다
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Event = req("ReplicatedStorage/shared/lune/sim/event")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local E = Event.def("halloween")
expect(E ~= nil, "할로윈 이벤트가 있다")
-- 한국 시간의 그 날 그 시각(os.time은 세계 표준시)
local function kst(y, m, d, hh, mm, ss)
	-- 날짜 → 1970-01-01부터의 날 수(그레고리력 — 이 컴퓨터의 시간대와 상관없이)
	local yy = if m <= 2 then y - 1 else y
	local era = yy // 400
	local yoe = yy - era * 400
	local doy = (153 * ((m + 9) % 12) + 2) // 5 + d - 1
	local days = era * 146097 + yoe * 365 + yoe // 4 - yoe // 100 + doy - 719468
	return days * 86400 + hh * 3600 + mm * 60 + ss - 9 * 3600
end
-- (위의 셈이 맞는지: 한국 시간 2026-10-24 00:00 = 세계 표준시 2026-10-23 15:00)
local t24 = kst(2026, 10, 24, 0, 0, 0)
local u = os.date("!*t", t24)
eq(("%d-%d %d:%d"):format(u.month, u.day, u.hour, u.min), "10-23 15:0", "(한국 시간 10월 24일 0시 = 세계 표준시 10월 23일 15시)")

-- ① 기간
eq(Event.on("halloween", kst(2026, 10, 23, 23, 59, 59)), false, "10월 23일 23:59:59에는 꺼져 있다")
eq(Event.on("halloween", t24), true, "10월 24일 0시에 켜진다")
eq(Event.on("halloween", kst(2026, 10, 31, 12, 0, 0)), true, "10월 31일(할로윈)")
eq(Event.on("halloween", kst(2026, 11, 7, 23, 59, 59)), true, "11월 7일 23:59:59까지")
eq(Event.on("halloween", kst(2026, 11, 8, 0, 0, 0)), false, "11월 8일 0시에 꺼진다")
eq(Event.on("halloween", kst(2027, 10, 30, 9, 0, 0)), true, "해마다 저절로(2027년)")
eq(Event.on("halloween", kst(2027, 7, 1, 9, 0, 0)), false, "여름에는 꺼져 있다")
local a, b = Event.span(E)
eq(a .. " ~ " .. b, "10월 24일 ~ 11월 7일", "기간의 글")

-- ② 호박 마녀: 마을(집) 일곱에만
local homes, witches = {}, 0
for key in SCENES.homes do
	homes[key] = true
end
for key, sc in SCENES.scenes do
	for _, n in sc.npcs or {} do
		if n.id == "witch" then
			witches += 1
			expect(homes[key] == true, "호박 마녀는 마을(집)에만 — " .. key)
			eq(n.event, "halloween", "기간 이벤트의 주민 — " .. key)
		end
	end
end
local nHomes = 0
for _ in homes do
	nHomes += 1
end
eq(witches, nHomes, "마을(집)마다 하나")
eq(Event.npcOn({ event = "halloween" }, kst(2026, 12, 1, 0, 0, 0)), false, "기간 밖에는 서 있지 않다(화면이 세우지 않는다)")
eq(Event.npcOn({ id = "merchant" }, kst(2026, 12, 1, 0, 0, 0)), true, "다른 주민은 늘")

-- ③ 사탕
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local function lootCount(on: boolean, boss: boolean?)
	Event.clock = function()
		return if on then t24 + 3600 else kst(2026, 12, 1, 0, 0, 0)
	end
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(5))
	local h = Hero.new(1, "axion")
	h.weak = 0
	local mob = room.mobs[1]
	mob.boss = boss
	local candy, other = 0, 0
	for _ = 1, 2000 do
		for _, d in room:lootFor(h, mob) do
			if d.goods == E.candy.id then
				candy += 1
			else
				other += 1
			end
		end
	end
	return candy, other
end
local c1, o1 = lootCount(true)
local c0, o0 = lootCount(false)
expect(c1 > 2000 * E.candy.chance / 100 * 0.6 and c1 < 2000 * E.candy.chance / 100 * 1.4, ("켜져 있으면 사탕이 약 %d%%(2000마리에 %d)"):format(E.candy.chance, c1))
eq(c0, 0, "꺼져 있으면 사탕이 없다")
eq(o1, o0, "다른 떨어지는 것(장비 · 달가루 · 재료)의 흐름은 그대로 — 사탕은 따로 굴린다")
local cb = lootCount(true, true)
eq(cb, 0, "보스는 떨어뜨리지 않는다")
local g = Items.goods(E.candy.id)
expect(g ~= nil and g.tab == "etc" and g.kind == "event", "호박 사탕 = 기타 탭의 이벤트 물건")

-- ⑤ 경매장
local Market = req("ReplicatedStorage/shared/lune/sim/market")
local okM = Market.sellable({ item = E.candy.id, n = 5 })
expect(not okM, "호박 사탕은 경매장에 올릴 수 없다")

-- ④ 바꾸기(서버의 흐름)
local handlers = {}
local sent = {}
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
SERVICE("MessagingService", { PublishAsync = function() end, SubscribeAsync = function() end })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names, giftBox = {}, {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end,
	rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
	-- 관리자의 선물 상자(2026-10-29 — server/lune/modules/gifts.luau)
	giftAdd = function(uid, g) giftBox[uid] = giftBox[uid] or {}; table.insert(giftBox[uid], g); return true end,
	giftTake = function(uid, name)
		local mine, rest = {}, {}
		for _, g in giftBox[uid] or {} do
			table.insert(if g.name == name then mine else rest, g)
		end
		giftBox[uid] = rest
		return true, mine
	end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local p = { UserId = 11301, Name = "호박", DisplayName = "호박", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
handlers.Ready(p)
local made = handlers.Chars(p, "create", "호박사냥", "riven")
handlers.Chars(p, "enter", made.id)
World.wake(p)
local s = World.session(p)
Hero.setLevel(s.hero, 40, Hero.jobAt(40))
World.jump(p, "town")
local witch
for _, n in SCENES.scenes.town.npcs do
	if n.id == "witch" then
		witch = n
	end
end
s.trust, s.stale = true, nil
handlers.Move(p, witch.x + 200, witch.y, 1) -- 멀리(첫 자리 보고 — 들어섰다)
Event.clock = function()
	return t24 + 7200
end
Bag.give(s.hero, E.candy.id, 130)
local far = handlers.EventTrade(p, "halloween", "potion")
expect(far and not far.ok and far.msg == E.words.far, "호박 마녀 곁이 아니면 바꾸지 못한다")
s.trust = true
handlers.Move(p, witch.x + 4, witch.y, 1) -- 마녀 곁
local pot = Items.potionFor(40)
local before = Bag.count(s.hero, pot.id)
local r1 = handlers.EventTrade(p, "halloween", "potion")
expect(r1 and r1.ok, "물약을 산다 — " .. tostring(r1 and r1.msg))
eq(Bag.count(s.hero, E.candy.id), 120, "사탕 10개를 덜었다")
eq(Bag.count(s.hero, pot.id) - before, 20, "내 레벨(Lv.40)의 가장 좋은 물약 20개 — " .. pot.name)
expect(r1 and r1.view and r1.view.list ~= nil, "계정의 상점 상태를 함께 돌려준다(화면이 「보유」 · 산 수를 새로 그린다)")
local r2 = handlers.EventTrade(p, "halloween", "scroll")
expect(r2 and r2.ok and Bag.count(s.hero, "scroll_return") >= 5, "귀환 주문서 다섯 장")
-- 한정 탈것 · 펫 · 데미지 스킨(사용자: "한정 할로윈 라이딩, 한정 할로윈 펫(재까마귀 스펙), 할로윈 데미지스킨")
local c = s.acct.bm
local function item(id)
	return Event.item(E, id)
end
Bag.give(s.hero, E.candy.id, item("mount").cost + item("pet").cost + item("dskin").cost)
local have0 = Bag.count(s.hero, E.candy.id)
local rm = handlers.EventTrade(p, "halloween", "mount")
expect(rm and rm.ok and c.mounts.mount_wolf_hw == true, "한정 탈것 「호박불 늑대」가 계정에 — " .. tostring(rm and rm.msg))
local rp = handlers.EventTrade(p, "halloween", "pet")
expect(rp and rp.ok and c.pets.pet_bat_hw == true, "한정 펫 「아기 호박박쥐」가 계정에")
local rd = handlers.EventTrade(p, "halloween", "dskin")
expect(rd and rd.ok and c.dskins.dskin_halloween == true, "할로윈 데미지 스킨이 계정에")
eq(c.dskin, "dskin_halloween", "낀 스킨이 없었으면 바로 낀다")
eq(have0 - Bag.count(s.hero, E.candy.id), item("mount").cost + item("pet").cost + item("dskin").cost, "세 값만큼 사탕을 덜었다")
local again = handlers.EventTrade(p, "halloween", "mount")
expect(again and not again.ok and again.msg == E.words.once, "가진 탈것은 다시 사지 못한다")
-- 펫 = 재까마귀와 같은 일(떨어진 것을 줍는 펫 — 몬스터의 그림 · 펫의 배율)
local RIDE = req("ReplicatedStorage/shared/lune/data/ride.generated")
local batDef, crowDef
for _, q in RIDE.pets do
	if q.id == "pet_bat_hw" then
		batDef = q
	elseif q.id == "pet_crow" then
		crowDef = q
	end
end
expect(batDef ~= nil and batDef.free == "event" and crowDef ~= nil, "아기 호박박쥐 = 상점(로벅스)에서 팔지 않는 펫(사탕으로만)")
-- (이어서 사용자 "펫은 재까마귀 성능, 탈것도 로벅스 탈것보다는 살짝안좋아야해"): 펫의 줍기는 free가 있느냐로 갈린다(로벅스 펫만 빨아들인다 — server world.luau onPetPick · client rideView.luau RideView.sucks)
expect(batDef ~= nil and crowDef ~= nil and (batDef.free ~= nil) == (crowDef.free ~= nil) and crowDef.free ~= nil, "아기 호박박쥐의 줍기 = 아기 재까마귀(달려가서 줍는다 · 빨아들이지 않는다)")
local hwM, bookM
for _, m in RIDE.mounts do
	if m.id == "mount_wolf_hw" then
		hwM = m
	elseif m.id == "mount_book" then
		bookM = m
	end
end
expect(hwM ~= nil and typeof(hwM.speed) == "number" and hwM.speed < RIDE.mountSpeed and hwM.speed > (bookM and bookM.speed or 1), ("호박불 늑대 = 로벅스 탈것(%.1f배)보다 조금 느리고 걷기보다 빠르다(%s배)"):format(RIDE.mountSpeed, tostring(hwM and hwM.speed)))
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local bc, cc = CHARS.chars.pet_bat_hw, CHARS.chars.pet_crow
expect(bc ~= nil and cc ~= nil and bc.size == cc.size and bc.clips.idle ~= nil, "재까마귀처럼 몬스터의 서기 그림을 펫의 배율로(" .. tostring(bc and bc.size) .. ")")
-- 데미지 스킨: 가방의 캐시 탭에서 뺀다 · 다시 낀다(서버 Cash "dskin") · 방 사람들의 이름표(Who)에 실린다
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Format = req("ReplicatedStorage/shared/lune/ui/format")
local off = handlers.Cash(p, "dskin", false)
expect(off and off.ok and c.dskin == false, "데미지 스킨을 뺀다")
local on = handlers.Cash(p, "dskin", "dskin_halloween")
expect(on and on.ok and c.dskin == "dskin_halloween", "다시 낀다")
expect(on and on.dskin == "dskin_halloween" and on.dskins and on.dskins[1] == "dskin_halloween", "상점 상태에 가진 · 낀 스킨이 있다(캐시 탭의 줄)")
local bad = handlers.Cash(p, "dskin", "nope")
expect(bad and not bad.ok, "가지지 않은 스킨은 끼지 못한다")
local who = nil
for i = #sent, 1, -1 do
	local e = sent[i]
	if e.name == "Who" and e.player == p then
		who = e.args[2]
		break
	end
end
local mine = nil
for _, w in who or {} do
	if w.id == s.hero.id then
		mine = w
	end
end
eq(mine and mine.dskin, "dskin_halloween", "이름표(Who)에 낀 데미지 스킨")
local back = Cash.unpack(Cash.pack(c))
expect(back.dskins.dskin_halloween == true and back.dskin == "dskin_halloween", "저장되고 읽힌다")
-- 달가루 랜덤 상자(이어서 사용자 "달가루 상자는 더 비싸야해 쉽게 얻는게 아니라 … 엄청 조금줄수도 엄청 많이줄수도있는 랜덤박스로"): 계정에 limit번(이번 해의 할로윈)
local di = item("dust")
expect(di.cost >= 100, "비싸다 — 사탕 " .. di.cost .. "개(전에는 30)")
expect(typeof(di.roll) == "table" and #di.roll >= 4, "칸이 여럿")
local band = Cash.bandOf(Cash.topLevel(s.acct, s.hero.level))
local base = Event.dustBase(band)
local lo, q0 = Event.dustRoll(di, band, 0)
local hi, q1 = Event.dustRoll(di, band, 0.999999)
expect(q0.x <= 0.1 and q1.x >= 5, ("엄청 조금(%.2f배) ~ 엄청 많이(%.0f배)"):format(q0.x, q1.x))
expect(hi >= lo * 40, ("가장 적게 %d · 가장 많이 %d(그 레벨대 달가루 상자 %d)"):format(lo, hi, base))
expect(q1.big == true and q0.big ~= true, "가장 많은 칸만 화면 위 큰 알림")
local mean = 0
local wsum = 0
for _, q in di.roll do
	mean += q.x * q.w
	wsum += q.w
end
mean /= wsum
expect(mean < 1, ("평균은 상자 하나보다 적다(%.2f배)"):format(mean))
local seen = {}
for k = 1, 2000 do
	local _, q = Event.dustRoll(di, band, (k - 0.5) / 2000)
	seen[q.x] = (seen[q.x] or 0) + 1
end
eq(seen[q1.x], math.floor(2000 * q1.w / wsum + 0.5), "칸마다 무게대로 나온다(가장 많은 칸 " .. q1.w .. "/" .. wsum .. ")")
eq(Event.what(E, di, 40, band), E.words.dustWhat, "상점의 이름 「" .. E.words.dustWhat .. "」(양은 사는 순간 굴린다)")
Bag.give(s.hero, E.candy.id, di.cost * (di.limit + 1))
local d0 = s.hero.dust
for k = 1, di.limit do
	local before = s.hero.dust
	local r = handlers.EventTrade(p, "halloween", "dust")
	local got = s.hero.dust - before
	expect(r and r.ok and got >= lo and got <= hi, ("달가루 랜덤 상자 %d/%d — %d(%s)"):format(k, di.limit, got, tostring(r and r.msg)))
	expect(r and string.find(r.msg, Format.comma(got), 1, true) ~= nil, "알림에 받은 양 — " .. tostring(r and r.msg))
end
expect(s.hero.dust > d0, "달가루가 들어왔다(" .. (s.hero.dust - d0) .. ")")
local over = handlers.EventTrade(p, "halloween", "dust")
expect(over and not over.ok and over.msg == E.words.soldOut, "한도를 다 쓰면 「다 샀다」")
eq(c.ev[Event.countKey(E, di)], di.limit, "산 수가 계정에 적힌다")
expect(string.find(Event.countKey(E, di), "2026", 1, true) ~= nil, "올해의 할로윈으로 센다 — " .. Event.countKey(E, di))
-- 칭호
Bag.give(s.hero, E.candy.id, 100)
local r3 = handlers.EventTrade(p, "halloween", "title")
expect(r3 and r3.ok and s.hero.titles.pumpkin == true, "사탕 100개 → 칭호 「호박 수확자」")
local gotTitle = false
for _, e in sent do
	if e.name == "TitleGot" and e.player == p and table.find(e.args[1], "pumpkin") then
		gotTitle = true
	end
end
expect(gotTitle, "칭호를 받았다는 알림")
local r4 = handlers.EventTrade(p, "halloween", "title")
expect(r4 and not r4.ok and r4.msg == E.words.once, "칭호는 한 번만")
-- 능력치 초기화 주문서는 팔지 않는다(이어서 사용자 "능력치 초기화주문서는 왜팔아? 그냥 능력치초기화 그냥 풀려잇는데")
local sellsReset = false
for _, it in E.shop do
	if it.goods == "statreset" then
		sellsReset = true
	end
end
expect(not sellsReset, "상점에 능력치 초기화 주문서가 없다")
local r5 = handlers.EventTrade(p, "halloween", "reset")
expect(r5 and not r5.ok, "없는 물건은 사지 못한다")
Bag.take(s.hero, E.candy.id, Bag.count(s.hero, E.candy.id))
local r5b = handlers.EventTrade(p, "halloween", "potion")
expect(r5b and not r5b.ok and string.find(r5b.msg, "/" .. item("potion").cost, 1, true) ~= nil, "사탕이 모자라면 사지 못한다 — " .. tostring(r5b and r5b.msg))
-- 보스를 잡으면 사탕(사용자 "보스 잡아도 사탕좀 많이주고"): 켜져 있을 때만 보상의 방의 소비 아이템에 더한다
local bg = Event.bossGoods("hard")
expect(#bg == 1 and bg[1].id == E.candy.id and bg[1].n == E.boss.hard, "하드: 사탕 " .. E.boss.hard)
eq(Event.bossGoods("normal")[1].n, E.boss.normal, "노말: 사탕 " .. E.boss.normal)
Event.clock = function()
	return kst(2026, 11, 8, 0, 0, 1)
end
eq(#Event.bossGoods("hard"), 0, "기간이 지나면 보스의 사탕도 없다")
Bag.give(s.hero, E.candy.id, 100)
local r6 = handlers.EventTrade(p, "halloween", "potion")
expect(r6 and not r6.ok and r6.msg == E.words.off, "기간이 지나면 상점이 닫힌다")
local r7 = handlers.EventTrade(p, "nope", "potion")
expect(r7 and not r7.ok, "없는 이벤트")
-- ⑦ 관리 창 「이벤트」 탭의 사탕(사용자 "나 어드민 호박사탕 지급 탭 만들어주고"): 나에게 · 이 서버의 닉네임 · 접속하지 않은 닉네임(선물 상자 → 그 캐릭터로 들어올 때)
local notAdmin = handlers.Admin(p, "candy", "halloween", "", 100)
expect(notAdmin == nil or not notAdmin.ok, "관리자가 아니면 듣지 않는다")
local pa = { UserId = 10311679477, Name = "dolupa95", DisplayName = "dolupa95", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
handlers.Ready(pa)
local madeA = handlers.Chars(pa, "create", "할로시험", "axion")
handlers.Chars(pa, "enter", madeA.id)
World.wake(pa)
local sa = World.session(pa)
local a1 = handlers.Admin(pa, "candy", "halloween", "", 1000)
expect(a1 and a1.ok and Bag.count(sa.hero, E.candy.id) == 1000, "나에게 +1,000 — " .. tostring(a1 and a1.msg))
local a2 = handlers.Admin(pa, "candyClear", "halloween")
expect(a2 and a2.ok and Bag.count(sa.hero, E.candy.id) == 0, "모두 빼기 — " .. tostring(a2 and a2.msg))
local bad = handlers.Admin(pa, "candy", "halloween", "", 0)
expect(bad and not bad.ok, "수는 1부터")
local c0 = Bag.count(s.hero, E.candy.id)
table.clear(sent)
local a3 = handlers.Admin(pa, "candy", "halloween", "호박사냥", 100)
expect(a3 and a3.ok and Bag.count(s.hero, E.candy.id) - c0 == 100, "이 서버의 「호박사냥」에게 바로 +100 — " .. tostring(a3 and a3.msg))
local told = false
for _, ev in sent do
	if ev.name == "Megaphone" and ev.player == p and string.find(ev.args[1], "+100", 1, true) then
		told = true
	end
end
expect(told, "받는 사람의 화면 위 알림(운영자의 선물)")
local a4 = handlers.Admin(pa, "candy", "halloween", "없는닉네임", 100)
expect(a4 and not a4.ok, "없는 닉네임 — " .. tostring(a4 and a4.msg))
-- 접속하지 않은 사람: 선물 상자에 적힌다 → 그 캐릭터로 들어오면(첫 1초) 가방에
local Account = req("ReplicatedStorage/shared/lune/sim/account")
local pq = { UserId = 11399, Name = "다른이", DisplayName = "다른이", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
handlers.Ready(pq)
local madeQ = handlers.Chars(pq, "create", "사탕받이", "mooni")
World.removePlayer(pq) -- (캐릭터를 만들고 나갔다)
expect(names[Account.nameKey("사탕받이")] == 11399, "이름 장부에 있다")
local a5 = handlers.Admin(pa, "candy", "halloween", "사탕받이", 250)
expect(a5 and a5.ok and giftBox[11399] and #giftBox[11399] == 1 and giftBox[11399][1].n == 250, "접속하지 않은 사람 → 선물 상자 — " .. tostring(a5 and a5.msg))
handlers.Ready(pq)
handlers.Chars(pq, "enter", madeQ.id)
World.wake(pq)
local sq = World.session(pq)
table.clear(sent)
for _ = 1, 12 do
	World.tick(0.1)
end
eq(Bag.count(sq.hero, E.candy.id), 250, "그 캐릭터로 들어오니 가방에 사탕 250")
eq(#(giftBox[11399] or {}), 0, "선물 상자는 비었다")
local toldQ = false
for _, ev in sent do
	if ev.name == "Megaphone" and ev.player == pq then
		toldQ = true
	end
end
expect(toldQ, "들어오며 받은 알림")
for _ = 1, 12 do
	World.tick(0.1)
end
eq(Bag.count(sq.hero, E.candy.id), 250, "한 번만 받는다")
World.removePlayer(pq)
-- ⑧ 하드 보상의 방의 사탕(2026-10-30 사용자: "지금 하드보스 격파했는데 사탕 60개만준다는데?"): 상자에서 떨어진 사탕 덩이의 합 · 방이 닫힌 뒤 가방에 든 사탕
Event.clock = function()
	return t24 + 7200
end
local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")
Bag.take(sa.hero, E.candy.id, Bag.count(sa.hero, E.candy.id))
local rb = handlers.Admin(pa, "box", "hard")
expect(rb and rb.ok and Weekly.isBox(sa.scene), "관리 「보상의 방 · 하드」 — " .. tostring(rb and rb.msg))
local broom = World.room(sa.scene)
local chest = SCENES.scenes[sa.scene].chest
sa.hero.x, sa.hero.y = chest.x, chest.y
local ro = handlers.Week(pa, "open")
expect(ro and ro.ok, "상자를 연다 — " .. tostring(ro and (ro.why or ro.msg)))
local piles, sum = 0, 0
for _, d in broom.drops do
	if d.kind == "goods" and d.goods == E.candy.id then
		piles += 1
		sum += d.amount
	end
end
print(("[113] 하드 상자의 사탕: 덩이 %d · 합 %d(설계 %d)"):format(piles, sum, E.boss.hard))
do
	local xs = {}
	for _, d in broom.drops do
		table.insert(xs, ("%s%s@%d,%d"):format(d.kind == "goods" and d.goods == E.candy.id and "C" or d.kind:sub(1, 1), "", math.floor(d.x), math.floor(d.y)))
	end
	table.sort(xs)
	print("[113] 떨어진 자리(" .. #xs .. "): " .. table.concat(xs, " "), "방 폭", (SCENES.scenes[sa.scene].w or 0) * 16, "상자", chest.x, chest.y)
end
eq(sum, E.boss.hard, "하드 상자의 사탕 합 = " .. E.boss.hard)
World.boxSettle(broom)
eq(Bag.count(sa.hero, E.candy.id), E.boss.hard, "방이 닫히면 줍지 않은 사탕도 가방에(합 " .. E.boss.hard .. ")")
-- 실제 보스(불씨 도둑 두목 · 하드 — 물약 · 주문서 덩이까지 든 상자): 덩이를 하나씩 직접 주워 가방의 사탕을 센다
Bag.take(sa.hero, E.candy.id, Bag.count(sa.hero, E.candy.id))
local tk = World.openBoxFor({ sa }, "thiefboss", "hard", { [sa.hero.id] = true }, 1, nil)
local troom = World.room(tk)
local tchest = SCENES.scenes[tk].chest
sa.hero.x, sa.hero.y = tchest.x, tchest.y
local to = handlers.Week(pa, "open")
expect(to and to.ok, "도둑 두목 하드 상자를 연다 — " .. tostring(to and (to.why or to.msg)))
local ids, cand, total = {}, 0, 0
for id, d in troom.drops do
	table.insert(ids, id)
	total += 1
	if d.kind == "goods" and d.goods == E.candy.id then
		cand += d.amount
	end
end
table.sort(ids)
local fails = {}
for _, id in ids do
	local d = troom.drops[id]
	if d then
		sa.hero.x, sa.hero.y = d.x, d.y
		handlers.Pickup(pa, id)
		if troom.drops[id] then
			table.insert(fails, ("%s@%d"):format(d.kind, math.floor(d.x)))
		end
	end
end
print(("[113] 도둑 두목 하드 상자: 덩이 %d · 사탕 %d · 주운 뒤 가방의 사탕 %d · 못 주운 것 %s"):format(total, cand, Bag.count(sa.hero, E.candy.id), table.concat(fails, " ")))
eq(Bag.count(sa.hero, E.candy.id), E.boss.hard, "덩이를 다 주우면 가방에 사탕 " .. E.boss.hard)
World.removePlayer(pa)
Event.clock = os.time
World.removePlayer(p)
