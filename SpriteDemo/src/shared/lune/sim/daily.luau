-- 일일 의뢰의 셈 — 화면도 서버도 모르는 셈이다(서버 server/lune/modules/world.luau의 onDaily · 화면 client/lune/ui/dailyWindow.luau가 부른다).
--  사용자 2026-10-13: "일일 퀘스트 필요합니다. 게시판이랑 상호작용해서 일퀘받는거 좋습니다. 근데 좀더 간결하게 해도 될거 같습니다.  5분쯤 걸리게 / 일일 의뢰는 10부터 열죠"
--  규칙과 수는 공방의 js/lune/design/daily.js(data/daily.generated.luau):
--   · Lv.10부터 · 마을의 의뢰 게시판 앞에서 받고 낸다 · 하루 둘 — 내 레벨로 갈 수 있는 사냥터 가운데 레벨이 높은 near곳에서 그 몬스터 30마리씩
--   · 날마다 자정(한국 시간)에 새 의뢰로 바뀐다(받아 두고 못 끝낸 것 · 다 잡고 안 낸 것도 그때 사라진다)
--   · 보상은 내 레벨의 것: 의뢰 하나를 낼 때마다 경험치 · 달돈, 그날의 의뢰를 모두 내면 덤으로 달가루
--  캐릭터의 표에 얹는 것: h.daily = { [지역] = { day = 그 의뢰들의 날, tasks = { { scene, mob, n, have, st } … }, bonus = 덤을 받았는가 } }
--   st = 0 안 받음 · 1 하는 중(have가 n이 되면 낼 수 있다) · 2 냈다
local DATA = require(script.Parent.Parent.data["daily.generated"])
local Quests = require(script.Parent.quests) -- 줄의 몬스터를 피한다(Quests.lineMobs)

local Daily = {}
Daily.DATA = DATA
Daily.FROM = DATA.from
Daily.WORDS = DATA.words
Daily.REGION = "r1" -- 처음의 게시판(초승달 마을)
-- 그 장면 · 그 주민(게시판 · 의뢰 접수원)이 맡은 지역(없으면 nil) — 2026-10-16: 지역마다 게시판(은달 항구 = 수정 숲)
function Daily.regionAt(scene: string, npc: string?): string?
	for region, b in DATA.boards do
		if b.scene == scene and (npc == nil or b.npc == npc) then
			return region
		end
	end
	return nil
end
Daily.OPEN, Daily.ON, Daily.DONE = 0, 1, 2

