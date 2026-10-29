-- 「달의 계승자」 — 상용 MMORPG에 견준 구조의 빈 곳 메우기(2026-10-18 — 사용자가 8시간 자리를 비운 동안: "계획세우고 반영하고 … 자율적으로 작업해봐").
--  ① 쓰러진 벌칙(약해짐)이 보인다 · ② 맵에 들어서면 맵 이름 · (이어서 붙는 것들은 아래에 차례로)
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
local pixelText = req("Client/ui/pixelText")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small", KIT.font.small, {})
pixelText.Register("body", KIT.font.body, {})

-- 화면 없이 돌리는 틀(그림 · 글은 적어만 둔다)
local function frame(name: string?, parent, x, y, w, h)
	local f = { Name = name or "Frame", Visible = true, Parent = parent, x = x, y = y, w = w, h = h, kids = {} }
	function f:Destroy() end
	function f:GetDescendants()
		return {}
	end
	function f:GetChildren()
		return {}
	end
	return f
end
local texts = {}
MOCK("Client/lune/ui/ui", {
	COLOR = setmetatable({}, { __index = function(_, k) return k end }),
	M = { small = 10, body = 12 },
	text = function(parent, text, x, y, width, opts)
		local item = { text = text, x = x, y = y, w = width, font = opts and opts.font or "small", color = opts and opts.color, parent = parent }
		function item.set(_, v)
			item.text = v
		end
		table.insert(texts, item)
		return item
	end,
	panel = function(parent, x, y, w, h) return frame("Panel", parent, x, y, w, h) end,
	button = function(parent, label) return { frame = frame("Button", parent) } end,
})
MOCK("Client/lune/stage", { REF_W = 960, place = function(root, name, at, x, y, w, h) return frame(name, root, x, y, w, h) end })

-- ---- ① 쓰러진 벌칙(약해짐) ----
do
	local D = Layout.DEATH
	expect(typeof(D.weak) == "string" and string.find(D.weak, "{m}", 1, true) ~= nil, "쓰러졌을 때의 상자에 약해짐의 줄이 있다(남은 분을 채우는 자리)")
	expect(D.textY < D.weakY and D.weakY < D.hintY and D.hintY < D.buttonY, "줄의 차례: 묻는 글 → 약해짐 → 안내 → 단추")
	local filled = string.gsub(D.weak, "{m}", "30")
	expect(pixelText.Measure(filled, "small") <= D.w - D.pad * 2, "가장 긴 약해짐의 줄(30분)이 상자 안에 한 줄로 든다: " .. filled)
	local DeathBox = req("Client/lune/ui/deathBox")
	table.clear(texts)
	DeathBox.show(frame("Root"), function() end, 12)
	local shown = false
	for _, t in texts do
		shown = shown or (string.find(t.text, "약해짐 12분", 1, true) ~= nil and t.color == "red")
	end
	expect(shown, "Lv.10 위에서 쓰러지면 상자에 「약해짐 12분」이 붉게 뜬다")
	table.clear(texts)
	DeathBox.show(frame("Root"), function() end, 0)
	for _, t in texts do
		expect(string.find(t.text, "약해짐", 1, true) == nil, "벌칙이 없으면(Lv.10 아래) 그 줄을 띄우지 않는다")
	end
	DeathBox.hide()
	-- 벌칙의 값은 서버의 영웅 자료가 그대로 화면에 간다(selfView의 weak — 초)
	local N = req("ReplicatedStorage/shared/lune/config/numbers")
	expect(N.deathMinutes(30) > 0 and N.deathMinutes(150) <= 30, "약해짐의 분: Lv.30 > 0 · 가장 길어도 30분")
end

