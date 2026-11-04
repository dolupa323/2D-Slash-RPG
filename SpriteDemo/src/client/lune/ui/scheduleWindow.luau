-- 스케줄러 창 — 메뉴 → 「스케줄러」(2026-11-03 사용자 "스케줄러를 만들어서 모바일,pc 에서 스케줄러 ui 가 나오고 일일퀘스트, 보스 했는지 이번주 잡았는지, 오늘 깼는지 던전 이런거 보이고
--  깨면 체크표시되고 메이플에 스케줄러기능이있어 참고하면된다"). 메이플스토리의 스케줄러처럼 이 캐릭터가 매일 · 매주 할 일을 한 창에 모아 보여 준다(보기만 — 하는 곳은 그 자리).
--  위부터: 탭 「일일 n/m」 · 「주간 n/m」(n = 끝낸 수 · m = 할 수 있는 수 — 잠긴 줄은 빼고) / 줄마다 [칸] 이름 ……… 오른쪽 진행 —
--   끝낸 줄 = 민트 칸에 체크 · 진행 글 민트 / 잠긴 줄 = 흐림 / 다음 초기화까지 남은 시간 · 안내 한 줄.
--  줄은 서버가 셈해 준다(ctx.scheduleFetch → world.luau의 "Schedule" → shared/lune/sim/schedule.luau) — 창을 열 때 · 탭을 바꿀 때 다시 묻는다.
--  모양은 공방 시험 탭 js/lune/ui/paint.js의 paintSchedule과 같다(치수 = 공방 design/ui.js UILAYOUT.schedule · 글 = SCHEDULE). 화면 오른쪽의 옆 판(ui/windows.luau)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Schedule = require(lune.sim.schedule)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local S = Layout.SCHEDULE
local W = UI.schedule
local CHECK = { { 0, 2 }, { 1, 3 }, { 2, 4 }, { 3, 3 }, { 4, 2 }, { 5, 1 }, { 6, 0 } } -- 체크의 점(칸 안 왼쪽 위 2 · 3점부터 — 공방 paint.js의 SCHED_CHECK와 같다)
local TABS = { "daily", "weekly" }

local ScheduleWindow = {}
ScheduleWindow.TITLE = W.title
ScheduleWindow.tab = "daily" -- 고른 탭(창을 닫았다 열어도 남는다)

function ScheduleWindow.size(): (number, number)
	return S.w, S.h
end

-- 줄 앞의 칸: 끝냈으면 민트로 채우고 어두운 체크 · 잠겼으면 흐린 테두리
local function box(parent: Instance, x: number, y: number, done: boolean, locked: boolean)
	local s = S.box
	Ui.box(parent, x, y, s, s, if done then C.accent elseif locked then C.off else C.line)
	if not done then
		Ui.box(parent, x + 1, y + 1, s - 2, s - 2, C.panel2)
		return
	end
	for _, p in CHECK do
		Ui.box(parent, x + 2 + p[1], y + 3 + p[2], 1, 2, C.ink)
	end
end

function ScheduleWindow.build(body: Frame, ctx, w: number, _h: number)
	local view = {}
	local holder: Frame? = nil -- 탭 · 줄(다시 그릴 때마다 새로 짓는다 — 줄의 수 · 탭 글의 폭이 바뀐다)
	local reset = Ui.text(body, "", 0, S.resetY, w, { color = C.dim })
	Ui.text(body, W.note, 0, S.noteY, w, { color = C.dim })

	function view.refresh()
		if holder then
			holder:Destroy()
		end
		holder = Ui.group(body, 0, 0, w, S.resetY, "Schedule")
		local got = ctx.schedule and ctx.schedule() or nil
		-- 탭: 「일일 n/m」 · 「주간 n/m」
		local tx = 0
		for _, key in TABS do
			local done, total = Schedule.count(got and got[key])
			local tab = Ui.tab(holder :: Frame, W.tabs[key] .. " " .. done .. "/" .. total, tx, 0, function()
				ScheduleWindow.tab = key
				view.refresh()
				if ctx.scheduleFetch then
					ctx.scheduleFetch() -- (탭을 바꾸면 다시 묻는다 — 그 사이 끝낸 것)
				end
			end)
			tab.frame.Name = "Tab_" .. key
			tab:setOn(ScheduleWindow.tab == key)
			tx += tab.width + 16
		end
		if not got then
			Ui.text(holder :: Frame, W.loading, 0, S.listY + 4, w, { color = C.dim })
			reset:set("")
			return
		end
		local rows = got[ScheduleWindow.tab] or {}
		for i, r in rows do
			if i > S.rows then
				break
			end
			local y = S.listY + (i - 1) * S.rowH
			local ty = y + math.floor((S.rowH - 12) / 2) - 2
			if i > 1 then
				Ui.line(holder :: Frame, 0, y - 2, w)
			end
			box(holder :: Frame, 0, y + math.floor((S.rowH - S.box) / 2) - 2, r.done == true, r.locked == true)
			Ui.text(holder :: Frame, r.name, S.nameX, ty, w - S.nameX - S.statusW - 6, { color = if r.locked then C.off else C.text })
			Ui.text(holder :: Frame, r.text, w - S.statusW, ty, S.statusW, { align = "right", color = if r.done then C.accent elseif r.locked then C.off else C.gold })
		end
		local weekly = ScheduleWindow.tab == "weekly"
		reset:set(Format.fill(if weekly then W.resetWeek else W.resetDay, { t = Schedule.leftText(if weekly then got.weekLeft or 0 else got.dayLeft or 0) }))
	end
	view.refresh()
	if ctx.scheduleFetch then
		ctx.scheduleFetch() -- 창을 열 때 묻는다(대답이 오면 Windows.refresh가 다시 그린다)
	end
	return view
end

return ScheduleWindow
