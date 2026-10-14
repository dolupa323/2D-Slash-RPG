-- 「달의 계승자」 — 초반의 성장과 직업 사이의 균형을 잰다(사용자 2026-10-10: "처음에 성장이 너무 어렵습니다. 성장밸런스 확인하고, 직업별 밸런스도 확인해봐야합니다.
--  어떤직업은 시작부터 쉽게 사냥하는데 어떤직업은 그것도 어려운경우가 있고").
--  재는 법: 진짜 서버의 셈(world.luau)으로 직업마다 캐릭터를 만들어 그 레벨의 사냥터에 세우고, 몬스터 곁에서 사냥기만 되풀이해 쓴다(화면이 하듯 구간을 보낸다).
--   한 마리를 잡는 데 걸린 시간 · 쓴 횟수 · 그동안 잃은 체력(최대 체력의 %) · 얻은 경험치를 적고, 그 레벨을 올리는 데 드는 마릿수와 시간을 셈한다.
--   걷는 시간 · 줍는 시간은 넣지 않는다(싸우는 시간만) — 그래서 「분당 마릿수」는 설계의 값(N.rateAt — 걷는 시간 포함)보다 높게 나와야 정상이다.
--  결과는 [BAL] 줄로 찍는다(python tools/test/run.py 26_lune_balance). 맨 아래의 검사는 직업 사이의 차이와 초반의 길이가 정한 테두리 안인지 본다.
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0 -- 치명타는 뺀다(재는 값이 흔들리지 않게)
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local packets = req("ReplicatedStorage/shared/lune/net/packets")
local TICK = 1 / 20

local handlers = {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function() end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, book = {}, {}
local rankDisk, rankInfo = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return book[key] end,
	claimName = function(key, id) book[key] = id; return true end,
	freeName = function(key) book[key] = nil end,
	rankSet = function(board, key, score) rankDisk[board] = rankDisk[board] or {}; rankDisk[board][key] = score end,
	rankRemove = function(board, key) if rankDisk[board] then rankDisk[board][key] = nil end end,
	rankTop = function(board, n)
		local rows = {}
		for key, score in rankDisk[board] or {} do
			table.insert(rows, { key = key, score = score })
		end
		table.sort(rows, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.key < b.key end)
		while #rows > n do table.remove(rows) end
		return rows
	end,
	rankInfoSet = function(key, info) rankInfo[key] = info end,
	rankInfoGet = function(key) return rankInfo[key] end,
	rankInfoRemove = function(key) rankInfo[key] = nil end,
	isOffline = function() return false end,
})
local World = req("ServerScriptService/server/lune/modules/world")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
World.start()
local function run(seconds)
	for _ = 1, math.floor(seconds / TICK + 0.5) do
		World.tick(TICK)
	end
end
local function person(t)
	t.attrs = {}
	t.SetAttribute = function(self, key, value) self.attrs[key] = value end
	return t
end
local function routeNext(from, target)
	local prev, queue = { [from] = from }, { from }
	while #queue > 0 do
		local cur = table.remove(queue, 1)
		if cur == target then
			while prev[cur] ~= from do
				cur = prev[cur]
			end
			return cur
		end
		for _, portal in SCENES.scenes[cur].portals do
			if not prev[portal.to] then
				prev[portal.to] = cur
				table.insert(queue, portal.to)
			end
		end
	end
	return nil
end
local function goTo(player, target)
	for _ = 1, 32 do
		local ss = World.session(player)
		if ss.scene == target then
			return true
		end
		local hop = routeNext(ss.scene, target)
		for _, portal in SCENES.scenes[ss.scene].portals do
			if portal.to == hop then
				ss.jumped, ss.stale = true, nil
				handlers.Move(player, portal.x, portal.y, 1)
			end
		end
		if not handlers.Travel(player, hop) then
			return false
		end
	end
	return false
end

-- 그 직업의 사냥기(1차)
local function mobSkill(class: string)
	for id, sk in COMBAT.skills do
		if sk.who == class and sk.type == "mob" and sk.job == 1 then
			return id, sk
		end
	end
	error("사냥기가 없다 " .. class)
