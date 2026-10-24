-- 「달의 계승자」 — 영구 게임 패스: 경험치 1.25배 · 드롭률 1.25배(2026-10-22 — 공방 design/bm.js의 xp125 · drop125 · shared sim/cash.luau · room.luau · server cash.luau · world.luau).
--  사용자: "경험치 1.25 배, 드롭률 1.25배 패스 팔고싶은데 영구적용패스" · "패스가 로블록스에 개발자상품말고 패스라고 하는게 있어 그걸 말하는거야 구매하면 영구적용되는 효과로"
--  보는 것: ① 자료(게임 패스 · 효과 · 편의 탭 · 그림) ② 경험치 배율(쿠폰과 더한다) ③ 드롭: 장비 · 재료 · 귀한 물건만 1.25배(달가루 · 달돈은 그대로)
--   ④ 서버: 들어서면 로블록스에 물어 얹는다 · 버프 줄에 보낸다 · 상점에 「보유」 · 번호가 없으면 얹지 않는다(「준비 중」)
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local BM = req("ReplicatedStorage/shared/lune/data/bm.generated")

-- ① 자료
local xpP, dropP = Cash.product("xp125"), Cash.product("drop125")
expect(xpP ~= nil and xpP.kind == "pass", "경험치 1.25배 = 게임 패스(개발자 상품이 아니다)")
expect(dropP ~= nil and dropP.kind == "pass", "드롭률 1.25배 = 게임 패스")
eq(xpP.effect.xp, 0.25, "경험치 +25%")
eq(dropP.effect.drop, 0.25, "드롭률 +25%")
expect(xpP.trade == false and dropP.trade == false, "거래되지 않는다(로블록스가 계정에 묶는다)")
expect(xpP.built and dropP.built, "게임에 만들어 둔 상품")
local conv = BM.shop.rows.conv
expect(table.find(conv, "xp125") ~= nil and table.find(conv, "drop125") ~= nil, "달빛 상점의 「편의」 탭에 있다")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
for _, p in { xpP, dropP } do
	expect(typeof(p.icon) == "string" and p.icon ~= "", p.id .. ": 그림이 있다")
	expect(typeof(p.line) == "string" and p.line ~= "", p.id .. ": 한 줄 설명")
end
expect(UI.buffTip.forever ~= nil and UI.buffTip.pass ~= nil, "버프 줄의 「영구」 · 설명의 글")

-- ② 경험치: 쿠폰(30분 1.5배)과 더한다
do
	local h = Hero.new(7701, "riven")
	eq(Cash.expMul(h), 1, "아무것도 없으면 1배")
	h.passXp = 0.25
	eq(Cash.expMul(h), 1.25, "패스만 1.25배")
	h.expLeft = 600
	eq(Cash.expMul(h), 1.75, "쿠폰과 함께면 더해서 1.75배(제가 정한 것)")
	h.passXp = 0
	eq(Cash.expMul(h), 1.5, "쿠폰만 1.5배")
	h.expLeft = 0
	h.level = 20
	local base = Hero.killXp(h, 20, 1)
	h.passXp = 0.25
	local more = Hero.killXp(h, 20, 1)
	expect(math.abs(more - base * 1.25) <= 1, ("잡은 경험치 %d → %d(1.25배)"):format(base, more))
	local xp, drop = Cash.passEffect({ xp125 = true })
	expect(xp == 0.25 and drop == 0, "경험치 패스만")
	xp, drop = Cash.passEffect({ xp125 = true, drop125 = true })
	expect(xp == 0.25 and drop == 0.25, "둘 다")
	xp, drop = Cash.passEffect({})
	expect(xp == 0 and drop == 0, "없으면 0")
end

-- ③ 드롭: 장비 · 재료 · 귀한 물건만 1.25배 — 달가루는 그대로
do
	local function roll(passDrop: number)
		local room = Room.new("r2a1", SCENES.scenes.r2a1, Random.new(9))
		room.lootRng = Random.new(77)
		local h = Hero.new(7702, "riven")
		h.level, h.passDrop = 34, passDrop
		local mob = nil
		for _, m in room.mobs do
			mob = m
			break
		end
		local items, dust = 0, 0
		for _ = 1, 30000 do
			for _, d in room:lootFor(h, mob) do
				if d.kind == "dust" then
					dust += d.amount
				else
					items += 1
				end
			end
			table.clear(room.drops)
		end
		return items, dust
	end
	local i0, d0 = roll(0)
	local i1, d1 = roll(0.25)
	expect(i0 > 200, ("굴린 것이 넉넉하다(장비 · 재료 · 귀한 것 %d)"):format(i0))
	local ratio = i1 / math.max(1, i0)
	expect(ratio > 1.17 and ratio < 1.33, ("장비 · 재료 · 귀한 물건이 1.25배쯤 나온다(%.3f배 — %d → %d)"):format(ratio, i0, i1))
	local dr = d1 / math.max(1, d0)
	expect(dr > 0.95 and dr < 1.05, ("달가루는 그대로(%.3f배)"):format(dr))
	-- 달돈은 lootFor가 아니라 dropFor — 패스를 보지 않는다
	local room = Room.new("r2a1#77", SCENES.scenes.r2a1, Random.new(9))
	local h = Hero.new(7703, "riven")
	h.passDrop = 0.25
	local n = 0
	for _, m in room.mobs do
		for _ = 1, 2000 do
			if room:dropFor(h, m) then
				n += 1
			end
		end
		break
	end
	expect(n > 0, "달돈은 패스와 상관없이 떨어진다(dropFor)")
