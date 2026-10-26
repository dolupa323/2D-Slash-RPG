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

local TitleServer = {}
TitleServer.RETRY = 60 -- 적지 못했을 때(저장소 탈) 다시 해 보기까지(초)

local ten = nil -- 아는 열 사람의 기록(서버가 켜질 때 읽는다 — 읽기 전이면 nil)
local busy, failAt = false, -math.huge

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
function TitleServer.start()
	load()
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
	local got = {}
	for _, t in Titles.LIST do
		if t.rule == "admin" and not admin and h.titles[t.id] then
			h.titles[t.id] = nil -- 관리자가 아닌데 가지고 있다: 뺀다
			if h.title == t.id then
				h.title = nil
			end
			s.dirty = true
		end
		local mine = (t.rule == "admin" and admin == true) or (t.rule == "first" and first ~= nil and first.key == key) or (t.rule == "ten" and ten ~= nil and has(ten, key))
		if mine and Titles.give(h, t.id) then
			table.insert(got, t.id)
		end
	end
	return got
end

-- (자동 검사: 기록을 비운다)
function TitleServer.reset(list)
	ten, busy, failAt = list, false, -math.huge
end

return TitleServer
