-- 퀘스트 연출(장면)의 셈 — 공방 js/lune/cine.js를 옮긴 것(2026-10-15). 무엇이 언제 끝나고 누가 어디에 있나만 셈하고, 그리기는 client/lune/cineView.luau가 한다.
--  사용자 2026-10-15: "현재 메인 퀘스트 라인 너무스토리 몰입이 안됩니다 … 몰입되는 중간에 연출이 있는것도아니고 다른게임들 어떻게 스토리 진행하는지 좀 파악하고 만들어야합니다."
--  장면 자료 = data/cine.generated.luau(공방 js/lune/design/cine.js — 단계의 뜻은 그 파일의 머리말).
--  w = 세계를 묻는 창구 { hero = () -> { x, y, dir }, npc = (id) -> { x, y, dir, name }?, npcName = (id) -> string?, boss = () -> { x, y }?, cls = 내 직업, heroName = 내 캐릭터의 이름 }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DATA = require(ReplicatedStorage.shared.lune.data["cine.generated"])

local L = DATA.ui
local Cine = {}
Cine.DATA = DATA

local BLOCK = { "bars", "cam", "say", "walk", "die", "wait", "fade", "card", "title", "note", "tint" }
local OTHER = { "face", "mark", "spawn", "hide", "show", "shake", "picture", "sfx" }

-- 단계의 갈래(그 단계에 든 낱말)
function Cine.verbOf(s): string?
	for _, k in BLOCK do
		if s[k] ~= nil then
			return k
		end
	end
	for _, k in OTHER do
		if s[k] ~= nil then
			return k
		end
	end
	return nil
end

local function ease(k: number): number
	return if k < 0.5 then 2 * k * k else 1 - ((-2 * k + 2) ^ 2) / 2
end

-- 그 사람의 지금 자리 { x, y, dir } — 내 캐릭터 · 세운 것 · 보스 · 주민(장면이 옮긴 자리가 먼저)
function Cine.posOf(st, who: string)
	if who == "hero" then
		local h = st.w.hero()
		local o = st.over.hero
		return { x = h.x, y = h.y, dir = (o and o.dir) or h.dir }
	end
	if st.actors[who] then
		return st.actors[who]
	end
	if who == "boss" then
		return if st.w.boss then st.w.boss() else nil
	end
	local n = st.w.npc(who)
	if not n then
		return nil
	end
	local o = st.over[who]
	return { x = (o and o.x) or n.x, y = n.y, dir = (o and o.dir) or n.dir, name = n.name }
end

-- 자리의 가로(도트). 그 사람이 없으면(보스가 아직 나타나지 않았다 · 그 맵에 없는 주민) nil
local function xOf(st, x): number?
	if typeof(x) == "table" then
		local p = Cine.posOf(st, x[1])
		return if p then p.x + x[2] else nil
	elseif typeof(x) == "string" then
		local p = Cine.posOf(st, x)
		return if p then p.x else nil
	end
	return x
end

local function camNow(st): number
	return st.cam or st.w.hero().x
end

-- 말의 이름표: 'none' = 없음(속마음) · 'hero' = 내 캐릭터의 이름 · 세운 주민 = 그 주민의 이름
function Cine.nameOf(st, who: string): string?
	if who == "none" then
		return nil
	end
	if who == "hero" then
		return st.w.heroName
	end
	local a = st.actors[who]
	if a and a.npc then
		local n = st.w.npc(a.npc)
		return (n and n.name) or (st.w.npcName and st.w.npcName(a.npc)) or a.npc
	end
	local n = st.w.npc(who)
	return (n and n.name) or (st.w.npcName and st.w.npcName(who)) or who
end

function Cine.textOf(st, text: string): string
	return (string.gsub(text, "{weapon}", DATA.weapon[st.w.cls] or "무기"))
end

local function finish(st)
	st.done, st.wait = true, nil
	st.actors, st.over, st.marks = {}, {}, {}
	st.cam, st.cmove = nil, nil
	st.bars, st.barsTo, st.fade, st.fmove = 0, 0, 0, nil
	st.tint, st.tintA, st.tmove = nil, 0, nil
	st.say, st.card, st.title, st.note, st.picture, st.glow = nil, nil, nil, nil, nil, false
	st.shakeT = 0