end

-- ④ 서버: 들어서면 로블록스에 물어 그 캐릭터에 얹는다
local owned = {} -- [패스 번호] = true(로블록스가 「가졌다」고 답할 것)
local asked = 0
SERVICE("MarketplaceService", {
	UserOwnsGamePassAsync = function(_, _uid, rid)
		asked += 1
		return owned[rid] == true
	end,
})
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
	rankSet = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
local CashServer = req("ServerScriptService/server/lune/modules/cash")
local CashS = req("ReplicatedStorage/shared/lune/sim/cash") -- (서버가 쓰는 것과 같은 모듈 — 상품 번호를 시험용으로 넣는다)
World.start()
local function newPlayer(id: number, name: string)
	local p = { UserId = id, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, "riven")
	handlers.Chars(p, "enter", made.id)
	return p, World.session(p)
end
-- 번호가 없으면(대시보드에 아직 만들지 않았다 — 「준비 중」) 묻지도 얹지도 않는다
local realXp, realDrop = CashS.product("xp125").rid, CashS.product("drop125").rid -- (대시보드의 진짜 번호 — 2026-10-22 사용자가 만든 것: 시험 끝에 되돌린다)
expect(realXp == 2044688783 and realDrop == 2044970818, "대시보드의 패스 번호가 들어 있다")
CashS.product("xp125").rid, CashS.product("drop125").rid = 0, 0
do
	local p, s = newPlayer(7710, "패스없음")
	expect((s.hero.passXp or 0) == 0 and (s.hero.passDrop or 0) == 0, "번호가 없는 패스는 얹지 않는다")
	eq(asked, 0, "로블록스에 묻지 않는다")
	World.removePlayer(p)
end
-- 번호를 넣고(시험용) 경험치 패스만 가진 사람
CashS.product("xp125").rid, CashS.product("drop125").rid = 990125, 990225
owned[990125] = true
do
	table.clear(sent)
	local p, s = newPlayer(7711, "경험치패스")
	eq(s.hero.passXp, 0.25, "들어서면 경험치 패스의 효과(+25%)")
	eq(s.hero.passDrop or 0, 0, "드롭률 패스는 없다")
	local me = nil
	for _, f in sent do
		if f.name == "Self" and f.player == p then
			me = f.args[1]
		end
	end
	expect(me ~= nil and me.passes and me.passes.xp125 == true and not me.passes.drop125, "화면에 가진 패스를 보낸다(버프 줄의 「영구」)")
	-- 상점: 가진 패스는 「보유」
	local view = Cash.view(s.acct, os.time(), s.passes, s.hero.level, {})
	local row = nil
	for _, r in view.list do
		if r.id == "xp125" then
			row = r
		end
	end
	expect(row and row.own == true and row.ready == true, "상점의 경험치 패스 줄 = 보유")
	-- 산 순간(PromptGamePassPurchaseFinished — 서버가 s.passes에 적고 효과를 얹는다)
	s.passes.drop125 = true
	expect(CashServer.applyPasses(s), "드롭률 패스를 샀다 — 바뀌었다")
	eq(s.hero.passDrop, 0.25, "드롭률 패스의 효과(+25%)")
	expect(not CashServer.applyPasses(s), "다시 얹어도 그대로")
	-- 게임 밖(로블록스 웹)에서 산 패스(2026-10-24 사용자: "게임 밖에서 로블록스 측에서 패스결제하면 게임에서 패스 구매한걸로 적용이 안된다"):
	--  「안 가졌다」는 RECHECK초가 지나면 다시 묻는다 → 새로 가진 것을 얹고 알린다(CashGot)
	s.passes.drop125 = false
	s.passAsked = s.passAsked or {}
	s.passAsked.drop125 = nil
	CashServer.applyPasses(s) -- (지금 물었다 — 그 때를 적는다)
	eq(s.hero.passDrop or 0, 0, "드롭률 패스가 없는 것으로 시작")
	owned[CashS.product("drop125").rid] = true -- 웹에서 샀다
	table.clear(sent)
	eq(#CashServer.recheck(s), 0, "RECHECK초 안에는 다시 묻지 않는다")
	s.passAsked.drop125 = nil -- (RECHECK초가 지났다 — 시험 틀은 게임 모듈의 시계가 따로라 적힌 때를 지운다)
	local got = CashServer.recheck(s)
	eq(got[1], "drop125", "다시 물어 새로 가진 패스를 찾았다")
	eq(s.hero.passDrop, 0.25, "웹에서 산 드롭률 패스의 효과가 얹혔다")
	local told = false
	for _, f in sent do
		told = told or (f.name == "CashGot" and f.player == p and f.args[1] == "drop125")
	end
	expect(told, "산 것을 화면에 알린다(CashGot)")
	eq(#CashServer.recheck(s), 0, "가진 것은 다시 알리지 않는다")
	World.removePlayer(p)
end
CashS.product("xp125").rid, CashS.product("drop125").rid = realXp, realDrop
