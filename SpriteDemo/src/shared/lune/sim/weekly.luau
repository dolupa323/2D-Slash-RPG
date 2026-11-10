-- 주간 보스(2026-10-24 — 공방 js/lune/design/weekboss.js · city.generated의 weekly): 노말 · 하드, 한 주에 한 번 격파.
--  사용자 2026-10-24: "보스도 노말, 하드 난이도 해서 보스도 제작해 던전이랑 마찬가지로 보스 퀘스트 만들고 그 퀘스트를 깨다보면 보스문 있고, 거기에 입장 ui 있고 파티로 입장하는거야 주간 1회 격파고"
--  하는 일: 보스 퀘스트(큰 「!!」)를 끝내면 그 보스의 문이 열린다 → 문 앞에서 ↑ = 보스 창(노말 · 하드 · 혼자 · 파티) → <보스 방>#wn번호(노말) · #wh번호(하드)의 따로 된 방 →
--   보스가 곧바로 선다(퀘스트와 상관없이 — sim/room.luau) · 제한 시간 안에 쓰러뜨리면 그 방의 사람마다 이번 주의 격파를 적는다 → back초 뒤 문 앞으로.
--  한 주 = 한국 시간 목요일 0시부터(메이플스토리 주간 보스의 초기화와 같은 요일 — 1970-01-01이 목요일이라 그날부터 7일씩 센다). 노말 · 하드 가운데 하나를 격파하면 그 주에 그 보스는 끝.
--  캐릭터마다의 기록 = h.rift.week[보스] = { w = 격파한 주 · m = "normal" | "hard" }(sim/rift.luau가 같이 저장한다 — 저장 꼴을 늘리지 않으려고 토벌의 기록에 붙였다)
local lune = script.Parent.Parent
local CITY = require(lune.data["city.generated"])
local W = CITY.weekly
local Items = require(script.Parent.items) -- 이름 붙은 장비(격파 보상 — 2026-10-27)
local Titles = require(script.Parent.titles) -- 첫 격파 칭호
local Format = require(lune.ui.format)

local Weekly = {}
Weekly.DATA = W
Weekly.MODES = { "normal", "hard" }

local byId, byRoom = {}, {}
for _, b in W.bosses do
	byId[b.id] = b
	byRoom[b.room] = b
	for _, r in b.rooms or {} do -- 방이 여럿인 보스(2026-11-04 용암 거인 — 첫 굴 · 둘째 굴 · 분화구): 어느 방이든 그 보스의 방
		byRoom[r] = b
	end
end

function Weekly.boss(id: any)
	return if typeof(id) == "string" then byId[id] else nil
end

-- 한국 시간으로 몇째 주인가(목요일 0시에 바뀐다)
function Weekly.weekOf(now: number): number
	local day = math.floor((now + W.reset.offset * 3600) / 86400) -- 1970-01-01(목)이 0
	return math.floor(day / 7)
end

-- 방 이름에서 난이도와 그 보스: "r2c4#wn3" → "normal", 보스 · "r2c4#wh7" → "hard" · 아니면 nil
--  연습(2026-11-10 사용자 "보스 연습모드도 추가해야해 내가 그 주에 그 보스를 클리어해도 도전할수있게 보상은 안주는 그냥 연습모드인거지" — 공방 weekboss.js practice): "r2c4#wpn3" · "#wph3" → 셋째 값 true
function Weekly.ofKey(key: string): (string?, any, boolean)
	local base, p, m = string.match(key, "^([^#]+)#w(p?)([nh])%d+$")
	if not base then
		return nil, nil, false
	end
	return if m == "h" then "hard" else "normal", byRoom[base], p == "p"
end

