-- 「달의 계승자」 — 여러 개 판매(등급으로 고르기 — 2026-10-23).
--  사용자: "인벤토리에서 모두판매할때 등급에 따라 판매할수있게해줘 낡은만 팔거나, 허름한만 팔거나, 빼어난만 팔거나"
--  보는 것: ① Bag.sellMany(달돈 = 하나씩 판 값의 합 · 되사기 목록 · 겹친 것 · 없는 것은 건너뜀 · 하나도 없으면 안 됨 · 너무 많으면 안 됨)
--   ② 서버(Item "sellMany" — 잡화 상인 앞에서만) ③ 글(단추에 「~다」 없음 · 등급 다섯)
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local UIW = req("ReplicatedStorage/shared/lune/data/ui.generated").words
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")

-- ① 셈
do
	local h = Hero.new(8301, "axion")
	local ids, want = {}, 0
	for i = 1, 5 do
		local it = Items.make("hat", 1, i, nil) -- 등급 1(낡은) ~ 5(빼어난)
		expect(Bag.add(h, it), "장비를 가방에 넣는다 " .. i)
		table.insert(ids, it.id)
		if i <= 3 then
			want += Items.sellPrice(it)
		end
	end
	local money0, back0 = h.money, #(h.buyback or {})
	local got, why, n = Bag.sellMany(h, { ids[1], ids[2], ids[3], ids[2], 999999 })
	eq(n, 3, "셋을 팔았다(겹친 것 · 없는 것은 건너뛴다) — " .. tostring(why))
	eq(got, want, "받은 달돈 = 하나씩 판 값의 합")
	eq(h.money, money0 + want, "달돈이 늘었다")
	eq(#h.buyback - back0, 3, "판 셋이 되사기 목록에 들어갔다")
	for i = 1, 3 do
		expect(Bag.find(h, ids[i]) == nil, "판 장비는 가방에 없다 " .. i)
	end
	expect(Bag.find(h, ids[4]) ~= nil and Bag.find(h, ids[5]) ~= nil, "고르지 않은 둘은 남았다")
	local g2, w2 = Bag.sellMany(h, { 999999 })
	expect(g2 == nil and w2 ~= nil, "가방에 없는 것만이면 안 된다")
	expect(Bag.sellMany(h, "x") == nil, "목록이 아니면 안 된다")
	local many = {}
	for i = 1, Bag.BULK_MAX + 1 do
		many[i] = i
	end
	expect(Bag.sellMany(h, many) == nil, "한 번에 " .. Bag.BULK_MAX .. "개 넘게는 안 된다")
end

-- ③ 글
do
	local W = UIW.bulkSell
	expect(W and W.title and W.go == "판매" and W.stop == "취소", "여러 개 판매의 글 · 단추 「판매」 · 「취소」")
	for _, k in { "go", "stop" } do
		expect(not string.find(W[k], "다$"), "단추에 「~다」를 쓰지 않는다: " .. W[k])
	end
	local names = {}
	for _, q in Items.data.QUALITY do
		table.insert(names, q.name)
	end
	eq(table.concat(names, ","), "낡은,허름한,보통,좋은,빼어난", "등급 단추 다섯(사용자가 말한 낡은 · 허름한 · 빼어난이 들어 있다)")
end

-- ② 서버
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
World.start()
local p = { UserId = 8310, Name = "판매시험", DisplayName = "판매시험", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
handlers.Ready(p)
local made = handlers.Chars(p, "create", "판매시험", "axion")
handlers.Chars(p, "enter", made.id)
World.jump(p, "in_store") -- 초승달 마을의 가게 안(잡화 상인)
local s = World.session(p)
local function lastDone()
	local done = nil
	for _, f in sent do
		if f.name == "ItemDone" and f.player == p then
			done = f.args[1]
		end
	end
	return done
end
do
	local h = s.hero
	local ids = {}
	for i = 1, 3 do
		local it = Items.make("hat", 1, 1, nil)
		Bag.add(h, it)
		table.insert(ids, it.id)
	end
	-- 상인 앞이 아니면 안 된다(가게의 왼쪽 끝)
	h.x = 0
	table.clear(sent)
	handlers.Item(p, "sellMany", ids)
	local d1 = lastDone()
	expect(d1 and not d1.ok and Bag.find(h, ids[1]) ~= nil, "잡화 상인 앞이 아니면 팔지 않는다 — " .. tostring(d1 and d1.why))
	-- 잡화 상인 앞
	local npc = nil
	for _, n in SCENES.scenes.in_store.npcs do
		if Items.data.NPCDO[n.id] == "shop" then
			npc = n -- 잡화 상인(주민마다 하는 일 — NPCDO)
		end
	end
	expect(npc ~= nil, "가게 안에 잡화 상인이 있다")
	if npc then
		h.x, h.y = npc.x, npc.y
		local money0 = h.money
		table.clear(sent)
		handlers.Item(p, "sellMany", ids)
		local d2 = lastDone()
		expect(d2 and d2.ok and d2.action == "sellMany" and d2.result == h.money - money0 and d2.result > 0, "상인 앞에서는 한꺼번에 팔고 받은 달돈을 알린다 — " .. tostring(d2 and d2.why))
		for _, id in ids do
			expect(Bag.find(h, id) == nil, "판 장비는 가방에 없다")
		end
	end
end
World.removePlayer(p)