end

-- 사냥기를 한 번 쓴다(화면이 하듯: 구간을 차례로 보낸다 — 모으는 구간은 그 구간이 끝나자마자 뗀다)
local function cast(p, id, sk, x, y, dir)
	for i, seg in sk.segs do
		handlers.Skill(p, id, i, x, y, dir)
		run(seg.time)
	end
end

-- 그 장면에서 그 종류의 몬스터 n마리를 차례로 잡는다. 돌려주는 것: 한 마리에 든 시간 · 쓴 횟수 · 잃은 체력(최대 체력의 %) · 얻은 경험치(평균)
local function hunt(p, sceneKey: string, kind: string, n: number)
	local s = World.session(p)
	local h = s.hero
	if not goTo(p, sceneKey) then
		return nil
	end
	local room = World.room(sceneKey)
	local id, sk = mobSkill(h.class)
	-- 사냥기가 닿는 자리: 몬스터의 왼쪽에 서서 오른쪽을 본다(상자의 앞쪽 끝에서 조금 안쪽)
	local reach = 0
	for _, hit in sk.hits do
		reach = math.max(reach, hit.box[2])
	end
	local stand = math.min(reach - 10, 30)
	local sum = { time = 0, casts = 0, lost = 0, xp = 0, n = 0 }
	-- 여러 바퀴를 돈다(그 종류가 서너 마리뿐이라 한 바퀴로는 재는 수가 모자라 값이 크게 흔들렸다 — 2026-10-11: 아홉 마리를 잰다. 바퀴 사이에는 다시 나오기를 기다린다)
	for _ = 1, 5 do
	for _, mob in room.mobs do
		if sum.n >= n then
			break
		end
		if mob.kind == kind and mob.hp > 0 then
			run(2) -- 나타나는 동작이 끝나기를 기다린다
			h.hp = h.maxHp
			h.alive = true
			local xp0, level0 = h.xp, h.level
			local t0, casts = World.now, 0
			local lost = 0
			while mob.hp > 0 and casts < 60 do
				s.jumped, s.stale = true, nil
				h.x, h.y = mob.x - stand, mob.y
				handlers.Move(p, h.x, h.y, 1)
				local before = h.hp
				cast(p, id, sk, h.x, h.y, 1)
				casts += 1
				lost += math.max(0, before - h.hp)
				if h.hp < h.maxHp * 0.3 then
					h.hp = h.maxHp -- 쓰러지지 않게 채운다(잃은 양은 따로 센다)
				end
			end
			if mob.hp <= 0 then
				sum.time += World.now - t0
				sum.casts += casts
				sum.lost += lost / h.maxHp * 100
				sum.xp += if h.level == level0 then h.xp - xp0 else 0
				sum.n += 1
			end
			-- 레벨이 오르지 않게 되돌린다(같은 레벨에서 잰다)
			if h.level ~= level0 then
				h.level, h.xp = level0, xp0
				Hero.recalc(h)
			else
				h.xp = xp0
			end
		end
	end
	if sum.n >= n then
		break
	end
	run(COMBAT.rules.respawn + 3)
	end
	if sum.n == 0 then
		return nil
	end
	return { time = sum.time / sum.n, casts = sum.casts / sum.n, lost = sum.lost / sum.n, xp = sum.xp / sum.n, n = sum.n }
end

-- 재는 자리: 레벨 · 장면 · 몬스터(그 레벨의 사냥터에서 가장 많은 몬스터)
local SPOTS = {
	-- 2026-10-14부터 한 맵에 한 종류: 마을 어귀 = 수습 검병 · 달그림자 사냥터 = 검병 · 깊은 곳 = 포자 주머니 · 야영지 = 재까마귀
	{ lv = 1, scene = "r1a1", kind = "trainee" },
	{ lv = 2, scene = "r1a1", kind = "trainee" },
	{ lv = 3, scene = "hunt", kind = "warrior" },
	{ lv = 5, scene = "hunt", kind = "warrior" },
	{ lv = 6, scene = "r1a3", kind = "puff" },
	{ lv = 9, scene = "r1a4", kind = "crow" },
}