-- 방 이름을 짓는다(practice = 연습의 방 — #wp)
function Weekly.key(b, mode: string, serial: number, practice: boolean?): string
	return b.room .. "#w" .. (if practice then "p" else "") .. (if mode == "hard" then "h" else "n") .. serial
end

-- ---------- 연습(2026-11-10 — 공방 weekboss.js practice: 메이플의 연습 모드처럼 그 주의 격파와 상관없이 · 보상 없이 · 하루 perDay번(모든 보스 합)) ----------
local PRAC = W.practice or { perDay = 20, back = 10 }
Weekly.PRACTICE = PRAC
-- 연습을 세는 날(한국 시간 자정에 바뀐다 — 일일 의뢰 · 던전과 같은 날)
function Weekly.practiceDay(now: number): number
	return math.floor((now + W.reset.offset * 3600) / 86400)
end
-- 오늘 남은 연습 수(r = 캐릭터의 rift — prac = { d = 날, n = 쓴 수 })
function Weekly.practiceLeft(r, now: number): number
	if not PRAC.perDay then
		return math.huge -- 횟수 제한 없음(2026-11-10 사용자 "연습모드 횟수 무한으로해야해")
	end
	local p = r and r.prac
	local used = if p and p.d == Weekly.practiceDay(now) then p.n else 0
	return math.max(0, PRAC.perDay - used)
end
-- 연습으로 들어갔다(하나 쓴다)
function Weekly.practiceUse(r, now: number)
	local d = Weekly.practiceDay(now)
	if not r.prac or r.prac.d ~= d then
		r.prac = { d = d, n = 0 }
	end
	r.prac.n += 1
end
-- 그 장면(바탕 이름)이 그 보스의 방인가(방이 여럿인 보스는 그 가운데 하나)
function Weekly.isRoomOf(b, base: string): boolean
	return byRoom[base] == b
end
-- 같은 싸움의 다음 방 이름: "r3d5#wn12" → "r3d6#wn12"(번호 · 난이도는 그대로 — 2026-11-04 용암 거인의 방 셋)
function Weekly.stageKey(key: string, room: string): string
	local tail = string.match(key, "#wp?[nh]%d+$") -- (연습의 방도 — #wp)
	return room .. (tail or "")
end

-- 이번 주에 그 보스를 격파했는가(했으면 그 난이도)
function Weekly.done(r, id: string, now: number): string?
	local e = r and r.week and r.week[id]
	if e and e.w == Weekly.weekOf(now) then
		return e.m
	end
	return nil
end

-- 격파를 적는다(이번 주에 이미 했으면 false)
function Weekly.mark(r, id: string, mode: string, now: number): boolean
	r.week = r.week or {}
	if Weekly.done(r, id, now) then
		return false
	end
	r.week[id] = { w = Weekly.weekOf(now), m = mode }
	return true
end

-- 그 보스 · 난이도에 들어갈 수 있는가. 맞으면 nil, 아니면 까닭(문이 열렸는가 = 보스 퀘스트를 끝냈는가 · 레벨 · 이번 주)
--  practice = 연습(2026-11-10): 이번 주의 격파는 보지 않고 오늘 남은 연습 수를 본다(문 · 출현 · 레벨은 같다)
function Weekly.canEnter(h, b, mode: string, now: number, practice: boolean?): string?
	local words = W.words
	local st = h.quests and h.quests[b.quest]
	local m = b[mode]
	if not m then
		return "모르는 난이도다"
	elseif not h.alive then
		return "쓰러진 채로는 들어갈 수 없다"
	elseif not require(script.Parent.reveal).open(b.id, now) then
		-- 아직 출현하지 않았다(2026-11-05 — sim/reveal.luau): 「아직 깨어나지 않았다 — 출현까지 47:12」(시각을 모르면 「보스의 문이 굳게 닫혀 있다」)
		local Reveal = require(script.Parent.reveal)
		local left = Reveal.left(b.id, now)
		return if left then (string.gsub(words.revealClosed or words.closed, "{t}", Reveal.clockText(left))) else words.closed
	elseif not (st and st.done) then
		return words.closed
	elseif h.level < m.need then
		return (string.gsub(words.low, "{a}", tostring(m.need)))
	elseif practice and Weekly.practiceLeft(h.rift, now) <= 0 then
		return (string.gsub(words.practiceOut or words.done, "{max}", tostring(PRAC.perDay)))
	elseif not practice and Weekly.done(h.rift, b.id, now) then
		return words.done
	end
	return nil
end

-- 창에 보내는 것: 보스마다 이번 주의 격파(없으면 false) · 다음 초기화까지 남은 초
function Weekly.view(r, now: number)
	local done = {}
	for _, b in W.bosses do
		done[b.id] = Weekly.done(r, b.id, now) or false
	end
	local nextAt = (Weekly.weekOf(now) + 1) * 7 * 86400 - W.reset.offset * 3600
	return { done = done, reset = math.max(0, nextAt - now), prac = if PRAC.perDay then Weekly.practiceLeft(r, now) else 999999, pracMax = PRAC.perDay or 0 } -- (횟수 제한이 없으면 큰 수 — 보내는 값에 무한을 싣지 않는다) -- prac = 오늘 남은 연습(2026-11-10)
end
-- 연습의 기록을 고른다(저장에서 읽은 것 — sim/rift.luau의 pack · unpack)
function Weekly.cleanPractice(p: any)
	if typeof(p) == "table" and typeof(p.d) == "number" and typeof(p.n) == "number" then
		return { d = math.floor(p.d), n = math.clamp(math.floor(p.n), 0, PRAC.perDay or 1e6) }
	end
	return nil
end

-- 기록의 꼴을 고른다(저장에서 읽은 것 — 모르는 보스 · 이상한 값은 버린다)
function Weekly.clean(data: any)
	local out = {}
	if typeof(data) == "table" then
		for id, e in data do
			if byId[id] and typeof(e) == "table" and typeof(e.w) == "number" and (e.m == "normal" or e.m == "hard") then
				out[id] = { w = math.floor(e.w), m = e.m }
			end
		end
	end
	return out
end

-- ---------- 격파 보상(2026-10-27 — 공방 design/weekboss.js의 pay) ----------
--  보스 창의 「격파 보상」 세 줄(공방 시험 탭 ui/paint.js의 weekPayLines와 같은 셈): ① 달가루 · 달돈 ② 첫 격파 칭호 ③ 이름 붙은 장비(있는 난이도)
--   그 보스의 장비가 하드에만 있으면 노말에서는 셋째 줄에 「장신구는 하드에서만 …」 · 보상이 없는 보스는 「보상은 곧 정해진다」
local SLOTNAME = {}
for _, sl in Items.data.SLOTS do
	SLOTNAME[sl.id] = sl.name
end
-- 소비 아이템의 목록 글: 「큰 달빛 물약 30개 · 귀환 주문서 2개」(list = { { id, n } … } — pay.goods · 남은 것)
function Weekly.goodsText(list): string
	local parts = {}
	for _, g in list do
		local def = Items.goods(g.id)
		if def and typeof(g.roll) == "table" and #g.roll > 0 then
			-- 수를 굴리는 것(윤슬 조각 — 2026-11-07): 「윤슬 조각 1~5개」
			table.insert(parts, Format.fill(W.words.payGoods, { item = def.name, n = ("%d~%d"):format(g.roll[1][1], g.roll[#g.roll][1]) }))
		elseif def and (g.n or 0) > 0 then
			table.insert(parts, Format.fill(W.words.payGoods, { item = def.name, n = Format.comma(g.n) }))
		end
	end
	return table.concat(parts, " · ")
end

-- 굴려 정하는 수(2026-11-07 — design/weekboss.js의 YUNSEUL_ROLL: { { 수, % } … } 합 100)
function Weekly.rollCount(roll, rng): number
	local r, acc = rng:NextNumber(0, 100), 0
	for _, e in roll do
		acc += e[2]
		if r < acc then
			return e[1]
		end
	end
	return roll[#roll][1]
end

function Weekly.payLines(b, mode: string): ({ string }, number)
	local words = W.words
	local p = b and b.pay and b.pay[mode]
	if not p then
		return { words.payNone, "", "" }
	end
	local t = Titles.def(p.title)
	local u = if p.drop then Items.unique(p.drop.u) else nil
	local hardDrop = b.pay.hard and b.pay.hard.drop
	-- 칭호가 없는 보스(그림자 사수 — 2026-10-28 사용자 "내가 이번보스 칭호 안준다고했잖아")는 칭호 줄을 빼고 장신구 줄을 올린다. 둘째 값 = 장신구 줄의 차례(창이 민트로 칠한다)
	local out = { Format.fill(words.payMain, { n = Format.comma(p.dust), m = Format.comma(p.money) }) }
	if t then
		table.insert(out, Format.fill(words.payTitle, { t = t.name }))
	elseif p.goods and #p.goods > 0 then
		table.insert(out, Weekly.goodsText(p.goods)) -- 소비 아이템(2026-10-28 타락한 부단장 — 칭호가 없는 보스의 둘째 줄)
	end
	-- 화심 장비 완제도 나오는 난이도(용암 거인 하드 — 2026-11-09 · pay.more의 pick fireheart): 셋째 줄 = payFireheart(부위 대신 「화심 장비 완제」)
	local fire = false
	for _, e in p.more or {} do
		fire = fire or e.pick == "fireheart"
	end
	table.insert(out, if u and fire and words.payFireheart then Format.fill(words.payFireheart, { item = u.name }) elseif u then Format.fill(words.payDrop, { item = u.name, part = SLOTNAME[u.slot] }) elseif hardDrop then words.payHardOnly else "")
	local itemAt = #out
	while #out < 3 do
		table.insert(out, "")
	end
	return out, itemAt
end

-- 격파한 사람 하나에게 첫 격파 칭호(그 난이도 — 이미 있으면 nil). 달가루 · 달돈은 보상의 방의 상자에서(2026-10-28 — Weekly.openBox · 전에는 여기서 바로 더했다)
function Weekly.giveTitle(h, b, mode: string): string?
	local p = b and b.pay and b.pay[mode]
	if p and p.title and Titles.give(h, p.title) then
		return p.title
	end
	return nil
end

-- 이름 붙은 장비: 파티에 한 번 굴린다(파티 보상 — 사용자 2026-10-27 "아니 파티보상이야 뭘파티원별로굴려" · 10-28부터는 보상의 방의 상자에서 흩어진다: "그냥 파티보상으로 전부 지급되는거야 흩부려지는거야").
--  나왔으면 그 장비(보상의 방의 상자에서 하나가 떨어진다 — Weekly.openBox · 2026-10-28) · 안 나왔으면 nil
--  pct = 관리자가 시험으로 걸어 둔 확률(%) — 있으면 그 값 그대로(관리 「희귀 장신구」 · 2026-10-27)
--  mul = 드롭률 배율 — 파티에서 가장 높은 사람의 것(드롭률 쿠폰 · 패스: Cash.dropMul — 사용자 2026-10-27 "마안 드롭률이 올라야해 파티에서 가장높은사람의 드롭률 배율로")
--   확률 = 설계의 값 x mul
function Weekly.roll(b, mode: string, rng, pct: number?, mul: number?)
	local p = b and b.pay and b.pay[mode]
	if p and p.drop and Items.unique(p.drop.u) and rng:NextNumber(0, 100) < (pct or p.drop.pct * (mul or 1)) then
		return Items.makeUnique(p.drop.u)
	end
	return nil
end

-- 더 나오는 장비(2026-11-09 용암 거인 하드 — 사용자 "화심장비 완제가 낮은확률로 드롭되고" · design/weekboss.js pay.<난이도>.more): 파티에 한 번씩 굴린다(Weekly.roll과 같이)
--  { pick = "fireheart", pct } = 화심 장비 완제 하나 — 직업 = 받을 사람 가운데 하나(classes · 없으면 다섯 직업 가운데) · 부위 = 주화 값의 거꾸로(무기 5 · 방어구 2 → 무기가 드물다) ·
--  성능 = 숯돌에서 바꿀 때처럼 굴린다(Items.rollQuality). 확률 = pct x mul(파티에서 가장 높은 드롭률). 돌려주는 것: 나온 장비들
function Weekly.rollMore(b, mode: string, rng, mul: number?, classes: { string }?): { any }
	local p = b and b.pay and b.pay[mode]
	local out = {}
	for _, e in (p and p.more) or {} do
		if e.pick == "fireheart" and rng:NextNumber(0, 100) < (e.pct or 0) * (mul or 1) then
			local pool = if classes and #classes > 0 then classes else { "axion", "riven", "reaper", "mooni", "salamander" }
			local who = pool[rng:NextInteger(1, #pool)]
			local cands, total = {}, 0
			for _, u in Items.data.UNIQUES or {} do
				if u.set == "fireheart" and u.who == who then
					local w = 1 / math.max(1, u.cost or 1)
					table.insert(cands, { id = u.id, w = w })
					total += w
				end
			end
			local r, acc = rng:NextNumber(0, total), 0
			for _, c in cands do
				acc += c.w
				if r <= acc then
					table.insert(out, Items.makeUnique(c.id, Items.rollQuality(rng)))
					break
				end
			end
		end
	end
	return out
end

-- ---------- 방의 셈(sim/room.luau가 부른다) ----------
-- 방을 열 때: 주간의 방이면 room.weekly = { mode, boss = 보스의 이름표, t(흐른 시간), state = "fight" | "clear" | "fail", backAt }
--  lives = 사람마다 남은 데스 카운트(키 = 캐릭터 번호의 글 — 화면에 그대로 보낸다. 없으면 W.lives)
function Weekly.start(room, mode: string, b, practice: boolean?)
	room.weekly = { mode = mode, boss = b.id, t = 0, state = "fight", backAt = nil, changed = true, lives = {}, potions = {}, time = b.time or W.time } -- time = 그 보스의 제한 시간(용암 거인 20분 — 2026-11-04 · 없으면 모두의 것)
	room.weekly.practice = if practice then true else nil -- 연습의 방(2026-11-10): 격파해도 기록 · 보상 없이 back초 뒤 문 앞으로(Weekly.cleared)
end

-- 데스 카운트(2026-10-27 사용자: "보스 데스카운트는 사람마다 개인 데스카운트 5야 / 무니 소생같은건 데스카운트 소모안하고 살아나는거고")
--  쓰러진 사람이 스스로 일어날 때(「일어나기」 · 마지막이면 「나가기」) 하나 준다 — 파티원의 소생(Hero.raise)은 이것을 부르지 않는다
function Weekly.livesLeft(room, id: number): number
	local wk = room.weekly
	local n = wk and wk.lives and wk.lives[tostring(id)]
	return if n then n else W.lives
end
-- 하나 쓴다: 남은 수를 돌려준다(0이면 다 썼다 — 보스의 문 앞으로 나간다)
function Weekly.useLife(room, id: number): number
	local wk = room.weekly
	Weekly.statOf(room, id).deaths += 1 -- MVP의 생존(2026-11-07)
	local left = math.max(0, Weekly.livesLeft(room, id) - 1)
	wk.lives = wk.lives or {}
	wk.lives[tostring(id)] = left
	wk.changed = true
	return left
end

-- 물약 제한(2026-11-07 사용자: "용암거인 포션 제한 걸자 한 레이드 내에서 20개 제한" — 공방 weekboss.js의 potionCap):
--  그 보스의 레이드 안에서 사람마다 potionCap개까지(세 방이 하나로 이어진다 — 서버 World.toStage가 potions를 옮긴다). potions = 사람마다 쓴 수(키 = 캐릭터 번호의 글)
function Weekly.potionCap(room): number?
	local wk = room and room.weekly
	local b = wk and Weekly.boss(wk.boss)
	return if b and typeof(b.potionCap) == "number" then b.potionCap else nil
end
-- 더 마실 수 있나(제한이 없는 방이면 늘 된다)
function Weekly.canDrink(room, id: number): boolean
	local cap = Weekly.potionCap(room)
	if not cap then
		return true
	end
	local used = room.weekly.potions and room.weekly.potions[tostring(id)] or 0
	return used < cap
end
-- 하나 마셨다(제한이 있는 방에서만 센다)
function Weekly.drank(room, id: number)
	if not Weekly.potionCap(room) then
		return
	end
	local wk = room.weekly
	wk.potions = wk.potions or {}
	wk.potions[tostring(id)] = (wk.potions[tostring(id)] or 0) + 1
	wk.changed = true
end

-- ---------- MVP(2026-11-07 — 공방 weekboss.js의 mvp · 로스트아크의 MVP를 따른다) ----------
--  wk.stats[캐릭터 번호의 글] = { dmg = 보스에게 넣은 피해, gim = 보스 곁의 것(혹 · 폭탄 · 단지 · 가짜)에 넣은 피해, deaths = 데스 카운트를 쓴 수 } — 방이 여럿인 보스는 다음 방으로 옮긴다(서버 World.toStage)
function Weekly.statOf(room, id: number)
	local wk = room.weekly
	wk.stats = wk.stats or {}
	local k = tostring(id)
	local st = wk.stats[k]
	if not st then
		st = { dmg = 0, gim = 0, deaths = 0 }
		wk.stats[k] = st
	end
	return st
end
-- 그 사람이 넣은 피해(sim/room.luau가 맞을 때마다 부른다 — 싸우는 동안만)
function Weekly.note(room, id: number, mob, took: number)
	local wk = room.weekly
	if not wk or wk.state ~= "fight" or took <= 0 then
		return
	end
	local st = Weekly.statOf(room, id)
	if mob.kind == wk.boss then
		st.dmg += took
	else
		st.gim += took
	end
end
-- 결과: people = { { id, name, class } … }(그 방의 사람들) → { rows = { { id, name, class, dmg(몫 0~1), gim(몫), deaths, score, mvp, best = { dmg, gim, life } } … }(점수 차례), mvp = 캐릭터 번호 | nil }
function Weekly.mvp(room, people)
	local M = W.mvp
	local wk = room.weekly or {}
	local stats = wk.stats or {}
	local td, tg = 0, 0
	for _, p in people do
		local st = stats[tostring(p.id)] or { dmg = 0, gim = 0, deaths = 0 }
		td += st.dmg
		tg += st.gim
	end
	local rows = {}
	for _, p in people do
		local st = stats[tostring(p.id)] or { dmg = 0, gim = 0, deaths = 0 }
		local d = if td > 0 then st.dmg / td else 0
		local g = if tg > 0 then st.gim / tg else 0
		local life = math.max(0, 1 - st.deaths * M.lifeStep)
		local score = d * M.w.dmg + g * M.w.gim + life * M.w.life
		table.insert(rows, { id = p.id, name = p.name, class = p.class, dmg = d, gim = g, deaths = st.deaths, score = score, best = {} })
	end
	table.sort(rows, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.dmg > b.dmg
	end)
	local mvp = nil
	if #rows >= M.min then
		rows[1].mvp = true
		mvp = rows[1].id
		-- 분야마다 가장 높은 사람(같으면 앞 사람) — 기믹은 넣은 사람이 있을 때만 · 생존은 쓰러짐이 가장 적은 사람(모두 같으면 표시하지 않는다)
		local function top(key: string, better: (any, any) -> boolean)
			local best = rows[1]
			for _, r in rows do
				if better(r, best) then
					best = r
				end
			end
			best.best[key] = true
		end
		top("dmg", function(a, b)
			return a.dmg > b.dmg
		end)
		if tg > 0 then
			top("gim", function(a, b)
				return a.gim > b.gim
			end)
		end
		local lo, hi = math.huge, -math.huge
		for _, r in rows do
			lo, hi = math.min(lo, r.deaths), math.max(hi, r.deaths)
		end
		if lo < hi then
			top("life", function(a, b)
				return a.deaths < b.deaths
			end)
		end
	end
	return { rows = rows, mvp = mvp }
end

-- 시간이 흐른다: 제한 시간을 넘기면 실패
function Weekly.step(room, dt: number)
	local wk = room.weekly
	wk.t += dt
	if wk.state == "fight" and wk.t >= (wk.time or W.time) then
		wk.state, wk.backAt, wk.changed = "fail", wk.t + W.failBack, true
	end
end

-- 보스가 쓰러졌다: box.after초 뒤 방의 사람 모두를 보상의 방으로(서버 — Weekly.boxDue · 2026-10-28. 전에는 back초 뒤 문 앞으로)
function Weekly.cleared(room)
	local wk = room.weekly
	if wk and wk.state == "fight" then
		if wk.practice then
			wk.state, wk.backAt, wk.changed = "clear", wk.t + PRAC.back, true -- 연습(2026-11-10): 보상의 방 없이 문 앞으로
		else
			wk.state, wk.boxAt, wk.changed = "clear", wk.t + W.box.after, true
		end
	end
end

-- 보상의 방으로 옮길 때인가(한 번만 — 서버가 옮긴 뒤 boxAt을 지운다)
function Weekly.toBox(room): boolean
	local wk = room.weekly
	return wk ~= nil and wk.boxAt ~= nil and wk.t >= wk.boxAt
end

-- 방의 사람들을 문 앞으로 돌려보낼 때인가
function Weekly.due(room): boolean
	local wk = room.weekly
	return wk ~= nil and wk.backAt ~= nil and wk.t >= wk.backAt
end

-- ---------- 보상의 방(2026-10-28 — 공방 design/weekboss.js의 box · maps.js의 wkbox 「달의 보물고」) ----------
--  사용자: "보스를 처치하면 자동으로 모두 보스 보상방으로 이동하고 보스 보상방에는 보상상자가 멋지게 잇고 상자를 열면 보상이 파티보상으로 흩부려지는 방식으로
--   그 파티에 최대 드롭률을 가지고잇는 유저의 드롭률로 적용되고, 그냥 파티보상으로 전부 지급되는거야 흩부려지는거야"
--  방 이름 = wkbox#번호(보스마다 · 격파마다 따로 — 장면의 이름 풀이가 「#번호」를 받는다). room.box = { boss, mode, who = { [캐릭터 번호] = true }(받을 사람 = 격파로 적힌 사람), mul(파티에서 가장 높은 드롭률), test(관리의 시험 확률), t, opened }
--  상자를 열면(받을 사람 누구나 — 상자 곁에서 ↑): 달가루 · 달돈을 box.dust · box.money 덩이로 나눠(합 = 사람마다의 보상) 흩뿌린다 — 덩이는 받을 사람 누구나 줍고, 누가 주워도 받을 사람 모두에게
--   그 몫이 들어간다(share · Room:pickup). 이름 붙은 장비는 한 번 굴려(확률 x mul) 나오면 하나 떨어진다(받을 사람 누구나 줍는다). 모두 사라지지 않는다(keep) · 받을 사람 밖은 못 줍는다(party)
local Physics = require(script.Parent.physics)
local BOX = W.box
Weekly.BOX = BOX

-- 보스마다의 보상의 방(2026-11-06 사용자 "각 보스마다 보상방 위치판정도, 디자인도 다 달라야해"): 그 보스의 boxRoom(공방 weekboss.js — maps.js의 wkbox_<보스>) · 없으면 함께 쓰는 BOX.scene
function Weekly.boxScene(bossId: string?): string
	local b = if bossId then Weekly.boss(bossId) else nil
	return if b and b.boxRoom then b.boxRoom else BOX.scene
end
function Weekly.boxKey(serial: number, bossId: string?): string
	return Weekly.boxScene(bossId) .. "#" .. serial
end
local BOX_SCENES = { [BOX.scene] = true }
for _, b in W.bosses do
	if b.boxRoom then
		BOX_SCENES[b.boxRoom] = true
	end
end
function Weekly.isBox(key: any): boolean
	if typeof(key) ~= "string" then
		return false
	end
	local base = string.match(key, "^(.+)#%d+$")
	return base ~= nil and BOX_SCENES[base] == true
end

-- 방을 연다(서버가 격파 뒤에 그 방을 만들고 부른다)
function Weekly.startBox(room, bossId: string, mode: string, who, mul: number?, test: number?)
	room.box = { boss = bossId, mode = mode, who = who, mul = mul or 1, test = test, t = 0, opened = false, changed = true }
end

function Weekly.boxStep(room, dt: number)
	if room.box then
		room.box.t += dt
	end
end

-- 머무는 시간이 다 됐는가(서버가 남은 것을 나누고 보스의 문 앞으로)
function Weekly.boxDue(room): boolean
	return room.box ~= nil and room.box.t >= BOX.stay
end

-- 화면에 보내는 것: { boss, mode, opened, left(남은 초), x · y(상자의 자리 — 바닥 가운데) }
function Weekly.boxView(room)
	local bx = room.box
	if not bx then
		return nil
	end
	local c = room.scene and room.scene.chest or { x = 0, y = 0 }
	return { boss = bx.boss, mode = bx.mode, opened = bx.opened, left = math.max(0, BOX.stay - bx.t), x = c.x, y = c.y }
end

-- 그 사람이 지금 상자를 열 수 있는가(받을 사람 · 살아 있다 · 상자 곁) — 아니면 까닭
function Weekly.canOpen(room, h): string?
	local bx = room.box
	if not bx then
		return "보상 상자가 없다"
	elseif bx.opened then
		return "이미 열었다"
	elseif not bx.who[h.id] then
		return W.words.boxNot
	elseif not h.alive then
		return "쓰러져 있다"
	end
	local c = room.scene.chest
	if math.abs(h.x - c.x) > BOX.reach or math.abs(h.y - c.y) > 40 then
		return W.words.boxHint
	end
	return nil
end

-- (x)의 땅: 상자의 높이에서 아래로 처음 막힌 칸의 윗면(보물고의 단 위 · 바닥)
local function groundAt(scene, x: number, from: number): number
	local tx = math.floor(x / 16)
	for ty = math.floor(from / 16), (scene.h or 14) - 1 do
		if Physics.cell(scene, tx, ty) == "#" then
			return ty * 16
		end
	end
	return from
end

-- 보상이 떨어질 수 있는 가로 범위(점): 상자 자리에서 좌우로, 튀어 오르는 높이(c.y - 30)와 서는 높이(c.y - 8)의 칸이 모두 비어 있는 데까지 — 벽(막힌 칸)에 닿으면 멈춘다.
--  2026-11-07 사용자: "지금 보스 보상이 벽으로 들어가는 문제가 있어요" — 보스마다의 보상의 방(11-06)에서 상자가 벽 가까이 있는 방(도둑단의 장물 창고 x 88 — 왼쪽 벽 0~32 ·
--  기사단의 봉헌실 x 376 — 오른쪽 벽 448~)에서, 맵 끝 20점만 피해 벽 속(x 20 · 460)에 떨어졌다. margin = 벽에서 띄우는 만큼(제가 정한 것)
local SPAN_MARGIN = 12
function Weekly.dropSpan(scene, c): (number, number)
	local w = scene.w or 26
	local rows = { math.floor((c.y - 30) / 16), math.floor((c.y - 8) / 16) }
	local function open(tx: number): boolean
		if tx < 0 or tx >= w then
			return false
		end
		for _, ty in rows do
			if Physics.cell(scene, tx, ty) == "#" then
				return false
			end
		end
		return true
	end
	local t0 = math.floor(c.x / 16)
	local lo, hi = t0, t0
	while open(lo - 1) do
		lo -= 1
	end
	while open(hi + 1) do
		hi += 1
	end
	return lo * 16 + SPAN_MARGIN, (hi + 1) * 16 - SPAN_MARGIN
end

-- 상자를 연다: 흩뿌릴 것을 방에 떨어뜨리고 그 목록과 이름 붙은 장비(없으면 nil)를 돌려준다. 떨어진 것에는 from(상자의 뚜껑 자리) · delay(튀어나오는 차례)가 붙는다 — 화면이 상자에서 튀어 오르게 그린다
function Weekly.openBox(room, rng)
	local bx = room.box
	if not bx or bx.opened then
		return nil, nil
	end
	bx.opened, bx.changed = true, true
	local b = Weekly.boss(bx.boss)
	local p = b and b.pay and b.pay[bx.mode]
	local c = room.scene.chest
	local lo, hi = Weekly.dropSpan(room.scene, c) -- 벽 안쪽(2026-11-07 — 전에는 맵 끝 20점만 피했다)
	local list = {}
	-- 받을 사람이 혼자면(혼자 격파 · 관리의 보상의 방) 펫도 줍는다 · 둘 이상이면 직접 주워야 한다(nopet — Room:pickup이 펫의 줍기를 막는다 · 2026-10-28)
	local people = 0
	for _ in bx.who do
		people += 1
	end
	local function drop(d)
		local i = #list + 1
		local side = if i % 2 == 0 then 1 else -1
		local dist = BOX.spread[1] + (BOX.spread[2] - BOX.spread[1]) * rng:NextNumber()
		-- 그쪽에 벽이 가까우면 반대쪽으로 · 그래도 넘으면 범위 끝에(벽 속에 떨어지지 않게)
		local x = c.x + side * dist
		if x < lo or x > hi then
			x = c.x - side * dist
		end
		x = math.clamp(x, lo, hi)
		d.share = d.kind == "dust" or d.kind == "money" or d.kind == "goods" or nil -- 소비 아이템 덩이도 나눈다(2026-10-28)
		d.party, d.keep, d.nopet = bx.who, true, people > 1 or nil
		d.fromX, d.fromY, d.delay, d.popT = c.x, c.y - 30, (i - 1) * BOX.gap, BOX.pop
		table.insert(list, room:addDrop(d, x, groundAt(room.scene, x, c.y - 30), nil))
	end
	-- 덩이로 나눈다(마지막 덩이에 나머지) — 번갈아 달돈 · 달가루
	local function split(total: number, n: number): { number }
		local out = {}
		local each = math.floor(total / n)
		for k = 1, n do
			out[k] = if k == n then total - each * (n - 1) else each
		end
		return out
	end
	if p then
		local dust, money = split(p.dust, BOX.dust), split(p.money, BOX.money)
		-- 덩이를 왼쪽 · 오른쪽에 번갈아 놓으므로 짝마다 달돈 · 달가루의 차례를 바꾼다(한쪽에 한 가지만 몰리지 않게)
		for k = 1, math.max(#dust, #money) do
			local pair = if k % 2 == 1 then { { "money", money[k] }, { "dust", dust[k] } } else { { "dust", dust[k] }, { "money", money[k] } }
			for _, q in pair do
				if q[2] and q[2] > 0 then
					drop({ kind = q[1], amount = q[2] })
				end
			end
		end
	end
	-- 소비 아이템(2026-10-28 사용자 보상 설계 「소비 아이템」 — design/weekboss.js의 pay.goods): pile개씩 덩이로 · 누가 주워도 받을 사람 모두에게(달가루 · 달돈처럼)
	--  기간 이벤트의 사탕(2026-10-29 할로윈 — 사용자 "보스 잡아도 사탕좀 많이주고": sim/event.luau의 bossGoods — 켜져 있을 때만 · 보상이 있는 보스만)
	local goodsList = table.clone((p and p.goods) or {})
	if p then
		for _, g in require(script.Parent.event).bossGoods(bx.mode) do
			table.insert(goodsList, g)
		end
	end
	for _, g in goodsList do
		local def = Items.goods(g.id)
		if def then
			local left = if typeof(g.roll) == "table" and #g.roll > 0 then Weekly.rollCount(g.roll, rng) else g.n -- (윤슬 조각 — 상자를 열 때 한 번 굴린다 · 2026-11-07)
			while left > 0 do
				local k = math.min(left, math.max(1, g.pile or 1))
				drop({ kind = "goods", goods = g.id, amount = k, name = def.name, icon = def.icon })
				left -= k
			end
		end
	end
	local item = if p then Weekly.roll(b, bx.mode, rng, bx.test, bx.mul) else nil
	if item then
		drop({ kind = "gear", item = item, amount = 1 })
	end
	-- 하드의 화심 장비 완제(2026-11-09 — 위 Weekly.rollMore): 받을 사람 가운데 방에 있는 사람들의 직업으로
	if p and p.more then
		local classes = {}
		for _, h in room.heroes or {} do
			if bx.who[h.id] and h.class then
				table.insert(classes, h.class)
			end
		end
		for _, extra in Weekly.rollMore(b, bx.mode, rng, bx.mul, classes) do
			drop({ kind = "gear", item = extra, amount = 1 })
		end
	end
	return list, item
end

-- 머무는 시간이 다 됐다 · 방이 닫힌다: 아직 줍지 않은 것 — 달가루 · 달돈 덩이 = 받을 사람 모두에게(사람마다 합) · 장비 = 목록으로(서버가 받을 사람 가운데 하나의 가방에).
--  방의 떨어진 것은 비운다. 돌려주는 것: { dust, money, items = { 장비 … } }(받을 사람마다 같은 dust · money)
function Weekly.boxLeft(room)
	local out = { dust = 0, money = 0, items = {}, goods = {} } -- goods = { { id, n } … }(소비 아이템 — 받을 사람마다 같은 수)
	if not room.box then
		return out
	end
	local goodsAt = {}
	for id, d in room.drops do
		if d.party == room.box.who then
			if d.kind == "dust" then
				out.dust += d.amount
			elseif d.kind == "money" then
				out.money += d.amount
			elseif d.kind == "gear" then
				table.insert(out.items, d.item)
			elseif d.kind == "goods" then
				local i = goodsAt[d.goods]
				if not i then
					table.insert(out.goods, { id = d.goods, n = 0 })
					i = #out.goods
					goodsAt[d.goods] = i
				end
				out.goods[i].n += d.amount
			end
			room.drops[id] = nil
		end
	end
	return out
end

-- 화면에 보내는 방의 상태: { boss, mode, state, left(남은 초 — 싸우는 동안), back(돌아가기까지 초), lives(사람마다 남은 데스 카운트 — 키 = 캐릭터 번호의 글 · 없는 사람은 livesMax) }
function Weekly.roomView(room)
	local wk = room.weekly
	if not wk then
		return nil
	end
	return {
		boss = wk.boss,
		mode = wk.mode,
		state = wk.state,
		left = math.max(0, (wk.time or W.time) - wk.t),
		back = if wk.backAt then math.max(0, wk.backAt - wk.t) else nil,
		box = if wk.boxAt then math.max(0, wk.boxAt - wk.t) else nil, -- 격파한 뒤 보상의 방으로 가기까지(초 — 2026-10-28)
		lives = table.clone(wk.lives or {}),
		livesMax = W.lives,
		potions = table.clone(wk.potions or {}), -- 사람마다 쓴 물약(2026-11-07 — 제한이 있는 보스만 센다)
		potionCap = Weekly.potionCap(room), -- 없으면 nil(제한 없음)
		practice = wk.practice, -- 연습의 방(2026-11-10 — 화면 위 보스 체력 바 아래 줄 「노말 연습 · 20:00」)
	}
end

return Weekly