-- ---- ② 맵 이름 ----
do
	local L = Layout.MAPNAME
	expect(L ~= nil and L.w > 0 and L.nameY > 0 and L.hold >= 1.5, "맵 이름의 칸과 시간(공방 UILAYOUT.mapName)")
	local MapName = req("Client/lune/mapName")
	local r, n = MapName.titleOf("r2a1")
	eq(r, "수정 숲", "성문 밖 숲길의 지역")
	eq(n, "성문 밖 숲길", "성문 밖 숲길의 이름")
	r, n = MapName.titleOf("ct")
	eq(r, "", "은달 항구: 지역 이름이 맵 이름과 같으면 지역 줄은 비운다")
	eq(n, "은달 항구", "은달 항구")
	r, n = MapName.titleOf("town")
	expect(n == SCENES.scenes.town.name and r ~= "" and r ~= n, "초승달 마을의 지역 줄 = 1지역 " .. r)
	r, n = MapName.titleOf("rf1#3")
	eq(n, SCENES.scenes.rf1.name, "토벌의 방(rf1#번호)은 그 장면의 이름")
	-- 모든 장면: 이름이 칸에 들어간다
	for key, sc in SCENES.scenes do
		local _, name = MapName.titleOf(key)
		expect(pixelText.Measure(name, "body") <= L.w, ("맵 이름이 칸에 들어간다 %s — %s"):format(key, name))
	end
	-- 보이는 시간: 밝아짐 → 머묾 → 흐려짐 · 보스 체력이 뜨면 바로 사라진다
	MapName.init(frame("Root"))
	MapName.show("r2a1")
	eq(MapName.alpha(), 0, "막 뜬 때는 보이지 않는다(밝아지는 중)")
	MapName.step(L.fadeIn)
	eq(MapName.alpha(), 1, "밝아진 뒤에는 다 보인다")
	MapName.step(L.hold + L.fadeOut + 0.1)
	eq(MapName.alpha(), 0, "머문 뒤 흐려져 사라진다")
	MapName.show("r2a1")
	MapName.step(0.5, true)
	eq(MapName.alpha(), 0, "보스 체력 · 퀘스트 연출이 그 자리를 쓰면 바로 사라진다")
end

