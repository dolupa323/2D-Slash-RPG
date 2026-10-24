-- 주간 보스(2026-10-24 — 공방 js/lune/design/weekboss.js · city.generated의 weekly): 노말 · 하드, 한 주에 한 번 격파.
--  사용자 2026-10-24: "보스도 노말, 하드 난이도 해서 보스도 제작해 던전이랑 마찬가지로 보스 퀘스트 만들고 그 퀘스트를 깨다보면 보스문 있고, 거기에 입장 ui 있고 파티로 입장하는거야 주간 1회 격파고"
--  하는 일: 보스 퀘스트(큰 「!!」)를 끝내면 그 보스의 문이 열린다 → 문 앞에서 ↑ = 보스 창(노말 · 하드 · 혼자 · 파티) → <보스 방>#wn번호(노말) · #wh번호(하드)의 따로 된 방 →
--   보스가 곧바로 선다(퀘스트와 상관없이 — sim/room.luau) · 제한 시간 안에 쓰러뜨리면 그 방의 사람마다 이번 주의 격파를 적는다 → back초 뒤 문 앞으로.
--  한 주 = 한국 시간 목요일 0시부터(메이플스토리 주간 보스의 초기화와 같은 요일 — 1970-01-01이 목요일이라 그날부터 7일씩 센다). 노말 · 하드 가운데 하나를 격파하면 그 주에 그 보스는 끝.
--  캐릭터마다의 기록 = h.rift.week[보스] = { w = 격파한 주 · m = "normal" | "hard" }(sim/rift.luau가 같이 저장한다 — 저장 꼴을 늘리지 않으려고 토벌의 기록에 붙였다)
local lune = script.Parent.Parent
local CITY = require(lune.data["city.generated"])
local W = CITY.weekly

local Weekly = {}
Weekly.DATA = W
Weekly.MODES = { "normal", "hard" }

local byId, byRoom = {}, {}
for _, b in W.bosses do
	byId[b.id] = b
	byRoom[b.room] = b
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
function Weekly.ofKey(key: string): (string?, any)
	local base, m = string.match(key, "^([^#]+)#w([nh])%d+$")
	if not base then
		return nil, nil
	end
	return if m == "h" then "hard" else "normal", byRoom[base]
end

-- 방 이름을 짓는다
function Weekly.key(b, mode: string, serial: number): string
	return b.room .. "#w" .. (if mode == "hard" then "h" else "n") .. serial
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
function Weekly.canEnter(h, b, mode: string, now: number): string?
	local words = W.words
	local st = h.quests and h.quests[b.quest]
	local m = b[mode]
	if not m then
		return "모르는 난이도다"
	elseif not h.alive then
		return "쓰러진 채로는 들어갈 수 없다"
	elseif not (st and st.done) then
		return words.closed
	elseif h.level < m.need then
		return (string.gsub(words.low, "{a}", tostring(m.need)))
	elseif Weekly.done(h.rift, b.id, now) then
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
	return { done = done, reset = math.max(0, nextAt - now) }
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

-- ---------- 방의 셈(sim/room.luau가 부른다) ----------
-- 방을 열 때: 주간의 방이면 room.weekly = { mode, boss = 보스의 이름표, t(흐른 시간), state = "fight" | "clear" | "fail", backAt }
function Weekly.start(room, mode: string, b)
	room.weekly = { mode = mode, boss = b.id, t = 0, state = "fight", backAt = nil, changed = true }
end

-- 시간이 흐른다: 제한 시간을 넘기면 실패
function Weekly.step(room, dt: number)
	local wk = room.weekly
	wk.t += dt
	if wk.state == "fight" and wk.t >= W.time then
		wk.state, wk.backAt, wk.changed = "fail", wk.t + W.failBack, true
	end
end

-- 보스가 쓰러졌다
function Weekly.cleared(room)
	local wk = room.weekly
	if wk and wk.state == "fight" then
		wk.state, wk.backAt, wk.changed = "clear", wk.t + W.back, true
	end
end

-- 방의 사람들을 문 앞으로 돌려보낼 때인가
function Weekly.due(room): boolean
	local wk = room.weekly
	return wk ~= nil and wk.backAt ~= nil and wk.t >= wk.backAt
end

-- 화면에 보내는 방의 상태: { boss, mode, state, left(남은 초 — 싸우는 동안), back(돌아가기까지 초) }
function Weekly.roomView(room)
	local wk = room.weekly
	if not wk then
		return nil
	end
	return {
		boss = wk.boss,
		mode = wk.mode,
		state = wk.state,
		left = math.max(0, W.time - wk.t),
		back = if wk.backAt then math.max(0, wk.backAt - wk.t) else nil,
	}
end

return Weekly
