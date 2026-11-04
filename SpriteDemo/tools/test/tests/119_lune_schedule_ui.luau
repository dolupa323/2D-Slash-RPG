-- 「달의 계승자」 — 스케줄러 창을 화면 없이 지어 본다(client/lune/ui/scheduleWindow.luau — 2026-11-03 사용자 "스케줄러를 만들어서 모바일,pc 에서 스케줄러 ui 가 나오고 …
--  깨면 체크표시되고 메이플에 스케줄러기능이있어 참고하면된다"). 모양은 공방 시험 탭의 paintSchedule과 같다. 보는 것:
--   대답 전 「불러오는 중」 · 탭 「일일 n/m」 · 「주간 n/m」 · 줄마다 칸 · 이름 · 진행 · 끝낸 줄에 체크(점 일곱) · 잠긴 줄은 흐림 · 탭을 누르면 바뀌고 다시 묻는다 · 다음 초기화 글 · 글은 칸 안(폭)
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
local UIG = req("ReplicatedStorage/shared/lune/data/ui.generated")
local S = Layout.SCHEDULE

local texts, boxes, tabs, lines = {}, {}, {}, 0
local function frame(name)
	local f = { Name = name, Visible = true }
	function f:Destroy()
		f.gone = true
	end
	return f
end
local function text(parent, value, x, y, width, opts)
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
end
local COLOR = setmetatable({}, { __index = function(_, k)
	return k
end }) -- 색 = 그 이름(검사가 읽기 쉽게)
MOCK("Client/lune/ui/ui", {
	COLOR = COLOR,
	text = text,
	group = function(parent, x, y, w, h, name)
		local f = frame(name)
		f.parent, f.x, f.y, f.w, f.h = parent, x, y, w, h
		return f
	end,
	box = function(parent, x, y, w, h, color)
		local b = { parent = parent, x = x, y = y, w = w, h = h, color = color }
		table.insert(boxes, b)
		return b
	end,
	line = function()
		lines += 1
		return frame("Line")
	end,
	tab = function(parent, label, x, y, onClick)
		local it = { frame = frame("Tab"), width = #label * 3, text = label, on = false, click = onClick, parent = parent }
		function it.setOn(_, on)
			it.on = on
		end
		table.insert(tabs, it)
		return it
	end,
})
local ScheduleWindow = req("Client/lune/ui/scheduleWindow")
local Schedule = req("ReplicatedStorage/shared/lune/sim/schedule")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Attend = req("ReplicatedStorage/shared/lune/sim/attend")
local Weekly = req("ReplicatedStorage/shared/lune/sim/weekly")

local NOW = 1793700000
local h = Hero.new(1, "axion")
h.level = 35
local acct = { att = Attend.new() }
Attend.checkIn(acct.att, NOW)
acct.att.got = acct.att.n -- 출석 받음(체크)
local b = Weekly.DATA.bosses[1]
h.quests[b.quest] = { done = true }
h.level = math.max(h.level, b.normal.need)
Weekly.mark(h.rift, b.id, "hard", NOW) -- 주간 보스 하나 격파(체크)

local answer = nil
local fetched = 0
local ctx = {
	schedule = function()
		return answer
	end,
	scheduleFetch = function()
		fetched += 1
	end,
}
local w, hgt = ScheduleWindow.size()
eq(w, S.w, "창의 폭 = 공방의 치수")
local body = frame("Body")
ScheduleWindow.tab = "daily"
local ok, view = pcall(ScheduleWindow.build, body, ctx, w, hgt)
expect(ok, "창을 짓는다 " .. tostring(view))
eq(fetched, 1, "창을 열면 서버에 묻는다")
local loading = false
for _, t in texts do
	if t.value == UIG.schedule.loading then
		loading = true
	end
end
expect(loading, "대답 전에는 「불러오는 중」")

-- 대답이 왔다 → 다시 그린다
answer = Schedule.view(h, acct, NOW)
texts, boxes, tabs = {}, {}, {}
view.refresh()
eq(#tabs, 2, "탭 둘")
local dd, dt = Schedule.count(answer.daily)
local wd, wt = Schedule.count(answer.weekly)
eq(tabs[1].text, UIG.schedule.tabs.daily .. " " .. dd .. "/" .. dt, "탭 「일일 n/m」")
eq(tabs[2].text, UIG.schedule.tabs.weekly .. " " .. wd .. "/" .. wt, "탭 「주간 n/m」")
expect(tabs[1].on and not tabs[2].on, "일일 탭이 켜져 있다")
local function rowTexts()
	local names, status = {}, {}
	for _, t in texts do
		if t.x == S.nameX then
			table.insert(names, t)
		elseif t.opts.align == "right" then
			table.insert(status, t)
		end
	end
	return names, status
end
local names, status = rowTexts()
eq(#names, math.min(#answer.daily, S.rows), "일일 줄마다 이름")
eq(#status, #names, "줄마다 진행 글")
for i, t in names do
	expect(t.width > 0 and t.width + S.nameX + S.statusW <= w, "이름은 진행 글과 겹치지 않는 폭 안")
	eq(t.value, answer.daily[i].name, "줄의 이름 = 서버의 줄")
	eq(t.tint, if answer.daily[i].locked then "off" else "text", "잠긴 줄은 흐림")
	eq(status[i].tint, if answer.daily[i].done then "accent" elseif answer.daily[i].locked then "off" else "gold", "진행 글의 색(끝냄 = 민트)")
end
local checks = 0
for _, bx in boxes do
	if bx.color == "ink" and bx.w == 1 and bx.h == 2 then
		checks += 1
	end
end
eq(checks, 7 * dd, "끝낸 줄마다 체크(점 일곱)")
local resetText = nil
for _, t in texts do
	if t.y == S.resetY then
		resetText = t.value
	end
end
-- (다음 초기화 줄은 창을 지을 때 만든 것 — 다시 그릴 때 글만 바뀐다: 처음 목록에서 찾는다)
-- 주간 탭을 누른다 → 바뀌고 다시 묻는다
local before = fetched
tabs[2].click()
expect(ScheduleWindow.tab == "weekly", "주간 탭으로")
expect(fetched == before + 1, "탭을 바꾸면 다시 묻는다")
local wn = 0
for _, t in texts do
	if t.x == S.nameX and t.value == b.name then
		wn += 1
	end
end
expect(wn >= 1, "주간 탭에 보스의 줄")
local beaten = false
for _, t in texts do
	if t.opts.align == "right" and string.find(t.value, Weekly.DATA.modes.hard.name, 1, true) and t.tint == "accent" then
		beaten = true
	end
end
expect(beaten, "격파한 보스 = 「하드 격파」 민트")
ScheduleWindow.tab = "daily"
