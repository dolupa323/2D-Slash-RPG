-- 「달의 계승자」 — 파티 찾기(2026-11-05 사용자 "파티 보스라서 파티구하고 방만들고 막 이런 UI도 있어야해 파티를 구해서 가는거라서" · 고르심: 같은 서버만 · 방장이 수락 · 방장 출발 → 바로 보스 방).
--  보는 것: ① 셈(sim/finder.luau — 방의 사람 = 방장의 파티): 방 만들기(파티장만) · 신청(혼자인 사람 · 조건 레벨 · 한 사람 한 방) · 수락(→ 파티에 든다) · 거절 · 준비 · 출발 조건(둘 이상 · 모두 준비) ·
--   가득 참 · 파티에서 나가면 준비가 지워진다 · 방을 만들면 그 사람의 신청이 거둬진다 · 목록(새 방이 위)
--   ② 창(client/lune/ui/finderWindow.luau)을 화면 없이 지어 본다: 대답 전 「불러오는 중」 · 모집 중의 줄 · 신청 단추 · 내 방(방장 — 신청한 사람 · 수락 · 거절 · 출발은 모두 준비해야 켜진다) · 방 만들기의 단추 셋
local Finder = req("ReplicatedStorage/shared/lune/sim/finder")
local Party = req("ReplicatedStorage/shared/lune/sim/party")
local UIG = req("ReplicatedStorage/shared/lune/data/ui.generated")

-- ---- ① 셈 ----
local pb = Party.newBook()
local P = {
	members = function(uid)
		return Party.members(pb, uid)
	end,
	leader = function(uid)
		local p = Party.of(pb, uid)
		return if p then p.leader else uid
	end,
}
local fb = Finder.new()
local NOW = 1000
local function join(leader, uid)
	assert(Party.invite(pb, leader, uid, NOW))
	assert(Party.accept(pb, uid, NOW))
end

