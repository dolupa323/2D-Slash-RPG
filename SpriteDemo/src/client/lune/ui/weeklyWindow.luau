-- 보스 창 — 그 보스의 문 앞에서 ↑(2026-10-24 — 공방 design/weekboss.js · 주간 보스). 문은 그 보스 퀘스트(큰 「!!」)를 끝내야 열린다.
--  사용자: "보스 퀘스트 만들고 그 퀘스트를 깨다보면 보스문 있고, 거기에 입장 ui 있고 파티로 입장하는거야 주간 1회 격파고"
--  위부터: 이름(본문 · 금색) · 오른쪽 「이번 주 0/1」 / 보스의 글(두 줄) / 줄 / [노말] [하드](고른 쪽이 밝다) / 「입장 Lv.58 · 보스 Lv.60 · 제한 시간 15분」 /
--   「격파 보상」 세 줄(달가루 · 달돈 / 첫 격파 칭호 / 하드의 이름 붙은 장비 — 2026-10-27) / 「노말 · 하드 가운데 하나를 한 주에 한 번 …」 / 「한국 시간 목요일 0시에 다시 열린다」 / [혼자 입장] [파티 입장] / 들어가지 못한 까닭(빨강) · 안내 한 줄.
--  들어가기는 서버가 정한다(ctx.weekDo("enter", 보스, 난이도, 파티인가) → world.luau의 "Week"). 모양은 공방 시험 탭의 js/lune/ui/paint.js(paintWeekly)와 같다.
--  화면 오른쪽의 옆 판(ui/windows.luau). 문에서 멀어지면 닫힌다(boot.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Weekly = require(lune.sim.weekly)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local S = Layout.WEEKLY
local WD = Weekly.DATA
local W = WD.words

local WeeklyWindow = {}
WeeklyWindow.TITLE = W.title
WeeklyWindow.mode = "normal" -- 고른 난이도(창을 닫았다 열어도 남는다)

function WeeklyWindow.size(): (number, number)
	return S.w, S.h
end

function WeeklyWindow.build(body: Frame, ctx, w: number, _h: number, arg: any)
	local b = Weekly.boss(arg) or WD.bosses[1]
	local view = {}
	Ui.text(body, b.name, 0, 2, w - 90, { font = "body", color = C.gold })
	local week = Ui.text(body, "", 0, 4, w, { align = "right", color = C.accent })
	Ui.text(body, b.text, 0, S.textY, w, { lines = S.textLines, color = C.text })
	Ui.line(body, 0, S.lineY, w)
	local half = math.floor((w - S.modeGap) / 2)
	local modeBtn = {}
	for i, mode in Weekly.MODES do
		local btn = Ui.button(body, WD.modes[mode].name, if i == 1 then 0 else half + S.modeGap, S.modeY, if i == 1 then half else w - half - S.modeGap, function()
			WeeklyWindow.mode = mode
			view.refresh()
		end)
		btn.frame.Name = if mode == "hard" then "Hard" else "Normal"
		modeBtn[mode] = btn
	end
	local info = Ui.text(body, "", 0, S.infoY, w, { color = C.dim })
	Ui.text(body, W.pay, 0, S.payY, S.payLabelW, { color = C.dim })
	-- 격파 보상 세 줄(2026-10-27 — sim/weekly.luau의 payLines · 고른 난이도마다): 달가루 · 달돈 / 첫 격파 칭호(있는 보스만 — 그림자 사수는 없다 · 10-28) / 이름 붙은 장비(하드) — 장신구 줄은 민트
	local payRows = {}
	for i = 1, 3 do
		payRows[i] = Ui.text(body, "", S.payLabelW, S.payY + (i - 1) * S.payGap, w - S.payLabelW, { color = if i == 3 then C.accent else C.gold })
	end
	Ui.text(body, W.note, 0, S.noteY, w, { color = C.dim })
	Ui.text(body, W.reset, 0, S.resetY, w, { color = C.dim })
	local bhalf = math.floor((w - S.btnGap) / 2)
	local entering = false
	local function enter(party: boolean)
		if entering then
			return
		end
		entering = true
		ctx.weekDo("enter", b.id, WeeklyWindow.mode, party)
		entering = false
	end
	local solo = Ui.button(body, W.solo, 0, S.btnY, bhalf, function()
		enter(false)
	end, { main = true })
	solo.frame.Name = "Solo"
	local party = Ui.button(body, W.party, bhalf + S.btnGap, S.btnY, w - bhalf - S.btnGap, function()
		enter(true)
	end)
	party.frame.Name = "Party"
	local note = Ui.text(body, "", 0, S.footY, w, { color = C.dim })

	function view.refresh()
		local me = ctx.me()
		local level = if me then me.level else 1
		local got = ctx.week()
		local done = got and got.view and got.view.done and got.view.done[b.id]
		local mode = WeeklyWindow.mode
		local m = b[mode]
		week:set(Format.fill(W.week, { n = if done then 1 else 0 }))
		week:color(if done then C.dim else C.accent)
		for k, btn in modeBtn do
			btn:setMain(k == mode)
		end
		info:set(Format.fill(W.modeLine, { need = m.need, lv = m.lv }) .. " · " .. Format.fill(W.time, { m = math.floor(WD.time / 60) }))
		local lines, itemAt = Weekly.payLines(b, mode)
		for i, t in lines do
			payRows[i]:set(t)
			payRows[i]:color(if i == itemAt then C.accent else C.gold) -- 장신구 줄은 민트(칭호가 없는 보스는 둘째 줄 — 2026-10-28)
		end
		local open = not done and level >= m.need
		solo:setEnabled(open)
		party:setEnabled(open and ctx.partyHere ~= nil and ctx.partyHere())
		local why = got and got.why
		if not why and done then
			why = W.done
		elseif not why and level < m.need then
			why = Format.fill(W.low, { a = m.need })
		end
		note:set(why or W.partyHint)
		note:color(if why then C.red else C.dim)
	end
	view.refresh()
	return view
end

return WeeklyWindow
