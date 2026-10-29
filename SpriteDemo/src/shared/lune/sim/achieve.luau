-- 업적의 셈 — 계정이 같이 쌓는다(공방 js/lune/design/achieve.js — 2026-10-15 · 사용자: "출석보상, 업적 만들어야합니다"; 목록 · 점수 · 등급 · 보상은 제 제안).
--  계정의 표 acct.ach = { c = { [셈] = 수 }(kill · partyKill · craft · dismantle · party · sold · daily · attend · death · fail), kinds = { [몬스터] = true }(쓰러뜨린 종류),
--   seen = { [장면] = true }(들른 맵), star = 강화로 붙인 가장 높은 별, done = { [업적] = true }(해냄), got = { [업적] = true }(보상을 받음) }
--  레벨 · 차수 · 퀘스트처럼 캐릭터가 가진 것은 셀 때의 사정(ctx)으로 본다: { level, job, classes = { [직업] = 가장 높은 레벨 }, quests = 지금 캐릭터의 퀘스트 책, star = 지금 가진 장비의 가장 높은 별, att = 출석의 표 }
--  한 번 해낸 업적은 계정에 남는다(다른 캐릭터로 들어가도 그대로). 단계(after)가 있는 것은 앞 단계를 해낸 뒤에 보이고 그 뒤에야 해낼 수 있다(목록의 차례가 앞 단계가 먼저다).
local data = script.Parent.Parent.data
local D = require(data["achieve.generated"])
local SCENES = require(data["scenes.generated"])
local ATT = require(data["attend.generated"])
local Quests = require(script.Parent.quests)
local Gift = require(script.Parent.gift)

local Achieve = {}
Achieve.DATA = D
Achieve.WORDS = D.words
Achieve.LIST = D.list
Achieve.BY = {} :: { [string]: any }
for i, def in D.list do
	def.order = i
	Achieve.BY[def.id] = def
end
Achieve.COUNTS = { kill = true, partyKill = true, craft = true, dismantle = true, party = true, sold = true, daily = true, attend = true, death = true, fail = true, shard = true, story = true, rift = true } -- shard · story · rift(토벌) = 2편(2026-10-16 — 호감도를 빼며 friend도 뺐다)

-- 지역의 맵(들를 곳 — 그 지역의 바깥 맵 · 실내와 꿈은 빼고)과 몬스터의 종류(그 지역 장면의 몬스터 · 꿈의 수련 인형은 빼고) — 장면 자료의 region으로 센다
Achieve.REGION = {} :: { [string]: { maps: { string }, kinds: { string }, mapSet: { [string]: boolean }, kindSet: { [string]: boolean } } }
local function regionOf(r: string)
	local got = Achieve.REGION[r]
	if got then
		return got
	end
	local maps, kinds, mapSet, kindSet = {}, {}, {}, {}
	for key, sc in SCENES.scenes do
		if sc.region == r and key ~= "dream" then
			if not sc.indoor then
				table.insert(maps, key)
				mapSet[key] = true
			end
			-- 몬스터의 종류는 언제든 다시 갈 수 있는 바깥 맵의 것만(2026-10-26 사용자 "지금 업적중에 안깨지는거 다 확인해라": 전에는 실내 · 파티마다 따로 들어가는 퀘스트 방의 것도 들어가,
			--  초승 고개에서는 지하실(in_cellar — 한 번뿐인 이야기 방)에만 나오는 수련 인형(dummy) · 정예 창병(espearman)을 잡아야 해서 그 방을 지난 사람은 깰 수 없었다)
			for _, m in (if sc.indoor or sc.inst then {} else sc.mobs or {}) do
				if not kindSet[m.kind] then
					kindSet[m.kind] = true
					table.insert(kinds, m.kind)
				end
			end
		end
	end
	table.sort(maps)
	table.sort(kinds)
	got = { maps = maps, kinds = kinds, mapSet = mapSet, kindSet = kindSet }
	Achieve.REGION[r] = got
	return got
end
for _, def in D.list do
	if def.goal.region then
		regionOf(def.goal.region)
	end
end

