-- 「달의 계승자」 — 윤슬 조각의 큐브 창(2026-11-10 사용자: "윤슬조각 돌리는거 왜 비포, 에프터 선택이 없는데? 메이플 큐브 ui 처럼 되어야하는거야"). 보는 것:
--  ① 서버(world.luau Item "reroll" · "rerollPick"): 굴리면 조각 하나를 쓰고 AFTER를 돌려주지만 장비는 그대로 · 「AFTER 적용」이면 바뀐다 · 「BEFORE 유지」면 그대로 ·
--     「한 번 더」는 조각 하나를 더 쓰고 AFTER만 새로 · 굴린 것이 없는데 고르면 아무 일도 없다 · 조각이 없으면 굴리지 못한다
--  ② 창(client/lune/ui/cubeWindow.luau): 굴린 것이 없으면 「재설정」 하나 · 있으면 「BEFORE 유지」 「AFTER 적용」 「한 번 더」 · BEFORE · AFTER의 줄
local Items = req("ReplicatedStorage/shared/lune/sim/items")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local W = Items.EXTRA.words
local TOOL = Items.EXTRA.reroll.id

-- ① 서버
local sent = {}
local handlers = {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, v)
		if name == "ItemDone" then
			table.insert(sent, v)
		end
	end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
SERVICE("MessagingService", { PublishAsync = function() end, SubscribeAsync = function() end })
local function signal()
	return { Connect = function() end }
end
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk = {}
MOCK("ServerScriptService/server/lune/modules/store", setmetatable({
	lock = function() return true end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, v) disk[id] = v return true end,
	loadOld = function() return nil end,
	nameOwner = function() return nil end,
	claimName = function() return true end,
	rankTop = function() return {} end,
	rankInfoGet = function() return nil end,
	isOffline = function() return false end,
}, { __index = function() return function() return nil end end }))
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local p = { UserId = 9301, Name = "큐브", DisplayName = "큐브", attrs = {} }
p.SetAttribute = function(self, k, v) self.attrs[k] = v end
p.Kick = function() end
local r = handlers.Ready(p)
local cid = r and r.select and r.select.chars[1] and r.select.chars[1].id
if not cid then
	local m = handlers.Chars(p, "create", "큐브", "axion")
	cid = m and m.id
end
handlers.Chars(p, "enter", cid)
local s = World.session(p)
local h = s.hero
local it = Items.make("weapon", 150, 2, "axion")
it.ex = Items.rollExtra(150) -- (떨어질 때 굴리는 추가 옵션 — make는 굴리지 않는다)
local at = Bag.add(h, it)
expect(at ~= nil, "가방에 Lv.150 장비")
it = h.gear[at]
Bag.give(h, TOOL, 3)
local function exKey(ex)
	local out = {}
	for _, e in ex or {} do
		table.insert(out, e.k .. "=" .. e.v)
	end
	return table.concat(out, ",")
end
local before = exKey(it.ex)
local function last()
	return sent[#sent]
end
handlers.Item(p, "reroll", it.id)
local d = last()
expect(d and d.action == "reroll" and d.ok, "굴린다")
eq(Bag.count(h, TOOL), 2, "조각 하나를 썼다")
eq(exKey(it.ex), before, "굴려도 장비는 그대로(AFTER는 아직)")
expect(d.result and d.result.id == it.id and exKey(d.result.before) == before and #d.result.after == #it.ex, "BEFORE = 지금 옵션 · AFTER = 같은 줄 수의 새 옵션")
local after1 = exKey(d.result.after)
handlers.Item(p, "rerollPick", it.id, "before")
eq(exKey(it.ex), before, "「BEFORE 유지」: 그대로")
expect(last().ok and last().result.pick == "before", "BEFORE를 골랐다고 알린다")
handlers.Item(p, "rerollPick", it.id, "after")
expect(not last().ok, "고를 것이 없으면(이미 골랐다) 아무 일도 없다")
eq(exKey(it.ex), before, "그대로")
handlers.Item(p, "reroll", it.id)
handlers.Item(p, "reroll", it.id) -- 한 번 더
eq(Bag.count(h, TOOL), 0, "한 번 더 = 조각 하나 더")
local after2 = exKey(last().result.after)
handlers.Item(p, "rerollPick", it.id, "after")
eq(exKey(it.ex), after2, "「AFTER 적용」: 마지막으로 굴린 AFTER가 들어간다")
local _ = after1
handlers.Item(p, "reroll", it.id)
expect(not last().ok and last().why == W.noTool, "조각이 없으면 굴리지 못한다")
World.removePlayer(p)

-- ② 창
RESET()
local texts, buttons = {}, {}
local function frame(name)
	local f = { Name = name, Visible = true }
	function f:Destroy() end
	return f
end
MOCK("Client/lune/ui/ui", {
	COLOR = setmetatable({}, { __index = function() return Color3.fromRGB(1, 2, 3) end }),
	group = function() return frame("Group") end,
	line = function() return frame("Line") end,
	text = function(_, t)
		local o = { value = t }
		table.insert(texts, o)
		function o.size() return 10, 14 end
		return o
	end,
	button = function(_, label, x, y, w, fn, opts)
		local b = { label = label, click = fn, frame = frame("Button"), main = opts and opts.main }
		function b.setEnabled(_, on) b.on = on end
		table.insert(buttons, b)
		return b
	end,
})
MOCK("Client/lune/ui/itemCell", {
	size = function() return 30 end,
	new = function() local c = { frame = frame("Cell") } function c.set() end return c end,
	label = function() return "달빛 장검" end,
	color = function() return Color3.fromRGB(1, 2, 3) end,
})
local Cube = req("Client/lune/ui/cubeWindow")
local wi = Items.make("weapon", 150, 2, "axion")
wi.ex = Items.rollExtra(150)
wi.id = 77
local bag = { gear = { wi }, equip = {}, use = {}, etc = { { item = TOOL, n = 2 } }, size = 24 } -- (윤슬 조각 = 「기타」 탭)
local pend = nil
local calls = {}
local ctx = {
	bag = function() return bag end,
	reroll = function() return pend end,
	send = function(...) table.insert(calls, { ... }) end,
}
local w, hh = Cube.size()
local view = Cube.build(frame("Body"), ctx, w, hh, 77)
local function labels()
	local out = {}
	for _, b in view.buttons do
		table.insert(out, b.text)
	end
	return table.concat(out, "|")
end
eq(labels(), W.roll, "굴린 것이 없으면 「재설정」 하나")
expect(view.buttons[1].on == true, "조각이 있으면 누를 수 있다")
view.buttons[1].fn()
expect(calls[1][2] == "reroll" and calls[1][3] == 77, "「재설정」 → 서버에 굴리기")
pend = { id = 77, before = wi.ex, after = Items.rollExtra(150) }
table.clear(texts)
view.refresh()
eq(labels(), table.concat({ W.keepBefore, W.useAfter, W.again }, "|"), "굴린 것이 있으면 BEFORE 유지 · AFTER 적용 · 한 번 더")
local seen = {}
for _, t in texts do
	seen[t.value] = true
end
expect(seen[W.before] and seen[W.after], "BEFORE · AFTER 머리")
view.buttons[2].fn()
expect(calls[#calls][2] == "rerollPick" and calls[#calls][4] == "after", "「AFTER 적용」 → 서버에 after")
view.buttons[1].fn()
expect(calls[#calls][2] == "rerollPick" and calls[#calls][4] == "before", "「BEFORE 유지」 → before")
bag.etc = {}
view.refresh()
expect(view.buttons[3].on == false, "조각이 없으면 「한 번 더」를 누를 수 없다")
