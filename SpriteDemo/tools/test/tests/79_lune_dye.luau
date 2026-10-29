-- 「달의 계승자」 — 무기 · 로브 색 바꾸기(염색 — 2026-10-22 · 공방 design/dye.js · bm.js의 dyepoint · dyerobe · shared sim/dye.luau · server world.luau의 Cash "dye").
--  사용자: "무기 색깔 바꾸는거 할수있어? 로브색깔이나" · "살라맨더 머리색 바뀌는걸로하죠"
--  보는 것: ① 자료(색 · 상품 · 아이템 · 그림판) ② 규칙(고를 수 있는 색 · 같은 색 · 「원래」) ③ 저장(캐릭터에 남는다 · 모르는 색은 버린다 · 고르는 화면에 간다)
--   ④ 구매(보관함에 염색약) ⑤ 서버(한 개를 쓰고 바꾼다 · 방 사람들에게 · 없으면 · 이상한 색이면 쓰지 않는다) ⑥ 그림의 자리(영웅의 장마다 염색 판의 자리 · 판에 들어간다)
local Dye = req("ReplicatedStorage/shared/lune/sim/dye")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Account = req("ReplicatedStorage/shared/lune/sim/account")
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local ASSETS = req("ReplicatedStorage/shared/lune/data/assets.generated")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local BM = req("ReplicatedStorage/shared/lune/data/bm.generated")
local DYE = Dye.data

