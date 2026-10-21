-- 「달의 계승자」 — 관리자(어드민)의 시험용 명령: 관리자만 쓸 수 있는가 · 값을 서버가 다시 보는가 · 저장되지 않는가.
--  사용자 2026-10-11: "저만 쓸수있는 어드민용 탭 … 경험치 배율증가, 레벨 조정, 아이템발급 등등 … 누군가 해킹같은거해서 사용도 못해야하고 오직 어드민만 사용할수있어야합니다."
--  지키는 것(server/lune/modules/admin.luau · world.luau의 onAdmin): 관리자인지는 서버가 계정 번호로만 가린다 · 명령이 올 때마다 다시 가린다 · 값의 범위와 꼴을 다시 본다.
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")

local handlers = {}
local sent = {} -- 서버가 보낸 것들 { name, player }
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player)
		table.insert(sent, { name = name, player = player })
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
local disk, book = {}, {}
local rankDisk, rankInfo = {}, {}
local marketBoards = {} -- 경매장의 장부(가짜 저장소)
MOCK("ServerScriptService/server/lune/modules/store", {
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return book[key] end,
	claimName = function(key, id) book[key] = id; return true end,
	freeName = function(key) book[key] = nil end,
	rankSet = function(board, key, score) rankDisk[board] = rankDisk[board] or {}; rankDisk[board][key] = score end,
	rankRemove = function(board, key) if rankDisk[board] then rankDisk[board][key] = nil end end,
	rankTop = function() return {} end,
	rankInfoSet = function(key, info) rankInfo[key] = info end,
	rankInfoGet = function(key) return rankInfo[key] end,
	rankInfoRemove = function(key) rankInfo[key] = nil end,
	isOffline = function() return false end,
	-- 경매장의 장부(관리 창의 「경매장 시험」이 쓴다 — 자세한 것은 41_lune_market.luau)
	marketRead = function(key) return true, marketBoards[key] end,
	marketUpdate = function(key, fn)
		local new, x, y = fn(marketBoards[key])
		if new ~= nil then
			marketBoards[key] = new
		end
		return true, x, y, marketBoards[key]
	end,
})
local World = req("ServerScriptService/server/lune/modules/world")
local Admin = req("ServerScriptService/server/lune/modules/admin")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Quests = req("ReplicatedStorage/shared/lune/sim/quests")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
World.start()

local OWNER = 10311679477 -- 게임의 주인(dolupa95)
local function person(t)
	t.attrs = {}
	t.SetAttribute = function(self, key, value) self.attrs[key] = value end
	return t
end
local function enter(userId: number, name: string, class: string)
	local p = person({ UserId = userId, Name = name })
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, class)
	local got = handlers.Chars(p, "enter", made.id)
	return p, World.session(p), got
end

-- ---- 1) 누가 관리자인가 ----
expect(Admin.is({ UserId = OWNER }) == true, "게임의 주인은 관리자다")
for _, who in { { UserId = 3001 }, { UserId = OWNER + 1 }, { UserId = 0 }, { UserId = -OWNER }, { UserId = tostring(OWNER) }, {}, { UserId = OWNER + 0.5 } } do
	expect(Admin.is(who) == false, "다른 계정 번호는 관리자가 아니다 " .. tostring(who.UserId))
end
expect(Admin.is(nil) == false and Admin.is("dolupa95") == false and Admin.is(OWNER) == false, "계정이 아닌 것은 관리자가 아니다")
expect(handlers.Admin ~= nil, "관리자 명령을 듣는 곳이 있다")

-- ---- 2) 관리자가 아닌 사람: 어떤 명령도 듣지 않는다(대답도 없다) — 아무것도 바뀌지 않는다 ----
local pUser, sUser, gotUser = enter(3001, "해본다3001", "axion")
expect(gotUser.self.admin == nil, "관리자가 아닌 사람의 상태에는 admin 칸이 없다(관리 창을 여는 단추가 보이지 않는다)")
local hu = sUser.hero
local function snap(hero, session)
	local bag = 0
	for i = 1, Bag.size(hero) do
		if hero.gear[i] then
			bag += 1
		end
	end
	return table.concat({ hero.level, hero.xp, hero.job, hero.ap, hero.sp, hero.money, hero.dust, hero.hp, hero.maxHp, bag, Hero.potions(hero), tostring(hero.xpBoost), tostring(hero.dmgBoost), tostring(hero.god), session.scene }, "|")
