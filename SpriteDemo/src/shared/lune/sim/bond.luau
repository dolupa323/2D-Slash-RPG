-- 2편(Lv.30~59)의 도시 생활 — 만나면 열림 · 모험의 서 · 달조각 · 숨은 이야기(공방 js/lune/design/city.js — 2026-10-16).
--  사용자 2026-10-16: "작은마을에서 벗어나서 대도시로 진입해서 사람들과 커넥션해서 하는 컨텐츠들이 연결되고 로스트아크로 치면 베른 북부 첫 진입과 같다. 퀘스트는 필수 진행이 아니라, 여기저기 흩어져있고"
--  같은 날 사용자: "호감도는 왜만드는거고" → 호감도(단계 · 선물 · 단계 보상)를 뺐다. 사람과 이어지는 것 = 「만나면 열림」: 도시의 그 사람(D.meet)에게 처음 말을 걸면 인사를 나누고, 그때 그 사람의 기능이 열린다.
--  캐릭터마다(h.bond — 퀘스트가 캐릭터마다라서 · 제 결정). 화면도 서버도 모르는 순수한 셈이다(서버는 이것으로 바꾸고, 화면은 view를 받아 그린다).
--  b = { met = { [사람] = true } · shard = { [id] = true } · story = { [id] = true } · kill = { [몬스터] = 잡은 수(모험의 서의 몫까지만) } · tome = { [곳] = { [%] = true } } · open = 모험의 서가 열렸다 }
local lune = script.Parent.Parent
local D = require(lune.data["city.generated"])
local Gift = require(script.Parent.gift)

local Bond = {}
Bond.DATA = D
Bond.SHARD_REACH = { x = 14, y = 24 } -- 달조각에 닿는 거리(도트 — 발밑에서)
Bond.STORY_REACH = { x = 28, y = 30 } -- 숨은 이야기 앞(↑)

local shardById, storyById = {}, {}
for _, x in D.shards do
	shardById[x.id] = x
end
for _, x in D.stories do
	storyById[x.id] = x
end
Bond.shard = function(id: any)
	return if typeof(id) == "string" then shardById[id] else nil
end
Bond.story = function(id: any)
	return if typeof(id) == "string" then storyById[id] else nil
end
-- 모험의 서가 세는 몬스터 { [몬스터] = true }
local tomeMobs = {}
for _, a in D.tome.areas do
	for _, kind in a.mobs do
		tomeMobs[kind] = true
	end
end

function Bond.new()
	return { met = {}, shard = {}, story = {}, kill = {}, tome = {}, open = false }
end

-- ---------- 만나면 열림 ----------
-- 처음 인사를 나누면 기능이 열리는 사람인가(D.meet — 대장장이 담금 · 창고지기 한아름 · 경매사 금송 · 의뢰 접수원 소담 · 토벌대장 무진)
function Bond.isMeet(npc: any): boolean
	return typeof(npc) == "string" and D.meet[npc] ~= nil
end
-- 그 사람의 기능이 열렸는가(만나는 사람이 아니면 늘 열려 있다)
function Bond.opened(b, npc: any): boolean
	return not Bond.isMeet(npc) or b.met[npc] == true
end
-- 처음 인사를 나눴다: 처음이면 true(그때 기능이 열린다)
function Bond.meet(b, npc: any): boolean
	if not Bond.isMeet(npc) or b.met[npc] then
		return false
	end
	b.met[npc] = true
	return true
end

-- ---------- 달조각 · 숨은 이야기 · 몬스터 ----------
-- 그 자리에 서 있으면 그 맵의 아직 못 주운 달조각을 줍는다(서버가 자리 보고마다 — 닿으면 줍는다). 주운 것의 id
function Bond.touchShard(b, scene: string, x: number, y: number): string?
	for _, s in D.shards do
		if s.scene == scene and not b.shard[s.id] and math.abs(s.x - x) <= Bond.SHARD_REACH.x and math.abs(s.y - y) <= Bond.SHARD_REACH.y then
			b.shard[s.id] = true
			return s.id
		end
	end
	return nil
end
-- 숨은 이야기를 읽는다(그 앞에서 ↑). 처음 읽었으면 true(이미 읽었어도 글은 다시 볼 수 있다 — 화면이 그대로 띄운다)
function Bond.read(b, id: any, scene: string, x: number, y: number): (boolean?, string?)
	local st = Bond.story(id)
	if not st then
		return nil, "없는 이야기다"
	elseif st.scene ~= scene or math.abs(st.x - x) > Bond.STORY_REACH.x or math.abs(st.y - y) > Bond.STORY_REACH.y then
		return nil, "그 앞이 아니다"
	end
	local first = not b.story[id]
	b.story[id] = true
	return first
end
-- 몬스터를 잡았다(모험의 서의 몫까지만 센다)
function Bond.onKill(b, kind: string)
	if tomeMobs[kind] then
		local n = b.kill[kind] or 0
		if n < D.tome.mobNeed then
			b.kill[kind] = n + 1
		end
	end
