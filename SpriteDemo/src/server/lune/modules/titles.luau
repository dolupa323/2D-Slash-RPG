-- 칭호를 준다(2026-10-26 사용자: "지금 레벨 선착순 150 만렙 달성자들 top 10 까지 칭호 만들어서 발급할거고, 강타는 top10 칭호도 주고, 1위 칭호도 줄거야").
--  세계 기록 둘을 본다(store.luau의 LuneWorld_v1): firstMax(가장 먼저 Lv.150 — 레벨 순위 1위에 고정) → rule first의 칭호 · maxTen(Lv.150에 오른 차례로 열 사람) → rule ten의 칭호.
--  world.luau가 1초마다 그 사람마다 부른다(백금 사슴 CashServer.maxGift 곁). 만렙인 캐릭터가 아직 열 사람의 기록에 없고 열이 차지 않았으면 적어 본다(오른 때 maxAt의 차례로 끼운다 —
--  이것이 생기기 전에 오른 넷은 2026-10-26에 오른 때의 차례로 미리 적어 두었다: 강타 · 0NJ4 · 여왕 · MooNi).
--  관리자 · 확인용 임시 계정 · 시험 봇 · Studio의 캐릭터는 기록에 적지 않는다(만렙 최초 달성과 같다 — 부르는 쪽 world.luau가 eligible로 가린다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Titles = require(lune.sim.titles)
local Rank = require(lune.sim.rank)
local N = require(lune.config.numbers)
local Store = require(script.Parent.store)
local NameRules = require(lune.data["names.generated"]) -- titleNames = 이름으로 주는 칭호의 닉네임(번역하지 않는 파일 — 2026-10-29)

local TitleServer = {}
TitleServer.RETRY = 60 -- 적지 못했을 때(저장소 탈) 다시 해 보기까지(초)
TitleServer.GOLD_EVERY = 30 -- 황금왕의 주가 바뀌었는지 보는 사이(초)
TitleServer.clock = os.time -- 황금왕의 주를 셈하는 시계(자동 검사가 바꾼다)

-- 황금왕(후원 순위 1위 — 2026-10-29 사용자: "로벅스 지출 1위에게 황금왕 이라는 칭호를 지급해 … 매주 목요일마다 확인하고 그 주 1위에게 칭호 지급하고
--  다음주에 바뀌었다면 또 바뀐 1위한테 지급하고 2위한테서 뺏고"): 세계 기록 goldKing { user, week } — 목요일 0시(한국 시간)가 지나면 이 서버가 그때의 후원 판 1위 계정으로 정해 본다
--  (다른 서버가 이미 그 주를 정했으면 그것을 받는다 — store.luau goldKingSettle). 관리자 계정은 후원 판에 오르지 않는다 · 판이 비었으면 그 주는 아무도 없다(user 0).
--  처음 켜질 때 기록이 없으면 그때 바로 정한다(제가 정한 것 — 다음 목요일까지 기다리지 않게)
local gold = nil -- 아는 기록(nil = 아직 못 읽었다)
local goldBusy, goldAt = false, -math.huge
local function settleGold(week: number)
	goldBusy = true
	task.spawn(function()
		local Admin = require(script.Parent.admin)
		local user, spent = 0, 0
		local okTop, rows = pcall(Store.rankTop, "robux", 15)
		if okTop and typeof(rows) == "table" then
			for _, row in rows do
				local id = Rank.userOf(row.key)
				if id and not Admin.isId(id) and typeof(row.score) == "number" and row.score > 0 then
					user, spent = id, row.score
					break
				end
			end
		end
		if okTop then
			local ok, have = pcall(Store.goldKingSettle, week, { user = user, week = week, spent = spent, at = TitleServer.clock() })
			if ok and typeof(have) == "table" then
				gold = have
			end
		end
		goldBusy = false
	end)
end
-- 1초마다(grant가 부른다) — GOLD_EVERY초마다 본다: 아직 못 읽었으면 읽고, 아는 기록의 주가 지났으면 이번 주를 정한다
function TitleServer.goldTick(now: number)
	if goldBusy or now - goldAt < TitleServer.GOLD_EVERY then
		return
	end
	goldAt = now
	local week = Titles.goldWeek(TitleServer.clock())
	if gold == nil then
		goldBusy = true
		task.spawn(function()
			local ok, read, rec = pcall(Store.goldKingGet)
			goldBusy = false
			if ok and read then
				if typeof(rec) == "table" and rec.week == week then
					gold = rec
				elseif not goldBusy then
					settleGold(week) -- 기록이 없거나 지난 주의 것: 이번 주를 정한다
				end
			end
		end)
	elseif gold.week ~= week then
		settleGold(week)
	end
end
-- 지금 아는 황금왕의 기록(없으면 nil — 자동 검사가 본다)
function TitleServer.gold()
	return gold
end

local ten = nil -- 아는 열 사람의 기록(서버가 켜질 때 읽는다 — 읽기 전이면 nil)
local busy, failAt = false, -math.huge
-- 직업마다의 첫 만렙(2026-10-27 사용자: "직업별 첫 만렙 유저들 칭호 만들거야"): [직업] = 기록 { key, name, class, at } · false = 읽었는데 아직 없다 · nil = 아직 못 읽었다
local firsts = {}
local classBusy, classFailAt = {}, {}

local function has(list, key: string): boolean
	for _, r in list or {} do
		if typeof(r) == "table" and r.key == key then
			return true
		end
	end
	return false
end

-- 서버가 켜질 때 한 번: 열 사람의 기록을 읽어 둔다(못 읽으면 RETRY초 뒤에 다시)
local function load()
	task.spawn(function()
		local ok, list = pcall(Store.maxTenGet)
		if ok and typeof(list) == "table" then
			ten = list
		end
	end)
end
-- 직업마다의 첫 만렙 기록을 적어 본다(비어 있을 때만 적힌다 — 이미 있으면 그것이 돌아온다)
local function claimClass(class: string, rec, now: number)
	if classBusy[class] or now - (classFailAt[class] or -math.huge) < TitleServer.RETRY then
		return
	end
	classBusy[class] = true
	task.spawn(function()
		local ok, have = pcall(Store.classFirstClaim, class, rec)
		classBusy[class] = nil
		if ok and typeof(have) == "table" then
			firsts[class] = have
		else
			classFailAt[class] = now
		end
	end)
end
-- 그 직업에서 열 사람의 기록의 가장 이른 사람(그 직업의 첫 만렙 — 열이 차기 전에 오른 사람은 모두 열 사람에 있다)
local function earliestOf(class: string)
	local best = nil
	for _, r in ten or {} do
		if typeof(r) == "table" and r.class == class and typeof(r.at) == "number" and (not best or r.at < best.at) then
			best = r
		end
	end
	return best
end
-- 켜질 때 직업마다 읽는다. 없으면 열 사람의 기록에서 그 직업의 가장 이른 사람으로 채운다(이 칭호가 생기기 전에 오른 사람 — 2026-10-27: 무니 강타 · 살라맨더 0NJ4 · 리퍼 여왕 · 리븐 Ryuville)
-- 그 칭호의 세계 기록 열쇠(classFirst = 그 직업 · named = 「named_<칭호>」 — 이름으로 주는 칭호도 같은 길로: 2026-10-29)
local function recKey(t): string?
	if t.rule == "classFirst" and t.class then
		return t.class
	elseif t.rule == "named" then
		return "named_" .. t.id
	end
	return nil
end
local function loadClasses()
	task.spawn(function()
		for _, t in Titles.LIST do
			local k = recKey(t)
			if k and firsts[k] == nil then
				local ok, got, rec = pcall(Store.classFirstGet, k)
				if ok and got then
					firsts[k] = if typeof(rec) == "table" and rec.key then rec else false
				end
			end
		end
	end)
end
function TitleServer.start()
	load()
	loadClasses()
end

-- 지금 아는 열 사람의 기록(없으면 nil — 자동 검사가 본다)
function TitleServer.ten()
	return ten
end

-- 만렙인 캐릭터를 열 사람의 기록에 적어 본다(이미 있거나 · 다 찼거나 · 적는 중이면 아무것도 하지 않는다)
function TitleServer.tryTen(rec, now: number)
	if busy or now - failAt < TitleServer.RETRY then
		return
	end
	if ten == nil then
		failAt = now
		load() -- 켜질 때 읽지 못했다: 다시 읽는다
		return
	end
	if has(ten, rec.key) or #ten >= Titles.CAP then
		return
	end
	busy = true
	task.spawn(function()
		local ok, list = pcall(Store.maxTenAdd, rec, Titles.CAP)
		busy = false
		if ok and typeof(list) == "table" then
			ten = list
		else
			failAt = now
		end
	end)
end

-- 그 사람(지금 캐릭터)에게 받을 칭호를 준다. first = 세계 기록 firstMax(없으면 nil) · eligible = 기록에 적을 수 있는 사람인가 · admin = 관리자 계정인가.
--  rule goldking(황금왕 — 2026-10-29)은 계정의 칭호: 그 주의 기록의 계정이면 어느 캐릭터든 받고, 기록이 다른 계정으로 바뀌었으면 뺀다(둘째 돌려주는 것 = 뺀 칭호들).
--  rule admin(운영자 — 2026-10-26 사용자 "운영자 칭호도 만들어줘 나만낄수있는거")은 관리자 계정의 캐릭터에만 준다 · 관리자가 아닌데 가지고 있으면 뺀다(달고 있었으면 뗀다).
--  돌려주는 것: 새로 받은 칭호들(없으면 빈 목록)
function TitleServer.grant(s, first, eligible: boolean, now: number, admin: boolean?): { string }
	local h = s.hero
	if not h or not s.cid or s.guest or not h.titles then
		return {}
	end
	local key = Rank.charKey(s.player.UserId, s.cid)
	if eligible and h.level >= N.MAX_LEVEL and h.maxAt then
		TitleServer.tryTen({ key = key, name = s.name, class = h.class, at = h.maxAt }, now)
	end
	-- 직업마다의 첫 만렙: 기록이 비었으면 채운다 — 열 사람의 기록에 그 직업이 있으면 그 가장 이른 사람으로, 없으면 지금 만렙인 이 캐릭터로
	for _, t in Titles.LIST do
		local c = t.class
		if t.rule == "classFirst" and c and firsts[c] == false then
			local seed = earliestOf(c)
			if seed then
				claimClass(c, seed, now)
			elseif eligible and h.class == c and h.level >= N.MAX_LEVEL and h.maxAt and ten ~= nil then
				claimClass(c, { key = key, name = s.name, class = c, at = h.maxAt }, now)
			end
		elseif t.rule == "classFirst" and c and firsts[c] == nil and now - (classFailAt[c] or -math.huge) >= TitleServer.RETRY then
			classFailAt[c] = now
			loadClasses() -- 켜질 때 읽지 못했다: 다시 읽는다
		end
		-- 이름으로 주는 칭호(2026-10-29 — 「앞설 뻔했던 자」 = 리퍼): 기록이 비었고 이 캐릭터의 이름이 그 이름이면 이 캐릭터로 적는다(그 뒤로는 그 캐릭터만)
		if t.rule == "named" then
			local k = "named_" .. t.id
			if firsts[k] == false and eligible and NameRules.titleNames and NameRules.titleNames[t.id] and table.find(NameRules.titleNames[t.id], s.name) then
				claimClass(k, { key = key, name = s.name, class = h.class, at = os.time() }, now)
			elseif firsts[k] == nil and now - (classFailAt["load:" .. k] or -math.huge) >= TitleServer.RETRY then
				classFailAt["load:" .. k] = now -- (읽기를 다시 해 보는 때 — 적기(claimClass)의 기다림과 따로)
				loadClasses()
			end
		end
	end
	TitleServer.goldTick(now)
	local got, lost = {}, {}
	local goldMine = gold ~= nil and gold.user == s.player.UserId
	for _, t in Titles.LIST do
		if t.rule == "admin" and not admin and h.titles[t.id] then
			h.titles[t.id] = nil -- 관리자가 아닌데 가지고 있다: 뺀다
			if h.title == t.id then
				h.title = nil
			end
			s.dirty = true
		end
		if t.rule == "goldking" and gold ~= nil and not goldMine and h.titles[t.id] then
			h.titles[t.id] = nil -- 황금왕이 다른 계정으로 넘어갔다: 뺀다(달고 있었으면 뗀다 — 2026-10-29)
			if h.title == t.id then
				h.title = nil
			end
			s.dirty = true
			table.insert(lost, t.id)
		end
		local rk = recKey(t)
		local rec = if rk then firsts[rk] else nil
		local mine = (t.rule == "admin" and admin == true) or (t.rule == "first" and first ~= nil and first.key == key) or (t.rule == "ten" and ten ~= nil and has(ten, key))
			or ((t.rule == "classFirst" or t.rule == "named") and typeof(rec) == "table" and rec.key == key) or (t.rule == "goldking" and goldMine)
		if mine and Titles.give(h, t.id) then
			table.insert(got, t.id)
		end
	end
	return got, lost
end

-- (자동 검사: 기록을 비운다 · classes = 직업마다의 첫 만렙 기록 [직업] = 기록 · false(없음) — 안 주면 모두 「아직 못 읽었다」)
function TitleServer.reset(list, classes, goldRec)
	ten, busy, failAt = list, false, -math.huge
	firsts, classBusy, classFailAt = classes or {}, {}, {}
	gold, goldBusy, goldAt = goldRec, false, -math.huge
end
-- 지금 아는 직업의 첫 만렙 기록(자동 검사가 본다)
function TitleServer.classFirst(class: string)
	return firsts[class]
end

return TitleServer