-- ① 자료
expect(#DYE.point >= 4 and #DYE.robe >= 4, "무기 색 · 로브 색이 여럿")
for _, cls in CLASSES.order do
	local hd = DYE.heroes[cls]
	expect(hd ~= nil, cls .. ": 염색 자료가 있다")
	for _, q in DYE.point do
		expect(hd and hd.chips[q.id] ~= nil and #hd.chips[q.id] == 2, cls .. " · " .. q.id .. ": 색 칸의 두 색")
	end
end
expect(DYE.heroes.salamander.hair == true, "살라맨더는 무기 대신 머리 색(사용자 10-22)")
for _, cls in { "axion", "riven", "reaper", "mooni" } do
	expect(DYE.heroes[cls].hair == false, cls .. ": 무기 색")
end
for _, id in { "dyepoint", "dyerobe" } do
	local p = Cash.product(id)
	expect(p ~= nil and p.kind == "product", id .. ": 개발자 상품")
	expect(p and p.trade == true and p.icon == "bm_" .. id, id .. ": 거래 가능 · 제 그림")
	-- 2026-10-22 사용자 "달빛상점에서 염색약 빼 일단 이건 계획이고 달빛상점에 보여주면안되는거야" → 꺼 둔 상품(탭에 없고 살 수 없다 · 셈 · 창 · 그림판은 남는다)
	expect(p and p.built == false, id .. ": 꺼 둔 상품(살 수 없다)")
	for _, ids in BM.shop.rows do
		expect(table.find(ids, id) == nil, id .. ": 달빛 상점의 어느 탭에도 없다")
	end
	local g = Items.goods("bm_" .. id)
	expect(g ~= nil and g.paid == true, id .. ": 유료 아이템(가방 · 경매장)")
end
eq(Items.goods("bm_dyepoint").kind, "bmDyePoint", "무기 염색약의 종류")
eq(Items.goods("bm_dyerobe").kind, "bmDyeRobe", "로브 염색약의 종류")
eq(#Cash.check(), 0, "상품 표 · 아이템 표가 맞는다(염색약 포함)")
for _, q in DYE.point do
	expect(typeof(ASSETS[q.page]) == "string" and string.sub(ASSETS[q.page], 1, 13) == "rbxassetid://", q.id .. ": 무기 색의 판이 올라가 있다")
end
expect(string.sub(ASSETS[DYE.body] or "", 1, 13) == "rbxassetid://", "로브의 판이 올라가 있다")

-- ② 규칙
eq(#Dye.choices("point"), #DYE.point + 1, "고르는 칸 = 「원래」 + 무기 색")
eq(Dye.choices("robe")[1], Dye.BASE, "「원래」가 맨 앞")
expect(Dye.valid("point", "gold") and Dye.valid("robe", "navy") and Dye.valid("robe", Dye.BASE), "있는 색 · 「원래」는 된다")
expect(not Dye.valid("point", "navy") and not Dye.valid("robe", "gold") and not Dye.valid("hat", "gold") and not Dye.valid("point", 3), "다른 곳의 색 · 없는 곳 · 이상한 값은 안 된다")
do
	local h = Hero.new(7901, "axion")
	expect(Dye.apply(h, "point", Dye.BASE) == nil, "원래 색에서 「원래」는 안 된다(같은 색)")
	expect(Dye.apply(h, "point", "gold") == true and h.look.point == "gold", "금빛으로")
	local ok, why = Dye.apply(h, "point", "gold")
	expect(ok == nil and why == DYE.words.same, "같은 색은 안 된다")
	expect(Dye.apply(h, "robe", "navy") == true and h.look.robe == "navy" and h.look.point == "gold", "로브는 따로")
	expect(Dye.apply(h, "point", Dye.BASE) == true and h.look.point == nil and h.look.robe == "navy", "「원래」로 되돌린다")

	-- ③ 저장
	local back = Hero.unpack(7901, Hero.pack(h))
	expect(back and back.look.robe == "navy" and back.look.point == nil, "저장하고 다시 읽어도 그대로")
	local packed = Hero.pack(h)
	packed.look = { point = "rainbow", robe = "navy" }
	local odd = Hero.unpack(7901, packed)
	expect(odd and odd.look.point == nil and odd.look.robe == "navy", "모르는 색은 버린다(원래 색)")
	packed.look = nil
	local old = Hero.unpack(7901, packed)
	expect(old and typeof(old.look) == "table" and next(old.look) == nil, "염색이 생기기 전의 저장 = 원래 색")
	eq(Hero.view(h).look.robe, "navy", "내 화면에 보내는 것에 색이 있다")
	local acct = Account.new and Account.new(7901) or nil
	if acct then
		table.insert(acct.chars, { id = 1, name = "염색", class = "axion", hero = Hero.pack(h) })
		local v = Account.view(acct)
		expect(v.chars[#v.chars].look and v.chars[#v.chars].look.robe == "navy", "캐릭터 고르는 화면에도 그 색")
	end
end

-- ④ 구매 → 보관함
do
	local acct = { bm = nil }
	local ok = pcall(function()
		acct = Account.new(7902)
	end)
	if ok and acct and acct.bm then
		local got = Cash.grant(acct, "dyepoint", "rcpt-dye-1", os.time(), 6, nil)
		expect(got == true, "무기 염색약을 샀다")
		local n = 0
		for _, e in acct.bm.box do
			if e.id == "bm_dyepoint" then
				n += e.n
			end
		end
		eq(n, 1, "보관함에 무기 염색약 한 개")
	else
		print("(Account.new가 없다 — 구매 검사는 건너뜀)")
	end
end

-- ⑥ 그림의 자리: 영웅의 장마다 염색 판의 자리(8 · 9번째) · 판 안 · 다른 캐릭터에는 없다
do
	local bad, n = 0, 0
	for _, cls in CLASSES.order do
		for _, clip in CHARS.chars[cls].clips do
			for _, f in clip.frames do
				if f then
					n += 1
					if not (f[8] and f[9] and f[8] >= 0 and f[9] >= 0 and f[8] + f[4] <= 1024 and f[9] + f[5] <= 1024) then
						bad += 1
					end
				end
			end
		end
	end
	expect(n > 500, "영웅의 장이 많다(" .. n .. ")")
	eq(bad, 0, "영웅의 장마다 염색 판의 자리가 있다")
	local other = 0
	for id, c in CHARS.chars do
		if not DYE.heroes[id] then
			for _, clip in c.clips do
				for _, f in clip.frames do
					if f and f[8] then
						other += 1
					end
				end
			end
		end
	end
	eq(other, 0, "몬스터 · 펫에는 염색 판의 자리가 없다")
	local S = UI.layout.cash
	expect(S.dyeGX + S.dyeCols * S.dyeCellW + (S.dyeCols - 1) * S.dyeGap <= S.w, "색 칸이 창의 폭 안에")
	local rows = math.ceil((math.max(#DYE.point, #DYE.robe) + 1) / S.dyeCols)
	expect(rows * S.dyeCellH + (rows - 1) * S.dyeGap <= S.dyeBox, "색 칸 줄이 미리보기 판의 높이 안에")
end

-- ⑤ 서버
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
SERVICE("MessagingService", { PublishAsync = function() end, SubscribeAsync = function() end })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names = {}, {}
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
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local function join(uid, name, cls)
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, cls)
	handlers.Chars(p, "enter", made.id)
	return p, World.session(p)
end
local p, s = join(7910, "염색시험", "salamander")
local p2, s2 = join(7911, "구경꾼", "riven")
World.jump(p, "town") -- (새 캐릭터는 저마다의 「달빛 꿈」 방에서 시작한다 — 둘을 같은 마을로)
World.jump(p2, "town")
expect(s.scene == s2.scene, "둘이 같은 장면")
local h = s.hero
do
	local r0 = handlers.Cash(p, "dye", { part = "point", id = "gold" })
	expect(r0 and not r0.ok and r0.why == DYE.words.none, "염색약이 없으면 바뀌지 않는다")
	Bag.give(h, "bm_dyepoint", 2)
	local r1 = handlers.Cash(p, "dye", { part = "point", id = "rainbow" })
	expect(r1 and not r1.ok, "없는 색은 안 된다")
	eq(Bag.count(h, "bm_dyepoint"), 2, "안 되면 염색약을 쓰지 않는다")
	local r2 = handlers.Cash(p, "dye", "gold")
	expect(r2 and not r2.ok, "꼴이 이상한 요청은 안 된다")
	table.clear(sent)
	local r3 = handlers.Cash(p, "dye", { part = "point", id = "gold" })
	expect(r3 and r3.ok and r3.name == "금빛", "금빛으로 바뀌었다(살라맨더 = 머리 색)")
	eq(Bag.count(h, "bm_dyepoint"), 1, "염색약 한 개를 썼다")
	eq(h.look.point, "gold", "캐릭터의 색")
	local seen = false
	for _, f in sent do
		if f.name == "Who" and f.player == p2 then
			for _, w in f.args[2] do
				if w.id == h.id and w.look and w.look.point == "gold" then
					seen = true
				end
			end
		end
	end
	expect(seen, "같은 장면의 다른 사람에게 그 색이 간다")
	local r4 = handlers.Cash(p, "dye", { part = "point", id = "gold" })
	expect(r4 and not r4.ok and r4.why == DYE.words.same, "같은 색은 안 된다")
	eq(Bag.count(h, "bm_dyepoint"), 1, "같은 색이면 염색약을 쓰지 않는다")
	local r5 = handlers.Cash(p, "dye", { part = "robe", id = "navy" })
	expect(r5 and not r5.ok and r5.why == DYE.words.none, "로브는 로브 염색약으로만")
	local r6 = handlers.Cash(p, "dye", { part = "point", id = Dye.BASE })
	expect(r6 and r6.ok and h.look.point == nil, "「원래」로 되돌린다(한 개를 쓴다)")
	eq(Bag.count(h, "bm_dyepoint"), 0, "두 개를 다 썼다")
end
World.removePlayer(p2)
World.removePlayer(p)
-- 나간 뒤의 저장에도 색이 남는다
do
	local p3, s3 = join(7912, "저장시험", "mooni")
	Bag.give(s3.hero, "bm_dyerobe", 1)
	local r = handlers.Cash(p3, "dye", { part = "robe", id = "wine" })
	expect(r and r.ok, "자주 로브")
	World.removePlayer(p3)
	local saved = disk[7912]
	local found = false
	for _, c in (saved and saved.chars) or {} do
		if c.hero and c.hero.look and c.hero.look.robe == "wine" then
			found = true
		end
	end
	expect(found, "계정의 저장에 그 캐릭터의 색이 있다")
end