end

-- 단계를 시작한다. 바로 끝나는 것은 다음으로 넘어가고, 기다릴 것이 생기면 멈춘다
local function run(st)
	while not st.wait and not st.done do
		local s = st.def.steps[st.i]
		if not s then
			finish(st)
			return
		end
		local v = Cine.verbOf(s)
		if v == "bars" then
			st.barsTo = s.bars
			st.wait = { left = L.barsT }
		elseif v == "cam" then
			local back = s.cam == "hero"
			local to = if back then st.w.hero().x else (xOf(st, s.cam) or camNow(st)) -- 없는 사람이면 카메라는 그대로
			local t = s.t or L.camT
			st.cmove = { from = camNow(st), to = to, back = back, t = 0, dur = t }
			st.wait = { left = t }
		elseif v == "say" then
			st.say = { who = s.say, name = Cine.nameOf(st, s.say), text = Cine.textOf(st, s.text), t = 0 }
			st.wait = { input = "say" }
		elseif v == "note" then
			local lines = {}
			for i, x in s.text do
				lines[i] = Cine.textOf(st, x)
			end
			st.note = { title = s.note, text = lines }
			st.wait = { input = "note" }
		elseif v == "walk" then
			local p = Cine.posOf(st, s.walk)
			local to = xOf(st, s.to)
			if p and to then
				local tgt = st.actors[s.walk]
				if not tgt then
					st.over[s.walk] = st.over[s.walk] or {}
					tgt = st.over[s.walk]
					if tgt.x == nil then
						tgt.x = p.x
					end
				end
				tgt.walk = { to = to, speed = s.speed or L.speed }
				tgt.dir = if to >= p.x then 1 else -1
				if not s.go then
					st.wait = { walker = s.walk }
				end
			end
		elseif v == "face" then
			local d
			if typeof(s.dir) == "number" then
				d = s.dir
			else
				local a, b = Cine.posOf(st, s.dir), Cine.posOf(st, s.face)
				local dx = (if a then a.x else 0) - (if b then b.x else 0)
				d = if dx < 0 then -1 else 1
			end
			if st.actors[s.face] then
				st.actors[s.face].dir = d
			else
				st.over[s.face] = st.over[s.face] or {}
				st.over[s.face].dir = d
			end
		elseif v == "mark" then
			table.insert(st.marks, { who = s.mark, kind = s.kind, t = L.mark })
		elseif v == "spawn" then
			st.actors[s.spawn] = { x = xOf(st, s.x) or st.w.hero().x, y = s.y or st.w.hero().y, dir = s.dir or -1, mob = s.mob, npc = s.npc, clip = "idle", t = 0, alpha = 1 }
		elseif v == "die" then
			local a = st.actors[s.die]
			if a then
				a.clip, a.t, a.dying = "death", 0, 0
			end
			st.wait = { left = L.die }
		elseif v == "hide" or v == "show" then
			local key = s.hide or s.show
			if st.actors[key] then
				st.actors[key].hidden = v == "hide"
			else
				st.over[key] = st.over[key] or {}
				st.over[key].hidden = v == "hide"
			end
		elseif v == "wait" then
			st.wait = { left = s.wait }
		elseif v == "shake" then
			st.shakeT, st.shakeA = s.shake, s.amp or 2
		elseif v == "fade" then
			local t = s.t or L.fadeT
			if t <= 0 then
				st.fade = s.fade
			else
				st.fmove = { from = st.fade, to = s.fade, t = 0, dur = t }
				st.wait = { left = t }
			end
		elseif v == "tint" then
			local t = s.t or 0
			local on = s.tint ~= nil and s.tint ~= false
			if on then
				st.tint = s.tint
			end
			local to = if on then (s.a or 0.25) else 0
			if t <= 0 then
				st.tintA = to
				if not on then
					st.tint = nil
				end
			else
				st.tmove = { from = st.tintA, to = to, t = 0, dur = t, off = not on }
				st.wait = { left = t }
			end
		elseif v == "card" then
			st.card = { text = s.card, sub = s.sub or "", t = 0 }
			st.wait = { left = L.card }
		elseif v == "title" then
			st.title = { text = s.title, sub = s.sub or "", t = 0 }
			st.wait = { left = L.title }
		elseif v == "picture" then
			st.picture = if s.picture == false then nil else s.picture
			st.glow = s.glow ~= nil and s.glow ~= false
		elseif v == "sfx" then
			table.insert(st.sfx, s.sfx)
		end
		if not st.wait then
			st.i += 1
		end
	end