local function whole(v: any, lo: number, hi: number): boolean
	return typeof(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

-- 풀에서 그 장면의 그 몬스터를 찾는다(없으면 nil)
local function entry(region: string, scene: any, mob: any)
	local board = DATA.boards[region]
	for _, q in (if board then board.pool else {}) do
		if q.scene == scene and q.mob == mob then
			return q
		end
	end
	return nil
end
Daily.entry = entry

-- 그 시각(os.time)의 날짜 번호 — 자정(한국 시간)에 넘어간다 · 다음 자정까지 남은 초
function Daily.dayOf(now: number): number
	return math.floor((now + DATA.offset * 3600) / 86400)
end
function Daily.left(now: number): number
	return 86400 - (now + DATA.offset * 3600) % 86400
end

-- 그 레벨 · 그날의 의뢰들: 갈 수 있는 사냥터(그 몬스터의 가장 낮은 레벨 ≤ 내 레벨) 가운데 레벨이 높은 near곳에서 차례로 돈다(공방의 dailyPick과 같은 셈)
--  skip = 피할 몬스터(퀘스트 줄에서 아직 끝내지 않은 퀘스트의 몬스터 — Quests.lineMobs): 지나온 사냥터에서 뽑는다. 다 빠지면 예전대로(2026-10-15)
function Daily.pick(region: string, level: number, day: number, skip: { [string]: boolean }?)
	local can, top = {}, {}
	for _, q in DATA.boards[region].pool do
		if q.lv[1] <= level then
			table.insert(can, q)
			if not (skip and skip[q.mob]) then
				table.insert(top, q)
			end
		end
	end
	if #top == 0 then
		top = can
	end
	while #top > DATA.near do
		table.remove(top, 1)
	end
	local out = {}
	for i = 1, DATA.perDay do
		local q = top[(day + i - 1) % #top + 1]
		out[i] = { scene = q.scene, mob = q.mob, n = DATA.kills, have = 0, st = Daily.OPEN }
	end
	return out
end

-- 오늘의 것으로 맞춘다(처음이거나 날이 바뀌었으면 새로 뽑는다). 돌려주는 것: 그 지역의 상태(아직 열리지 않은 레벨 · 게시판이 없는 지역이면 nil), 새로 뽑았는가
function Daily.sync(h, region: string, now: number)
	local board = DATA.boards[region]
	if not board or h.level < math.max(DATA.from, board.from or 0) then -- 게시판마다 여는 레벨(은달 항구의 것은 Lv.30 — 2026-10-16)
		return nil, false
	end
	local day = Daily.dayOf(now)
	local st = h.daily[region]
	if st and st.day == day then
		-- 마릿수의 설계가 바뀌었으면 아직 내지 않은 의뢰를 새 수로 맞춘다(2026-10-13: 30 → 8 — 받아 둔 30마리짜리가 자정까지 남지 않게)
		for _, t in st.tasks do
			if t.st ~= Daily.DONE and t.n ~= DATA.kills then
				t.n = DATA.kills
				t.have = math.min(t.have, t.n)
			end
		end
		return st, false
	end
	st = { day = day, tasks = Daily.pick(region, h.level, day, Quests.lineMobs(h.quests or {}, region)), bonus = false }
	h.daily[region] = st
	return st, true
end

function Daily.isReady(t): boolean
	return t.st == Daily.ON and t.have >= t.n
end

-- 의뢰를 받는다(게시판 앞에서 — 자리는 서버가 본다). 받아야 세기 시작한다
function Daily.accept(h, region: string, i: any, now: number): (boolean?, string?)
	local st = Daily.sync(h, region, now)
	local t = st and st.tasks[i]
	if not t then
		return nil, DATA.words.early
	elseif t.st ~= Daily.OPEN then
		return nil, "이미 받은 의뢰다"
	end
	t.st, t.have = Daily.ON, 0
	return true, nil
end

-- 몬스터를 잡았다: 하는 중인 오늘의 의뢰 가운데 그 장면의 그 몬스터인 것을 하나 센다. 돌려주는 것: 센 것이 있는가
function Daily.onKill(h, mob: string, scene: string, now: number): boolean
	local day = Daily.dayOf(now)
	local changed = false
	for _, st in h.daily do
		if st.day == day then -- 날이 바뀐 뒤에는 어제의 의뢰를 세지 않는다(게시판에 가면 새 의뢰로 바뀐다)
			for _, t in st.tasks do
				if t.st == Daily.ON and t.have < t.n and t.mob == mob and t.scene == scene then
					t.have += 1
					changed = true
				end
			end
		end
	end
	return changed
end

-- 의뢰를 낸다: 달돈(과 덤의 달가루)은 여기서 얹고, 경험치는 돌려준 값을 부른 쪽이 준다(레벨 업을 알려야 한다).
--  돌려주는 것: { xp, money, dust(덤 — 그날의 의뢰를 모두 냈을 때만 0보다 크다), all = 모두 냈는가, name = 그 몬스터의 이름 } 또는 nil과 까닭
function Daily.turnIn(h, region: string, i: any, now: number)
	local st = Daily.sync(h, region, now)
	local t = st and st.tasks[i]
	if not t then
		return nil, DATA.words.early
	elseif not Daily.isReady(t) then
		return nil, DATA.words.notYet
	end
	t.st = Daily.DONE
	local level = math.clamp(h.level, 1, #DATA.pay.xp)
	local q = entry(region, t.scene, t.mob)
	local reward = { xp = DATA.pay.xp[level], money = DATA.pay.money[level], dust = 0, all = true, name = if q then q.name else "" }
	h.money += reward.money
	for _, x in st.tasks do
		reward.all = reward.all and x.st == Daily.DONE
	end
	if reward.all and not st.bonus then
		st.bonus = true
		reward.dust = DATA.pay.dust[level]
		h.dust += reward.dust
	end
	return reward, nil
end

-- 화면에 보내는 것: { from, left(다음 자정까지 초), boards = { [지역] = { tasks = { { scene, mob, name, place, n, have, st } … }, bonus, pay = { xp, money, dust }(내 레벨의 것) } } }
--  아직 열리지 않은 레벨이면 boards가 비어 있다. 날이 바뀌었으면 여기서 새 의뢰로 바뀐다(둘째 값 = 바뀌었는가 — 저장해야 한다)
function Daily.view(h, now: number)
	local out = { from = DATA.from, left = Daily.left(now), boards = {} }
	local fresh = false
	local level = math.clamp(h.level, 1, #DATA.pay.xp)
	for region in DATA.boards do
		local st, new = Daily.sync(h, region, now)
		fresh = fresh or new
		if st then
			local tasks = {}
			for i, t in st.tasks do
				local q = entry(region, t.scene, t.mob)
				tasks[i] = { scene = t.scene, mob = t.mob, name = if q then q.name else "", place = if q then q.place else "", n = t.n, have = t.have, st = t.st }
			end
			out.boards[region] = { tasks = tasks, bonus = st.bonus, pay = { xp = DATA.pay.xp[level], money = DATA.pay.money[level], dust = DATA.pay.dust[level] } }
		end
	end
	return out, fresh
end

-- 게시판 위의 표시(화면이 받은 것으로 셈한다): 낼 것이 있으면 "?" · 아직 안 받은 것이 있으면 "!" · 없으면 nil
function Daily.mark(board: any): string?
	local best: string? = nil
	for _, t in (if board then board.tasks else {}) do
		if Daily.isReady(t) then
			return "?"
		elseif t.st == Daily.OPEN then
			best = "!"
		end
	end
	return best
end

-- 알리미에 적을 것(화면이 받은 것으로): 하는 중인 의뢰들 { name, place, n, have }
function Daily.tracked(view: any)
	local out = {}
	for region in DATA.boards do
		local board = view and view.boards and view.boards[region]
		for i, t in (if board then board.tasks else {}) do
			if t.st == Daily.ON then
				table.insert(out, { name = t.name, place = t.place, n = t.n, have = t.have, region = region, i = i }) -- region · i = 길찾기가 그 의뢰를 가리킬 때 쓴다
			end
		end
	end
	return out
end

-- ---------- 저장 ----------
function Daily.pack(d)
	local out = {}
	for region, st in d do
		local tasks = {}
		for i, t in st.tasks do
			tasks[i] = { scene = t.scene, mob = t.mob, n = t.n, have = t.have, st = t.st }
		end
		out[region] = { day = st.day, tasks = tasks, bonus = st.bonus }
	end
	return out
end

-- 저장된 것을 되살린다: 꼴이 맞지 않는 지역의 것은 버린다(게시판에 가면 오늘의 의뢰를 새로 받는다 — 잃는 것은 그날의 진행뿐이다)
function Daily.unpack(data: any)
	local out = {}
	if typeof(data) ~= "table" then
		return out
	end
	for region in DATA.boards do
		local st = data[region]
		if typeof(st) == "table" and whole(st.day, 0, 1e7) and typeof(st.tasks) == "table" then
			local tasks, fine = {}, true
			for i = 1, DATA.perDay do
				local t = st.tasks[i]
				if typeof(t) == "table" and entry(region, t.scene, t.mob) and whole(t.n, 1, 9999) and whole(t.have, 0, t.n) and whole(t.st, Daily.OPEN, Daily.DONE) then
					tasks[i] = { scene = t.scene, mob = t.mob, n = t.n, have = t.have, st = t.st }
				else
					fine = false
				end
			end
			if fine then
				out[region] = { day = st.day, tasks = tasks, bonus = st.bonus == true }
			end
		end
	end
	return out
end

return Daily