-- ---- ③ 획득 알림: 같은 갈래가 이어 오면 한 줄로 합치고, 줄 수를 넘지 않고, 시간이 지나면 사라진다 ----
do
	local L = Layout.GAINLOG
	local GainLog = req("Client/lune/gainLog")
	GainLog.clear()
	GainLog.xp(100)
	GainLog.xp(250)
	eq(#GainLog.lines, 1, "경험치가 이어 오면 한 줄로 합친다")
	expect(string.find(GainLog.lines[1].text, "350", 1, true) ~= nil, "합친 줄의 수 = 더한 값: " .. GainLog.lines[1].text)
	GainLog.money(30)
	GainLog.item("빼어난 Lv.30 큰 도끼")
	GainLog.level(31)
	GainLog.quest("성문 밖의 저녁")
	eq(#GainLog.lines, 5, "갈래가 다르면 새 줄")
	GainLog.step(L.merge + 0.1)
	GainLog.xp(5)
	eq(GainLog.lines[#GainLog.lines].text, "경험치 +5", "합치는 시간이 지나면 새 줄")
	for i = 1, 10 do
		GainLog.item("물건 " .. i)
	end
	eq(#GainLog.lines, L.lines, "줄 수를 넘지 않는다(오래된 줄부터 빠진다)")
	GainLog.step(L.life + L.fade + 0.1)
	eq(#GainLog.lines, 0, "머문 뒤 흐려져 사라진다")
	for _, w in { "경험치 +1,234,567", "획득: 빼어난 Lv.150 달빛 대검", "퀘스트 완료: 오천 년을 바래지 않은 깃발" } do
		expect(pixelText.Measure(w, "small") <= 220, "획득 알림의 긴 줄도 칸(220)에 든다: " .. w)
	end
end

-- ---- ④ 주민의 고르는 말: 할 일이 둘 넘으면 줄마다 하나(돌려줄 것 → 받을 것 → 하는 중 → 대화하기) ----
do
	local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
	eq(Quests.talkMenu({ ready = {}, offer = { "r2m1" }, wait = {} }, 3), nil, "하나뿐이면 고르는 말 없이 바로(전과 같다)")
	local m = Quests.talkMenu({ ready = { "r2m2" }, offer = { "r2s1" }, wait = { "r2s2" } }, 3)
	expect(m ~= nil and #m == 3, "대화창의 줄 수(3)까지")
	eq(m[1].kind, "ready", "돌려줄 것이 먼저")
	eq(m[2].kind, "offer", "받을 것이 다음")
	eq(m[3].kind, "chat", "마지막 줄은 늘 「대화하기」(넘는 퀘스트는 줄이 빌 때)")
	m = Quests.talkMenu({ ready = {}, offer = { "r2m1" }, wait = { "r2s2" } }, 3)
	expect(m ~= nil and m[1].kind == "offer" and m[2].kind == "wait" and m[3].kind == "chat", "받을 것 · 하는 중인 것 · 대화하기")
	for _, row in m do
		expect(pixelText.Measure(row.text, "body") <= 428, "고르는 줄이 대화창의 폭에 든다: " .. row.text)
	end
	-- 4차 전직 퀘스트(2026-10-18): 퀘스트가 생겨 Lv.100이 되어도 저절로 오르지 않는다
	local job4 = Quests.jobQuest(4)
	expect(job4 ~= nil and job4.giver == "master", "4차 전직은 사제의 퀘스트")
end

-- ---- ⑤ 비선공(첫 사냥터의 수습 검병 — 2026-10-18): 맞기 전에는 곁에 서 있어도 알아채지 않고, 맞으면 쫓는다 ----
do
	local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
	local Room = req("ReplicatedStorage/shared/lune/sim/room")
	local def = COMBAT.mobs.trainee
	expect(def ~= nil and def.passive == true, "수습 검병은 비선공")
	for id, m in COMBAT.mobs do
		expect(not m.passive or id == "trainee", "비선공은 첫 사냥터의 수습 검병뿐(제 판단) — " .. id)
	end
	local h = { id = 1, alive = true, x = 100, y = 100, buffs = {}, buffAt = {} }
	local mob = { def = def, x = 110, y = 100, aggro = 0, target = nil }
	eq(Room.findTarget(nil, mob, { [1] = h }), nil, "곁(10점)에 서 있어도 맞기 전에는 알아채지 않는다")
	mob.aggro, mob.target = 5, 1
	eq(Room.findTarget(nil, mob, { [1] = h }), 1, "맞은 뒤(aggro)에는 알아채고 쫓는다")
	local other = { def = COMBAT.mobs.puff, x = 110, y = 100, aggro = 0 }
	if other.def and other.def.see and other.def.see >= 10 then
		eq(Room.findTarget(nil, other, { [1] = h }), 1, "다른 몬스터는 그대로 선공")
	end
end

-- ---- ⑥ 창고 칸(설계 「창고 칸 +4」 — 지역마다 부탁 하나 · 2026-10-18): 계정에 한 번씩 붙고, 창고의 탭마다 칸이 는다 ----
do
	local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
	local Account = req("ReplicatedStorage/shared/lune/sim/account")
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	local ids = {}
	for _, def in Quests.list do
		if (def.reward.store or 0) > 0 then
			table.insert(ids, def.id)
			eq(def.reward.store, 4, "창고 칸 보상은 4칸 — " .. def.name)
		end
	end
	eq(#ids, 4, "창고를 늘리는 부탁은 지역마다 하나(넷)")
	local acct = Account.new()
	eq(Account.storeExtra(acct), 0, "처음 계정은 늘린 칸이 없다")
	acct.storeGot[ids[1]] = true
	acct.storeGot[ids[2]] = true
	eq(Account.storeExtra(acct), 8, "부탁 둘 = 8칸")
	local back = Account.unpack(Account.pack(acct))
	eq(Account.storeExtra(back), 8, "저장하고 다시 읽어도 그대로")
	local h = { store = { gear = {}, use = {}, etc = {} } }
	for i = 1, 24 do
		h.store.gear[i], h.store.use[i], h.store.etc[i] = false, false, false
	end
	eq(Bag.storeSize(h), 24, "기본 24칸")
	Bag.growStore(h, 8)
	eq(Bag.storeSize(h), 32, "늘린 뒤 32칸")
	eq(#h.store.use, 32, "탭마다 빈 칸이 붙는다")
	local QW = req("Client/lune/ui/questWindow")
	local parts = QW.rewardParts(Quests.def(ids[1]).reward, 30, "axion")
	local shown = false
	for _, p in parts do
		shown = shown or p.text == "창고 칸 +4"
	end
	expect(shown, "퀘스트 창의 보상에 「창고 칸 +4」")
end

-- ---- ⑦ 되사기(2026-10-18 — 메이플의 재구매): 판 값 그대로 되산다 · 이번 접속에 판 것 가장 최근 10개 · 저장하지 않는다 ----
do
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	local Items = req("ReplicatedStorage/shared/lune/sim/items")
	local h = Hero.new(901, "axion")
	h.money = 100000
	local start = Bag.count(h, "potion1") -- 새 캐릭터는 물약 열을 가지고 시작한다
	Bag.give(h, "potion1", 5)
	local slot
	for i, s in h.use do
		if s and s.item == "potion1" then
			slot = i
			break
		end
	end
	local got = Bag.sell(h, "use", slot, 3)
	expect(got ~= nil and got > 0, "판다")
	eq(#h.buyback, 1, "판 것을 기억한다")
	local money = h.money
	expect(Bag.buyBack(h, 1) == true, "되산다")
	eq(h.money, money - got, "판 값 그대로")
	eq(Bag.count(h, "potion1"), start + 5, "판 셋이 돌아왔다")
	eq(#h.buyback, 0, "되산 것은 목록에서 빠진다")
	-- 장비
	local it = Items.make("hat", 10, Items.NORMAL)
	Bag.add(h, it)
	local gslot
	for i, g in h.gear do
		if g == it then
			gslot = i
		end
	end
	local price = Bag.sell(h, "gear", gslot)
	expect(price ~= nil and Bag.view(h).buyback[1].gear ~= nil and Bag.view(h).buyback[1].price == price, "되사기 목록(장비 · 값)이 화면에 간다")
	expect(Bag.buyBack(h, 1) == true, "장비도 되산다")
	local back = false
	for _, g in h.gear do
		back = back or (g and g.slot == "hat" and g.stage == 10)
	end
	expect(back, "되산 장비가 가방에")
	-- 가장 최근 10개
	for _ = 1, 12 do
		Bag.give(h, "potion1", 1)
		for i, s in h.use do
			if s and s.item == "potion1" then
				Bag.sell(h, "use", i, 1)
				break
			end
		end
	end
	eq(#h.buyback, Bag.BUYBACK, "가장 최근 10개까지")
	h.money = 0
	expect(Bag.buyBack(h, 1) == nil, "달돈이 모자라면 되사지 못한다")
	eq(Bag.buyBack(h, 99), nil, "없는 차례")
	local packed = Hero.pack(h)
	eq(packed.buyback, nil, "저장하지 않는다(나갔다 들어오면 비어 있다)")
	expect(pixelText.Measure("되사기 — 이번 접속에 판 것(판 값 그대로)", "small") <= 300, "되사기 머리 줄(shopWindow.BACK_HEAD)이 상점 창의 폭에 든다")
end

-- ---- ⑨ 사냥터 정예(2026-10-18 — 메이플의 엘리트 몬스터 · 공방 combat.js FIELD_ELITE): 2지역부터의 사냥터에서 every마리를 잡으면 하나가 나온다 ----
do
	local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
	local Room = req("ReplicatedStorage/shared/lune/sim/room")
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	local FE = COMBAT.fieldElite
	expect(FE ~= nil and FE.every > 0 and FE.hp > 1 and FE.xp > 1, "정예의 규칙이 게임에")
	local n = 0
	for key, sc in SCENES.scenes do
		if sc.elite then
			n += 1
			expect(sc.region ~= "r1" and not sc.story and not sc.rift and #sc.mobs > 0, "정예는 2지역부터의 사냥터에만 — " .. key)
		elseif sc.region == "r2" or sc.region == "r3" or sc.region == "r4" then
			expect(#sc.mobs == 0 or sc.story or sc.rift, "몬스터가 있는 2~4지역 사냥터에는 정예가 나온다 — " .. key)
		end
	end
	expect(n >= 40, "정예가 나오는 맵이 2 · 3 · 4지역 · 바다의 사냥터(" .. n .. ")")
	expect(not SCENES.scenes["rf1#1"].elite, "토벌에는 없다")
	-- 방의 셈
	local sc = SCENES.scenes.r2a1
	expect(sc.elite == true, "성문 밖 숲길에는 나온다")
	local room = Room.new("r2a1", sc, Random.new(3))
	-- (2026-10-28부터 그 뒤에 잠수 방지 날파리의 자리가 붙는다 — 정예의 자리는 장면의 몬스터 바로 다음)
	local flies = if Room.huntRoom(sc) then COMBAT.afk.slots else 0
	eq(#room.mobs, #sc.mobs + 1 + flies, "몬스터 목록 끝에 정예의 자리 하나(번호가 바뀌지 않게) + 날파리의 자리")
	local slot = room.mobs[#sc.mobs + 1]
	eq(room.eliteSlot, slot, "정예의 자리 = 장면의 몬스터 바로 다음")
	expect(slot.fieldElite and slot.elite and slot.away and slot.state == "gone", "처음에는 없다")
	local plain = room.mobs[1]
	eq(slot.kind, plain.kind, "그 맵의 몬스터")
	eq(slot.maxHp, plain.maxHp * FE.hp, "체력 hp배")
	expect(room:describe().mobs[slot.id].elite == true, "화면에 「정예」로 간다(분홍 빛 · 이름표)")
	local h = Hero.new(5801, "riven")
	h.level = 32
	h.x, h.y = sc.spawn.x, sc.spawn.y
	local function kill(mob)
		mob.state, mob.hp = "idle", mob.maxHp
		local out = { hits = {}, kills = {} }
		room:strike(h, mob, mob.hp + 1, mob.x, nil, out)
		return out
	end
	for _ = 1, FE.every - 1 do
		kill(plain)
	end
	expect(slot.away, "every - 1마리까지는 없다")
	kill(plain)
	expect(not slot.away and slot.state == "spawn" and slot.hp == slot.maxHp, "every마리째에 나온다")
	local spotOk = false
	for _, m in room.mobs do
		spotOk = spotOk or (not m.fieldElite and m.homeX == slot.homeX and m.y == slot.y)
	end
	expect(spotOk, "맵의 몬스터 자리 가운데 하나에서")
	local saw = false
	for _, e in room:step({}, 0.05) do
		saw = saw or (e.type == "elite" and e.mob == slot.id and e.y == slot.y)
	end
	expect(saw, "방 사람들에게 알린다(나온 자리의 높이와 함께)")
	for _ = 1, FE.every + 3 do
		kill(plain)
	end
	expect(not slot.away and room.eliteKills == 0, "정예가 있는 동안은 세지 않는다(하나뿐)")
	slot.state = "idle"
	local want = math.max(1, math.floor(Hero.killXp(h, slot.lv, slot.def.hp) * FE.xp + 0.5))
	local out = { hits = {}, kills = {} }
	room:strike(h, slot, slot.hp + 1, slot.x, nil, out)
	local k = out.kills[1]
	expect(k ~= nil and k.xp == want, "경험치 xp배")
	expect(k.drop ~= nil and k.drop.kind == "money", "달돈은 반드시 떨어진다")
	for _ = 1, 40 do
		room:step({}, 0.05)
	end
	expect(slot.away and slot.state == "gone", "쓰러지면 다시 나오지 않는다 — 다시 every마리")
	for _ = 1, FE.every do
		kill(plain)
	end
	expect(not slot.away, "다시 every마리를 잡으면 또 나온다")
end

-- ---- ⑩ 버프 그림의 설명(2026-10-18 — 공방 ui.js BUFFTIP): 글이 판에 든다 · 단추와 ↑ 안내에 「~다」가 없다 ----
do
	local UIDATA = req("ReplicatedStorage/shared/lune/data/ui.generated")
	local BT = UIDATA.buffTip
	expect(BT ~= nil and BT.weak ~= nil and BT.left ~= nil, "버프 설명의 글이 게임에")
	local TIP = Layout.STAT.tip
	local inner = TIP.w - TIP.pad * 2
	for _, line in { BT.weak.text, BT.weak.hint, BT.onLine, (BT.left:gsub("{t}", "59분")) } do
		expect(pixelText.Measure(line, "small") <= inner * TIP.lines, "설명 판에 든다 — " .. line)
	end
	expect(pixelText.Measure(BT.weak.title, "body") <= inner, "제목이 판에 든다")
	local W = UIDATA.words
	for k, v in W.ask do
		expect(not v[2]:match("다$"), "수 고르기의 단추에 「~다」가 없다 — " .. k .. " " .. v[2])
	end
	expect(not W.askNo:match("다$"), "취소 단추에 「~다」가 없다")
	expect(not UIDATA.layout.death.yes:match("다$"), "쓰러진 상자의 단추에 「~다」가 없다")
	local QD = req("ReplicatedStorage/shared/lune/data/quests.generated")
	local acts = 0
	for _, q in QD.list do
		for _, st in q.steps or {} do
			if type(st.act) == "string" then
				acts += 1
				expect(not st.act:match("다$"), "↑ 자리의 안내에 「~다」가 없다 — " .. q.id .. " " .. st.act)
			end
		end
	end
	expect(acts >= 5, "↑ 자리의 안내를 봤다(" .. acts .. ")")
	local CITY = req("ReplicatedStorage/shared/lune/data/city.generated")
	local stories = 0
	for _, st in CITY.stories or {} do
		stories += 1
		expect(not st.act:match("다$"), "숨은 이야기의 안내에 「~다」가 없다 — " .. st.act)
	end
	expect(stories >= 8, "숨은 이야기의 안내를 봤다(" .. stories .. ")")
end

-- ---- ⑪ 경험치 줄의 설명(2026-10-18 — 공방 ui.js XPTIP): 가장 긴 수(Lv.200 근처)도 설명 판에 든다 ----
do
	local UIDATA = req("ReplicatedStorage/shared/lune/data/ui.generated")
	local Format = req("ReplicatedStorage/shared/lune/ui/format")
	local XT = UIDATA.xpTip
	expect(XT ~= nil and XT.now ~= nil and XT.left ~= nil, "경험치 설명의 글이 게임에")
	local TIP = Layout.STAT.tip
	local inner = TIP.w - TIP.pad * 2
	local big = 1234567890
	local now = Format.fill(XT.now, { xp = Format.comma(big), need = Format.comma(big), pct = "100.00" })
	expect(pixelText.Measure(now, "small") <= inner, "경험치 줄이 한 줄에 든다 — " .. now)
	expect(pixelText.Measure(Format.fill(XT.left, { n = Format.comma(big) }), "small") <= inner, "다음 레벨까지 줄이 든다")
end

-- ---- ⑫ 가방이 가득 찼다(2026-10-18): 가득 찬 탭을 가려낸다(가방 단추에 점 · 획득 알림) ----
do
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	local UIDATA = req("ReplicatedStorage/shared/lune/data/ui.generated")
	local h = Hero.new(5901, "axion")
	eq(#Bag.fullTabs(Bag.view(h)), 0, "새 캐릭터의 가방은 가득 차지 않았다")
	local Items = req("ReplicatedStorage/shared/lune/sim/items")
	for i = 1, Bag.size(h) do
		if not h.gear[i] then
			h.gear[i] = Items.make("hat", 10, 2, "axion")
		end
	end
	local full = Bag.fullTabs(Bag.view(h))
	expect(#full == 1 and full[1] == "gear", "장비 탭이 가득 찼다")
	local line = UIDATA.words.bagFull:gsub("{tab}", "장비")
	expect(pixelText.Measure(line, "small") <= UIDATA.hud.gainLog.w, "알림 줄이 획득 알림 칸에 든다 — " .. line)
end

-- ---- ⑬ 경매장 「팔림」(2026-10-18): 획득 알림 한 줄이 칸에 든다(긴 이름 · 큰 수) ----
do
	local Market = req("ReplicatedStorage/shared/lune/sim/market")
	local Format = req("ReplicatedStorage/shared/lune/ui/format")
	local UIDATA = req("ReplicatedStorage/shared/lune/data/ui.generated")
	expect(Market.WORDS.soldNote ~= nil and Market.WORDS.sold == "판매 완료", "「팔림」의 글이 게임에 · 「완료」 탭의 「판매 완료」는 그대로(이름이 겹쳐 덮었던 것 — 2026-10-18 검토)")
	local line = Format.fill(Market.WORDS.soldNote, { name = "빼어난 Lv.100 큰 도끼", n = 9999 })
	expect(pixelText.Measure(line, "small") <= UIDATA.hud.gainLog.w, "「팔림」 줄이 획득 알림 칸에 든다 — " .. line)
end

-- ---- ⑭ 창고는 줄지 않는다(2026-10-18 검토): 저장된 물건이 지금 칸 수보다 뒤에 있으면 칸을 늘려 두고 · 칸 늘리기는 줄이지 않는다 ----
do
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	local Items = req("ReplicatedStorage/shared/lune/sim/items")
	local h = Hero.new(5911, "axion")
	h.storeExtra = 8
	Bag.loadStore(h, nil)
	eq(Bag.storeSize(h), 32, "창고 32칸")
	h.store.gear[30] = Items.make("hat", 10, 2, "axion")
	local packed = Bag.pack(h)
	local h2 = Hero.new(5912, "riven")
	h2.storeExtra = 0 -- 퀘스트의 「창고 칸」 보상 자료가 줄었다고 치자
	Bag.loadStore(h2, packed.store)
	expect(Bag.storeSize(h2) >= 30 and h2.store.gear[30] ~= nil and h2.store.gear[30] ~= false, "뒤 칸의 물건을 잃지 않는다(칸을 그만큼 늘려 둔다)")
	local before = Bag.storeSize(h2)
	Bag.growStore(h2, 0)
	eq(Bag.storeSize(h2), before, "칸 늘리기는 줄이지 않는다")
end

-- ---- ⑮ 전직은 차례대로(2026-10-18 검토): 2차를 건너뛴 Lv.60은 3차 전직 퀘스트를 받지 못하고 · 돌려주는 것도 바로 다음 차수일 때만 ----
do
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
	local h = Hero.new(5921, "reaper")
	Hero.setLevel(h, 60, 1) -- 1차인 채로 Lv.60(2차 전직 퀘스트를 하지 않았다)
	eq(h.job, 1, "1차인 채로")
	eq(Quests.state(h.quests, h.level, "job3"), "locked", "2차를 하지 않았으면 3차 전직 퀘스트는 잠겨 있다")
	expect(Quests.state(h.quests, h.level, "job2") == "open", "2차 전직 퀘스트는 받을 수 있다")
	local open = {}
	for _, def in Quests.openJobs(h.quests, h.level) do
		open[def.id] = true
	end
	expect(open.job2 and not open.job3, "사제가 내미는 전직 퀘스트도 2차뿐")
	-- 예전에 받아 둔 3차(이 잠금 전) — 다 해도 돌려주지 못한다(끝났는데 전직이 안 되는 일이 없게)
	h.quests.job3 = { done = false, c = {} }
	for i, step in Quests.def("job3").steps do
		h.quests.job3.c[i] = step.n
	end
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	for _, t in Quests.takes("job3") do
		Bag.give(h, t.item, t.n)
	end
	local got, why = Hero.questDone(h, "job3")
	expect(got == nil and why ~= nil and h.job == 1 and not h.quests.job3.done, "2차 전에는 3차 전직 퀘스트를 돌려주지 못한다 — " .. tostring(why))
	Hero.setLevel(h, 60, 2)
	eq(h.job, 2, "2차가 되면")
	expect(Quests.state(h.quests, h.level, "job3") ~= "locked", "3차 전직 퀘스트가 풀린다")
end

-- ---- ⑯ 퀘스트 물건은 창고에 맡길 수 없다(2026-10-18 검토 — 창고는 계정이 같이 써서 다른 캐릭터가 꺼내 퀘스트를 바로 끝냈다) ----
do
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
	local h = Hero.new(5931, "axion")
	Bag.loadStore(h, nil)
	Bag.give(h, "etc_plate", 3)
	local at
	for i = 1, Bag.size(h) do
		if h.etc[i] and h.etc[i].item == "etc_plate" then
			at = i
		end
	end
	local ok, why = Bag.storeIn(h, "etc", at, nil, nil)
	expect(ok == nil and why == Bag.NO_STORE and Bag.count(h, "etc_plate") == 3 and Bag.stored(h, "etc") == 0, "퀘스트 물건(갑옷 조각)은 맡기지 못한다")
	Bag.give(h, "mat_ore1", 2) -- 퀘스트가 아닌 기타 물건은 그대로 맡긴다
	local dust
	for i = 1, Bag.size(h) do
		if h.etc[i] and h.etc[i].item == "mat_ore1" then
			dust = i
		end
	end
	expect(dust ~= nil and Bag.storeIn(h, "etc", dust, nil, nil) == true and Bag.stored(h, "etc") == 1, "다른 기타 물건(재료)은 맡긴다")
end

-- ---- ⑰ 조작이 돌아올 때 읽지 않은 「누른 순간」을 버린다(2026-10-18 검토: 문을 지나며 화면이 까만 동안 ↑를 한 번 더 누르면 막이 걷히자마자 들어온 문으로 되돌아갔다) ----
do
	local Input = req("Client/lune/input")
	Input.press("up")
	Input.release("up")
	Input.press("jump")
	Input.flush()
	expect(not Input.take("up") and not Input.take("jump"), "버린 뒤에는 누른 순간이 남지 않는다")
	expect(Input.held("jump"), "누르고 있는 것은 그대로")
	Input.release("jump")
	Input.press("jump")
	expect(Input.take("jump"), "그 뒤에 새로 누른 것은 읽힌다")
	Input.release("jump")
end

-- ---- ⑱ 첫 강화(달가루 없이 반드시 붙는다)는 서버와 대장간 창이 같은 셈(Items.firstFree — 2026-10-18 검토: 창은 「제 레벨 + 10」을 보지 않아 높은 장비에도 「첫 강화」를 보였다) ----
do
	local Items = req("ReplicatedStorage/shared/lune/sim/items")
	expect(Items.firstFree(false, 10, { star = 0, stage = 20 }) == true, "제 레벨 + 10까지의 별 없는 장비는 첫 강화")
	expect(Items.firstFree(false, 10, { star = 0, stage = 21 }) == false, "그보다 높은 장비는 아니다")
	expect(Items.firstFree(true, 10, { star = 0, stage = 10 }) == false, "강화를 해 본 캐릭터는 아니다")
	expect(Items.firstFree(false, 10, { star = 1, stage = 10 }) == false, "별이 있는 장비는 아니다")
end

-- ---- ⑲ 방을 떠난 사람의 늦게 드는 타는 버린다(Room:forget — 2026-10-18 검토: 떠난 리퍼의 붙는 불이 보스를 쓰러뜨려 아무도 몫을 받지 못했다) ----
do
	local Room = req("ReplicatedStorage/shared/lune/sim/room")
	local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
	local room = Room.new("hunt", SCENES.scenes.hunt, Random.new(3))
	local a, b = Hero.new(5941, "reaper"), Hero.new(5942, "riven")
	room.laters = { { at = 1, hero = a, fn = function() end }, { at = 1, hero = b, fn = function() end }, { at = 2, hero = a, fn = function() end } }
	room:forget(a)
	expect(#room.laters == 1 and room.laters[1].hero == b, "떠난 사람의 것만 지운다")
end

-- ---- ⑳ 초대한 사람이 나가면 받은 사람의 초대 상자를 닫는다(Party.leave의 셋째 값 — 2026-10-18 검토) ----
do
	local Party = req("ReplicatedStorage/shared/lune/sim/party")
	local book = Party.newBook()
	local ok = Party.invite(book, 1, 2, 0)
	expect(ok ~= nil, "초대했다")
	local left, gone, cleared = Party.leave(book, 1)
	expect(#left == 0 and gone == false and cleared ~= nil and cleared[1] == 2, "나간 사람이 보낸 초대를 받은 사람(2)을 알려 준다")
	expect(book.asks[2] == nil, "그 초대는 지워졌다")
end