end

local function nextStep(st)
	st.wait = nil
	st.i += 1
	run(st)
end

function Cine.new(def, w)
	local st = {
		def = def, w = w, i = 1, wait = nil, done = false, actors = {}, over = {}, marks = {}, cam = nil, cmove = nil,
		bars = 0, barsTo = 0, fade = 0, fmove = nil, tint = nil, tintA = 0, tmove = nil, shakeT = 0, shakeA = 0,
		say = nil, card = nil, title = nil, note = nil, picture = nil, glow = false, sfx = {}, clock = 0,
	}
	run(st)
	return st
end

-- 시간을 흘린다(dt초)
function Cine.step(st, dt: number)
	if st.done then
		return
	end
	st.clock += dt
	if st.barsTo > st.bars then
		st.bars = math.min(st.barsTo, st.bars + dt / L.barsT)
	else
		st.bars = math.max(st.barsTo, st.bars - dt / L.barsT)
	end
	local m = st.cmove
	if m then
		m.t += dt
		local k = if m.dur > 0 then math.min(1, m.t / m.dur) else 1
		local to = if m.back then st.w.hero().x else m.to
		st.cam = m.from + (to - m.from) * ease(k)
		if k >= 1 then
			st.cam = if m.back then nil else to
			st.cmove = nil
		end
	end
	local f = st.fmove
	if f then
		f.t += dt
		local k = math.min(1, f.t / f.dur)
		st.fade = f.from + (f.to - f.from) * k
		if k >= 1 then
			st.fmove = nil
		end
	end
	local tm = st.tmove
	if tm then
		tm.t += dt
		local k = math.min(1, tm.t / tm.dur)
		st.tintA = tm.from + (tm.to - tm.from) * k
		if k >= 1 then
			st.tmove = nil
			if tm.off then
				st.tint = nil
			end
		end
	end
	st.shakeT = math.max(0, st.shakeT - dt)
	for i = #st.marks, 1, -1 do
		local q = st.marks[i]
		q.t -= dt
		if q.t <= 0 then
			table.remove(st.marks, i)
		end
	end
	local function move(a)
		if a.t ~= nil then
			a.t += dt
		end
		if a.dying ~= nil then
			a.dying += dt
			a.alpha = math.max(0, 1 - math.max(0, a.dying - L.die * 0.45) / (L.die * 0.55))
		end
		local wk = a.walk
		if wk then
			local d = wk.to - a.x
			local stepX = wk.speed * dt
			if math.abs(d) <= stepX then
				a.x, a.walk = wk.to, nil
			else
				a.x += math.sign(d) * stepX
				a.dir = math.sign(d)
			end
		end
	end
	for _, a in st.actors do
		move(a)
	end
	for _, a in st.over do
		move(a)
	end
	if st.say then
		st.say.t += dt
	end
	if st.card then
		st.card.t += dt
	end
	if st.title then
		st.title.t += dt
	end
	local w = st.wait
	if not w then
		return
	end
	if w.left ~= nil then
		w.left -= dt
		if w.left <= 0 then
			local v = Cine.verbOf(st.def.steps[st.i])
			if v == "card" then
				st.card = nil
			elseif v == "title" then
				st.title = nil
			end
			nextStep(st)
		end
	elseif w.walker then
		local a = st.actors[w.walker] or st.over[w.walker]
		if not a or not a.walk then
			nextStep(st)
		end
	end
end

