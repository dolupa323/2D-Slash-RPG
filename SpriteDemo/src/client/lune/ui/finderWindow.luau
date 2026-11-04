-- 파티 찾기 창 — 메뉴 → 「파티 찾기」(2026-11-05 사용자 "파티 보스라서 파티구하고 방만들고 막 이런 UI도 있어야해 파티를 구해서 가는거라서" ·
--  고르심: 같은 서버만 · 방장이 수락 · 방장 출발 → 바로 보스 방). 로스트아크 · WoW의 파티 찾기 꼴.
--  탭: 「모집 중」(방마다 두 줄 — 보스 · 난이도 … n/4 / 조건 레벨 · 방장 — 오른쪽 「신청」 · 「신청 취소」) · 「방 만들기」(보스 · 난이도 · 조건을 단추로 돌려 고르고 「방 만들기」) ·
--   방에 들면 「방 만들기」 자리가 「내 방」(머리 줄 · 파티원과 준비 · 방장에게는 신청한 사람의 「수락」 · 「거절」 · 아래 [출발 · 방 닫기] 또는 [준비 · 방 나가기]).
--  셈은 서버(ctx.finderDo → world.luau의 "Finder" → shared/lune/sim/finder.luau). 창을 열 때 · 열려 있는 동안 3초마다 묻고, 내 방이 바뀌면 서버가 먼저 보낸다(FinderView).
--  모양은 공방 시험 탭 js/lune/ui/paint.js의 paintFinder와 같다(치수 = 공방 design/ui.js UILAYOUT.finder · 글 = FINDER). 화면 오른쪽의 옆 판(ui/windows.luau)
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

local FinderWindow = {}
FinderWindow.TITLE = W.title
FinderWindow.tab = "list" -- 고른 탭(창을 닫았다 열어도 남는다)
FinderWindow.page = 1
FinderWindow.pick = { boss = 1, mode = 1, step = 1 } -- 방 만들기에서 고른 것(차례)

function FinderWindow.size(): (number, number)
	return S.w, S.h
end

local function modeName(mode: string): string
	local m = Weekly.DATA.modes[mode]
	return if m then m.name else mode
end