end

-- ---------- 모험의 서 ----------
-- 곳 하나의 칸들: { parts = { quest = { a, b }, mob = …, shard = …, story = … }, have, total, pct }
function Bond.area(b, book, areaId: string)
	local a = nil
	for _, x in D.tome.areas do
		if x.id == areaId then
			a = x
		end
	end
	if not a then
		return nil
	end
	local parts = {}
	local q = 0
	for _, id in a.quests do
		if book[id] and book[id].done then
			q += 1
		end
	end
	parts.quest = { q, #a.quests }
	local m = 0
	for _, kind in a.mobs do
		if (b.kill[kind] or 0) >= D.tome.mobNeed then
			m += 1
		end
	end
	parts.mob = { m, #a.mobs }
	local sh = 0
	for _, id in a.shards do
		if b.shard[id] then
			sh += 1
		end
	end
	parts.shard = { sh, #a.shards }
	local stc = 0
	for _, id in a.stories do
		if b.story[id] then
			stc += 1
		end
	end
	parts.story = { stc, #a.stories }
	local have, total = 0, 0
	for _, p in parts do
		have += p[1]
		total += p[2]
	end
	return { id = a.id, name = a.name, parts = parts, have = have, total = total, pct = if total > 0 then math.floor(have * 100 / total) else 0 }
end
-- 모험의 서의 보상을 받는다(그곳의 %가 됐고 아직 안 받았다)
function Bond.claimTome(h, book, areaId: any, pct: any): (any, string?)
	local b = h.bond
	if not b.open then
		return nil, "아직 모험의 서가 없다"
	end
	local view = typeof(areaId) == "string" and Bond.area(b, book, areaId)
	if not view then
		return nil, "없는 곳이다"
	end
	local reward = nil
	for _, r in D.tome.rewards do
		if r.pct == pct then
			reward = r
		end
	end
	if not reward then
		return nil, "없는 보상이다"
	end
	b.tome[areaId] = b.tome[areaId] or {}
	if b.tome[areaId][tostring(pct)] then
		return nil, "이미 받았다"
	elseif view.pct < pct then
		return nil, ("%d%%가 되면 받는다"):format(pct)
	end
	local ok, why = Gift.give(h, reward.give)
	if not ok then
		return nil, why
	end
	b.tome[areaId][tostring(pct)] = true
	return reward.give
end

-- ---------- 화면에 보내는 꼴 ----------
-- met = { [사람] = true } · tome = { 곳마다 Bond.area + got = { [%] = true } } · shard · story · kill · open
function Bond.view(h, _now: number?)
	local b = h.bond
	local out = { met = {}, shard = {}, story = {}, kill = {}, tome = {}, open = b.open }
	for npc in b.met do
		out.met[npc] = true
	end
	for id in b.shard do
		out.shard[id] = true
	end
	for id in b.story do
		out.story[id] = true
	end
	for kind, n in b.kill do
		out.kill[kind] = n
	end
	for _, a in D.tome.areas do
		local v = Bond.area(b, h.quests, a.id)
		v.got = {}
		for k in b.tome[a.id] or {} do
			v.got[k] = true
		end
		table.insert(out.tome, v)
	end
	return out
end
-- 받을 것이 있는가(메뉴의 점): 모험의 서의 %
function Bond.ready(view): boolean
	if view.open then
		for _, a in view.tome do
			for _, r in D.tome.rewards do
				if a.pct >= r.pct and not a.got[tostring(r.pct)] then
					return true
				end
			end
		end
	end
	return false
end

-- ---------- 저장 ----------
local function whole(v: any, lo: number, hi: number): boolean
	return typeof(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end
function Bond.pack(b)
	return { met = b.met, shard = b.shard, story = b.story, kill = b.kill, tome = b.tome, open = b.open }
end
function Bond.unpack(data: any)
	local b = Bond.new()
	if typeof(data) ~= "table" then
		return b
	end
	for npc, v in (typeof(data.met) == "table" and data.met or {}) do
		if v == true and Bond.isMeet(npc) then
			b.met[npc] = true
		end
	end
	for id, v in (typeof(data.shard) == "table" and data.shard or {}) do
		if v == true and shardById[id] then
			b.shard[id] = true
		end
	end
	for id, v in (typeof(data.story) == "table" and data.story or {}) do
		if v == true and storyById[id] then
			b.story[id] = true
		end
	end
	for kind, n in (typeof(data.kill) == "table" and data.kill or {}) do
		if tomeMobs[kind] and whole(n, 0, D.tome.mobNeed) then
			b.kill[kind] = n
		end
	end
	for area, list in (typeof(data.tome) == "table" and data.tome or {}) do
		if typeof(area) == "string" and typeof(list) == "table" then
			b.tome[area] = {}
			for k, v in list do
				if typeof(k) == "string" and v == true then
					b.tome[area][k] = true
				end
			end
		end
	end
	b.open = data.open == true
	return b
end

return Bond
