-- 파티 찾기 창 — 그 보스의 문 → 보스 창의 [파티 찾기](2026-11-05). 사용자: "파티 보스라서 파티구하고 방만들고 막 이런 UI도 있어야해" →
--  같은 날 "메뉴탭에서 접근하는게 아니라 해당 던전에서 파티방을 만드는거야 그 던전 갈사람을 구할수있는 구인구직 ui 를 만드는거고 로스트아크 파티모집 어떻게하는지 … 공부하고만들어" ·
--  "보스,난이도, 조건 선택을 클랙해서 바꾸는게 어디있어 제발 ui 의 기본은 지키자". 로스트아크의 레이드 파티 찾기 꼴(보스마다 따로 · 모집 글 등록 → 파티 대기실 · 참가 신청 → 방장 수락):
--  넓은 창(혼자 쓴다). 위 줄 = [모집 글 등록](왼쪽 위) · 난이도 거르기 탭(전체 · 노말 · 하드) · 제목 찾기 칸(오른쪽) /
--   왼쪽 = 방 목록(줄을 누르면 고른 줄이 밝다 — 제목 … n/4 / 난이도 · 최소 레벨 · 방장 · 「신청함」) / 오른쪽 = 고른 방(제목 · 조건 · 같은 직업 · 파티원 — 레벨 · 이름 · 직업 · 전투력) + [참가 신청] · [참가 취소].
--  모집 글 등록 = 제목(글 칸) · 난이도 · 최소 레벨(보기를 다 늘어놓은 단추 줄 — 고른 것이 밝다) · 같은 직업도 받기(체크 칸) · [등록] [취소].
--  파티 대기실(내가 든 방이 있으면) = 왼쪽 파티원 넷(방장 · 문 앞 / 멀리) + [입장] [모집 취소] | [나가기] · 오른쪽 신청자(수락 · 거절).
--  셈은 서버(ctx.finderDo → world.luau의 "Finder" → shared/lune/sim/finder.luau) — 창을 열 때 · 열려 있는 동안 3초마다 묻고, 내 방이 바뀌면 서버가 먼저 보낸다(FinderView).
--  모양은 공방 시험 탭 js/lune/ui/paint.js의 paintFinder와 같다(치수 = 공방 design/ui.js UILAYOUT.finder · 글 = FINDER). 화면의 넓은 창(ui/windows.luau)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Weekly = require(lune.sim.weekly)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local S = Layout.FINDER
local W = UI.finder
local POLL = 3 -- 열려 있는 동안 묻는 사이(초)
local CHECK = { { 0, 2 }, { 1, 3 }, { 2, 4 }, { 3, 3 }, { 4, 2 }, { 5, 1 }, { 6, 0 } } -- 체크의 점(스케줄러의 칸과 같다)

local FinderWindow = { wide = true }
FinderWindow.TITLE = W.title
FinderWindow.view = "list" -- "list" 방 목록 · "form" 모집 글 등록(내 방이 있으면 늘 파티 대기실)
FinderWindow.filter = "all" -- 난이도 거르기
FinderWindow.sel = nil :: any -- 고른 방(방장)
FinderWindow.page = 1
FinderWindow.form = { mode = nil :: string?, step = 1, same = true }

function FinderWindow.size(): (number, number)
	return S.w, S.h
end

-- 창의 제목 = 「파티 찾기 · 그 보스」(보스마다 따로 — 로스트아크처럼)
function FinderWindow.title(arg: any): string?
	local b = Weekly.boss(arg)
	return if b then W.title .. " · " .. b.name else nil
end

local function modeName(mode: string): string
	local m = Weekly.DATA.modes[mode]
	return if m then m.name else mode
end