local function whole(v: any, lo: number, hi: number): boolean
	return typeof(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

function Achieve.new()
	return { c = {}, kinds = {}, seen = {}, star = 0, done = {}, got = {} }
end

local function keysOf(set): { string }
	local out = {}
	for k in set do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

function Achieve.pack(a)
	return { c = table.clone(a.c), kinds = keysOf(a.kinds), seen = keysOf(a.seen), star = a.star, done = keysOf(a.done), got = keysOf(a.got) }
end

-- 저장된 것(없거나 꼴이 이상한 것은 버린다)
function Achieve.unpack(v: any)
	local a = Achieve.new()
	if typeof(v) ~= "table" then
		return a
	end
	if typeof(v.c) == "table" then
		for k in Achieve.COUNTS do
			if whole(v.c[k], 0, 1e12) then
				a.c[k] = v.c[k]
			end
		end
	end
	local function setOf(list, into, known: (string) -> boolean)
		if typeof(list) ~= "table" then
			return
		end
		for i, k in list do
			if typeof(i) ~= "number" or i > 2000 then
				break -- (목록이 아닌 꼴로 저장된 것 — 숫자가 아닌 열쇠와 견주면 오류가 났다 · 2026-10-18 검토)
			end
			if typeof(k) == "string" and #k <= 40 and known(k) then
				into[k] = true
			end
		end
	end
	setOf(v.kinds, a.kinds, function()
		return true
	end)
	setOf(v.seen, a.seen, function()
		return true
	end)
	setOf(v.done, a.done, function(k)
		return Achieve.BY[k] ~= nil
	end)
	setOf(v.got, a.got, function(k)
		return a.done[k] == true
	end)
	a.star = if whole(v.star, 0, 99) then v.star else 0
	return a
end

-- ---------- 셈 ----------
function Achieve.add(a, key: string, n: number?)
	if Achieve.COUNTS[key] then
		a.c[key] = (a.c[key] or 0) + (n or 1)
	end
end

-- 몬스터를 쓰러뜨렸다(그 장면에서) — shared = 다른 사람과 함께(파티원이 같은 맵에서)
function Achieve.killed(a, kind: string, scene: string, shared: boolean?)
	Achieve.add(a, "kill")
	if shared then
		Achieve.add(a, "partyKill")
	end
	local sc = SCENES.scenes[scene]
	local r = sc and sc.region and Achieve.REGION[sc.region]
	if r and r.kindSet[kind] then
		a.kinds[kind] = true
	end
end

-- 그 맵에 들렀다
function Achieve.visited(a, scene: string)
	scene = SCENES.base(scene) -- 파티마다 따로 들어가는 장면의 방(r1c4#5)도 그 맵으로(2026-10-21)
	local sc = SCENES.scenes[scene]
	local r = sc and sc.region and Achieve.REGION[sc.region]
	if r and r.mapSet[scene] then
		a.seen[scene] = true
	end
end

-- 강화로 별을 붙였다(그 장비의 별)
function Achieve.forged(a, star: number)
	a.star = math.max(a.star, star)
end

local function lineDefs(region: string)
	local out = {}
	for _, def in Quests.list do
		if def.line and def.region == region and def.playable then
			table.insert(out, def)
		end
	end
	return out
end

-- 그 업적의 진행: 한 것 · 해야 하는 것
function Achieve.progress(a, def, ctx): (number, number)
	local g = def.goal
	local k = g.kind
	if k == "level" then
		return math.min(ctx.level or 1, g.n), g.n
	elseif k == "job" then
		return if (ctx.job or 1) >= g.n then 1 else 0, 1
	elseif k == "classes" then
		local have = 0
		for _, lv in ctx.classes or {} do
			if lv >= g.level then
				have += 1
			end
		end
		return math.min(have, g.n), g.n
	elseif k == "line" then
		local list = lineDefs(g.region)
		local need = g.n or #list
		local have = 0
		for _, q in list do
			local st = ctx.quests and ctx.quests[q.id]
			if st and st.done then
				have += 1
			end
		end
		return math.min(have, need), need
	elseif k == "quest" then
		local st = ctx.quests and ctx.quests[g.id]
		return if st and st.done then 1 else 0, 1
	elseif k == "visit" or k == "kinds" then
		local r = regionOf(g.region)
		local list, set = if k == "visit" then r.maps else r.kinds, if k == "visit" then a.seen else a.kinds
		local have = 0
		for _, x in list do
			if set[x] then
				have += 1
			end
		end
		return have, #list
	elseif k == "star" then
		return math.min(math.max(a.star, ctx.star or 0), g.n), g.n
	elseif k == "attendMonth" then
		local t = ctx.att
		return math.min(if t then t.n else 0, ATT.days), ATT.days
	elseif k == "count" then
		return math.min(a.c[g.key] or 0, g.n), g.n
	end
	return 0, 1
end

-- 보이는가: 앞 단계(after)를 해냈거나 단계가 없다
function Achieve.visible(a, def): boolean
	return not def.after or a.done[def.after] == true
end

-- 새로 해낸 업적을 적는다. 새로 해낸 것의 id들(목록의 차례 — 앞 단계가 먼저라 한 번에 여러 단계를 넘을 수 있다)
function Achieve.check(a, ctx): { string }
	local fresh = {}
	for _, def in D.list do
		if not a.done[def.id] and Achieve.visible(a, def) then
			local have, need = Achieve.progress(a, def, ctx)
			if have >= need then
				a.done[def.id] = true
				table.insert(fresh, def.id)
			end
		end
	end
	return fresh
end

-- 점수와 등급: 점수 · 지금 등급의 이름(없으면 nil) · 다음 등급 { name, from }(가장 높으면 nil)
function Achieve.score(a): number
	local n = 0
	for id in a.done do
		local def = Achieve.BY[id]
		if def then
			n += D.points[def.grade] or 0
		end
	end
	return n
end
function Achieve.grade(score: number): (string?, any)
	local now, nextOne = nil, nil
	for _, g in D.grades do
		if score >= g.from then
			now = g.name
		elseif not nextOne then
			nextOne = g
		end
	end
	return now, nextOne
end

-- 받을 것의 수(해냈고 아직 받지 않은 것)
function Achieve.ready(a): number
	local n = 0
	for id in a.done do
		if not a.got[id] then
			n += 1
		end
	end
	return n
end

-- 보상을 받는다(누른 캐릭터에게). 됐으면 true · 아니면 (nil, 까닭)
function Achieve.claim(a, h, id: any): (boolean?, string?)
	local def = typeof(id) == "string" and Achieve.BY[id] or nil
	if not def or not a.done[def.id] then
		return nil, "아직 해내지 못한 업적이다"
	elseif a.got[def.id] then
		return nil, "이미 받았다"
	end
	local ok, why = Gift.give(h, def.reward)
	if not ok then
		return nil, why
	end
	a.got[def.id] = true
	return true
end

-- 받을 것을 모두(목록의 차례로) — 받은 수와(가방이 차서 멈췄으면) 까닭
function Achieve.claimAll(a, h): (number, string?)
	local n, last = 0, nil
	for _, def in D.list do
		if a.done[def.id] and not a.got[def.id] then
			local ok, why = Achieve.claim(a, h, def.id)
			if ok then
				n += 1
			else
				last = why -- 가방에 들지 않는 것은 건너뛰고 나머지(달돈 · 달가루만 주는 것 등)는 받는다(2026-10-18 검토 — 전에는 거기서 멈췄다)
			end
		end
	end
	return n, last
end

-- 화면에 보내는 것: 점수 · 업적마다 { have, need, st } (st: 0 = 아직 안 보임(앞 단계) · 1 = 하는 중 · 2 = 해냄(받을 것) · 3 = 받음)
function Achieve.view(a, ctx)
	local rows = {}
	for _, def in D.list do
		local have, need = Achieve.progress(a, def, ctx)
		local st = if a.got[def.id] then 3 elseif a.done[def.id] then 2 elseif Achieve.visible(a, def) then 1 else 0
		rows[def.id] = { have = if st >= 2 then need else have, need = need, st = st }
	end
	return { score = Achieve.score(a), rows = rows }
end

return Achieve
