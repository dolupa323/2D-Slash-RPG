-- 「달의 계승자」 — 키 설정 · 퀵슬롯이 다시 들어와도 남는가.
--  사용자 2026-10-12: "지금 키세팅을하고 다시접속하면 키세팅이 초기화됩니다."
--  서버의 길 그대로(Keys · Slots · TouchSlots → 저장 → 나갔다 들어옴 → Chars enter가 돌려주는 것)를 따라가 본다.
--  저장소는 로블록스의 DataStore처럼 값을 JSON으로 한 번 거친다(표가 그대로 남는 가짜 저장소로는 드러나지 않는 것이 있다).
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Quick = req("ReplicatedStorage/shared/lune/ui/quick")
local DT = 1 / 20

-- DataStore가 하는 일의 흉내: 차례로 놓인 표(1..n)는 배열로, 그 밖의 표는 이름표가 글자인 표로(숫자 이름표는 글자가 된다). nil은 사라진다
local function json(v)
	if typeof(v) ~= "table" then
		return v
	end
	local n = 0
	for _ in v do
		n += 1
	end
	local array = n > 0 and #v == n
	local out = {}
	for k, x in v do
		out[if array then k else tostring(k)] = json(x)
	end
	return out
end

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
local failRead = {} -- [사람] = true — 그 사람의 계정을 읽지 못한다(2026-10-18)
local slow, order = 0, {} -- slow = 저장소가 쓰는 데 걸리는 시간(초 — 진짜 저장소는 기다리게 한다) · order = 저장소에 쓴 차례
MOCK("ServerScriptService/server/lune/modules/store", {
	loadAccount = function(id)
		if failRead[id] then
			return nil, true -- 저장소가 답하지 않았다(라이브)
		end
		return json(disk[id]), false
	end,
	saveAccount = function(id, data)
		local copy = json(data) -- 부른 순간의 값
		if slow > 0 then
			task.wait(slow)
		end
		disk[id] = copy
		table.insert(order, "account")
		return true
	end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankRaise = function() end,
	rankSet = function()
		if slow > 0 then
			task.wait(slow)
		end
		table.insert(order, "rank")
	end,
	rankRemove = function() end,
	rankTop = function() return {} end,
	rankInfoSet = function()
		table.insert(order, "rank")
	end,
	rankInfoGet = function() return nil end,
	rankInfoRemove = function() end,
	isOffline = function() return false end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()

local function same(a, b): boolean
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end
local function show(t): string
	local parts = {}
	for k, v in t do
		table.insert(parts, tostring(k) .. "=" .. tostring(v))
	end
	table.sort(parts)
	return "{" .. table.concat(parts, " ") .. "}"
end

for ci, class in { "riven", "axion", "mooni" } do
	local p = { UserId = 5100 + ci, Name = "키" .. ci, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", "키설정" .. ci, class)
	expect(made and made.ok, class .. ": 캐릭터를 만든다")
	local got = handlers.Chars(p, "enter", made.id)
	expect(got ~= nil and got.self ~= nil, class .. ": 들어간다")
	expect(next(got.self.keys) == nil, class .. ": 처음에는 바꾼 키가 없다")
	local slots0 = got.self.slots
	eq(#slots0, Quick.N, class .. ": 퀵슬롯의 칸 수")

	-- 키를 바꾼다(키 설정 창이 보내는 꼴 그대로 — 기본과 다른 것만)
	local keys = { ["slot:1"] = "T", ["slot:2"] = "LeftControl", jump = "X", ["win:bag"] = "B", pickup = "Space" }
	handlers.Keys(p, keys)
	expect(same(World.session(p).hero.keys, keys), class .. ": 서버가 바꾼 키를 받아 둔다")
	-- 퀵슬롯을 바꾼다: 둘째 칸의 것을 일곱째 칸으로 옮기고, 넷째 칸을 비운다
	local slots = table.clone(slots0)
	slots[7], slots[2] = slots[2], false
	slots[4] = false
	local back = handlers.Slots(p, slots)
	expect(same(back, slots), class .. ": 서버가 바꾼 칸들을 받아 둔다 " .. show(back or {}))
	-- 스마트폰의 단추 배치도 따로 바꾼다
	--  (폰에는 칸 1의 단추가 없다 — 2026-10-13. 칸 1에 놓아 보내면 서버가 단추가 있는 빈 칸으로 옮긴다: 40_lune_skill_touch.luau가 본다)
	local tslots = table.clone(slots0)
	tslots[9], tslots[1] = tslots[1], false
	tslots[6], tslots[3] = tslots[3], false
	tslots[13], tslots[14] = "act_jump", "act_interact" -- 폰의 칸 13 · 14 = 점프 · 상호작용(2026-10-21 — 늘 하나씩 있다)
	local tback = handlers.TouchSlots(p, tslots)
	expect(same(tback, tslots), class .. ": 스마트폰의 배치도 받아 둔다")

	-- ① 캐릭터 고르기로 나갔다가 다시 들어온다
	handlers.Chars(p, "leave")
	got = handlers.Chars(p, "enter", made.id)
	expect(same(got.self.keys, keys), class .. ": 캐릭터를 다시 골라 들어와도 바꾼 키가 남는다 — " .. show(got.self.keys))
	expect(same(got.self.slots, slots), class .. ": 캐릭터를 다시 골라 들어와도 퀵슬롯이 남는다 — " .. show(got.self.slots))
	expect(same(got.self.tslots, tslots), class .. ": 스마트폰의 배치도 남는다")

	-- ② 게임에서 나갔다가 다시 접속한다(저장소를 거친다)
	World.removePlayer(p)
	expect(disk[p.UserId] ~= nil, class .. ": 나갈 때 저장된다")
	local first = handlers.Ready(p)
	expect(first ~= nil and first.select ~= nil, class .. ": 다시 접속하면 캐릭터 고르기")
	got = handlers.Chars(p, "enter", made.id)
	expect(got ~= nil and same(got.self.keys, keys), class .. ": 다시 접속해도 바꾼 키가 남는다 — " .. show(got and got.self.keys or {}))
	expect(got ~= nil and same(got.self.slots, slots), class .. ": 다시 접속해도 퀵슬롯이 남는다 — " .. show(got and got.self.slots or {}))
	expect(got ~= nil and same(got.self.tslots, tslots), class .. ": 다시 접속해도 스마트폰의 배치가 남는다")

	-- ③ 키를 바꾼 직후(틈틈이 하는 저장이 돌기 전)에 나가도 남는다
	local keys2 = { ["slot:3"] = "G" }
	handlers.Keys(p, keys2)
	World.removePlayer(p)
	handlers.Ready(p)
	got = handlers.Chars(p, "enter", made.id)
	expect(got ~= nil and same(got.self.keys, keys2), class .. ": 바꾸자마자 나가도 남는다 — " .. show(got and got.self.keys or {}))

	-- ④ 레벨이 오르고 전직한 뒤(스킬이 늘고 물약의 단이 바뀐 뒤)에도 칸들이 남는다
	local h = World.session(p).hero
	Hero.setLevel(h, 32)
	World.session(p).dirty = true
	local slotsNow = table.clone(h.slots)
	World.removePlayer(p)
	handlers.Ready(p)
	got = handlers.Chars(p, "enter", made.id)
	expect(got ~= nil and same(got.self.slots, slotsNow), class .. ": 레벨이 오른 뒤에도 퀵슬롯이 남는다 — " .. show(got and got.self.slots or {}) .. " / 기대 " .. show(slotsNow))
	expect(got ~= nil and same(got.self.keys, keys2), class .. ": 레벨이 오른 뒤에도 바꾼 키가 남는다")
	World.removePlayer(p)
end

-- ---- 바꾸자마자 나가도 남는가(사용자가 겪은 것): 저장소는 쓰는 데 시간이 걸리고, 혼자 하다 나가면 서버가 곧바로 닫힌다 ----
do
	local p = { UserId = 5200, Name = "키닫힘", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", "닫힘시험", "riven")
	handlers.Chars(p, "enter", made.id)
	-- ① 키를 바꾸면 몇 초 안에 저장한다(60초마다 도는 저장을 기다리지 않는다)
	local keys = { ["slot:1"] = "T", jump = "X" }
	handlers.Keys(p, keys)
	World.saveDue()
	expect(disk[p.UserId] == nil or not same(disk[p.UserId].chars and disk[p.UserId].chars[1] and disk[p.UserId].chars[1].hero.keys, keys), "바꾼 바로 그 순간에는 아직 쓰지 않는다(연달아 바꾸는 동안 한 번만 쓰게)")
	advance(5)
	World.saveDue()
	local function savedKeys()
		local acct = disk[p.UserId]
		for _, c in (acct and acct.chars) or {} do
			if c.id == made.id then
				return c.hero.keys
			end
		end
		return nil
	end
	expect(same(savedKeys(), keys), "키를 바꾸면 몇 초 안에 저장된다 — " .. show(savedKeys() or {}))
	-- 퀵슬롯도 같다
	local slots = table.clone(World.session(p).hero.slots)
	slots[8], slots[2] = slots[2], false
	handlers.Slots(p, slots)
	advance(5)
	World.saveDue()
	local saved
	for _, c in disk[p.UserId].chars do
		saved = if c.id == made.id then c.hero.slots else saved
	end
	expect(same(saved, slots), "퀵슬롯을 바꿔도 몇 초 안에 저장된다")
	-- ② 저장의 차례: 계정을 먼저 쓰고 순위판은 그 뒤에(서버가 닫히는 중에 순위판을 쓰느라 계정이 밀리지 않게)
	table.clear(order)
	Hero.setLevel(World.session(p).hero, 12) -- 순위판에 올릴 것이 생긴다
	World.session(p).dirty = true
	World.saveAll(true)
	expect(order[1] == "account" and table.find(order, "rank") ~= nil, "계정을 먼저 쓰고 순위판은 그 뒤에 쓴다 — " .. table.concat(order, " "))
	-- ③ 바꾸자마자 나가고, 곧바로 서버가 닫힌다: 저장이 다 쓰일 때까지 닫히기를 기다린다
	local keys2 = { ["slot:2"] = "G", pickup = "C" }
	handlers.Keys(p, keys2)
	slow = 3
	local stopped = false
	task.spawn(World.removePlayer, p) -- 나간다(저장소에 쓰는 중 — 3초 걸린다)
	task.spawn(function()
		World.stop() -- 혼자였으니 서버가 닫힌다
		stopped = true
	end)
	expect(not stopped, "나가는 사람의 저장이 끝나기 전에는 서버가 닫히기를 기다린다")
	expect(not same(savedKeys(), keys2), "(아직 쓰는 중)")
	advance(10)
	expect(stopped, "저장이 끝나면 닫힌다")
	expect(same(savedKeys(), keys2), "바꾸자마자 나가도 저장된다 — " .. show(savedKeys() or {}))
	slow = 0
	handlers.Ready(p)
	local got = handlers.Chars(p, "enter", made.id)
	expect(got ~= nil and same(got.self.keys, keys2), "다시 들어오면 바꾼 키 그대로다")
	World.removePlayer(p)
end

-- ---- 소리 설정이 다시 들어와도 남는가(계정의 것 — 캐릭터를 바꿔도 같다) ----
--  사용자 2026-10-13: "소리조절 있어야합니다." 서버의 길 그대로(Sound → 저장 → 나갔다 들어옴 → Ready가 돌려주는 select.sound)를 따라간다
do
	local SOUND = UI.layout.sound
	-- 저장된 소리 설정에는 화면 설정(fx · nums — 2026-10-18)이 늘 실린다(보내지 않았으면 켜짐)
	local function full(t)
		local c = table.clone(t)
		if c.fx == nil then
			c.fx = true
		end
		if c.nums == nil then
			c.nums = true
		end
		if c.lang == nil then
			c.lang = "auto" -- 언어(2026-10-27 영문): 보내지 않았으면 자동
		end
		if c.touch == nil then
			c.touch = "new" -- 폰 단추 배치(2026-10-28): 보내지 않았으면 새 배치
		end
		return c
	end
	local start = { music = SOUND.start, sfx = SOUND.start, on = true }
	local p = { UserId = 5300, Name = "소리", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
	local first = handlers.Ready(p)
	expect(first ~= nil and first.select ~= nil and same(first.select.sound, full(start)), "처음 온 계정은 처음 크기(모두 켬 · 열 칸)")
	-- 캐릭터 고르기 화면에서(캐릭터로 들어가기 전에) 바꿔도 받는다
	handlers.Sound(p, { music = 7, sfx = 3, on = true })
	expect(same(World.session(p).acct.sound, full({ music = 7, sfx = 3, on = true })), "캐릭터 고르기 화면에서 바꾼 것도 받아 둔다")
	local made = handlers.Chars(p, "create", "소리시험", "mooni")
	expect(made and made.ok and same(made.select.sound, full({ music = 7, sfx = 3, on = true })), "캐릭터를 만들어도 그대로다")
	handlers.Chars(p, "enter", made.id)
	local want = { music = 4, sfx = 0, on = false }
	handlers.Sound(p, want)
	expect(same(World.session(p).acct.sound, full(want)), "게임 안에서 바꾼 것을 받아 둔다")
	-- 말이 안 되는 것은 받지 않는다(그 앞의 것이 남는다)
	for i, bad in { { music = 11, sfx = 3, on = true }, { music = -1, sfx = 3, on = true }, { music = 1.5, sfx = 3, on = true }, { music = "7", sfx = 3, on = true },
		{ music = 3, sfx = 3 }, { music = 3, sfx = 3, on = 1 }, {}, { sfx = 5, on = true }, { music = 0 / 0, sfx = 1, on = true } } do
		handlers.Sound(p, bad)
		expect(same(World.session(p).acct.sound, full(want)), ("말이 안 되는 소리 설정 %d은 받지 않는다"):format(i))
	end
	-- ① 캐릭터 고르기로 나가면 그 화면이 받는 것에 들어 있다
	local left = handlers.Chars(p, "leave")
	expect(left ~= nil and left.select ~= nil and same(left.select.sound, full(want)), "캐릭터 고르기로 나가도 그대로다")
	handlers.Chars(p, "enter", made.id)
	-- ② 게임에서 나갔다가 다시 접속한다(저장소를 거친다)
	World.removePlayer(p)
	expect(disk[p.UserId] ~= nil and same(disk[p.UserId].sound, full(want)), "나갈 때 계정에 저장된다 — " .. show(disk[p.UserId] and disk[p.UserId].sound or {}))
	first = handlers.Ready(p)
	expect(first ~= nil and first.select ~= nil and same(first.select.sound, full(want)), "다시 접속해도 소리 설정이 남는다 — " .. show(first and first.select and first.select.sound or {}))
	-- ③ 바꾸면 몇 초 안에 저장한다 · 바꾸자마자 나가도 남는다
	handlers.Chars(p, "enter", made.id)
	local want2 = { music = 9, sfx = 6, on = true }
	handlers.Sound(p, want2)
	advance(6)
	World.saveDue()
	expect(same(disk[p.UserId].sound, full(want2)), "소리 설정을 바꾸면 몇 초 안에 저장된다")
	local want3 = { music = 0, sfx = 10, on = true }
	handlers.Sound(p, want3)
	World.removePlayer(p)
	first = handlers.Ready(p)
	expect(first ~= nil and same(first.select.sound, full(want3)), "바꾸자마자 나가도 남는다")
	World.removePlayer(p)
	-- ④ 소리 설정이 생기기 전에 저장된 계정(sound가 없다): 처음 크기로 읽고, 캐릭터는 그대로다
	local old = { UserId = 5301, Name = "옛소리", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
	local copy = json(disk[p.UserId])
	copy.sound = nil
	disk[old.UserId] = copy
	first = handlers.Ready(old)
	expect(first ~= nil and first.select ~= nil and same(first.select.sound, full(start)), "소리 설정이 없던 저장은 처음 크기로 읽는다")
	eq(#first.select.chars, 1, "그 계정의 캐릭터는 그대로다")
	World.removePlayer(old)
end

-- ---- 계정을 읽지 못했다(라이브의 저장소가 답하지 않는다 — 2026-10-18 검토): 빈 계정으로 들여보내지 않고 내보낸다 · 나갈 때 저장하지 않는다(저장된 것을 덮어쓰지 않게) ----
do
	local kicked = nil
	local p = { UserId = 5400, Name = "못읽음", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function(_, why) kicked = why end }
	disk[5400] = { v = 1, keep = "진짜 계정" }
	failRead[5400] = true
	local first = handlers.Ready(p)
	expect(first == nil and kicked ~= nil, "읽지 못하면 들여보내지 않는다(내보낸다) — " .. tostring(kicked))
	World.removePlayer(p)
	expect(disk[5400] ~= nil and disk[5400].keep == "진짜 계정", "나가며 저장된 것을 덮어쓰지 않는다")
	failRead[5400] = nil
end