end
local before = snap(hu, sUser)
local tries = {
	{ "xp", 100 }, { "dmg", 100 }, { "god", true }, { "heal" }, { "level", 150 }, { "level", 30 }, { "job", 2 }, { "skills", "max" }, { "skills", "reset" }, { "stats", "reset" },
	{ "money", 100000000 }, { "dust", 1000000 }, { "gear", 30, 5, 5 }, { "goods", "potion1", 999 }, { "quests", "fill" }, { "goto", "r1c3" }, { "없는 일" },
}
for _, t in tries do
	table.clear(sent)
	local got = handlers.Admin(pUser, t[1], t[2], t[3], t[4])
	eq(got, nil, "관리자가 아니면 대답이 없다 — " .. t[1])
	eq(snap(hu, sUser), before, "관리자가 아니면 아무것도 바뀌지 않는다 — " .. t[1])
	eq(#sent, 0, "관리자가 아니면 아무것도 보내지 않는다 — " .. t[1])
end

-- ---- 3) 관리자: 내 상태에 admin 칸이 온다 ----
local pAdmin, sAdmin, gotAdmin = enter(OWNER, "해본다9477", "axion")
expect(typeof(gotAdmin.self.admin) == "table" and gotAdmin.self.admin.xp == 1 and gotAdmin.self.admin.dmg == 1 and gotAdmin.self.admin.god == false, "관리자의 상태에는 admin 칸이 있다")
local h = sAdmin.hero
local function ask(what, a, b, c)
	return handlers.Admin(pAdmin, what, a, b, c)
end
local function refused(what, a, b, c, note)
	local was = h.level .. "|" .. h.job .. "|" .. h.money .. "|" .. h.dust .. "|" .. sAdmin.scene
	local got = ask(what, a, b, c)
	expect(typeof(got) == "table" and got.ok == false and typeof(got.msg) == "string" and got.msg ~= "", "거절한다(까닭과 함께) — " .. note)
	eq(h.level .. "|" .. h.job .. "|" .. h.money .. "|" .. h.dust .. "|" .. sAdmin.scene, was, "거절하면 바뀌지 않는다 — " .. note)
end

-- 레벨: 올리고 내린다 — 능력치 · 스킬의 점수가 그 레벨의 것으로 다시 주어진다
local r = ask("level", 30)
expect(r.ok and h.level == 30 and h.xp == 0 and h.job == 1, "Lv.30으로(차수는 그대로 1차)")
eq(h.ap, N.apAt(30), "능력치 점수는 그 레벨까지 받은 만큼(찍지 않은 채로)")
eq(h.hp, h.maxHp, "체력이 다 찬다")
expect(h.quests.job2 == nil and Quests.state(h.quests, h.level, "job2") == "open", "Lv.30의 1차는 전직 퀘스트를 받을 수 있다(저절로 받지는 않는다 — 사제에게 가서 받는다)")
ask("level", 5)
expect(h.level == 5 and h.ap == N.apAt(5), "Lv.5로 내린다")
for _, bad in { 0, N.MAX_LEVEL + 1, 1.5, -3, 0 / 0, math.huge, "30", true } do
	refused("level", bad, nil, nil, "레벨 " .. tostring(bad))
end
-- 차수: 그 레벨이 되어야 한다
refused("job", 2, nil, nil, "Lv.5에 2차")
ask("level", 60)
r = ask("job", 3)
expect(r.ok and h.job == 3, "Lv.60에 3차로")
r = ask("job", 1)
expect(r.ok and h.job == 1 and h.level == 60, "차수를 내린다(레벨은 그대로)")
for _, bad in { 0, 5, 2.5, "2" } do
	refused("job", bad, nil, nil, "차수 " .. tostring(bad))