local uid = 2600
local table_ = {} -- [직업][레벨] = 잰 것
for _, class in CLASSES.order do
	table_[class] = {}
	for _, spot in SPOTS do
		uid += 1
		local p = person({ UserId = uid, Name = "bal" .. uid })
		handlers.Ready(p)
		local made = handlers.Chars(p, "create", "잰다" .. uid, class)
		handlers.Chars(p, "enter", made.id)
		World.wake(p) -- (새 캐릭터는 꿈에서 시작한다 — 꿈은 마친 것으로)
		local h = World.session(p).hero
		while h.level < spot.lv do
			Hero.gainXp(h, N.xpNeed(h.level) - h.xp)
		end
		Hero.autoStat(h)
		Hero.autoSkill(h)
		Hero.recalc(h)
		h.hp = h.maxHp
		local r = hunt(p, spot.scene, spot.kind, 9)
		if r then
			local mobLv = 0
			for _, def in SCENES.scenes[spot.scene].mobs do
				if def.kind == spot.kind then
					mobLv = def.lv
				end
			end
			r.kills = math.ceil(N.xpNeed(spot.lv) / math.max(1, r.xp))
			r.minutes = r.kills * r.time / 60
			r.maxHp = h.maxHp
			r.mobLv = mobLv
			table_[class][spot.lv] = r
			print(("[BAL] %-10s Lv.%-2d vs %-8s(Lv.%d) | 한 마리 %4.1f초 · %4.1f번 · 체력 -%4.1f%% · 경험치 %5.1f | 레벨업까지 %3d마리 · 싸움만 %4.1f분(설계 %4.1f분 · %d마리) | 체력 %d · 전투력 %d"):format(
				class, spot.lv, spot.kind, mobLv, r.time, r.casts, r.lost, r.xp, r.kills, r.minutes, N.minutesAt(spot.lv), N.killsAt(spot.lv), h.maxHp, Hero.power(h)))
		else
			print(("[BAL] %-10s Lv.%-2d vs %-8s | 재지 못했다"):format(class, spot.lv, spot.kind))
		end
		World.removePlayer(p)
	end
end

-- 직업 사이의 차이: 같은 자리에서 가장 빠른 직업과 가장 느린 직업
for _, spot in SPOTS do
	local fast, slow, safe, risky = math.huge, 0, math.huge, 0
	local who = {}
	for _, class in CLASSES.order do
		local r = table_[class][spot.lv]
		if r then
			if r.time < fast then fast = r.time; who.fast = class end
			if r.time > slow then slow = r.time; who.slow = class end
			if r.lost < safe then safe = r.lost; who.safe = class end
			if r.lost > risky then risky = r.lost; who.risky = class end
		end
	end
	print(("[BAL] Lv.%-2d %-8s | 잡는 시간: 가장 빠름 %s %.1f초 · 가장 느림 %s %.1f초(%.2f배) | 잃는 체력: 가장 적음 %s %.1f%% · 가장 많음 %s %.1f%%"):format(
		spot.lv, spot.kind, who.fast, fast, who.slow, slow, slow / fast, who.safe, safe, who.risky, risky))
	-- 두 번에 잡는 Lv.1에서는 사냥기를 한 번 쓰는 시간의 차이(리븐 0.55초 · 살라맨더 1초)가 그대로 배수가 된다 — 차이가 1초 안이면 같은 것으로 본다
	expect(slow / fast <= 1.6 or slow - fast <= 1, ("Lv.%d %s: 직업 사이의 잡는 시간이 1.6배 안이다(또는 차이가 1초 안 — %.2f배 · %s %.1f초 · %s %.1f초)"):format(spot.lv, spot.kind, slow / fast, who.fast, fast, who.slow, slow))
	expect(risky <= 35, ("Lv.%d %s: 한 마리를 잡는 동안 잃는 체력이 최대 체력의 35%% 안이다(%s %.1f%%)"):format(spot.lv, spot.kind, who.risky, risky))
end