local r1 = Finder.make(fb, P, 1, "lavagiant", "normal", 120)
expect(r1 ~= nil and r1.leader == 1 and r1.minLv == 120, "혼자인 사람이 방을 만든다(방장 = 자기)")
local _, w0 = Finder.make(fb, P, 1, "lavagiant", "normal", 120)
eq(w0, "이미 방이 있다", "방은 하나")
-- 신청
local _, wLow = Finder.apply(fb, P, 2, 1, 110)
eq(wLow, "Lv.120부터 신청한다", "조건 레벨이 모자라면 신청하지 못한다")
expect(Finder.apply(fb, P, 2, 1, 125) ~= nil, "조건이 되면 신청한다")
eq(fb.app[2], 1, "한 사람은 한 방에 신청")
local _, wTwice = Finder.apply(fb, P, 2, 1, 125)
eq(wTwice, "이미 신청했다", "같은 방에 두 번은 안 된다")
-- 다른 방에 신청하면 앞의 신청은 거둬진다
local r9 = Finder.make(fb, P, 9, "thiefboss", "normal", 76)
expect(Finder.apply(fb, P, 2, 9, 125) ~= nil and fb.app[2] == 9 and #r1.apps == 0, "다른 방에 신청하면 앞의 것은 거둬진다")
Finder.close(fb, 9)
eq(fb.app[2], nil, "방이 닫히면 그 방의 신청도 사라진다")
expect(Finder.apply(fb, P, 2, 1, 125) ~= nil, "다시 신청")
-- 수락 → 파티에 든다(서버가 하는 것)
local acc = Finder.accept(fb, P, 1, 2)
expect(acc ~= nil and #r1.apps == 0 and fb.app[2] == nil, "수락하면 신청이 거둬진다")
join(1, 2)
eq(#P.members(1), 2, "수락한 사람은 방장의 파티에 든다 — 방의 사람 = 파티")
expect(Finder.roomOf(fb, P, 2) == r1, "파티원의 방 = 파티장의 방")
-- 파티가 있는 사람은 신청하지 못한다
join(5, 6)
local _, wParty = Finder.apply(fb, P, 6, 1, 130)
eq(wParty, "파티를 나와야 신청한다", "파티가 있으면 나와야 신청한다")
-- 거절
expect(Finder.apply(fb, P, 3, 1, 130) ~= nil, "셋째가 신청")
expect(Finder.deny(fb, 1, 3) ~= nil and fb.app[3] == nil and #r1.apps == 0, "거절하면 신청이 사라진다")
-- 출발 조건
local _, wReady = Finder.check(fb, P, 1)
eq(wReady, "1명이 아직 준비하지 않았다", "파티원이 준비해야 출발한다")
local _, wNotLeader = Finder.check(fb, P, 2)
eq(wNotLeader, "방장만 출발한다", "파티원은 출발하지 못한다")
Finder.setReady(fb, P, 2, true)
local okR, members = Finder.check(fb, P, 1)
expect(okR == r1 and #members == 2, "모두 준비하면 출발할 수 있다(둘)")
Finder.setReady(fb, P, 2, false)
expect(not r1.ready[2], "준비 취소")
-- 가득 참
join(1, 3)
join(1, 4)
eq(#P.members(1), 4, "넷")
local _, wFull = Finder.apply(fb, P, 7, 1, 150)
eq(wFull, "방이 가득 찼다", "넷이면 가득")
-- 파티에서 나가면 준비가 지워진다(sweep)
Finder.setReady(fb, P, 4, true)
Party.leave(pb, 4)
Finder.sweep(fb, P)
expect(not r1.ready[4], "파티를 나간 사람의 준비는 지워진다")
-- 둘 미만이면 출발 못 함
local solo = Finder.make(fb, P, 8, "shadowarcher", "hard", 70)
expect(solo ~= nil, "다른 사람의 방")
local _, wTwo = Finder.check(fb, P, 8)
eq(wTwo, "둘 이상이 모여야 출발한다", "혼자서는 출발하지 못한다")
-- 파티장이 아닌 사람은 방을 만들지 못한다
local _, wMake = Finder.make(fb, P, 2, "lavagiant", "normal", 120)
eq(wMake, "파티장만 방을 만든다", "파티원은 방을 만들지 못한다")
-- 목록: 새 방이 위 · 인원 = 파티
local list = Finder.list(fb, P)
eq(#list, 2, "방 둘")
expect(list[1].leader == 8 and list[2].leader == 1 and list[2].n == 3, "새 방이 위 · 인원 = 그 파티의 수")
-- 방을 만들면 그 사람(들)의 신청은 거둬진다
expect(Finder.apply(fb, P, 10, 8, 80) ~= nil, "열째가 신청")
Finder.make(fb, P, 10, "fallenknight", "normal", 58)
expect(fb.app[10] == nil and #solo.apps == 0, "방을 만들면 신청이 거둬진다")

-- ---- ② 창 ----
local texts, buttons, tabs = {}, {}, {}
local function frame(name)
	local f = { Name = name, Visible = true }
	function f:Destroy()
		f.gone = true
	end
	return f
end
local COLOR = setmetatable({}, { __index = function(_, k)
	return k
end })
MOCK("Client/lune/ui/ui", {
	COLOR = COLOR,
	text = function(parent, value, x, y, width, opts)
		local t = { parent = parent, value = value, x = x, y = y, width = width, opts = opts or {} }
		t.tint = t.opts.color
		function t.set(_, v)
			t.value = v
		end
		function t.color(_, c)
			t.tint = c
		end
		table.insert(texts, t)
		return t
	end,
	group = function(parent, x, y, w, h, name)
		local f = frame(name)
		f.parent, f.x, f.y, f.w, f.h = parent, x, y, w, h
		return f
	end,
	box = function()
		return frame("Box")
	end,
	line = function()
		return frame("Line")
	end,
	tab = function(parent, label, x, y, onClick)
		local it = { frame = frame("Tab"), width = #label * 3, text = label, on = false, click = onClick }
		function it.setOn(_, on)
			it.on = on
		end
		table.insert(tabs, it)
		return it
	end,
	button = function(parent, label, x, y, w, onClick, opts)
		local it = { frame = frame("Button"), text = label, x = x, y = y, w = w, click = onClick, enabled = true, opts = opts or {} }
		function it.setEnabled(_, on)
			it.enabled = on
		end
		table.insert(buttons, it)
		return it
	end,
})
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
local S = Layout.FINDER
local FW = req("Client/lune/ui/finderWindow")
local W = UIG.finder
local answer = nil
local did = {}
local ctx = {
	finder = function()
		return answer
	end,
	finderDo = function(action, a)
		table.insert(did, { action, a })
	end,
}
local w, hgt = FW.size()
eq(w, S.w, "창의 폭 = 공방의 치수")
FW.tab = "list"
local ok, view = pcall(FW.build, frame("Body"), ctx, w, hgt)
expect(ok, "창을 짓는다 " .. tostring(view))
local loading = false
for _, t in texts do
	if t.value == W.loading then
		loading = true
	end
end
expect(loading, "대답 전에는 「불러오는 중」")
local function find(label)
	for _, b in buttons do
		if b.text == label then
			return b
		end
	end
	return nil
end
-- 모집 중
answer = {
	rooms = { { id = 11, boss = "용암 거인", mode = "normal", lv = 120, n = 2, leader = "달그림자", mine = false, applied = false }, { id = 12, boss = "불씨 도둑 두목", mode = "hard", lv = 96, n = 4, leader = "수정바람", mine = false, applied = false } },
	mine = nil, bosses = {}, max = 4, steps = { 0, 10, 20 },
}
texts, buttons, tabs = {}, {}, {}
view.refresh()
eq(#tabs, 2, "탭 둘")
eq(tabs[1].text, W.tabs.list .. " 2", "「모집 중 2」")
eq(tabs[2].text, W.tabs.make, "방이 없으면 둘째 탭 = 「방 만들기」")
local applies = {}
for _, b in buttons do
	if b.text == W.apply then
		table.insert(applies, b)
	end
end
eq(#applies, 2, "방마다 「신청」")
expect(applies[1].enabled and not applies[2].enabled, "가득 찬 방은 신청 단추가 꺼진다")
applies[1].click()
expect(did[#did][1] == "apply" and did[#did][2] == 11, "신청 = 서버에 apply(방장)")
for _, t in texts do
	if t.width then
		expect(t.width > 0 and (t.x or 0) + t.width <= w + 1, "글은 창의 폭 안: " .. tostring(t.value))
	end
end
-- 내 방(방장)
answer = {
	rooms = {}, max = 4, steps = { 0, 10, 20 }, bosses = {},
	mine = { boss = "용암 거인", mode = "normal", lv = 120, lead = true, ready = false,
		members = { { id = 1, name = "나", lv = 130, leader = true, ready = true }, { id = 2, name = "달그림자", lv = 125, leader = false, ready = false } },
		apps = { { id = 3, name = "수정바람", lv = 122, power = 18432 } } },
}
FW.tab = "make"
texts, buttons, tabs = {}, {}, {}
view.refresh()
eq(FW.tab, "room", "방에 들어 있으면 「내 방」 탭")
eq(tabs[2].text, W.tabs.room, "둘째 탭 = 「내 방」")
local start = find(W.start)
expect(start ~= nil and not start.enabled, "파티원이 준비하지 않았으면 「출발」이 꺼져 있다")
expect(find(W.accept) ~= nil and find(W.deny) ~= nil, "신청한 사람마다 「수락」 · 「거절」")
find(W.accept).click()
expect(did[#did][1] == "accept" and did[#did][2] == 3, "수락 = 서버에 accept(사람)")
answer.mine.members[2].ready = true
texts, buttons, tabs = {}, {}, {}
view.refresh()
expect(find(W.start).enabled, "모두 준비하면 「출발」이 켜진다")
find(W.start).click()
eq(did[#did][1], "start", "출발 = 서버에 start")
-- 파티원(방장 아님): 준비 · 방 나가기
answer.mine.lead = false
texts, buttons, tabs = {}, {}, {}
view.refresh()
expect(find(W.readyOn) ~= nil and find(W.leave) ~= nil and find(W.start) == nil, "파티원 = 「준비」 · 「방 나가기」")
find(W.readyOn).click()
expect(did[#did][1] == "ready" and did[#did][2] == true, "준비 = 서버에 ready(true)")
-- 방 만들기
answer = { rooms = {}, mine = nil, max = 4, steps = { 0, 10, 20 }, bosses = { { id = "lavagiant", name = "용암 거인", modes = { "normal" }, need = { normal = 120 } } } }
FW.tab = "make"
texts, buttons, tabs = {}, {}, {}
view.refresh()
expect(find("용암 거인") ~= nil, "보스 단추")
local cond = find("Lv.120부터")
expect(cond ~= nil, "조건 단추 = 입장 레벨부터")
cond.click()
expect(find("Lv.130부터") ~= nil, "조건을 누르면 +10")
find(W.make).click()
expect(did[#did][1] == "make" and did[#did][2] == "lavagiant", "방 만들기 = 서버에 make(보스, 난이도, 조건 단계)")
view.destroy()