-- 지금 말이 다 나왔나(cps = 초당 글자 수)
function Cine.sayFull(st, cps: number): boolean
	return st.say == nil or st.say.t * cps >= (utf8.len(st.say.text) or #st.say.text)
end

-- 누름: "next"(↑ · 스페이스 · 누르기 — 나오는 중이면 한 번에 다 보이고, 다 나왔으면 넘긴다) · "skip"(Esc · 「건너뛰기」 — 끝낸다)
function Cine.input(st, kind: string, cps: number?)
	if st.done then
		return
	end
	if kind == "skip" then
		finish(st)
		return
	end
	local w = st.wait
	if w and w.input == "say" then
		if not Cine.sayFull(st, cps or 30) then
			st.say.t = 1e9
			return
		end
		st.say = nil
		nextStep(st)
	elseif w and w.input == "note" then
		st.note = nil
		nextStep(st)
	end
end

-- 카드 · 이름의 비침(들어올 때 · 나갈 때 0.5초에 걸쳐)
function Cine.cardAlpha(c, life: number): number
	return math.max(0, math.min(1, c.t / 0.5, (life - c.t) / 0.5))
end

-- 방의 이름 → 맵의 이름(r1c4#5 → r1c4): 파티마다 따로 들어가는 장면(스토리 보스의 방 · 사당 지하 · 꿈)의 방에서도 장면의 맵과 견준다(2026-10-21)
local function baseOf(map: any): any
	return if type(map) == "string" then (string.match(map, "^(.-)#w?[nh]?%d+$") or map) else map
end

-- 틀 장면: 그 퀘스트의 그 때(on)이고 맵이 맞고 아직 보지 않은 것. seen = { [id] = true }
function Cine.find(on: string, quest: string, map: string?, seen): any
	map = baseOf(map)
	for _, c in DATA.list do
		local w = c.when
		if w.on == on and w.quest == quest and (w.map == nil or w.map == map) and not seen[c.id] then
			return c
		end
	end
	return nil
end

-- 틀 장면들(차례대로 — 장의 이름 카드가 먼저): 그 퀘스트의 그 때(on)이고 맵이 맞고 아직 보지 않은 것 모두
function Cine.findAll(on: string, quest: string, map: string?, seen): { any }
	map = baseOf(map)
	local cards, rest = {}, {}
	for _, c in DATA.list do
		local w = c.when
		if w.on == on and w.quest == quest and (w.map == nil or w.map == map) and not seen[c.id] then
			table.insert(if string.find(c.id, "_ch_", 1, true) then cards else rest, c)
		end
	end
	for _, c in rest do
		table.insert(cards, c)
	end
	return cards
end

-- 받기 전의 장면(on = "before"): 그 맵에 들어섰는데 그 퀘스트를 아직 받지 않았다(새 캐릭터가 꿈에서 깨어 사당에 들어설 때)
function Cine.before(map: string, book, seen): { any }
	map = baseOf(map)
	local out = {}
	for _, c in DATA.list do
		local w = c.when
		if w.on == "before" and w.map == map and book[w.quest] == nil and not seen[c.id] then
			table.insert(out, c)
		end
	end
	return out
end

-- 그 맵에서 지금 덮을 색(퀘스트 동안의 맵 모습 — 불타는 마을의 붉은 하늘). quests = 하는 중인 퀘스트 { [id] = 상태 }
function Cine.lookAt(map: string, active: { [string]: boolean }): (string?, number)
	map = baseOf(map)
	for _, lk in DATA.look do
		if active[lk.quest] and table.find(lk.maps, map) then
			return lk.tint, lk.a
		end
	end
	return nil, 0
end

-- 그 장면이 지금 나올 때인가(서버가 「장면을 튼다」를 받을 때 — 2026-10-18 검토: 안 본 장면을 아무 데서나 하나씩 틀어 장면마다 90초씩 맞지 않았다).
--  맵이 정해진 장면은 그 맵에서만 · 받기 전(before)의 장면은 그 퀘스트를 받기 전에만 · 나머지(enter · goal · complete)는 그 퀘스트를 받은 뒤에만
function Cine.fits(id: any, map: string?, book): boolean
	map = baseOf(map)
	for _, c in DATA.list do
		if c.id == id then
			local w = c.when
			if w.map ~= nil and w.map ~= map then
				return false
			end
			if w.quest ~= nil and book ~= nil then
				local st = book[w.quest]
				if w.on == "before" then
					return st == nil
				end
				return st ~= nil
			end
			return true
		end
	end
	return false
end

-- 알려진 장면 id인가(서버가 「봤다」를 받을 때 거른다)
function Cine.known(id: any): boolean
	if typeof(id) ~= "string" then
		return false
	end
	for _, c in DATA.list do
		if c.id == id then
			return true
		end
	end
	return false
end

return Cine