end
-- 스킬 · 능력치
ask("job", 2)
ask("skills", "max")
local maxed = 0
for _, tier in CLASSES.classes.axion.tiers do
	if tier.job <= 2 then
		for _, sk in tier.skills do
			if Hero.ready(sk.id) then
				expect(h.skills[sk.id] == sk.max, "모두 마스터 " .. sk.id)
				maxed += 1
			end
		end
	end
end
expect(maxed >= 6, "1 · 2차의 스킬을 봤다")
ask("skills", "reset")
local spent = 0
for _, lv in h.skills do
	spent += lv
end
expect(spent <= 12, ("스킬을 되돌리면 차수가 주는 레벨 1만 남는다(%d)"):format(spent))
handlers.StatAuto(pAdmin)
expect(h.ap == 0, "능력치를 찍었다")
ask("stats", "reset")
eq(h.ap, N.apAt(60), "능력치를 되돌리면 점수를 모두 돌려받는다")
-- 경험치 배율: 표에 있는 값만 · 받는 경험치에 그대로 곱한다
refused("xp", 3, nil, nil, "표에 없는 배율")
refused("xp", 1000, nil, nil, "큰 배율")
ask("level", 10)
ask("xp", 10)
eq(h.xpBoost, 10, "경험치 x10")
Hero.gainXp(h, 7)
eq(h.xp, 70, "받는 경험치가 열 배")
ask("xp", 1)
eq(h.xpBoost, nil, "x1이면 끈다")
-- 피해 배율: 피해의 셈에만 — 보이는 전투력은 그대로
local shown, raw = Hero.power(h), Hero.powerRaw(h)
ask("dmg", 20)
expect(math.abs(Hero.powerRaw(h) - raw * 20) < 0.001 and Hero.power(h) == shown, "피해 x20 — 보이는 전투력과 순위는 그대로")
refused("dmg", 7, nil, nil, "표에 없는 피해 배율")
ask("dmg", 1)
-- 무적 · 체력
ask("god", true)
eq(Hero.hurt(h, 99999), 0, "무적이면 맞지 않는다")
ask("god", false)
h.invuln = 0 -- 맵에 들어선 뒤의 보호 시간을 지운다
expect(Hero.hurt(h, 10) > 0, "끄면 다시 맞는다")
h.invuln = 0
Hero.hurt(h, 999999)
expect(not h.alive, "쓰러뜨려 본다")
r = ask("heal")
expect(r.ok and h.alive and h.hp == h.maxHp, "체력 채우기는 쓰러진 캐릭터도 일으킨다")
-- 달돈 · 달가루
local m0, d0 = h.money, h.dust
ask("money", 1000000)
ask("dust", 10000)
expect(h.money == m0 + 1000000 and h.dust == d0 + 10000, "달돈과 달가루")
for _, bad in { 0, -5, 100000001, 2.5, "100" } do
	refused("money", bad, nil, nil, "달돈 " .. tostring(bad))
