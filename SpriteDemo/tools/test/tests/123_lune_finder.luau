-- 「달의 계승자」 — 파티 찾기(2026-11-05 사용자 "파티 보스라서 파티구하고 방만들고 막 이런 UI도 있어야해" → 같은 날 "메뉴탭에서 접근하는게 아니라 해당 던전에서 파티방을 만드는거야 …
--  로스트아크 파티모집 어떻게하는지 레이드 게임들에서 구인구직을 어떻게 구현하는지 공부하고만들어" · "보스,난이도, 조건 선택을 클랙해서 바꾸는게 어디있어 제발 ui 의 기본은 지키자").
--  보는 것: ① 셈(sim/finder.luau — 방의 사람 = 방장의 파티 · 보스마다 따로): 모집 글 등록(파티장만 · 제목 · 최소 레벨 · 같은 직업) · 참가 신청(혼자인 사람 · 최소 레벨 · 같은 직업 · 한 사람 한 방 ·
--   다른 방에 신청하면 앞의 것은 거둬진다) · 수락 · 거절 · 입장 조건(방장 · 둘 이상) · 가득 참 · 방이 닫히면 신청이 사라진다 · 목록(그 보스만 · 새 방이 위) · 제목 다듬기
--   ② 창(client/lune/ui/finderWindow.luau)을 화면 없이 지어 본다: 대답 전 「불러오는 중」 / 방 목록(위 줄 [모집 글 등록] · 난이도 탭 · 제목 찾기 · 줄을 누르면 고른 방 · [참가 신청] · 까닭) /
--   모집 글 등록(난이도 · 최소 레벨 = 다 늘어놓은 단추 줄 · 같은 직업 체크 · [등록] = make(보스, 난이도, { 제목, 단계, 같은 직업 })) / 파티 대기실(방장 — 멀리 있는 사람이 있으면 [입장] 꺼짐 · 수락 · 거절 / 파티원 — [나가기])
local Finder = req("ReplicatedStorage/shared/lune/sim/finder")
local Party = req("ReplicatedStorage/shared/lune/sim/party")
local UIG = req("ReplicatedStorage/shared/lune/data/ui.generated")

-- ---- ① 셈 ----
local pb = Party.newBook()
local CLASS = { [1] = "riven", [2] = "axion", [3] = "riven", [4] = "reaper", [5] = "sala", [6] = "axion", [7] = "sala", [8] = "reaper", [9] = "axion", [10] = "sala" }
local P = {
	members = function(uid)
		return Party.members(pb, uid)
	end,
	leader = function(uid)
		local p = Party.of(pb, uid)
		return if p then p.leader else uid
	end,
	classOf = function(uid)
		return CLASS[uid]
	end,
}
local fb = Finder.new()
local NOW = 1000
local function join(leader, uid)
	assert(Party.invite(pb, leader, uid, NOW))
	assert(Party.accept(pb, uid, NOW))
end
local function me(uid, level)
	return { level = level, class = CLASS[uid] }
end

local r1 = Finder.make(fb, P, 1, { boss = "lavagiant", mode = "normal", title = "같이 가요", minLv = 120, sameClass = false })
expect(r1 ~= nil and r1.leader == 1 and r1.minLv == 120 and r1.title == "같이 가요" and r1.sameClass == false, "혼자인 사람이 모집 글을 등록한다(방장 = 자기)")
local _, w0 = Finder.make(fb, P, 1, { boss = "lavagiant", mode = "normal", title = "", minLv = 120 })
eq(w0, "이미 모집 중이다", "모집 글은 하나")
-- 신청
local _, wLow = Finder.apply(fb, P, 2, 1, me(2, 110))
eq(wLow, "Lv.120부터 신청한다", "최소 레벨이 모자라면 신청하지 못한다")
local _, wSame = Finder.apply(fb, P, 3, 1, me(3, 130))
eq(wSame, "같은 직업은 받지 않는 방이다", "같은 직업을 받지 않는 방에는 같은 직업이 신청하지 못한다")
expect(Finder.apply(fb, P, 2, 1, me(2, 125)) ~= nil, "조건이 되면 신청한다")
eq(fb.app[2], 1, "한 사람은 한 방에 신청")
local _, wTwice = Finder.apply(fb, P, 2, 1, me(2, 125))
eq(wTwice, "이미 신청했다", "같은 방에 두 번은 안 된다")
eq(Finder.canApply(fb, P, 1, 1, me(1, 130)), "내 방이다", "내 방에는 신청하지 않는다")
-- 다른 방에 신청하면 앞의 신청은 거둬진다
local r9 = Finder.make(fb, P, 9, { boss = "lavagiant", mode = "normal", title = "", minLv = 120, sameClass = true })
expect(Finder.apply(fb, P, 2, 9, me(2, 125)) ~= nil and fb.app[2] == 9 and #r1.apps == 0, "다른 방에 신청하면 앞의 것은 거둬진다")
eq(Finder.canApply(fb, P, 9, 1, me(9, 130)), "모집 중인 방이 있다 — 취소하고 신청한다", "모집 중이면 남의 방에 신청하지 못한다")
Finder.close(fb, 9)
expect(fb.app[2] == nil and r9 ~= nil, "방이 닫히면 그 방의 신청도 사라진다")
expect(Finder.apply(fb, P, 2, 1, me(2, 125)) ~= nil, "다시 신청")
Finder.withdraw(fb, 2)
expect(fb.app[2] == nil and #r1.apps == 0, "참가 취소 = 신청을 거둔다")
expect(Finder.apply(fb, P, 2, 1, me(2, 125)) ~= nil, "또 신청")
-- 수락 → 파티에 든다(서버가 하는 것)
local acc = Finder.accept(fb, P, 1, 2)
expect(acc ~= nil and #r1.apps == 0 and fb.app[2] == nil, "수락하면 신청이 거둬진다")
join(1, 2)
eq(#P.members(1), 2, "수락한 사람은 방장의 파티에 든다 — 방의 사람 = 파티")
expect(Finder.roomOf(fb, P, 2) == r1, "파티원의 방 = 파티장의 방")
local _, wAxion = Finder.apply(fb, P, 6, 1, me(6, 130))
eq(wAxion, "같은 직업은 받지 않는 방이다", "파티원의 직업도 본다(이미 든 액시온)")
-- 파티가 있는 사람은 신청하지 못한다
join(5, 7)
local _, wParty = Finder.apply(fb, P, 7, 1, me(7, 130))
eq(wParty, "파티를 나와야 신청한다", "파티가 있으면 나와야 신청한다")
-- 거절
expect(Finder.apply(fb, P, 4, 1, me(4, 130)) ~= nil, "넷째가 신청")
expect(Finder.deny(fb, 1, 4) ~= nil and fb.app[4] == nil and #r1.apps == 0, "거절하면 신청이 사라진다")
local _, wNoApp = Finder.accept(fb, P, 1, 4)
eq(wNoApp, "신청이 없다", "거절한 사람은 수락할 수 없다")
-- 입장 조건
local okR, members = Finder.check(fb, P, 1)
expect(okR == r1 and #members == 2, "방장 + 둘이면 입장할 수 있다(문 앞은 서버가 본다)")
local _, wNotLeader = Finder.check(fb, P, 2)
eq(wNotLeader, "방장만 입장한다", "파티원은 입장 단추가 없다")
-- 가득 참
join(1, 4)
join(1, 8)
eq(#P.members(1), 4, "넷")
local _, wFull = Finder.apply(fb, P, 10, 1, me(10, 150))
eq(wFull, "방이 가득 찼다", "넷이면 가득")
-- 혼자서는 입장 못 함
local solo = Finder.make(fb, P, 10, { boss = "thiefboss", mode = "hard", title = "", minLv = 96, sameClass = true })
expect(solo ~= nil, "다른 보스의 방")
local _, wTwo = Finder.check(fb, P, 10)
eq(wTwo, "둘 이상이 모여야 입장한다", "혼자서는 입장하지 못한다")
-- 파티장이 아닌 사람은 등록하지 못한다
local _, wMake = Finder.make(fb, P, 2, { boss = "lavagiant", mode = "normal", title = "", minLv = 120 })
eq(wMake, "파티장만 모집 글을 등록한다", "파티원은 등록하지 못한다")
-- 목록: 그 보스만 · 인원 = 파티
local list = Finder.list(fb, P, "lavagiant")
eq(#list, 1, "용암 거인의 방은 하나(도둑 두목의 방은 그쪽 목록에)")
expect(list[1].leader == 1 and list[1].n == 4 and list[1].title == "같이 가요", "인원 = 그 파티의 수 · 제목")
eq(#Finder.list(fb, P, "thiefboss"), 1, "도둑 두목의 방")
-- 새 방이 위
join(3, 5 + 100)
Finder.make(fb, P, 3, { boss = "thiefboss", mode = "normal", title = "", minLv = 76, sameClass = true })
local tl = Finder.list(fb, P, "thiefboss")
expect(#tl == 2 and tl[1].leader == 3 and tl[2].leader == 10, "새 방이 위")
-- 방장이 파티장이 아니게 되면(파티가 흩어졌다) 방이 닫힌다
Party.leave(pb, 3)
local closed = Finder.sweep(fb, P)
expect(#closed == 0 and fb.rooms[3] ~= nil, "혼자 남은 방장은 그대로 파티장 — 방이 남는다")
-- 제목 다듬기
eq(Finder.cleanTitle("  같이\n가요   빨리  "), "같이 가요 빨리", "앞뒤 빈칸 · 줄바꿈 · 겹친 빈칸")
eq(utf8.len(Finder.cleanTitle(string.rep("가", 30))), Finder.TITLE_MAX, "제목은 20자까지")
eq(Finder.cleanTitle(nil), "", "글이 아니면 빈 제목")

-- ---- ② 창 ----
local texts, buttons, tabs, hits, fields = {}, {}, {}, {}, {}
local BODY = nil
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
		if name == "Finder" then
			-- 창이 다시 그린다: 앞의 것을 버린다(늘 있는 글 — 아래 까닭 줄 — 은 남긴다)
			local keep = {}
			for _, t in texts do
				if t.parent == BODY then
					table.insert(keep, t)
				end
			end
			texts, buttons, tabs, hits = keep, {}, {}, {}
		end
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
	hit = function(parent)
		local h = { parent = parent }
		h.Activated = { Connect = function(_, fn)
			h.fn = fn
		end }
		table.insert(hits, h)
		return h
	end,
	field = function(parent, x, y, w, h, placeholder)
		local box = { Text = "", Parent = frame("Field"), placeholder = placeholder, x = x, w = w }
		function box.GetPropertyChangedSignal(_, _prop)
			return { Connect = function(_, fn)
				box.changed = fn
			end }
		end
		table.insert(fields, box)
		return box
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
	finderDo = function(action, a, b, c)
		table.insert(did, { action, a, b, c })
	end,
}
local w, hgt = FW.size()
eq(w, S.w, "창의 폭 = 공방의 치수")
expect(FW.wide == true, "넓은 창(혼자 쓴다)")
local title = FW.title("lavagiant")
expect(title ~= nil and string.find(title, W.title, 1, true) == 1, "창의 제목 = 「파티 찾기 · 그 보스」")
FW.view, FW.filter, FW.sel, FW.page = "list", "all", nil, 1
BODY = frame("Body")
local ok, view = pcall(FW.build, BODY, ctx, w, hgt, "lavagiant")
expect(ok, "창을 짓는다 " .. tostring(view))
local function has(value)
	for _, t in texts do
		if t.value == value then
			return t
		end
	end
	return nil
end
expect(has(W.loading) ~= nil, "대답 전에는 「불러오는 중」")
eq(#fields, 2, "글 칸 둘(제목 찾기 · 모집 글의 제목) — 한 번만 짓는다")
local search, titleBox = fields[1], fields[2]
local function named(name)
	for _, b in buttons do
		if b.frame.Name == name then
			return b
		end
	end
	return nil
end
local function redraw()
	view.refresh()
end
local function withinWindow(what)
	for _, t in texts do
		if t.width then
			expect(t.width > 0 and (t.x or 0) + t.width <= w + 1, what .. " — 글은 창의 폭 안: " .. tostring(t.value))
		end
	end
	for _, b in buttons do
		expect(b.x >= 0 and b.x + b.w <= w + 1, what .. " — 단추는 창의 폭 안: " .. tostring(b.text))
	end
end
local function who(id, name, lv, leader, here)
	return { id = id, name = name, lv = lv, power = 18000 + id, class = "리븐", leader = leader, here = here ~= false }
end
-- 방 목록
local BOSS = { id = "lavagiant", name = "용암 거인", modes = { { id = "normal", need = 120, can = true }, { id = "hard", need = 140, can = false } } }
answer = {
	boss = BOSS, max = 4, steps = { 0, 5, 10, 20 }, mine = nil,
	rooms = {
		{ id = 11, mode = "normal", title = "같이 가요", lv = 120, same = true, n = 2, leader = "달그림자", members = { who(11, "달그림자", 125, true), who(12, "은빛도끼", 122, false) }, applied = false, can = nil },
		{ id = 13, mode = "hard", title = "숙련자만", lv = 150, same = false, n = 4, leader = "수정바람", members = { who(13, "수정바람", 160, true) }, applied = false, can = "방이 가득 찼다" },
	},
}
redraw()
expect(search.Parent.Visible and not titleBox.Parent.Visible, "목록에서는 제목 찾기 칸만 보인다")
expect(named("Do_register") ~= nil and named("Do_register").opts.main, "왼쪽 위 [모집 글 등록]")
eq(#tabs, 3, "난이도 탭 셋(전체 · 노말 · 하드)")
expect(tabs[1].text == W.all and tabs[1].on, "처음은 「전체」")
eq(FW.sel, 11, "고른 방이 없으면 첫 방을 고른다")
local apply = named("Do_apply")
expect(apply ~= nil and apply.text == W.apply and apply.enabled, "고른 방의 [참가 신청]")
apply.click()
expect(did[#did][1] == "apply" and did[#did][2] == 11, "참가 신청 = 서버에 apply(방장)")
expect(has("Lv.122 은빛도끼") ~= nil, "고른 방의 파티원(레벨 · 이름)")
withinWindow("방 목록")
-- 줄을 누르면 그 방을 고른다
local rowHit = nil
for _, h in hits do
	if h.parent and h.parent.Name == "Row2" then
		rowHit = h
	end
end
expect(rowHit ~= nil, "줄마다 누르는 자리")
rowHit.fn()
eq(FW.sel, 13, "둘째 줄을 누르면 그 방")
expect(not named("Do_apply").enabled, "가득 찬 방은 [참가 신청]이 꺼진다")
expect(has("방이 가득 찼다") ~= nil, "까닭이 아래 줄에")
-- 난이도 탭: 하드만
tabs[3].click()
eq(FW.filter, "hard", "「하드」 탭")
local rows = 0
for _, h in hits do
	if h.parent and string.sub(h.parent.Name or "", 1, 3) == "Row" then
		rows += 1
	end
end
eq(rows, 1, "하드 방만 보인다")
tabs[1].click()
-- 제목 찾기(글 칸에 적으면 바로 거른다)
search.Text = "같이"
search.changed()
rows = 0
for _, h in hits do
	if h.parent and string.sub(h.parent.Name or "", 1, 3) == "Row" then
		rows += 1
	end
end
eq(rows, 1, "제목에 「같이」가 든 방만")
search.Text = ""
search.changed()
-- 신청한 방 → [참가 취소]
answer.rooms[1].applied = true
FW.sel = 11
redraw()
expect(named("Do_apply").text == W.cancel and named("Do_apply").enabled, "신청한 방은 [참가 취소]")
named("Do_apply").click()
eq(did[#did][1], "withdraw", "참가 취소 = 서버에 withdraw")
expect(has(W.applied) ~= nil, "목록의 줄에 「신청함」")
answer.rooms[1].applied = false
-- 모집 글 등록
named("Do_register").click()
eq(FW.view, "form", "[모집 글 등록]을 누르면 등록 화면")
expect(titleBox.Parent.Visible and not search.Parent.Visible, "등록 화면에서는 제목 칸만 보인다")
local normal, hard = named("Do_mode_normal"), named("Do_mode_hard")
expect(normal ~= nil and hard ~= nil, "난이도 단추 둘이 다 보인다(눌러서 돌리는 단추가 아니다)")
expect(normal.opts.main and not hard.enabled, "고른 것(노말)이 밝고, 들어갈 수 없는 하드는 꺼져 있다")
for i, st in { 0, 5, 10, 20 } do
	local b = named("Do_step" .. i)
	expect(b ~= nil and b.text == ("Lv.%d부터"):format(120 + st), "최소 레벨 단추 " .. i .. " = 입장 레벨 + " .. st)
end
expect(named("Do_step1").opts.main, "처음은 입장 레벨부터")
named("Do_step3").click()
expect(named("Do_step3").opts.main and not named("Do_step1").opts.main, "누른 단추가 밝다")
local sameHit = nil
for _, h in hits do
	if h.parent and h.parent.Name == "Same" then
		sameHit = h
	end
end
expect(sameHit ~= nil, "같은 직업 체크 칸")
sameHit.fn()
eq(FW.form.same, false, "체크를 누르면 꺼진다")
withinWindow("모집 글 등록")
titleBox.Text = "  빠르게 가요 "
named("Do_ok").click()
local last = did[#did]
expect(last[1] == "make" and last[2] == "lavagiant" and last[3] == "normal" and last[4].title == "  빠르게 가요 " and last[4].step == 3 and last[4].same == false, "등록 = 서버에 make(보스, 난이도, { 제목, 단계, 같은 직업 })")
eq(FW.view, "list", "등록하면 목록(대답이 오면 파티 대기실)")
-- 파티 대기실(방장)
answer = {
	boss = BOSS, max = 4, steps = { 0, 5, 10, 20 }, rooms = {},
	mine = { boss = "용암 거인", bossId = "lavagiant", mode = "normal", title = "빠르게 가요", lv = 130, same = false, lead = true,
		members = { who(1, "나", 130, true), who(2, "달그림자", 125, false, false) },
		apps = { who(3, "수정바람", 132, false), who(4, "은빛도끼", 140, false) } },
}
redraw()
expect(not search.Parent.Visible and not titleBox.Parent.Visible, "대기실에서는 글 칸이 숨는다")
expect(has(W.room.title) ~= nil, "「파티 대기실」")
expect(has(W.room.away) ~= nil and has(W.room.here) ~= nil, "파티원마다 「문 앞」 · 「멀리」")
local start = named("Do_start")
expect(start ~= nil and not start.enabled, "멀리 있는 파티원이 있으면 [입장]이 꺼져 있다")
expect(named("Do_accept1") ~= nil and named("Do_deny2") ~= nil, "신청자마다 [수락] · [거절]")
named("Do_accept1").click()
expect(did[#did][1] == "accept" and did[#did][2] == 3, "수락 = 서버에 accept(사람)")
named("Do_deny2").click()
expect(did[#did][1] == "deny" and did[#did][2] == 4, "거절 = 서버에 deny(사람)")
withinWindow("파티 대기실")
answer.mine.members[2].here = true
redraw()
expect(named("Do_start").enabled, "모두 문 앞이면 [입장]이 켜진다")
named("Do_start").click()
eq(did[#did][1], "start", "입장 = 서버에 start")
named("Do_stop").click()
eq(did[#did][1], "leave", "모집 취소 = 서버에 leave")
-- 파티원(방장 아님)
answer.mine.lead = false
answer.mine.apps = {}
redraw()
expect(named("Do_leave") ~= nil and named("Do_start") == nil and named("Do_accept1") == nil, "파티원 = [나가기]만")
expect(has(W.room.wait) ~= nil, "「방장이 신청을 받고 있다」")
-- 서버가 까닭을 주면 아래 줄에
answer.why = "보스의 문 앞에서 신청한다"
redraw()
expect(has("보스의 문 앞에서 신청한다") ~= nil, "서버의 까닭")
view.destroy()
