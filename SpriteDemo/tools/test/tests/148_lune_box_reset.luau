-- 「달의 계승자」 — 상자 판매 바로잡기를 서버 그대로 돌려 본다(2026-11-10 사용자: "다시 다뺏고 안연상자를 산것보다 카테고리별로 +3인거야 그리고 상자별로 선택상자를 주는걸로").
--  보는 것(server/lune/modules/world.luau · cash.luau · dupfixBuys.luau · shared/lune/sim/cash.luau):
--   판매 기록에 있는 사람(Tuesday — 계정 번호 1275060964)이 들어오면 계정을 읽을 때 한 번: 상자에서 받은 것을 거두고(따로 산 초롱 달토끼는 하나 남김) 보관함에 안 연 상자(산 수 + 3) · 선택 상자 하나씩 ·
--   다시 들어와도 또 하지 않는다 · 안 연 상자를 가방에서 쓰면 뽑기 연출(CashGot) · 선택 상자를 쓰면 고르는 창(가방의 「사용」은 쓰지 않는다) → Cash "pick" = 그것을 받는다
local Cash = req("ReplicatedStorage/shared/lune/sim/cash")
local Account = req("ReplicatedStorage/shared/lune/sim/account")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")

local handlers = {}
local sent = {} -- 서버가 보낸 것들 { name, player, args }
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
local disk, book, saves = {}, {}, 0
MOCK("ServerScriptService/server/lune/modules/store", {
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data)
		disk[id] = data
		saves += 1
		return true
	end,
	loadOld = function() return nil end,
	nameOwner = function(key) return book[key] end,
	claimName = function(key, id) book[key] = id; return true end,
	freeName = function(key) book[key] = nil end,
	rankSet = function() end,
	rankRaise = function() end,
	rankRemove = function() end,
	rankTop = function() return {} end,
	rankInfoSet = function() end,
	rankInfoGet = function() return nil end,
	rankInfoRemove = function() end,
	isOffline = function() return false end,
	bmGiftAdd = function() return true end,
	bmGiftList = function() return true, {} end,
	bmGiftRemove = function() return true end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()

local TUESDAY = 1275060964
local function person(uid: number, name: string)
	local t = { UserId = uid, Name = name, attrs = {} }
	t.SetAttribute = function(self, key, value) self.attrs[key] = value end
	return t
end
local function lastSent(name: string)
	for i = #sent, 1, -1 do
		if sent[i].name == name then
			return sent[i]
		end
	end
	return nil
end
local function boxN(c, id)
	for _, e in c.box do
		if e.id == id then
			return e.n
		end
	end
	return 0
end

-- 저장된 계정: 상자에서 받은 것(펫 · 이름표 · 말풍선 · 데미지 스킨 · 탈것) + 따로 산 초롱 달토끼 + 보관함의 윤슬 조각(겹침에서)
local stored = Account.new()
local b = stored.bm
b.pets.pet_lantern, b.pets.pet_bud = true, true
b.extra.pet_lantern = 1
b.petsOut = { "pet_lantern", "pet_bud" }
b.ntags.ntag_wave, b.ntags.ntag_lotus = true, true
b.ntag = "ntag_wave"
b.bubbles.bub_wave = true
b.dskins.dsk_mint = true
b.mounts.mount_jelly = true
b.mount = "mount_jelly"
table.insert(b.box, { id = "yunseul", n = 7 })
disk[TUESDAY] = Account.pack(stored)

local p = person(TUESDAY, "Tuesday")
handlers.Ready(p)
local made = handlers.Chars(p, "create", "화요일", "axion")
handlers.Chars(p, "enter", made.id)
local s = World.session(p)
local c = s.acct.bm
eq(c.boxReset, 1, "들어오면 바로잡았다")
expect(s.resetNote == true, "세계에 들어오면 알림(boxreset)")
expect(c.pets.pet_lantern and not c.pets.pet_bud and Cash.count(c, "pet_lantern") == 1, "상자의 펫은 거두고 따로 산 초롱 달토끼는 하나 남는다")
expect(not c.ntags.ntag_wave and not c.ntags.ntag_lotus and not c.bubbles.bub_wave and not c.dskins.dsk_mint and not c.mounts.mount_jelly, "상자의 것을 모두 거뒀다")
expect(c.ntag == false and c.mount == false, "낀 이름표 · 고른 탈것을 푼다")
eq(table.concat(Cash.petsOut(c), ","), "pet_lantern", "꺼낸 펫은 가진 것만")
expect(boxN(c, "bm_box_petbox") == 6 and boxN(c, "bm_box_tagskin") == 6 and boxN(c, "bm_box_bubblebox") == 5 and boxN(c, "bm_box_dmgskin") == 4 and boxN(c, "bm_box_mountbox") == 4, "안 연 상자 = 산 수 + 3(펫 6 · 이름표 6 · 말풍선 5 · 데미지 스킨 4 · 탈것 4)")
expect(boxN(c, "bm_pick_petbox") == 1 and boxN(c, "bm_pick_tagskin") == 1 and boxN(c, "bm_pick_bubblebox") == 1 and boxN(c, "bm_pick_dmgskin") == 1 and boxN(c, "bm_pick_mountbox") == 1, "선택 상자 하나씩(상자마다)")
eq(boxN(c, "yunseul"), 0, "보관함의 윤슬 조각을 거뒀다")
local savedPack = disk[TUESDAY]
expect(savedPack and savedPack.bm and savedPack.bm.boxReset == 1, "바로 저장했다")

-- 안 연 상자를 가방에서 쓴다 → 열리고 뽑기 연출(CashGot <상자> { box, n })
expect(Bag.give(s.hero, "bm_box_petbox", 2), "가방에 안 연 상자(보관함에서 받은 셈)")
table.clear(sent)
handlers.Potion(p, "bm_box_petbox")
local got = lastSent("CashGot")
expect(got and got.args[1] == "petbox" and typeof(got.args[2]) == "table" and typeof(got.args[2].box) == "string", "뽑기 연출을 보낸다 — " .. tostring(got and got.args[2] and got.args[2].box))
eq(Bag.count(s.hero, "bm_box_petbox"), 1, "안 연 상자 하나를 썼다")
expect(c.lastBox == nil, "연출에 실은 뒤 지운다")
local opened = got and got.args[2].box
expect(opened and c.pets[opened] == true, "나온 펫이 계정에")
handlers.Potion(p, "bm_box_petbox")
eq(Bag.count(s.hero, "bm_box_petbox"), 0, "둘째도 열었다")

-- 선택 상자: 가방의 「사용」으로는 쓰지 않는다(고르는 창이 연다) · Cash "pick"이 그것을 준다
expect(Bag.give(s.hero, "bm_pick_tagskin", 1), "가방에 선택 상자")
table.clear(sent)
handlers.Potion(p, "bm_pick_tagskin")
local done = lastSent("ItemDone")
expect(done and done.args[1].ok == false, "「사용」으로는 쓰지 않는다(창을 연다)")
eq(Bag.count(s.hero, "bm_pick_tagskin"), 1, "그대로 1개")
local res = handlers.Cash(p, "pick", "ntag_royal")
expect(res and res.ok == true and res.picked == "ntag_royal", "황금 왕관 이름표를 골랐다")
expect(c.ntags.ntag_royal == true and Bag.count(s.hero, "bm_pick_tagskin") == 0, "받고 선택 상자를 썼다")
local bad = handlers.Cash(p, "pick", "ntag_royal")
expect(bad and bad.ok == false, "선택 상자가 없으면 못 고른다")

-- 다시 들어와도 또 하지 않는다
local before = boxN(c, "bm_box_tagskin")
handlers.Chars(p, "leave")
local p2 = person(TUESDAY, "Tuesday")
handlers.Ready(p2)
local s2 = World.session(p2)
expect(s2 and s2.acct and s2.acct.bm.boxReset == 1 and boxN(s2.acct.bm, "bm_box_tagskin") == before and not s2.resetNote, "다시 들어와도 그대로(계정에 한 번)")

-- 판매 기록에 없는 사람은 그대로
local q = person(55501, "다른이")
handlers.Ready(q)
local sq = World.session(q)
expect(sq and sq.acct and (sq.acct.bm.boxReset or 0) == 0 and #sq.acct.bm.box == 0, "판매 기록에 없는 사람은 그대로")