-- 체크 칸: 켜면 민트 칸에 어두운 체크 · 끄면 테두리만
local function checkbox(parent: Instance, x: number, y: number, on: boolean)
	local s = S.checkS
	Ui.box(parent, x, y, s, s, if on then C.accent else C.line)
	if not on then
		Ui.box(parent, x + 1, y + 1, s - 2, s - 2, C.panel2)
		return
	end
	for _, p in CHECK do
		Ui.box(parent, x + 2 + p[1], y + 3 + p[2], 1, 2, C.ink)
	end
end

function FinderWindow.build(body: Frame, ctx, w: number, _h: number, arg: any)
	local view = {}
	local bossId = arg
	local alive = true
	local holder: Frame? = nil
	-- 늘 있는 것: 제목 찾기 칸 · 제목 칸(다시 짓지 않는다 — 다시 지으면 적던 글이 끊긴다) · 아래 까닭 줄
	local search = Ui.field(body, w - S.searchW, 0, S.searchW, S.barH, W.search)
	local titleBox = Ui.field(body, S.formLabelW, S.formY, w - S.formLabelW, S.barH, W.form.hint)
	local why = Ui.text(body, "", 0, S.whyY, w, { color = C.red })
	search:GetPropertyChangedSignal("Text"):Connect(function()
		FinderWindow.page = 1
		view.refresh()
	end)

	local function act(action: string, a: any, b: any, c: any)
		if ctx.finderDo then
			ctx.finderDo(action, a, b, c)
		end
	end

	-- 위 줄: [모집 글 등록] · 난이도 탭(목록일 때) · 제목(등록 · 대기실일 때)
	local function bar(p: Frame, got)
		local modes = (got.boss and got.boss.modes) or {}
		if got.mine then
			Ui.text(p, W.room.title, 0, 4, 120, { font = "body", color = C.gold })
			Ui.text(p, got.mine.boss .. " · " .. modeName(got.mine.mode) .. " · " .. Format.fill(W.cond, { lv = got.mine.lv }) .. " · " .. (if got.mine.same then W.same else W.noSame), 124, 6, w - 124, { align = "right", color = C.dim })
			return
		elseif FinderWindow.view == "form" then
			Ui.text(p, W.form.title .. " — " .. (if got.boss then got.boss.name else ""), 0, 4, w, { font = "body", color = C.gold })
			return
		end
		Ui.button(p, W.register, 0, 0, S.regW, function()
			FinderWindow.view = "form"
			view.refresh()
		end, { h = S.barH, main = true }).frame.Name = "Do_register"
		local tabs = { { "all", W.all } }
		if #modes > 1 then
			for _, m in modes do
				table.insert(tabs, { m.id, modeName(m.id) })
			end
		end
		local tx = S.tabX
		for _, t in tabs do
			local tab = Ui.tab(p, t[2], tx, 4, function()
				FinderWindow.filter = t[1]
				FinderWindow.page = 1
				view.refresh()
			end)
			tab.frame.Name = "Tab_" .. t[1]
			tab:setOn(FinderWindow.filter == t[1])
			tx += tab.width + 14
		end
	end

	-- 방 목록(왼쪽) · 고른 방(오른쪽)
	local function list(p: Frame, got)
		local key = string.lower(search.Text or "")
		local rooms = {}
		for _, r in got.rooms or {} do
			if (FinderWindow.filter == "all" or r.mode == FinderWindow.filter) and (key == "" or string.find(string.lower(r.title), key, 1, true)) then
				table.insert(rooms, r)
			end
		end
		local max = got.max or 4
		if #rooms == 0 then
			Ui.text(p, W.none, 0, S.listY + 4, S.listW, { color = C.dim, lines = 2 })
		end
		local pages = math.max(1, math.ceil(#rooms / S.rows))
		FinderWindow.page = math.clamp(FinderWindow.page, 1, pages)
		local sel = nil
		for _, r in rooms do
			if r.id == FinderWindow.sel then
				sel = r
			end
		end
		if not sel then
			sel = rooms[(FinderWindow.page - 1) * S.rows + 1]
			FinderWindow.sel = if sel then sel.id else nil
		end
		for i = 1, S.rows do
			local r = rooms[(FinderWindow.page - 1) * S.rows + i]
			if not r then
				break
			end
			local y = S.listY + (i - 1) * S.rowH
			local on = r == sel
			local row = Ui.group(p, 0, y, S.listW, S.rowH - 2, "Row" .. i)
			if on then
				Ui.box(row, 0, 0, S.listW, S.rowH - 2, C.panel2)
				Ui.box(row, 0, 0, 2, S.rowH - 2, C.accent)
			end
			Ui.text(row, r.title, 8, 3, S.listW - 64, { color = if on then C.accent else C.text })
			Ui.text(row, Format.fill(W.count, { n = r.n, max = max }), S.listW - 52, 3, 46, { align = "right", color = if r.n >= max then C.off else C.gold })
			Ui.text(row, Format.fill(W.rowSub, { mode = modeName(r.mode), lv = r.lv, name = r.leader }), 8, 19, S.listW - 72, { color = C.dim })
			if r.applied then
				Ui.text(row, W.applied, S.listW - 62, 19, 56, { align = "right", color = C.accent })
			end
			Ui.hit(row).Activated:Connect(function()
				FinderWindow.sel = r.id
				view.refresh()
			end)
			if i > 1 then
				Ui.line(p, 0, y - 2, S.listW)
			end
		end
		if pages > 1 then
			Ui.text(p, Format.fill(W.page, { a = FinderWindow.page, b = pages }), 0, S.btnY + 5, 60, { color = C.dim })
			Ui.button(p, W.next, S.listW - 64, S.btnY, 64, function()
				FinderWindow.page = FinderWindow.page % pages + 1
				view.refresh()
			end, { h = S.barH }).frame.Name = "Do_next"
		end
		-- 고른 방
		local x, sw = S.sideX, S.sideW
		Ui.box(p, x - 7, S.listY, 1, S.btnY + 22 - S.listY, C.line)
		if not sel then
			Ui.text(p, W.pick, x, S.sideY + 4, sw, { color = C.dim, lines = 2 })
			return nil
		end
		Ui.text(p, sel.title, x, S.sideY, sw, { font = "body", color = C.gold })
		Ui.text(p, modeName(sel.mode) .. " · " .. Format.fill(W.cond, { lv = sel.lv }), x, S.sideY + 20, sw, { color = C.text })
		Ui.text(p, if sel.same then W.same else W.noSame, x, S.sideY + 36, sw, { color = C.dim })
		Ui.text(p, Format.fill(W.members, { n = sel.n, max = max }), x, S.sideMembersY - 18, sw, { color = C.gold })
		for i, m in sel.members or {} do
			local y = S.sideMembersY + (i - 1) * S.sideMemberH
			Ui.text(p, Format.fill(W.member, { lv = m.lv, name = m.name }), x, y, sw - 40, { color = C.text })
			if m.leader then
				Ui.text(p, W.room.leader, x + sw - 40, y, 40, { align = "right", color = C.gold })
			end
			Ui.text(p, Format.fill(W.memberSub, { class = m.class, power = Format.comma(m.power) }), x, y + 14, sw, { color = C.dim })
		end
		local btn = Ui.button(p, if sel.applied then W.cancel else W.apply, x, S.btnY, sw, function()
			if sel.applied then
				act("withdraw")
			else
				act("apply", sel.id)
			end
		end, { main = not sel.applied })
		btn.frame.Name = "Do_apply"
		btn:setEnabled(sel.applied or sel.can == nil)
		return if sel.applied then nil else sel.can
	end

	-- 모집 글 등록: 제목 · 난이도 · 최소 레벨 · 같은 직업
	local function form(p: Frame, got)
		local fm = FinderWindow.form
		local modes = (got.boss and got.boss.modes) or {}
		local pickMode = nil
		for _, m in modes do
			if m.id == fm.mode and m.can then
				pickMode = m
			end
		end
		if not pickMode then
			for _, m in modes do
				if m.can and not pickMode then
					pickMode = m
				end
			end
			pickMode = pickMode or modes[1]
			fm.mode = if pickMode then pickMode.id else nil
		end
		local steps = got.steps or { 0 }
		fm.step = math.clamp(fm.step, 1, #steps)
		local labels = { W.form.name, W.form.mode, W.form.lv, W.form.job }
		for i, l in labels do
			Ui.text(p, l, 0, S.formY + (i - 1) * S.formH + 5, S.formLabelW - 6, { color = C.dim })
		end
		-- 난이도: 보기를 다 늘어놓은 단추 줄(고른 것이 밝다 · 들어갈 수 없는 난이도는 흐림)
		for i, m in modes do
			local b = Ui.button(p, modeName(m.id), S.formLabelW + (i - 1) * (S.segW + 6), S.formY + S.formH, S.segW, function()
				fm.mode = m.id
				view.refresh()
			end, { h = S.barH, main = pickMode == m })
			b.frame.Name = "Do_mode_" .. m.id
			b:setEnabled(m.can)
		end
		-- 최소 레벨: 입장 레벨 + 0 · 5 · 10 · 20
		local need = if pickMode then pickMode.need else 1
		for i, st in steps do
			local b = Ui.button(p, Format.fill(W.cond, { lv = need + st }), S.formLabelW + (i - 1) * (S.segW + 6), S.formY + S.formH * 2, S.segW, function()
				fm.step = i
				view.refresh()
			end, { h = S.barH, main = fm.step == i })
			b.frame.Name = "Do_step" .. i
		end
		-- 같은 직업도 받기(체크 칸 — 글까지 누르는 자리)
		local cy = S.formY + S.formH * 3
		local check = Ui.group(p, S.formLabelW, cy, w - S.formLabelW, S.barH, "Same")
		checkbox(check, 0, 5, fm.same)
		Ui.text(check, W.form.same, S.checkS + 8, 4, w - S.formLabelW - S.checkS - 8, { color = C.text })
		Ui.hit(check).Activated:Connect(function()
			fm.same = not fm.same
			view.refresh()
		end)
		Ui.text(p, W.form.note, 0, S.formNoteY, w, { color = C.dim, lines = 2 })
		local ok = Ui.button(p, W.form.ok, 0, S.formBtnY, S.formBtnW, function()
			if fm.mode then
				act("make", bossId, fm.mode, { title = titleBox.Text, step = fm.step, same = fm.same })
				FinderWindow.view = "list"
			end
		end, { main = true })
		ok.frame.Name = "Do_ok"
		ok:setEnabled(pickMode ~= nil and pickMode.can)
		Ui.button(p, W.form.back, S.formBtnW + 8, S.formBtnY, S.formBtnW, function()
			FinderWindow.view = "list"
			view.refresh()
		end).frame.Name = "Do_back"
	end

	-- 파티 대기실: 왼쪽 파티원 · 아래 단추 / 오른쪽 신청자
	local function room(p: Frame, got)
		local m = got.mine
		local max = got.max or 4
		Ui.text(p, m.title, 0, S.roomY, S.listW, { color = C.text })
		local away = 0
		for i = 1, max do
			local y = S.roomMemberY + (i - 1) * S.roomMemberH
			local mb = m.members[i]
			if i > 1 then
				Ui.line(p, 0, y - 4, S.listW)
			end
			if mb then
				Ui.text(p, Format.fill(W.member, { lv = mb.lv, name = mb.name }), 0, y, S.listW - 96, { font = "body", color = C.text })
				if mb.leader then
					Ui.text(p, W.room.leader, S.listW - 96, y + 1, 44, { align = "right", color = C.gold })
				end
				Ui.text(p, if mb.here then W.room.here else W.room.away, S.listW - 48, y + 1, 48, { align = "right", color = if mb.here then C.accent else C.dim })
				Ui.text(p, Format.fill(W.memberSub, { class = mb.class, power = Format.comma(mb.power) }), 0, y + 18, S.listW, { color = C.dim })
				if not mb.here then
					away += 1
				end
			else
				Ui.text(p, "-", 0, y, 40, { color = C.off })
			end
		end
		local half = math.floor((S.listW - 8) / 2)
		if m.lead then
			Ui.text(p, W.room.startNote, 0, S.btnY - 18, S.listW, { color = C.dim })
			local go = Ui.button(p, W.room.start, 0, S.btnY, half, function()
				act("start")
			end, { main = true })
			go.frame.Name = "Do_start"
			go:setEnabled(#m.members >= 2 and away == 0)
			Ui.button(p, W.room.stop, S.listW - half, S.btnY, half, function()
				act("leave")
			end).frame.Name = "Do_stop"
		else
			Ui.button(p, W.room.leave, 0, S.btnY, half, function()
				act("leave")
			end).frame.Name = "Do_leave"
		end
		-- 신청자(방장에게만)
		local x, sw = S.sideX, S.sideW
		Ui.box(p, x - 7, S.roomY, 1, S.btnY + 22 - S.roomY, C.line)
		if not m.lead then
			Ui.text(p, W.room.wait, x, S.sideY + 4, sw, { color = C.dim, lines = 2 })
			return
		end
		Ui.text(p, Format.fill(W.room.apps, { n = #m.apps }), x, S.sideY, sw, { color = C.gold })
		if #m.apps == 0 then
			Ui.text(p, W.room.noApps, x, S.appY, sw, { color = C.dim })
		end
		local textW = sw - S.appBtnW * 2 - 8
		for i, ap in m.apps do
			local y = S.appY + (i - 1) * S.appH
			if y + S.appH > S.btnY + 22 then
				break
			end
			Ui.text(p, Format.fill(W.member, { lv = ap.lv, name = ap.name }), x, y + 3, textW, { color = C.text })
			Ui.text(p, Format.fill(W.memberSub, { class = ap.class, power = Format.comma(ap.power) }), x, y + 22, sw, { color = C.dim })
			Ui.button(p, W.room.accept, x + sw - S.appBtnW * 2 - 4, y - 2, S.appBtnW, function()
				act("accept", ap.id)
			end, { h = S.barH, main = true }).frame.Name = "Do_accept" .. i
			Ui.button(p, W.room.deny, x + sw - S.appBtnW, y - 2, S.appBtnW, function()
				act("deny", ap.id)
			end, { h = S.barH }).frame.Name = "Do_deny" .. i
		end
	end

	function view.refresh()
		if holder then
			holder:Destroy()
		end
		local p = Ui.group(body, 0, 0, w, S.whyY, "Finder")
		holder = p
		local got = ctx.finder and ctx.finder() or nil
		local listing = got ~= nil and got.mine == nil and FinderWindow.view ~= "form"
		search.Parent.Visible = listing
		titleBox.Parent.Visible = got ~= nil and got.mine == nil and FinderWindow.view == "form"
		if not got then
			Ui.text(p, W.loading, 0, S.listY + 4, w, { color = C.dim })
			why:set("")
			return
		end
		bar(p, got)
		local hint = nil
		if got.mine then
			room(p, got)
		elseif FinderWindow.view == "form" then
			form(p, got)
		else
			hint = list(p, got)
		end
		why:set(got.why or hint or "")
	end
	function view.destroy()
		alive = false
	end
	view.refresh()
	if ctx.finderFetch then
		ctx.finderFetch(bossId) -- 창을 열 때 묻는다(대답이 오면 Windows.refresh가 다시 그린다)
		task.spawn(function()
			while alive do
				task.wait(POLL)
				if alive then
					ctx.finderFetch(bossId) -- 열려 있는 동안(다른 사람이 연 방 · 인원 · 신청)
				end
			end
		end)
	end
	return view
end

return FinderWindow