end
refused("dust", 1000001, nil, nil, "달가루가 너무 많다")
-- 장비 한 벌: 단계 · 성능 · 별의 범위
local used = Bag.used(h, "gear")
r = ask("gear", 30, 5, 5)
expect(r.ok and Bag.used(h, "gear") == used + #Items.data.GEAR, "Lv.30 장비 다섯 부위가 가방에 들어온다")
local found = 0
for i = 1, Bag.size(h) do
	local it = h.gear[i]
	if it and it.stage == 30 and it.q == 5 and it.star == 5 then
		found += 1
	end
end
eq(found, #Items.data.GEAR, "그 단계 · 성능 · 별이다")
refused("gear", 31, 3, 0, "없는 단계")
refused("gear", 30, 6, 0, "없는 성능")
refused("gear", 30, 3, Items.starCap(30) + 1, "그 단계의 상한을 넘는 별")
refused("gear", 30, 3, -1, "음수의 별")
for _ = 1, 20 do
	ask("gear", 1, 1, 0)
end
refused("gear", 1, 1, 0, "가방이 가득 차면")
-- 소비 · 기타 아이템
local p0 = Bag.count(h, "potion1")
r = ask("goods", "potion1", 50)
expect(r.ok and Bag.count(h, "potion1") == p0 + 50, "물약 50병")
refused("goods", "없는아이템", 1, nil, "없는 아이템")
refused("goods", "potion1", 1000, nil, "너무 많은 수")
refused("goods", "potion1", 0, nil, "0개")
refused("goods", 12345, 1, nil, "이름표가 글이 아니다")
-- 맵 이동
r = ask("goto", "r1b2")
expect(r.ok and sAdmin.scene == "r1b2", "굽잇길로 옮긴다")
refused("goto", "없는맵", nil, nil, "없는 맵")
refused("goto", 123, nil, nil, "맵의 이름표가 글이 아니다")
-- 퀘스트의 할 일 채우기
ask("level", 30)
expect(h.job == 1 and h.quests.job2 == nil and Quests.state(h.quests, h.level, "job2") == "open", "차수를 내린 뒤 Lv.30이 되면 전직 퀘스트를 다시 받을 수 있다")
expect(Quests.accept(h.quests, h.level, "job2"), "전직 퀘스트를 받아 둔다")
r = ask("quests", "fill")
expect(r.ok and Quests.state(h.quests, h.level, "job2") == "ready", "하는 중인 전직 퀘스트의 할 일이 찬다(돌려주러 간다)")
refused("quests", "모두 끝내기", nil, nil, "모르는 일")
refused("없는 일", nil, nil, nil, "모르는 명령")

-- ---- 4) 시험용 값은 저장되지 않는다 ----
ask("xp", 50)
ask("dmg", 100)
ask("god", true)
local packed = Hero.pack(h)
expect(packed.xpBoost == nil and packed.dmgBoost == nil and packed.god == nil and packed.admin == nil, "배율 · 무적은 저장하지 않는다")
local back = Hero.unpack(OWNER, packed)
expect(back ~= nil and back.xpBoost == nil and back.dmgBoost == nil and back.god == nil, "다시 들어오면 꺼져 있다")

-- ---- 5) 관리자의 명령이 다른 사람에게 새지 않는다 ----
eq(snap(hu, sUser), before, "관리자가 무엇을 해도 다른 사람은 그대로다")