function FinderWindow.build(body: Frame, ctx, w: number, _h: number)
	local view = {}
	local holder: Frame? = nil
	local alive = true
	local why = Ui.text(body, "", 0, S.whyY, w, { color = C.red })

	local function act(action: string, a: any, b: any, c: any)
		if ctx.finderDo then
			ctx.finderDo(action, a, b, c)
		end
	end

	-- 모집 중: 방마다 두 줄 + 오른쪽 단추
	local function list(p: Frame, got)
		local rooms = got.rooms or {}
		if #rooms == 0 then
			Ui.text(p, W.none, 0, S.listY + 4, w, { color = C.dim, lines = 2 })
			return
		end
		local pages = math.max(1, math.ceil(#rooms / S.rows))
		FinderWindow.page = math.clamp(FinderWindow.page, 1, pages)
		for i = 1, S.rows do
			local r = rooms[(FinderWindow.page - 1) * S.rows + i]
			if not r then
				break
			end
			local y = S.listY + (i - 1) * S.rowH
			if i > 1 then
				Ui.line(p, 0, y - 2, w)
			end
			local full = r.n >= (got.max or 4)
			Ui.text(p, r.boss .. " · " .. modeName(r.mode), 0, y + 2, w - S.btnW - 48, { color = C.gold })
			Ui.text(p, Format.fill(W.count, { n = r.n, max = got.max or 4 }), w - S.btnW - 44, y + 2, 36, { align = "right", color = if full then C.off else C.accent })
			Ui.text(p, Format.fill(W.sub, { lv = r.lv, name = r.leader }), 0, y + 18, w - S.btnW - 8, { color = C.dim })
			local btn = Ui.button(p, if r.applied then W.applied else W.apply, w - S.btnW, y + 5, S.btnW, function()
				if r.applied then
					act("withdraw")
				else
					act("apply", r.id)
				end
			end, { h = 22 })
			btn.frame.Name = "Do_apply" .. i
			btn:setEnabled(r.applied or (not r.mine and not full and got.mine == nil))
		end
		if pages > 1 then
			Ui.text(p, Format.fill(W.page, { a = FinderWindow.page, b = pages }), 0, S.btnY + 4, 80, { color = C.dim })
			Ui.button(p, W.next, w - 56, S.btnY, 56, function()
				FinderWindow.page = FinderWindow.page % pages + 1
				view.refresh()
			end, { h = 22 }).frame.Name = "Do_next"
		end
	end

	-- 방 만들기: 보스 · 난이도 · 조건을 단추로 돌려 고른다
	local function make(p: Frame, got)
		local bosses = got.bosses or {}
		if #bosses == 0 then
			Ui.text(p, W.noBoss, 0, S.pickY, w, { color = C.dim, lines = 2 })
			return
		end
		local pk = FinderWindow.pick
		pk.boss = math.clamp(pk.boss, 1, #bosses)
		local bb = bosses[pk.boss]
		pk.mode = math.clamp(pk.mode, 1, #bb.modes)
		local mode = bb.modes[pk.mode]
		local steps = got.steps or { 0 }
		pk.step = math.clamp(pk.step, 1, #steps)
		local need = (bb.need and bb.need[mode]) or 1
		local rows = {
			{ W.boss, bb.name, function()
				pk.boss = pk.boss % #bosses + 1
				pk.mode = 1
			end },
			{ W.mode, modeName(mode), function()
				pk.mode = pk.mode % #bb.modes + 1
			end },
			{ W.cond, Format.fill(W.condLv, { lv = need + steps[pk.step] }), function()
				pk.step = pk.step % #steps + 1
			end },
		}
		for i, row in rows do
			local y = S.pickY + (i - 1) * S.pickH
			Ui.text(p, row[1], 0, y + 6, S.pickLabelW - 4, { color = C.dim })
			Ui.button(p, row[2], S.pickLabelW, y, w - S.pickLabelW, function()
				row[3]()
				view.refresh()
			end, { h = 22 }).frame.Name = "Do_pick" .. i
		end
		Ui.text(p, W.makeNote, 0, S.noteY, w, { color = C.dim, lines = 2 })
		Ui.button(p, W.make, 0, S.makeY, w, function()
			act("make", bb.id, mode, pk.step)
		end, { main = true }).frame.Name = "Do_make"
	end

	-- 내 방: 머리 줄 · 파티원 · 신청한 사람(방장에게만) · 아래 단추 둘
	local function room(p: Frame, got)
		local m = got.mine
		Ui.text(p, Format.fill(W.head, { boss = m.boss, mode = modeName(m.mode), lv = m.lv }), 0, S.headY, w, { color = C.gold })
		local waiting = 0
		for i = 1, got.max or 4 do
			local y = S.memberY + (i - 1) * S.memberH
			local mb = m.members[i]
			if mb then
				Ui.text(p, Format.fill(W.member, { lv = mb.lv, name = mb.name }), 0, y, w - 70, { font = "body" })
				Ui.text(p, if mb.leader then W.leader elseif mb.ready then W.ready else W.wait, w - 66, y + 1, 66, { align = "right", color = if mb.leader then C.gold elseif mb.ready then C.accent else C.dim })
				if not mb.leader and not mb.ready then
					waiting += 1
				end
			else
				Ui.text(p, "-", 0, y, 40, { color = C.off })
			end
		end
		local half = math.floor((w - 8) / 2)
		if m.lead then
			Ui.text(p, W.apps, 0, S.appsY, w, { color = C.gold })
			if #m.apps == 0 then
				Ui.text(p, W.noApps, 0, S.appsY + 20, w, { color = C.dim })
			end
			for i = 1, S.apps do
				local ap = m.apps[i]
				if not ap then
					break
				end
				local y = S.appsY + 18 + (i - 1) * S.appH
				Ui.text(p, Format.fill(W.app, { lv = ap.lv, name = ap.name, power = Format.comma(ap.power) }), 0, y + 5, w - S.appBtnW * 2 - 8, { color = C.text })
				Ui.button(p, W.accept, w - S.appBtnW * 2 - 4, y, S.appBtnW, function()
					act("accept", ap.id)
				end, { h = 22 }).frame.Name = "Do_accept" .. i
				Ui.button(p, W.deny, w - S.appBtnW, y, S.appBtnW, function()
					act("deny", ap.id)
				end, { h = 22 }).frame.Name = "Do_deny" .. i
			end
			local go = Ui.button(p, W.start, 0, S.btnY, half, function()
				act("start")
			end, { main = true })
			go.frame.Name = "Do_start"
			go:setEnabled(#m.members >= 2 and waiting == 0)
			Ui.button(p, W.close, w - half, S.btnY, half, function()
				act("leave")
			end).frame.Name = "Do_close"
		else
			Ui.button(p, if m.ready then W.readyOff else W.readyOn, 0, S.btnY, half, function()
				act("ready", not m.ready)
			end, { main = not m.ready }).frame.Name = "Do_ready"
			Ui.button(p, W.leave, w - half, S.btnY, half, function()
				act("leave")
			end).frame.Name = "Do_leave"
		end
	end

	function view.refresh()
		if holder then
			holder:Destroy()
		end
		local p = Ui.group(body, 0, 0, w, S.whyY, "Finder")
		holder = p
		local got = ctx.finder and ctx.finder() or nil
		if got and got.mine and FinderWindow.tab == "make" then
			FinderWindow.tab = "room"
		elseif got and not got.mine and FinderWindow.tab == "room" then
			FinderWindow.tab = "list"
		end
		-- 탭: 「모집 중 n」 · 「방 만들기」(방에 들어 있으면 「내 방」)
		local tabs = { { "list", W.tabs.list .. (if got then " " .. #(got.rooms or {}) else "") }, if got and got.mine then { "room", W.tabs.room } else { "make", W.tabs.make } }
		local tx = 0
		for _, t in tabs do
			local tab = Ui.tab(p, t[2], tx, 0, function()
				FinderWindow.tab = t[1]
				view.refresh()
			end)
			tab.frame.Name = "Tab_" .. t[1]
			tab:setOn(FinderWindow.tab == t[1])
			tx += tab.width + 16
		end
		if not got then
			Ui.text(p, W.loading, 0, S.listY + 4, w, { color = C.dim })
			why:set("")
			return
		end
		why:set(got.why or "")
		if FinderWindow.tab == "room" and got.mine then
			room(p, got)
		elseif FinderWindow.tab == "make" then
			make(p, got)
		else
			list(p, got)
		end
	end
	function view.destroy()
		alive = false
	end
	view.refresh()
	if ctx.finderFetch then
		ctx.finderFetch() -- 창을 열 때 묻는다(대답이 오면 Windows.refresh가 다시 그린다)
		task.spawn(function()
			while alive do
				task.wait(POLL)
				if alive then
					ctx.finderFetch() -- 열려 있는 동안(다른 사람이 만든 방 · 인원)
				end
			end
		end)
	end
	return view
end

return FinderWindow
