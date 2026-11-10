-- 룬 · 별똥별 조각의 서버(2026-11-07 사용자: "메이플 룬을 답습해서 만들자 미끼두는 방식도 채용하자 누가봐도 먹어야되게 보이는 별똥별 조각이 떨어지고 그걸 안먹는 걸
--  로그나 정보로 수집해서 매크로 위험수치를 판단할수있게") — 셈은 shared/lune/sim/rune.luau · 설계 공방 js/lune/design/rune.js.
--  world.luau가 부른다: bind(방 · 방에 알리기) · onKill(그 맵) · onScene(맵을 옮겼다) · tick(사람마다 1초마다) · onRemote(↑로 해방 · 화살표 · 별똥별 줍기)
--  ① 룬(사냥 맵마다 하나): 그 맵에서 사냥이 이어진 지 15분이면 몬스터가 서는 자리 하나에 나온다 → ↑로 다가가 화살표 넷 → 해방(경험치 +100% 3분 · 15분 쿨 · 15분 가호)
--     두면 5분 뒤부터 그 맵의 저주(경험치 · 떨어지는 것 50 → 70 → 90 → 100% 덜 — 가호가 있는 사람은 받지 않는다). 사람의 표시 hero.runeXp · hero.curse(저장하지 않는다)
--     저주는 사람에게 붙어 다닌다(2026-11-10 사용자 "룬의 저주는 사냥터를옮기던뭐하던 해도 룬의저주가 없어지면안된다" — 전에는 맵을 옮기면 0이 되었다):
--      hero.runeCurse = { s = 받은 가장 높은 단계, map = 그 맵 }(캐릭터와 같이 저장 — 다시 접속 · 서버를 옮겨도 남는다) · 깎는 것은 사냥터에서만(보스 · 던전 · 마을은 그대로).
--      풀리는 때(제가 정한 것): 그 사람이 어느 맵이든 룬을 해방했을 때 · 저주가 시작된 맵에 서 있는 동안 누군가 그 맵의 룬을 해방했을 때 · 가호가 있는 동안은 새로 받지 않는다
--  ② 별똥별 조각(사람마다): 사냥 중이면 6 ~ 10분에 한 번 곁에 떨어진다(그 사람에게만) — 몸으로 닿으면 줍는다(작은 달가루). 놓친 것은 매크로 확인의 st.bait에 남아 의심이 된다
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Rune = require(lune.sim.rune)
local SCENES = require(lune.data["scenes.generated"])
local Net = require(lune.net.net)

local RuneGuard = {}
local R, B = Rune.DATA.rune, Rune.DATA.bait
local rng = Random.new()
local maps: { [string]: any } = {}
local ctx: any = nil -- world.luau가 단다: { roomOf(key), toRoom(key, 이름, …) }

function RuneGuard.bind(c)
	ctx = c
end

local function huntScene(key: string?): boolean
	return require(script.Parent.macroGuard).huntScene(key)
end
local function mapOf(key: string)
	local m = maps[key]
	if not m then
		m = Rune.newMap()
		maps[key] = m
	end
	return m
end
local function playerOf(s)
	if not s.rune then
		s.rune = Rune.newPlayer()
	end
	return s.rune
end
-- 그 사람에게 보낼 맵의 모습(+ 내 룬의 시간들)
local function viewFor(s, key: string?)
	local now = os.time()
	local v = if key and huntScene(key) then Rune.mapView(mapOf(key), now) else { stage = 0 }
	local p = s.rune
	v.curse = if s.hero and s.hero.runeCurse then s.hero.runeCurse.s else 0 -- 내게 붙은 저주의 단계(맵을 옮겨도 남는다 — 2026-11-10)
	if p then
		v.buffLeft = math.max(0, p.buffUntil - now)
		v.cdLeft = math.max(0, p.cdUntil - now)
		v.guardLeft = math.max(0, p.guardUntil - now)
	end
	return v
end
local function toMap(key: string)
	if ctx and ctx.sessionsIn then
		for _, s in ctx.sessionsIn(key) do
			Net.FireClient("RuneMap", s.player, viewFor(s, key))
		end
	end
end
-- 룬이 설 자리: 그 맵의 몬스터가 서는 자리 가운데 하나(땅 위) — 구간 안의 아무 곳
local function spotIn(key: string): (number?, number?)
	local sc = SCENES.scenes[SCENES.base(key) or key]
	if not sc or not sc.mobs or #sc.mobs == 0 then
		return nil, nil
	end
	local m = sc.mobs[rng:NextInteger(1, #sc.mobs)]
	local a, b = m.x, m.x
	if typeof(m.range) == "table" then
		a, b = m.range[1], m.range[2]
	end
	return math.floor(rng:NextNumber(a, b) + 0.5), m.y
end

-- 그 맵에서 잡았다(처치 하나마다)
function RuneGuard.onKill(key: string)
	if huntScene(key) then
		Rune.onKill(mapOf(key), os.time())
	end
end

-- 맵을 옮겼다: 떠 있던 별똥별은 사라진다(놓친 것으로 세지 않는다 — 떠났을 뿐) · 새 맵의 룬을 알린다
function RuneGuard.onScene(s, key: string?)
	local p = playerOf(s)
	if p.bait.cur then
		Net.FireClient("Bait", s.player, { gone = p.bait.cur.id })
		p.bait.cur = nil
	end
	p.try = nil
	Net.FireClient("RuneMap", s.player, viewFor(s, key))
end

-- 사람마다 1초마다(World.tick): 맵의 룬이 나올 때 · 저주의 단계가 바뀔 때 알림 · 사람의 배율 · 별똥별
function RuneGuard.tick(s, key: string?)
	local h = s.hero
	if not h then
		return
	end
	local p = playerOf(s)
	local now = os.time()
	local hunt = huntScene(key)
	local m = if hunt and key then mapOf(key) else nil
	if m and key and m.tickAt ~= now then -- 맵의 일은 그 맵에서 1초에 한 번(사람이 여럿이어도)
		m.tickAt = now
		if Rune.tick(m, now, function()
			return spotIn(key)
		end) then
			toMap(key)
		end
		local st = Rune.stage(m, now)
		if st ~= (m.shownStage or 0) then
			m.shownStage = st
			toMap(key)
		end
	end
	local xp = Rune.xpMul(p, now)
	h.runeXp = if xp ~= 1 then xp else nil
	-- 내게 붙은 저주: 이 맵의 단계가 더 높으면 그것으로(맵이 바뀌어도 낮아지지 않는다) · 가호가 있으면 없다
	local guard = p.guardUntil > now
	local st = if m and not guard then Rune.stage(m, now) else 0
	local c0 = h.runeCurse
	local carry = c0
	if guard then
		carry = nil
	elseif st > 0 and (not carry or st > carry.s) then
		carry = { s = st, map = key }
	end
	if carry ~= c0 then
		h.runeCurse = carry
		s.dirty = true
		Net.FireClient("RuneMap", s.player, viewFor(s, key))
	end
	local cut = if carry and hunt then (R.curse.cut[carry.s] or 0) else 0
	h.curse = if cut > 0 then cut else nil
	-- 별똥별 조각: 지난 B.hunt.window초 안에 B.hunt.kills마리 넘게 잡고 있으면(매크로 확인의 처치 기록)
	local mst = s.macro
	if not mst or not mst.bait then
		return
	end
	local recent = 0
	for i = #mst.kills, 1, -1 do
		if now - mst.kills[i] > B.hunt.window then
			break
		end
		recent += 1
	end
	local curId = p.bait.cur and p.bait.cur.id
	local what = Rune.baitTick(p, mst.bait, now, hunt and recent >= B.hunt.kills and h.alive ~= false, function(a: number, b: number)
		return rng:NextInteger(a, b)
	end)
	if what == "miss" then
		Net.FireClient("Bait", s.player, { gone = curId })
		require(script.Parent.macroGuard).bait(s, false) -- 계정의 매크로 기록: 놓쳤다(2026-11-09)
	elseif what == "drop" and ctx and key then
		local room = ctx.roomOf(key)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local want = h.x + side * rng:NextInteger(B.dist[1], B.dist[2])
		local x = if room and room.onFloor then room:onFloor(want, h.x, h.y) else want
		if math.abs(x - h.x) < B.dist[1] * 0.5 then -- 그쪽 땅이 짧다: 반대쪽으로
			x = if room and room.onFloor then room:onFloor(h.x - side * rng:NextInteger(B.dist[1], B.dist[2]), h.x, h.y) else x
		end
		local c = Rune.baitDrop(p, mst.bait, now, math.floor(x + 0.5), h.y)
		Net.FireClient("Bait", s.player, { id = c.id, x = c.x, y = c.y, life = B.life })
	end
end

-- 화면이 보낸 것: ("start") ↑로 해방을 시작 · ("answer", { 화살표 … }) · ("bait", 번호) 별똥별에 닿았다
function RuneGuard.onRemote(s, action: string, a: any, _b: any)
	local h = s.hero
	local key = s.scene
	if not h or not key then
		return { why = "none" }
	end
	local p = playerOf(s)
	local now = os.time()
	if action == "start" then
		if not huntScene(key) then
			return { why = "none" }
		end
		local arrows, why = Rune.start(mapOf(key), p, now, h.x, h.y, function(n: number)
			return rng:NextInteger(1, n)
		end)
		if not arrows then
			return { why = why, cdLeft = math.max(0, p.cdUntil - now), retryLeft = math.max(0, p.retryAt - now) }
		end
		return { arrows = arrows, time = R.time }
	elseif action == "answer" then
		if not huntScene(key) then
			return { result = "none" }
		end
		local res = Rune.answer(mapOf(key), p, a, now)
		if res == "done" then
			-- 저주가 풀린다: 푼 사람(어디서 받은 저주든) · 이 맵에서 받은 저주를 지닌 채 이 맵에 서 있는 사람(2026-11-10)
			h.runeCurse = nil
			s.dirty = true
			if ctx and ctx.sessionsIn then
				for _, o in ctx.sessionsIn(key) do
					local oh = o.hero
					if oh and oh.runeCurse and oh.runeCurse.map == key then
						oh.runeCurse = nil
						oh.curse = nil
						o.dirty = true
					end
				end
			end
			toMap(key)
			h.runeXp = Rune.xpMul(p, now)
			h.curse = nil
			require(script.Parent.analytics).custom(s, "RuneSolved", 1, key)
		end
		return { result = res, retry = R.retry, buffLeft = math.max(0, p.buffUntil - now), cdLeft = math.max(0, p.cdUntil - now) }
	elseif action == "bait" then
		local mst = s.macro
		if not mst or not mst.bait then
			return { got = false }
		end
		if Rune.baitPick(p, mst.bait, now, a, h.x, h.y) then
			require(script.Parent.macroGuard).bait(s, true) -- 계정의 매크로 기록: 주웠다(2026-11-09)
			local n = B.dust and B.dust[math.clamp(h.level, 1, #B.dust)] or 1
			h.dust += n
			s.dirty = true
			return { got = true, dust = n }
		end
		return { got = false }
	end
	return nil
end

-- 관리 창(매크로 탭): 지난 한 시간의 별똥별 주운 수 / 떨어진 수
function RuneGuard.baitCounts(s): (number, number)
	local mst = s.macro
	return Rune.baitCounts(mst and mst.bait, os.time())
end

return RuneGuard