-- ---- 6) 관리 창을 화면 없이 돌려 본다(client/lune/ui/adminWindow.luau): 네 탭의 단추를 모두 눌러 서버까지 — 관리자면 모두 대답이 오고, 관리자가 아니면 하나도 듣지 않는다 ----
do
	local pixelText = req("Client/ui/pixelText")
	local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
	pixelText.Register("small", KIT.font.small, {})
	pixelText.Register("body", KIT.font.body, {})
	local buttons = {} -- 지금 그려진 단추들 { text, w, font, click }
	local tabClicks = {} -- 탭의 이름 → 눌렀을 때
	local status = nil -- 아래 줄의 글
	local function frame(name: string?)
		local f = { Name = name or "Frame" }
		function f:Destroy()
			self.destroyed = true
			if self.Name == "Page" then
				table.clear(buttons)
			end
		end
		return f
	end
	local any = setmetatable({}, { __index = function() return "c" end })
	MOCK("Client/lune/ui/ui", {
		COLOR = any,
		measure = function(text: string, font: string?) return (pixelText.Measure(text, font or "small")) end,
		group = function(_, _, _, _, _, name) return frame(name) end,
		line = function() return frame("Line") end,
		tab = function(_, text, _, _, onClick)
			tabClicks[text] = onClick
			local t = { width = 30 }
			function t.setOn() end
			return t
		end,
		text = function(_, text, _, _, width)
			local item = { value = text, width = width }
			function item.set(_, v) item.value = v end
			function item.color() end
			function item.show() end
			if status == nil and text == "관리자에게만 보이는 창이다" then
				status = item
			end
			return item
		end,
		button = function(_, text, x, y, w, onClick, opts)
			local font = if opts and opts.font then opts.font elseif opts and opts.h and opts.h < 26 then "small" else "body"
			table.insert(buttons, { text = text, x = x, w = w, font = font, click = onClick })
			return { frame = frame("Button") }
		end,
	})
	local AdminWindow = req("Client/lune/ui/adminWindow")
	local w, hgt = AdminWindow.size()
	expect(w + 36 <= 768 and hgt + 64 <= 432, "관리 창이 스마트폰의 화면 틀(768x432)에 들어간다")
	-- 이동 탭의 맵 묶음: 게임의 모든 장면이 한 번씩
	local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
	local places, count = {}, 0
	for _, g in AdminWindow.places() do
		for _, at in g.list do
			expect(SCENES.scenes[at.key] ~= nil and places[at.key] == nil, "이동 탭의 맵 " .. at.key)
			places[at.key] = true
			count += 1
		end
	end
	local total = 0
	for _ in SCENES.scenes do
		total += 1
	end
	eq(count, total, "모든 장면으로 옮겨 갈 수 있다")
	for _, g in AdminWindow.goods() do
		expect(Items.goods(g.id) ~= nil and g.n >= 1 and g.n <= 999, "받을 수 있는 아이템 " .. g.id)
	end

	local shown, showCalls = 75, 0 -- 「보스 크기」 미리보기(화면 쪽만 — 서버에 묻지 않는다)
	local function run(player, expectAnswer: boolean)
		local calls, answered = 0, 0
		local ctx = {
			bossShow = function(v: number?)
				if v then
					shown = v
					showCalls += 1
				end
				return shown
			end,
			me = function()
				local sess = World.session(player)
				return { level = sess.hero.level, job = sess.hero.job, admin = if expectAnswer then { xp = 1, dmg = 1, god = false } else nil }
			end,
			admin = function(what, a, b, c)
				calls += 1
				local got = handlers.Admin(player, what, a, b, c)
				if got ~= nil then
					answered += 1
					expect(typeof(got.msg) == "string" and got.msg ~= "", "서버의 대답에 글이 있다 — " .. tostring(what))
				end
				return got
			end,
		}
		table.clear(buttons)
		status = nil
		local view = AdminWindow.build(frame("Body"), ctx, w, hgt)
		for _, t in AdminWindow.TABS do
			tabClicks[t.name]()
			-- 단추의 글이 단추 안에 들어간다 · 단추가 창 밖으로 나가지 않는다
			for _, b in buttons do
				expect(pixelText.Measure(b.text, b.font) <= b.w - 6, ("단추의 글이 단추에 들어간다 「%s」(%d / %d)"):format(b.text, pixelText.Measure(b.text, b.font), b.w - 6))
				expect(b.x >= 0 and b.x + b.w <= w, ("단추가 창 안이다 「%s」(%d ~ %d)"):format(b.text, b.x, b.x + b.w))
			end
			-- 그려진 단추를 차례로 모두 누른다(누르면 다시 그려지는 단추도 있어 이름으로 다시 찾는다)
			local names = {}
			for _, b in buttons do
				table.insert(names, b.text)
			end
			expect(#names >= 3, "탭에 단추가 있다 " .. t.name)
			for _, name in names do
				for _, b in buttons do
					if b.text == name then
						b.click()
						break
					end
				end
			end
		end
		view.destroy()
		return calls, answered
	end
	-- 관리자: 누른 만큼 서버가 대답한다
	local calls, answered = run(pAdmin, true)
	expect(showCalls == #AdminWindow.BOSS_SHOW and shown == AdminWindow.BOSS_SHOW[#AdminWindow.BOSS_SHOW], ("「보스 크기」의 단추마다 그림의 크기를 바꾼다(%d번 · 마지막 %d%%)"):format(showCalls, shown))
	expect(calls >= 40 and answered == calls, ("관리자가 누른 단추는 모두 서버가 대답한다(%d번 가운데 %d번)"):format(calls, answered))
	-- 관리자가 아닌 사람이 이 창을 억지로 띄워 모든 단추를 눌러도: 서버는 하나도 듣지 않고, 그 사람은 그대로다
	local was = snap(hu, sUser)
	calls, answered = run(pUser, false)
	expect(calls >= 40 and answered == 0, ("관리자가 아닌 사람이 누른 단추는 하나도 듣지 않는다(%d번 가운데 %d번)"):format(calls, answered))
	eq(snap(hu, sUser), was, "그 사람은 그대로다")
	expect(status ~= nil and status.value:find("관리자가 아니다", 1, true) ~= nil, "창에는 「서버가 듣지 않았다」고 뜬다")
end

-- ---- 7) 관리 이동 뒤에 문을 지난다(2026-10-11 — 사용자: "어드민 기능으로 이동후에 포탈이용 불가능합니다. 똑바로 만드세요") ----
do
	local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
	local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
	ask("heal")
	ask("god", false)
	-- (가) 옮긴 직후: 옮겨지기 전에 떠난 늦은 자리 보고(옛 장면의 자리)가 뒤따라 와도 받지 않는다 — 새 장면의 시작 자리에 그대로 서 있다
	expect(ask("goto", "hunt").ok, "달그림자 사냥터로 옮긴다")
	local hunt = SCENES.scenes.hunt
	expect(sAdmin.scene == "hunt" and h.x == hunt.spawn.x and h.y == hunt.spawn.y, "그 장면의 시작 자리에 선다")
	expect(h.invuln >= 10, "화면이 열릴 때까지(막을 치고 그림을 불러온다) 피해를 받지 않는다 " .. h.invuln)
	handlers.Move(pAdmin, hunt.spawn.x + 400, hunt.spawn.y, 1)
	expect(h.x == hunt.spawn.x and h.y == hunt.spawn.y, "늦은 보고를 새 장면의 자리로 믿지 않는다")
	expect(h.invuln >= 10, "늦은 보고는 화면이 열린 것으로 치지 않는다")
	-- (나) 화면이 열렸다: 시작 자리에서의 첫 보고부터 받고, 거기서부터 보통의 들어선 뒤 보호를 센다
	handlers.Move(pAdmin, hunt.spawn.x + 2, hunt.spawn.y, 1)
	eq(h.x, hunt.spawn.x + 2, "도착한 자리의 보고를 받는다")
	eq(h.invuln, COMBAT.rules.arrive, "화면이 열린 때부터 들어선 뒤의 보호")
	handlers.Move(pAdmin, hunt.spawn.x + 60, hunt.spawn.y, 1)
	eq(h.x, hunt.spawn.x + 60, "그 뒤로는 걷는 대로 받는다")
	-- 문으로 옮겼을 때도 화면이 열릴 때까지 보호한다(첫 기술이 와도 열린 것으로 친다)
	expect(ask("goto", "r1a1").ok, "마을 어귀로")
	expect(h.invuln >= 10, "옮긴 뒤의 긴 보호")
	handlers.Skill(pAdmin, "ax_slam", 1, h.x, h.y, 1)
	expect(h.invuln <= COMBAT.rules.arrive, "기술을 쓰면(화면이 열렸다) 긴 보호가 끝난다 " .. h.invuln)
	-- (다) 모든 장면: 관리로 옮긴 뒤 걸어서(한 번의 보고에 가로 60점 · 세로 120점까지) 문마다 가서 지난다
	local count = 0
	for key, sc in SCENES.scenes do
		for _, portal in sc.portals do
			local r = ask("goto", key)
			expect(r ~= nil and r.ok and SCENES.base(sAdmin.scene) == key, "옮긴다 " .. key) -- (파티마다 따로 들어가는 장면이면 그 방 — r1c4#번호 · 2026-10-21)
			local here = sAdmin.scene
			handlers.Move(pAdmin, sc.spawn.x, sc.spawn.y, 1) -- 화면이 열렸다(도착 보고)
			local guard = 0
			while (math.abs(h.x - portal.x) > 1 or math.abs(h.y - portal.y) > 1) and guard < 400 do
				guard += 1
				sAdmin.trust = true -- (시간을 흘리지 않고 걷는다 — 이동 몫을 셈하지 않게)
				handlers.Move(pAdmin, h.x + math.clamp(portal.x - h.x, -60, 60), h.y + math.clamp(portal.y - h.y, -120, 120), 1)
			end
			expect(math.abs(h.x - portal.x) <= 1 and math.abs(h.y - portal.y) <= 1, ("%s: 문 %s 앞까지 걸어간다(%d, %d)"):format(key, portal.to, h.x, h.y))
			-- 퀘스트를 받아야 열리는 문(need — 달의 사당 안의 「사당 지하」): 받기 전에는 지나가지 못하고, 받은 뒤에는 지난다
			if portal.need then
				-- need = 퀘스트의 이름표 하나 또는 여럿(그 가운데 하나라도 받으면 열린다)
				local needs = if typeof(portal.need) == "table" then portal.need else { portal.need }
				local kept = {}
				for _, id in needs do
					kept[id] = h.quests[id]
					h.quests[id] = nil
				end
				expect(handlers.Travel(pAdmin, portal.to) == nil and sAdmin.scene == here, ("%s: 퀘스트 %s를 받기 전에는 문 %s을 지나가지 못한다"):format(key, table.concat(needs, " · "), portal.to))
				for _, id in needs do
					h.quests[id] = kept[id]
				end
				h.quests[needs[#needs]] = kept[needs[#needs]] or { done = false, c = {} } -- 마지막 것 하나만 받아도 열린다
			end
			if portal.done then
				-- done = 그 퀘스트를 끝내야 열리는 문(초승달 마을의 작은 나루 — 「불타는 마을」): 받기만 해서는 안 열리고, 끝내면 열린다
				h.quests[portal.done] = nil
				expect(handlers.Travel(pAdmin, portal.to) == nil and sAdmin.scene == here, ("%s: 퀘스트 %s가 없으면 문 %s을 지나가지 못한다"):format(key, portal.done, portal.to))
				h.quests[portal.done] = { done = false, c = {} }
				expect(handlers.Travel(pAdmin, portal.to) == nil and sAdmin.scene == here, ("%s: 퀘스트 %s를 받기만 해서는 문 %s이 열리지 않는다"):format(key, portal.done, portal.to))
				h.quests[portal.done] = { done = true, c = {} }
			end
			local Tut = req("ReplicatedStorage/shared/lune/sim/tutorial")
			if key == Tut.SCENE then
				-- 꿈(튜토리얼 — 2026-10-14)의 빛나는 문: 미션을 다 하기 전에는 열리지 않고, 마지막 미션(나가기)의 차례에 지나가면 꿈을 마친다
				h.tut = Tut.new()
				expect(handlers.Travel(pAdmin, portal.to) == nil and sAdmin.scene == here, "꿈의 문은 첫 미션 때는 열리지 않는다")
				h.tut.step = Tut.TOTAL
			end
			local trip = handlers.Travel(pAdmin, portal.to)
			expect(trip ~= nil and SCENES.base(trip.scene) == portal.to and sAdmin.scene == trip.scene, ("%s: 관리로 옮긴 뒤 문 %s을 지난다"):format(key, portal.to))
			if key == Tut.SCENE then
				expect(h.tut.done, "꿈의 문을 지나면 튜토리얼이 끝난다")
			end
			count += 1
		end
	end
	expect(count > 150, "모든 장면의 모든 문을 지나 봤다 " .. count)
	-- (라) 쓰러졌을 때의 「체력 채우기」: 서버가 일으키고, 화면에도 일어났다고 알린다(이것이 없으면 화면은 쓰러진 채 남아 움직이지도 문을 지나지도 못한다)
	h.alive, h.hp = false, 0
	refused("goto", "town", nil, nil, "쓰러져 있으면 옮기지 못한다")
	table.clear(sent)
	local r = ask("heal")
	expect(r.ok and h.alive and h.hp == h.maxHp, "쓰러졌어도 일으켜 체력을 채운다")
	local raised = false
	for _, e in sent do
		raised = raised or (e.name == "Raise" and e.player == pAdmin)
	end
	expect(raised, "화면에 일어났다고 알린다(Raise)")
	expect(ask("goto", "town").ok and sAdmin.scene == "town", "일어난 뒤에는 옮길 수 있다")
end
