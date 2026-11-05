-- 스케줄러(2026-11-03 사용자 "스케줄러를 만들어서 모바일,pc 에서 스케줄러 ui 가 나오고 일일퀘스트, 보스 했는지 이번주 잡았는지, 오늘 깼는지 던전 이런거 보이고
--  깨면 체크표시되고 메이플에 스케줄러기능이있어 참고하면된다"). 메이플스토리의 스케줄러(일일 · 주간 컨텐츠의 진행과 보스 클리어 현황을 한 창에서 — 끝낸 것에 체크)처럼
--  이 캐릭터가 매일 · 매주 할 일을 모아 보여 준다(보기만 한다 — 하는 곳은 그 자리: 게시판 · 토벌대장 · 던전의 문 · 보스의 문).
--  일일: 출석(계정) · 일일 의뢰(게시판마다 — 오늘 낸 의뢰 / 둘) · 수정 틈 토벌(오늘 받은 보상 / 둘) · 던전마다(오늘 끝냈나)
--  주간: 보스마다(이번 주 격파 — 노말 · 하드 가운데 하나)
--  줄 = { id, name, text, done(체크) , locked(아직 열리지 않았다 — 흐림) } · 셈만 한다(저장을 바꾸지 않는다 — 날이 바뀐 기록은 0으로 읽는다)
--  글은 공방 js/lune/design/ui.js의 SCHEDULE(ui.generated의 schedule) · 창은 client/lune/ui/scheduleWindow.luau · 공방 시험 탭 ui/paint.js의 paintSchedule
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local CITY = require(lune.data["city.generated"])
local Daily = require(script.Parent.daily)
local Weekly = require(script.Parent.weekly)
local Attend = require(script.Parent.attend)
local Format = require(lune.ui.format)

local Schedule = {}
local W = UI.schedule

-- 일일 의뢰 게시판의 차례(여는 레벨이 낮은 것부터)
local function boards(): { string }
	local list = {}
	for region in Daily.DATA.boards do
		table.insert(list, region)
	end
	table.sort(list, function(a, b)
		local fa, fb = Daily.DATA.boards[a].from or 0, Daily.DATA.boards[b].from or 0
		return if fa ~= fb then fa < fb else a < b
	end)
	return list
end

-- 남은 시간 글(「3시간 12분」 · 「12분」)
local function leftText(s: number): string
	local m = math.max(1, math.ceil(s / 60))
	if m >= 60 then
		return Format.fill(W.hour, { h = math.floor(m / 60), m = m % 60 })
	end
	return Format.fill(W.min, { m = m })
end
Schedule.leftText = leftText

-- h = 캐릭터 · acct = 계정(출석 — 없으면 그 줄을 뺀다) · now = 지금(초)
function Schedule.view(h, acct, now: number)
	local today = Daily.dayOf(now)
	local daily, weekly = {}, {}
	-- 출석(계정의 것 — 그날 처음 들어오면 칸이 차고, 받으면 끝)
	local att = acct and acct.att
	if att then
		local ready = Attend.ready(att)
		local checked = att.last == today
		table.insert(daily, { id = "attend", name = W.attend, text = if ready > 0 then Format.fill(W.claim, { n = ready }) elseif checked then W.done else Format.fill(W.today, { a = 0, b = 1 }), done = checked and ready <= 0, locked = false })
	end
	-- 일일 의뢰: 게시판마다 오늘 낸 수 / 의뢰 수(여는 레벨 전이면 잠김)
	for _, region in boards() do
		local b = Daily.DATA.boards[region]
		local need = math.max(Daily.DATA.from, b.from or 0)
		local st = h.daily and h.daily[region]
		local n, done = b.perDay or Daily.DATA.perDay or 2, 0 -- (게시판마다의 수 — 기도 탑 = 셋)
		if st and st.day == today then
			n = #st.tasks
			for _, t in st.tasks do
				if t.st == Daily.DONE then
					done += 1
				end
			end
		end
		local locked = h.level < need
		table.insert(daily, { id = "daily:" .. region, name = Format.fill(W.daily, { place = b.name }), text = if locked then Format.fill(W.low, { a = need }) elseif done >= n then W.done else Format.fill(W.today, { a = done, b = n }), done = not locked and done >= n, locked = locked })
	end
	-- 수정 틈 토벌: 오늘 받은 보상 / 하루의 수
	do
		local D = CITY.rift
		local r = h.rift or {}
		local used = if r.day == today then r.used or 0 else 0
		local need = D.tiers[1].lv
		local locked = h.level < need
		table.insert(daily, { id = "rift", name = W.rift, text = if locked then Format.fill(W.low, { a = need }) elseif used >= D.perDay then W.done else Format.fill(W.today, { a = used, b = D.perDay }), done = not locked and used >= D.perDay, locked = locked })
	end
	-- 던전마다: 오늘 끝냈나(문은 그 퀘스트를 끝내야 열린다 · 레벨 구간)
	for _, t in CITY.dungeon.tiers do
		local q = h.quests and h.quests[t.quest]
		local open = q ~= nil and q.done == true
		local finished = ((h.rift or {}).dungeon or {})[t.id] == today
		local text, locked
		if finished then
			text, locked = W.done, false
		elseif not open then
			text, locked = W.closed, true
		elseif h.level < t.lv then
			text, locked = Format.fill(W.low, { a = t.lv }), true
		elseif h.level > t.lvMax then
			text, locked = Format.fill(W.high, { b = t.lvMax }), true
		else
			text, locked = Format.fill(W.today, { a = 0, b = 1 }), false
		end
		table.insert(daily, { id = "dungeon:" .. t.id, name = t.name, text = text, done = finished, locked = locked })
	end
	-- 주간 보스마다: 이번 주 격파(노말 · 하드 가운데 하나 — 한국 시간 목요일 0시에 다시)
	for _, b in Weekly.DATA.bosses do
		if b.dev or not require(script.Parent.reveal).open(b.id, now) then
			continue -- 퍼블리시하지 않는 보스(2026-11-04) · 아직 출현하지 않은 보스(2026-11-05 — 출현하면 줄이 생긴다)
		end
		local q = h.quests and h.quests[b.quest]
		local open = q ~= nil and q.done == true
		local mode = Weekly.done(h.rift, b.id, now)
		local need = b.normal and b.normal.need or 1
		local text, locked
		if mode then
			text, locked = Format.fill(W.beaten, { mode = Weekly.DATA.modes[mode] and Weekly.DATA.modes[mode].name or "" }), false
		elseif not open then
			text, locked = W.closed, true
		elseif h.level < need then
			text, locked = Format.fill(W.low, { a = need }), true
		else
			text, locked = Format.fill(W.week, { a = 0, b = 1 }), false
		end
		table.insert(weekly, { id = "boss:" .. b.id, name = b.name, text = text, done = mode ~= nil, locked = locked })
	end
	local week = Weekly.view(h.rift, now)
	return { daily = daily, weekly = weekly, dayLeft = Daily.left(now), weekLeft = week.reset }
end

-- 끝낸 수 · 할 수 있는 수(잠긴 줄은 빼고) — 탭 이름 옆의 「2/5」
function Schedule.count(rows): (number, number)
	local done, total = 0, 0
	for _, r in rows or {} do
		if not r.locked then
			total += 1
			if r.done then
				done += 1
			end
		end
	end
	return done, total
end

return Schedule
