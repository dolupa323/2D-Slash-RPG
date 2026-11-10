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
WeeklyWindow.practice = false -- [격파] [연습] 가운데 연습을 골랐는가(2026-11-10 — 공방 weekboss.js practice)

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
	local only = not b.hard -- 난이도가 하나뿐인 보스(용암 거인 — 2026-11-04): 노말 단추 하나를 가득
	if only then
		WeeklyWindow.mode = "normal"
	end
	for i, mode in Weekly.MODES do
		if only and mode ~= "normal" then
			continue
		end
		local btn = Ui.button(body, WD.modes[mode].name, if i == 1 then 0 else half + S.modeGap, S.modeY, if only then w elseif i == 1 then half else w - half - S.modeGap, function()
			WeeklyWindow.mode = mode
			view.refresh()
		end)
		btn.frame.Name = if mode == "hard" then "Hard" else "Normal"
		modeBtn[mode] = btn
	end
	-- [격파] [연습](2026-11-10 사용자 "보스 연습모드도 추가해야해 내가 그 주에 그 보스를 클리어해도 도전할수있게 보상은 안주는 그냥 연습모드인거지"): 고른 쪽이 밝다
	local kindBtn = {}
	for i, k in { "clear", "practice" } do
		local btn = Ui.button(body, if k == "practice" then W.kindPractice else W.kindClear, if i == 1 then 0 else half + S.modeGap, S.kindY, if i == 1 then half else w - half - S.modeGap, function()
			WeeklyWindow.practice = k == "practice"
			view.refresh()
		end)
		btn.frame.Name = if k == "practice" then "Practice" else "Clear"
		kindBtn[k] = btn
	end
	local info = Ui.text(body, "", 0, S.infoY, w, { color = C.dim })
	Ui.text(body, W.pay, 0, S.payY, S.payLabelW, { color = C.dim })
	-- 격파 보상 세 줄(2026-10-27 — sim/weekly.luau의 payLines · 고른 난이도마다): 달가루 · 달돈 / 첫 격파 칭호(있는 보스만 — 그림자 사수는 없다 · 10-28) / 이름 붙은 장비(하드) — 장신구 줄은 민트
	local payRows = {}
	for i = 1, 3 do
		payRows[i] = Ui.text(body, "", S.payLabelW, S.payY + (i - 1) * S.payGap, w - S.payLabelW, { color = if i == 3 then C.accent else C.gold })
	end
	local noteLine = Ui.text(body, W.note, 0, S.noteY, w, { color = C.dim }) -- (연습이면 「이번 주 격파와 상관없이 · 오늘 남은 연습 n/20」)
	Ui.text(body, W.reset, 0, S.resetY, w, { color = C.dim })
	local bthird = math.floor((w - S.btnGap * 2) / 3) -- 단추 셋: 혼자 입장 · 파티 입장 · 파티 찾기(2026-11-05)
	local entering = false
	local function enter(party: boolean)
		if entering then
			return
		end
		entering = true
		ctx.weekDo("enter", b.id, WeeklyWindow.mode, party, WeeklyWindow.practice)
		entering = false
	end
	local solo = Ui.button(body, W.solo, 0, S.btnY, bthird, function()
		enter(false)
	end, { main = true })
	solo.frame.Name = "Solo"
	local party = Ui.button(body, W.party, bthird + S.btnGap, S.btnY, bthird, function()
		enter(true)
	end)
	party.frame.Name = "Party"
	-- 파티 찾기(2026-11-05 — 로스트아크의 레이드 입장 창 오른쪽 아래 [파티 찾기]처럼): 이 보스의 모집 글 · 파티 대기실(넓은 창 — client/lune/ui/finderWindow.luau)
	local finder = Ui.button(body, W.finder or "", (bthird + S.btnGap) * 2, S.btnY, w - (bthird + S.btnGap) * 2, function()
		require(script.Parent.windows).open("finder", b.id)
	end)
	finder.frame.Name = "Finder"
	local note = Ui.text(body, "", 0, S.footY, w, { color = C.dim })

	function view.refresh()
		local me = ctx.me()
		local level = if me then me.level else 1
		local got = ctx.week()
		local done = got and got.view and got.view.done and got.view.done[b.id]
		local mode = WeeklyWindow.mode
		local m = b[mode]
		local prac = WeeklyWindow.practice
		local pracMax = Weekly.PRACTICE.perDay or 999999 -- (false = 횟수 제한 없음 — 2026-11-10)
		local pracLeft = if got and got.view and typeof(got.view.prac) == "number" then got.view.prac else pracMax
		for k, btn in kindBtn do
			btn:setMain((k == "practice") == prac)
		end
		noteLine:set(if prac then Format.fill(W.practiceNote, { n = pracLeft, max = pracMax }) else W.note)
		week:set(Format.fill(W.week, { n = if done then 1 else 0 }))
		week:color(if done then C.dim else C.accent)
		for k, btn in modeBtn do
			btn:setMain(k == mode)
		end
		-- (그 보스만의 제한 시간 — 용암 거인 20분 · 물약 제한이 있으면 끝에 「물약 20개까지」 — 2026-11-07)
		local infoText = Format.fill(W.modeLine, { need = m.need, lv = m.lv }) .. " · " .. Format.fill(W.time, { m = math.floor((b.time or WD.time) / 60) })
		if typeof(b.potionCap) == "number" then
			infoText ..= " · " .. Format.fill(W.potionCap, { n = b.potionCap })
		end
		info:set(infoText)
		local lines, itemAt = Weekly.payLines(b, mode)
		if prac then
			lines, itemAt = { W.practicePay, "", "" }, 0 -- 연습: 보상 없음(2026-11-10)
		end
		for i, t in lines do
			-- 칸(w - payLabelW)을 넘는 줄(소비 아이템이 넷 — 용암 거인 · 2026-11-07 윤슬 조각을 더하며): 뒤에서부터 덜어 내고 「 외 n가지」(글은 칸을 넘지 않는다)
			local avail = w - S.payLabelW
			if Ui.measure(t) > avail and string.find(t, " · ", 1, true) then
				local parts = string.split(t, " · ")
				local cut = 0
				while #parts > 1 and Ui.measure(table.concat(parts, " · ") .. Format.fill(W.payMore or " 외 {n}가지", { n = cut + 1 })) > avail do
					table.remove(parts)
					cut += 1
				end
				if cut > 0 then
					t = table.concat(parts, " · ") .. Format.fill(W.payMore or " 외 {n}가지", { n = cut })
				end
			end
			payRows[i]:set(t)
			payRows[i]:color(if prac then C.dim elseif i == itemAt then C.accent else C.gold) -- 장신구 줄은 민트(칭호가 없는 보스는 둘째 줄 — 2026-10-28) · 연습은 흐리게
		end
		local open = (if prac then pracLeft > 0 else not done) and level >= m.need -- (연습: 이번 주 격파와 상관없이 · 오늘 남은 연습이 있으면)
		solo:setEnabled(open)
		party:setEnabled(open and ctx.partyHere ~= nil and ctx.partyHere())
		local why = got and got.why
		if not why and prac and pracLeft <= 0 then
			why = Format.fill(W.practiceOut, { max = pracMax })
		elseif not why and done and not prac then
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
