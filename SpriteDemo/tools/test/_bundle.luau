-- 가짜 로블록스 환경(테스트용) — tools/test/run.py가 이 파일 뒤에 모듈들과 테스트를 붙여 한 파일로 실행한다.
--  MODULES[경로] = 모듈 함수. 경로 = "ReplicatedStorage/shared/…" · "ServerScriptService/server/…".
--  req(경로)로 불러온다. 가짜 모듈로 바꾸려면 불러오기 전에 MOCK(경로, 값).
--  시간: clock.now(가짜 시계, os.clock이 이 값을 돌려준다) · advance(초)로 흘려보내면 task.delay · task.wait가 그때 실행된다.
MODULES = {}
local LOADED = {}

-- ---------- Vector2 ----------
local V2 = {}
V2.__index = function(t, k)
	if k == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y)
	elseif k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y)
		return if m > 0 then setmetatable({ X = t.X / m, Y = t.Y / m }, V2) else setmetatable({ X = 0, Y = 0 }, V2)
	end
	return V2[k]
end
local function vec(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
V2.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
	if type(a) == "number" then return vec(a * b.X, a * b.Y) end
	if type(b) == "number" then return vec(a.X * b, a.Y * b) end
	return vec(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then return vec(a.X / b, a.Y / b) end
	return vec(a.X / b.X, a.Y / b.Y)
end
V2.__unm = function(a) return vec(-a.X, -a.Y) end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
function V2.Dot(a, b) return a.X * b.X + a.Y * b.Y end
function V2.Lerp(a, b, t) return vec(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end
local Vector2 = { new = vec, zero = vec(0, 0), one = vec(1, 1) }

-- ---------- Random(정해진 순서 — 테스트가 매번 같게) ----------
local Random = {}
function Random.new(seed)
	local s = (seed or 12345) % 2147483647
	local r = {}
	local function nextf()
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
	function r:NextNumber(a, b)
		local f = nextf()
		if a and b then return a + (b - a) * f end
		return f
	end
	function r:NextInteger(a, b)
		return a + math.floor(nextf() * (b - a + 1))
	end
	return r
end

-- ---------- 가짜 시계 · task ----------
clock = { now = 1000 }
local timers = {}
local task = {}
function task.delay(t, fn, ...)
	table.insert(timers, { at = clock.now + t, fn = fn, args = { ... } })
end
function task.spawn(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then error(err, 0) end
	return co
end
function task.defer(fn, ...) return task.spawn(fn, ...) end
function task.wait(t)
	local co = coroutine.running()
	t = t or 0.03
	table.insert(timers, { at = clock.now + t, co = co, waited = t })
	return coroutine.yield()
end
-- 시간을 흘려보낸다: 그 사이 예약된 것들을 시각 순서대로 실행
function advance(seconds)
	local target = clock.now + seconds
	while true do
		local best
		for i, tm in timers do
			if tm.at <= target and (not best or tm.at < timers[best].at) then best = i end
		end
		if not best then break end
		local tm = table.remove(timers, best)
		clock.now = math.max(clock.now, tm.at)
		if tm.co then
			local ok, err = coroutine.resume(tm.co, tm.waited)
			if not ok then error(err, 0) end
		else
			tm.fn(table.unpack(tm.args))
		end
	end
	clock.now = target
end
local osMock = setmetatable({ clock = function() return clock.now end, time = function() return 1700000000 + math.floor(clock.now) end }, { __index = os })

-- ---------- 인스턴스 흉내(경로 노드) ----------
local nodeMeta = {}
local function node(path)
	return setmetatable({ __path = path }, nodeMeta)
end
local function exists(path)
	if MODULES[path] or LOADED[path] ~= nil then return true end
	local prefix = path .. "/"
	for p in MODULES do
		if string.sub(p, 1, #prefix) == prefix then return true end
	end
	return false
end
nodeMeta.__index = function(t, k)
	local path = rawget(t, "__path")
	if k == "Parent" then
		local parent = string.match(path, "^(.*)/[^/]+$")
		return node(parent or "")
	elseif k == "Name" then
		return string.match(path, "([^/]+)$")
	elseif k == "FindFirstChild" or k == "WaitForChild" then
		return function(_, name)
			local p = path .. "/" .. name
			return if exists(p) then node(p) else nil
		end
	elseif k == "GetChildren" then
		return function()
			local seen, out = {}, {}
			local prefix = path .. "/"
			for p in MODULES do
				if string.sub(p, 1, #prefix) == prefix then
					local child = string.match(string.sub(p, #prefix + 1), "^[^/]+")
					if not seen[child] then seen[child] = true; table.insert(out, node(prefix .. child)) end
				end
			end
			return out
		end
	elseif k == "IsA" then
		return function(_, class) return class == "ModuleScript" and MODULES[path] ~= nil end
	end
	return node(path .. "/" .. k)
end

local services = {}
local game = {}
function game:GetService(name)
	return services[name] or node(name)
end
-- 테스트가 가짜 서비스를 끼워 넣는다(Players · RunService 등)
function SERVICE(name, value) services[name] = value end

local function typeofMock(v)
	if type(v) == "table" then
		local mt = getmetatable(v)
		if mt == V2 then return "Vector2" end
		if mt == nodeMeta then return "Instance" end
		if rawget(v, "__type") then return rawget(v, "__type") end
	end
	return type(v)
end

local Color3 = { fromRGB = function(r, g, b) return { __type = "Color3", R = r / 255, G = g / 255, B = b / 255 } end, new = function(r, g, b) return { __type = "Color3", R = r, G = g, B = b } end }
local UDim2 = { fromOffset = function(x, y) return { X = { Offset = x, Scale = 0 }, Y = { Offset = y, Scale = 0 } } end, new = function(xs, xo, ys, yo) return { X = { Offset = xo, Scale = xs }, Y = { Offset = yo, Scale = ys } } end }
local Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, k2) return k .. "." .. k2 end }) end })
local Instance = { new = function(class) return { ClassName = class } end }
warnings = {}
local function warnMock(...) table.insert(warnings, table.concat({ ... }, " ")) end
local quietPrint = function() end

local function requireMock(target)
	local path = if type(target) == "string" then target else rawget(target, "__path")
	if LOADED[path] ~= nil then return LOADED[path] end
	local fn = MODULES[path]
	if not fn then error("모듈 없음: " .. tostring(path), 2) end
	local result = fn(node(path), game, requireMock, task, osMock, typeofMock, Vector2, Random, Color3, UDim2, Enum, Instance, warnMock, quietPrint, node("Workspace"), function() return clock.now end)
	LOADED[path] = result
	return result
end
req = requireMock
function MOCK(path, value) LOADED[path] = value end
function RESET() table.clear(LOADED); table.clear(timers); table.clear(services); table.clear(warnings); clock.now = 1000 end
V = vec
RandomNew = Random.new

-- ---------- 테스트 도구 ----------
local total, failed, current = 0, 0, ""
function expect(cond, msg)
	total += 1
	if not cond then
		failed += 1
		print(("  FAIL [%s] %s"):format(current, tostring(msg)))
	end
end
function eq(a, b, msg)
	expect(a == b, ("%s (기대 %s, 실제 %s)"):format(tostring(msg), tostring(b), tostring(a)))
end
function runTest(name, fn)
	current = name
	RESET()
	local before, beforeFailed = total, failed
	local ok, err = pcall(fn)
	if not ok then
		failed += 1; total += 1
		print(("  FAIL [%s] 실행 중 오류: %s"):format(name, tostring(err)))
	end
	print(("[%s] 검사 %d개, 실패 %d개"):format(name, total - before, failed - beforeFailed))
end
function finish()
	print(("== 전체 검사 %d개, 실패 %d개 =="):format(total, failed))
end

MODULES['ReplicatedStorage/shared/config/balance'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 게임 규칙 수치(밸런스)의 "단 하나의 출처". 서버와 클라이언트가 같은 값을 각자 하드코딩하면 한쪽만
-- 고쳐서 표시와 실제가 어긋나므로(예: 최대 체력 공식이 클라/서버에 따로 있었음), 규칙에 관련된
-- 숫자와 공식은 전부 여기에만 두고 양쪽이 이 파일을 읽는다.
local balance = {}

-- 성장
balance.BASE_MAX_HEALTH = 100
balance.MAX_HEALTH_PER_LEVEL = 20
balance.BASE_ATTACK = 10
balance.ATTACK_PER_LEVEL = 2 -- 레벨업마다 오르는 공격력(「오문 닌자전」 §3-3 — 따로 찍지 않고 자동으로 오른다)
balance.BASE_DEFENSE = 0

-- 사망 페널티(GAME_DESIGN §7): 지금 레벨 필요 경험치의 5% + 가진 골드의 5%를 잃는다. 레벨은 내려가지 않는다.
balance.DEATH_EXP_LOSS = 0.05
balance.DEATH_GOLD_LOSS = 0.05

-- 레벨에서 오는 공격력(무기 · 강화는 따로 더한다 — server inventoryService.GetAttackDamage)
function balance.attackFor(level: number): number
	return balance.BASE_ATTACK + (math.max(level, 1) - 1) * balance.ATTACK_PER_LEVEL
end

function balance.maxHealthFor(level: number): number
	return balance.BASE_MAX_HEALTH + (level - 1) * balance.MAX_HEALTH_PER_LEVEL
end

-- 레벨업 필요 경험치: 1레벨 100, 2레벨 150, ...
function balance.maxExperienceFor(level: number): number
	return 100 + (level - 1) * 50
end

-- 인벤토리: 탭(장비·소비·기타·캐시·중요)마다 칸이 따로 있다. 탭당 칸 수(클라이언트 UI 그리드도 이 값으로 그린다).
balance.INVENTORY_TABS = { "Equip", "Use", "Etc", "Cash", "Key" }
balance.INVENTORY_TAB_NAMES = { Equip = "장비", Use = "소비", Etc = "기타", Cash = "캐시", Key = "중요" }
balance.INVENTORY_COLUMNS = 6
balance.INVENTORY_ROWS = 4
balance.INVENTORY_SLOTS = balance.INVENTORY_COLUMNS * balance.INVENTORY_ROWS

-- 월드 드랍(땅에 버려진 아이템): 이 시간(초)이 지나면 사라진다. 줍기 거리(도트, 발 기준) — 서버는 복제 지연만큼 여유를 더 준다.
balance.WORLD_DROP_LIFETIME = 90
balance.PICKUP_RANGE = 20
balance.PICKUP_PAD = 16

-- 탑다운 전투(서버 권위): 공격 판정 최소 간격(초) — 클라이언트 공격 동작(4장 x 0.08초 + 쉬는 0.1초)보다 약간 짧게.
balance.TOWN_ATTACK_COOLDOWN = 0.35

return balance

end
MODULES['ReplicatedStorage/shared/config/capture'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 포획 규칙(클라이언트·서버 공용) — GAME_DESIGN.md §3. 공방 js/bells.js captureChance와 같은 공식.
--  전투 중에 소비 단축칸(1·2·3)에 놓은 방울을 쓰면 바라보는 방향으로 직선으로 날아가고, 처음 맞은 몬스터에게 포획을 시도한다.
--  자격: 아무도 안 때린 몬스터이거나, 던진 사람이 지금 그 몬스터의 딜 1등일 때만(아니면 튕겨 나감 — "포획 불가").
--  종합 포획 확률 = 방울 기본 포획률 + 레벨 보정 + 체력 보정 (+ 속성 방울 + 잘 만든 방울), 1% ~ 95%.
--  실패하면 몬스터는 도망간다(쓰러뜨린 게 아니라 아무도 재료를 못 받음). 그냥 쓰러뜨리면 = 재료 받기.
--  화면에 보이는 건 가방 방울 상세의 "기본 포획률"뿐 — 종합 확률은 보여 주지 않는다. 판정·굴리기는 서버만.
local exports = {}

-- 방울 등급(1~5) → 기본 포획률. 아이템 id = "Bell<등급>"(shared/data/items.luau)
exports.BASE_RATE = { 0.30, 0.45, 0.60, 0.75, 0.90 }
exports.LEVEL_PENALTY = 0.008 -- 레벨 보정: 몬스터 레벨 1당 −0.8%p
exports.HP_BONUS = 0.50 -- 체력 보정: 깎인 체력 비율 × 최대 +50%p
exports.ELEMENT_BONUS = 0.10 -- 속성 방울 속성 == 몬스터 속성(속성 방울은 M6)
exports.WELL_MADE_BONUS = 0.05 -- 잘 만든 방울(M6)
exports.MIN_CHANCE = 0.01
exports.MAX_CHANCE = 0.95
exports.HINT_HP = 0.3 -- 체력이 이 비율 이하면 몬스터 머리 위에 작은 방울 표시(숫자 없음)

-- 던지기
exports.THROW_RANGE = 80 -- 날아가는 거리(도트)
exports.THROW_WIDTH = 7 -- 직선에서 이만큼(도트) 옆까지 맞음
exports.THROW_SPEED = 180 -- 도트/초
exports.THROW_COOLDOWN = 0.8 -- 초
-- 흔들림(딸랑): 판정을 SHAKES번으로 나눠 굴린다. 한 번 통과 확률 = 종합 확률^(1/SHAKES) → 다 통과하면 성공(전체 확률은 그대로).
-- 딸랑 횟수 = 통과한 판정 수(확률이 낮으면 0~1번 만에 깨지고, 높을수록 끝까지 버팀) — 포켓몬 볼 흔들림과 같은 원리.
exports.SHAKES = 3
exports.RING_TIME = 0.35 -- 룬 문양 원이 그려지는 시간
exports.DING_TIME = 0.45 -- 딸랑 한 번(방울 흔들림 + 몬스터 꿈틀)

-- 맞은 뒤 결과가 보이기까지(서버는 이 시간 뒤에 결과를 적용한다)
function exports.RevealTime(dings: number): number
	return exports.RING_TIME + exports.DING_TIME * dings + 0.15
end

-- 흔들림 판정: (딸랑 횟수, 성공 여부)
function exports.RollShakes(chance: number, rng: Random): (number, boolean)
	local per = chance ^ (1 / exports.SHAKES)
	local dings = 0
	for _ = 1, exports.SHAKES do
		if rng:NextNumber() < per then
			dings += 1
		else
			break
		end
	end
	return dings, dings == exports.SHAKES
end

function exports.BaseRate(tier: number): number
	return exports.BASE_RATE[tier] or exports.BASE_RATE[1]
end

-- 종합 포획 확률
function exports.Chance(level: number, tier: number, hpRatio: number, elementMatch: boolean?, wellMade: boolean?): number
	local p = exports.BaseRate(tier)
		- exports.LEVEL_PENALTY * level
		+ exports.HP_BONUS * (1 - math.clamp(hpRatio, 0, 1))
	if elementMatch then
		p += exports.ELEMENT_BONUS
	end
	if wellMade then
		p += exports.WELL_MADE_BONUS
	end
	return math.clamp(p, exports.MIN_CHANCE, exports.MAX_CHANCE)
end

return exports

end
MODULES['ReplicatedStorage/shared/config/combat'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 탑다운 전투 수치(기본 공격·몬스터 체력) — 숫자는 전부 여기서 고친다.
-- 거리 단위는 "도트"(바닥 타일 1칸 = 16도트).
return {
	-- 기본 공격: 몸이 들썩이는 4장 애니메이션(공방 캐릭터 탭 "기본 공격"), hitFrame번째 장에서 한 번 판정.
	ATTACK_DAMAGE = 10,
	ATTACK_FRAME_TIME = 0.08, -- 한 장에 걸리는 시간(4장 = 0.32초)
	ATTACK_COOLDOWN = 0.1, -- 공격이 끝나고 다음 공격까지 쉬는 시간

	-- 일반 공격 범위: 바라보는 방향 앞쪽 사각형(발 위치 기준).
	--  reach = 앞으로 얼마나 닿나, width = 옆으로 얼마나 넓나
	ATTACK_REACH = 20,
	ATTACK_WIDTH = 22,

	-- 투척 무기(단축칸): 연달아 던지는 최소 간격(초). 무기별 수치는 shared/data/ninjaItems.luau Throw
	THROW_COOLDOWN = 0.45,

	-- 몬스터(체력·경험치·공격력은 레벨에 따라 — shared/config/monsterLevels.luau)
	MONSTER_RESPAWN = 6, -- 쓰러진 뒤 같은 스폰 구역에 다시 나타날 때까지(초)

	-- 몬스터 반격: 맞으면 때린 사람을 쫓아가 공격한다(먼저 덤비지는 않음 — GAME_DESIGN §2 [제안])
	MONSTER_ATTACK_RANGE = 13, -- 이 거리(도트) 안이면 공격
	MONSTER_ATTACK_COOLDOWN = 1.6, -- 공격 간격(초)
	MONSTER_CHASE_SPEED = 1.3, -- 쫓을 때 속도 = 평소 × 이 값
	MONSTER_LEASH = 128, -- 집(나타난 자리)에서 이만큼 멀어지면 포기하고 돌아간다(도트)
	MONSTER_AGGRO_TIME = 8, -- 마지막으로 맞은 뒤 이 시간이 지나면 포기(초)
}

end
MODULES['ReplicatedStorage/shared/config/drops'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 사냥 드롭(서버) — 「오문 닌자전」 NINJA_DESIGN.md §6.
--  몬스터를 쓰러뜨리면(기여도 10% 이상인 사람 각자) 엽전 + 그 몬스터가 사는 지역의 드롭 표를 한 줄씩 굴린다.
--  지역 = townWorld species[i].element(지역 id). chance = 그 줄이 나올 확률, count = 개수(없으면 1).
--  초안(2026-10-03). 두루마리(N2) · 무기(N3) 드롭은 아래 SCROLLS · WEAPONS.
local exports = {}

exports.REGION = {
	field = {
		{ item = "GrassBlade", chance = 0.35 },
		{ item = "Branch", chance = 0.28 },
		{ item = "Feather", chance = 0.10 },
		{ item = "CopperBar", chance = 0.05 }, -- 들판 무기 강화 재료
		{ item = "Onigiri", chance = 0.06 },
	},
	bamboo = {
		{ item = "Branch", chance = 0.35 },
		{ item = "Stone", chance = 0.25 },
		{ item = "Feather", chance = 0.12 },
		{ item = "CopperBar", chance = 0.08 },
		{ item = "Onigiri", chance = 0.06 },
	},
	swamp = {
		{ item = "Stone", chance = 0.30 },
		{ item = "CopperBar", chance = 0.14 },
		{ item = "IronBar", chance = 0.05 },
		{ item = "Sushi", chance = 0.06 },
	},
	desert = {
		{ item = "Stone", chance = 0.30 },
		{ item = "IronBar", chance = 0.14 },
		{ item = "GreenGem", chance = 0.04 },
		{ item = "Sushi", chance = 0.06 },
	},
	snow = {
		{ item = "IronBar", chance = 0.16 },
		{ item = "SilverBar", chance = 0.08 },
		{ item = "GreenGem", chance = 0.05 },
		{ item = "Sushi", chance = 0.06 },
	},
	ruins = {
		{ item = "SilverBar", chance = 0.14 },
		{ item = "GoldBar", chance = 0.05 },
		{ item = "RedGem", chance = 0.05 },
		{ item = "Yakitori", chance = 0.06 },
	},
	tower = {
		{ item = "GoldBar", chance = 0.12 },
		{ item = "RedGem", chance = 0.06 },
		{ item = "YellowGem", chance = 0.04 },
		{ item = "Yakitori", chance = 0.06 },
	},
	nest = {
		{ item = "GoldBar", chance = 0.14 },
		{ item = "MithrilBar", chance = 0.06 },
		{ item = "YellowGem", chance = 0.05 },
		{ item = "PurpleGem", chance = 0.03 },
		{ item = "Yakitori", chance = 0.06 },
	},
}

-- 인술 두루마리(N2): 어느 지역에서나 SCROLL_CHANCE 확률로 다섯 유파 중 하나(고르게). 다른 유파 것은 팔거나 거래한다.
exports.SCROLL_CHANCE = 0.012
exports.SCROLLS = { "ScrollFire", "ScrollIce", "ScrollPlant", "ScrollRock", "ScrollThunder" }

-- 무기(N3): 그 지역 무기 중 하나가 WEAPON_CHANCE 확률로. 들판 무기는 잡화 상점에서도 판다.
exports.WEAPON_CHANCE = 0.015
exports.WEAPONS = {
	field = { "Ninjato", "Sai", "Club" },
	bamboo = { "Katana", "Spear", "Whip" },
	swamp = { "LongSword", "Axe" },
	desert = { "Trident", "Scimitar", "Hammer" },
	snow = { "Rapier", "Halberd" },
	ruins = { "GreatSword" },
	tower = { "GreatSword" },
	nest = { "GreatSword" },
}

-- 부적(N3): 그 지역 부적이 CHARM_CHANCE 확률로. 첫 부적(수호 부적)은 잡화 상점에서 판다.
exports.CHARM_CHANCE = 0.008
exports.CHARMS = {
	bamboo = { "WindCharm" },
	swamp = { "WindCharm" },
	desert = { "IronCharm" },
	snow = { "IronCharm" },
	ruins = { "SpiritCharm" },
	tower = { "SpiritCharm" },
	nest = { "SpiritCharm" },
}

-- 한 번 굴림 → { { item = id, count = n }, ... }
function exports.Roll(region: string?, rng: Random)
	local out = {}
	local list = exports.REGION[region or ""]
	if not list then
		return out
	end
	for _, d in list do
		if rng:NextNumber() < d.chance then
			table.insert(out, { item = d.item, count = d.count or 1 })
		end
	end
	if rng:NextNumber() < exports.SCROLL_CHANCE then
		table.insert(out, { item = exports.SCROLLS[rng:NextInteger(1, #exports.SCROLLS)], count = 1 })
	end
	local pool = exports.WEAPONS[region or ""]
	if pool and rng:NextNumber() < exports.WEAPON_CHANCE then
		table.insert(out, { item = pool[rng:NextInteger(1, #pool)], count = 1 })
	end
	local charms = exports.CHARMS[region or ""]
	if charms and rng:NextNumber() < exports.CHARM_CHANCE then
		table.insert(out, { item = charms[rng:NextInteger(1, #charms)], count = 1 })
	end
	return out
end

return exports

end
MODULES['ReplicatedStorage/shared/config/features'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 기능 스위치(클라이언트·서버 공용) — 「오문 닌자전」 기획(NINJA_DESIGN.md §13)에서 지금은 빼 둔 것들.
--  코드는 지우지 않고 꺼 둔다. 나중에 다시 켤 때 여기만 바꾸면 된다.
return {
	PETS = false, -- 펫(소환수): 나중에 BM으로 넣는다 — 펫 상자 · 따라다니기 · 펫 스킬
	CAPTURE = false, -- 포획(맺음 방울 던지기)
}

end
MODULES['ReplicatedStorage/shared/config/fxAssets.generated'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/write_fx_ids.mjs).
-- 원본 이미지: SpriteDemo/assets/fx/ (dino-workshop/tools/export_fx.mjs)
return {
	SHEETS = { "rbxassetid://97676105585004", "rbxassetid://119545531456505", "rbxassetid://103759261237104", "rbxassetid://91333167371905" },
}

end
MODULES['ReplicatedStorage/shared/config/monsterLevels'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 몬스터 레벨 규칙(클라이언트·서버 공용) — GAME_DESIGN.md §2.
--  종마다 자연 스폰 레벨 범위가 있다(townWorld.generated의 species[i].levelMin~levelMax, 공방 js/buns.js의 lv). 최대 100.
--  레벨이 곧 희귀도: 범위 안에서도 높은 레벨일수록 드물게 나온다(RollLevel — 범위 맨 아래가 가장 흔하고 위로 갈수록 선형으로 줄어듦).
--  예전 내보내기(범위가 없는 species)는 도감 순번으로 계산하던 옛 규칙으로 대신한다(공방에서 다시 보내면 사라짐).
-- 체력·경험치 공식도 여기에만 둔다(서버가 경험치를 줄 때 같은 공식으로 검증).
local world = require(script.Parent.Parent.data["townWorld.generated"])

local exports = {}

exports.MAX_LEVEL = 100
local LEGACY_LEVELS_PER_TIER = 5

-- 옛 규칙(속성 안 순번 = 단계, n단계 = Lv.5(n-1)~5n)
local tierOf = {}
do
	local count = {}
	for row, s in world.species do
		count[s.element] = (count[s.element] or 0) + 1
		tierOf[row] = count[s.element]
	end
end

-- 자연 스폰 레벨 범위(최소, 최대)
function exports.LevelRange(row: number): (number, number)
	local s = world.species[row]
	if s and s.levelMin and s.levelMax then
		return s.levelMin, s.levelMax
	end
	local tier = tierOf[row] or 1
	return math.max(1, (tier - 1) * LEGACY_LEVELS_PER_TIER), tier * LEGACY_LEVELS_PER_TIER
end

-- 스폰 레벨 뽑기: 범위 안 레벨 L의 가중치 = (최대 - L + 1) — 낮은 레벨이 흔하고 높은 레벨이 드물다
function exports.RollLevel(row: number, rng: Random): number
	local lo, hi = exports.LevelRange(row)
	local total = 0
	for level = lo, hi do
		total += hi - level + 1
	end
	local pick = rng:NextNumber() * total
	for level = lo, hi do
		pick -= hi - level + 1
		if pick < 0 then
			return level
		end
	end
	return lo
end

-- 레벨별 몬스터 체력(Lv.1 = 30, 레벨당 +10)
function exports.MaxHealth(level: number): number
	return 20 + level * 10
end

-- 몬스터 공격력(방어력을 빼기 전, 최소 1): Lv.1 = 6, 레벨당 +2
function exports.AttackDamage(level: number): number
	return 4 + level * 2
end

-- 처치 경험치(Lv.1 = 15, 레벨당 +5) — 플레이어 1레벨 필요 경험치는 100(balance.maxExperienceFor)
function exports.Experience(level: number): number
	return 10 + level * 5
end

return exports

end
MODULES['ReplicatedStorage/shared/config/ninjutsu'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 유파 · 전직 · 인술(「오문 닌자전」 NINJA_DESIGN.md §0-1 · §4) — 수치는 전부 여기서 고친다. 클라이언트·서버 공용.
--  전직(메이플식, 사용자 지시 2026-10-03): Lv.1~9는 견습 닌자(유파 없음). 1차 전직(Lv.10) 때 유파를 고르고, 2차 30 · 3차 60 · 4차 100.
--   전직은 마을 스승 곁에서. 전직 단계(Job 0~4)마다 그 유파의 인술 칸이 하나씩 열린다 — skills[n] = n차 전직에 배우는 인술.
--   유파를 바꾸려면 스승 곁에서 엽전 CHANGE_COST(전직 단계는 그대로).
--  기력: 인술에 쓰는 자원. 초당 ENERGY_REGEN씩 차고, 기본 공격이 맞을 때마다 ENERGY_PER_HIT.
--  스킬 레벨 · SP · 단축칸은 아래 「스킬 나무」 절. (MAX_LEVEL · LEVEL_BONUS · LevelScale은 옛 두루마리 단계 — 더는 쓰지 않는다)
-- 거리 단위는 "도트"(바닥 타일 1칸 = 16도트). 피해 = 내 공격력 × power × 단계 보정.
--
-- 인술 종류(kind):
--  projectile — 바라보는 방향 직선으로 날아가(range · speed · width) 처음 닿은 몬스터에서 터짐(radius 안 모두)
--  line       — 바라보는 방향 앞 긴 사각형(length × width*2) 안 모두(꿰뚫음), delay초 뒤
--  circle     — 쓴 자리 둘레 radius 안 모두, delay초 뒤. hits · interval이 있으면 여러 번
--  chain      — range 안 가장 가까운 몬스터 → jumpRange 안 다음 몬스터로 jumps번 옮겨 감(옮길 때마다 피해 × falloff)
--  heal       — 내 체력을 최대 체력의 ratio만큼 회복(vigorCost가 있으면 기력 대신 생기를 쓴다)
--  seed       — 투사체처럼 날아가 처음 닿은 몬스터에 박히고(power), fuse초 뒤 그 자리 둘레 radius에 터진다(burstPower)
--  guard      — seconds초 동안 받는 피해 × mult
-- 연출(fx — 이름은 shared/data/ninjaFx.generated.luau의 팩 이펙트, 클라 town/ninjutsuFx.luau · 공방 「닌자 맵」 탭이 읽는다):
--  shot = 날아가는 그림 · burst = 도착(가운데) 자리에서 한 번 · ring = 둘레에 ringCount개 · row = 앞으로 한 줄에 rowCount개
--  self = 쓴 사람 몸(loop면 지속 시간 동안 되풀이) · hit = 맞은 몬스터 몸 위
-- 덧붙는 효과: ember(불씨 중첩 — f_ember를 배웠을 때) · frost(서리 중첩 — i_frost를 배웠을 때) · selfHeal(쓴 사람 체력을 최대 체력의 그 비율만큼 회복) · burn(ticks번 · interval초마다 공격력 × power) · slow(mult배 속도로 seconds초) · stun(seconds초 멈춤) · push(도트만큼 밀림)
local exports = {}

exports.ENERGY_MAX = 100
exports.ENERGY_REGEN = 6
exports.ENERGY_PER_HIT = 4
exports.JOB_LEVELS = { 10, 30, 60, 100 } -- n차 전직을 할 수 있는 레벨(= n번 인술 칸이 열리는 전직)
exports.JOB_NAMES = { [0] = "견습", "하닌", "중닌", "상닌", "닌자 마스터" } -- 전직 단계별 계급 이름
exports.MAX_LEVEL = 5
exports.LEVEL_BONUS = 0.15
exports.CHANGE_COST = 1000
exports.CHANGE_NPC = "elder" -- 유파를 바꿔 주는 NPC 역할(스승)
exports.HAND_Y = 7 -- 손 높이(발에서 위로, 도트) — 투사체·직선 인술이 나가는 자리
exports.BODY_Y = 6 -- 몬스터 몸 가운데(발에서 위로, 도트)
-- 대쉬(이동기, 사용자 지시 2026-10-03): 견습은 "구르기", 1차 전직부터 유파의 대쉬(같은 키 — Shift · 화면 버튼).
--  순수 이동기다 — 피해도, 적을 멈추거나 느리게 하거나 밀치는 효과도 없다(사용자 지시). 길에 남는 그림은 보이기만 한다.
--  유파마다 무게가 다르다 — 불 · 번개는 빠르게, 얼음은 중간, 풀 · 바위는 무겁게(준비 동작 windup이 있고 느리다).
--  windup초 멈췄다가 time초 동안 바라보는 쪽으로 distance도트(벽에 막히면 거기까지). cost = 기력.
--  fx: start(떠난 자리) · path(길을 따라 pathStep도트마다. pathHold = 머무는 장에서 머무는 초, pathLoop = 그 초 동안 되풀이) · finish(닿은 자리)
exports.DASH = {
	novice = { name = "구르기", feel = "견습", windup = 0, distance = 36, time = 0.22, cooldown = 3, cost = 0,
		fx = { start = "smoke" },
		desc = "바라보는 쪽으로 짧게 구른다." },
	fire = { name = "불길 걸음", feel = "빠름", windup = 0, distance = 64, time = 0.16, cooldown = 3, cost = 8,
		fx = { start = "smoke", path = "flam", pathStep = 11, pathLoop = 0.6 },
		desc = "불꽃처럼 내달린다. 지나간 자리에 불길이 잠깐 인다." },
	thunder = { name = "번쩍", feel = "가장 빠름", windup = 0, distance = 72, time = 0.06, cooldown = 2.5, cost = 8,
		fx = { start = "spark", path = "boltLine", pathStep = 16, finish = "spark" },
		desc = "눈 깜짝할 사이에 옮겨 간다. 지나간 길에 번개 줄기가 남는다." },
	ice = { name = "얼음 길", feel = "중간", windup = 0.05, distance = 56, time = 0.28, cooldown = 4, cost = 8,
		fx = { start = "iceFlake", path = "iceFloor", pathStep = 12, pathHold = 0.7 },
		desc = "얼음 길을 깔며 미끄러진다." },
	plant = { name = "덩굴 도약", feel = "무거움", windup = 0.18, distance = 48, time = 0.34, cooldown = 5, cost = 8,
		fx = { path = "vine", pathStep = 16, pathHold = 0.5, finish = "plant" },
		desc = "덩굴이 몸을 감았다가 앞으로 튕겨 낸다." },
	rock = { name = "돌진", feel = "가장 무거움", windup = 0.22, distance = 48, time = 0.42, cooldown = 6, cost = 8,
		fx = { start = "smoke", path = "rockBits", pathStep = 12, finish = "dustRing" },
		desc = "몸을 낮췄다가 묵직하게 내달린다." },
}
exports.DASH_KEY = "LeftShift"

exports.BURN_FX = "flam" -- 불붙어 타는 동안 맞은 몬스터 위(피격 출처 "nin:burn")

-- 유파 순서 = 캐릭터 시트 줄 순서(townWorld.generated schools와 같아야 한다 — 테스트가 확인)
exports.SCHOOLS = { "fire", "ice", "plant", "rock", "thunder" }

exports.SCHOOL_INFO = {
	fire = { name = "불", title = "화문", color = { 228, 109, 58 }, desc = "한 방이 센 유파. 불씨가 남아 계속 태운다.", skills = { "fire_ball", "f_breath", "fire_rain", "fire_dragon" } },
	ice = { name = "얼음", title = "빙문", color = { 99, 171, 214 }, desc = "적을 느리게 하고 얼려 세운다.", skills = { "ice_spike", "i_shatter", "ice_lance", "ice_storm" } },
	plant = { name = "풀", title = "초문", color = { 122, 168, 62 }, desc = "덩굴로 묶고 잎으로 상처를 낫게 한다.", skills = { "plant_bind", "plant_heal", "plant_thorn", "plant_bloom" } },
	rock = { name = "바위", title = "암문", color = { 168, 122, 84 }, desc = "적을 밀쳐 내고 바위로 몸을 지킨다.", skills = { "rock_spike", "rock_guard", "rock_quake", "rock_meteor" } },
	thunder = { name = "번개", title = "뇌문", color = { 240, 200, 72 }, desc = "빠르고, 번개가 옆 적에게 튄다.", skills = { "thunder_bolt", "thunder_storm", "thunder_chain", "thunder_judge" } },
}

exports.SKILLS = {
	-- ===== 불 =====
	fire_ball = {
		name = "화염구", school = "fire", kind = "projectile", cost = 30, cooldown = 4,
		range = 112, speed = 200, width = 7, radius = 20, power = 2.2,
		ember = 1,
		fx = { shot = "fireball", burst = "explosion", hit = "flam" },
		desc = "불덩이를 던진다. 닿은 자리에서 터지며 불씨를 붙인다.",
	},
	-- ===== 얼음 =====
	ice_spike = {
		name = "얼음 가시", school = "ice", kind = "line", cost = 28, cooldown = 4,
		length = 88, width = 9, power = 1.7, delay = 0.2,
		frost = 1,
		fx = { shot = "iceSpike", hit = "iceB" },
		desc = "앞으로 얼음 가시를 쏜다. 꿰뚫고, 맞은 적에게 서리가 쌓인다.",
	},
	-- ===== 풀 =====
	plant_bind = {
		name = "덩굴 묶기", school = "plant", kind = "circle", cost = 28, cooldown = 5,
		radius = 34, power = 1.5, delay = 0.2, stun = 2,
		root = 5,
		fx = { ring = "plantB", ringCount = 5, hit = "plant" },
		desc = "덩굴이 내 둘레의 적을 묶는다.",
	},
	plant_heal = {
		name = "치유의 잎", school = "plant", kind = "heal", cost = 0, vigorCost = 30, cooldown = 6,
		ratio = 0.22,
		fx = { self = "boost" },
		desc = "생기 30을 써서 체력을 회복한다.",
	},
	-- ===== 바위 =====
	rock_spike = {
		name = "바위 주먹", school = "rock", kind = "line", cost = 26, cooldown = 3.5,
		length = 40, width = 14, power = 2.5, delay = 0.2, push = 22,
		fx = { row = "rockSpike", rowCount = 2 },
		desc = "앞을 크게 내리친다. 짧지만 세고, 맞은 적이 멀리 밀려난다.",
	},
	rock_guard = {
		name = "바위 갑옷", school = "rock", kind = "guard", cost = 35, cooldown = 14,
		mult = 0.5, seconds = 6,
		fx = { self = "shield", loop = true },
		desc = "6초 동안 받는 피해가 절반이 된다.",
	},
	-- ===== 번개 =====
	thunder_bolt = {
		name = "번개", school = "thunder", kind = "chain", cost = 26, cooldown = 3,
		range = 84, jumps = 2, jumpRange = 44, power = 1.7, falloff = 0.7,
		fx = { hit = "thunder" },
		desc = "가까운 적에게 번개가 떨어지고 옆 적 둘에게 옮겨 간다.",
	},
	thunder_storm = {
		name = "뇌우", school = "thunder", kind = "circle", cost = 45, cooldown = 10,
		radius = 44, power = 0.9, delay = 0.2, hits = 3, interval = 0.4,
		fx = { ring = "thunder", ringCount = 4, hit = "thunder" },
		desc = "내 둘레에 번개가 세 번 내리친다.",
	},
	-- ===== 3차 전직(Lv.60) =====
	fire_rain = {
		name = "불비", school = "fire", kind = "circle", cost = 55, cooldown = 14,
		radius = 48, power = 1.6, delay = 0.25, hits = 3, interval = 0.35,
		ember = 1,
		fx = { ring = "explosion", ringCount = 5, hit = "flam" },
		desc = "내 둘레에 불덩이가 세 번 쏟아진다.",
	},
	ice_lance = {
		name = "빙창", school = "ice", kind = "projectile", cost = 50, cooldown = 12,
		range = 140, speed = 260, width = 8, radius = 26, power = 3.2,
		frost = 2,
		fx = { shot = "iceSpike", burst = "ice", hit = "iceB" },
		desc = "얼음 창을 던진다. 닿은 자리 둘레가 얼어붙어 느려진다.",
	},
	plant_thorn = {
		name = "가시덤불", school = "plant", kind = "line", cost = 45, cooldown = 10,
		length = 80, width = 14, power = 2.6, delay = 0.2, stun = 1.5,
		fx = { row = "plant", rowCount = 3, hit = "plant" },
		desc = "앞으로 가시덤불이 뻗어 적을 꿰고 묶는다.",
	},
	rock_quake = {
		name = "지진", school = "rock", kind = "circle", cost = 50, cooldown = 12,
		radius = 44, power = 2.8, delay = 0.25, push = 18,
		fx = { ring = "rockSpike", ringCount = 5 },
		desc = "땅을 울려 둘레의 적을 멀리 밀쳐 낸다.",
	},
	thunder_chain = {
		name = "연쇄 번개", school = "thunder", kind = "chain", cost = 45, cooldown = 9,
		range = 96, jumps = 5, jumpRange = 52, power = 2.2, falloff = 0.85,
		fx = { hit = "thunder" },
		desc = "번개가 적 여섯에게 차례로 옮겨 간다.",
	},
	-- ===== 4차 전직(Lv.100) =====
	fire_dragon = {
		name = "화룡", school = "fire", kind = "line", cost = 80, cooldown = 24,
		length = 120, width = 16, power = 5, delay = 0.3,
		ember = 2,
		fx = { shot = "fireball", row = "explosion", rowCount = 4, hit = "flam" },
		desc = "불의 용이 앞을 길게 휩쓴다.",
	},
	ice_storm = {
		name = "눈보라", school = "ice", kind = "circle", cost = 80, cooldown = 26,
		radius = 56, power = 1.5, delay = 0.25, hits = 4, interval = 0.4, stun = 1.2,
		frost = 1,
		fx = { ring = "ice", ringCount = 8, hit = "iceB" },
		desc = "넓은 둘레에 눈보라가 네 번 몰아쳐 적을 얼린다.",
	},
	plant_bloom = {
		name = "만개", school = "plant", kind = "circle", cost = 80, cooldown = 26,
		radius = 50, power = 3.2, delay = 0.3, stun = 2, selfHeal = 0.25,
		fx = { ring = "plantB", ringCount = 8, hit = "plant" },
		desc = "꽃이 피어 둘레의 적을 묶고, 내 체력을 25% 회복한다.",
	},
	rock_meteor = {
		name = "낙석", school = "rock", kind = "projectile", cost = 85, cooldown = 26,
		range = 110, speed = 150, width = 10, radius = 40, power = 5.5, stun = 1.5,
		fx = { shot = "rockShot", burst = "explosion" },
		desc = "큰 바위를 던진다. 떨어진 자리 둘레가 무너진다.",
	},
	thunder_judge = {
		name = "천벌", school = "thunder", kind = "circle", cost = 85, cooldown = 26,
		radius = 60, power = 1.6, delay = 0.2, hits = 5, interval = 0.3, stun = 0.8,
		fx = { ring = "thunder", ringCount = 6, hit = "thunder" },
		desc = "넓은 둘레에 벼락이 다섯 번 내리친다.",
	},
}

-- ===== 스킬 나무(메이플식 1~4차 — 공방 설계 dino-workshop/js/ninja/design/skills.js를 옮기는 중) =====
--  지금: 1차 · 2차 전직 스킬은 새 설계대로. 3~4차는 옛 인술이 자리를 지킨다(옮기는 대로 바뀐다 — 빙문 4차는 비어 있음).
--  스킬 포인트(SP): 레벨업마다 SP_PER_LEVEL, 전직할 때 SP_ON_JOB — 그 전직 구간에서 얻은 SP는 그 전직 스킬에만 쓴다.
--  스킬마다 마스터 레벨(max). 쓰는 인술은 레벨이 오를수록 피해 · 회복량이 는다(마스터에서 +GROW). 0레벨 = 아직 안 배움.
--  전직하면 그 전직의 주력기와 핵심 장치는 1레벨로 바로 배운다(auto). 배운 쓰는 인술은 단축칸 SLOTS개에 골라 넣는다.
--  두루마리(자기 유파): 지금 전직의 SP를 1 준다.
exports.SP_PER_LEVEL = 3
exports.SP_ON_JOB = 3
exports.GROW = 0.8
exports.SLOTS = 4

-- 1차 새 스킬 — 쓰는 인술
exports.SKILLS.p_seed = {
	name = "가시 씨앗", school = "plant", kind = "seed", cost = 24, cooldown = 3,
	range = 104, speed = 180, width = 7, power = 0.6, fuse = 2, radius = 24, burstPower = 2.0, root = 6,
	fx = { shot = "plantSpike", hit = "plantB", burstHit = "plant" },
	desc = "씨앗을 쏜다. 맞은 적에게 박혀 있다가 2초 뒤 가시로 터진다.",
}
-- 1차 새 스킬 — 핵심 장치(core) · 패시브. kind = "passive"는 쓰는 인술이 아니다(단축칸에 못 넣는다).
--  핵심 장치는 서버 ninjutsuService가 돌린다: 불씨 · 서리 = 몬스터에 쌓임, 생기 · 견고 · 전하 = 내게 쌓임(CoreUpdated로 화면에 보임).
exports.SKILLS.f_ember = {
	name = "불씨", school = "fire", kind = "passive", core = true,
	stacks = 3, seconds = 6, interval = 1, power = 0.10, perLevel = 0.01,
	desc = "불 인술에 맞은 적에게 불씨가 쌓인다(최대 3). 하나마다 1초에 한 번 피해.",
}
exports.SKILLS.f_blade = {
	name = "달궈진 칼날", school = "fire", kind = "passive",
	every = 3, power = 0.2, perLevel = 0.03, ember = 1, fx = { hit = "flam" },
	desc = "기본 공격이 3번째로 맞을 때마다 불꽃이 튀어 추가 피해와 불씨 1.",
}
exports.SKILLS.i_frost = {
	name = "서리", school = "ice", kind = "passive", core = true,
	stacks = 5, seconds = 8, slowPer = 0.1, freeze = 2, perLevel = 0.1,
	desc = "얼음 인술에 맞은 적에게 서리가 쌓인다. 하나마다 느려지고, 5가 되면 얼어붙는다.",
}
exports.SKILLS.i_armor = {
	name = "얼음 갑옷", school = "ice", kind = "passive",
	perLevel = 0.01, frost = 1,
	desc = "받는 피해가 줄고, 나를 때린 적에게 서리 1.",
}
exports.SKILLS.p_vigor = {
	name = "생기", school = "plant", kind = "passive", core = true,
	stacks = 100, perHit = 6, perLevel = 0.4,
	desc = "풀 인술이 맞을 때마다 생기가 쌓인다(최대 100). 회복 인술은 생기를 쓴다.",
}
exports.SKILLS.r_firm = {
	name = "견고", school = "rock", kind = "passive", core = true,
	stacks = 5, seconds = 8, reduce = 0.04, perLevel = 0.002, guardGain = 2,
	desc = "맞을 때마다 견고가 쌓인다(최대 5). 하나마다 받는 피해가 줄어든다.",
}
exports.SKILLS.t_charge = {
	name = "전하", school = "thunder", kind = "passive", core = true,
	stacks = 10, seconds = 3, speedPer = 0.02, perLevel = 0.001,
	desc = "공격이 맞을 때마다 전하가 쌓인다(최대 10). 하나마다 공격이 빨라진다.",
}
exports.SKILLS.t_static = {
	name = "정전기", school = "thunder", kind = "passive",
	every = 4, power = 0.4, perLevel = 0.04, fx = { hit = "thunder" },
	desc = "기본 공격이 4번째로 맞을 때마다 작은 번개가 한 번 더 친다.",
}
-- 공용(전 유파)
exports.SKILLS.c_mastery = {
	name = "무기 단련", school = "", kind = "passive",
	perLevel = 0.015,
	desc = "무기를 다루는 솜씨. 공격력이 오른다.",
}
exports.SKILLS.c_energy = {
	name = "기력 단련", school = "", kind = "passive",
	maxPerLevel = 4, regenPerLevel = 0.2,
	desc = "최대 기력과 기력 회복이 는다.",
}

-- ===== 2차 스킬(공방 설계 그대로 — 유파마다 주력기 · 터뜨리기/제어 · 설치 · 버프 · 패시브) =====
--  새 종류: zone(설치 — offset 앞에 seconds초, interval마다 radius 안에 효과. heal = 안의 아군 회복, once = 처음 닿을 때 한 번, limit = 둘 수 있는 수)
--   · buff(나와 radius 안 아군에게 seconds초: attack 공격력 + · haste 걸음/공격 속도 + · regen 2초마다 회복)
--   · detonate(내 불씨가 걸린 적이 불씨 수만큼 터짐, spread 안의 적에게 불씨) · shatter(얼어붙은 적 = 깨짐 mult배 + 조각 shard, 아니면 서리)
--   · discharge(전하를 다 써서 반경 radius + radiusPer×전하, 피해 power + powerPer×전하) · decoy(나를 쫓던 적이 seconds초 놓침 → 서리)
--   · counter(window초 안에 맞으면 피해 없이 radius에 충격파 + 견고 가득)
--  line의 덧붙임: hits · interval(여러 번) · follow(그때그때 내 자리에서) · segments · segDelay · falloff(나눠서 차례로 터짐) · pull(끌어당김)
--  projectile의 덧붙임: shots · shotGap(연달아) · single(한 마리만) · mark(표식 — 표식 있는 적을 다시 맞히면 번개 power) · firmBonus(견고 하나마다 피해 +, 다 씀)
-- 불
exports.SKILLS.f_breath = {
	name = "화염 방사", school = "fire", kind = "line", cost = 34, cooldown = 5,
	length = 56, width = 14, power = 0.9, delay = 0.15, hits = 4, interval = 0.4, follow = true, ember = 1,
	fx = { row = "flam", rowCount = 4, rowRepeat = 4, hit = "flam" },
	desc = "앞으로 불길을 1.6초 동안 뿜는다. 네 번 태우고 불씨가 쌓인다.",
}
exports.SKILLS.f_ignite = {
	name = "점화", school = "fire", kind = "detonate", cost = 30, cooldown = 8,
	radius = 130, power = 1.0, spread = 30, spreadEmber = 1,
	fx = { self = "spark", hit = "explosion" },
	desc = "불씨가 걸린 적이 모두 터진다. 불씨 수만큼 세고, 옆의 적에게 불씨가 옮겨붙는다.",
}
exports.SKILLS.f_pillar = {
	name = "불기둥", school = "fire", kind = "zone", cost = 36, cooldown = 10,
	offset = 28, radius = 20, seconds = 6, interval = 0.5, power = 0.35, ember = 1, limit = 2,
	fx = { zone = "firePillar", hit = "flam" },
	desc = "앞에 불기둥이 6초 동안 선다. 가까운 적을 계속 태우고 불씨를 붙인다. 2개까지.",
}
exports.SKILLS.f_heat = {
	name = "열기", school = "fire", kind = "buff", cost = 30, cooldown = 60,
	radius = 70, seconds = 120, buff = { attack = 0.08, attackPerLevel = 0.012 },
	fx = { self = "aura" },
	desc = "120초 동안 나와 가까운 파티원의 공격력이 오른다.",
}
exports.SKILLS.f_drain = {
	name = "타오르는 마음", school = "fire", kind = "passive",
	base = 0.01, perLevel = 0.004, cap = 5,
	desc = "내 불씨가 걸린 적 하나마다 인술 피해가 는다(5마리까지).",
}
-- 얼음
exports.SKILLS.i_shatter = {
	name = "깨뜨리기", school = "ice", kind = "shatter", cost = 40, cooldown = 9,
	radius = 44, power = 1.2, delay = 0.2, frost = 2, shatter = { mult = 3, shard = 0.8, shardRadius = 34 },
	fx = { ring = "iceFlake", ringCount = 6, hit = "iceB" },
	desc = "둘레에 냉기를 터뜨린다. 얼어붙은 적은 깨져 큰 피해를 받고 조각이 옆으로 튄다. 아니면 서리 2.",
}
exports.SKILLS.i_wall = {
	name = "얼음 벽", school = "ice", kind = "zone", cost = 30, cooldown = 12,
	offset = 24, radius = 16, seconds = 5, interval = 0.5, stun = 0.6, limit = 1,
	fx = { zone = "ice" },
	desc = "앞에 얼음 벽이 5초 동안 선다. 닿은 적은 멈춰 선다.",
}
exports.SKILLS.i_decoy = {
	name = "얼음 분신", school = "ice", kind = "decoy", cost = 26, cooldown = 14,
	radius = 50, seconds = 2, frost = 2,
	fx = { burst = "smoke", ring = "iceFlake", ringCount = 3 },
	desc = "얼음 분신을 남긴다. 나를 쫓던 적이 2초 동안 나를 놓치고, 분신이 깨지며 서리 2.",
}
exports.SKILLS.i_cold = {
	name = "차가운 피", school = "ice", kind = "passive",
	perLevel = 0.03,
	desc = "서리가 걸렸거나 얼어붙은 적에게 인술 피해가 는다.",
}
-- 풀
exports.SKILLS.p_whip = {
	name = "덩굴 채찍", school = "plant", kind = "line", cost = 26, cooldown = 3.5,
	length = 48, width = 24, power = 1.9, delay = 0.15, pull = 20,
	fx = { front = "arc", hit = "plantB" },
	desc = "긴 덩굴을 크게 휘두른다. 맞은 적을 내 쪽으로 끌어당긴다.",
}
exports.SKILLS.p_flower = {
	name = "치유꽃", school = "plant", kind = "zone", cost = 40, cooldown = 15,
	offset = 0, radius = 34, seconds = 20, interval = 1, heal = 0.02, limit = 2,
	fx = { zone = "flower" },
	desc = "꽃을 심는다. 20초 동안 가까운 아군이 조금씩 회복한다. 2송이까지.",
}
exports.SKILLS.p_root = {
	name = "뿌리 내림", school = "plant", kind = "passive",
	vigorPerLevel = 0.1, reducePerLevel = 0.02,
	desc = "뿌리 표식이 있는 적을 치면 생기가 더 쌓이고, 그 적에게 받는 피해가 준다.",
}
exports.SKILLS.p_breath = {
	name = "숲의 숨결", school = "plant", kind = "buff", cost = 30, cooldown = 60,
	radius = 70, seconds = 120, buff = { regen = 0.01 },
	fx = { self = "boost" },
	desc = "120초 동안 나와 가까운 파티원이 조금씩 회복한다.",
}
-- 바위
exports.SKILLS.r_crack = {
	name = "지면 강타", school = "rock", kind = "line", cost = 30, cooldown = 4.5,
	length = 72, width = 12, power = 1.5, delay = 0.15, segments = 3, segDelay = 0.22, falloff = 0.85,
	fx = { row = "rockSpike", rowCount = 3, rowGap = 0.22 },
	desc = "땅을 내리치면 균열이 앞으로 세 번 이어서 터진다. 멀수록 약하다.",
}
exports.SKILLS.r_counter = {
	name = "되받아치기", school = "rock", kind = "counter", cost = 20, cooldown = 8,
	window = 0.6, radius = 36, power = 2.2,
	fx = { self = "shield", loop = true, hit = "hit_circle" },
	desc = "잠깐 막는 자세. 그 사이에 맞으면 피해 없이 충격파로 되받아치고 견고가 가득 찬다.",
}
exports.SKILLS.r_throw = {
	name = "바위 던지기", school = "rock", kind = "projectile", cost = 34, cooldown = 7,
	range = 110, speed = 170, width = 9, radius = 26, power = 2.0, stun = 1, firmBonus = 0.15,
	fx = { shot = "rockShot", burst = "rockBurst" },
	desc = "바위를 던진다. 떨어진 자리의 적이 멈춘다. 견고를 다 써서 더 세게 던진다.",
}
exports.SKILLS.r_stomp = {
	name = "발 구르기", school = "rock", kind = "circle", cost = 28, cooldown = 9,
	radius = 38, power = 1.2, delay = 0.15, stun = 1, firmGain = 1,
	fx = { burst = "dustRing", ring = "rockBits", ringCount = 6 },
	desc = "발을 굴러 둘레의 적을 띄워 멈추게 한다. 견고 1을 얻는다.",
}
exports.SKILLS.r_heavy = {
	name = "무거운 몸", school = "rock", kind = "passive",
	perLevel = 0.01,
	desc = "받는 피해가 줄어든다.",
}
-- 번개
exports.SKILLS.t_star = {
	name = "뇌전 수리검", school = "thunder", kind = "projectile", cost = 26, cooldown = 3,
	range = 110, speed = 260, width = 7, radius = 0, power = 0.8, shots = 3, shotGap = 0.12, single = true,
	mark = { seconds = 5, power = 1.0 },
	fx = { shot = "shurikenMagic", hit = "spark", markHit = "thunder" },
	desc = "번개 두른 수리검 셋을 연달아 던진다. 표식이 붙은 적을 다시 맞히면 번개가 떨어진다.",
}
exports.SKILLS.t_discharge = {
	name = "방전", school = "thunder", kind = "discharge", cost = 20, cooldown = 8,
	radius = 26, radiusPer = 3, power = 0.6, powerPer = 0.22, delay = 0.1,
	fx = { burst = "circleSpark", hit = "thunder" },
	desc = "전하를 모두 써서 둘레에 번개를 쏟는다. 전하가 많을수록 넓고 세다.",
}
exports.SKILLS.t_trap = {
	name = "번개 덫", school = "thunder", kind = "zone", cost = 24, cooldown = 6,
	offset = 20, radius = 20, seconds = 20, interval = 0.25, power = 0.8, stun = 1.5, once = true, limit = 3,
	fx = { zone = "circleSpark2", flat = true, hit = "thunder" },
	desc = "덫을 놓는다. 밟은 적과 그 둘레가 감전되어 멈춘다. 3개까지.",
}
exports.SKILLS.t_haste = {
	name = "질풍", school = "thunder", kind = "buff", cost = 30, cooldown = 60,
	radius = 70, seconds = 180, buff = { haste = 0.10, hastePerLevel = 0.008 },
	fx = { self = "boost" },
	desc = "180초 동안 나와 가까운 파티원의 걸음과 공격이 빨라진다.",
}
exports.SKILLS.t_shock = {
	name = "감전", school = "thunder", kind = "passive",
	seconds = 5, base = 0.02, perLevel = 0.01,
	desc = "내 번개에 맞은 적은 5초 동안 내 인술에 더 아프다.",
}

-- 유파 → 전직(1~4) → 스킬 id. 각 전직의 첫 번째 = 주력기.
exports.TREE = {
	fire = { { "fire_ball", "f_ember", "f_blade" }, { "f_breath", "f_ignite", "f_pillar", "f_heat", "f_drain" }, { "fire_rain" }, { "fire_dragon" } },
	ice = { { "ice_spike", "i_frost", "i_armor" }, { "ice_lance", "i_shatter", "i_wall", "i_decoy", "i_cold" }, { "ice_storm" }, {} },
	plant = { { "p_seed", "p_vigor", "plant_heal" }, { "p_whip", "plant_bind", "p_flower", "p_root", "p_breath" }, { "plant_thorn" }, { "plant_bloom" } },
	rock = { { "rock_spike", "r_firm", "rock_guard" }, { "r_crack", "r_counter", "r_throw", "r_stomp", "r_heavy" }, { "rock_quake" }, { "rock_meteor" } },
	thunder = { { "thunder_bolt", "t_charge", "t_static" }, { "t_star", "t_discharge", "t_trap", "t_haste", "t_shock" }, { "thunder_chain", "thunder_storm" }, { "thunder_judge" } },
}
exports.COMMON = { { "c_mastery", "c_energy" }, {}, {}, {} }
-- 마스터 레벨(없으면 전직별 기본: 1차 20 · 2차 15 · 3차 20 · 4차 30)
local MAX = {
	f_ember = 10, f_blade = 10, i_frost = 10, i_armor = 10, p_vigor = 10, plant_heal = 10, r_firm = 10, rock_guard = 10,
	t_charge = 10, t_static = 10, c_mastery = 10, c_energy = 5,
	f_breath = 20, f_ignite = 15, f_pillar = 10, f_heat = 10, f_drain = 10,
	ice_lance = 20, i_shatter = 15, i_wall = 10, i_decoy = 10, i_cold = 10,
	p_whip = 20, plant_bind = 15, p_flower = 10, p_root = 10, p_breath = 10,
	r_crack = 20, r_counter = 15, r_throw = 10, r_stomp = 10, r_heavy = 10,
	t_star = 20, t_discharge = 15, t_trap = 10, t_haste = 10, t_shock = 10,
}
local JOB_MAX = { 20, 15, 20, 30 }
local jobOf = {}
for _, jobs in exports.TREE do
	for job, list in jobs do
		for _, id in list do
			jobOf[id] = job
		end
	end
end
for job, list in exports.COMMON do
	for _, id in list do
		jobOf[id] = job
	end
end

function exports.JobOf(id: string): number?
	return jobOf[id]
end

function exports.MaxOf(id: string): number
	return MAX[id] or JOB_MAX[jobOf[id] or 1]
end

function exports.IsActive(id: string): boolean
	local s = exports.SKILLS[id]
	return s ~= nil and s.kind ~= "passive"
end

-- 그 유파 · 전직의 스킬 목록(고유 + 공용)
function exports.TreeFor(school: string?, job: number): { string }
	local out = {}
	for _, id in (exports.TREE[school or ""] or {})[job] or {} do
		table.insert(out, id)
	end
	for _, id in exports.COMMON[job] or {} do
		table.insert(out, id)
	end
	return out
end

-- 전직하면 바로 1레벨로 배우는 것: 그 전직의 주력기(첫 번째) + 핵심 장치
function exports.AutoFor(school: string?, job: number): { string }
	local out = {}
	for i, id in (exports.TREE[school or ""] or {})[job] or {} do
		if i == 1 or exports.SKILLS[id].core then
			table.insert(out, id)
		end
	end
	return out
end

-- 그 유파 스킬인가(공용 포함)
function exports.Belongs(id: string, school: string?): boolean
	local s = exports.SKILLS[id]
	return s ~= nil and jobOf[id] ~= nil and (s.school == "" or s.school == school)
end

-- 스킬 레벨 보정(피해 · 회복량): 1레벨 = 1, 마스터 = 1 + GROW
function exports.Scale(id: string, level: number?): number
	local max = exports.MaxOf(id)
	local l = math.clamp(level or 1, 1, max)
	return if max <= 1 then 1 else 1 + (l - 1) * exports.GROW / (max - 1)
end

-- 레벨업 SP: 전직한 뒤로는 레벨이 오를 때마다 지금 전직에 SP_PER_LEVEL(progressionService가 부른다). 받았으면 true
function exports.GrantLevelSp(data, gained: number): boolean
	local job = data.Job or 0
	if gained <= 0 or job < 1 then
		return false
	end
	if typeof(data.SP) ~= "table" then
		data.SP = { 0, 0, 0, 0 }
	end
	data.SP[job] = (data.SP[job] or 0) + gained * exports.SP_PER_LEVEL
	return true
end

-- 그 레벨까지 그 전직 구간에서 얻는 SP(전직할 때 SP_ON_JOB + 구간 안에서 오른 레벨 × SP_PER_LEVEL)
function exports.SpEarned(job: number, level: number): number
	local from = exports.JOB_LEVELS[job]
	if not from or level < from then
		return 0
	end
	local to = (exports.JOB_LEVELS[job + 1] or math.huge) - 1
	return exports.SP_ON_JOB + (math.min(level, to) - from) * exports.SP_PER_LEVEL
end

-- 유파 번호(0부터 — 캐릭터 시트 줄). 유파가 없으면(아직 안 고름) 0.
-- 그 사람의 대쉬 id("novice" = 견습 구르기)와 정의
function exports.DashFor(school: string?, job: number?): (string, any)
	local id = if (job or 0) >= 1 and exports.DASH[school or ""] then school :: string else "novice"
	return id, exports.DASH[id]
end

function exports.SchoolIndex(school: string?): number
	local i = table.find(exports.SCHOOLS, school or "")
	return if i then i - 1 else 0
end

-- 그 유파의 칸(1~4 = n차 전직 인술)에 들어가는 인술 id
function exports.SkillFor(school: string?, slot: number): string?
	local info = exports.SCHOOL_INFO[school or ""]
	return info and info.skills[slot]
end

-- 그 레벨에서 할 수 있는 전직 단계(0~4)
function exports.JobFor(level: number): number
	local job = 0
	for i, need in exports.JOB_LEVELS do
		if level >= need then
			job = i
		end
	end
	return job
end

-- 단계 보정(1단계 = 1.0)
function exports.LevelScale(level: number?): number
	return 1 + (math.clamp(level or 1, 1, exports.MAX_LEVEL) - 1) * exports.LEVEL_BONUS
end

-- 저장 데이터(data.Ninjutsu = { [인술 id] = 단계 })에서 그 인술 단계(없으면 1)
function exports.LevelOf(levels, id: string): number
	local level = levels and levels[id]
	return if typeof(level) == "number" then math.clamp(math.floor(level), 0, exports.MaxOf(id)) else 0
end

return exports

end
MODULES['ReplicatedStorage/shared/config/npcTalk'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- NPC 대사 — 역할(공방 js/npc.js의 id)마다 한 마디(또는 여러 마디 목록 — 말 걸 때마다 무작위). 줄바꿈은 \n. 여기서 자유롭게 고친다.
-- (상점·수리·창고 같은 실제 기능은 아직 없어서 "곧 열린다"고 안내한다.)
return {
	RANGE = 30, -- 플레이어 발과 NPC 발 사이가 이 거리(도트) 안이면 말을 걸 수 있다(계산대 너머에서도 닿게)
	LINES = {
		blacksmith = "어서 와! 좋은 칼은 좋은 쇠에서 나오지.\n주괴를 모아 오면 무기를 강화해 주마. 곧 문을 열 거야.",
		potion = "보글보글~ 오늘 끓인 물약이 아주 잘 됐어요!", -- (포션상은 말을 걸면 가게 창이 열려서 지금은 안 쓰임)
		repair = "장비가 망가졌어? 내가 뚝딱 고쳐 줄게!\n수리는 곧 시작할 거야.",
		merchant = "수리검, 쿠나이, 폭탄!\n닌자에게 필요한 건 다 있어요.",
		healer = "자, 다 나았어요! 몸이 개운하죠?\n다치면 언제든 다시 오세요.", -- 말을 걸면 체력이 가득 찬 뒤 나오는 말
		storage = "짐이 많으면 여기 맡겨 둬.\n창고는 곧 열 거야.",
		elder = "왔느냐, 견습 닌자여.\n마을 남쪽 새싹 들판에서 수련을 쌓고 오너라.",
		-- 일반인: 여러 마디 중 하나를 무작위로
		villagerMan = { "오늘 날씨 참 좋네!", "들판에는 요괴가 많으니 조심하게." },
		villagerOld = { "젊을 땐 나도 이름난 닌자였지.", "수리검은 손목으로 던지는 게야." },
		noble = { "이 마을의 닌자들은 믿음직하구먼." },
		villagerWoman = { "어머, 처음 보는 얼굴이네요!", "저녁은 뭘 만들까~" },
		villagerBoy = { "나도 크면 몬스터 조련사가 될 거야!", "술래잡기 할래?" },
		villagerGirl = { "만두 몬스터 너무 귀엽지 않아?", "안녕! 나랑 친구 할래?" },
		villagerGrandma = { "아이고, 착하기도 하지.", "젊을 땐 나도 모험을 다녔단다." },
		villagerYouth = { "요즘 대장간 칼이 제일 잘 나간대.", "언젠가 이 마을을 떠나 여행할 거야." },
		villagerLady = { "마을 광장 분수 봤어요? 정말 예뻐요.", "꽃집이 생기면 좋겠어요." },
	},
	DEFAULT = "안녕하세요!",
}

end
MODULES['ReplicatedStorage/shared/config/petSkills'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 펫 패시브 스킬(M4) — GAME_DESIGN §2. 공방 js/skills.js와 같은 수치(초안, 사용자 확인 후 조정).
--  플레이어가 공격할 때마다(TownAttack) 함께 다니는 펫마다 발동 판정 → 서버가 피해(주인 기여도에 합산)·회복을 주고,
--  같은 씬 모두에게 PetSkill 연출 이벤트를 보낸다. 종별 스킬·이펙트는 shared/data/petSkills.generated.luau(공방 내보내기).
--  거리 단위는 도트(combat.luau와 같음).
local generated = require(script.Parent.Parent.data["petSkills.generated"])

local exports = {}

-- 패턴: 발동 확률(공격 1번당) · 피해 배율(× 펫 힘)
exports.PATTERNS = {
	bolt = { name = "투사체", proc = 0.30, mult = 1.0 }, -- 가장 가까운 몬스터 한 마리(사거리 BOLT_RANGE)
	burst = { name = "주변 원형", proc = 0.20, mult = 0.7 }, -- 플레이어 둘레 BURST_RADIUS 안 모두
	orbit = { name = "회전", proc = 0.15, mult = 0.35 }, -- ORBIT_TIME초 동안 둘레를 돌며 ORBIT_TICK초마다
	drop = { name = "낙하", proc = 0.20, mult = 1.3 }, -- 방금 맞힌(없으면 가까운) 몬스터 자리에 DROP_DELAY 뒤, 반지름 DROP_RADIUS
	buff = { name = "버프", proc = 0.15, mult = 0 }, -- 플레이어 체력을 최대 체력의 HEAL_RATIO만큼 회복
}

exports.PET_COOLDOWN = 0.8 -- 펫 한 마리가 연달아 쓰지 못하는 시간(초)
exports.HEAL_RATIO = 0.05
exports.BOLT_RANGE = 80
exports.BOLT_FLIGHT = 0.35 -- 날아가는 시간(초) — 도착할 때 피해
exports.BURST_RADIUS = 28
exports.BURST_DELAY = 0.25
exports.ORBIT_TIME = 3
exports.ORBIT_TICK = 0.5
exports.ORBIT_RADIUS = 30 -- 도는 원 반지름(도트) — 이 근처(±ORBIT_BAND)에 있는 몬스터가 맞는다
exports.ORBIT_BAND = 14
exports.DROP_DELAY = 0.4
exports.DROP_RADIUS = 16
exports.DROP_RANGE = 80 -- 맞힌 몬스터가 없을 때 고를 거리

-- 펫 힘 = 4 + 1.2 × 펫 레벨 (Lv1 5 · Lv10 16 · Lv50 64 · Lv100 124)
function exports.Power(level: number): number
	return 4 + 1.2 * level
end

function exports.Damage(pattern: string, level: number): number
	local p = exports.PATTERNS[pattern]
	return if p then math.max(1, math.round(exports.Power(level) * p.mult)) else 0
end

-- 종 id → { name, pattern, ... } (없으면 nil)
function exports.SkillOf(speciesId: string)
	return generated.species[speciesId]
end

exports.generated = generated

return exports

end
MODULES['ReplicatedStorage/shared/config/pets'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 펫(잡은 몬스터) 저장·편성 규칙(클라이언트·서버 공용) — GAME_DESIGN.md §5, §9.
--  저장 형태(playerSchema v4): Pets = { Box = { 개체... }, Party = { 상자 번호... }, Slots = 열린 슬롯 수, Boxes = 가진 박스 수 }
--   개체 = { S = 종 id, L = 레벨(잡은 레벨 그대로 평생 고정), C = 이로치(1) 아니면 0, B = 맺은 방울 등급(1~5), T = 잡은 시각(os.time) }
--   Box는 빈 칸 없는 촘촘한 배열(DataStore 안전) — 박스 화면의 칸 = 배열 순서. Party는 Box 번호 배열(1번 = 대표 펫, 남에게 보이는 한 마리).
--   Paid = 유료로 산 펫 칸 수(0~2). (Slots 필드는 v4 초기값 — 칸 수는 SlotCount로 계산한다)
local exports = {}

exports.BOX_SIZE = 30 -- 박스 1개 칸 수
exports.BOXES_START = 8 -- 처음 가진 박스(240마리)
exports.BOXES_MAX = 20 -- 최대 박스(600마리)
exports.SLOTS_START = 1 -- 처음 열린 펫 슬롯
exports.SLOTS_MAX = 4 -- 최대 펫 슬롯(3·4번째는 유료)
exports.SLOT2_LEVEL = 20 -- 플레이어 레벨 20이 되면 2번째 슬롯 무료
exports.SHINY_CHANCE = 1 / 2048 -- 이로치(색만 다름)

-- 도감 상태(Dex[종 id] 값)
exports.DEX_SEEN = 1 -- 봤음(싸워서 쓰러뜨림)
exports.DEX_CAUGHT = 2 -- 잡았음

-- 함께 다니는 펫 칸 수: 1칸 기본 + 플레이어 Lv20이면 1칸 무료 + 유료로 산 칸(최대 2, Pets.Paid)
function exports.SlotCount(level: number, paid: number?): number
	local n = exports.SLOTS_START + (if level >= exports.SLOT2_LEVEL then 1 else 0) + math.clamp(paid or 0, 0, 2)
	return math.min(n, exports.SLOTS_MAX)
end

function exports.Capacity(boxes: number): number
	return boxes * exports.BOX_SIZE
end

return exports

end
MODULES['ReplicatedStorage/shared/config/quests'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 본 줄거리 퀘스트 규칙(서버 · 클라이언트 공용). 퀘스트 자료는 공방 설계(dino-workshop/js/ninja/design/story.js)를
-- 그대로 옮긴 shared/data/quests.generated.luau — 차례대로 하나씩 진행한다.
--  저장: data.Quest = { Index = 지금 퀘스트 번호(1부터, 다 끝내면 COUNT + 1), Accepted = 받았는가, Progress = 처치 수 등 }
--  흐름: 주는 사람에게 말을 걸어 받는다 → 목표를 채운다 → 끝낼 사람(TurnIn)에게 말을 건다.
--        가기 · 탈것은 그 자리에 닿으면 바로 끝난다. 주는 사람 = 말 걸 사람인 "말 걸기"는 받자마자 끝난다.
local list = require(script.Parent.Parent.data["quests.generated"])

local exports = {}

exports.LIST = list
exports.COUNT = #list

function exports.Get(index: number)
	return list[index]
end

-- 끝내러 갈 NPC 키(nil = 닿으면 바로 끝남)
function exports.TurnIn(q): string?
	if q.kind == "reach" or q.kind == "ride" then
		return nil
	end
	return if q.kind == "talk" then q.target else q.giver
end

-- 받자마자 끝나는가
function exports.Instant(q): boolean
	return q.kind == "talk" and q.target == q.giver
end

-- 처치 수를 세는 퀘스트인가(몬스터 · 보스 id = q.target)
function exports.CountsKill(q, speciesId: string): boolean
	return (q.kind == "kill" or q.kind == "boss") and q.target == speciesId
end

-- 목표를 채웠는가. have = 가진 개수(모으기), job = 전직 단계
function exports.Ready(q, progress: number, have: number, job: number): boolean
	if q.kind == "kill" or q.kind == "boss" then
		return progress >= q.count
	elseif q.kind == "collect" then
		return have >= q.count
	elseif q.kind == "job" then
		return job >= (tonumber(q.target) or math.huge)
	elseif q.kind == "talk" then
		return true
	end
	return progress >= 1
end

-- 추적창에 쓰는 한 줄
function exports.Objective(q, accepted: boolean, progress: number, have: number, job: number, level: number): string
	if not accepted then
		if level < q.level then
			return ("Lv.%d부터 · %s"):format(q.level, q.giverName)
		end
		return q.giverName .. "에게 가기"
	end
	if q.kind == "talk" then
		return q.targetName .. "에게 가기"
	elseif q.kind == "reach" then
		return q.targetName .. " 가기"
	elseif q.kind == "ride" then
		return q.targetName .. " 타기"
	end
	if exports.Ready(q, progress, have, job) then
		return q.giverName .. "에게 돌아가기"
	end
	if q.kind == "job" then
		return q.targetName .. " 하기"
	end
	local n = if q.kind == "collect" then have else progress
	return ("%s %d/%d"):format(q.targetName, math.min(n, q.count), q.count)
end

-- 보상 아이템 id("SchoolScroll" = 내 유파의 두루마리. 유파가 없으면 nil)
local SCROLL = { fire = "ScrollFire", ice = "ScrollIce", plant = "ScrollPlant", rock = "ScrollRock", thunder = "ScrollThunder" }
function exports.RewardItem(q, school: string?): string?
	if q.item == "SchoolScroll" then
		return SCROLL[school or ""]
	end
	return q.item
end

return exports

end
MODULES['ReplicatedStorage/shared/config/rewards'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 몬스터 처치 보상 규칙(서버) — GAME_DESIGN.md §3.
--  기여도 = 그 몬스터에 넣은 피해 ÷ 최대 체력(펫 피해 포함 — M4부터). 개인 기준(파티 합산 없음), 씬이 바뀌면 사라진다.
--  기여도 CONTRIB_MIN 이상인 사람 모두 경험치·골드·재료를 받는다. 딜 1등(동점이면 먼저 때린 사람)은 M2부터 [포획 시도]/[재료 받기]를 고른다.
local exports = {}

exports.CONTRIB_MIN = 0.10

-- 재료는 몬스터마다 하나(그 몬스터의 특징이 담긴 아이템 — townWorld species[i].material = "Mat_<종 id>", 공방 js/materials.js)

-- 재료 개수: Lv1~24 = 1개, 25~49 = 2개, … Lv100 = 5개
function exports.MaterialCount(level: number): number
	return 1 + math.floor(level / 25)
end

-- 골드: 레벨 + 3 근처(±30%)
function exports.Gold(level: number, rng: Random): number
	local base = level + 3
	return math.max(1, math.round(base * rng:NextNumber(0.7, 1.3)))
end

return exports

end
MODULES['ReplicatedStorage/shared/config/scenes'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 씬 이름의 "단 하나의 출처". 문자열이 여러 파일에 흩어져 있으면 이름을 바꿀 때 어긋나므로 여기서만 정의한다.
-- 씬은 전부 탑다운 씬이고 공방(js/ninja/maps.js → tools/export_ninja.mjs)이 shared/data/townWorld.generated.luau로 내보낸다.
-- 로블록스 씬 이름은 "town_<씬 키>", 씬 모듈은 전부 client/modules/town을 같이 쓴다.
local townWorld = require(script.Parent.Parent.data.townWorld)

return {
	-- 게임 시작 씬이자 쓰러졌을 때 돌아오는 곳(공방에서 정한 시작 씬 — 닌자 마을).
	TOWN = townWorld.StartSceneName(),
}

end
MODULES['ReplicatedStorage/shared/config/shops'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- NPC 가게 — 가게 id마다: 어느 NPC(공방 js/npc.js 역할 id)에게 말을 걸면 열리는지, 제목, 파는 물건(items.luau id, 값은 Price).
-- 파는 쪽(판매)은 가게와 상관없이 SellPrice가 있는 아이템이면 어디서든 팔 수 있다.
return {
	potion = {
		npc = "potion",
		title = "밥집",
		goods = { "Onigiri", "Sushi", "Yakitori" },
	},
	-- 잡화 상점: 투척 무기(수리검 · 쿠나이 · 폭탄) + 들판 무기(닌자도 · 사이 · 곤봉). 포획 방울은 팔지 않는다(포획 꺼 둠).
	merchant = {
		npc = "merchant",
		title = "잡화 상점",
		goods = { "Shuriken", "Kunai", "Bomb", "Ninjato", "Sai", "Club", "GuardCharm" },
	},
}

end
MODULES['ReplicatedStorage/shared/config/townAssets.generated'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/write_ninja_ids.mjs).
-- 원본 이미지: SpriteDemo/assets/ninja/ (「오문 닌자전」 — Ninja Adventure 팩, CC0)
return {
	OBJECTS = "rbxassetid://116867253795408",
	MONSTERS = "rbxassetid://134523042922733",
	MONSTER_SHEETS = { "rbxassetid://134523042922733" }, -- 몬스터 66종이 한 장에 들어 있다
	PLAYER = "rbxassetid://78471859808863",
	NPCS = "rbxassetid://111577531997651",
	ITEMS = "rbxassetid://81901429550263", -- 아이템 아이콘 시트(shared/data/itemIcons.generated.luau)
	FX = "rbxassetid://98901275850125", -- 인술 · 맞음 이펙트 시트(shared/data/ninjaFx.generated.luau)
	UI = "rbxassetid://100142829399672", -- UI 키트 아틀라스(shared/data/uiKit.generated.luau, tools/export_ninja_ui.mjs)
	-- 도트 글꼴 글자판(shared/data/pixelFont.generated.luau, tools/export_ninja_font.mjs)
	FONT = {
		body = { "rbxassetid://86254954369011", "rbxassetid://74815922164131" },
		title = { "rbxassetid://134390545966158", "rbxassetid://131806650250169", "rbxassetid://124307610648212", "rbxassetid://103155499437491" },
	},
	GROUNDS = {
		village = "rbxassetid://118988897104438", -- 닌자 마을
		field1 = "rbxassetid://137687022207213", -- 새싹 들판 1
		field2 = "rbxassetid://115125289318889", -- 새싹 들판 2
		field3 = "rbxassetid://121926389256231", -- 새싹 들판 3
		hill1 = "rbxassetid://112754327978342", -- 나비 언덕 1
		hill2 = "rbxassetid://74468023793636", -- 나비 언덕 2
		hill3 = "rbxassetid://136155507364311", -- 나비 언덕 3
		pond = "rbxassetid://125057394654328", -- 큰 웅덩이
	},
}

end
MODULES['ReplicatedStorage/shared/config/townAssets'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 탑다운 씬 이미지 에셋 + 화면 배율.
-- 원본 이미지: SpriteDemo/assets/bunvillage/*.png — 에셋 공방(C:/YJS/Roblox/dino-workshop)의
-- tools/export_roblox.mjs가 만들고, 업로드한 id는 tools/write_asset_ids.mjs가 townAssets.generated.luau에 쓴다.
-- 배율(바닥·오브젝트·몬스터·캐릭터)도 공방 규칙(js/world.js)에서 내보낸 값을 그대로 쓴다 — 여기서 따로 고치지 않는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ids = require(script.Parent["townAssets.generated"])
local world = require(ReplicatedStorage.shared.data["townWorld.generated"])

return {
	SCALE = world.scale, -- 바닥 1도트 = 화면 px
	CHAR_SCALE = world.charScale, -- 캐릭터 1도트 = 화면 px
	MONSTER_SCALE = world.monsterScale, -- 몬스터 1도트 = 화면 px
	OBJECTS = ids.OBJECTS, -- 오브젝트 아틀라스
	MONSTERS = ids.MONSTERS, -- 몬스터 시트 1장째(종마다 대기R4 걷기R4 대기L4 걷기L4)
	MONSTER_SHEETS = ids.MONSTER_SHEETS or { ids.MONSTERS }, -- 몬스터 시트 전부(1024px 한계로 여러 장) — townWorld.MonsterSheet(row)로 고른다
	PLAYER = ids.PLAYER, -- 플레이어(줄: 아래·위·왼·오, 칸: 걷기4 + 공격4)
	NPCS = ids.NPCS, -- NPC 시트(역할마다 한 줄, 대기 2장)
	UI = ids.UI or "", -- UI 키트 아틀라스(shared/data/uiKit.generated.luau)
	FX = ids.FX or "", -- 인술 이펙트 시트(shared/data/ninjaFx.generated.luau) — 업로드 전이면 빈 글자(이펙트를 안 그림)
	GROUNDS = ids.GROUNDS, -- 씬 키 → 바닥 이미지
}

end
MODULES['ReplicatedStorage/shared/config/weapons'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 무기 종류와 강화(「오문 닌자전」 NINJA_DESIGN.md §7) — 수치는 전부 여기서 고친다. 클라이언트·서버 공용.
--  무기 아이템은 shared/data/ninjaWeapons.luau(Class = 아래 CLASSES의 키, Level = 쓸 수 있는 레벨, Attack = 공격력).
--  종류마다 기본 공격의 범위·빠르기·세기가 다르다:
--   reach = 앞으로 닿는 거리(도트) · width = 옆 폭(도트) · speed = 공격 시간 배율(작을수록 빠름) · power = 기본 공격 피해 배율
--   (power는 기본 공격에만 — 투척 무기·인술은 공격력 그대로 쓴다)
--   hitFx = 맞은 몬스터 위에 나오는 팩 이펙트(shared/data/ninjaFx.generated.luau의 이름 — 팩 FX/Attack)
--  강화(대장간 NPC 곁에서): +1 ~ +MAX. 한 단계마다 무기 공격력의 BONUS만큼(최소 +1) 오른다.
--   재료 = 그 무기 레벨대의 주괴 × 목표 단계 + 엽전. 실패하면 재료·엽전만 없어지고 단계는 그대로(깨지지 않는다).
local combat = require(script.Parent.combat)

local exports = {}

exports.CLASSES = {
	sword = { name = "도검", reach = 20, width = 22, speed = 1.0, power = 1.0, hitFx = "hit_slash", desc = "빠르기와 범위가 고른 무기." },
	dual = { name = "쌍수", reach = 16, width = 18, speed = 0.7, power = 0.8, hitFx = "hit_cut2", desc = "짧지만 아주 빠르다." },
	heavy = { name = "대형", reach = 24, width = 30, speed = 1.45, power = 1.6, hitFx = "hit_cutx", desc = "느리지만 넓고 세다." },
	polearm = { name = "장병기", reach = 36, width = 12, speed = 1.1, power = 1.1, hitFx = "hit_cut", desc = "멀리 곧게 찌른다." },
	whip = { name = "채찍", reach = 30, width = 36, speed = 1.25, power = 0.95, hitFx = "hit_circle", desc = "넓게 휘둘러 여럿을 친다." },
}
-- 맨손(무기 없음) · 종류가 없는 옛 무기
exports.UNARMED = { name = "맨손", reach = combat.ATTACK_REACH, width = combat.ATTACK_WIDTH, speed = 1, power = 1, hitFx = "hit_claw" }
exports.THROW_HIT_FX = "hit_cut" -- 투척 무기에 맞았을 때

-- 무기 정의(items.luau의 한 줄) → 종류 수치
function exports.ClassOf(def)
	return (def and exports.CLASSES[def.Class or ""]) or exports.UNARMED
end

-- ---- 강화 ----
exports.MAX_PLUS = 10
exports.BONUS = 0.08
exports.RATE = { 1, 1, 1, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2 } -- [목표 단계] = 성공 확률
exports.UPGRADE_NPC = "blacksmith"
-- 무기 레벨 → 강화에 쓰는 주괴(위에서부터, 무기 레벨이 under보다 낮으면 그 주괴)
exports.BARS = {
	{ under = 20, item = "CopperBar" },
	{ under = 45, item = "IronBar" },
	{ under = 60, item = "SilverBar" },
	{ under = 90, item = "GoldBar" },
	{ under = math.huge, item = "MithrilBar" },
}

-- 강화 +plus가 더해 주는 공격력
function exports.Bonus(def, plus: number?): number
	local n = math.clamp(plus or 0, 0, exports.MAX_PLUS)
	if n <= 0 or not def or not def.Attack then
		return 0
	end
	return math.max(n, math.round(def.Attack * exports.BONUS * n))
end

-- 목표 단계(지금 +1)로 올리는 값: { bar = 주괴 아이템 id, bars = 개수, gold = 엽전, rate = 성공 확률 } — 더 못 올리면 nil
function exports.Cost(def, target: number)
	if not def or not def.Attack or target < 1 or target > exports.MAX_PLUS then
		return nil
	end
	local bar = exports.BARS[#exports.BARS].item
	for _, b in exports.BARS do
		if (def.Level or 1) < b.under then
			bar = b.item
			break
		end
	end
	return { bar = bar, bars = target, gold = math.round((20 + def.Attack * 4) * target), rate = exports.RATE[target] }
end

return exports

end
MODULES['ReplicatedStorage/shared/data/itemIcons.generated'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/export_ninja.mjs, 목록 js/ninja/pack.js ITEM_ICONS).
-- 팩 아이템 아이콘 시트(assets/ninja/items.png, 에셋 id = townAssets.generated의 ITEMS) 안 위치.
-- 도트 UI(client/modules/ui/pixelUI.luau)가 도트 UI 키트 부품과 같은 이름 규칙(icon_<이름>)으로 찾는다 — items.luau KitIcon = "nj_<키>".
return {
	rects = {
		icon_nj_shuriken = { x = 0, y = 0, w = 16, h = 16 },
		icon_nj_kunai = { x = 16, y = 0, w = 16, h = 16 },
		icon_nj_bomb = { x = 32, y = 0, w = 16, h = 16 },
		icon_nj_caltrop = { x = 48, y = 0, w = 16, h = 16 },
		icon_nj_onigiri = { x = 64, y = 0, w = 16, h = 16 },
		icon_nj_sushi = { x = 80, y = 0, w = 16, h = 16 },
		icon_nj_yakitori = { x = 96, y = 0, w = 16, h = 16 },
		icon_nj_noodle = { x = 112, y = 0, w = 16, h = 16 },
		icon_nj_meat = { x = 128, y = 0, w = 16, h = 16 },
		icon_nj_fish = { x = 144, y = 0, w = 16, h = 16 },
		icon_nj_branch = { x = 160, y = 0, w = 16, h = 16 },
		icon_nj_grass = { x = 176, y = 0, w = 16, h = 16 },
		icon_nj_rock = { x = 192, y = 0, w = 16, h = 16 },
		icon_nj_feather = { x = 208, y = 0, w = 16, h = 16 },
		icon_nj_bar_copper = { x = 224, y = 0, w = 16, h = 16 },
		icon_nj_bar_iron = { x = 240, y = 0, w = 16, h = 16 },
		icon_nj_bar_silver = { x = 0, y = 16, w = 16, h = 16 },
		icon_nj_bar_gold = { x = 16, y = 16, w = 16, h = 16 },
		icon_nj_bar_mithril = { x = 32, y = 16, w = 16, h = 16 },
		icon_nj_gem_green = { x = 48, y = 16, w = 16, h = 16 },
		icon_nj_gem_red = { x = 64, y = 16, w = 16, h = 16 },
		icon_nj_gem_yellow = { x = 80, y = 16, w = 16, h = 16 },
		icon_nj_gem_purple = { x = 96, y = 16, w = 16, h = 16 },
		icon_nj_pot_life = { x = 112, y = 16, w = 16, h = 16 },
		icon_nj_pot_milk = { x = 128, y = 16, w = 16, h = 16 },
		icon_nj_pot_water = { x = 144, y = 16, w = 16, h = 16 },
		icon_nj_medipack = { x = 160, y = 16, w = 16, h = 16 },
		icon_nj_coin_gold = { x = 176, y = 16, w = 16, h = 16 },
		icon_nj_coin_silver = { x = 192, y = 16, w = 16, h = 16 },
		icon_nj_scroll = { x = 208, y = 16, w = 16, h = 16 },
		icon_nj_scroll_fire = { x = 224, y = 16, w = 16, h = 16 },
		icon_nj_scroll_ice = { x = 240, y = 16, w = 16, h = 16 },
		icon_nj_scroll_plant = { x = 0, y = 32, w = 16, h = 16 },
		icon_nj_scroll_rock = { x = 16, y = 32, w = 16, h = 16 },
		icon_nj_scroll_thunder = { x = 32, y = 32, w = 16, h = 16 },
		icon_nj_katana = { x = 48, y = 32, w = 16, h = 16 },
		icon_nj_sword = { x = 64, y = 32, w = 16, h = 16 },
		icon_nj_ninjaku = { x = 80, y = 32, w = 16, h = 16 },
		icon_nj_sai = { x = 96, y = 32, w = 16, h = 16 },
		icon_nj_bigsword = { x = 112, y = 32, w = 16, h = 16 },
		icon_nj_club = { x = 128, y = 32, w = 16, h = 16 },
		icon_nj_lance = { x = 144, y = 32, w = 16, h = 16 },
		icon_nj_whip = { x = 160, y = 32, w = 16, h = 16 },
		icon_nj_axe = { x = 176, y = 32, w = 16, h = 16 },
		icon_nj_fork = { x = 192, y = 32, w = 16, h = 16 },
		icon_nj_sword2 = { x = 208, y = 32, w = 16, h = 16 },
		icon_nj_hammer = { x = 224, y = 32, w = 16, h = 16 },
		icon_nj_rapier = { x = 240, y = 32, w = 16, h = 16 },
		icon_nj_lance2 = { x = 0, y = 48, w = 16, h = 16 },
		icon_nj_charm1 = { x = 16, y = 48, w = 16, h = 16 },
		icon_nj_charm2 = { x = 32, y = 48, w = 16, h = 16 },
		icon_nj_charm3 = { x = 48, y = 48, w = 16, h = 16 },
	},
}

end
MODULES['ReplicatedStorage/shared/data/items'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 아이템 마스터 데이터(정적 표). 인벤토리에는 { Tab, Slot, ItemId, Count, Plus? }만 저장하고, 이름/설명/최대 스택 같은 정적
-- 정보는 항상 이 표에서 ItemId로 조회한다(저장 데이터가 커지지 않고, 표를 고치면 기존 아이템에도 바로 반영됨).
-- 「오문 닌자전」: 아이템은 전부 Ninja Adventure 팩 그림을 쓴다 — 실제 정의는 두 파일에 있고 여기서 합친다.
--   shared/data/ninjaItems.luau   투척 무기 · 음식 · 인술 두루마리 · 부적 · 재료
--   shared/data/ninjaWeapons.luau 무기(종류 · 레벨 · 공격력)
-- (예전 포획 게임의 나무 검 · 잎사귀 갑옷 · 물약 · 방울 · 몬스터 재료는 없앴다. 옛 저장 데이터는 playerSchema v10이 바꿔 준다.)
--
-- 공통 항목: Name · Description · Tab(가방 탭 "Equip" 장비 / "Use" 소비 / "Etc" 기타 / "Cash" 캐시 / "Key" 중요 — 탭마다 칸이 따로) ·
--  Type · StackMax · Price(가게에서 살 때 값, 없으면 안 판다) · SellPrice(가게에 팔 때 값, 없으면 못 판다) ·
--  KitIcon(팩 아이템 아이콘 이름 "nj_<키>" — shared/data/itemIcons.generated.luau) · EquipSlot(착용 칸 "Weapon" / "Armor"(부적)) ·
--  Heal(먹으면 체력 회복) · Throw(투척 무기 수치) · NoDrop(버릴 수 없음)
local items = {}

for id, def in require(script.Parent.ninjaItems) do
	items[id] = def
end
for id, def in require(script.Parent.ninjaWeapons) do
	items[id] = def
end

return items

end
MODULES['ReplicatedStorage/shared/data/ninjaFx.generated'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/export_ninja.mjs, 목록 js/ninja/pack.js FX_SHEETS).
-- 팩 인술 이펙트 시트(assets/ninja/fx.png, 에셋 id = townAssets.generated의 FX) 안 위치: 이름 → 첫 장 자리(x, y) · 한 장 크기(w, h) · 장수(가로로 이어짐).
return {
	frameTime = 0.07, -- 한 장에 걸리는 시간(초)
	rects = {
		explosion = { x = 0, y = 0, w = 40, h = 40, frames = 9 },
		flam = { x = 0, y = 40, w = 25, h = 30, frames = 8 },
		ice = { x = 0, y = 70, w = 32, h = 32, frames = 10 },
		iceB = { x = 0, y = 102, w = 32, h = 32, frames = 9 },
		plant = { x = 0, y = 134, w = 30, h = 28, frames = 8 },
		plantB = { x = 0, y = 162, w = 30, h = 26, frames = 7 },
		rockSpike = { x = 0, y = 188, w = 54, h = 48, frames = 10 },
		thunder = { x = 0, y = 236, w = 20, h = 28, frames = 8 },
		fireball = { x = 0, y = 264, w = 16, h = 16, frames = 4 },
		iceSpike = { x = 0, y = 280, w = 18, h = 10, frames = 8 },
		rockShot = { x = 0, y = 290, w = 16, h = 16, frames = 4 },
		shield = { x = 0, y = 306, w = 24, h = 26, frames = 6 },
		boost = { x = 0, y = 332, w = 53, h = 35, frames = 8 },
		spark = { x = 0, y = 367, w = 27, h = 35, frames = 10 },
		hit_cut = { x = 0, y = 402, w = 32, h = 32, frames = 4 },
		hit_cut2 = { x = 0, y = 434, w = 32, h = 32, frames = 5 },
		hit_cutx = { x = 0, y = 466, w = 32, h = 32, frames = 4 },
		hit_claw = { x = 0, y = 498, w = 32, h = 32, frames = 4 },
		hit_slash = { x = 0, y = 530, w = 32, h = 32, frames = 4 },
		hit_circle = { x = 0, y = 562, w = 32, h = 32, frames = 4 },
		smoke = { x = 0, y = 594, w = 32, h = 32, frames = 6 },
		dustRing = { x = 0, y = 626, w = 30, h = 14, frames = 8 },
		rockBits = { x = 0, y = 640, w = 16, h = 16, frames = 5 },
		iceFlake = { x = 0, y = 656, w = 32, h = 32, frames = 9 },
		plantSpike = { x = 0, y = 688, w = 16, h = 20, frames = 6 },
		arc = { x = 0, y = 708, w = 38, h = 34, frames = 6 },
		aura = { x = 0, y = 742, w = 25, h = 24, frames = 5 },
		shurikenMagic = { x = 0, y = 766, w = 16, h = 16, frames = 2 },
		circleSpark = { x = 0, y = 782, w = 32, h = 32, frames = 6 },
		circleSpark2 = { x = 0, y = 814, w = 32, h = 32, frames = 5 },
		rockBurst = { x = 0, y = 846, w = 30, h = 30, frames = 14 },
		firePillar = { x = 0, y = 876, w = 30, h = 41, frames = 9 },
		flower = { x = 0, y = 917, w = 16, h = 16, frames = 6, hold = 3 },
		iceFloor = { x = 0, y = 933, w = 16, h = 12, frames = 6, hold = 3 },
		boltLine = { x = 0, y = 945, w = 16, h = 12, frames = 5 },
		vine = { x = 0, y = 957, w = 16, h = 12, frames = 6, hold = 3 },
	},
}

end
MODULES['ReplicatedStorage/shared/data/ninjaItems'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 「오문 닌자전」 아이템(NINJA_DESIGN.md §4 · §6) — shared/data/items.luau가 합친다.
--  아이콘: 팩 아이템 시트(shared/data/itemIcons.generated.luau) — KitIcon = "nj_<키>".
--  Throw(투척 무기, 단축칸 1·2·3으로 던진다 — 쓰면 1개 줄어듦):
--   power = 피해 배율(× 내 공격력) · range = 날아가는 거리(도트) · speed = 도트/초 · width = 직선에서 옆으로 맞는 폭(도트)
--   radius = 있으면 닿은 자리(안 맞으면 끝까지 날아간 자리) 둘레 모두에게(폭탄)
return {
	-- ===== 투척 무기 =====
	Shuriken = {
		Name = "수리검", Tab = "Use", Type = "Throw", StackMax = 99, Price = 4, SellPrice = 1,
		Throw = { power = 0.8, range = 96, speed = 220, width = 6 },
		Description = "가볍게 던지는 표창. 공격력의 80% 피해.",
		KitIcon = "nj_shuriken", Icon = "",
	},
	Kunai = {
		Name = "쿠나이", Tab = "Use", Type = "Throw", StackMax = 99, Price = 10, SellPrice = 2,
		Throw = { power = 1.3, range = 112, speed = 260, width = 5 },
		Description = "멀리 곧게 날아가는 단검. 공격력의 130% 피해.",
		KitIcon = "nj_kunai", Icon = "",
	},
	Bomb = {
		Name = "폭탄", Tab = "Use", Type = "Throw", StackMax = 50, Price = 35, SellPrice = 8,
		Throw = { power = 2.0, range = 64, speed = 120, width = 8, radius = 22 },
		Description = "닿은 자리에서 터져 둘레 모두에게 공격력의 200% 피해.",
		KitIcon = "nj_bomb", Icon = "",
	},
	-- ===== 음식(체력 회복) =====
	Onigiri = {
		Name = "주먹밥", Tab = "Use", Type = "Consumable", StackMax = 99, Heal = 40, Price = 15, SellPrice = 3,
		Description = "든든한 주먹밥. 체력을 40 회복.",
		KitIcon = "nj_onigiri", Icon = "",
	},
	Sushi = {
		Name = "초밥", Tab = "Use", Type = "Consumable", StackMax = 99, Heal = 120, Price = 45, SellPrice = 9,
		Description = "신선한 초밥. 체력을 120 회복.",
		KitIcon = "nj_sushi", Icon = "",
	},
	Yakitori = {
		Name = "닭꼬치", Tab = "Use", Type = "Consumable", StackMax = 99, Heal = 260, Price = 110, SellPrice = 22,
		Description = "숯불 향 가득한 꼬치. 체력을 260 회복.",
		KitIcon = "nj_yakitori", Icon = "",
	},
	-- ===== 인술 두루마리(드묾 — 자기 유파 것을 쓰면 인술 단계 +1, server/modules/ninjutsuService.luau UseScroll) =====
	ScrollFire = { Name = "불의 두루마리", Tab = "Use", Type = "Scroll", School = "fire", StackMax = 99, SellPrice = 150, Description = "불 유파의 비전. 쓰면 불 인술이 한 단계 오른다.", KitIcon = "nj_scroll_fire", Icon = "" },
	ScrollIce = { Name = "얼음의 두루마리", Tab = "Use", Type = "Scroll", School = "ice", StackMax = 99, SellPrice = 150, Description = "얼음 유파의 비전. 쓰면 얼음 인술이 한 단계 오른다.", KitIcon = "nj_scroll_ice", Icon = "" },
	ScrollPlant = { Name = "풀의 두루마리", Tab = "Use", Type = "Scroll", School = "plant", StackMax = 99, SellPrice = 150, Description = "풀 유파의 비전. 쓰면 풀 인술이 한 단계 오른다.", KitIcon = "nj_scroll_plant", Icon = "" },
	ScrollRock = { Name = "바위의 두루마리", Tab = "Use", Type = "Scroll", School = "rock", StackMax = 99, SellPrice = 150, Description = "바위 유파의 비전. 쓰면 바위 인술이 한 단계 오른다.", KitIcon = "nj_scroll_rock", Icon = "" },
	ScrollThunder = { Name = "번개의 두루마리", Tab = "Use", Type = "Scroll", School = "thunder", StackMax = 99, SellPrice = 150, Description = "번개 유파의 비전. 쓰면 번개 인술이 한 단계 오른다.", KitIcon = "nj_scroll_thunder", Icon = "" },
	-- ===== 부적(방어구 대신 차는 장신구 — NINJA_DESIGN §7. 착용 칸은 옛 방어구 칸 "Armor"를 그대로 쓴다) =====
	--  Defense = 몬스터에게 받는 피해에서 빼는 값 · Level = 찰 수 있는 레벨. 첫 부적은 잡화 상점, 나머지는 드롭(shared/config/drops.luau CHARMS)
	GuardCharm = { Name = "수호 부적", Tab = "Equip", Type = "Charm", EquipSlot = "Armor", StackMax = 1, Level = 1, Defense = 2, Price = 90, SellPrice = 24, Description = "몸을 지켜 주는 부적. 방어력 +2.", KitIcon = "nj_charm1", Icon = "" },
	WindCharm = { Name = "바람 부적", Tab = "Equip", Type = "Charm", EquipSlot = "Armor", StackMax = 1, Level = 15, Defense = 7, SellPrice = 84, Description = "바람이 공격을 흘려 낸다. 방어력 +7.", KitIcon = "nj_charm2", Icon = "" },
	IronCharm = { Name = "금강 부적", Tab = "Equip", Type = "Charm", EquipSlot = "Armor", StackMax = 1, Level = 35, Defense = 16, SellPrice = 192, Description = "몸이 쇠처럼 단단해진다. 방어력 +16.", KitIcon = "nj_charm3", Icon = "" },
	SpiritCharm = { Name = "신령 부적", Tab = "Equip", Type = "Charm", EquipSlot = "Armor", StackMax = 1, Level = 60, Defense = 30, SellPrice = 360, Description = "신령이 깃든 부적. 방어력 +30.", KitIcon = "nj_charm3", Icon = "" },
	-- ===== 재료(사냥 드롭 — 강화·제작에 쓴다, N3) =====
	GrassBlade = { Name = "풀잎", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 1, Description = "들판 몬스터가 떨어뜨리는 질긴 풀잎.", KitIcon = "nj_grass", Icon = "" },
	Branch = { Name = "나뭇가지", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 2, Description = "단단한 나뭇가지. 무기 손잡이 재료.", KitIcon = "nj_branch", Icon = "" },
	Feather = { Name = "깃털", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 3, Description = "가벼운 깃털. 화살과 부적 재료.", KitIcon = "nj_feather", Icon = "" },
	Stone = { Name = "돌멩이", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 2, Description = "묵직한 돌멩이.", KitIcon = "nj_rock", Icon = "" },
	CopperBar = { Name = "구리 주괴", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 8, Description = "무기 강화에 쓰는 구리 주괴.", KitIcon = "nj_bar_copper", Icon = "" },
	IronBar = { Name = "철 주괴", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 16, Description = "무기 강화에 쓰는 철 주괴.", KitIcon = "nj_bar_iron", Icon = "" },
	SilverBar = { Name = "은 주괴", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 30, Description = "무기 강화에 쓰는 은 주괴.", KitIcon = "nj_bar_silver", Icon = "" },
	GoldBar = { Name = "금 주괴", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 55, Description = "무기 강화에 쓰는 금 주괴.", KitIcon = "nj_bar_gold", Icon = "" },
	MithrilBar = { Name = "미스릴 주괴", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 100, Description = "아주 귀한 미스릴 주괴.", KitIcon = "nj_bar_mithril", Icon = "" },
	GreenGem = { Name = "초록 보석", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 40, Description = "풀빛이 도는 보석.", KitIcon = "nj_gem_green", Icon = "" },
	RedGem = { Name = "붉은 보석", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 60, Description = "불빛이 도는 보석.", KitIcon = "nj_gem_red", Icon = "" },
	YellowGem = { Name = "노란 보석", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 80, Description = "번개 빛이 도는 보석.", KitIcon = "nj_gem_yellow", Icon = "" },
	PurpleGem = { Name = "보라 보석", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 120, Description = "신비한 보라 보석.", KitIcon = "nj_gem_purple", Icon = "" },
}

end
MODULES['ReplicatedStorage/shared/data/ninjaWeapons'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 「오문 닌자전」 무기(NINJA_DESIGN.md §7) — shared/data/items.luau가 합친다. 그림 = Ninja Adventure 팩 무기.
--  Class = 무기 종류(shared/config/weapons.luau CLASSES) · Level = 쓸 수 있는 레벨 · Attack = 공격력(대략 3 + 1.2 × Level)
--  얻는 곳: 들판 무기는 잡화 상점(Price), 그 뒤 지역 무기는 그 지역 몬스터가 드물게 떨어뜨린다(shared/config/drops.luau WEAPONS).
--  아이콘: 팩 아이템 시트(itemIcons.generated) — KitIcon = "nj_<키>". 등 뒤에 메는 그림도 같은 아이콘을 쓴다.
local function weapon(name: string, class: string, level: number, icon: string, desc: string, price: number?)
	local attack = math.round(3 + 1.2 * level)
	return {
		Name = name, Tab = "Equip", Type = "Weapon", EquipSlot = "Weapon", StackMax = 1,
		Class = class, Level = level, Attack = attack,
		Price = price, SellPrice = attack * 6,
		Description = desc,
		KitIcon = "nj_" .. icon, Icon = "",
	}
end

return {
	-- ===== 새싹 들판(Lv.1~) — 잡화 상점에서 판다 =====
	Ninjato = weapon("닌자도", "sword", 1, "ninjaku", "견습 닌자의 곧은 칼.", 60),
	Sai = weapon("사이", "dual", 5, "sai", "양손에 쥐는 갈래 단검.", 180),
	Club = weapon("나무 곤봉", "heavy", 5, "club", "묵직한 나무 곤봉.", 180),
	-- ===== 대나무 숲(Lv.10~) =====
	Katana = weapon("카타나", "sword", 10, "katana", "잘 벼린 닌자의 칼."),
	Spear = weapon("죽창", "polearm", 12, "lance", "길게 찌르는 대나무 창."),
	Whip = weapon("덩굴 채찍", "whip", 15, "whip", "넓게 휘두르는 채찍."),
	-- ===== 개울과 늪(Lv.20~) =====
	LongSword = weapon("장검", "sword", 20, "sword", "날이 긴 검."),
	Axe = weapon("도끼", "heavy", 22, "axe", "늪 나무도 쪼개는 도끼."),
	-- ===== 모래 사막(Lv.30~) =====
	Trident = weapon("삼지창", "polearm", 30, "fork", "세 갈래 창."),
	Scimitar = weapon("사막의 검", "sword", 35, "sword2", "사막 도적이 쓰던 검."),
	Hammer = weapon("전투 망치", "heavy", 38, "hammer", "바위도 부수는 망치."),
	-- ===== 눈 덮인 산(Lv.45~) =====
	Rapier = weapon("얼음 세검", "sword", 45, "rapier", "가늘고 날카로운 검."),
	Halberd = weapon("미늘창", "polearm", 50, "lance2", "날이 달린 긴 창."),
	-- ===== 버려진 마을(Lv.60~) =====
	GreatSword = weapon("대검", "heavy", 60, "bigsword", "두 손으로 드는 큰 검."),
}

end
MODULES['ReplicatedStorage/shared/data/petSkills.generated'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/export_fx.mjs).
-- 펫 스킬 이펙트 시트 위치와 종별 스킬. 시트 그림: SpriteDemo/assets/fx/fx<N>.png(에셋 id는 shared/config/fxAssets.generated.luau).
--  effects["번호:색"] = { sheet, cell(0부터, 왼쪽 위에서 가로로), frames }
--  species[종 id] = { name, pattern(bolt|burst|orbit|drop|buff), kind(line|area|melee|drop), fx, hit, scale(64칸 그림 배율, 2 = 캐릭터 도트와 같은 밀도), multi(내리꽂기 개수),
--                    aim(원본 그림 방향 라디안 — 날아가는 쪽으로 돌릴 때 뺀다, 없으면 안 돌림), hold(투사체로 날 때 붙잡는 장), noRest(도착 뒤 남은 장 대신 맞음 이펙트) }
return {
	FRAME = 64,
	COLS = 16,
	FRAME_TIME = 0.04,
	SHEET_COUNT = 4,
	effects = {
		["03:warm"] = { sheet = 1, cell = 243, frames = 13 },
		["114:warm"] = { sheet = 2, cell = 148, frames = 12 },
		["124:warm"] = { sheet = 2, cell = 232, frames = 12 },
		["135:white"] = { sheet = 3, cell = 0, frames = 12 },
		["136:white"] = { sheet = 3, cell = 36, frames = 12 },
		["174:green"] = { sheet = 3, cell = 225, frames = 10 },
		["176:warm"] = { sheet = 3, cell = 215, frames = 10 },
		["184:red"] = { sheet = 3, cell = 119, frames = 11 },
		["185:purple"] = { sheet = 2, cell = 220, frames = 12 },
		["186:purple"] = { sheet = 3, cell = 12, frames = 12 },
		["197:purple"] = { sheet = 2, cell = 28, frames = 14 },
		["221:white"] = { sheet = 4, cell = 0, frames = 10 },
		["230:brown"] = { sheet = 4, cell = 202, frames = 5 },
		["230:cyan"] = { sheet = 4, cell = 207, frames = 5 },
		["230:green"] = { sheet = 4, cell = 197, frames = 5 },
		["230:indigo"] = { sheet = 4, cell = 212, frames = 5 },
		["230:purple"] = { sheet = 4, cell = 187, frames = 5 },
		["230:red"] = { sheet = 4, cell = 177, frames = 5 },
		["230:warm"] = { sheet = 4, cell = 182, frames = 5 },
		["230:white"] = { sheet = 4, cell = 192, frames = 5 },
		["231:warm"] = { sheet = 4, cell = 76, frames = 9 },
		["232:red"] = { sheet = 4, cell = 112, frames = 9 },
		["233:green"] = { sheet = 3, cell = 235, frames = 10 },
		["240:green"] = { sheet = 3, cell = 245, frames = 10 },
		["242:warm"] = { sheet = 3, cell = 195, frames = 10 },
		["25:warm"] = { sheet = 2, cell = 0, frames = 14 },
		["285:green"] = { sheet = 4, cell = 138, frames = 8 },
		["296:red"] = { sheet = 4, cell = 40, frames = 9 },
		["315:brown"] = { sheet = 4, cell = 170, frames = 7 },
		["334:cyan"] = { sheet = 4, cell = 121, frames = 9 },
		["335:cyan"] = { sheet = 4, cell = 103, frames = 9 },
		["377:warm"] = { sheet = 4, cell = 146, frames = 8 },
		["387:white"] = { sheet = 4, cell = 154, frames = 8 },
		["388:brown"] = { sheet = 4, cell = 85, frames = 9 },
		["395:red"] = { sheet = 4, cell = 58, frames = 9 },
		["396:cyan"] = { sheet = 4, cell = 162, frames = 8 },
		["397:red"] = { sheet = 4, cell = 49, frames = 9 },
		["397:warm"] = { sheet = 4, cell = 94, frames = 9 },
		["426:cyan"] = { sheet = 4, cell = 30, frames = 10 },
		["428:white"] = { sheet = 4, cell = 20, frames = 10 },
		["437:cyan"] = { sheet = 4, cell = 10, frames = 10 },
		["437:red"] = { sheet = 3, cell = 185, frames = 10 },
		["449:warm"] = { sheet = 4, cell = 67, frames = 9 },
		["464:green"] = { sheet = 3, cell = 152, frames = 11 },
		["466:indigo"] = { sheet = 3, cell = 163, frames = 11 },
		["474:white"] = { sheet = 3, cell = 174, frames = 11 },
		["476:warm"] = { sheet = 2, cell = 184, frames = 12 },
		["484:indigo"] = { sheet = 3, cell = 48, frames = 12 },
		["485:brown"] = { sheet = 2, cell = 196, frames = 12 },
		["485:cyan"] = { sheet = 3, cell = 72, frames = 12 },
		["485:green"] = { sheet = 2, cell = 208, frames = 12 },
		["485:indigo"] = { sheet = 3, cell = 60, frames = 12 },
		["485:purple"] = { sheet = 3, cell = 96, frames = 12 },
		["485:red"] = { sheet = 2, cell = 136, frames = 12 },
		["485:warm"] = { sheet = 2, cell = 160, frames = 12 },
		["485:white"] = { sheet = 3, cell = 24, frames = 12 },
		["486:purple"] = { sheet = 2, cell = 172, frames = 12 },
		["487:green"] = { sheet = 3, cell = 130, frames = 11 },
		["516:purple"] = { sheet = 3, cell = 84, frames = 12 },
		["528:white"] = { sheet = 2, cell = 97, frames = 13 },
		["529:red"] = { sheet = 2, cell = 84, frames = 13 },
		["567:white"] = { sheet = 2, cell = 123, frames = 13 },
		["568:brown"] = { sheet = 2, cell = 14, frames = 14 },
		["569:white"] = { sheet = 2, cell = 110, frames = 13 },
		["578:red"] = { sheet = 3, cell = 108, frames = 11 },
		["579:brown"] = { sheet = 2, cell = 70, frames = 14 },
		["586:warm"] = { sheet = 2, cell = 56, frames = 14 },
		["612:warm"] = { sheet = 1, cell = 183, frames = 15 },
		["625:green"] = { sheet = 1, cell = 198, frames = 15 },
		["632:white"] = { sheet = 2, cell = 42, frames = 14 },
		["64:red"] = { sheet = 4, cell = 130, frames = 8 },
		["652:green"] = { sheet = 1, cell = 167, frames = 16 },
		["654:indigo"] = { sheet = 1, cell = 118, frames = 17 },
		["655:purple"] = { sheet = 1, cell = 228, frames = 15 },
		["662:brown"] = { sheet = 1, cell = 213, frames = 15 },
		["664:red"] = { sheet = 1, cell = 135, frames = 16 },
		["665:green"] = { sheet = 1, cell = 151, frames = 16 },
		["673:warm"] = { sheet = 1, cell = 65, frames = 18 },
		["674:white"] = { sheet = 1, cell = 83, frames = 18 },
		["69:red"] = { sheet = 3, cell = 205, frames = 10 },
		["701:purple"] = { sheet = 1, cell = 46, frames = 19 },
		["702:brown"] = { sheet = 1, cell = 101, frames = 17 },
		["713:brown"] = { sheet = 1, cell = 0, frames = 23 },
		["722:indigo"] = { sheet = 1, cell = 23, frames = 23 },
		["78:green"] = { sheet = 3, cell = 141, frames = 11 },
		["79:green"] = { sheet = 2, cell = 244, frames = 12 },
	},
	species = {
		piyo = { name = "불씨 콕", pattern = "bolt", kind = "line", scale = 1.5, multi = 1, fx = "437:red", hit = "485:red", aim = -0.7854, hold = 1, noRest = false },
		yeowoo = { name = "여우불 꼬리", pattern = "orbit", kind = "area", scale = 3, multi = 1, fx = "296:red", hit = "230:red", hold = 1, noRest = false },
		wonsung = { name = "불꽃 바나나", pattern = "drop", kind = "drop", scale = 2, multi = 1, fx = "114:warm", hit = "230:warm", hold = 1, noRest = false },
		bulpanda = { name = "노을 꼬리치기", pattern = "burst", kind = "area", scale = 3, multi = 1, fx = "03:warm", hit = "230:warm", hold = 1, noRest = false },
		bulham = { name = "볼주머니 불씨", pattern = "bolt", kind = "line", scale = 1.5, multi = 1, fx = "397:red", hit = "485:red", aim = -0.7854, hold = 1, noRest = false },
		kkulkkul = { name = "따끈 콧김", pattern = "burst", kind = "area", scale = 3, multi = 1, fx = "25:warm", hit = "230:warm", hold = 1, noRest = false },
		bulbu = { name = "불깃 날리기", pattern = "bolt", kind = "line", scale = 2, multi = 1, fx = "395:red", hit = "485:red", aim = 0.45, hold = 3, noRest = true },
		bulyeomso = { name = "따뜻한 털", pattern = "buff", kind = "melee", scale = 2, multi = 1, fx = "242:warm", hit = "", hold = 1, noRest = false },
		bulbakjwi = { name = "노을 날갯짓", pattern = "orbit", kind = "area", scale = 3, multi = 1, fx = "64:red", hit = "230:red", hold = 1, noRest = false },
		buldudu = { name = "땅불 솟기", pattern = "drop", kind = "drop", scale = 2, multi = 1, fx = "529:red", hit = "230:red", hold = 1, noRest = false },
		bandit = { name = "반딧불 무리", pattern = "orbit", kind = "area", scale = 3, multi = 1, fx = "673:warm", hit = "230:warm", hold = 1, noRest = false },
		maekom = { name = "매운 고추씨", pattern = "bolt", kind = "line", scale = 1.2, multi = 1, fx = "578:red", hit = "485:red", aim = -0.35, hold = 4, noRest = false },
		chotbul = { name = "촛불 온기", pattern = "buff", kind = "melee", scale = 2, multi = 1, fx = "69:red", hit = "", hold = 1, noRest = false },
		horong = { name = "호박 굴리기", pattern = "bolt", kind = "line", scale = 1.5, multi = 1, fx = "612:warm", hit = "485:warm", hold = 3, noRest = false },
		haebara = { name = "햇살 꽃잎", pattern = "burst", kind = "area", scale = 3, multi = 1, fx = "176:warm", hit = "230:warm", hold = 1, noRest = false },
		bulssi = { name = "불똥 떨구기", pattern = "drop", kind = "drop", scale = 2, multi = 2, fx = "664:red", hit = "230:red", hold = 1, noRest = false },
		cocoa = { name = "코코아 한 모금", pattern = "buff", kind = "melee", scale = 2, multi = 1, fx = "568:brown", hit = "", hold = 1, noRest = false },
		jeongu = { name = "번쩍 전구", pattern = "burst", kind = "area", scale = 3, multi = 1, fx = "449:warm", hit = "230:warm", hold = 1, noRest = false },
		donut = { name = "스프링클 뿌리기", pattern = "drop", kind = "drop", scale = 2, multi = 2, fx = "486:purple", hit = "230:purple", hold = 1, noRest = false },
		sikppang = { name = "식빵 던지기", pattern = "bolt", kind = "line", scale = 1.5, multi = 1, fx = "231:warm", hit = "485:warm", aim = -0.7854, hold = 2, noRest = false },
		alkong = { name = "달걀 톡", pattern = "drop", kind = "drop", scale = 2, multi = 1, fx = "528:white", hit = "230:white", hold = 1, noRest = false },
		lantern = { name = "초롱 불빛", pattern = "orbit", kind = "area", scale = 3, multi = 1, fx = "184:red", hit = "230:red", hold = 1, noRest = false },
		goguma = { name = "군고구마 김", pattern = "burst", kind = "area", scale = 3, multi = 1, fx = "476:warm", hit = "230:warm", hold = 1, noRest = false },
		ssakto = { name = "깡충 새싹", pattern = "drop", kind = "drop", scale = 2, multi = 1, fx = "665:green", hit = "230:green", hold = 1, noRest = false },
		supgom = { name = "숲곰 발도장", pattern = "burst", kind = "area", scale = 3, multi = 1, fx = "487:green", hit = "230:green", hold = 1, noRest = false },
		daram = { name = "도토리 튕기기", pattern = "bolt", kind = "line", scale = 1.5, multi = 1, fx = "388:brown", hit = "485:brown", hold = 4, noRest = false },
		saseum = { name = "잎새 뿔바람", pattern = "orbit", kind = "area", scale = 3, multi = 1, fx = "174:green", hit = "230:green", hold = 1, noRest = false },
		dalpaeng = { name = "이끼 담요", pattern = "buff", kind = "melee", scale = 2, multi = 1, fx = "625:green", hit = "", hold = 1, noRest = false },
		panda = { name = "대나무 잎날", pattern = "bolt", kind = "line", scale = 2, multi = 1, fx = "233:green", hit = "485:green", aim = 0, hold = 2, noRest = true },
		kkotyang = { name = "꽃향기", pattern = "buff", kind = "melee", scale = 2, multi = 1, fx = "185:purple", hit = "", hold = 1, noRest = false },
		ipkoala = { name = "유칼립 잎비", pattern = "drop", kind = "drop", scale = 2, multi = 3, fx = "240:green", hit = "230:green", hold = 1, noRest = false },
		ipneoguri = { name = "나뭇잎 둔갑", pattern = "orbit", kind = "area", scale = 3, multi = 1, fx = "285:green", hit = "230:green", hold = 1, noRest = false },
		ipkapi = { name = "귤 껍질 톡", pattern = "bolt", kind = "line", scale = 1.5, multi = 1, fx = "124:warm", hit = "485:warm", hold = 5, noRest = false },
		pulsong = { name = "네잎 행운", pattern = "buff", kind = "melee", scale = 2, multi = 1, fx = "78:green", hit = "", hold = 1, noRest = false },
		pulneulbo = { name = "포근 이끼", pattern = "burst", kind = "area", scale = 3, multi = 1, fx = "79:green", hit = "230:green", hold = 1, noRest = false },
		beoseot = { name = "포자 퐁", pattern = "burst", kind = "area", scale = 3, multi = 1, fx = "662:brown", hit = "230:brown", hold = 1, noRest = false },
		bungbung = { name = "붕붕 침", pattern = "bolt", kind = "line", scale = 2, multi = 1, fx = "377:warm", hit = "485:warm", aim = 0.7854, hold = 2, noRest = true },
		seonin = { name = "가시 콕콕", pattern = "orbit", kind = "area", scale = 3, multi = 1, fx = "652:green", hit = "230:green", hold = 1, noRest = false },
		mumu = { name = "무 뽑기", pattern = "drop", kind = "drop", scale = 2, multi = 1, fx = "569:white", hit = "230:white", hold = 1, noRest = false },
		ttalkong = { name = "새콤 씨앗", pattern = "bolt", kind = "line", scale = 1.5, multi = 1, fx = "397:warm", hit = "485:warm", aim = -0.7854, hold = 1, noRest = false },
		solbang = { name = "솔방울 낙하", pattern = "drop", kind = "drop", scale = 2, multi = 1, fx = "713:brown", hit = "230:brown", hold = 1, noRest = false },
		kkomul = { name = "실타래 감기", pattern = "burst", kind = "area", scale = 3, multi = 1, fx = "135:white", hit = "230:white", hold = 1, noRest = false },
		hwabun = { name = "화분 물주기", pattern = "buff", kind = "melee", scale = 2, multi = 1, fx = "464:green", hit = "", hold = 1, noRest = false },
		bamsong = { name = "밤송이 굴리기", pattern = "bolt", kind = "line", scale = 1.5, multi = 1, fx = "315:brown", hit = "485:brown", hold = 2, noRest = false },
		napul = { name = "날개가루", pattern = "orbit", kind = "area", scale = 3, multi = 1, fx = "335:cyan", hit = "230:cyan", hold = 1, noRest = false },
		jumeok = { name = "주먹밥 한입", pattern = "buff", kind = "melee", scale = 2, multi = 1, fx = "221:white", hit = "", hold = 1, noRest = false },
		gaji = { name = "가지 꽁", pattern = "drop", kind = "drop", scale = 2, multi = 1, fx = "701:purple", hit = "230:purple", hold = 1, noRest = false },
		boksung = { name = "복숭아 향", pattern = "burst", kind = "area", scale = 3, multi = 1, fx = "186:purple", hit = "230:purple", hold = 1, noRest = false },
		penggu = { name = "얼음 미끄럼", pattern = "bolt", kind = "line", scale = 2, multi = 1, fx = "387:white", hit = "485:white", aim = 0.45, hold = 2, noRest = true },
		sudal = { name = "조개 던지기", pattern = "bolt", kind = "line", scale = 2, multi = 1, fx = "136:white", hit = "485:white", hold = 4, noRest = false },
		mulbeom = { name = "물보라", pattern = "burst", kind = "area", scale = 3, multi = 1, fx = "484:indigo", hit = "230:indigo", hold = 1, noRest = false },
		mulori = { name = "물결 꽥", pattern = "burst", kind = "area", scale = 3, multi = 1, fx = "466:indigo", hit = "230:indigo", hold = 1, noRest = false },
		mulkkotge = { name = "집게 싹둑", pattern = "orbit", kind = "area", scale = 3, multi = 1, fx = "232:red", hit = "230:red", hold = 1, noRest = false },
		mulbiber = { name = "통나무 쿵", pattern = "drop", kind = "drop", scale = 2, multi = 1, fx = "702:brown", hit = "230:brown", hold = 1, noRest = false },
		mulakeo = { name = "악어 물기", pattern = "bolt", kind = "line", scale = 2, multi = 1, fx = "722:indigo", hit = "485:indigo", aim = -1.5708, hold = 6, noRest = true },
		mulbukgeuk = { name = "눈송이", pattern = "drop", kind = "drop", scale = 2.5, multi = 1, fx = "674:white", hit = "230:white", hold = 1, noRest = false },
		mulgalme = { name = "바닷바람", pattern = "orbit", kind = "area", scale = 3, multi = 1, fx = "567:white", hit = "230:white", hold = 1, noRest = false },
		bangul = { name = "물방울 톡", pattern = "bolt", kind = "line", scale = 1.5, multi = 1, fx = "437:cyan", hit = "485:cyan", aim = -0.7854, hold = 1, noRest = false },
		mungge = { name = "소나기", pattern = "drop", kind = "drop", scale = 2.5, multi = 3, fx = "334:cyan", hit = "230:cyan", hold = 1, noRest = false },
		yeonip = { name = "연꽃 이슬", pattern = "buff", kind = "melee", scale = 2, multi = 1, fx = "655:purple", hit = "", hold = 1, noRest = false },
		haepa = { name = "찌릿 촉수", pattern = "burst", kind = "area", scale = 2.5, multi = 1, fx = "197:purple", hit = "230:purple", hold = 1, noRest = false },
		nunmung = { name = "눈덩이 굴리기", pattern = "bolt", kind = "line", scale = 1.5, multi = 1, fx = "428:white", hit = "485:white", hold = 3, noRest = false },
		jogae = { name = "진주 반짝", pattern = "orbit", kind = "area", scale = 3, multi = 1, fx = "474:white", hit = "230:white", hold = 1, noRest = false },
		chacha = { name = "따뜻한 차", pattern = "buff", kind = "melee", scale = 2, multi = 1, fx = "632:white", hit = "", hold = 1, noRest = false },
		jororong = { name = "물뿌리개 샤워", pattern = "burst", kind = "area", scale = 3, multi = 1, fx = "426:cyan", hit = "230:cyan", hold = 1, noRest = false },
		gaegul = { name = "개골 혀치기", pattern = "bolt", kind = "line", scale = 2, multi = 1, fx = "516:purple", hit = "485:purple", aim = -1.5708, hold = 4, noRest = true },
		munmun = { name = "먹물 퐁", pattern = "drop", kind = "drop", scale = 2, multi = 1, fx = "654:indigo", hit = "230:indigo", hold = 1, noRest = false },
		ppobok = { name = "빵빵 부풀기", pattern = "burst", kind = "area", scale = 3, multi = 1, fx = "586:warm", hit = "230:warm", hold = 1, noRest = false },
		subak = { name = "수박씨 퉤", pattern = "bolt", kind = "line", scale = 2, multi = 1, fx = "579:brown", hit = "485:brown", aim = 0, hold = 2, noRest = true },
		icecone = { name = "사르르 냉기", pattern = "orbit", kind = "area", scale = 3, multi = 1, fx = "396:cyan", hit = "230:cyan", hold = 1, noRest = false },
	},
}

end
MODULES['ReplicatedStorage/shared/data/pixelFont.generated'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/export_ninja_font.mjs, 글꼴 정의 js/font.js).
-- 도트 글꼴 글자판 규칙. 글자 순서: ASCII 32~126(95자) → 기호(extra) → 낱자 ㄱ~ㅣ(U+3131~3163, 51자) → 한글 가~힣(11,172자).
-- 한 장에 perPage자씩, 가로 cols칸(칸 = cellW x cellH). 한글·낱자 폭은 hangulAdv, 영문·기호 폭은 asciiAdv/extraAdv.
-- 글꼴: 갈무리(Galmuri11 · Galmuri14) — Copyright (c) 2019–2025 Lee Minseo, SIL Open Font License 1.1.
return {
	body = { cellW = 12, cellH = 13, line = 14, hangulAdv = 12, cols = 85, perPage = 6630, pages = 2, asciiAdv = { 5, 4, 4, 8, 8, 10, 8, 4, 4, 4, 6, 8, 4, 6, 4, 6, 8, 6, 8, 8, 8, 8, 8, 8, 8, 8, 4, 4, 5, 6, 5, 6, 10, 8, 8, 9, 8, 7, 7, 9, 8, 4, 7, 8, 7, 10, 8, 9, 8, 9, 8, 8, 8, 9, 8, 10, 8, 8, 7, 4, 6, 4, 6, 8, 4, 7, 8, 7, 8, 8, 6, 8, 7, 4, 6, 7, 4, 10, 7, 8, 8, 8, 6, 7, 6, 8, 8, 10, 8, 8, 7, 5, 4, 5, 8 }, extra = { "♥", "★", "×", "·", "…", "♪", "—", "→", "←", "↑", "↓", "▲", "▼", "●", "○", "「", "」" }, extraAdv = { 12, 12, 8, 4, 12, 12, 10, 12, 12, 12, 12, 12, 12, 12, 12, 5, 5 } },
	title = { cellW = 16, cellH = 20, line = 20, hangulAdv = 15, cols = 64, perPage = 3264, pages = 4, asciiAdv = { 6, 5, 5, 11, 9, 12, 13, 5, 6, 6, 9, 9, 5, 8, 5, 9, 10, 6, 10, 10, 10, 10, 10, 10, 10, 10, 5, 5, 7, 8, 7, 9, 15, 11, 10, 11, 10, 9, 9, 11, 10, 5, 9, 10, 9, 11, 10, 11, 10, 11, 10, 11, 11, 11, 11, 11, 10, 11, 10, 5, 9, 5, 7, 10, 5, 9, 10, 10, 10, 10, 8, 10, 9, 5, 5, 9, 5, 11, 9, 10, 10, 10, 7, 9, 8, 9, 9, 11, 9, 9, 9, 6, 5, 6, 11 }, extra = { "♥", "★", "×", "·", "…", "♪", "—", "→", "←", "↑", "↓", "▲", "▼", "●", "○", "「", "」" }, extraAdv = { 15, 15, 9, 5, 15, 15, 11, 15, 15, 15, 15, 15, 15, 15, 15, 6, 6 } },
}

end
MODULES['ReplicatedStorage/shared/data/quests.generated'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 자동 생성: dino-workshop/tools/export_ninja_design.mjs — 손으로 고치지 않는다(설계는 dino-workshop/js/ninja/design/story.js).
-- 본 줄거리 퀘스트: 차례대로 하나씩 진행한다. kind = talk · kill · collect · reach · boss · job · ride.
--  giver/target(talk) = NPC 키, target(kill · boss) = 몬스터 · 보스 id, target(collect) = 아이템 id, scene(reach) = 씬 id(아직 짓지 않은 곳은 nil),
--  targetName = 목표의 이름(추적창 글), offer = 받을 때 대사, done = 끝낼 때 대사. item = "SchoolScroll"이면 내 유파의 두루마리.
return {
	-- 서장 · 견습 닌자 (Lv.1~3)
	{ id = "m001", chapter = "ch0", title = "스승의 부름", giver = "elder", giverName = "스승", kind = "talk", target = "elder", targetName = "스승", count = 1, level = 1, text = "스승에게 말을 건다.", offer = "스승에게 말을 건다.", done = "왔느냐, 견습 닌자여. 요즘 들판의 짐승들이 사나워졌다. 다섯 봉인이 약해진 탓이지… 우선 네 몸부터 단련해야겠구나.", exp = 20, gold = 0 },
	{ id = "m002", chapter = "ch0", title = "첫 수련", giver = "elder", giverName = "스승", kind = "kill", target = "Slime", targetName = "말랑이", count = 5, level = 2, text = "새싹 들판 1에서 말랑이 5마리를 쓰러뜨린다.", offer = "마을 남쪽 길로 나가면 새싹 들판이다. 말랑이 다섯 마리를 쓰러뜨리고 오너라.", done = "제법이구나. 주먹밥을 줄 테니 다치면 먹거라. 다음은 잡화상에게 가 보아라.", exp = 120, gold = 80, item = "Onigiri", itemCount = 5 },
	{ id = "m003", chapter = "ch0", title = "닌자의 도구", giver = "merchant", giverName = "잡화상", kind = "talk", target = "merchant", targetName = "잡화상", count = 1, level = 2, text = "잡화상에게서 수리검 쓰는 법을 듣는다(단축칸).", offer = "잡화상에게서 수리검 쓰는 법을 듣는다(단축칸).", done = "스승님이 보내셨다고요? 닌자는 칼만 쓰지 않아요. 수리검을 드릴 테니 단축칸에 넣고 던져 보세요. 다음엔 대장간에 들러 보세요.", exp = 30, gold = 0, item = "Shuriken", itemCount = 30 },
	{ id = "m004", chapter = "ch0", title = "칼을 벼리다", giver = "blacksmith", giverName = "대장장이", kind = "collect", target = "CopperBar", targetName = "구리 주괴", count = 1, level = 3, text = "구리 주괴 1개를 대장장이에게 가져가 강화하는 법을 듣는다.", offer = "칼이 무디구먼. 들판 몬스터가 가끔 구리 주괴를 떨어뜨리지. 하나 구해 오면 강화하는 법을 알려 주마.", done = "좋은 구리야. 주괴와 엽전이 있으면 내가 무기를 강화해 주지. 몇 개 더 줄 테니 직접 해 보게.", exp = 120, gold = 90, item = "CopperBar", itemCount = 3 },
	-- 1장 · 들판의 이변 (Lv.3~10)
	{ id = "m101", chapter = "ch1", title = "버섯이 걸어 다닌다", giver = "potion", giverName = "약방 주인", kind = "kill", target = "Mushroom", targetName = "버섯돌이", count = 12, level = 3, text = "새싹 들판 2 · 3의 버섯돌이 12마리.", offer = "큰일이에요! 약에 쓰던 버섯이 걸어 다니며 사람을 물어요. 새싹 들판 2와 3의 버섯돌이 열두 마리만 쫓아 주세요.", done = "고마워요! 버섯이 요괴가 되다니… 스승님 말씀대로 봉인이 약해졌나 봐요.", exp = 160, gold = 90 },
	{ id = "m102", chapter = "ch1", title = "약초꾼의 부탁", giver = "potion", giverName = "약방 주인", kind = "collect", target = "GrassBlade", targetName = "풀잎", count = 10, level = 4, text = "풀잎 10장을 모아 온다.", offer = "다친 사람이 늘어서 약이 모자라요. 들판 몬스터가 떨어뜨리는 풀잎 열 장만 모아 주세요.", done = "이만하면 넉넉해요. 갓 만든 초밥이에요, 가져가세요. 참, 스승님이 찾으시던데요.", exp = 150, gold = 110, item = "Sushi", itemCount = 3 },
	{ id = "m103", chapter = "ch1", title = "언덕 너머", giver = "elder", giverName = "스승", kind = "reach", target = "나비 언덕 1", scene = "hill1", targetName = "나비 언덕 1", count = 1, level = 6, text = "나비 언덕까지 길을 살핀다.", offer = "들판 동쪽 나비 언덕에서도 이상한 소리가 들린다는구나. 가서 살피고 오너라.", done = "나비 언덕에 닿았다. 애벌레들이 사납게 꿈틀거린다.", exp = 105, gold = 0 },
	{ id = "m104", chapter = "ch1", title = "갉아먹힌 곳간", giver = "storage", giverName = "창고지기", kind = "kill", target = "Mouse", targetName = "도토리쥐", count = 15, level = 7, text = "나비 언덕 3의 도토리쥐 15마리.", offer = "곳간의 곡식을 도토리쥐가 다 갉아먹었어. 나비 언덕 3에 굴이 있다던데, 열다섯 마리만 혼내 줘.", done = "덕분에 한시름 놓았어. 쥐들이 웅덩이 쪽으로 달아나던데… 거기 뭔가 큰 게 있나 봐. 스승님께 알려 드려.", exp = 320, gold = 150 },
	{ id = "m105", chapter = "ch1", title = "웅덩이의 주인", giver = "elder", giverName = "스승", kind = "boss", target = "GiantSlime", targetName = "거대 말랑이", count = 1, level = 9, text = "큰 웅덩이의 거대 말랑이를 쓰러뜨린다(1차 전직 시험).", offer = "큰 웅덩이에 거대한 말랑이가 나타났다. 들판의 이변은 그 녀석 탓이다. 쓰러뜨리면 너를 유파에 들이마.", done = "해냈구나! 이제 너는 견습이 아니다. 다섯 유파 가운데 네 길을 고를 때가 되었다.", exp = 1000, gold = 720 },
	{ id = "m106", chapter = "ch1", title = "1차 전직", giver = "elder", giverName = "스승", kind = "job", target = "1", targetName = "1차 전직", count = 1, level = 10, text = "스승에게서 유파를 골라 하닌이 된다.", offer = "불, 얼음, 풀, 바위, 번개. 다섯 문 가운데 하나를 골라라. 고르고 나면 다시 내게 말을 걸거라.", done = "오늘부터 너는 하닌이다. 이 두루마리로 인술을 갈고닦아라. 다음은 대나무 숲이다.", exp = 0, gold = 0, item = "SchoolScroll", itemCount = 1 },
	-- 2장 · 대숲의 속삭임 (Lv.10~20)
	{ id = "m201", chapter = "ch2", title = "숲 어귀의 찻집", giver = "elder", giverName = "스승", kind = "reach", target = "대숲 찻집", scene = nil, targetName = "대숲 찻집", count = 1, level = 10, text = "대숲 찻집 주인을 찾아간다.", offer = "대숲 찻집 주인을 찾아간다.", done = "수고했다.", exp = 165, gold = 0 },
	{ id = "m202", chapter = "ch2", title = "찻잎 도둑", giver = "teaMaster", giverName = "찻집 주인", kind = "kill", target = "Racoon", targetName = "너구리", count = 20, level = 12, text = "대숲 오솔길 3 · 깊은 대숲 1의 너구리 20마리.", offer = "대숲 오솔길 3 · 깊은 대숲 1의 너구리 20마리.", done = "수고했다.", exp = 520, gold = 230 },
	{ id = "m203", chapter = "ch2", title = "사당으로 가는 길", giver = "teaMaster", giverName = "찻집 주인", kind = "collect", target = "Branch", targetName = "나뭇가지", count = 15, level = 14, text = "나뭇가지 15개로 끊어진 다리를 고친다.", offer = "나뭇가지 15개로 끊어진 다리를 고친다.", done = "수고했다.", exp = 450, gold = 260 },
	{ id = "m204", chapter = "ch2", title = "밤의 눈", giver = "peddler", giverName = "떠돌이 상인", kind = "kill", target = "Owl", targetName = "부엉이", count = 20, level = 16, text = "깊은 대숲 3의 부엉이 20마리.", offer = "깊은 대숲 3의 부엉이 20마리.", done = "수고했다.", exp = 680, gold = 290 },
	{ id = "m205", chapter = "ch2", title = "풀의 봉인석", giver = "elder", giverName = "스승", kind = "boss", target = "GiantBamboo", targetName = "거대 대나무 정령", count = 1, level = 18, text = "대숲 사당의 거대 대나무 정령을 진정시킨다.", offer = "대숲 사당의 거대 대나무 정령을 진정시킨다.", done = "수고했다.", exp = 1900, gold = 1260, item = "GreenGem", itemCount = 1 },
	{ id = "m206", chapter = "ch2", title = "검은 발자국", giver = "teaMaster", giverName = "찻집 주인", kind = "talk", target = "elder", targetName = "스승", count = 1, level = 20, text = "사당에 남은 검은 두건 조각을 스승에게 보인다 — 쿠로의 이름을 처음 듣는다.", offer = "사당에 남은 검은 두건 조각을 스승에게 보인다 — 쿠로의 이름을 처음 듣는다.", done = "수고했다.", exp = 210, gold = 0 },
	-- 3장 · 안개 너머 (Lv.20~30)
	{ id = "m301", chapter = "ch3", title = "강을 따라", giver = "teaMaster", giverName = "찻집 주인", kind = "ride", target = "boat", targetName = "나룻배", count = 1, level = 20, text = "나룻배를 타고 갈대 나루로 간다.", offer = "나룻배를 타고 갈대 나루로 간다.", done = "수고했다.", exp = 315, gold = 0 },
	{ id = "m302", chapter = "ch3", title = "사라진 그물", giver = "kappaFisher", giverName = "갓파 어부", kind = "kill", target = "Fish", targetName = "뻐끔어", count = 25, level = 22, text = "맑은 개울 2 · 3의 뻐끔어 25마리.", offer = "맑은 개울 2 · 3의 뻐끔어 25마리.", done = "수고했다.", exp = 920, gold = 380 },
	{ id = "m303", chapter = "ch3", title = "늪의 약", giver = "herbalist", giverName = "약초꾼", kind = "collect", target = "Stone", targetName = "돌멩이", count = 20, level = 24, text = "돌멩이 20개(늪 약을 가는 맷돌).", offer = "돌멩이 20개(늪 약을 가는 맷돌).", done = "수고했다.", exp = 750, gold = 410, item = "Sushi", itemCount = 5 },
	{ id = "m304", chapter = "ch3", title = "안개 속의 다리", giver = "kappaFisher", giverName = "갓파 어부", kind = "kill", target = "Octopus", targetName = "문어", count = 25, level = 26, text = "안개 늪 2 · 3의 문어 25마리.", offer = "안개 늪 2 · 3의 문어 25마리.", done = "수고했다.", exp = 1080, gold = 440 },
	{ id = "m305", chapter = "ch3", title = "연못의 왕", giver = "elder", giverName = "스승", kind = "boss", target = "GiantFrog", targetName = "거대 두꺼비", count = 1, level = 28, text = "두꺼비 연못의 거대 두꺼비(2차 전직 시험).", offer = "두꺼비 연못의 거대 두꺼비(2차 전직 시험).", done = "수고했다.", exp = 2900, gold = 1860 },
	{ id = "m306", chapter = "ch3", title = "2차 전직", giver = "elder", giverName = "스승", kind = "job", target = "2", targetName = "2차 전직", count = 1, level = 30, text = "닌자 마을로 돌아가 중닌이 된다.", offer = "닌자 마을로 돌아가 중닌이 된다.", done = "수고했다.", exp = 0, gold = 0 },
	-- 4장 · 모래 위의 왕 (Lv.30~45)
	{ id = "m401", chapter = "ch4", title = "바람을 타고", giver = "kiteMaker", giverName = "연 장인", kind = "ride", target = "kite", targetName = "큰 연", count = 1, level = 30, text = "큰 연을 타고 오아시스 장터로 간다.", offer = "큰 연을 타고 오아시스 장터로 간다.", done = "수고했다.", exp = 465, gold = 0 },
	{ id = "m402", chapter = "ch4", title = "대상의 호위", giver = "caravan", giverName = "대상 상인", kind = "kill", target = "Snake2", targetName = "모래뱀", count = 30, level = 33, text = "모래 길 2 · 3의 모래뱀 30마리.", offer = "모래 길 2 · 3의 모래뱀 30마리.", done = "수고했다.", exp = 1360, gold = 540 },
	{ id = "m403", chapter = "ch4", title = "세공사의 주문", giver = "jeweler", giverName = "보석 세공사", kind = "collect", target = "IronBar", targetName = "철 주괴", count = 12, level = 36, text = "철 주괴 12개.", offer = "철 주괴 12개.", done = "수고했다.", exp = 1110, gold = 590, item = "GreenGem", itemCount = 2 },
	{ id = "m404", chapter = "ch4", title = "협곡의 거미줄", giver = "caravan", giverName = "대상 상인", kind = "kill", target = "SpiderYellow", targetName = "황금 거미", count = 30, level = 39, text = "바위 협곡 2 · 3의 황금 거미 30마리.", offer = "바위 협곡 2 · 3의 황금 거미 30마리.", done = "수고했다.", exp = 1600, gold = 630 },
	{ id = "m405", chapter = "ch4", title = "폭풍 속으로", giver = "elder", giverName = "스승", kind = "reach", target = "외눈 왕의 무덤", scene = nil, targetName = "외눈 왕의 무덤", count = 1, level = 42, text = "모래 폭풍 언덕을 지나 무덤에 닿는다.", offer = "모래 폭풍 언덕을 지나 무덤에 닿는다.", done = "수고했다.", exp = 645, gold = 0 },
	{ id = "m406", chapter = "ch4", title = "바위의 봉인석", giver = "elder", giverName = "스승", kind = "boss", target = "DemonCyclop", targetName = "외눈 도깨비 왕", count = 1, level = 45, text = "외눈 도깨비 왕을 쓰러뜨린다 — 봉인석은 이미 없다.", offer = "외눈 도깨비 왕을 쓰러뜨린다 — 봉인석은 이미 없다.", done = "수고했다.", exp = 4600, gold = 2880 },
	-- 5장 · 산마루의 시합 (Lv.45~60)
	{ id = "m501", chapter = "ch5", title = "눈 위의 날개", giver = "craneTamer", giverName = "두루미 조련사", kind = "ride", target = "crane", targetName = "두루미", count = 1, level = 45, text = "두루미를 타고 설산 암자로 간다.", offer = "두루미를 타고 설산 암자로 간다.", done = "수고했다.", exp = 690, gold = 0 },
	{ id = "m502", chapter = "ch5", title = "암자의 겨울 준비", giver = "hermit", giverName = "암자 수도승", kind = "kill", target = "Bear", targetName = "곰", count = 35, level = 48, text = "눈길 2 · 3의 곰 35마리.", offer = "눈길 2 · 3의 곰 35마리.", done = "수고했다.", exp = 1960, gold = 770 },
	{ id = "m503", chapter = "ch5", title = "얼어붙은 종", giver = "hermit", giverName = "암자 수도승", kind = "collect", target = "SilverBar", targetName = "은 주괴", count = 12, level = 51, text = "은 주괴 12개로 깨진 종을 고친다.", offer = "은 주괴 12개로 깨진 종을 고친다.", done = "수고했다.", exp = 1560, gold = 810 },
	{ id = "m504", chapter = "ch5", title = "동굴의 울음", giver = "hunter", giverName = "사냥꾼", kind = "boss", target = "GiantSpirit", targetName = "거대 유령", count = 1, level = 54, text = "얼음 동굴 2의 거대 유령.", offer = "얼음 동굴 2의 거대 유령.", done = "수고했다.", exp = 4125, gold = 2280 },
	{ id = "m505", chapter = "ch5", title = "텐구의 시합", giver = "tengu", giverName = "푸른 텐구", kind = "boss", target = "TenguBlue", targetName = "푸른 텐구", count = 1, level = 57, text = "산마루 사당에서 푸른 텐구와 겨룬다(3차 전직 시험).", offer = "산마루 사당에서 푸른 텐구와 겨룬다(3차 전직 시험).", done = "수고했다.", exp = 4350, gold = 2400 },
	{ id = "m506", chapter = "ch5", title = "3차 전직", giver = "elder", giverName = "스승", kind = "job", target = "3", targetName = "3차 전직", count = 1, level = 60, text = "텐구의 깃털을 들고 돌아가 상닌이 된다.", offer = "텐구의 깃털을 들고 돌아가 상닌이 된다.", done = "수고했다.", exp = 0, gold = 0 },
	-- 6장 · 불탄 고향 (Lv.60~75)
	{ id = "m601", chapter = "ch6", title = "등불 아래", giver = "scout", giverName = "정찰대장", kind = "reach", target = "등불 야영지", scene = nil, targetName = "등불 야영지", count = 1, level = 60, text = "산을 내려가 야영지에 합류한다.", offer = "산을 내려가 야영지에 합류한다.", done = "수고했다.", exp = 915, gold = 0 },
	{ id = "m602", chapter = "ch6", title = "길을 트다", giver = "scout", giverName = "정찰대장", kind = "kill", target = "Skull", targetName = "해골", count = 40, level = 63, text = "무너진 길 2 · 3의 해골 40마리.", offer = "무너진 길 2 · 3의 해골 40마리.", done = "수고했다.", exp = 2560, gold = 990 },
	{ id = "m603", chapter = "ch6", title = "무녀의 등불", giver = "hana", giverName = "하나", kind = "collect", target = "GoldBar", targetName = "금 주괴", count = 10, level = 66, text = "금 주괴 10개로 봉인의 등불을 만든다.", offer = "금 주괴 10개로 봉인의 등불을 만든다.", done = "수고했다.", exp = 2010, gold = 1040 },
	{ id = "m604", chapter = "ch6", title = "저택의 불", giver = "hana", giverName = "하나", kind = "boss", target = "GiantFlam", targetName = "거대 불꽃", count = 1, level = 69, text = "불탄 저택 1의 거대 불꽃.", offer = "불탄 저택 1의 거대 불꽃.", done = "수고했다.", exp = 5250, gold = 2880 },
	{ id = "m605", chapter = "ch6", title = "남겨진 일기", giver = "hana", giverName = "하나", kind = "reach", target = "저택 안뜰", scene = nil, targetName = "저택 안뜰", count = 1, level = 72, text = "쿠로의 옛집에서 일기를 찾는다 — 요괴에게 가족을 잃은 날의 기록.", offer = "쿠로의 옛집에서 일기를 찾는다 — 요괴에게 가족을 잃은 날의 기록.", done = "수고했다.", exp = 1095, gold = 0 },
	{ id = "m606", chapter = "ch6", title = "불의 봉인석", giver = "elder", giverName = "스승", kind = "boss", target = "TenguRed", targetName = "붉은 텐구", count = 1, level = 75, text = "저택 안뜰의 붉은 텐구.", offer = "저택 안뜰의 붉은 텐구.", done = "수고했다.", exp = 7600, gold = 4680, item = "RedGem", itemCount = 3 },
	-- 7장 · 번개의 탑 (Lv.75~90)
	{ id = "m701", chapter = "ch7", title = "탑의 문", giver = "towerKeeper", giverName = "탑지기", kind = "talk", target = "towerKeeper", targetName = "탑지기", count = 1, level = 75, text = "탑 아래 수련장에서 탑지기의 허락을 받는다.", offer = "탑 아래 수련장에서 탑지기의 허락을 받는다.", done = "수고했다.", exp = 760, gold = 0 },
	{ id = "m702", chapter = "ch7", title = "층마다 시험", giver = "towerKeeper", giverName = "탑지기", kind = "kill", target = "SkullBlue", targetName = "푸른 해골", count = 45, level = 78, text = "탑 2 · 3층의 푸른 해골 45마리.", offer = "탑 2 · 3층의 푸른 해골 45마리.", done = "수고했다.", exp = 3160, gold = 1220 },
	{ id = "m703", chapter = "ch7", title = "수조의 괴물", giver = "trainee", giverName = "수련생", kind = "boss", target = "SquidRed", targetName = "붉은 대왕오징어", count = 1, level = 81, text = "탑 5층 수조의 붉은 대왕오징어.", offer = "탑 5층 수조의 붉은 대왕오징어.", done = "수고했다.", exp = 6150, gold = 3360 },
	{ id = "m704", chapter = "ch7", title = "지하의 포효", giver = "towerKeeper", giverName = "탑지기", kind = "kill", target = "TRex", targetName = "폭군 도마뱀", count = 45, level = 84, text = "탑 지하 3 · 4의 폭군 도마뱀 45마리.", offer = "탑 지하 3 · 4의 폭군 도마뱀 45마리.", done = "수고했다.", exp = 3400, gold = 1310 },
	{ id = "m705", chapter = "ch7", title = "번개의 봉인석", giver = "elder", giverName = "스승", kind = "boss", target = "GiantBlueSamurai", targetName = "탑의 수호 무사", count = 1, level = 87, text = "탑 꼭대기의 수호 무사.", offer = "탑 꼭대기의 수호 무사.", done = "수고했다.", exp = 8800, gold = 5400, item = "YellowGem", itemCount = 3 },
	{ id = "m706", chapter = "ch7", title = "다섯 조각", giver = "hana", giverName = "하나", kind = "talk", target = "elder", targetName = "스승", count = 1, level = 90, text = "쿠로가 다섯 봉인석을 모두 가져갔음을 알린다 — 하늘배를 띄운다.", offer = "쿠로가 다섯 봉인석을 모두 가져갔음을 알린다 — 하늘배를 띄운다.", done = "수고했다.", exp = 910, gold = 0 },
	-- 8장 · 오문 닌자 (Lv.90~100)
	{ id = "m801", chapter = "ch8", title = "구름 위로", giver = "captain", giverName = "선장", kind = "ride", target = "skyship", targetName = "하늘배", count = 1, level = 90, text = "닌자 마을 절벽 선착장에서 하늘배를 탄다.", offer = "닌자 마을 절벽 선착장에서 하늘배를 탄다.", done = "수고했다.", exp = 1365, gold = 0 },
	{ id = "m802", chapter = "ch8", title = "용암을 건너", giver = "captain", giverName = "선장", kind = "kill", target = "Snake3", targetName = "붉은 뱀", count = 50, level = 92, text = "용암 계곡 1 · 2의 붉은 뱀 50마리.", offer = "용암 계곡 1 · 2의 붉은 뱀 50마리.", done = "수고했다.", exp = 3720, gold = 1430 },
	{ id = "m803", chapter = "ch8", title = "용의 비늘", giver = "hana", giverName = "하나", kind = "collect", target = "MithrilBar", targetName = "미스릴 주괴", count = 10, level = 94, text = "미스릴 주괴 10개로 봉인의 사슬을 만든다.", offer = "미스릴 주괴 10개로 봉인의 사슬을 만든다.", done = "수고했다.", exp = 2850, gold = 1460 },
	{ id = "m804", chapter = "ch8", title = "쿠로", giver = "elder", giverName = "스승", kind = "boss", target = "GiantRedSamurai", targetName = "타락한 쿠로", count = 1, level = 96, text = "용의 뜰 3 — 요괴왕의 힘에 먹힌 쿠로(붉은 거대 사무라이).", offer = "용의 뜰 3 — 요괴왕의 힘에 먹힌 쿠로(붉은 거대 사무라이).", done = "수고했다.", exp = 9700, gold = 5940 },
	{ id = "m805", chapter = "ch8", title = "4차 전직", giver = "elder", giverName = "스승", kind = "job", target = "4", targetName = "4차 전직", count = 1, level = 100, text = "쿠로가 돌려준 다섯 봉인석 앞에서 닌자 마스터가 된다(Lv.100).", offer = "쿠로가 돌려준 다섯 봉인석 앞에서 닌자 마스터가 된다(Lv.100).", done = "수고했다.", exp = 0, gold = 0 },
	{ id = "m806", chapter = "ch8", title = "요괴왕 야마타", giver = "elder", giverName = "스승", kind = "boss", target = "DragonBlue", targetName = "요괴왕 야마타", count = 1, level = 100, text = "용의 왕좌에서 요괴왕을 다시 가둔다.", offer = "용의 왕좌에서 요괴왕을 다시 가둔다.", done = "수고했다.", exp = 10100, gold = 6180, item = "PurpleGem", itemCount = 5 },
}

end
MODULES['ReplicatedStorage/shared/data/townWorld.generated'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 자동 생성 파일 — 직접 고치지 말 것.
-- 만든 곳: C:/YJS/Roblox/dino-workshop/tools/export_ninja.mjs (「오문 닌자전」 — Ninja Adventure 팩 + js/ninja 맵 정의)
-- 좌표 단위는 "도트"(바닥 타일 1칸 = 16도트). 화면에서는 1도트 = scale px(바닥·캐릭터·몬스터 모두 같은 크기).
return {
	tile = 16,
	scale = 4, -- 바닥 1도트 = 화면 px
	monsterScale = 4,
	charScale = 4,
	fine = 4, -- 충돌 격자 한 칸 = fine x fine 도트
	playerFeet = { halfW = 3, h = 3 },
	monsterFeet = { halfW = 4, h = 3 },
	playerSpeed = 60,
	monsterSpeed = 12,
	monsterRoam = 48, -- 나타난 자리에서 이 반경(도트) 안을 자유롭게 돌아다닌다
	monsterWait = {
	0.6,
	2.2,
}, -- 한 번 걸은 뒤 쉬는 시간(초) 범위
	objectAtlas = { w = 512, h = 48 },
	-- 몬스터: 종마다 block x block 덩어리(한 줄에 perRow종). 덩어리 안 = 열(아래 0 · 위 1 · 왼 2 · 오 3) × 줄(걷기 4장).
	monsterSheet = { cellW = 16, cellH = 16, block = 64, perRow = 16, dirs = 4, steps = 4, sheets = 1 },
	-- 플레이어: 유파마다 4줄(아래·위·왼·오), 칸 = 걷기 walk장 + 공격 attack장. 발바닥 = 칸 위에서 feetY 도트. 공격 판정은 hitFrame번째 장.
	playerSheet = { cellW = 16, cellH = 16, walk = 4, attack = 4, hitFrame = 2, feetY = 16, schools = 5 },
	schools = {
		{ id = "fire", name = "불" },
		{ id = "ice", name = "얼음" },
		{ id = "plant", name = "풀" },
		{ id = "rock", name = "바위" },
		{ id = "thunder", name = "번개" },
	},
	-- NPC: 역할마다 한 줄(row), 칸 = 대기 frames장. 씬의 npcs = { type, row, name, x, y(발 위치 도트) }.
	npcSheet = { cellW = 16, cellH = 16, frames = 2, feetY = 16 },
	npcFeet = { halfW = 5, h = 4 },
	npcTypes = {
		{ id = "elder", name = "스승", role = "유파 · 인술 · 승급 시험" },
		{ id = "blacksmith", name = "대장장이", role = "무기 강화" },
		{ id = "merchant", name = "잡화상", role = "투척 무기 · 잡화" },
		{ id = "potion", name = "약방 주인", role = "물약 · 음식" },
		{ id = "healer", name = "수도승", role = "체력 회복" },
		{ id = "storage", name = "창고지기", role = "아이템 맡기기" },
		{ id = "villagerMan", name = "마을 사람", role = "일반인" },
		{ id = "villagerOld", name = "할아버지", role = "일반인" },
		{ id = "noble", name = "영주", role = "일반인" },
	},
	rects = {
		bigtree = { x = 0, y = 0, w = 48, h = 48 },
		house = { x = 49, y = 0, w = 64, h = 48 },
		houseFlat = { x = 114, y = 0, w = 64, h = 48 },
		house2 = { x = 179, y = 0, w = 64, h = 48 },
		houseRed = { x = 244, y = 0, w = 64, h = 48 },
		shop = { x = 309, y = 0, w = 48, h = 48 },
		tree = { x = 358, y = 0, w = 32, h = 32 },
		tree2 = { x = 391, y = 0, w = 32, h = 32 },
		pine = { x = 424, y = 0, w = 32, h = 32 },
		bush = { x = 457, y = 0, w = 16, h = 16 },
		bush2 = { x = 474, y = 0, w = 16, h = 16 },
	},
	-- 지역(사냥터 레벨대) — 몬스터의 element가 이 id를 가리킨다(도감 탭)
	regions = {
		{ id = "field", name = "새싹 들판", levelMin = 1, levelMax = 10 },
		{ id = "bamboo", name = "대나무 숲", levelMin = 10, levelMax = 20 },
		{ id = "swamp", name = "개울과 늪", levelMin = 20, levelMax = 30 },
		{ id = "desert", name = "모래 사막", levelMin = 30, levelMax = 45 },
		{ id = "snow", name = "눈 덮인 산", levelMin = 45, levelMax = 60 },
		{ id = "ruins", name = "버려진 마을", levelMin = 60, levelMax = 75 },
		{ id = "tower", name = "수련의 탑", levelMin = 75, levelMax = 90 },
		{ id = "nest", name = "용의 둥지", levelMin = 90, levelMax = 100 },
	},
	-- levelMin~levelMax: 종마다 자연 스폰 레벨 범위. element = 사는 지역 id.
	species = {
		{ id = "Slime", name = "말랑이", element = "field", levelMin = 1, levelMax = 4 },
		{ id = "Mushroom", name = "버섯돌이", element = "field", levelMin = 2, levelMax = 6 },
		{ id = "Larva", name = "애벌레", element = "field", levelMin = 3, levelMax = 7 },
		{ id = "Butterfly", name = "팔랑나비", element = "field", levelMin = 4, levelMax = 8 },
		{ id = "Mouse", name = "도토리쥐", element = "field", levelMin = 5, levelMax = 10 },
		{ id = "Slime2", name = "숲 말랑이", element = "bamboo", levelMin = 10, levelMax = 13 },
		{ id = "Bamboo", name = "대나무 정령", element = "bamboo", levelMin = 10, levelMax = 14 },
		{ id = "Racoon", name = "너구리", element = "bamboo", levelMin = 11, levelMax = 15 },
		{ id = "Snake", name = "풀뱀", element = "bamboo", levelMin = 12, levelMax = 16 },
		{ id = "Mole", name = "두더지", element = "bamboo", levelMin = 14, levelMax = 18 },
		{ id = "Owl", name = "부엉이", element = "bamboo", levelMin = 16, levelMax = 20 },
		{ id = "Axolot", name = "우파루", element = "swamp", levelMin = 20, levelMax = 24 },
		{ id = "Fish", name = "뻐끔어", element = "swamp", levelMin = 21, levelMax = 25 },
		{ id = "Mollusc", name = "소라게", element = "swamp", levelMin = 22, levelMax = 26 },
		{ id = "GreenOctopus", name = "늪 문어", element = "swamp", levelMin = 23, levelMax = 27 },
		{ id = "Octopus", name = "문어", element = "swamp", levelMin = 24, levelMax = 28 },
		{ id = "KappaGreen", name = "갓파", element = "swamp", levelMin = 26, levelMax = 30 },
		{ id = "Lizard", name = "도마뱀", element = "desert", levelMin = 30, levelMax = 35 },
		{ id = "Snake2", name = "모래뱀", element = "desert", levelMin = 31, levelMax = 36 },
		{ id = "Reptile", name = "사막 파충류", element = "desert", levelMin = 32, levelMax = 37 },
		{ id = "Mole2", name = "모래 두더지", element = "desert", levelMin = 33, levelMax = 38 },
		{ id = "SpiderYellow", name = "황금 거미", element = "desert", levelMin = 34, levelMax = 39 },
		{ id = "Cyclope", name = "외눈박이", element = "desert", levelMin = 36, levelMax = 41 },
		{ id = "Beast", name = "사막 야수", element = "desert", levelMin = 40, levelMax = 45 },
		{ id = "Slime3", name = "눈 말랑이", element = "snow", levelMin = 45, levelMax = 49 },
		{ id = "Bear", name = "곰", element = "snow", levelMin = 45, levelMax = 50 },
		{ id = "AxolotBlue", name = "얼음 우파루", element = "snow", levelMin = 46, levelMax = 51 },
		{ id = "Panda", name = "판다", element = "snow", levelMin = 47, levelMax = 52 },
		{ id = "BlueBat", name = "푸른 박쥐", element = "snow", levelMin = 48, levelMax = 53 },
		{ id = "Spirit", name = "유령", element = "snow", levelMin = 52, levelMax = 57 },
		{ id = "Owl2", name = "눈 부엉이", element = "snow", levelMin = 54, levelMax = 60 },
		{ id = "MouseBlack", name = "검은 쥐", element = "ruins", levelMin = 60, levelMax = 64 },
		{ id = "Skull", name = "해골", element = "ruins", levelMin = 60, levelMax = 65 },
		{ id = "LanternGreen", name = "도깨비 등불", element = "ruins", levelMin = 61, levelMax = 66 },
		{ id = "Eye", name = "눈알 요괴", element = "ruins", levelMin = 63, levelMax = 68 },
		{ id = "HeartGreen", name = "독 심장", element = "ruins", levelMin = 65, levelMax = 70 },
		{ id = "SpiderRed", name = "붉은 거미", element = "ruins", levelMin = 66, levelMax = 71 },
		{ id = "Flam", name = "불꽃 요괴", element = "ruins", levelMin = 68, levelMax = 73 },
		{ id = "Spirit2", name = "원령", element = "ruins", levelMin = 70, levelMax = 75 },
		{ id = "Larva2", name = "탑 애벌레", element = "tower", levelMin = 75, levelMax = 78 },
		{ id = "YellowsBat", name = "황금 박쥐", element = "tower", levelMin = 75, levelMax = 79 },
		{ id = "SkullBlue", name = "푸른 해골", element = "tower", levelMin = 75, levelMax = 80 },
		{ id = "LanternRed", name = "붉은 등불", element = "tower", levelMin = 76, levelMax = 81 },
		{ id = "Eye2", name = "붉은 눈알", element = "tower", levelMin = 78, levelMax = 83 },
		{ id = "KappaRed", name = "붉은 갓파", element = "tower", levelMin = 79, levelMax = 84 },
		{ id = "Cyclope2", name = "붉은 외눈박이", element = "tower", levelMin = 80, levelMax = 85 },
		{ id = "Dragon", name = "새끼 용", element = "tower", levelMin = 82, levelMax = 88 },
		{ id = "TRex", name = "폭군 도마뱀", element = "tower", levelMin = 84, levelMax = 90 },
		{ id = "Beast2", name = "지하 야수", element = "tower", levelMin = 85, levelMax = 90 },
		{ id = "Slime4", name = "용암 말랑이", element = "nest", levelMin = 90, levelMax = 94 },
		{ id = "Mollusc2", name = "용암 소라게", element = "nest", levelMin = 90, levelMax = 94 },
		{ id = "Mushroom2", name = "독버섯", element = "nest", levelMin = 90, levelMax = 94 },
		{ id = "HeartRed", name = "불 심장", element = "nest", levelMin = 90, levelMax = 95 },
		{ id = "Snake3", name = "붉은 뱀", element = "nest", levelMin = 90, levelMax = 95 },
		{ id = "Lizard2", name = "불 도마뱀", element = "nest", levelMin = 90, levelMax = 95 },
		{ id = "ButterflyBlue", name = "푸른 나비", element = "nest", levelMin = 91, levelMax = 95 },
		{ id = "FishRed", name = "붉은 뻐끔어", element = "nest", levelMin = 91, levelMax = 95 },
		{ id = "Flam2", name = "푸른 불꽃", element = "nest", levelMin = 91, levelMax = 96 },
		{ id = "Octopus2", name = "심해 문어", element = "nest", levelMin = 91, levelMax = 96 },
		{ id = "BambooYellow", name = "황금 대나무", element = "nest", levelMin = 92, levelMax = 96 },
		{ id = "Snake4", name = "검은 뱀", element = "nest", levelMin = 92, levelMax = 97 },
		{ id = "Reptile2", name = "용 파충류", element = "nest", levelMin = 92, levelMax = 97 },
		{ id = "RedOctopus", name = "붉은 문어", element = "nest", levelMin = 93, levelMax = 98 },
		{ id = "GreyTrex", name = "회색 폭군", element = "nest", levelMin = 93, levelMax = 99 },
		{ id = "DragonYellow", name = "황금 용", element = "nest", levelMin = 94, levelMax = 100 },
		{ id = "GoldRacoon", name = "황금 너구리", element = "nest", levelMin = 95, levelMax = 100 },
	},
	start = "village",
	-- 씬: blocked는 충돌 격자(1 = 못 지나감), objects는 원래 크기 기준 위치 + 그리기 배율(scale),
	-- zones는 몬스터 스폰 구역(도트 사각형, species는 종 번호), portals.to는 도착 씬 키, outside는 맵 바깥 색.
	scenes = {
		village = {
			name = "닌자 마을", w = 30, h = 22, indoor = false,
			outside = { 173, 188, 58 },
			ground = { w = 480, h = 352 },
			spawn = { x = 240, y = 198 },
			blocked = {
				"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"011110011110011110001111000111100011110011110001111001111001111001111000111100111100111100011110001111001111011110000111",
				"011110011110011110001111000111100011110011110001111001111001111001111000111100111100111100011110001111001111011110000111",
				"011110011110011110001111000111100000000011110001111001111001111001111000111100111100111100011110001111001111011110000111",
				"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"000000000001111000000000000000111100111100000000001111000000001111000000000111100000000011110011110000000000000001111001",
				"000001111001111001111001111000111100111100111100001111001111001111000111100111100011110011110011110001111011110001111001",
				"000001111001111001111001111000111100111100111100001111001111001111000111100111100011110011110011110001111011110001111001",
				"000001111000000001111001111000000000000000111100000000001111000000000111100000000011110000000000000001111011110000000000",
				"001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"001111011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"011110000000000000000000000011100000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"011110011110000000000000000011100000000000000000000000000000000000000000000000000000000000000000000000000000001111011110",
				"000000011110000000000000000011100000000000000000000000000000000000000000000000000000000000000000000000000000001111011110",
				"000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"011110000000000000000000000000000000000000011100000000000000000000000000000000000000000000000000000000000000000000011110",
				"011110000000000000000000000000000000000000011100000000000000000000000000000000000011100000000000000000000000000000011110",
				"011110000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000000000011110",
				"000000011110000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000011110000000",
				"000000011110000000000000000000000000111000000000000000000000000000000000000000000000000000001110000000000000011110000000",
				"001111011110000000000000000000000000111000000000000000000000000000000000000000000000000000001110000000000000011110000000",
				"001111000000000000000000000000000000000000000000000011111111111111110000000000000000000000001110000000000000000000111100",
				"001111000000000000000000000000000000000000000000000011111111111111110000000000000000000000000000000000000000001111111100",
				"000000011110000000000000000000000000000000000000000011111111111111110000000000000000000000000000000000000000001111111100",
				"000000011110000000000000000000000000000000000000000011111111111111110000111000000000000000000000000000000000001111000000",
				"000000011110000011111111111111110000000000000000000011111111111111110000111000000000000000111111111111000000000000000000",
				"001111000000000011111111111111110000000000000000000011111111111111110000111000000000000000111111111111000000000000111100",
				"001111000000000011111111111111110000000000000000000011111111111111110000000000000000000000111111111111000000000000111100",
				"001111011110000011111111111111110000000000000000000011111111111111110000000000000000000000111111111111000000000000111100",
				"000000011110000011111111111111110000000000000000000000000000000000000000000000000011100000111111111111000000011110000000",
				"000000011110000011111111111111110000000000000000000000000000000000000000000000000011100000111111111111000000011110000000",
				"011110000000000011111111111111110000000000000000000000000000000000000000000000000011100000111111111111000000011110011110",
				"011110000000000011111111111111110000000000000000000000000011110000000000000000000000000000111111111111000000000000011110",
				"011110000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000011110",
				"000000011110000000000000000000000111000000000000000000000000000000000000000000000000011100000000000000000000011110000000",
				"000000011110000000000000000000000111000000000000000000000000000000000000000000000000011100000000000000000000011110000000",
				"001111011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"001111011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"001111011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"001111011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"000000011110000000000000000000000000000000000000000000000000000000000000111000000000000000000000000000000000011110000000",
				"000000011110000000000000000000000000111100000000000000000000000000000000111000000000000000000000000000000000011110111100",
				"001111000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"001111000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000111100",
				"001111000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000011110000000",
				"000000011110000000000000000000000000000000000000011100000000000000000000000000000000000000000000000000000000011110000000",
				"001111011110000000000000000000000000000000000000011100000000000000000000000000000000000000000000000000000000011110000000",
				"001111011110000011111111111111110000000000000000011100000000000000000000000000000000000011111111111111110000000000011110",
				"001111000000000011111111111111110000000000000000000000000000000000000000000000000000000011111111111111110000000000011110",
				"000000011110000011111111111111110000000000000000000000000000000000000000000000000000000011111111111111110000000000011110",
				"000000011110000011111111111111110000000000000000000000000000000000000000000000000000000011111111111111110000001111000000",
				"000000011110000011111111111111110000000000000000000000000000000000000000000000000000000011111111111111110000001111000000",
				"001111000000000011111111111111110011110000000000000000000000000000000000000000000011110011111111111111110000001111011110",
				"001111000000000011111111111111110011110000000000000000000000000000000000000000000011110011111111111111110000000000011110",
				"001111000000000011111111111111110000000000000000000000000000000000000000000000000000000011111111111111110000001111011110",
				"000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"000000111100000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000001111000000",
				"001111111100000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000",
				"001111000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000111100",
				"001111011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"000001111001111000000000000000000000000000000000000000000000000000001111000000000111100000000001111000000000000001111000",
				"000001111001111001111000111100111100111100011110000000000000000000001111000111100111100011110001111011110011110001111000",
				"000001111001111001111000111100111100111100011110000000000000000000001111000111100111100011110001111011110011110001111000",
				"000000000000000001111000111100111100111100011110000000000000000000000000000111100000000011110000000011110011110000000000",
				"001111011110000000000000001111000000000111100011110000000000000000000001111000000000000000000000011110000000000000001111",
				"001111011110001111000111101111000111100111100011110000000000000000000001111001111000111100111100011110011110011110001111",
				"001111011110001111000111101111000111100111100011110000000000000000000001111001111000111100111100011110011110011110001111",
				"000000000000001111000111100000000111100000000000000000000000000000000000000001111000111100111100000000011110011110000000",
			},
			objects = {
				{ id = "house", x = 208, y = 96, bottom = 144, scale = 4 },
				{ id = "houseRed", x = 64, y = 112, bottom = 160, scale = 4 },
				{ id = "shop", x = 360, y = 112, bottom = 160, scale = 4 },
				{ id = "house2", x = 64, y = 240, bottom = 288, scale = 4 },
				{ id = "houseFlat", x = 352, y = 240, bottom = 288, scale = 4 },
				{ id = "tree", x = -5, y = -7, bottom = 25, scale = 4 },
				{ id = "tree", x = 11, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = -2, y = 315, bottom = 347, scale = 4 },
				{ id = "tree", x = 11, y = 300, bottom = 332, scale = 4 },
				{ id = "tree2", x = 21, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 35, y = 11, bottom = 43, scale = 4 },
				{ id = "tree", x = 22, y = 315, bottom = 347, scale = 4 },
				{ id = "tree", x = 37, y = 299, bottom = 331, scale = 4 },
				{ id = "tree2", x = 46, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 60, y = 13, bottom = 45, scale = 4 },
				{ id = "pine", x = 49, y = 319, bottom = 351, scale = 4 },
				{ id = "tree", x = 60, y = 302, bottom = 334, scale = 4 },
				{ id = "tree", x = 72, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 85, y = 13, bottom = 45, scale = 4 },
				{ id = "pine", x = 76, y = 318, bottom = 350, scale = 4 },
				{ id = "tree", x = 86, y = 301, bottom = 333, scale = 4 },
				{ id = "tree", x = 99, y = -8, bottom = 24, scale = 4 },
				{ id = "tree", x = 112, y = 9, bottom = 41, scale = 4 },
				{ id = "pine", x = 97, y = 315, bottom = 347, scale = 4 },
				{ id = "tree", x = 111, y = 301, bottom = 333, scale = 4 },
				{ id = "tree2", x = 128, y = -8, bottom = 24, scale = 4 },
				{ id = "tree", x = 135, y = 11, bottom = 43, scale = 4 },
				{ id = "tree2", x = 124, y = 318, bottom = 350, scale = 4 },
				{ id = "tree", x = 136, y = 301, bottom = 333, scale = 4 },
				{ id = "tree", x = 151, y = -7, bottom = 25, scale = 4 },
				{ id = "tree", x = 160, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 147, y = 316, bottom = 348, scale = 4 },
				{ id = "tree2", x = 165, y = 300, bottom = 332, scale = 4 },
				{ id = "tree2", x = 179, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 191, y = 9, bottom = 41, scale = 4 },
				{ id = "tree", x = 175, y = 315, bottom = 347, scale = 4 },
				{ id = "tree2", x = 204, y = -6, bottom = 26, scale = 4 },
				{ id = "pine", x = 215, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 228, y = -7, bottom = 25, scale = 4 },
				{ id = "tree", x = 241, y = 10, bottom = 42, scale = 4 },
				{ id = "tree", x = 253, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 266, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 266, y = 299, bottom = 331, scale = 4 },
				{ id = "pine", x = 280, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 291, y = 11, bottom = 43, scale = 4 },
				{ id = "tree", x = 275, y = 315, bottom = 347, scale = 4 },
				{ id = "tree", x = 292, y = 303, bottom = 335, scale = 4 },
				{ id = "tree2", x = 303, y = -4, bottom = 28, scale = 4 },
				{ id = "tree2", x = 319, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 302, y = 318, bottom = 350, scale = 4 },
				{ id = "tree2", x = 316, y = 299, bottom = 331, scale = 4 },
				{ id = "tree2", x = 330, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 343, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 330, y = 317, bottom = 349, scale = 4 },
				{ id = "tree", x = 344, y = 302, bottom = 334, scale = 4 },
				{ id = "pine", x = 357, y = -8, bottom = 24, scale = 4 },
				{ id = "tree", x = 369, y = 12, bottom = 44, scale = 4 },
				{ id = "tree", x = 354, y = 318, bottom = 350, scale = 4 },
				{ id = "tree", x = 370, y = 299, bottom = 331, scale = 4 },
				{ id = "tree", x = 384, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 397, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 380, y = 316, bottom = 348, scale = 4 },
				{ id = "pine", x = 391, y = 301, bottom = 333, scale = 4 },
				{ id = "tree", x = 407, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 417, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 403, y = 319, bottom = 351, scale = 4 },
				{ id = "tree", x = 417, y = 300, bottom = 332, scale = 4 },
				{ id = "tree", x = 430, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 443, y = 10, bottom = 42, scale = 4 },
				{ id = "tree2", x = 430, y = 318, bottom = 350, scale = 4 },
				{ id = "tree", x = 445, y = 299, bottom = 331, scale = 4 },
				{ id = "tree2", x = 459, y = -4, bottom = 28, scale = 4 },
				{ id = "tree", x = 469, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 456, y = 315, bottom = 347, scale = 4 },
				{ id = "tree", x = 471, y = 301, bottom = 333, scale = 4 },
				{ id = "tree", x = -1, y = 27, bottom = 59, scale = 4 },
				{ id = "pine", x = 20, y = 35, bottom = 67, scale = 4 },
				{ id = "tree", x = 451, y = 27, bottom = 59, scale = 4 },
				{ id = "tree", x = 429, y = 37, bottom = 69, scale = 4 },
				{ id = "tree", x = -3, y = 47, bottom = 79, scale = 4 },
				{ id = "pine", x = 22, y = 55, bottom = 87, scale = 4 },
				{ id = "tree", x = 451, y = 49, bottom = 81, scale = 4 },
				{ id = "pine", x = 432, y = 56, bottom = 88, scale = 4 },
				{ id = "tree", x = -3, y = 67, bottom = 99, scale = 4 },
				{ id = "tree", x = 18, y = 77, bottom = 109, scale = 4 },
				{ id = "tree2", x = 451, y = 68, bottom = 100, scale = 4 },
				{ id = "tree2", x = 430, y = 77, bottom = 109, scale = 4 },
				{ id = "tree2", x = 2, y = 86, bottom = 118, scale = 4 },
				{ id = "tree", x = 21, y = 96, bottom = 128, scale = 4 },
				{ id = "pine", x = 447, y = 90, bottom = 122, scale = 4 },
				{ id = "tree", x = 432, y = 95, bottom = 127, scale = 4 },
				{ id = "tree2", x = -2, y = 111, bottom = 143, scale = 4 },
				{ id = "tree2", x = 18, y = 119, bottom = 151, scale = 4 },
				{ id = "tree", x = 450, y = 111, bottom = 143, scale = 4 },
				{ id = "tree", x = 429, y = 121, bottom = 153, scale = 4 },
				{ id = "pine", x = -3, y = 132, bottom = 164, scale = 4 },
				{ id = "tree", x = 22, y = 141, bottom = 173, scale = 4 },
				{ id = "tree2", x = 452, y = 130, bottom = 162, scale = 4 },
				{ id = "tree", x = 429, y = 141, bottom = 173, scale = 4 },
				{ id = "pine", x = -2, y = 149, bottom = 181, scale = 4 },
				{ id = "pine", x = 17, y = 162, bottom = 194, scale = 4 },
				{ id = "pine", x = 449, y = 151, bottom = 183, scale = 4 },
				{ id = "tree", x = 431, y = 162, bottom = 194, scale = 4 },
				{ id = "pine", x = -2, y = 172, bottom = 204, scale = 4 },
				{ id = "tree", x = 22, y = 180, bottom = 212, scale = 4 },
				{ id = "tree", x = 447, y = 169, bottom = 201, scale = 4 },
				{ id = "tree", x = 428, y = 181, bottom = 213, scale = 4 },
				{ id = "pine", x = 1, y = 194, bottom = 226, scale = 4 },
				{ id = "tree2", x = 18, y = 201, bottom = 233, scale = 4 },
				{ id = "pine", x = 448, y = 191, bottom = 223, scale = 4 },
				{ id = "tree", x = 427, y = 201, bottom = 233, scale = 4 },
				{ id = "tree2", x = 0, y = 214, bottom = 246, scale = 4 },
				{ id = "pine", x = 20, y = 225, bottom = 257, scale = 4 },
				{ id = "tree", x = 448, y = 211, bottom = 243, scale = 4 },
				{ id = "tree", x = 426, y = 220, bottom = 252, scale = 4 },
				{ id = "tree2", x = -1, y = 232, bottom = 264, scale = 4 },
				{ id = "pine", x = 19, y = 243, bottom = 275, scale = 4 },
				{ id = "pine", x = 451, y = 235, bottom = 267, scale = 4 },
				{ id = "tree", x = 430, y = 245, bottom = 277, scale = 4 },
				{ id = "tree2", x = -2, y = 254, bottom = 286, scale = 4 },
				{ id = "tree2", x = 18, y = 264, bottom = 296, scale = 4 },
				{ id = "tree2", x = 451, y = 253, bottom = 285, scale = 4 },
				{ id = "tree2", x = 430, y = 264, bottom = 296, scale = 4 },
				{ id = "tree", x = 1, y = 274, bottom = 306, scale = 4 },
				{ id = "tree", x = 21, y = 283, bottom = 315, scale = 4 },
				{ id = "pine", x = 450, y = 277, bottom = 309, scale = 4 },
				{ id = "pine", x = 430, y = 284, bottom = 316, scale = 4 },
				{ id = "bush", x = 142, y = 95, bottom = 111, scale = 4 },
				{ id = "bush2", x = 365, y = 97, bottom = 113, scale = 4 },
				{ id = "bush", x = 170, y = 78, bottom = 94, scale = 4 },
				{ id = "bush2", x = 163, y = 285, bottom = 301, scale = 4 },
				{ id = "bush", x = 286, y = 116, bottom = 132, scale = 4 },
				{ id = "bush2", x = 326, y = 137, bottom = 153, scale = 4 },
				{ id = "bush", x = 325, y = 85, bottom = 101, scale = 4 },
				{ id = "bush", x = 144, y = 224, bottom = 240, scale = 4 },
				{ id = "bush2", x = 111, y = 66, bottom = 82, scale = 4 },
				{ id = "bush", x = 194, y = 240, bottom = 256, scale = 4 },
			},
			zones = {},
			portals = {
				{ name = "새싹 들판 1 가는 길", x0 = 224, y0 = 336, x1 = 256, y1 = 352, to = "field1", arrive = "door" },
			},
			mons = {},
			npcs = {
				{ type = "elder", row = 1, name = "스승", x = 240, y = 163 },
				{ type = "blacksmith", row = 2, name = "대장장이", x = 138, y = 170 },
				{ type = "merchant", row = 3, name = "잡화상", x = 346, y = 170 },
				{ type = "potion", row = 4, name = "약방 주인", x = 144, y = 282 },
				{ type = "storage", row = 6, name = "창고지기", x = 336, y = 282 },
				{ type = "healer", row = 5, name = "수도승", x = 294, y = 234 },
				{ type = "villagerOld", row = 8, name = "할아버지", x = 182, y = 246 },
			},
		},
		field1 = {
			name = "새싹 들판 1", w = 40, h = 30, indoor = false,
			outside = { 173, 188, 58 },
			ground = { w = 640, h = 480 },
			spawn = { x = 320, y = 42 },
			blocked = {
				"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"0111100111100000000000000001111001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"0111100111100001111001111001111001111000111100111100111100111100001111000000000000000000001111000111100111100001111011110011110001111000111100111100011110011110",
				"0111100111100001111001111001111001111000111100111100111100111100001111000000000000000000001111000111100111100001111011110011110001111000111100111100011110011110",
				"0000000000000001111001111000000000000000111100111100111100111100001111000000000000000000001111000111100111100001111011110011110001111000111100111100011110011110",
				"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"0000000000000000011110001111000000000000000000000011110000000011110000000000000000000000000000111100111100000000011110000000000111100000000111100000000111100011",
				"0000111100011110011110001111001111001111000111100011110111100011110000000000000000000000000000111100111100011110011110001111000111100111100111100111100111100011",
				"0000111100011110011110001111001111001111000111100011110111100011110000000000000000000000000000111100111100011110011110001111000111100111100111100111100111100011",
				"0000111100011110000000000000001111001111000111100000000111100000000000000000000000000000000000000000000000011110000000001111000000000111100000000111100000000000",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0000000111100000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0000000111100000000011110000000000000000000000011100000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000000000000000000000",
				"0111100000000000000011110000000000000000000000011100000000000000000000000000000000000111110000000000000000000000000000000000000000000000000011100000000000111100",
				"0111100000000000000000000000000000000000000000011100000000000000000000000000000000000111110000000000000000000000000000000000000000000000000011100000000000111100",
				"0111100111100000000000000000000000000000000000000000000000000000000000001110000000000111110000000000000000000000000000000000000000000000000011100000011110111100",
				"0000000111100000000000000000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0011110111100000000000000011100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0011110000000000000000000011100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000011110",
				"0011110000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000011110",
				"0000000111100000000000000000000000000111100000000000011111000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000001111011110",
				"0000000111100000000000000000000000000111100000000000011111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0000000111100000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000001111000000",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111000011100000000000000111100",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111000000000000000000000111100",
				"0111100111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111000000000000000000000111100",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111000000000000000011110000000",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000000000000000011110111100",
				"0011110000000000000000000000000000000000001110000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000000000000000000000111100",
				"0011110000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"0000000111100000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000011110000000",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000001111000000000000000000000000000000011110000000",
				"0111100111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000001111000000000000000000000000000000000000111100",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000111100",
				"0111100111100000000000000000000000000000000000000011100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0000000111100000000000000000000000000000000000000011100000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0000000111100000000000000000000000000000000000000000000000000111100000000000000000000000111100000000000000000000000000000000000000000000000000000000011110000000",
				"0000000000000000000000011110000000000000000000000000000000000111100000000000000000000000111100000000000000000000000000000000000000000000000000000000011110000000",
				"0111100000000000000000011110000000000000000111000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000011110",
				"0111100000000000000000011110000000000000000111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"0111100111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000111100",
				"0111100111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000001111111100",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000001111000000",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0011110111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0000000111100000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0111100000000000011110000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111011110",
				"0111100000000000011110000000000000000000000000111100000000000000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000011110",
				"0111100000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000111110000000000000000000000000000000000000011110011110",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111110000000000000000000000000000000000000011110000000",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0111100111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0111100111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"0000000111100000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0000000111100000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0011110000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000111100",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000011110000000",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000011110000000",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000111100000000000000000000000000000000000000000011110000000",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000111100000000000000000000000000000000000000000000000011110",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000111100000000000000000000000000000000000000000000000011110",
				"0011110111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111011110",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0011110111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000011110000000",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000011110000000",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000011110",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"0011110111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0000000111100000000000000000000000000000001111000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0011110000000000000000000000000000000000001111000000000000000001111000000000000000000000000001111000000111100000000000000000000000000000000000000000011110011110",
				"0011110000000000000000000000000000000000001111000000000000000001111000000000000000000000000001111000000111100000000000000000000000000000000000000000000000011110",
				"0011111111000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000111100000000000000000000000000000000000000000011110011110",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"0011111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111011110",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000000000000000",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000000000111100",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0011110000000000011110000000000000000000000000000000000000000111100000000000000000000000000000000000000000111100001111000000000000000000000000000000000000111111",
				"0011111111111100011110011110001111000111100111000011110011110111100000000000000000000000000001111000111100111100001111011110001111001111001111000111111111111111",
				"0000011111111100011110011110001111000111100111000011110011110111100000000000000000000000000001111000111100111100001111011110001111001111001111000111111111100011",
				"0000011111111100000000011110001111000111100111000011110011110000000000000000000000000000000001111000111100000000000000011110001111001111001111000111111111100000",
				"1111000000000001111000000000000000111100000000000000000000011110000000000000000000000000001111000000000000000000000000000000000000000000111100111100000000000000",
				"1111000111100001111011110001111000111100111100111100111100011110001111000000000000000000001111000111100111100001111011110001111000111100111100111100111100011110",
				"1111000111100001111011110001111000111100111100111100111100011110001111000000000000000000001111000111100111100001111011110001111000111100111100111100111100011110",
				"0000000111100000000011110001111000000000111100111100111100000000001111000000000000000000000000000111100111100001111011110001111000111100000000000000111100011110",
			},
			objects = {
				{ id = "tree", x = -6, y = -9, bottom = 23, scale = 4 },
				{ id = "pine", x = 7, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = -6, y = 444, bottom = 476, scale = 4 },
				{ id = "tree2", x = 12, y = 431, bottom = 463, scale = 4 },
				{ id = "pine", x = 22, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 35, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 20, y = 447, bottom = 479, scale = 4 },
				{ id = "pine", x = 33, y = 429, bottom = 461, scale = 4 },
				{ id = "tree", x = 51, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 61, y = 10, bottom = 42, scale = 4 },
				{ id = "tree", x = 50, y = 444, bottom = 476, scale = 4 },
				{ id = "tree", x = 60, y = 428, bottom = 460, scale = 4 },
				{ id = "tree", x = 75, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 89, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 71, y = 446, bottom = 478, scale = 4 },
				{ id = "tree", x = 86, y = 428, bottom = 460, scale = 4 },
				{ id = "tree", x = 99, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 112, y = 12, bottom = 44, scale = 4 },
				{ id = "tree", x = 98, y = 444, bottom = 476, scale = 4 },
				{ id = "pine", x = 112, y = 429, bottom = 461, scale = 4 },
				{ id = "tree", x = 123, y = -8, bottom = 24, scale = 4 },
				{ id = "tree2", x = 138, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 127, y = 443, bottom = 475, scale = 4 },
				{ id = "pine", x = 139, y = 430, bottom = 462, scale = 4 },
				{ id = "tree", x = 153, y = -5, bottom = 27, scale = 4 },
				{ id = "tree2", x = 162, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 151, y = 445, bottom = 477, scale = 4 },
				{ id = "pine", x = 162, y = 431, bottom = 463, scale = 4 },
				{ id = "tree", x = 178, y = -5, bottom = 27, scale = 4 },
				{ id = "tree2", x = 192, y = 11, bottom = 43, scale = 4 },
				{ id = "tree", x = 174, y = 445, bottom = 477, scale = 4 },
				{ id = "tree2", x = 192, y = 428, bottom = 460, scale = 4 },
				{ id = "tree", x = 201, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 212, y = 13, bottom = 45, scale = 4 },
				{ id = "tree2", x = 201, y = 446, bottom = 478, scale = 4 },
				{ id = "tree", x = 217, y = 429, bottom = 461, scale = 4 },
				{ id = "pine", x = 226, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 240, y = 10, bottom = 42, scale = 4 },
				{ id = "tree2", x = 227, y = 444, bottom = 476, scale = 4 },
				{ id = "tree", x = 237, y = 427, bottom = 459, scale = 4 },
				{ id = "tree", x = 254, y = -7, bottom = 25, scale = 4 },
				{ id = "tree", x = 254, y = 444, bottom = 476, scale = 4 },
				{ id = "tree", x = 353, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 370, y = 11, bottom = 43, scale = 4 },
				{ id = "tree", x = 353, y = 443, bottom = 475, scale = 4 },
				{ id = "pine", x = 366, y = 430, bottom = 462, scale = 4 },
				{ id = "tree2", x = 379, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 393, y = 12, bottom = 44, scale = 4 },
				{ id = "tree", x = 379, y = 444, bottom = 476, scale = 4 },
				{ id = "pine", x = 393, y = 431, bottom = 463, scale = 4 },
				{ id = "tree", x = 405, y = -7, bottom = 25, scale = 4 },
				{ id = "tree", x = 420, y = 14, bottom = 46, scale = 4 },
				{ id = "tree", x = 405, y = 445, bottom = 477, scale = 4 },
				{ id = "tree", x = 417, y = 427, bottom = 459, scale = 4 },
				{ id = "tree", x = 435, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 445, y = 11, bottom = 43, scale = 4 },
				{ id = "pine", x = 435, y = 445, bottom = 477, scale = 4 },
				{ id = "tree", x = 448, y = 427, bottom = 459, scale = 4 },
				{ id = "tree", x = 456, y = -4, bottom = 28, scale = 4 },
				{ id = "tree", x = 472, y = 12, bottom = 44, scale = 4 },
				{ id = "tree", x = 457, y = 444, bottom = 476, scale = 4 },
				{ id = "pine", x = 469, y = 431, bottom = 463, scale = 4 },
				{ id = "pine", x = 482, y = -7, bottom = 25, scale = 4 },
				{ id = "pine", x = 499, y = 11, bottom = 43, scale = 4 },
				{ id = "tree2", x = 484, y = 444, bottom = 476, scale = 4 },
				{ id = "tree", x = 494, y = 428, bottom = 460, scale = 4 },
				{ id = "pine", x = 508, y = -4, bottom = 28, scale = 4 },
				{ id = "pine", x = 522, y = 12, bottom = 44, scale = 4 },
				{ id = "tree", x = 511, y = 447, bottom = 479, scale = 4 },
				{ id = "tree", x = 521, y = 430, bottom = 462, scale = 4 },
				{ id = "tree", x = 535, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 550, y = 10, bottom = 42, scale = 4 },
				{ id = "tree", x = 535, y = 443, bottom = 475, scale = 4 },
				{ id = "tree", x = 545, y = 429, bottom = 461, scale = 4 },
				{ id = "pine", x = 561, y = -7, bottom = 25, scale = 4 },
				{ id = "tree", x = 570, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 559, y = 443, bottom = 475, scale = 4 },
				{ id = "tree2", x = 573, y = 430, bottom = 462, scale = 4 },
				{ id = "tree2", x = 588, y = -5, bottom = 27, scale = 4 },
				{ id = "tree2", x = 598, y = 11, bottom = 43, scale = 4 },
				{ id = "pine", x = 585, y = 445, bottom = 477, scale = 4 },
				{ id = "tree", x = 596, y = 429, bottom = 461, scale = 4 },
				{ id = "tree", x = 613, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 624, y = 9, bottom = 41, scale = 4 },
				{ id = "tree", x = 611, y = 446, bottom = 478, scale = 4 },
				{ id = "tree", x = 624, y = 428, bottom = 460, scale = 4 },
				{ id = "tree", x = -4, y = 27, bottom = 59, scale = 4 },
				{ id = "tree", x = 17, y = 35, bottom = 67, scale = 4 },
				{ id = "tree", x = 609, y = 28, bottom = 60, scale = 4 },
				{ id = "tree2", x = 586, y = 35, bottom = 67, scale = 4 },
				{ id = "tree", x = -4, y = 46, bottom = 78, scale = 4 },
				{ id = "pine", x = 21, y = 56, bottom = 88, scale = 4 },
				{ id = "tree", x = 609, y = 46, bottom = 78, scale = 4 },
				{ id = "tree2", x = 591, y = 54, bottom = 86, scale = 4 },
				{ id = "tree", x = -5, y = 69, bottom = 101, scale = 4 },
				{ id = "tree", x = 20, y = 78, bottom = 110, scale = 4 },
				{ id = "pine", x = 609, y = 70, bottom = 102, scale = 4 },
				{ id = "pine", x = 587, y = 76, bottom = 108, scale = 4 },
				{ id = "tree", x = -2, y = 87, bottom = 119, scale = 4 },
				{ id = "tree2", x = 19, y = 100, bottom = 132, scale = 4 },
				{ id = "tree2", x = 611, y = 89, bottom = 121, scale = 4 },
				{ id = "tree2", x = 591, y = 98, bottom = 130, scale = 4 },
				{ id = "tree", x = -5, y = 111, bottom = 143, scale = 4 },
				{ id = "tree2", x = 21, y = 116, bottom = 148, scale = 4 },
				{ id = "tree", x = 607, y = 111, bottom = 143, scale = 4 },
				{ id = "pine", x = 588, y = 120, bottom = 152, scale = 4 },
				{ id = "pine", x = 0, y = 129, bottom = 161, scale = 4 },
				{ id = "tree", x = 21, y = 141, bottom = 173, scale = 4 },
				{ id = "pine", x = 608, y = 131, bottom = 163, scale = 4 },
				{ id = "tree2", x = 588, y = 139, bottom = 171, scale = 4 },
				{ id = "pine", x = -3, y = 151, bottom = 183, scale = 4 },
				{ id = "pine", x = 22, y = 160, bottom = 192, scale = 4 },
				{ id = "pine", x = 609, y = 149, bottom = 181, scale = 4 },
				{ id = "tree", x = 589, y = 161, bottom = 193, scale = 4 },
				{ id = "tree", x = -4, y = 172, bottom = 204, scale = 4 },
				{ id = "tree2", x = 19, y = 183, bottom = 215, scale = 4 },
				{ id = "tree", x = 611, y = 173, bottom = 205, scale = 4 },
				{ id = "pine", x = 587, y = 179, bottom = 211, scale = 4 },
				{ id = "tree", x = -4, y = 193, bottom = 225, scale = 4 },
				{ id = "tree", x = 18, y = 201, bottom = 233, scale = 4 },
				{ id = "tree", x = 608, y = 192, bottom = 224, scale = 4 },
				{ id = "tree", x = 592, y = 201, bottom = 233, scale = 4 },
				{ id = "tree", x = 1, y = 212, bottom = 244, scale = 4 },
				{ id = "pine", x = 19, y = 224, bottom = 256, scale = 4 },
				{ id = "pine", x = 608, y = 214, bottom = 246, scale = 4 },
				{ id = "tree2", x = 591, y = 224, bottom = 256, scale = 4 },
				{ id = "pine", x = -2, y = 235, bottom = 267, scale = 4 },
				{ id = "tree", x = 21, y = 245, bottom = 277, scale = 4 },
				{ id = "tree2", x = 612, y = 233, bottom = 265, scale = 4 },
				{ id = "tree", x = 588, y = 242, bottom = 274, scale = 4 },
				{ id = "tree", x = -4, y = 254, bottom = 286, scale = 4 },
				{ id = "tree", x = 21, y = 264, bottom = 296, scale = 4 },
				{ id = "tree", x = 606, y = 253, bottom = 285, scale = 4 },
				{ id = "tree", x = 592, y = 263, bottom = 295, scale = 4 },
				{ id = "pine", x = -1, y = 275, bottom = 307, scale = 4 },
				{ id = "tree", x = 20, y = 286, bottom = 318, scale = 4 },
				{ id = "pine", x = 607, y = 273, bottom = 305, scale = 4 },
				{ id = "pine", x = 589, y = 285, bottom = 317, scale = 4 },
				{ id = "pine", x = -1, y = 297, bottom = 329, scale = 4 },
				{ id = "pine", x = 19, y = 305, bottom = 337, scale = 4 },
				{ id = "pine", x = 612, y = 296, bottom = 328, scale = 4 },
				{ id = "tree", x = 592, y = 304, bottom = 336, scale = 4 },
				{ id = "tree", x = 0, y = 315, bottom = 347, scale = 4 },
				{ id = "tree", x = 19, y = 328, bottom = 360, scale = 4 },
				{ id = "tree2", x = 607, y = 317, bottom = 349, scale = 4 },
				{ id = "tree", x = 587, y = 328, bottom = 360, scale = 4 },
				{ id = "pine", x = 1, y = 336, bottom = 368, scale = 4 },
				{ id = "pine", x = 22, y = 346, bottom = 378, scale = 4 },
				{ id = "tree2", x = 611, y = 338, bottom = 370, scale = 4 },
				{ id = "tree", x = 586, y = 348, bottom = 380, scale = 4 },
				{ id = "tree", x = -1, y = 358, bottom = 390, scale = 4 },
				{ id = "tree2", x = 17, y = 368, bottom = 400, scale = 4 },
				{ id = "tree2", x = 612, y = 356, bottom = 388, scale = 4 },
				{ id = "tree", x = 589, y = 368, bottom = 400, scale = 4 },
				{ id = "pine", x = 0, y = 378, bottom = 410, scale = 4 },
				{ id = "tree", x = 16, y = 388, bottom = 420, scale = 4 },
				{ id = "tree2", x = 611, y = 380, bottom = 412, scale = 4 },
				{ id = "tree", x = 591, y = 387, bottom = 419, scale = 4 },
				{ id = "tree", x = -4, y = 400, bottom = 432, scale = 4 },
				{ id = "tree", x = 16, y = 408, bottom = 440, scale = 4 },
				{ id = "tree", x = 608, y = 402, bottom = 434, scale = 4 },
				{ id = "pine", x = 589, y = 410, bottom = 442, scale = 4 },
				{ id = "tree2", x = -2, y = 423, bottom = 455, scale = 4 },
				{ id = "tree", x = 17, y = 429, bottom = 461, scale = 4 },
				{ id = "pine", x = 608, y = 421, bottom = 453, scale = 4 },
				{ id = "tree", x = 586, y = 431, bottom = 463, scale = 4 },
				{ id = "bigtree", x = 497, y = 97, bottom = 145, scale = 4 },
				{ id = "pine", x = 465, y = 282, bottom = 314, scale = 4 },
				{ id = "pine", x = 236, y = 268, bottom = 300, scale = 4 },
				{ id = "tree", x = 364, y = 358, bottom = 390, scale = 4 },
				{ id = "bigtree", x = 325, y = 54, bottom = 102, scale = 4 },
				{ id = "tree", x = 244, y = 353, bottom = 385, scale = 4 },
				{ id = "tree", x = 447, y = 141, bottom = 173, scale = 4 },
				{ id = "tree", x = 344, y = 167, bottom = 199, scale = 4 },
				{ id = "tree", x = 160, y = 353, bottom = 385, scale = 4 },
				{ id = "pine", x = 176, y = 232, bottom = 264, scale = 4 },
				{ id = "tree", x = 140, y = 93, bottom = 125, scale = 4 },
				{ id = "bigtree", x = 409, y = 223, bottom = 271, scale = 4 },
				{ id = "pine", x = 86, y = 168, bottom = 200, scale = 4 },
				{ id = "pine", x = 356, y = 293, bottom = 325, scale = 4 },
				{ id = "tree", x = 236, y = 162, bottom = 194, scale = 4 },
				{ id = "bigtree", x = 198, y = 84, bottom = 132, scale = 4 },
				{ id = "bush2", x = 185, y = 80, bottom = 96, scale = 4 },
				{ id = "bush", x = 170, y = 186, bottom = 202, scale = 4 },
				{ id = "bush2", x = 285, y = 92, bottom = 108, scale = 4 },
				{ id = "bush2", x = 102, y = 100, bottom = 116, scale = 4 },
				{ id = "bush2", x = 338, y = 143, bottom = 159, scale = 4 },
				{ id = "bush2", x = 477, y = 105, bottom = 121, scale = 4 },
				{ id = "bush2", x = 67, y = 246, bottom = 262, scale = 4 },
				{ id = "bush2", x = 413, y = 310, bottom = 326, scale = 4 },
				{ id = "bush", x = 563, y = 214, bottom = 230, scale = 4 },
				{ id = "bush", x = 360, y = 344, bottom = 360, scale = 4 },
				{ id = "bush", x = 166, y = 148, bottom = 164, scale = 4 },
				{ id = "bush2", x = 198, y = 171, bottom = 187, scale = 4 },
				{ id = "bush2", x = 545, y = 119, bottom = 135, scale = 4 },
				{ id = "bush2", x = 558, y = 86, bottom = 102, scale = 4 },
				{ id = "bush", x = 420, y = 161, bottom = 177, scale = 4 },
				{ id = "bush2", x = 411, y = 373, bottom = 389, scale = 4 },
				{ id = "bush", x = 390, y = 412, bottom = 428, scale = 4 },
				{ id = "bush2", x = 79, y = 76, bottom = 92, scale = 4 },
			},
			zones = {
				{ name = "북서 풀밭", count = 6, x0 = 64, y0 = 64, x1 = 288, y1 = 192, species = {
					1,
				} },
				{ name = "북동 풀밭", count = 6, x0 = 352, y0 = 64, x1 = 592, y1 = 192, species = {
					1,
				} },
				{ name = "남서 풀밭", count = 6, x0 = 144, y0 = 256, x1 = 304, y1 = 432, species = {
					1,
				} },
				{ name = "남동 풀밭", count = 7, x0 = 336, y0 = 256, x1 = 496, y1 = 432, species = {
					1,
				} },
			},
			portals = {
				{ name = "닌자 마을 가는 길", x0 = 304, y0 = 0, x1 = 336, y1 = 16, to = "village", arrive = "door" },
				{ name = "새싹 들판 2 가는 길", x0 = 304, y0 = 464, x1 = 336, y1 = 480, to = "field2", arrive = "door" },
			},
			mons = {},
			npcs = {},
		},
		field2 = {
			name = "새싹 들판 2", w = 38, h = 28, indoor = false,
			outside = { 173, 188, 58 },
			ground = { w = 608, h = 448 },
			spawn = { x = 304, y = 42 },
			blocked = {
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000011110001111001111000000",
				"00111101111000111100111100011110011110011110001111001111000011110000000000000000000011110001111000111100111100111100111100011110011110001111001111000111",
				"00111101111000111100111100011110011110011110001111001111000011110000000000000000000011110001111000111100111100111100111100011110011110001111001111000111",
				"00111101111000111100111100011110000000011110001111001111000011110000000000000000000011110001111000111100111100000000111100011110000000000000000000000111",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000111100011110011110011110000000000000001111000111100111100000000000000000000011110001111000000000000000000000000000111100011110001111000000001",
				"00001111000111100011110011110011110011110001111001111000111100111100000000000000000000011110001111001111000111100011110111100111100011110001111001111001",
				"00001111000111100011110011110011110011110001111001111000111100111100000000000000000000011110001111001111000111100011110111100111100011110001111001111001",
				"00001111000000000000000000000000000011110001111000000000000000000000000000000000000000000000000000001111000111100011110111100000000000000000000001111000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000011110000000000000000000000000000000000011110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000011110000000",
				"00000011110000000000000000000000000000000000011110000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000011110111100",
				"01111000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000111100",
				"01111001111000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000011110000000",
				"00000001111000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111001111000000000000000000000000001110000000000000000011110000000000000000000000000011110000000000000000000000000000000000000000000000000011110011110",
				"00000001111000000000000000000000000001110000000000000000011110000000000000000000000000011110000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000001110000000000000000000000000000000000000000000000011110000000000000000000000000000000000000011100000000011110000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000000111100",
				"00111100000000000000111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000000111100",
				"00111101111000000000111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"01111001111000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"01111000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000",
				"01111000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"01111001111000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000001111000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000011100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111100000000000000011100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111101111000000000011100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000",
				"00000001111000000000000000000000000000000000000000000000000000000111100000000000000000001111000000000000000000000000000000000000000000000000000000000000",
				"01111001111000000000000000000000000000000000000000000000000000000111100000000000000000001111000000000000000000000000000000000000000000000000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000001111000000000000000000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000",
				"00000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000001111000000000000000",
				"00000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000",
				"01111000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000001110000000000000000000111100000000000000000011110",
				"00000011110000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000111100000000000011110011110",
				"00000011110000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000111100000000000011110000000",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111111110000000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111111110000000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00000011110000000000000000000000000000000000000111110000000000000000000000000000000000000011100000000000000000000000000000000000000000000000001111000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000001111111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111111110000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111110000000000000000011110000000",
				"00000011110000000000000111100000000000000000000000000000000000000000000000111100000000000000000001111000000000000000000111110000000000000000011110000000",
				"01111011110000000000000000000000000000000000000000000000000000000000000000111100000000000000000001111000000000000000000111110000000000000000011110011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000001111000000000000000000111110000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000001111000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000111100",
				"00000001111000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000001111000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111101111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000111100000000011110000000000000000000000000000000000011110000000011110001111000000000000000000000000000011110011110001111110000000",
				"00000111111111100111100111100011110011110001111001111001111000111100011110011110001111011110001111000111101111000011110111100011110011110001111000111100",
				"00000111100111100111100111100011110011110001111001111001111000111100011110011110001111011110001111000111101111000011110111100011110011110001111000111100",
				"00000111100111100111100000000011110000000001111001111001111000111100011110000000001111000000000000000111101111000011110111100000000000000000000000111100",
				"00000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000011110000000000000001111000000000000001111",
				"01111000111100011110111100011110011110011110011110001111000111100111100011110111100001111011110001111000111100011110111100011110001111011110011110001111",
				"01111000111100011110111100011110011110011110011110001111000111100111100011110111100001111011110001111000111100011110111100011110001111011110011110001111",
				"01111000111100011110111100011110011110011110000000001111000111100111100011110111100001111011110001111000111100000000111100011110000000011110011110000000",
			},
			objects = {
				{ id = "tree2", x = -1, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 9, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = -4, y = 413, bottom = 445, scale = 4 },
				{ id = "tree", x = 12, y = 398, bottom = 430, scale = 4 },
				{ id = "tree2", x = 22, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 35, y = 9, bottom = 41, scale = 4 },
				{ id = "tree", x = 25, y = 414, bottom = 446, scale = 4 },
				{ id = "tree", x = 36, y = 399, bottom = 431, scale = 4 },
				{ id = "pine", x = 50, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 62, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 51, y = 413, bottom = 445, scale = 4 },
				{ id = "tree2", x = 59, y = 398, bottom = 430, scale = 4 },
				{ id = "tree2", x = 71, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 87, y = 11, bottom = 43, scale = 4 },
				{ id = "tree", x = 72, y = 415, bottom = 447, scale = 4 },
				{ id = "tree", x = 85, y = 396, bottom = 428, scale = 4 },
				{ id = "tree2", x = 100, y = -4, bottom = 28, scale = 4 },
				{ id = "tree", x = 112, y = 10, bottom = 42, scale = 4 },
				{ id = "tree2", x = 100, y = 413, bottom = 445, scale = 4 },
				{ id = "tree2", x = 113, y = 396, bottom = 428, scale = 4 },
				{ id = "tree", x = 124, y = -8, bottom = 24, scale = 4 },
				{ id = "tree2", x = 135, y = 13, bottom = 45, scale = 4 },
				{ id = "tree2", x = 125, y = 414, bottom = 446, scale = 4 },
				{ id = "tree2", x = 136, y = 395, bottom = 427, scale = 4 },
				{ id = "tree2", x = 149, y = -4, bottom = 28, scale = 4 },
				{ id = "pine", x = 164, y = 13, bottom = 45, scale = 4 },
				{ id = "tree2", x = 148, y = 414, bottom = 446, scale = 4 },
				{ id = "tree", x = 165, y = 397, bottom = 429, scale = 4 },
				{ id = "pine", x = 177, y = -4, bottom = 28, scale = 4 },
				{ id = "tree", x = 186, y = 9, bottom = 41, scale = 4 },
				{ id = "tree", x = 174, y = 411, bottom = 443, scale = 4 },
				{ id = "tree", x = 186, y = 396, bottom = 428, scale = 4 },
				{ id = "tree", x = 199, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 216, y = 9, bottom = 41, scale = 4 },
				{ id = "tree", x = 198, y = 415, bottom = 447, scale = 4 },
				{ id = "pine", x = 214, y = 397, bottom = 429, scale = 4 },
				{ id = "tree2", x = 230, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 240, y = 11, bottom = 43, scale = 4 },
				{ id = "pine", x = 226, y = 414, bottom = 446, scale = 4 },
				{ id = "tree", x = 241, y = 399, bottom = 431, scale = 4 },
				{ id = "pine", x = 253, y = 413, bottom = 445, scale = 4 },
				{ id = "tree", x = 268, y = 398, bottom = 430, scale = 4 },
				{ id = "pine", x = 281, y = 412, bottom = 444, scale = 4 },
				{ id = "tree", x = 293, y = 395, bottom = 427, scale = 4 },
				{ id = "pine", x = 301, y = 413, bottom = 445, scale = 4 },
				{ id = "tree2", x = 319, y = 397, bottom = 429, scale = 4 },
				{ id = "tree", x = 327, y = -6, bottom = 26, scale = 4 },
				{ id = "pine", x = 339, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 332, y = 412, bottom = 444, scale = 4 },
				{ id = "pine", x = 339, y = 395, bottom = 427, scale = 4 },
				{ id = "tree", x = 358, y = -7, bottom = 25, scale = 4 },
				{ id = "tree", x = 367, y = 11, bottom = 43, scale = 4 },
				{ id = "pine", x = 353, y = 413, bottom = 445, scale = 4 },
				{ id = "pine", x = 368, y = 394, bottom = 426, scale = 4 },
				{ id = "tree", x = 383, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 391, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 380, y = 415, bottom = 447, scale = 4 },
				{ id = "tree", x = 396, y = 397, bottom = 429, scale = 4 },
				{ id = "tree", x = 409, y = -4, bottom = 28, scale = 4 },
				{ id = "tree", x = 419, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 409, y = 414, bottom = 446, scale = 4 },
				{ id = "tree2", x = 418, y = 397, bottom = 429, scale = 4 },
				{ id = "pine", x = 432, y = -9, bottom = 23, scale = 4 },
				{ id = "pine", x = 447, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 435, y = 411, bottom = 443, scale = 4 },
				{ id = "tree", x = 447, y = 397, bottom = 429, scale = 4 },
				{ id = "tree2", x = 456, y = -4, bottom = 28, scale = 4 },
				{ id = "tree", x = 467, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 457, y = 414, bottom = 446, scale = 4 },
				{ id = "tree", x = 467, y = 399, bottom = 431, scale = 4 },
				{ id = "pine", x = 484, y = -5, bottom = 27, scale = 4 },
				{ id = "tree2", x = 494, y = 9, bottom = 41, scale = 4 },
				{ id = "tree2", x = 482, y = 414, bottom = 446, scale = 4 },
				{ id = "pine", x = 498, y = 396, bottom = 428, scale = 4 },
				{ id = "pine", x = 507, y = -9, bottom = 23, scale = 4 },
				{ id = "tree2", x = 521, y = 11, bottom = 43, scale = 4 },
				{ id = "tree", x = 511, y = 412, bottom = 444, scale = 4 },
				{ id = "tree", x = 519, y = 395, bottom = 427, scale = 4 },
				{ id = "tree", x = 534, y = -9, bottom = 23, scale = 4 },
				{ id = "tree", x = 546, y = 10, bottom = 42, scale = 4 },
				{ id = "tree2", x = 533, y = 413, bottom = 445, scale = 4 },
				{ id = "tree", x = 548, y = 396, bottom = 428, scale = 4 },
				{ id = "pine", x = 560, y = -9, bottom = 23, scale = 4 },
				{ id = "tree", x = 570, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 557, y = 413, bottom = 445, scale = 4 },
				{ id = "tree2", x = 576, y = 397, bottom = 429, scale = 4 },
				{ id = "pine", x = 588, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 596, y = 10, bottom = 42, scale = 4 },
				{ id = "pine", x = 584, y = 411, bottom = 443, scale = 4 },
				{ id = "pine", x = 600, y = 399, bottom = 431, scale = 4 },
				{ id = "tree2", x = -4, y = 28, bottom = 60, scale = 4 },
				{ id = "tree2", x = 21, y = 34, bottom = 66, scale = 4 },
				{ id = "pine", x = 580, y = 24, bottom = 56, scale = 4 },
				{ id = "tree", x = 555, y = 35, bottom = 67, scale = 4 },
				{ id = "tree2", x = -1, y = 46, bottom = 78, scale = 4 },
				{ id = "tree2", x = 18, y = 57, bottom = 89, scale = 4 },
				{ id = "tree", x = 576, y = 45, bottom = 77, scale = 4 },
				{ id = "tree", x = 556, y = 57, bottom = 89, scale = 4 },
				{ id = "tree", x = -2, y = 70, bottom = 102, scale = 4 },
				{ id = "tree", x = 22, y = 77, bottom = 109, scale = 4 },
				{ id = "tree", x = 576, y = 66, bottom = 98, scale = 4 },
				{ id = "tree", x = 555, y = 77, bottom = 109, scale = 4 },
				{ id = "tree2", x = -4, y = 90, bottom = 122, scale = 4 },
				{ id = "tree", x = 18, y = 99, bottom = 131, scale = 4 },
				{ id = "tree", x = 580, y = 89, bottom = 121, scale = 4 },
				{ id = "tree2", x = 556, y = 98, bottom = 130, scale = 4 },
				{ id = "tree", x = 0, y = 111, bottom = 143, scale = 4 },
				{ id = "tree2", x = 21, y = 119, bottom = 151, scale = 4 },
				{ id = "tree", x = 575, y = 109, bottom = 141, scale = 4 },
				{ id = "tree", x = 559, y = 116, bottom = 148, scale = 4 },
				{ id = "tree", x = -5, y = 128, bottom = 160, scale = 4 },
				{ id = "pine", x = 19, y = 140, bottom = 172, scale = 4 },
				{ id = "pine", x = -3, y = 150, bottom = 182, scale = 4 },
				{ id = "tree", x = 19, y = 160, bottom = 192, scale = 4 },
				{ id = "pine", x = 1, y = 174, bottom = 206, scale = 4 },
				{ id = "tree2", x = 21, y = 180, bottom = 212, scale = 4 },
				{ id = "tree", x = 0, y = 193, bottom = 225, scale = 4 },
				{ id = "tree", x = 20, y = 203, bottom = 235, scale = 4 },
				{ id = "pine", x = -3, y = 211, bottom = 243, scale = 4 },
				{ id = "tree2", x = 22, y = 223, bottom = 255, scale = 4 },
				{ id = "tree2", x = -4, y = 232, bottom = 264, scale = 4 },
				{ id = "tree2", x = 17, y = 243, bottom = 275, scale = 4 },
				{ id = "tree", x = 580, y = 235, bottom = 267, scale = 4 },
				{ id = "tree", x = 555, y = 241, bottom = 273, scale = 4 },
				{ id = "pine", x = -2, y = 256, bottom = 288, scale = 4 },
				{ id = "tree", x = 17, y = 262, bottom = 294, scale = 4 },
				{ id = "tree2", x = 575, y = 255, bottom = 287, scale = 4 },
				{ id = "tree", x = 560, y = 266, bottom = 298, scale = 4 },
				{ id = "pine", x = -2, y = 277, bottom = 309, scale = 4 },
				{ id = "tree", x = 17, y = 287, bottom = 319, scale = 4 },
				{ id = "tree", x = 575, y = 275, bottom = 307, scale = 4 },
				{ id = "tree2", x = 556, y = 285, bottom = 317, scale = 4 },
				{ id = "tree2", x = -3, y = 295, bottom = 327, scale = 4 },
				{ id = "tree2", x = 20, y = 304, bottom = 336, scale = 4 },
				{ id = "tree", x = 580, y = 294, bottom = 326, scale = 4 },
				{ id = "tree", x = 555, y = 307, bottom = 339, scale = 4 },
				{ id = "tree", x = 1, y = 315, bottom = 347, scale = 4 },
				{ id = "tree", x = 21, y = 327, bottom = 359, scale = 4 },
				{ id = "pine", x = 574, y = 319, bottom = 351, scale = 4 },
				{ id = "tree", x = 556, y = 328, bottom = 360, scale = 4 },
				{ id = "tree2", x = -2, y = 337, bottom = 369, scale = 4 },
				{ id = "pine", x = 19, y = 347, bottom = 379, scale = 4 },
				{ id = "tree", x = 576, y = 335, bottom = 367, scale = 4 },
				{ id = "pine", x = 557, y = 346, bottom = 378, scale = 4 },
				{ id = "tree", x = 1, y = 358, bottom = 390, scale = 4 },
				{ id = "pine", x = 22, y = 367, bottom = 399, scale = 4 },
				{ id = "tree", x = 579, y = 358, bottom = 390, scale = 4 },
				{ id = "tree", x = 556, y = 367, bottom = 399, scale = 4 },
				{ id = "tree2", x = 1, y = 379, bottom = 411, scale = 4 },
				{ id = "pine", x = 20, y = 390, bottom = 422, scale = 4 },
				{ id = "tree2", x = 579, y = 377, bottom = 409, scale = 4 },
				{ id = "tree2", x = 557, y = 387, bottom = 419, scale = 4 },
				{ id = "tree", x = 252, y = 238, bottom = 270, scale = 4 },
				{ id = "tree2", x = 289, y = 290, bottom = 322, scale = 4 },
				{ id = "bigtree", x = 462, y = 273, bottom = 321, scale = 4 },
				{ id = "pine", x = 436, y = 129, bottom = 161, scale = 4 },
				{ id = "tree", x = 104, y = 125, bottom = 157, scale = 4 },
				{ id = "pine", x = 340, y = 96, bottom = 128, scale = 4 },
				{ id = "tree2", x = 381, y = 290, bottom = 322, scale = 4 },
				{ id = "tree", x = 466, y = 216, bottom = 248, scale = 4 },
				{ id = "tree2", x = 83, y = 280, bottom = 312, scale = 4 },
				{ id = "pine", x = 220, y = 94, bottom = 126, scale = 4 },
				{ id = "bigtree", x = 172, y = 245, bottom = 293, scale = 4 },
				{ id = "tree2", x = 166, y = 325, bottom = 357, scale = 4 },
				{ id = "pine", x = 345, y = 203, bottom = 235, scale = 4 },
				{ id = "pine", x = 256, y = 156, bottom = 188, scale = 4 },
				{ id = "bush", x = 179, y = 77, bottom = 93, scale = 4 },
				{ id = "bush", x = 358, y = 285, bottom = 301, scale = 4 },
				{ id = "bush", x = 147, y = 114, bottom = 130, scale = 4 },
				{ id = "bush", x = 357, y = 332, bottom = 348, scale = 4 },
				{ id = "bush", x = 452, y = 87, bottom = 103, scale = 4 },
				{ id = "bush", x = 234, y = 358, bottom = 374, scale = 4 },
				{ id = "bush", x = 261, y = 221, bottom = 237, scale = 4 },
				{ id = "bush", x = 410, y = 248, bottom = 264, scale = 4 },
				{ id = "bush", x = 79, y = 127, bottom = 143, scale = 4 },
				{ id = "bush2", x = 112, y = 94, bottom = 110, scale = 4 },
				{ id = "bush2", x = 82, y = 184, bottom = 200, scale = 4 },
				{ id = "bush2", x = 515, y = 121, bottom = 137, scale = 4 },
				{ id = "bush2", x = 533, y = 237, bottom = 253, scale = 4 },
				{ id = "bush2", x = 500, y = 252, bottom = 268, scale = 4 },
				{ id = "bush", x = 207, y = 318, bottom = 334, scale = 4 },
				{ id = "bush2", x = 385, y = 75, bottom = 91, scale = 4 },
			},
			zones = {
				{ name = "서쪽 풀밭(말랑이)", count = 6, x0 = 64, y0 = 64, x1 = 256, y1 = 176, species = {
					1,
				} },
				{ name = "가운데 풀밭", count = 8, x0 = 160, y0 = 240, x1 = 432, y1 = 400, species = {
					1,
					2,
				} },
				{ name = "동쪽 버섯밭", count = 6, x0 = 352, y0 = 64, x1 = 560, y1 = 176, species = {
					2,
				} },
			},
			portals = {
				{ name = "새싹 들판 1 가는 길", x0 = 288, y0 = 0, x1 = 320, y1 = 16, to = "field1", arrive = "door" },
				{ name = "새싹 들판 3 가는 길", x0 = 592, y0 = 192, x1 = 608, y1 = 224, to = "field3", arrive = "door" },
			},
			mons = {},
			npcs = {},
		},
		field3 = {
			name = "새싹 들판 3", w = 38, h = 28, indoor = false,
			outside = { 173, 188, 58 },
			ground = { w = 608, h = 448 },
			spawn = { x = 48, y = 214 },
			blocked = {
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000001111000000000000000000000000000000000011110000000000000000000000000000000000111100000000000000000000000000001111000111",
				"00111100111100111100111100111100001111001111011110000111100111100111100011110011110011110011110011110000111100111100111100111100011110001111001111000111",
				"00111100111100111100111100111100001111001111011110000111100111100111100011110011110011110011110011110000111100111100111100111100011110001111001111000111",
				"00111100111100111100111100111100000000001111011110000111100111100111100000000011110011110011110011110000111100000000111100111100011110001111000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00001111001111000000000011110001111011110001111000000000111100000000111100000000000000001111000000001111000000000000000111100000000001111001111001111000",
				"00001111001111000011110011110001111011110001111001111000111100111100111100011110001111001111001111001111000111100111100111100001111001111001111001111000",
				"00001111001111000011110011110001111011110001111001111000111100111100111100011110001111001111001111001111000111100111100111100001111001111001111001111000",
				"00000000000000000011110000000000000000000000000001111000000000111100000000011110001111000000001111000000000111100111100000000001111000000000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000111100000000000000000011110",
				"00111100111100000000000000000000000000000000000000000001110000000000000000001110000000000000000000000000000000000000000000000111100000000000000000011110",
				"00000000111100000000000000000000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000011110011110",
				"00000000111100000000000000000000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000011110000000",
				"01111000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"01111000000000000000000000000011100000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000011100000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000001111000000000000000000011100000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000001111000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000001111000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000011100000000000000000001111111100",
				"00111100000000000000000000000000000000001111000011110000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000111100",
				"00111100000000000000000000000000000000001111000011110000000000000000000000000000000000000000000000000000000000000000000011100000000000000000011110111100",
				"00111100111100000000000000000000000000001111000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000111100000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000111100000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000001111000000000000000000000000000011111000000001111000000000000000000000000000000000000000000000111100000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000011111000000001111000000000000000000000000000000000000000000000111100000000000000000011110",
				"01111001111000000000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000111100000000111100000000000000000000000",
				"00000001111000000000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000111100000000000000000000000001111000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000001111000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000",
				"00000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000011111000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000111100000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000111100000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000111100000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"01111001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111100000000000000001111000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111100000000000000001111000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000001111100000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000001111100000000000000000000011110",
				"01111011110000000000000000000000000000000000000000000000000000000000000000000001111000000000000011110000000000000000000000000000000000000000111100011110",
				"01111011110000000000000011100000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000111100000000",
				"00000011110000000000000011100000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000111100000000",
				"00000000000000000000000011100000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000",
				"01111000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000111100",
				"01111011110000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000111100",
				"01111011110000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"00000011110000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000000000000111100000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"01111000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"01111000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000111100",
				"01111001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100111100",
				"00000001111000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000111100000000",
				"00000001111000000000000000000000000000000000000000000000000001111000000000000000000000000111100000000000000000000000000000000000000000000000111100111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000111100",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000001111000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"00000011110000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000111100000000000000000000011110000000000011111111000",
				"00001111111111000111100111100011110001111011110001111000111100111100111100011110001111011110001111000111101111000111100011110011110001111001111111111000",
				"00001111001111000111100111100011110001111011110001111000111100111100111100011110001111011110001111000111101111000111100011110011110001111001111001111000",
				"00001111001111000111100111100011110000000011110001111000111100111100111100011110001111011110001111000000001111000111100011110000000001111001111000000000",
				"00000000000000111100000000011110000000000000000000000000000000000000000011110000000000000000000000000000000001111000000000111100001111001111001111000000",
				"01111000111100111100011110011110001111011110001111001111000111100111100011110011110011110011110001111000111101111000111100111100001111001111001111001111",
				"01111000111100111100011110011110001111011110001111001111000111100111100011110011110011110011110001111000111101111000111100111100001111001111001111001111",
				"01111000111100000000011110000000001111011110001111001111000111100111100000000011110011110011110001111000111100000000111100000000000000000000000000001111",
			},
			objects = {
				{ id = "tree2", x = -1, y = -6, bottom = 26, scale = 4 },
				{ id = "pine", x = 7, y = 10, bottom = 42, scale = 4 },
				{ id = "pine", x = -3, y = 413, bottom = 445, scale = 4 },
				{ id = "tree", x = 9, y = 397, bottom = 429, scale = 4 },
				{ id = "tree", x = 25, y = -4, bottom = 28, scale = 4 },
				{ id = "pine", x = 32, y = 10, bottom = 42, scale = 4 },
				{ id = "pine", x = 24, y = 414, bottom = 446, scale = 4 },
				{ id = "pine", x = 34, y = 397, bottom = 429, scale = 4 },
				{ id = "tree", x = 46, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 63, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 48, y = 411, bottom = 443, scale = 4 },
				{ id = "tree2", x = 59, y = 399, bottom = 431, scale = 4 },
				{ id = "pine", x = 72, y = -5, bottom = 27, scale = 4 },
				{ id = "pine", x = 89, y = 10, bottom = 42, scale = 4 },
				{ id = "pine", x = 75, y = 415, bottom = 447, scale = 4 },
				{ id = "tree", x = 85, y = 398, bottom = 430, scale = 4 },
				{ id = "tree2", x = 97, y = -5, bottom = 27, scale = 4 },
				{ id = "pine", x = 115, y = 9, bottom = 41, scale = 4 },
				{ id = "tree2", x = 100, y = 412, bottom = 444, scale = 4 },
				{ id = "pine", x = 113, y = 398, bottom = 430, scale = 4 },
				{ id = "pine", x = 128, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 136, y = 11, bottom = 43, scale = 4 },
				{ id = "pine", x = 127, y = 412, bottom = 444, scale = 4 },
				{ id = "tree", x = 140, y = 396, bottom = 428, scale = 4 },
				{ id = "pine", x = 153, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 162, y = 11, bottom = 43, scale = 4 },
				{ id = "tree2", x = 150, y = 412, bottom = 444, scale = 4 },
				{ id = "tree2", x = 161, y = 398, bottom = 430, scale = 4 },
				{ id = "pine", x = 173, y = -6, bottom = 26, scale = 4 },
				{ id = "pine", x = 187, y = 13, bottom = 45, scale = 4 },
				{ id = "tree2", x = 177, y = 414, bottom = 446, scale = 4 },
				{ id = "tree", x = 189, y = 398, bottom = 430, scale = 4 },
				{ id = "tree2", x = 204, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 214, y = 10, bottom = 42, scale = 4 },
				{ id = "pine", x = 201, y = 414, bottom = 446, scale = 4 },
				{ id = "tree", x = 215, y = 399, bottom = 431, scale = 4 },
				{ id = "pine", x = 229, y = -4, bottom = 28, scale = 4 },
				{ id = "pine", x = 240, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 229, y = 413, bottom = 445, scale = 4 },
				{ id = "tree2", x = 240, y = 399, bottom = 431, scale = 4 },
				{ id = "tree2", x = 252, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 265, y = 11, bottom = 43, scale = 4 },
				{ id = "pine", x = 251, y = 414, bottom = 446, scale = 4 },
				{ id = "tree", x = 263, y = 396, bottom = 428, scale = 4 },
				{ id = "tree2", x = 278, y = -8, bottom = 24, scale = 4 },
				{ id = "tree", x = 293, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 281, y = 411, bottom = 443, scale = 4 },
				{ id = "pine", x = 294, y = 398, bottom = 430, scale = 4 },
				{ id = "pine", x = 303, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 319, y = 13, bottom = 45, scale = 4 },
				{ id = "tree2", x = 305, y = 412, bottom = 444, scale = 4 },
				{ id = "pine", x = 319, y = 397, bottom = 429, scale = 4 },
				{ id = "pine", x = 328, y = -4, bottom = 28, scale = 4 },
				{ id = "pine", x = 343, y = 11, bottom = 43, scale = 4 },
				{ id = "pine", x = 329, y = 415, bottom = 447, scale = 4 },
				{ id = "pine", x = 342, y = 398, bottom = 430, scale = 4 },
				{ id = "tree", x = 353, y = -6, bottom = 26, scale = 4 },
				{ id = "pine", x = 367, y = 13, bottom = 45, scale = 4 },
				{ id = "pine", x = 353, y = 412, bottom = 444, scale = 4 },
				{ id = "pine", x = 369, y = 398, bottom = 430, scale = 4 },
				{ id = "tree2", x = 378, y = -7, bottom = 25, scale = 4 },
				{ id = "pine", x = 393, y = 10, bottom = 42, scale = 4 },
				{ id = "pine", x = 381, y = 412, bottom = 444, scale = 4 },
				{ id = "tree", x = 395, y = 396, bottom = 428, scale = 4 },
				{ id = "pine", x = 408, y = -5, bottom = 27, scale = 4 },
				{ id = "pine", x = 421, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 407, y = 413, bottom = 445, scale = 4 },
				{ id = "pine", x = 418, y = 396, bottom = 428, scale = 4 },
				{ id = "tree2", x = 430, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 444, y = 13, bottom = 45, scale = 4 },
				{ id = "tree2", x = 430, y = 411, bottom = 443, scale = 4 },
				{ id = "pine", x = 444, y = 399, bottom = 431, scale = 4 },
				{ id = "tree2", x = 456, y = -4, bottom = 28, scale = 4 },
				{ id = "tree2", x = 468, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 457, y = 412, bottom = 444, scale = 4 },
				{ id = "pine", x = 473, y = 398, bottom = 430, scale = 4 },
				{ id = "pine", x = 481, y = -7, bottom = 25, scale = 4 },
				{ id = "pine", x = 498, y = 13, bottom = 45, scale = 4 },
				{ id = "tree2", x = 482, y = 411, bottom = 443, scale = 4 },
				{ id = "tree", x = 495, y = 395, bottom = 427, scale = 4 },
				{ id = "pine", x = 509, y = -7, bottom = 25, scale = 4 },
				{ id = "tree2", x = 524, y = 10, bottom = 42, scale = 4 },
				{ id = "pine", x = 511, y = 412, bottom = 444, scale = 4 },
				{ id = "tree2", x = 525, y = 396, bottom = 428, scale = 4 },
				{ id = "tree", x = 536, y = -4, bottom = 28, scale = 4 },
				{ id = "pine", x = 549, y = 10, bottom = 42, scale = 4 },
				{ id = "pine", x = 535, y = 411, bottom = 443, scale = 4 },
				{ id = "tree", x = 547, y = 398, bottom = 430, scale = 4 },
				{ id = "pine", x = 561, y = -9, bottom = 23, scale = 4 },
				{ id = "pine", x = 570, y = 9, bottom = 41, scale = 4 },
				{ id = "pine", x = 561, y = 411, bottom = 443, scale = 4 },
				{ id = "tree2", x = 571, y = 396, bottom = 428, scale = 4 },
				{ id = "tree2", x = 586, y = -8, bottom = 24, scale = 4 },
				{ id = "tree", x = 601, y = 9, bottom = 41, scale = 4 },
				{ id = "pine", x = 584, y = 414, bottom = 446, scale = 4 },
				{ id = "pine", x = 599, y = 395, bottom = 427, scale = 4 },
				{ id = "pine", x = -3, y = 25, bottom = 57, scale = 4 },
				{ id = "tree2", x = 19, y = 37, bottom = 69, scale = 4 },
				{ id = "tree", x = 577, y = 25, bottom = 57, scale = 4 },
				{ id = "tree", x = 558, y = 37, bottom = 69, scale = 4 },
				{ id = "pine", x = -2, y = 44, bottom = 76, scale = 4 },
				{ id = "tree2", x = 22, y = 54, bottom = 86, scale = 4 },
				{ id = "pine", x = 579, y = 48, bottom = 80, scale = 4 },
				{ id = "pine", x = 554, y = 56, bottom = 88, scale = 4 },
				{ id = "pine", x = -3, y = 67, bottom = 99, scale = 4 },
				{ id = "tree2", x = 19, y = 76, bottom = 108, scale = 4 },
				{ id = "pine", x = 580, y = 66, bottom = 98, scale = 4 },
				{ id = "pine", x = 559, y = 77, bottom = 109, scale = 4 },
				{ id = "pine", x = -1, y = 90, bottom = 122, scale = 4 },
				{ id = "tree2", x = 22, y = 99, bottom = 131, scale = 4 },
				{ id = "tree2", x = 577, y = 87, bottom = 119, scale = 4 },
				{ id = "pine", x = 558, y = 96, bottom = 128, scale = 4 },
				{ id = "pine", x = -4, y = 110, bottom = 142, scale = 4 },
				{ id = "pine", x = 19, y = 120, bottom = 152, scale = 4 },
				{ id = "pine", x = 579, y = 107, bottom = 139, scale = 4 },
				{ id = "pine", x = 559, y = 120, bottom = 152, scale = 4 },
				{ id = "pine", x = -4, y = 233, bottom = 265, scale = 4 },
				{ id = "pine", x = 21, y = 241, bottom = 273, scale = 4 },
				{ id = "tree", x = 577, y = 235, bottom = 267, scale = 4 },
				{ id = "tree2", x = 559, y = 242, bottom = 274, scale = 4 },
				{ id = "pine", x = -2, y = 256, bottom = 288, scale = 4 },
				{ id = "pine", x = 18, y = 264, bottom = 296, scale = 4 },
				{ id = "tree", x = 580, y = 254, bottom = 286, scale = 4 },
				{ id = "pine", x = 554, y = 263, bottom = 295, scale = 4 },
				{ id = "tree", x = -4, y = 277, bottom = 309, scale = 4 },
				{ id = "pine", x = 18, y = 283, bottom = 315, scale = 4 },
				{ id = "pine", x = 575, y = 276, bottom = 308, scale = 4 },
				{ id = "tree2", x = 554, y = 284, bottom = 316, scale = 4 },
				{ id = "tree", x = -3, y = 297, bottom = 329, scale = 4 },
				{ id = "tree2", x = 22, y = 307, bottom = 339, scale = 4 },
				{ id = "pine", x = 578, y = 296, bottom = 328, scale = 4 },
				{ id = "tree", x = 558, y = 304, bottom = 336, scale = 4 },
				{ id = "pine", x = -5, y = 317, bottom = 349, scale = 4 },
				{ id = "pine", x = 22, y = 327, bottom = 359, scale = 4 },
				{ id = "pine", x = 578, y = 316, bottom = 348, scale = 4 },
				{ id = "tree", x = 554, y = 325, bottom = 357, scale = 4 },
				{ id = "tree2", x = 1, y = 339, bottom = 371, scale = 4 },
				{ id = "pine", x = 19, y = 345, bottom = 377, scale = 4 },
				{ id = "pine", x = 576, y = 336, bottom = 368, scale = 4 },
				{ id = "pine", x = 558, y = 348, bottom = 380, scale = 4 },
				{ id = "tree", x = 0, y = 357, bottom = 389, scale = 4 },
				{ id = "tree2", x = 21, y = 368, bottom = 400, scale = 4 },
				{ id = "tree2", x = 578, y = 358, bottom = 390, scale = 4 },
				{ id = "pine", x = 554, y = 370, bottom = 402, scale = 4 },
				{ id = "tree2", x = 0, y = 379, bottom = 411, scale = 4 },
				{ id = "pine", x = 18, y = 390, bottom = 422, scale = 4 },
				{ id = "pine", x = 579, y = 382, bottom = 414, scale = 4 },
				{ id = "pine", x = 558, y = 389, bottom = 421, scale = 4 },
				{ id = "tree2", x = 493, y = 111, bottom = 143, scale = 4 },
				{ id = "bigtree", x = 238, y = 97, bottom = 145, scale = 4 },
				{ id = "bigtree", x = 470, y = 232, bottom = 280, scale = 4 },
				{ id = "pine", x = 381, y = 141, bottom = 173, scale = 4 },
				{ id = "pine", x = 116, y = 103, bottom = 135, scale = 4 },
				{ id = "pine", x = 243, y = 296, bottom = 328, scale = 4 },
				{ id = "pine", x = 375, y = 256, bottom = 288, scale = 4 },
				{ id = "tree2", x = 203, y = 216, bottom = 248, scale = 4 },
				{ id = "pine", x = 134, y = 279, bottom = 311, scale = 4 },
				{ id = "pine", x = 349, y = 334, bottom = 366, scale = 4 },
				{ id = "tree2", x = 440, y = 315, bottom = 347, scale = 4 },
				{ id = "pine", x = 94, y = 217, bottom = 249, scale = 4 },
				{ id = "bigtree", x = 261, y = 191, bottom = 239, scale = 4 },
				{ id = "pine", x = 394, y = 78, bottom = 110, scale = 4 },
				{ id = "pine", x = 185, y = 89, bottom = 121, scale = 4 },
				{ id = "pine", x = 310, y = 263, bottom = 295, scale = 4 },
				{ id = "bush2", x = 181, y = 382, bottom = 398, scale = 4 },
				{ id = "bush2", x = 479, y = 100, bottom = 116, scale = 4 },
				{ id = "bush", x = 244, y = 343, bottom = 359, scale = 4 },
				{ id = "bush2", x = 302, y = 69, bottom = 85, scale = 4 },
				{ id = "bush2", x = 252, y = 81, bottom = 97, scale = 4 },
				{ id = "bush2", x = 68, y = 170, bottom = 186, scale = 4 },
				{ id = "bush2", x = 68, y = 303, bottom = 319, scale = 4 },
				{ id = "bush2", x = 516, y = 242, bottom = 258, scale = 4 },
				{ id = "bush", x = 118, y = 84, bottom = 100, scale = 4 },
				{ id = "bush", x = 452, y = 134, bottom = 150, scale = 4 },
				{ id = "bush2", x = 94, y = 281, bottom = 297, scale = 4 },
				{ id = "bush", x = 304, y = 123, bottom = 139, scale = 4 },
				{ id = "bush", x = 499, y = 64, bottom = 80, scale = 4 },
				{ id = "bush2", x = 159, y = 106, bottom = 122, scale = 4 },
				{ id = "bush2", x = 219, y = 64, bottom = 80, scale = 4 },
				{ id = "bush2", x = 416, y = 289, bottom = 305, scale = 4 },
			},
			zones = {
				{ name = "북쪽 버섯밭", count = 7, x0 = 80, y0 = 64, x1 = 304, y1 = 176, species = {
					2,
				} },
				{ name = "동쪽 버섯밭", count = 8, x0 = 400, y0 = 240, x1 = 560, y1 = 400, species = {
					2,
				} },
				{ name = "남쪽 버섯밭", count = 7, x0 = 80, y0 = 240, x1 = 304, y1 = 400, species = {
					2,
				} },
			},
			portals = {
				{ name = "새싹 들판 2 가는 길", x0 = 0, y0 = 192, x1 = 16, y1 = 224, to = "field2", arrive = "door" },
				{ name = "나비 언덕 1 가는 길", x0 = 592, y0 = 192, x1 = 608, y1 = 224, to = "hill1", arrive = "door" },
			},
			mons = {},
			npcs = {},
		},
		hill1 = {
			name = "나비 언덕 1", w = 38, h = 28, indoor = false,
			outside = { 173, 188, 58 },
			ground = { w = 608, h = 448 },
			spawn = { x = 48, y = 230 },
			blocked = {
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000011110000000000000000000000000000000000011110000000000000000000000000000000000000000011110000000000000000000000000000000",
				"00111100111100111100111100011110011110001111001111000111100111100111100011110001111001111001111000111100111100111100011110011110011110011110001111001111",
				"00111100111100111100111100011110011110001111001111000111100111100111100011110001111001111001111000111100111100111100011110011110011110011110001111001111",
				"00111100111100111100111100011110000000001111001111000111100111100111100000000001111001111001111000111100111100111100000000011110011110011110001111001111",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000111100000000111100000000011110000111101111001111000000000111100000000011110000000000000000111100000000000000000000000000000000001111000000000",
				"00000111100111100011110111100011110011110000111101111001111000111100111100011110011110001111001111000111101111000111100011110011110001111001111000111100",
				"00000111100111100011110111100011110011110000111101111001111000111100111100011110011110001111001111000111101111000111100011110011110001111001111000111100",
				"00000111100000000011110000000011110000000000000000000000000000111100000000011110000000001111001111000000001111000111100011110011110001111000000000111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"01111001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"00000001111000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"01111000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001110000001111000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001110000001111011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"01111001111000000000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000111000000000000000000000000000111100000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111101111000000000000000001111000000111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000001111000000111000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000001111000000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111101111000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000011110111100",
				"00000001111000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000011110",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000011110",
				"00000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000111100000000000000000011110",
				"00000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000111100000000000111100000000",
				"00000000000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000011100000000000000000000000000111100000000",
				"00000000000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000000000000000000000000000000000111100011110",
				"00000000000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000011110",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000001111000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000001111000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000011110000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000000000011110",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000000000011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000001111000000",
				"00000001111000000000000000000000000000000000000000000000000000111110000000000000000000000000000001111000000000000000000000000000000111100000001111000000",
				"00111100000000000000000000000000000000000000000000000000000000111110000000000000000000000000000001111000000000000000000000000000000000000000001111000000",
				"00111100000000000000000000000000000000000000000000000000000000111110000000000000000000000000000001111000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111011110",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"01111011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000011110000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000111110000000000000000000000001111011110",
				"00000011110000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000111110000000000000000000000001111000000",
				"00000011110000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000111110000000000000000000000001111000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000111110000000000000000000000000000111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000111100",
				"01111001111000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000011110111100",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000011110011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"01111001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111011110",
				"00000011110000000111100111100011110000000001111001111000000000000000000000000000000000000000000000000111100111100000000011110011110000000011111111000000",
				"00001111110011110111100111100011110001111001111001111000111100111100000000000000000000001111001111000111100111100111100011110011110001111011111111111001",
				"00001111000011110111100111100011110001111001111001111000111100111100000000000000000000001111001111000111100111100111100011110011110001111011110001111001",
				"00001111000011110000000000000000000001111000000000000000111100111100000000000000000000001111001111000000000000000111100000000000000001111000000001111001",
				"00000000000000000000000000000000011110000000000000000111101111000000000000000000000001111000000000111101111000000000000000111100000000000000000000001111",
				"01111000111101111000111100011110011110001111011110000111101111000000000000000000000001111011110000111101111000111100111100111100011110001111001111001111",
				"01111000111101111000111100011110011110001111011110000111101111000000000000000000000001111011110000111101111000111100111100111100011110001111001111001111",
				"01111000111101111000111100011110000000001111011110000000000000000000000000000000000000000011110000000000000000111100111100000000011110001111001111000000",
			},
			objects = {
				{ id = "tree2", x = -2, y = -7, bottom = 25, scale = 4 },
				{ id = "tree2", x = 11, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = -2, y = 413, bottom = 445, scale = 4 },
				{ id = "tree2", x = 6, y = 396, bottom = 428, scale = 4 },
				{ id = "pine", x = 22, y = -8, bottom = 24, scale = 4 },
				{ id = "tree2", x = 36, y = 11, bottom = 43, scale = 4 },
				{ id = "tree2", x = 23, y = 413, bottom = 445, scale = 4 },
				{ id = "tree2", x = 38, y = 396, bottom = 428, scale = 4 },
				{ id = "tree2", x = 49, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 64, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 45, y = 414, bottom = 446, scale = 4 },
				{ id = "tree2", x = 59, y = 395, bottom = 427, scale = 4 },
				{ id = "tree2", x = 74, y = -5, bottom = 27, scale = 4 },
				{ id = "pine", x = 85, y = 10, bottom = 42, scale = 4 },
				{ id = "tree2", x = 73, y = 415, bottom = 447, scale = 4 },
				{ id = "tree", x = 85, y = 395, bottom = 427, scale = 4 },
				{ id = "tree2", x = 100, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 112, y = 13, bottom = 45, scale = 4 },
				{ id = "tree2", x = 101, y = 415, bottom = 447, scale = 4 },
				{ id = "tree2", x = 113, y = 396, bottom = 428, scale = 4 },
				{ id = "tree", x = 125, y = -8, bottom = 24, scale = 4 },
				{ id = "tree2", x = 138, y = 9, bottom = 41, scale = 4 },
				{ id = "pine", x = 122, y = 411, bottom = 443, scale = 4 },
				{ id = "pine", x = 139, y = 397, bottom = 429, scale = 4 },
				{ id = "tree2", x = 151, y = -7, bottom = 25, scale = 4 },
				{ id = "tree", x = 166, y = 9, bottom = 41, scale = 4 },
				{ id = "tree2", x = 152, y = 415, bottom = 447, scale = 4 },
				{ id = "tree", x = 162, y = 395, bottom = 427, scale = 4 },
				{ id = "tree2", x = 176, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 187, y = 12, bottom = 44, scale = 4 },
				{ id = "tree", x = 173, y = 413, bottom = 445, scale = 4 },
				{ id = "tree", x = 187, y = 396, bottom = 428, scale = 4 },
				{ id = "tree2", x = 204, y = -5, bottom = 27, scale = 4 },
				{ id = "tree2", x = 213, y = 11, bottom = 43, scale = 4 },
				{ id = "pine", x = 203, y = 412, bottom = 444, scale = 4 },
				{ id = "tree", x = 217, y = 396, bottom = 428, scale = 4 },
				{ id = "pine", x = 228, y = -7, bottom = 25, scale = 4 },
				{ id = "tree2", x = 239, y = 13, bottom = 45, scale = 4 },
				{ id = "tree2", x = 225, y = 411, bottom = 443, scale = 4 },
				{ id = "pine", x = 239, y = 398, bottom = 430, scale = 4 },
				{ id = "pine", x = 251, y = -5, bottom = 27, scale = 4 },
				{ id = "tree2", x = 262, y = 10, bottom = 42, scale = 4 },
				{ id = "tree2", x = 279, y = -8, bottom = 24, scale = 4 },
				{ id = "tree", x = 292, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 307, y = -5, bottom = 27, scale = 4 },
				{ id = "pine", x = 317, y = 10, bottom = 42, scale = 4 },
				{ id = "tree", x = 331, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 344, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 330, y = 412, bottom = 444, scale = 4 },
				{ id = "tree", x = 344, y = 397, bottom = 429, scale = 4 },
				{ id = "tree", x = 355, y = -7, bottom = 25, scale = 4 },
				{ id = "tree2", x = 366, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 353, y = 412, bottom = 444, scale = 4 },
				{ id = "pine", x = 370, y = 399, bottom = 431, scale = 4 },
				{ id = "pine", x = 383, y = -7, bottom = 25, scale = 4 },
				{ id = "tree2", x = 395, y = 11, bottom = 43, scale = 4 },
				{ id = "tree2", x = 384, y = 412, bottom = 444, scale = 4 },
				{ id = "tree", x = 395, y = 395, bottom = 427, scale = 4 },
				{ id = "pine", x = 406, y = -4, bottom = 28, scale = 4 },
				{ id = "tree2", x = 416, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 405, y = 411, bottom = 443, scale = 4 },
				{ id = "tree2", x = 418, y = 395, bottom = 427, scale = 4 },
				{ id = "pine", x = 433, y = -5, bottom = 27, scale = 4 },
				{ id = "tree2", x = 445, y = 13, bottom = 45, scale = 4 },
				{ id = "tree2", x = 431, y = 414, bottom = 446, scale = 4 },
				{ id = "tree", x = 446, y = 399, bottom = 431, scale = 4 },
				{ id = "tree2", x = 460, y = -9, bottom = 23, scale = 4 },
				{ id = "tree2", x = 470, y = 13, bottom = 45, scale = 4 },
				{ id = "tree2", x = 455, y = 413, bottom = 445, scale = 4 },
				{ id = "tree", x = 472, y = 395, bottom = 427, scale = 4 },
				{ id = "pine", x = 484, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 496, y = 13, bottom = 45, scale = 4 },
				{ id = "tree2", x = 481, y = 411, bottom = 443, scale = 4 },
				{ id = "pine", x = 495, y = 394, bottom = 426, scale = 4 },
				{ id = "tree2", x = 510, y = -5, bottom = 27, scale = 4 },
				{ id = "tree2", x = 522, y = 13, bottom = 45, scale = 4 },
				{ id = "pine", x = 509, y = 412, bottom = 444, scale = 4 },
				{ id = "tree", x = 523, y = 397, bottom = 429, scale = 4 },
				{ id = "pine", x = 531, y = -7, bottom = 25, scale = 4 },
				{ id = "pine", x = 546, y = 10, bottom = 42, scale = 4 },
				{ id = "tree2", x = 537, y = 412, bottom = 444, scale = 4 },
				{ id = "pine", x = 544, y = 395, bottom = 427, scale = 4 },
				{ id = "tree", x = 558, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 575, y = 13, bottom = 45, scale = 4 },
				{ id = "pine", x = 560, y = 412, bottom = 444, scale = 4 },
				{ id = "tree2", x = 573, y = 398, bottom = 430, scale = 4 },
				{ id = "tree2", x = 586, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 601, y = 9, bottom = 41, scale = 4 },
				{ id = "tree2", x = 583, y = 411, bottom = 443, scale = 4 },
				{ id = "tree", x = 598, y = 396, bottom = 428, scale = 4 },
				{ id = "tree2", x = -4, y = 25, bottom = 57, scale = 4 },
				{ id = "tree2", x = 21, y = 33, bottom = 65, scale = 4 },
				{ id = "tree", x = 577, y = 23, bottom = 55, scale = 4 },
				{ id = "pine", x = 557, y = 36, bottom = 68, scale = 4 },
				{ id = "tree2", x = -4, y = 44, bottom = 76, scale = 4 },
				{ id = "tree2", x = 21, y = 56, bottom = 88, scale = 4 },
				{ id = "tree2", x = 576, y = 47, bottom = 79, scale = 4 },
				{ id = "tree2", x = 558, y = 54, bottom = 86, scale = 4 },
				{ id = "tree2", x = -2, y = 68, bottom = 100, scale = 4 },
				{ id = "pine", x = 19, y = 75, bottom = 107, scale = 4 },
				{ id = "pine", x = 579, y = 69, bottom = 101, scale = 4 },
				{ id = "pine", x = 558, y = 77, bottom = 109, scale = 4 },
				{ id = "pine", x = -3, y = 90, bottom = 122, scale = 4 },
				{ id = "tree", x = 21, y = 97, bottom = 129, scale = 4 },
				{ id = "tree2", x = 579, y = 88, bottom = 120, scale = 4 },
				{ id = "tree", x = 557, y = 96, bottom = 128, scale = 4 },
				{ id = "tree2", x = 1, y = 109, bottom = 141, scale = 4 },
				{ id = "tree", x = 22, y = 118, bottom = 150, scale = 4 },
				{ id = "tree2", x = 575, y = 108, bottom = 140, scale = 4 },
				{ id = "pine", x = 555, y = 119, bottom = 151, scale = 4 },
				{ id = "tree2", x = 0, y = 130, bottom = 162, scale = 4 },
				{ id = "pine", x = 21, y = 140, bottom = 172, scale = 4 },
				{ id = "pine", x = 575, y = 131, bottom = 163, scale = 4 },
				{ id = "tree", x = 556, y = 138, bottom = 170, scale = 4 },
				{ id = "tree", x = 579, y = 149, bottom = 181, scale = 4 },
				{ id = "tree", x = 554, y = 160, bottom = 192, scale = 4 },
				{ id = "tree2", x = 579, y = 170, bottom = 202, scale = 4 },
				{ id = "tree2", x = 560, y = 180, bottom = 212, scale = 4 },
				{ id = "tree2", x = 577, y = 192, bottom = 224, scale = 4 },
				{ id = "tree2", x = 557, y = 203, bottom = 235, scale = 4 },
				{ id = "tree", x = 580, y = 214, bottom = 246, scale = 4 },
				{ id = "tree2", x = 556, y = 222, bottom = 254, scale = 4 },
				{ id = "pine", x = 21, y = 241, bottom = 273, scale = 4 },
				{ id = "tree", x = 580, y = 233, bottom = 265, scale = 4 },
				{ id = "tree", x = 558, y = 246, bottom = 278, scale = 4 },
				{ id = "tree2", x = -2, y = 253, bottom = 285, scale = 4 },
				{ id = "pine", x = 22, y = 265, bottom = 297, scale = 4 },
				{ id = "tree", x = 576, y = 256, bottom = 288, scale = 4 },
				{ id = "tree2", x = 560, y = 264, bottom = 296, scale = 4 },
				{ id = "tree2", x = 1, y = 276, bottom = 308, scale = 4 },
				{ id = "tree2", x = 17, y = 284, bottom = 316, scale = 4 },
				{ id = "tree2", x = 580, y = 276, bottom = 308, scale = 4 },
				{ id = "pine", x = 558, y = 285, bottom = 317, scale = 4 },
				{ id = "tree", x = -4, y = 294, bottom = 326, scale = 4 },
				{ id = "tree2", x = 17, y = 306, bottom = 338, scale = 4 },
				{ id = "pine", x = 580, y = 297, bottom = 329, scale = 4 },
				{ id = "tree2", x = 558, y = 305, bottom = 337, scale = 4 },
				{ id = "tree2", x = -4, y = 317, bottom = 349, scale = 4 },
				{ id = "tree2", x = 19, y = 325, bottom = 357, scale = 4 },
				{ id = "tree2", x = 575, y = 316, bottom = 348, scale = 4 },
				{ id = "pine", x = 554, y = 324, bottom = 356, scale = 4 },
				{ id = "pine", x = -4, y = 338, bottom = 370, scale = 4 },
				{ id = "pine", x = 21, y = 349, bottom = 381, scale = 4 },
				{ id = "tree2", x = 578, y = 338, bottom = 370, scale = 4 },
				{ id = "tree", x = 558, y = 347, bottom = 379, scale = 4 },
				{ id = "tree2", x = -1, y = 356, bottom = 388, scale = 4 },
				{ id = "tree2", x = 20, y = 368, bottom = 400, scale = 4 },
				{ id = "tree2", x = 580, y = 359, bottom = 391, scale = 4 },
				{ id = "tree2", x = 554, y = 367, bottom = 399, scale = 4 },
				{ id = "tree", x = -4, y = 379, bottom = 411, scale = 4 },
				{ id = "tree2", x = 16, y = 389, bottom = 421, scale = 4 },
				{ id = "tree2", x = 579, y = 381, bottom = 413, scale = 4 },
				{ id = "pine", x = 559, y = 388, bottom = 420, scale = 4 },
				{ id = "tree2", x = 175, y = 307, bottom = 339, scale = 4 },
				{ id = "bigtree", x = 200, y = 150, bottom = 198, scale = 4 },
				{ id = "tree", x = 401, y = 178, bottom = 210, scale = 4 },
				{ id = "tree2", x = 285, y = 139, bottom = 171, scale = 4 },
				{ id = "tree", x = 104, y = 118, bottom = 150, scale = 4 },
				{ id = "tree", x = 355, y = 317, bottom = 349, scale = 4 },
				{ id = "bigtree", x = 318, y = 215, bottom = 263, scale = 4 },
				{ id = "bigtree", x = 437, y = 293, bottom = 341, scale = 4 },
				{ id = "bigtree", x = 236, y = 238, bottom = 286, scale = 4 },
				{ id = "tree", x = 370, y = 102, bottom = 134, scale = 4 },
				{ id = "bush", x = 442, y = 172, bottom = 188, scale = 4 },
				{ id = "bush2", x = 428, y = 357, bottom = 373, scale = 4 },
				{ id = "bush2", x = 500, y = 172, bottom = 188, scale = 4 },
				{ id = "bush", x = 258, y = 109, bottom = 125, scale = 4 },
				{ id = "bush", x = 524, y = 259, bottom = 275, scale = 4 },
				{ id = "bush", x = 151, y = 128, bottom = 144, scale = 4 },
				{ id = "bush2", x = 388, y = 264, bottom = 280, scale = 4 },
				{ id = "bush", x = 529, y = 95, bottom = 111, scale = 4 },
				{ id = "bush2", x = 326, y = 136, bottom = 152, scale = 4 },
				{ id = "bush2", x = 104, y = 73, bottom = 89, scale = 4 },
				{ id = "bush", x = 74, y = 171, bottom = 187, scale = 4 },
				{ id = "bush2", x = 389, y = 163, bottom = 179, scale = 4 },
			},
			zones = {
				{ name = "북쪽 꽃밭", count = 9, x0 = 80, y0 = 64, x1 = 528, y1 = 176, species = {
					3,
				} },
				{ name = "남서 꽃밭", count = 6, x0 = 80, y0 = 272, x1 = 256, y1 = 400, species = {
					3,
				} },
				{ name = "동쪽 꽃밭", count = 7, x0 = 368, y0 = 224, x1 = 544, y1 = 400, species = {
					3,
				} },
			},
			portals = {
				{ name = "새싹 들판 3 가는 길", x0 = 0, y0 = 208, x1 = 16, y1 = 240, to = "field3", arrive = "door" },
				{ name = "나비 언덕 2 가는 길", x0 = 288, y0 = 432, x1 = 320, y1 = 448, to = "hill2", arrive = "door" },
			},
			mons = {},
			npcs = {},
		},
		hill2 = {
			name = "나비 언덕 2", w = 38, h = 28, indoor = false,
			outside = { 173, 188, 58 },
			ground = { w = 608, h = 448 },
			spawn = { x = 304, y = 42 },
			blocked = {
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000001111000000000000001111",
				"01111000111101111000011110111100011110011110000111100111100111100000000000000000000001111011110001111000111100111100111100111100001111001111001111001111",
				"01111000111101111000011110111100011110011110000111100111100111100000000000000000000001111011110001111000111100111100111100111100001111001111001111001111",
				"01111000111101111000011110111100000000011110000111100111100111100000000000000000000001111011110001111000111100000000111100111100000000001111001111000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00001111001111001111000011110000000001111001111001111000111100000000000000000000000000000000000000000111100000000111100011110000000011110001111001111001",
				"00001111001111001111000011110001111001111001111001111000111100111100000000000000000000001111001111000111100111100111100011110011110011110001111001111001",
				"00001111001111001111000011110001111001111001111001111000111100111100000000000000000000001111001111000111100111100111100011110011110011110001111001111001",
				"00000000000000000000000000000001111000000000000000000000000000111100000000000000000000001111001111000000000111100000000000000011110000000000000000000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000011110011110",
				"01111011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000011110000000",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000011110000000",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000001110000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111101111000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000001111000000000000000000000000000000011110111100",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000011110000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000011110000000000000000011110011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111011110000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000011110000000000000001110000001111000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000011110000000",
				"00000011110000000000000001110000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000001110000000000000000000000000000000000000000000000000000000011110000000000000011100000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000111100",
				"00111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000111100",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000011110000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"01111000000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"01111001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"01111001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111000000000000000000000000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111000000000000000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111000000000000000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011111000000000000000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000011110000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111100000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111100000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111101111000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000001111000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000001111000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111100000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111100000000000000000000000000000000000000001111000000000000000000000000000000000000000000111100000011110000000000000000000000000000000000011110011110",
				"00000001111000000000000000000000000000000000001111000000000000000000000000000000000000000000111100000011110000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000111100000000000000000000000000000000000000000000000000111100000011110000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000111100000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000011110",
				"01111001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"00000001111000000111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001110000000000000000011110000000",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001110000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000001110000000000000000000000111100",
				"00111100111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000111100",
				"00000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111011110",
				"00001111111111100000000000000000000000000000000000000000000000000000011110000000000000001111000000000000000000000000000111100000000011110011111111000000",
				"00001111111111100111100111100011110011110001111000111101111001111000011110111100011110001111000111101111000111100111100111100011110011110011111111111000",
				"00001111000111100111100111100011110011110001111000111101111001111000011110111100011110001111000111101111000111100111100111100011110011110011110001111000",
				"00000000000000000111100111100011110011110001111000111101111001111000000000111100011110000000000111101111000111100111100000000011110000000000000001111000",
				"00000000000000000000011110000000000000000000001111001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111",
				"00111100111100111100011110011110011110001111001111001111000111100111100011110011110001111011110000111100111101111000011110111100001111011110001111001111",
				"00111100111100111100011110011110011110001111001111001111000111100111100011110011110001111011110000111100111101111000011110111100001111011110001111001111",
				"00111100111100111100000000011110011110001111000000000000000111100111100011110011110001111011110000111100111101111000011110111100001111011110001111000000",
			},
			objects = {
				{ id = "tree2", x = -2, y = -7, bottom = 25, scale = 4 },
				{ id = "tree2", x = 9, y = 10, bottom = 42, scale = 4 },
				{ id = "tree2", x = -1, y = 414, bottom = 446, scale = 4 },
				{ id = "tree", x = 10, y = 395, bottom = 427, scale = 4 },
				{ id = "tree2", x = 25, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 33, y = 11, bottom = 43, scale = 4 },
				{ id = "tree2", x = 22, y = 413, bottom = 445, scale = 4 },
				{ id = "tree", x = 36, y = 395, bottom = 427, scale = 4 },
				{ id = "tree2", x = 45, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 58, y = 9, bottom = 41, scale = 4 },
				{ id = "pine", x = 49, y = 412, bottom = 444, scale = 4 },
				{ id = "tree2", x = 59, y = 396, bottom = 428, scale = 4 },
				{ id = "pine", x = 75, y = -5, bottom = 27, scale = 4 },
				{ id = "tree2", x = 87, y = 9, bottom = 41, scale = 4 },
				{ id = "pine", x = 76, y = 410, bottom = 442, scale = 4 },
				{ id = "tree", x = 85, y = 397, bottom = 429, scale = 4 },
				{ id = "tree2", x = 97, y = -5, bottom = 27, scale = 4 },
				{ id = "pine", x = 115, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 102, y = 413, bottom = 445, scale = 4 },
				{ id = "tree", x = 114, y = 398, bottom = 430, scale = 4 },
				{ id = "tree2", x = 122, y = -8, bottom = 24, scale = 4 },
				{ id = "tree", x = 139, y = 12, bottom = 44, scale = 4 },
				{ id = "tree", x = 124, y = 415, bottom = 447, scale = 4 },
				{ id = "tree2", x = 137, y = 397, bottom = 429, scale = 4 },
				{ id = "pine", x = 148, y = -4, bottom = 28, scale = 4 },
				{ id = "pine", x = 164, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 154, y = 413, bottom = 445, scale = 4 },
				{ id = "pine", x = 164, y = 396, bottom = 428, scale = 4 },
				{ id = "tree2", x = 178, y = -5, bottom = 27, scale = 4 },
				{ id = "tree2", x = 188, y = 10, bottom = 42, scale = 4 },
				{ id = "pine", x = 176, y = 412, bottom = 444, scale = 4 },
				{ id = "tree", x = 190, y = 398, bottom = 430, scale = 4 },
				{ id = "tree", x = 203, y = -8, bottom = 24, scale = 4 },
				{ id = "tree2", x = 217, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 198, y = 410, bottom = 442, scale = 4 },
				{ id = "tree2", x = 212, y = 398, bottom = 430, scale = 4 },
				{ id = "tree", x = 227, y = -5, bottom = 27, scale = 4 },
				{ id = "tree2", x = 239, y = 13, bottom = 45, scale = 4 },
				{ id = "pine", x = 228, y = 415, bottom = 447, scale = 4 },
				{ id = "tree2", x = 237, y = 398, bottom = 430, scale = 4 },
				{ id = "tree2", x = 251, y = 415, bottom = 447, scale = 4 },
				{ id = "pine", x = 266, y = 394, bottom = 426, scale = 4 },
				{ id = "tree2", x = 281, y = 413, bottom = 445, scale = 4 },
				{ id = "tree", x = 288, y = 399, bottom = 431, scale = 4 },
				{ id = "tree", x = 304, y = 413, bottom = 445, scale = 4 },
				{ id = "tree2", x = 316, y = 397, bottom = 429, scale = 4 },
				{ id = "tree", x = 331, y = -8, bottom = 24, scale = 4 },
				{ id = "tree", x = 343, y = 12, bottom = 44, scale = 4 },
				{ id = "tree", x = 333, y = 414, bottom = 446, scale = 4 },
				{ id = "tree", x = 343, y = 395, bottom = 427, scale = 4 },
				{ id = "pine", x = 354, y = -7, bottom = 25, scale = 4 },
				{ id = "tree2", x = 369, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 353, y = 415, bottom = 447, scale = 4 },
				{ id = "pine", x = 371, y = 396, bottom = 428, scale = 4 },
				{ id = "tree", x = 380, y = -5, bottom = 27, scale = 4 },
				{ id = "tree2", x = 396, y = 10, bottom = 42, scale = 4 },
				{ id = "tree2", x = 382, y = 415, bottom = 447, scale = 4 },
				{ id = "tree2", x = 391, y = 396, bottom = 428, scale = 4 },
				{ id = "tree2", x = 408, y = -7, bottom = 25, scale = 4 },
				{ id = "tree2", x = 419, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 406, y = 414, bottom = 446, scale = 4 },
				{ id = "tree2", x = 419, y = 398, bottom = 430, scale = 4 },
				{ id = "pine", x = 433, y = -8, bottom = 24, scale = 4 },
				{ id = "tree", x = 445, y = 11, bottom = 43, scale = 4 },
				{ id = "pine", x = 430, y = 413, bottom = 445, scale = 4 },
				{ id = "tree2", x = 445, y = 399, bottom = 431, scale = 4 },
				{ id = "tree2", x = 456, y = -6, bottom = 26, scale = 4 },
				{ id = "pine", x = 471, y = 11, bottom = 43, scale = 4 },
				{ id = "tree2", x = 460, y = 415, bottom = 447, scale = 4 },
				{ id = "tree2", x = 468, y = 395, bottom = 427, scale = 4 },
				{ id = "tree2", x = 481, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 497, y = 12, bottom = 44, scale = 4 },
				{ id = "tree", x = 480, y = 413, bottom = 445, scale = 4 },
				{ id = "tree2", x = 498, y = 396, bottom = 428, scale = 4 },
				{ id = "tree2", x = 511, y = -9, bottom = 23, scale = 4 },
				{ id = "tree", x = 520, y = 10, bottom = 42, scale = 4 },
				{ id = "tree2", x = 511, y = 413, bottom = 445, scale = 4 },
				{ id = "tree", x = 521, y = 395, bottom = 427, scale = 4 },
				{ id = "tree2", x = 536, y = -7, bottom = 25, scale = 4 },
				{ id = "pine", x = 546, y = 9, bottom = 41, scale = 4 },
				{ id = "pine", x = 533, y = 412, bottom = 444, scale = 4 },
				{ id = "tree2", x = 546, y = 395, bottom = 427, scale = 4 },
				{ id = "pine", x = 560, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 574, y = 10, bottom = 42, scale = 4 },
				{ id = "pine", x = 558, y = 414, bottom = 446, scale = 4 },
				{ id = "tree2", x = 571, y = 396, bottom = 428, scale = 4 },
				{ id = "tree2", x = 584, y = -9, bottom = 23, scale = 4 },
				{ id = "tree", x = 597, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 585, y = 411, bottom = 443, scale = 4 },
				{ id = "pine", x = 600, y = 397, bottom = 429, scale = 4 },
				{ id = "tree", x = -1, y = 26, bottom = 58, scale = 4 },
				{ id = "pine", x = 18, y = 33, bottom = 65, scale = 4 },
				{ id = "tree2", x = 575, y = 28, bottom = 60, scale = 4 },
				{ id = "tree2", x = 555, y = 35, bottom = 67, scale = 4 },
				{ id = "tree2", x = 1, y = 45, bottom = 77, scale = 4 },
				{ id = "pine", x = 17, y = 58, bottom = 90, scale = 4 },
				{ id = "tree2", x = 576, y = 48, bottom = 80, scale = 4 },
				{ id = "tree", x = 559, y = 55, bottom = 87, scale = 4 },
				{ id = "tree2", x = -2, y = 69, bottom = 101, scale = 4 },
				{ id = "pine", x = 17, y = 77, bottom = 109, scale = 4 },
				{ id = "tree2", x = 581, y = 68, bottom = 100, scale = 4 },
				{ id = "tree2", x = 556, y = 75, bottom = 107, scale = 4 },
				{ id = "pine", x = 1, y = 90, bottom = 122, scale = 4 },
				{ id = "tree2", x = 20, y = 97, bottom = 129, scale = 4 },
				{ id = "tree2", x = 575, y = 87, bottom = 119, scale = 4 },
				{ id = "tree", x = 557, y = 100, bottom = 132, scale = 4 },
				{ id = "tree2", x = 1, y = 110, bottom = 142, scale = 4 },
				{ id = "tree2", x = 22, y = 118, bottom = 150, scale = 4 },
				{ id = "tree2", x = 578, y = 109, bottom = 141, scale = 4 },
				{ id = "tree", x = 556, y = 118, bottom = 150, scale = 4 },
				{ id = "tree2", x = -4, y = 131, bottom = 163, scale = 4 },
				{ id = "pine", x = 17, y = 138, bottom = 170, scale = 4 },
				{ id = "pine", x = 581, y = 127, bottom = 159, scale = 4 },
				{ id = "tree2", x = 556, y = 139, bottom = 171, scale = 4 },
				{ id = "tree", x = -2, y = 150, bottom = 182, scale = 4 },
				{ id = "tree2", x = 17, y = 159, bottom = 191, scale = 4 },
				{ id = "tree2", x = 576, y = 149, bottom = 181, scale = 4 },
				{ id = "tree", x = -4, y = 172, bottom = 204, scale = 4 },
				{ id = "tree2", x = 20, y = 179, bottom = 211, scale = 4 },
				{ id = "tree2", x = -2, y = 192, bottom = 224, scale = 4 },
				{ id = "tree2", x = 17, y = 202, bottom = 234, scale = 4 },
				{ id = "pine", x = -1, y = 213, bottom = 245, scale = 4 },
				{ id = "tree2", x = 21, y = 223, bottom = 255, scale = 4 },
				{ id = "pine", x = 0, y = 234, bottom = 266, scale = 4 },
				{ id = "tree2", x = 18, y = 241, bottom = 273, scale = 4 },
				{ id = "pine", x = -1, y = 254, bottom = 286, scale = 4 },
				{ id = "tree2", x = 21, y = 265, bottom = 297, scale = 4 },
				{ id = "pine", x = 556, y = 264, bottom = 296, scale = 4 },
				{ id = "tree2", x = 0, y = 273, bottom = 305, scale = 4 },
				{ id = "pine", x = 21, y = 285, bottom = 317, scale = 4 },
				{ id = "pine", x = 579, y = 275, bottom = 307, scale = 4 },
				{ id = "tree2", x = 555, y = 284, bottom = 316, scale = 4 },
				{ id = "tree", x = -2, y = 297, bottom = 329, scale = 4 },
				{ id = "tree2", x = 19, y = 306, bottom = 338, scale = 4 },
				{ id = "pine", x = 579, y = 298, bottom = 330, scale = 4 },
				{ id = "tree2", x = 558, y = 305, bottom = 337, scale = 4 },
				{ id = "tree2", x = -1, y = 318, bottom = 350, scale = 4 },
				{ id = "tree2", x = 21, y = 324, bottom = 356, scale = 4 },
				{ id = "tree2", x = 578, y = 316, bottom = 348, scale = 4 },
				{ id = "tree2", x = 557, y = 325, bottom = 357, scale = 4 },
				{ id = "tree2", x = -2, y = 340, bottom = 372, scale = 4 },
				{ id = "tree2", x = 18, y = 349, bottom = 381, scale = 4 },
				{ id = "tree2", x = 575, y = 336, bottom = 368, scale = 4 },
				{ id = "tree", x = 554, y = 346, bottom = 378, scale = 4 },
				{ id = "pine", x = -1, y = 358, bottom = 390, scale = 4 },
				{ id = "pine", x = 22, y = 367, bottom = 399, scale = 4 },
				{ id = "tree", x = 578, y = 357, bottom = 389, scale = 4 },
				{ id = "tree2", x = 555, y = 369, bottom = 401, scale = 4 },
				{ id = "tree2", x = -1, y = 378, bottom = 410, scale = 4 },
				{ id = "tree", x = 21, y = 391, bottom = 423, scale = 4 },
				{ id = "tree2", x = 578, y = 381, bottom = 413, scale = 4 },
				{ id = "tree", x = 559, y = 388, bottom = 420, scale = 4 },
				{ id = "tree", x = 177, y = 277, bottom = 309, scale = 4 },
				{ id = "tree2", x = 415, y = 119, bottom = 151, scale = 4 },
				{ id = "tree2", x = 398, y = 283, bottom = 315, scale = 4 },
				{ id = "tree", x = 221, y = 110, bottom = 142, scale = 4 },
				{ id = "tree", x = 110, y = 212, bottom = 244, scale = 4 },
				{ id = "tree2", x = 326, y = 141, bottom = 173, scale = 4 },
				{ id = "tree2", x = 318, y = 296, bottom = 328, scale = 4 },
				{ id = "tree", x = 249, y = 222, bottom = 254, scale = 4 },
				{ id = "tree2", x = 127, y = 132, bottom = 164, scale = 4 },
				{ id = "bigtree", x = 467, y = 169, bottom = 217, scale = 4 },
				{ id = "bush2", x = 368, y = 297, bottom = 313, scale = 4 },
				{ id = "bush2", x = 383, y = 88, bottom = 104, scale = 4 },
				{ id = "bush", x = 407, y = 166, bottom = 182, scale = 4 },
				{ id = "bush", x = 481, y = 370, bottom = 386, scale = 4 },
				{ id = "bush", x = 481, y = 134, bottom = 150, scale = 4 },
				{ id = "bush2", x = 152, y = 302, bottom = 318, scale = 4 },
				{ id = "bush", x = 111, y = 349, bottom = 365, scale = 4 },
				{ id = "bush", x = 396, y = 375, bottom = 391, scale = 4 },
				{ id = "bush", x = 67, y = 359, bottom = 375, scale = 4 },
				{ id = "bush", x = 61, y = 118, bottom = 134, scale = 4 },
				{ id = "bush2", x = 98, y = 157, bottom = 173, scale = 4 },
				{ id = "bush", x = 219, y = 181, bottom = 197, scale = 4 },
			},
			zones = {
				{ name = "서쪽 꽃밭(애벌레)", count = 7, x0 = 64, y0 = 64, x1 = 256, y1 = 224, species = {
					3,
				} },
				{ name = "남쪽 꽃밭", count = 9, x0 = 96, y0 = 272, x1 = 496, y1 = 400, species = {
					3,
					4,
				} },
				{ name = "동쪽 꽃밭(팔랑나비)", count = 7, x0 = 352, y0 = 64, x1 = 560, y1 = 192, species = {
					4,
				} },
			},
			portals = {
				{ name = "나비 언덕 1 가는 길", x0 = 288, y0 = 0, x1 = 320, y1 = 16, to = "hill1", arrive = "door" },
				{ name = "나비 언덕 3 가는 길", x0 = 592, y0 = 224, x1 = 608, y1 = 256, to = "hill3", arrive = "door" },
			},
			mons = {},
			npcs = {},
		},
		hill3 = {
			name = "나비 언덕 3", w = 38, h = 28, indoor = false,
			outside = { 173, 188, 58 },
			ground = { w = 608, h = 448 },
			spawn = { x = 48, y = 246 },
			blocked = {
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"01111000000000000000000000000000001111000000000000000000000111101111000000000000000000000011110000000000000000000000011110000000000000000000000111100000",
				"01111000111100111100011110011110001111001111001111001111000111101111000011110011110011110011110000111101111000111100011110011110011110001111000111101111",
				"01111000111100111100011110011110001111001111001111001111000111101111000011110011110011110011110000111101111000111100011110011110011110001111000111101111",
				"00000000111100111100011110011110000000001111001111001111000000000000000011110011110011110000000000111101111000111100000000011110011110001111000000001111",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00001111000000000111100011110011110011110011110001111000000000111100000000000000011110011110011110000000000000000111100000000011110001111001111001111000",
				"00001111000111100111100011110011110011110011110001111000111100111100111100011110011110011110011110001111000111100111100011110011110001111001111001111000",
				"00001111000111100111100011110011110011110011110001111000111100111100111100011110011110011110011110001111000111100111100011110011110001111001111001111000",
				"00000000000111100000000000000000000000000000000000000000111100000000111100011110000000000000000000001111000111100000000011110000000000000000000000000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000000000000000000000000111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000001111000000000000000000000000000000000000000000000000000000000000000111000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000011110111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000111100",
				"01111001111000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"01111001111000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111100000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111100000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000000111100000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000011110011110",
				"00000000111100000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000111100000000000000000000011110000000",
				"01111000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000111100000000000000000000011110000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000111100000000000000000000000000011110",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000000000011110",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"01111001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"00000000000000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00000000000000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000000000000000000000000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000000000000001111000000000000011110000000000000000000111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000000000000001111000000000000011110000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000111000000000011110000000",
				"00000000000000001111000000000000011110000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000111000000000011110000000",
				"00000000000000000000000000000000000000000000000000000000000000000111100000001111000000000000000000000000000000000000000000000000111000000000011110111100",
				"00000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000011110",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000111000000000000000000000000000000000000011110",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111000000001111000000000000000000001111011110",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000001111000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000001111000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111011110",
				"00000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000011110000000",
				"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000000000000000000000000011110111100",
				"00111100000000000000000000000000000000000000000000000000011100000000000000000000000000001111000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"01111000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"01111001111000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000111000000000111100000000000000000000000000000000000000000001111000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000111000000000111100000000000000000000000000000000000000000001111000000000000000000000011110000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000000011110",
				"00111100000000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00111101111000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"00000001111000000000000000000000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000001111000000000000000000000000011110111100",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000000000000000000011110000000",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00111101111000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"00000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"01111011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"01111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"00000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000",
				"00001111111000000000000000000001111000000000000001111001111000000000111100000000000000000000000000000000000000000111100111100000000000000000111111110000",
				"00001111111111100111100111100001111011110001111001111001111000011110111100000000000000000000011110000111100111100111100111100111100011110001111111110001",
				"00001111000111100111100111100001111011110001111001111001111000011110111100000000000000000000011110000111100111100111100111100111100011110001111011110001",
				"00000000000111100111100111100000000011110001111000000000000000011110000000000000000000000000011110000111100111100000000000000111100011110001111000000001",
				"00000000000001111000111100111100000000011110000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000111100111",
				"11110001111001111000111100111100011110011110000111101111001111000111100011110000000000000000000001111000111100011110011110001111011110001111000111100111",
				"11110001111001111000111100111100011110011110000111101111001111000111100011110000000000000000000001111000111100011110011110001111011110001111000111100111",
				"11110001111000000000000000000000011110000000000000001111001111000111100011110000000000000000000001111000111100011110011110001111011110000000000000000000",
			},
			objects = {
				{ id = "tree2", x = -3, y = -8, bottom = 24, scale = 4 },
				{ id = "tree", x = 7, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = -6, y = 414, bottom = 446, scale = 4 },
				{ id = "pine", x = 7, y = 395, bottom = 427, scale = 4 },
				{ id = "pine", x = 22, y = -5, bottom = 27, scale = 4 },
				{ id = "pine", x = 36, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 21, y = 412, bottom = 444, scale = 4 },
				{ id = "pine", x = 35, y = 398, bottom = 430, scale = 4 },
				{ id = "pine", x = 48, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 59, y = 10, bottom = 42, scale = 4 },
				{ id = "pine", x = 46, y = 411, bottom = 443, scale = 4 },
				{ id = "pine", x = 59, y = 397, bottom = 429, scale = 4 },
				{ id = "pine", x = 77, y = -5, bottom = 27, scale = 4 },
				{ id = "pine", x = 89, y = 9, bottom = 41, scale = 4 },
				{ id = "pine", x = 73, y = 411, bottom = 443, scale = 4 },
				{ id = "tree", x = 85, y = 399, bottom = 431, scale = 4 },
				{ id = "tree2", x = 101, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 112, y = 12, bottom = 44, scale = 4 },
				{ id = "tree", x = 96, y = 412, bottom = 444, scale = 4 },
				{ id = "pine", x = 114, y = 395, bottom = 427, scale = 4 },
				{ id = "tree", x = 126, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 134, y = 10, bottom = 42, scale = 4 },
				{ id = "tree2", x = 126, y = 413, bottom = 445, scale = 4 },
				{ id = "tree", x = 136, y = 398, bottom = 430, scale = 4 },
				{ id = "tree2", x = 153, y = -6, bottom = 26, scale = 4 },
				{ id = "tree2", x = 162, y = 9, bottom = 41, scale = 4 },
				{ id = "pine", x = 149, y = 411, bottom = 443, scale = 4 },
				{ id = "pine", x = 166, y = 398, bottom = 430, scale = 4 },
				{ id = "tree2", x = 175, y = -7, bottom = 25, scale = 4 },
				{ id = "pine", x = 188, y = 9, bottom = 41, scale = 4 },
				{ id = "pine", x = 179, y = 410, bottom = 442, scale = 4 },
				{ id = "tree", x = 187, y = 395, bottom = 427, scale = 4 },
				{ id = "tree2", x = 202, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 216, y = 13, bottom = 45, scale = 4 },
				{ id = "pine", x = 201, y = 414, bottom = 446, scale = 4 },
				{ id = "tree2", x = 213, y = 396, bottom = 428, scale = 4 },
				{ id = "tree2", x = 226, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 239, y = 9, bottom = 41, scale = 4 },
				{ id = "tree", x = 224, y = 414, bottom = 446, scale = 4 },
				{ id = "pine", x = 242, y = 397, bottom = 429, scale = 4 },
				{ id = "pine", x = 250, y = -9, bottom = 23, scale = 4 },
				{ id = "tree", x = 263, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 252, y = 414, bottom = 446, scale = 4 },
				{ id = "pine", x = 266, y = 396, bottom = 428, scale = 4 },
				{ id = "tree2", x = 281, y = -8, bottom = 24, scale = 4 },
				{ id = "tree2", x = 290, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 279, y = 414, bottom = 446, scale = 4 },
				{ id = "tree2", x = 304, y = -5, bottom = 27, scale = 4 },
				{ id = "pine", x = 316, y = 10, bottom = 42, scale = 4 },
				{ id = "tree", x = 329, y = -5, bottom = 27, scale = 4 },
				{ id = "pine", x = 340, y = 11, bottom = 43, scale = 4 },
				{ id = "tree", x = 353, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 366, y = 10, bottom = 42, scale = 4 },
				{ id = "pine", x = 365, y = 399, bottom = 431, scale = 4 },
				{ id = "tree2", x = 383, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 392, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 380, y = 413, bottom = 445, scale = 4 },
				{ id = "tree", x = 394, y = 397, bottom = 429, scale = 4 },
				{ id = "pine", x = 404, y = -4, bottom = 28, scale = 4 },
				{ id = "tree2", x = 421, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 408, y = 413, bottom = 445, scale = 4 },
				{ id = "tree", x = 419, y = 397, bottom = 429, scale = 4 },
				{ id = "pine", x = 434, y = -7, bottom = 25, scale = 4 },
				{ id = "tree2", x = 444, y = 9, bottom = 41, scale = 4 },
				{ id = "tree2", x = 434, y = 412, bottom = 444, scale = 4 },
				{ id = "pine", x = 444, y = 395, bottom = 427, scale = 4 },
				{ id = "tree", x = 459, y = -9, bottom = 23, scale = 4 },
				{ id = "pine", x = 473, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 459, y = 412, bottom = 444, scale = 4 },
				{ id = "tree", x = 470, y = 395, bottom = 427, scale = 4 },
				{ id = "tree", x = 484, y = -6, bottom = 26, scale = 4 },
				{ id = "pine", x = 498, y = 12, bottom = 44, scale = 4 },
				{ id = "tree", x = 486, y = 414, bottom = 446, scale = 4 },
				{ id = "pine", x = 493, y = 398, bottom = 430, scale = 4 },
				{ id = "tree2", x = 506, y = -7, bottom = 25, scale = 4 },
				{ id = "pine", x = 524, y = 11, bottom = 43, scale = 4 },
				{ id = "tree2", x = 506, y = 413, bottom = 445, scale = 4 },
				{ id = "tree2", x = 520, y = 398, bottom = 430, scale = 4 },
				{ id = "tree", x = 535, y = -6, bottom = 26, scale = 4 },
				{ id = "pine", x = 546, y = 9, bottom = 41, scale = 4 },
				{ id = "tree", x = 536, y = 412, bottom = 444, scale = 4 },
				{ id = "tree", x = 547, y = 399, bottom = 431, scale = 4 },
				{ id = "tree2", x = 563, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 573, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 563, y = 411, bottom = 443, scale = 4 },
				{ id = "tree", x = 570, y = 395, bottom = 427, scale = 4 },
				{ id = "tree2", x = 583, y = -7, bottom = 25, scale = 4 },
				{ id = "tree", x = 600, y = 14, bottom = 46, scale = 4 },
				{ id = "tree", x = 588, y = 411, bottom = 443, scale = 4 },
				{ id = "pine", x = 596, y = 398, bottom = 430, scale = 4 },
				{ id = "pine", x = -4, y = 28, bottom = 60, scale = 4 },
				{ id = "tree", x = 21, y = 37, bottom = 69, scale = 4 },
				{ id = "tree2", x = 580, y = 27, bottom = 59, scale = 4 },
				{ id = "tree", x = 560, y = 33, bottom = 65, scale = 4 },
				{ id = "tree", x = -1, y = 47, bottom = 79, scale = 4 },
				{ id = "tree", x = 19, y = 55, bottom = 87, scale = 4 },
				{ id = "pine", x = 575, y = 49, bottom = 81, scale = 4 },
				{ id = "tree", x = 559, y = 56, bottom = 88, scale = 4 },
				{ id = "tree2", x = -2, y = 66, bottom = 98, scale = 4 },
				{ id = "pine", x = 22, y = 78, bottom = 110, scale = 4 },
				{ id = "tree2", x = 576, y = 67, bottom = 99, scale = 4 },
				{ id = "tree", x = 555, y = 77, bottom = 109, scale = 4 },
				{ id = "tree", x = -2, y = 90, bottom = 122, scale = 4 },
				{ id = "pine", x = 18, y = 96, bottom = 128, scale = 4 },
				{ id = "pine", x = 577, y = 86, bottom = 118, scale = 4 },
				{ id = "pine", x = 558, y = 99, bottom = 131, scale = 4 },
				{ id = "pine", x = 1, y = 107, bottom = 139, scale = 4 },
				{ id = "tree", x = 22, y = 117, bottom = 149, scale = 4 },
				{ id = "pine", x = 581, y = 111, bottom = 143, scale = 4 },
				{ id = "tree2", x = 557, y = 117, bottom = 149, scale = 4 },
				{ id = "pine", x = -2, y = 128, bottom = 160, scale = 4 },
				{ id = "pine", x = 18, y = 140, bottom = 172, scale = 4 },
				{ id = "tree", x = 580, y = 128, bottom = 160, scale = 4 },
				{ id = "tree", x = 556, y = 141, bottom = 173, scale = 4 },
				{ id = "tree2", x = -2, y = 150, bottom = 182, scale = 4 },
				{ id = "tree", x = 576, y = 153, bottom = 185, scale = 4 },
				{ id = "tree", x = 558, y = 158, bottom = 190, scale = 4 },
				{ id = "pine", x = 577, y = 169, bottom = 201, scale = 4 },
				{ id = "pine", x = 558, y = 182, bottom = 214, scale = 4 },
				{ id = "pine", x = 575, y = 190, bottom = 222, scale = 4 },
				{ id = "pine", x = 557, y = 201, bottom = 233, scale = 4 },
				{ id = "pine", x = 578, y = 213, bottom = 245, scale = 4 },
				{ id = "tree2", x = 559, y = 222, bottom = 254, scale = 4 },
				{ id = "tree2", x = 578, y = 235, bottom = 267, scale = 4 },
				{ id = "tree2", x = 560, y = 241, bottom = 273, scale = 4 },
				{ id = "pine", x = 21, y = 264, bottom = 296, scale = 4 },
				{ id = "pine", x = 579, y = 255, bottom = 287, scale = 4 },
				{ id = "pine", x = 556, y = 266, bottom = 298, scale = 4 },
				{ id = "pine", x = -1, y = 277, bottom = 309, scale = 4 },
				{ id = "tree", x = 20, y = 284, bottom = 316, scale = 4 },
				{ id = "pine", x = 576, y = 275, bottom = 307, scale = 4 },
				{ id = "pine", x = 557, y = 287, bottom = 319, scale = 4 },
				{ id = "tree2", x = -4, y = 297, bottom = 329, scale = 4 },
				{ id = "pine", x = 21, y = 308, bottom = 340, scale = 4 },
				{ id = "pine", x = 577, y = 294, bottom = 326, scale = 4 },
				{ id = "pine", x = 557, y = 307, bottom = 339, scale = 4 },
				{ id = "pine", x = -1, y = 316, bottom = 348, scale = 4 },
				{ id = "tree", x = 18, y = 327, bottom = 359, scale = 4 },
				{ id = "pine", x = 580, y = 317, bottom = 349, scale = 4 },
				{ id = "tree", x = 560, y = 328, bottom = 360, scale = 4 },
				{ id = "tree2", x = 0, y = 339, bottom = 371, scale = 4 },
				{ id = "pine", x = 20, y = 349, bottom = 381, scale = 4 },
				{ id = "pine", x = 577, y = 338, bottom = 370, scale = 4 },
				{ id = "pine", x = 558, y = 345, bottom = 377, scale = 4 },
				{ id = "tree2", x = -2, y = 358, bottom = 390, scale = 4 },
				{ id = "pine", x = 18, y = 369, bottom = 401, scale = 4 },
				{ id = "pine", x = 577, y = 359, bottom = 391, scale = 4 },
				{ id = "pine", x = 557, y = 369, bottom = 401, scale = 4 },
				{ id = "pine", x = -3, y = 378, bottom = 410, scale = 4 },
				{ id = "tree", x = 20, y = 389, bottom = 421, scale = 4 },
				{ id = "tree", x = 576, y = 377, bottom = 409, scale = 4 },
				{ id = "pine", x = 554, y = 390, bottom = 422, scale = 4 },
				{ id = "pine", x = 178, y = 247, bottom = 279, scale = 4 },
				{ id = "pine", x = 464, y = 221, bottom = 253, scale = 4 },
				{ id = "tree2", x = 458, y = 121, bottom = 153, scale = 4 },
				{ id = "pine", x = 453, y = 308, bottom = 340, scale = 4 },
				{ id = "pine", x = 106, y = 107, bottom = 139, scale = 4 },
				{ id = "pine", x = 297, y = 181, bottom = 213, scale = 4 },
				{ id = "pine", x = 345, y = 269, bottom = 301, scale = 4 },
				{ id = "pine", x = 249, y = 95, bottom = 127, scale = 4 },
				{ id = "tree2", x = 378, y = 128, bottom = 160, scale = 4 },
				{ id = "bigtree", x = 209, y = 153, bottom = 201, scale = 4 },
				{ id = "pine", x = 262, y = 306, bottom = 338, scale = 4 },
				{ id = "bush", x = 295, y = 85, bottom = 101, scale = 4 },
				{ id = "bush2", x = 132, y = 193, bottom = 209, scale = 4 },
				{ id = "bush2", x = 449, y = 359, bottom = 375, scale = 4 },
				{ id = "bush", x = 260, y = 203, bottom = 219, scale = 4 },
				{ id = "bush2", x = 172, y = 337, bottom = 353, scale = 4 },
				{ id = "bush", x = 404, y = 99, bottom = 115, scale = 4 },
				{ id = "bush2", x = 407, y = 356, bottom = 372, scale = 4 },
				{ id = "bush2", x = 226, y = 290, bottom = 306, scale = 4 },
				{ id = "bush2", x = 425, y = 231, bottom = 247, scale = 4 },
				{ id = "bush2", x = 271, y = 370, bottom = 386, scale = 4 },
				{ id = "bush", x = 511, y = 196, bottom = 212, scale = 4 },
				{ id = "bush", x = 353, y = 227, bottom = 243, scale = 4 },
				{ id = "bush2", x = 223, y = 324, bottom = 340, scale = 4 },
				{ id = "bush", x = 333, y = 131, bottom = 147, scale = 4 },
				{ id = "bush2", x = 63, y = 193, bottom = 209, scale = 4 },
				{ id = "bush2", x = 124, y = 305, bottom = 321, scale = 4 },
			},
			zones = {
				{ name = "북쪽 꽃밭(팔랑나비)", count = 9, x0 = 80, y0 = 64, x1 = 528, y1 = 192, species = {
					4,
				} },
				{ name = "남서 굴밭(도토리쥐)", count = 7, x0 = 80, y0 = 288, x1 = 288, y1 = 400, species = {
					5,
				} },
				{ name = "동쪽 굴밭", count = 7, x0 = 384, y0 = 224, x1 = 544, y1 = 400, species = {
					4,
					5,
				} },
			},
			portals = {
				{ name = "나비 언덕 2 가는 길", x0 = 0, y0 = 224, x1 = 16, y1 = 256, to = "hill2", arrive = "door" },
				{ name = "큰 웅덩이 가는 길", x0 = 320, y0 = 432, x1 = 352, y1 = 448, to = "pond", arrive = "door" },
			},
			mons = {},
			npcs = {},
		},
		pond = {
			name = "큰 웅덩이", w = 34, h = 26, indoor = false,
			outside = { 173, 188, 58 },
			ground = { w = 544, h = 416 },
			spawn = { x = 272, y = 42 },
			blocked = {
				"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"0000000111100000000000000000000001111000000000000000111100000000000000000000000000000000000000000000000000000000000000000011110000000000",
				"0111100111100001111011110011110001111000111100111100111100000000000000000000001111001111000111100111100111100001111011110011110001111000",
				"0111100111100001111011110011110001111000111100111100111100000000000000000000001111001111000111100111100111100001111011110011110001111000",
				"0111100000000001111011110011110000000000111100111100000000000000000000000000001111001111000111100111100111100001111011110000000001111000",
				"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"0000011110000000011110000000000111100000000000000000000011110000000000000000000000111100000000111100000000000000000000011110000111100000",
				"0000011110111100011110011110000111101111000011110111100011110000000000000000000000111101111000111100111100111100011110011110000111101111",
				"0000011110111100011110011110000111101111000011110111100011110000000000000000000000111101111000111100111100111100011110011110000111101111",
				"0000000000111100000000011110000000001111000000000111100000000000000000000000000000000001111000000000111100111100011110000000000000001111",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0111100111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111011110",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"0111101111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000000000000000000000000000001111000000",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000001110000000000000000000001111000000",
				"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001110000000000000000000001111111100",
				"0011110000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000001110000000000000000000000000111100",
				"0011110000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"0011111111000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0011111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000011110000000",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000011110111100",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000000000000000000000000000111100",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0111100111100000000000000111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000",
				"0000000111100000000000000111000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100000000",
				"0000000111100000000000000111000000011110000000000000000000000000000000000000000000000000000000000000000000000000000111100000111100000000",
				"0111100000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000111100000000000111100",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0111100111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110",
				"0011110000000000000000011110000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000000000011110",
				"0011111111000000000000011110000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000000000011110",
				"0011111111000000000000011110000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000001111000000",
				"0000001111000000000000000000000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000001111000000",
				"0011110000000000000000000000000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000001111111100",
				"0011110000000000000000000000000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000000000111100",
				"0011111111000000000000000000000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000000000111100",
				"0000001111000000000000000000000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000001111000000",
				"0000001111000000000000000000000000000000111111111111111111111111111111111111111111111111111111110000000000000000000000000000001111000000",
				"0011110000000000000000000000000000000000111111111111111111111111111111111111111111111111111111110000000000000000000000000000001111011110",
				"0011110000000000000000000000000000000000111111111111111111111111111111111111111111111111111111110000000000000000000000000000000000011110",
				"0011110000000000000000000000000000000000111111111111111111111111111111111111111111111111111111110000000000000000000000000000000000011110",
				"0000000111100000000000000000000000000000111111111111111111111111111111111111111111111111111111110000000000000000000000000000011110000000",
				"0000000111100000000000000000000000000000111111111111111111111111111111111111111111111111111111110000000000000000000000000000011110000000",
				"0000000111100000000000000000000000000000111111111111111111111111111111111111111111111111111111110000000000000000000000000000011110000000",
				"0111100000000000000000111100000000000000111111111111111111111111111111111111111111111111111111110000000000000000000000000000000000111100",
				"0111100000000000000000111100000000000000111111111111111111111111111111111111111111111111111111110000000000000000000000000000000000111100",
				"0111100111100000000000000000000000000000111111111111111111111111111111111111111111111111111111110000000000000000000000000000011110111100",
				"0000000111100000000000000000000000000000111111111111111111111111111111111111111111111111111111110000000000000000000000000000011110000000",
				"0000000111100000000000000000000000000000111111111111111111111111111111111111111111111111111111110000000000000000000000000000011110011110",
				"0011110000000000000000000000000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000000000011110",
				"0011110000000000000000000000000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000000000011110",
				"0011110000000000000000000000000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000001111000000",
				"0000000011110000000000000000000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000001111000000",
				"0000000011110000000000000000000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000001111000000",
				"0011110011110000000000000000000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000000000111100",
				"0011110000000000000000000000000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000000000111100",
				"0011110000000000000000000000000000000000000000001111111111111111111111111111111111111111000000000000000000000000000000000000000000111100",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000001111000000",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000001111000000",
				"0011110111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000001111111100",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110111100",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0011110111100000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"0011110000000000000000000011110000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000011110",
				"0011110000000000000000000000000000000000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000011110",
				"0000000111100000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000011110011110",
				"0000000111100000000000000000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011110000000",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0011111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000000000001111000000",
				"0000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000000000001111000000",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000011100000000000000000000000000000000000111100",
				"0111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000111100",
				"0111100111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111000000",
				"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
				"0000000000000000000000000000000000000000000000000000000000000011110000000000000001111000000000000000000000011110011110001111001111000000",
				"0000011110111100011110011110000111100111101111000011110011110011110001111001111001111001111000111100111100011110011110001111001111000111",
				"0000011110111100011110011110000111100111101111000011110011110011110001111001111001111001111000111100111100011110011110001111001111000111",
				"0000011110111100011110011110000111100111101111000011110011110000000001111001111000000001111000111100111100000000000000000000000000000111",
				"0000000111100000000011110000000000000000000000000000000000000000000000001111000000000000000000000111100011110011110000000000000000000000",
				"0111100111100011110011110011110000111100111100111100011110111100011110001111001111000111101111000111100011110011110011110001111001111000",
				"0111100111100011110011110011110000111100111100111100011110111100011110001111001111000111101111000111100011110011110011110001111001111000",
				"0111100000000011110000000011110000111100111100111100011110111100011110000000001111000111101111000000000000000000000011110001111001111000",
			},
			objects = {
				{ id = "tree2", x = -4, y = -4, bottom = 28, scale = 4 },
				{ id = "tree2", x = 11, y = 9, bottom = 41, scale = 4 },
				{ id = "pine", x = -5, y = 383, bottom = 415, scale = 4 },
				{ id = "tree2", x = 10, y = 367, bottom = 399, scale = 4 },
				{ id = "tree2", x = 19, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 33, y = 13, bottom = 45, scale = 4 },
				{ id = "pine", x = 21, y = 380, bottom = 412, scale = 4 },
				{ id = "tree2", x = 33, y = 365, bottom = 397, scale = 4 },
				{ id = "pine", x = 50, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 59, y = 11, bottom = 43, scale = 4 },
				{ id = "pine", x = 49, y = 382, bottom = 414, scale = 4 },
				{ id = "pine", x = 58, y = 366, bottom = 398, scale = 4 },
				{ id = "tree", x = 72, y = -5, bottom = 27, scale = 4 },
				{ id = "tree2", x = 85, y = 13, bottom = 45, scale = 4 },
				{ id = "tree", x = 71, y = 379, bottom = 411, scale = 4 },
				{ id = "tree", x = 84, y = 364, bottom = 396, scale = 4 },
				{ id = "tree2", x = 98, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 115, y = 11, bottom = 43, scale = 4 },
				{ id = "tree", x = 97, y = 383, bottom = 415, scale = 4 },
				{ id = "pine", x = 115, y = 366, bottom = 398, scale = 4 },
				{ id = "pine", x = 123, y = -8, bottom = 24, scale = 4 },
				{ id = "tree", x = 136, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 128, y = 380, bottom = 412, scale = 4 },
				{ id = "pine", x = 140, y = 367, bottom = 399, scale = 4 },
				{ id = "pine", x = 150, y = -8, bottom = 24, scale = 4 },
				{ id = "tree", x = 166, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 151, y = 382, bottom = 414, scale = 4 },
				{ id = "tree2", x = 161, y = 367, bottom = 399, scale = 4 },
				{ id = "tree2", x = 177, y = -4, bottom = 28, scale = 4 },
				{ id = "tree", x = 188, y = 13, bottom = 45, scale = 4 },
				{ id = "tree2", x = 175, y = 382, bottom = 414, scale = 4 },
				{ id = "pine", x = 191, y = 366, bottom = 398, scale = 4 },
				{ id = "pine", x = 201, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 214, y = 9, bottom = 41, scale = 4 },
				{ id = "tree", x = 203, y = 380, bottom = 412, scale = 4 },
				{ id = "pine", x = 215, y = 366, bottom = 398, scale = 4 },
				{ id = "pine", x = 225, y = 381, bottom = 413, scale = 4 },
				{ id = "pine", x = 239, y = 363, bottom = 395, scale = 4 },
				{ id = "tree2", x = 252, y = 381, bottom = 413, scale = 4 },
				{ id = "tree2", x = 267, y = 365, bottom = 397, scale = 4 },
				{ id = "tree2", x = 281, y = 379, bottom = 411, scale = 4 },
				{ id = "tree2", x = 293, y = 365, bottom = 397, scale = 4 },
				{ id = "tree2", x = 305, y = -8, bottom = 24, scale = 4 },
				{ id = "pine", x = 320, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 303, y = 383, bottom = 415, scale = 4 },
				{ id = "tree", x = 315, y = 363, bottom = 395, scale = 4 },
				{ id = "tree", x = 329, y = -7, bottom = 25, scale = 4 },
				{ id = "tree2", x = 341, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 331, y = 382, bottom = 414, scale = 4 },
				{ id = "tree2", x = 341, y = 364, bottom = 396, scale = 4 },
				{ id = "tree2", x = 358, y = -6, bottom = 26, scale = 4 },
				{ id = "pine", x = 368, y = 10, bottom = 42, scale = 4 },
				{ id = "pine", x = 353, y = 382, bottom = 414, scale = 4 },
				{ id = "pine", x = 366, y = 364, bottom = 396, scale = 4 },
				{ id = "pine", x = 379, y = -6, bottom = 26, scale = 4 },
				{ id = "pine", x = 394, y = 12, bottom = 44, scale = 4 },
				{ id = "tree2", x = 379, y = 380, bottom = 412, scale = 4 },
				{ id = "pine", x = 390, y = 367, bottom = 399, scale = 4 },
				{ id = "tree2", x = 406, y = -7, bottom = 25, scale = 4 },
				{ id = "tree2", x = 416, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 409, y = 379, bottom = 411, scale = 4 },
				{ id = "pine", x = 419, y = 364, bottom = 396, scale = 4 },
				{ id = "pine", x = 434, y = -5, bottom = 27, scale = 4 },
				{ id = "pine", x = 443, y = 12, bottom = 44, scale = 4 },
				{ id = "pine", x = 432, y = 380, bottom = 412, scale = 4 },
				{ id = "pine", x = 443, y = 363, bottom = 395, scale = 4 },
				{ id = "pine", x = 455, y = -6, bottom = 26, scale = 4 },
				{ id = "tree", x = 468, y = 11, bottom = 43, scale = 4 },
				{ id = "tree", x = 457, y = 382, bottom = 414, scale = 4 },
				{ id = "pine", x = 472, y = 364, bottom = 396, scale = 4 },
				{ id = "pine", x = 481, y = -8, bottom = 24, scale = 4 },
				{ id = "tree", x = 498, y = 11, bottom = 43, scale = 4 },
				{ id = "tree", x = 486, y = 383, bottom = 415, scale = 4 },
				{ id = "tree", x = 495, y = 363, bottom = 395, scale = 4 },
				{ id = "tree2", x = 508, y = -5, bottom = 27, scale = 4 },
				{ id = "tree", x = 521, y = 12, bottom = 44, scale = 4 },
				{ id = "tree", x = 508, y = 381, bottom = 413, scale = 4 },
				{ id = "pine", x = 525, y = 365, bottom = 397, scale = 4 },
				{ id = "pine", x = -2, y = 27, bottom = 59, scale = 4 },
				{ id = "pine", x = 18, y = 33, bottom = 65, scale = 4 },
				{ id = "tree2", x = 511, y = 25, bottom = 57, scale = 4 },
				{ id = "pine", x = 494, y = 37, bottom = 69, scale = 4 },
				{ id = "tree", x = -3, y = 46, bottom = 78, scale = 4 },
				{ id = "pine", x = 18, y = 54, bottom = 86, scale = 4 },
				{ id = "pine", x = 515, y = 47, bottom = 79, scale = 4 },
				{ id = "pine", x = 495, y = 57, bottom = 89, scale = 4 },
				{ id = "tree2", x = 2, y = 69, bottom = 101, scale = 4 },
				{ id = "tree", x = 17, y = 76, bottom = 108, scale = 4 },
				{ id = "pine", x = 512, y = 66, bottom = 98, scale = 4 },
				{ id = "tree2", x = 492, y = 75, bottom = 107, scale = 4 },
				{ id = "tree2", x = -1, y = 86, bottom = 118, scale = 4 },
				{ id = "tree", x = 17, y = 99, bottom = 131, scale = 4 },
				{ id = "pine", x = 515, y = 89, bottom = 121, scale = 4 },
				{ id = "pine", x = 494, y = 99, bottom = 131, scale = 4 },
				{ id = "pine", x = -2, y = 111, bottom = 143, scale = 4 },
				{ id = "tree", x = 20, y = 119, bottom = 151, scale = 4 },
				{ id = "pine", x = 511, y = 107, bottom = 139, scale = 4 },
				{ id = "pine", x = 490, y = 119, bottom = 151, scale = 4 },
				{ id = "tree2", x = -2, y = 130, bottom = 162, scale = 4 },
				{ id = "pine", x = 20, y = 137, bottom = 169, scale = 4 },
				{ id = "tree2", x = 514, y = 128, bottom = 160, scale = 4 },
				{ id = "pine", x = 495, y = 137, bottom = 169, scale = 4 },
				{ id = "tree2", x = 2, y = 152, bottom = 184, scale = 4 },
				{ id = "tree2", x = 17, y = 158, bottom = 190, scale = 4 },
				{ id = "pine", x = 516, y = 148, bottom = 180, scale = 4 },
				{ id = "pine", x = 494, y = 160, bottom = 192, scale = 4 },
				{ id = "pine", x = 1, y = 171, bottom = 203, scale = 4 },
				{ id = "tree2", x = 16, y = 179, bottom = 211, scale = 4 },
				{ id = "tree2", x = 513, y = 170, bottom = 202, scale = 4 },
				{ id = "pine", x = 494, y = 183, bottom = 215, scale = 4 },
				{ id = "pine", x = 0, y = 191, bottom = 223, scale = 4 },
				{ id = "pine", x = 20, y = 200, bottom = 232, scale = 4 },
				{ id = "tree", x = 515, y = 191, bottom = 223, scale = 4 },
				{ id = "pine", x = 491, y = 201, bottom = 233, scale = 4 },
				{ id = "tree2", x = -3, y = 214, bottom = 246, scale = 4 },
				{ id = "pine", x = 19, y = 223, bottom = 255, scale = 4 },
				{ id = "pine", x = 512, y = 215, bottom = 247, scale = 4 },
				{ id = "pine", x = 493, y = 222, bottom = 254, scale = 4 },
				{ id = "tree", x = 0, y = 234, bottom = 266, scale = 4 },
				{ id = "pine", x = 22, y = 244, bottom = 276, scale = 4 },
				{ id = "tree", x = 516, y = 231, bottom = 263, scale = 4 },
				{ id = "tree", x = 494, y = 244, bottom = 276, scale = 4 },
				{ id = "tree", x = 0, y = 252, bottom = 284, scale = 4 },
				{ id = "tree", x = 19, y = 266, bottom = 298, scale = 4 },
				{ id = "pine", x = 514, y = 253, bottom = 285, scale = 4 },
				{ id = "pine", x = 495, y = 264, bottom = 296, scale = 4 },
				{ id = "pine", x = -1, y = 275, bottom = 307, scale = 4 },
				{ id = "tree", x = 19, y = 284, bottom = 316, scale = 4 },
				{ id = "tree", x = 512, y = 276, bottom = 308, scale = 4 },
				{ id = "tree2", x = 493, y = 284, bottom = 316, scale = 4 },
				{ id = "pine", x = 0, y = 295, bottom = 327, scale = 4 },
				{ id = "pine", x = 21, y = 305, bottom = 337, scale = 4 },
				{ id = "tree2", x = 515, y = 298, bottom = 330, scale = 4 },
				{ id = "tree2", x = 490, y = 305, bottom = 337, scale = 4 },
				{ id = "tree", x = 2, y = 317, bottom = 349, scale = 4 },
				{ id = "tree2", x = 18, y = 326, bottom = 358, scale = 4 },
				{ id = "tree", x = 513, y = 319, bottom = 351, scale = 4 },
				{ id = "pine", x = 496, y = 324, bottom = 356, scale = 4 },
				{ id = "tree2", x = -5, y = 339, bottom = 371, scale = 4 },
				{ id = "tree2", x = 18, y = 348, bottom = 380, scale = 4 },
				{ id = "tree", x = 511, y = 339, bottom = 371, scale = 4 },
				{ id = "tree", x = 496, y = 345, bottom = 377, scale = 4 },
				{ id = "bush", x = 207, y = 318, bottom = 334, scale = 4 },
				{ id = "bush", x = 92, y = 169, bottom = 185, scale = 4 },
				{ id = "bush", x = 88, y = 227, bottom = 243, scale = 4 },
				{ id = "bush", x = 460, y = 138, bottom = 154, scale = 4 },
				{ id = "bush", x = 405, y = 77, bottom = 93, scale = 4 },
				{ id = "bush2", x = 451, y = 280, bottom = 296, scale = 4 },
				{ id = "bush", x = 104, y = 308, bottom = 324, scale = 4 },
				{ id = "bush2", x = 97, y = 133, bottom = 149, scale = 4 },
				{ id = "bush2", x = 318, y = 118, bottom = 134, scale = 4 },
				{ id = "bush", x = 366, y = 346, bottom = 362, scale = 4 },
				{ id = "bush2", x = 340, y = 70, bottom = 86, scale = 4 },
				{ id = "bush", x = 285, y = 311, bottom = 327, scale = 4 },
				{ id = "bush", x = 140, y = 137, bottom = 153, scale = 4 },
				{ id = "bush2", x = 136, y = 84, bottom = 100, scale = 4 },
			},
			zones = {
				{ name = "서쪽 물가", count = 6, x0 = 64, y0 = 80, x1 = 160, y1 = 352, species = {
					5,
				} },
				{ name = "동쪽 물가", count = 6, x0 = 400, y0 = 80, x1 = 496, y1 = 352, species = {
					5,
				} },
				{ name = "남쪽 물가", count = 5, x0 = 144, y0 = 304, x1 = 416, y1 = 368, species = {
					5,
				} },
			},
			portals = {
				{ name = "나비 언덕 3 가는 길", x0 = 256, y0 = 0, x1 = 288, y1 = 16, to = "hill3", arrive = "door" },
			},
			mons = {},
			npcs = {},
		},
	},
}

end
MODULES['ReplicatedStorage/shared/data/townWorld'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 공방에서 만든 탑다운 씬들(townWorld.generated) 공용 도우미 — 클라이언트·서버가 같이 쓴다.
-- 로블록스 씬 이름 = "town_" .. 씬 키. 모듈 폴더는 전부 client/modules/town 하나를 같이 쓴다.
local world = require(script.Parent["townWorld.generated"])

local PREFIX = "town_"

local exports = {}
exports.data = world

-- 몬스터 종 번호(1부터)와 프레임 번호(0부터)를 공방 아틀라스 좌표로 변환한다.
-- 이전 시트는 speciesPerRow가 없어 한 줄에 한 종이며, 새 시트는 두 종씩 배치한다.
-- 「오문 닌자전」 시트(sheet.block이 있음): 종마다 block x block 덩어리, 덩어리 안 = 열(방향: 아래 0 · 위 1 · 왼 2 · 오 3) × 줄(걷기 장).
--  frame = 방향 * 4 + 걷기 장(0~3). 방향을 모르면 0(아래 보기 첫 장).
function exports.MonsterFrameOffset(row: number, frame: number): Vector2
	local sheet = world.monsterSheet
	if sheet.block then
		local index = row - 1
		local dir, step = (frame // 4) % 4, frame % 4
		return Vector2.new(
			(index % sheet.perRow) * sheet.block + dir * sheet.cellW,
			(index // sheet.perRow) * sheet.block + step * sheet.cellH
		)
	end
	local perRow = sheet.speciesPerRow or 1
	local index = (row - 1) % (sheet.perSheet or math.huge)
	return Vector2.new(
		((index % perRow) * sheet.cols + frame) * sheet.cellW,
		math.floor(index / perRow) * sheet.cellH
	)
end

-- 몬스터 종 번호가 들어 있는 시트 번호(1부터) — 종이 많아 시트가 여러 장이면 townAssets.MONSTER_SHEETS[이 번호]
function exports.MonsterSheet(row: number): number
	local per = world.monsterSheet.perSheet
	return if per then (row - 1) // per + 1 else 1
end

function exports.SceneName(key: string): string
	return PREFIX .. key
end

-- 로블록스 씬 이름 → 씬 키(탑다운 씬이 아니면 nil)
function exports.KeyOf(sceneName: string?): string?
	if typeof(sceneName) ~= "string" or sceneName:sub(1, #PREFIX) ~= PREFIX then
		return nil
	end
	local key = sceneName:sub(#PREFIX + 1)
	return if world.scenes[key] then key else nil
end

function exports.Get(key: string)
	return world.scenes[key]
end

-- 충돌 판정(클라이언트 town/map.luau와 서버 몬스터·드랍이 같은 규칙을 쓴다). 좌표는 도트.
function exports.IsBlocked(d, x: number, y: number): boolean
	local T, FINE = world.tile, world.fine
	if x < 0 or y < 0 or x >= d.w * T or y >= d.h * T then
		return true
	end
	local row = d.blocked[math.floor(y / FINE) + 1]
	local col = math.floor(x / FINE) + 1
	return row == nil or row:sub(col, col) == "1"
end

-- 발 상자(가운데 아래 기준, 폭 2*halfW, 높이 h)가 막힌 곳에 걸리는가
function exports.BoxBlocked(d, x: number, y: number, halfW: number, h: number): boolean
	return exports.IsBlocked(d, x - halfW, y - h)
		or exports.IsBlocked(d, x + halfW, y - h)
		or exports.IsBlocked(d, x - halfW, y - 0.01)
		or exports.IsBlocked(d, x + halfW, y - 0.01)
end

function exports.StartSceneName(): string
	return PREFIX .. world.start
end

return exports

end
MODULES['ReplicatedStorage/shared/data/uiKit.generated'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 자동 생성 파일 — 직접 고치지 말 것(dino-workshop/tools/export_ninja_ui.mjs).
-- 「오문 닌자전」 UI 키트: Ninja Adventure 팩 UI(나무 테마 · 대화 상자 · 스킬 아이콘 · 키 그림 · 얼굴 그림)로 만든 부품 아틀라스
-- (assets/ninja/ui.png, 에셋 id = townAssets.generated의 UI). slice = 9분할 여백 { 왼, 위, 오른, 아래 }.
return {
	colors = { ink = { 20, 27, 27 }, white = { 255, 255, 255 }, paper = { 242, 234, 241 }, accent = { 240, 103, 51 }, accentD = { 150, 83, 64 }, accentL = { 255, 173, 85 }, good = { 173, 188, 58 }, goodD = { 106, 121, 51 }, red = { 224, 57, 76 }, sky = { 95, 205, 228 }, yellow = { 255, 173, 85 }, gray = { 141, 151, 127 }, grayD = { 86, 99, 77 }, barBg = { 70, 64, 46 } },
	rects = {
		panel = { x = 50, y = 282, w = 22, h = 22, slice = { 10, 10, 10, 10 } },
		tag = { x = 379, y = 282, w = 12, h = 12, slice = { 3, 3, 3, 4 } },
		tab_on = { x = 392, y = 282, w = 16, h = 12, slice = { 5, 5, 6, 1 } },
		tab_off = { x = 409, y = 282, w = 16, h = 12, slice = { 5, 5, 6, 1 } },
		button_primary = { x = 474, y = 282, w = 16, h = 8, slice = { 3, 2, 3, 3 } },
		button_primary_pressed = { x = 491, y = 282, w = 16, h = 8, slice = { 3, 2, 3, 3 } },
		button_plain = { x = 0, y = 307, w = 16, h = 8, slice = { 3, 2, 3, 3 } },
		button_plain_pressed = { x = 17, y = 307, w = 16, h = 8, slice = { 3, 2, 3, 3 } },
		button_disabled = { x = 34, y = 307, w = 16, h = 8, slice = { 3, 2, 3, 3 } },
		pill = { x = 51, y = 307, w = 16, h = 8, slice = { 3, 2, 3, 3 } },
		pill_dark = { x = 73, y = 282, w = 16, h = 16, slice = { 4, 4, 4, 4 } },
		slot = { x = 90, y = 282, w = 16, h = 16, slice = { 3, 3, 3, 3 } },
		slot_selected = { x = 107, y = 282, w = 16, h = 16, slice = { 3, 3, 3, 3 } },
		bar_frame = { x = 124, y = 282, w = 16, h = 16, slice = { 4, 4, 4, 4 } },
		bar_fill_red = { x = 68, y = 307, w = 2, h = 7 },
		bar_fill_yellow = { x = 71, y = 307, w = 2, h = 7 },
		bar_fill_sky = { x = 74, y = 307, w = 2, h = 7 },
		bar_fill_mint = { x = 77, y = 307, w = 2, h = 7 },
		bubble = { x = 141, y = 282, w = 20, h = 16 },
		dialog = { x = 0, y = 0, w = 300, h = 58 },
		dialog_face = { x = 0, y = 59, w = 300, h = 58 },
		icon_heart = { x = 426, y = 282, w = 14, h = 12 },
		icon_coin = { x = 441, y = 282, w = 10, h = 10 },
		icon_bag = { x = 162, y = 282, w = 16, h = 16 },
		icon_book = { x = 179, y = 282, w = 16, h = 16 },
		icon_gear = { x = 196, y = 282, w = 11, h = 13 },
		icon_energy = { x = 452, y = 282, w = 11, h = 10 },
		icon_close = { x = 464, y = 282, w = 9, h = 9 },
		act_attack = { x = 351, y = 118, w = 24, h = 24 },
		act_talk = { x = 376, y = 118, w = 24, h = 24 },
		act_dash = { x = 401, y = 118, w = 24, h = 24 },
		act_skill = { x = 426, y = 118, w = 24, h = 24 },
		key_q = { x = 208, y = 282, w = 13, h = 13 },
		key_r = { x = 222, y = 282, w = 13, h = 13 },
		key_t = { x = 236, y = 282, w = 13, h = 13 },
		key_g = { x = 250, y = 282, w = 13, h = 13 },
		key_1 = { x = 264, y = 282, w = 13, h = 13 },
		key_2 = { x = 278, y = 282, w = 13, h = 13 },
		key_3 = { x = 292, y = 282, w = 13, h = 13 },
		key_e = { x = 306, y = 282, w = 13, h = 13 },
		key_f = { x = 320, y = 282, w = 13, h = 13 },
		key_shift = { x = 334, y = 282, w = 30, h = 13 },
		key_k = { x = 365, y = 282, w = 13, h = 13 },
		skill_fire_ball = { x = 451, y = 118, w = 24, h = 24 },
		skill_fire_ball_off = { x = 476, y = 118, w = 24, h = 24 },
		skill_ice_spike = { x = 0, y = 157, w = 24, h = 24 },
		skill_ice_spike_off = { x = 25, y = 157, w = 24, h = 24 },
		skill_plant_bind = { x = 50, y = 157, w = 24, h = 24 },
		skill_plant_bind_off = { x = 75, y = 157, w = 24, h = 24 },
		skill_plant_heal = { x = 100, y = 157, w = 24, h = 24 },
		skill_plant_heal_off = { x = 125, y = 157, w = 24, h = 24 },
		skill_rock_spike = { x = 150, y = 157, w = 24, h = 24 },
		skill_rock_spike_off = { x = 175, y = 157, w = 24, h = 24 },
		skill_rock_guard = { x = 200, y = 157, w = 24, h = 24 },
		skill_rock_guard_off = { x = 225, y = 157, w = 24, h = 24 },
		skill_thunder_bolt = { x = 250, y = 157, w = 24, h = 24 },
		skill_thunder_bolt_off = { x = 275, y = 157, w = 24, h = 24 },
		skill_thunder_storm = { x = 300, y = 157, w = 24, h = 24 },
		skill_thunder_storm_off = { x = 325, y = 157, w = 24, h = 24 },
		skill_f_ember = { x = 350, y = 157, w = 24, h = 24 },
		skill_f_ember_off = { x = 375, y = 157, w = 24, h = 24 },
		skill_f_blade = { x = 400, y = 157, w = 24, h = 24 },
		skill_f_blade_off = { x = 425, y = 157, w = 24, h = 24 },
		skill_i_frost = { x = 450, y = 157, w = 24, h = 24 },
		skill_i_frost_off = { x = 475, y = 157, w = 24, h = 24 },
		skill_i_armor = { x = 0, y = 182, w = 24, h = 24 },
		skill_i_armor_off = { x = 25, y = 182, w = 24, h = 24 },
		skill_p_seed = { x = 50, y = 182, w = 24, h = 24 },
		skill_p_seed_off = { x = 75, y = 182, w = 24, h = 24 },
		skill_p_vigor = { x = 100, y = 182, w = 24, h = 24 },
		skill_p_vigor_off = { x = 125, y = 182, w = 24, h = 24 },
		skill_r_firm = { x = 150, y = 182, w = 24, h = 24 },
		skill_r_firm_off = { x = 175, y = 182, w = 24, h = 24 },
		skill_t_charge = { x = 200, y = 182, w = 24, h = 24 },
		skill_t_charge_off = { x = 225, y = 182, w = 24, h = 24 },
		skill_t_static = { x = 250, y = 182, w = 24, h = 24 },
		skill_t_static_off = { x = 275, y = 182, w = 24, h = 24 },
		skill_c_mastery = { x = 300, y = 182, w = 24, h = 24 },
		skill_c_mastery_off = { x = 325, y = 182, w = 24, h = 24 },
		skill_c_energy = { x = 350, y = 182, w = 24, h = 24 },
		skill_c_energy_off = { x = 375, y = 182, w = 24, h = 24 },
		skill_f_breath = { x = 400, y = 182, w = 24, h = 24 },
		skill_f_breath_off = { x = 425, y = 182, w = 24, h = 24 },
		skill_f_ignite = { x = 450, y = 182, w = 24, h = 24 },
		skill_f_ignite_off = { x = 475, y = 182, w = 24, h = 24 },
		skill_f_pillar = { x = 0, y = 207, w = 24, h = 24 },
		skill_f_pillar_off = { x = 25, y = 207, w = 24, h = 24 },
		skill_f_heat = { x = 50, y = 207, w = 24, h = 24 },
		skill_f_heat_off = { x = 75, y = 207, w = 24, h = 24 },
		skill_f_drain = { x = 100, y = 207, w = 24, h = 24 },
		skill_f_drain_off = { x = 125, y = 207, w = 24, h = 24 },
		skill_i_shatter = { x = 150, y = 207, w = 24, h = 24 },
		skill_i_shatter_off = { x = 175, y = 207, w = 24, h = 24 },
		skill_i_wall = { x = 200, y = 207, w = 24, h = 24 },
		skill_i_wall_off = { x = 225, y = 207, w = 24, h = 24 },
		skill_i_decoy = { x = 250, y = 207, w = 24, h = 24 },
		skill_i_decoy_off = { x = 275, y = 207, w = 24, h = 24 },
		skill_i_cold = { x = 300, y = 207, w = 24, h = 24 },
		skill_i_cold_off = { x = 325, y = 207, w = 24, h = 24 },
		skill_p_whip = { x = 350, y = 207, w = 24, h = 24 },
		skill_p_whip_off = { x = 375, y = 207, w = 24, h = 24 },
		skill_p_flower = { x = 400, y = 207, w = 24, h = 24 },
		skill_p_flower_off = { x = 425, y = 207, w = 24, h = 24 },
		skill_p_root = { x = 450, y = 207, w = 24, h = 24 },
		skill_p_root_off = { x = 475, y = 207, w = 24, h = 24 },
		skill_p_breath = { x = 0, y = 232, w = 24, h = 24 },
		skill_p_breath_off = { x = 25, y = 232, w = 24, h = 24 },
		skill_r_crack = { x = 50, y = 232, w = 24, h = 24 },
		skill_r_crack_off = { x = 75, y = 232, w = 24, h = 24 },
		skill_r_counter = { x = 100, y = 232, w = 24, h = 24 },
		skill_r_counter_off = { x = 125, y = 232, w = 24, h = 24 },
		skill_r_throw = { x = 150, y = 232, w = 24, h = 24 },
		skill_r_throw_off = { x = 175, y = 232, w = 24, h = 24 },
		skill_r_stomp = { x = 200, y = 232, w = 24, h = 24 },
		skill_r_stomp_off = { x = 225, y = 232, w = 24, h = 24 },
		skill_r_heavy = { x = 250, y = 232, w = 24, h = 24 },
		skill_r_heavy_off = { x = 275, y = 232, w = 24, h = 24 },
		skill_t_star = { x = 300, y = 232, w = 24, h = 24 },
		skill_t_star_off = { x = 325, y = 232, w = 24, h = 24 },
		skill_t_discharge = { x = 350, y = 232, w = 24, h = 24 },
		skill_t_discharge_off = { x = 375, y = 232, w = 24, h = 24 },
		skill_t_trap = { x = 400, y = 232, w = 24, h = 24 },
		skill_t_trap_off = { x = 425, y = 232, w = 24, h = 24 },
		skill_t_haste = { x = 450, y = 232, w = 24, h = 24 },
		skill_t_haste_off = { x = 475, y = 232, w = 24, h = 24 },
		skill_t_shock = { x = 0, y = 257, w = 24, h = 24 },
		skill_t_shock_off = { x = 25, y = 257, w = 24, h = 24 },
		skill_fire_rain = { x = 50, y = 257, w = 24, h = 24 },
		skill_fire_rain_off = { x = 75, y = 257, w = 24, h = 24 },
		skill_fire_dragon = { x = 100, y = 257, w = 24, h = 24 },
		skill_fire_dragon_off = { x = 125, y = 257, w = 24, h = 24 },
		skill_ice_lance = { x = 150, y = 257, w = 24, h = 24 },
		skill_ice_lance_off = { x = 175, y = 257, w = 24, h = 24 },
		skill_ice_storm = { x = 200, y = 257, w = 24, h = 24 },
		skill_ice_storm_off = { x = 225, y = 257, w = 24, h = 24 },
		skill_plant_thorn = { x = 250, y = 257, w = 24, h = 24 },
		skill_plant_thorn_off = { x = 275, y = 257, w = 24, h = 24 },
		skill_plant_bloom = { x = 300, y = 257, w = 24, h = 24 },
		skill_plant_bloom_off = { x = 325, y = 257, w = 24, h = 24 },
		skill_rock_quake = { x = 350, y = 257, w = 24, h = 24 },
		skill_rock_quake_off = { x = 375, y = 257, w = 24, h = 24 },
		skill_rock_meteor = { x = 400, y = 257, w = 24, h = 24 },
		skill_rock_meteor_off = { x = 425, y = 257, w = 24, h = 24 },
		skill_thunder_chain = { x = 450, y = 257, w = 24, h = 24 },
		skill_thunder_chain_off = { x = 475, y = 257, w = 24, h = 24 },
		skill_thunder_judge = { x = 0, y = 282, w = 24, h = 24 },
		skill_thunder_judge_off = { x = 25, y = 282, w = 24, h = 24 },
		face_elder = { x = 301, y = 59, w = 38, h = 38 },
		face_blacksmith = { x = 340, y = 59, w = 38, h = 38 },
		face_merchant = { x = 379, y = 59, w = 38, h = 38 },
		face_potion = { x = 418, y = 59, w = 38, h = 38 },
		face_healer = { x = 457, y = 59, w = 38, h = 38 },
		face_storage = { x = 0, y = 118, w = 38, h = 38 },
		face_villagerMan = { x = 39, y = 118, w = 38, h = 38 },
		face_villagerOld = { x = 78, y = 118, w = 38, h = 38 },
		face_noble = { x = 117, y = 118, w = 38, h = 38 },
		face_school_fire = { x = 156, y = 118, w = 38, h = 38 },
		face_school_ice = { x = 195, y = 118, w = 38, h = 38 },
		face_school_plant = { x = 234, y = 118, w = 38, h = 38 },
		face_school_rock = { x = 273, y = 118, w = 38, h = 38 },
		face_school_thunder = { x = 312, y = 118, w = 38, h = 38 },
	},
}

end
MODULES['ReplicatedStorage/shared/net/net'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 네트워크 계층. 모든 RemoteEvent/RemoteFunction은 shared/net/packets.luau의 정의로만 만들고 쓴다 — 모듈마다
-- 리모트를 제각각 만들고 이름 문자열로 찾던 구조를 대체한다.
--   서버: Net.OnServer(이름, 핸들러) — 인자 개수/타입과 요청 빈도를 검사해서 통과한 요청만 핸들러로 보낸다.
--         Net.FireClient / Net.FireAllClients
--   클라: Net.FireServer / Net.Invoke / Net.OnClient
-- 검증에 실패하거나 빈도를 넘긴 요청은 조용히 버리고(서버 로그에는 플레이어·패킷별로 몇 초에 한 번만 경고) 핸들러는
-- 호출하지 않는다. 이동 위치를 매번 거절하는 것은 엔진 공식 문서가 비권장하지만(오탐/지연), 이 계층은 "중요 행동
-- 요청이 형식에 맞는지, 폭주하지 않는지"만 본다 — 위치/내용의 타당성 검증은 각 서비스가 맡는다.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local packets = require(script.Parent.packets)

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Remotes"

local Net = {}

local folder: Folder
if IS_SERVER then
	folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) or Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	for name, def in packets do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(if def.Kind == "Function" then "RemoteFunction" else "RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

local function getRemote(name: string)
	assert(packets[name], ("Net: 정의되지 않은 패킷 '%s' (shared/net/packets.luau에 먼저 추가)"):format(name))
	if IS_SERVER then
		return folder:FindFirstChild(name)
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME):WaitForChild(name)
end

-- ===== 서버 =====

-- 플레이어별 패킷별 토큰 버킷: buckets[userId][name] = { tokens, last }
local buckets: { [number]: { [string]: { tokens: number, last: number } } } = {}
local lastWarn: { [string]: number } = {}

local function warnThrottled(key: string, message: string)
	local now = os.clock()
	if not lastWarn[key] or now - lastWarn[key] > 5 then
		lastWarn[key] = now
		warn(message)
	end
end

local function takeToken(player: Player, name: string, limit): boolean
	local perPlayer = buckets[player.UserId]
	if not perPlayer then
		perPlayer = {}
		buckets[player.UserId] = perPlayer
	end
	local now = os.clock()
	local bucket = perPlayer[name]
	if not bucket then
		bucket = { tokens = limit.Burst, last = now }
		perPlayer[name] = bucket
	end
	bucket.tokens = math.min(limit.Burst, bucket.tokens + (now - bucket.last) * limit.PerSecond)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function validArgs(def, ...): boolean
	if select("#", ...) > #def.Args then
		return false -- 정의보다 인자가 많으면 형식 위반
	end
	for i, check in def.Args do
		if not check((select(i, ...))) then
			return false
		end
	end
	return true
end

-- ClientToServer 패킷 핸들러 등록. Function 패킷이면 핸들러의 반환값이 클라이언트에 돌아간다.
function Net.OnServer(name: string, handler: (player: Player, ...any) -> ...any)
	assert(IS_SERVER, "Net.OnServer는 서버에서만 쓴다")
	local def = packets[name]
	assert(def and def.Direction == "ClientToServer", ("Net.OnServer: '%s'는 ClientToServer 패킷이 아니다"):format(name))
	local remote = getRemote(name)

	local function guarded(player: Player, ...)
		if not takeToken(player, name, def.RateLimit) then
			warnThrottled(player.UserId .. name .. "rate", ("Net: %s의 '%s' 요청이 빈도 제한을 넘어 버려졌다"):format(player.Name, name))
			return false
		end
		if not validArgs(def, ...) then
			warnThrottled(player.UserId .. name .. "arg", ("Net: %s의 '%s' 요청 인자가 형식에 맞지 않아 버려졌다"):format(player.Name, name))
			return false
		end
		return true
	end

	if def.Kind == "Function" then
		remote.OnServerInvoke = function(player: Player, ...)
			if not guarded(player, ...) then
				return nil
			end
			return handler(player, ...)
		end
	else
		remote.OnServerEvent:Connect(function(player: Player, ...)
			if guarded(player, ...) then
				handler(player, ...)
			end
		end)
	end
end

function Net.FireClient(name: string, player: Player, ...: any)
	assert(IS_SERVER)
	getRemote(name):FireClient(player, ...)
end

function Net.FireAllClients(name: string, ...: any)
	assert(IS_SERVER)
	getRemote(name):FireAllClients(...)
end

if IS_SERVER then
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		buckets[player.UserId] = nil
	end)
end

-- ===== 클라이언트 =====

function Net.FireServer(name: string, ...: any)
	assert(not IS_SERVER)
	getRemote(name):FireServer(...)
end

function Net.Invoke(name: string, ...: any): any
	assert(not IS_SERVER)
	return getRemote(name):InvokeServer(...)
end

function Net.OnClient(name: string, handler: (...any) -> ()): RBXScriptConnection
	assert(not IS_SERVER)
	return getRemote(name).OnClientEvent:Connect(handler)
end

return Net

end
MODULES['ReplicatedStorage/shared/net/packets'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 네트워크 패킷(RemoteEvent/RemoteFunction) 정의의 "단 하나의 출처". 공식 멀티플레이 데모(shared/packets.luau,
-- Remo + t 라이브러리)와 같은 개념 — 리모트 이름/방향/인자 타입/요청 빈도 제한을 여기에만 적는다. 서버는 이 정의로
-- 리모트를 만들고, 클라이언트→서버 패킷은 net.luau가 인자 타입과 빈도를 자동으로 검사한 뒤에야 핸들러를 부른다.
--
-- Direction: "ClientToServer"(클라가 서버에 요청/보고) / "ServerToClient"(서버가 클라에 통지).
-- Kind: "Event"(RemoteEvent) / "Function"(RemoteFunction, 서버 핸들러가 값을 돌려줌).
-- Args: ClientToServer 패킷만 사용 — 위치 인자 검증 함수 목록(개수도 정확히 맞아야 통과).
-- RateLimit: ClientToServer 패킷만 사용 — 플레이어별 토큰 버킷(PerSecond: 초당 보충량, Burst: 최대 적립량).
-- ServerToClient의 Doc은 인자 설명용(검증하지 않음).
local scenes = require(script.Parent.Parent.config.scenes)

local t = {}

-- 유한한 숫자만(NaN/무한대는 좌표 조작에 쓰일 수 있어 거른다).
function t.number(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function t.string(value: any): boolean
	return typeof(value) == "string" and #value <= 64
end

function t.oneOf(...: string)
	local allowed = {}
	for _, value in { ... } do
		allowed[value] = true
	end
	return function(value: any): boolean
		return typeof(value) == "string" and allowed[value] == true
	end
end

function t.optional(check)
	return function(value: any): boolean
		return value == nil or check(value)
	end
end

function t.either(a, b)
	return function(value: any): boolean
		return a(value) or b(value)
	end
end

local packets = {
	-- ===== 클라이언트 -> 서버 =====
	-- 위치와 씬은 클라이언트가 보고하지 않는다 — 서버가 캐릭터 복제 요청(ReplicationRequest)의 내용에서 직접 읽는다.
	-- 씬 이동은 서버가 승인한다: 클라이언트는 "이 씬으로 가고 싶다"고 요청만 하고, 서버가 지금 씬/포탈 위치를 검증해서
	-- TravelApproved로 승인해야 실제로 이동한다. 플레이어가 어느 씬에 있는지의 진실은 서버가 갖는다.
	RequestTravel = {
		Kind = "Event",
		Direction = "ClientToServer",
		-- 목적지 씬 이름. 탑다운 씬이 여러 개라 이름 목록을 고정하지 않고, 실제로 갈 수 있는지는 서버 travelService가 포탈 위치로 검증한다.
		Args = { t.string },
		RateLimit = { PerSecond = 2, Burst = 3 },
	},
	EquipAction = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("Equip", "Unequip"), t.either(t.number, t.string) }, -- 동작, 인벤토리 슬롯 번호 또는 장비 슬롯 이름
		RateLimit = { PerSecond = 5, Burst = 5 },
	},
	-- ===== 탑다운 씬(온라인 공유) =====
	-- 지금 씬의 몬스터·월드 드랍 전체 목록(씬에 들어왔을 때 한 번). 돌려주는 값: { scene, monsters, drops }
	GetTownState = {
		Kind = "Function",
		Direction = "ClientToServer",
		Args = {},
		RateLimit = { PerSecond = 2, Burst = 4 },
	},
	-- 기본 공격: 바라보는 방향만 보낸다(공격 동작의 판정 프레임에). 위치는 서버가 아는 위치, 간격도 서버가 검증한다.
	-- 펫(M3): 상자 번호에 대한 행동 — Add(함께 다니기) · Remove(상자로) · Lead(대표로 = 파티 1번) · Release(놓아주기, 사라짐)
	PetAction = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("Add", "Remove", "Lead", "Release"), t.number },
		RateLimit = { PerSecond = 6, Burst = 6 },
	},
	-- 소비 단축칸에 아이템 놓기(칸 번호 1~3, 아이템 id 또는 ""=비우기) — 서버가 소비 아이템인지 검사
	SetQuickSlot = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.number, t.string },
		RateLimit = { PerSecond = 6, Burst = 6 },
	},
	-- 소비 단축칸 쓰기(칸 번호, 바라보는 방향) — 물약: 회복 / 방울: 그 방향으로 던지기(포획 시도)
	UseQuickSlot = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.number, t.oneOf("up", "down", "left", "right") },
		RateLimit = { PerSecond = 6, Burst = 6 },
	},
	TownAttack = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("up", "down", "left", "right") },
		RateLimit = { PerSecond = 6, Burst = 6 },
	},
	-- 무기 강화(대장간 NPC 곁에서): 칸 0 = 착용한 무기, 1 이상 = 가방 장비 탭의 그 칸. 재료 · 엽전 · 확률은 서버가 처리한다.
	UpgradeWeapon = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.number },
		RateLimit = { PerSecond = 3, Burst = 4 },
	},
	-- 유파 고르기 = 1차 전직(Lv.10, 스승 곁) / 이미 유파가 있으면 유파 바꾸기(엽전). 조건은 서버가 확인한다.
	ChooseSchool = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("fire", "ice", "plant", "rock", "thunder") },
		RateLimit = { PerSecond = 1, Burst = 3 },
	},
	-- 2 · 3 · 4차 전직(스승 곁, 전직 레벨이 됐을 때)
	JobAdvance = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = {},
		RateLimit = { PerSecond = 1, Burst = 2 },
	},
	-- 스킬 배우기 · 올리기(스킬 id — 그 전직의 SP 1) / 단축칸에 넣기(칸, 스킬 id · "" = 비움). 조건은 서버가 확인한다(ninjutsuService).
	LearnSkill = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.string },
		RateLimit = { PerSecond = 8, Burst = 12 },
	},
	SetSkillSlot = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.number, t.string },
		RateLimit = { PerSecond = 4, Burst = 8 },
	},
	-- 대쉬(이동기 — 견습 구르기 / 유파의 대쉬, shared/config/ninjutsu.luau DASH): 바라보는 방향. 쿨타임 · 기력은 서버가 확인하고
	--  같은 씬에 연출을 알린다(순수 이동기 — 피해 · 상태 이상 없음). 움직임 자체는 클라이언트가 한다(위치 복제). 연출은 NinjutsuCast("dash_<id>")로 같은 씬에 알린다.
	UseDash = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("up", "down", "left", "right") },
		RateLimit = { PerSecond = 3, Burst = 4 },
	},
	-- 본 줄거리 퀘스트: NPC(키)에게 말을 걸어 받거나 끝낸다 — 곁에 있는지 · 레벨 · 목표는 서버가 확인한다(questService).
	QuestTalk = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.string },
		RateLimit = { PerSecond = 2, Burst = 4 },
	},
	-- 인술 쓰기(칸 1~4 = n차 전직 인술, 바라보는 방향) — 전직 단계 · 쿨타임 · 기력은 서버가 확인한다.
	UseNinjutsu = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.number, t.oneOf("up", "down", "left", "right") },
		RateLimit = { PerSecond = 6, Burst = 6 },
	},
	-- 가방: 같은 탭 안에서 칸 옮기기(드래그 앤 드롭) — 탭, 보낸 칸, 받는 칸. 받는 칸에 아이템이 있으면 서로 바꾸고, 같은 아이템이면 합친다.
	MoveItem = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("Equip", "Use", "Etc", "Cash", "Key"), t.number, t.number },
		RateLimit = { PerSecond = 8, Burst = 10 },
	},
	-- 가방: 버리기(탭, 칸) → 서버가 가방에서 빼고 발밑에 월드 드랍으로 떨어뜨린다.
	DropItem = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("Equip", "Use", "Etc", "Cash", "Key"), t.number },
		RateLimit = { PerSecond = 3, Burst = 5 },
	},
	-- 가게(NPC 근처에서만 — 서버가 지금 씬의 그 가게 NPC와 거리를 확인): 사기(가게 id, 아이템, 개수) / 팔기(탭, 칸, 개수)
	ShopBuy = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.string, t.string, t.number },
		RateLimit = { PerSecond = 5, Burst = 6 },
	},
	ShopSell = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("Equip", "Use", "Etc", "Cash", "Key"), t.number, t.number },
		RateLimit = { PerSecond = 5, Burst = 6 },
	},
	-- 소비 아이템 사용(탭, 칸) — 물약: 서버가 체력을 회복하고 1개 줄인다(체력이 가득하면 안 쓴다).
	UseItem = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.oneOf("Equip", "Use", "Etc", "Cash", "Key"), t.number },
		RateLimit = { PerSecond = 4, Burst = 4 },
	},
	-- 땅의 아이템 줍기(드랍 id) — 서버가 같은 씬·거리·가방 자리를 검증한다. 먼저 주운 사람이 가져간다.
	PickupDrop = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = { t.number },
		RateLimit = { PerSecond = 5, Burst = 6 },
	},
	-- 치료사에게 회복 요청: 서버가 지금 씬에 치료사가 있고 플레이어가 그 가까이에 있는지 확인한 뒤 체력을 가득 채운다.
	RequestHeal = {
		Kind = "Event",
		Direction = "ClientToServer",
		Args = {},
		RateLimit = { PerSecond = 1, Burst = 2 },
	},
	GetPlayerData = {
		Kind = "Function",
		Direction = "ClientToServer",
		Args = {},
		RateLimit = { PerSecond = 3, Burst = 8 },
	},

	-- ===== 서버 -> 클라이언트 =====
	-- 체력은 서버가 소유한다. 서버가 계산한 결과를 알려줄 뿐 클라이언트가 체력을 보고하지 않는다.
	-- 다른 플레이어의 (더는 유효하지 않은) 캐릭터 사본을 지우라는 통지: userId, objectId. 씬을 옮기거나 캐릭터를 새로 만든 플레이어의 옛 사본이 남는 유령을 막는다.
	RemoveReplicated = { Kind = "Event", Direction = "ServerToClient", Doc = "userId, objectId" },
	TravelApproved = { Kind = "Event", Direction = "ServerToClient", Doc = "destinationSceneName" },
	PlayerHealthChanged = { Kind = "Event", Direction = "ServerToClient", Doc = "health, maxHealth, damage, died" },
	InventoryUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "{ {Slot, ItemId, Count} }" },
	StatsUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "level, experience, maxExperience, leveledUp" },
	ItemAcquired = { Kind = "Event", Direction = "ServerToClient", Doc = "itemId, count" },
	EquipmentUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "{ Weapon=ItemId?, Armor=ItemId? }, { Weapon=강화 단계? }" },
	-- 강화 결과(성공 여부, 아이템 id, 지금 단계) — 가방·장비 내용은 InventoryUpdated · EquipmentUpdated로 따로 온다
	UpgradeResult = { Kind = "Event", Direction = "ServerToClient", Doc = "success, itemId, plus" },
	GoldUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "gold" },
	-- 탑다운 씬 공유 상태(같은 씬 플레이어에게만 보낸다 — 첫 인자는 항상 씬 키: 씬을 옮기는 순간 늦게 온 것은 버린다)
	TownMonsterMoves = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, { {id, x, y, facingLeft, moving} } (10Hz)" },
	TownMonsterSpawned = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, { id, row, level, hp, maxHp, x, y }" },
	TownMonsterHit = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, id, hp, damage, attackerUserId, source(무기 id | \"pet:<종 id>\")" },
	TownMonsterAttack = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, id — 몬스터가 반격하는 순간(연출용, 피해는 PlayerHealthChanged)" },
	TownMonsterDied = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, id" },
	WorldDropSpawned = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, { id, itemId, count, x, y, expiresIn }" },
	WorldDropRemoved = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, id, pickedByUserId?" },
	-- 도감: 처음 쓰러뜨린 몬스터(종류 줄 번호) — "새 친구!" 팝업 + 알림
	DexDiscovered = { Kind = "Event", Direction = "ServerToClient", Doc = "row" },
	-- 포획(M2): 방울 던지기(같은 씬 모두에게 날아가는 연출) / 맞은 몬스터의 포획 결과(연출 — 결과는 capture.RevealTime(딸랑 횟수) 뒤 적용)
	BellThrown = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, userId, x, y, dirX, dirY, distance, tier, hitMonsterId(0 = 빗나감)" },
	TownCapture = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, id, tier, result(\"success\"|\"fail\"|\"blocked\"), dings(딸랑 횟수 0~3)" },
	-- 투척 무기를 던짐(같은 씬 모두에게 날아가는 연출 — 피해는 TownMonsterHit). radius > 0이면 도착 자리에서 터진다(폭탄)
	ProjectileThrown = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, userId, itemId, x, y, dirX, dirY, distance, speed, radius" },
	-- 유파와 인술(「오문 닌자전」 N2 — shared/config/ninjutsu.luau)
	SchoolUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "school, { [스킬 id] = 레벨 }, 전직 단계(0~4), { 전직별 안 쓴 SP }, { 단축칸 스킬 id }" },
	-- 내게 쌓이는 핵심 장치(생기 · 견고 · 전하): 스킬 id, 지금 값, 최대, 이 초 뒤 사라짐(없으면 안 사라짐)
	CoreUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "skillId, value, max, seconds?" },
	-- 버프를 받음(열기 · 질풍 · 숲의 숨결): kind = "attack" | "haste" | "regen", 값(비율), 지속 초 — haste는 클라가 걸음 · 공격 동작에 반영한다
	BuffUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "kind, value, seconds" },
	EnergyUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "energy, max, regenPerSecond — 값이 바뀔 때만(그 사이는 클라가 이어서 센다)" },
	-- 인술을 씀(같은 씬 모두에게 연출용 — 피해는 TownMonsterHit "nin:<인술 id>"). x, y = 쓴 사람 발(도트).
	--  distance = 종류마다: projectile 날아간 거리 · line 길이 · circle 반경 · guard 지속 초. targets = chain이 맞힌 몬스터 id 순서
	NinjutsuCast = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, userId, skillId, x, y, dirX, dirY, distance, { targetMonsterId }" },
	-- 본 줄거리 퀘스트 상태(shared/config/quests.luau): 지금 퀘스트 번호 · 받았는가 · 진행(처치 수 등) · 방금 끝낸 퀘스트 id(없으면 nil)
	QuestUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "index, accepted, progress, completedId?" },
	-- 몬스터 상태 이상(연출용): kind = "slow" | "stun"
	TownMonsterStatus = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, id, kind, seconds" },
	-- 펫 스킬 발동(M4, 같은 씬 모두에게 연출용 — 피해는 TownMonsterHit "pet:<종 id>", 회복은 PlayerHealthChanged). x, y = 대상 몬스터(없으면 주인 발) 위치(도트)
	PetSkill = { Kind = "Event", Direction = "ServerToClient", Doc = "sceneKey, ownerUserId, partySlot, speciesId, pattern, targetMonsterId(0 = 없음), x, y" },
	-- 펫 상자·파티가 바뀜(잡음·편성·놓아주기)
	PetsUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "{ Box, Party, Paid }" },
	-- 소비 단축칸 1·2·3(아이템 id, 빈 칸 = "")
	QuickSlotsUpdated = { Kind = "Event", Direction = "ServerToClient", Doc = "{ id1, id2, id3 }" },
	-- 짧은 알림(화면 위 토스트): 가방이 가득 찼어요 등
	Notify = { Kind = "Event", Direction = "ServerToClient", Doc = "text" },
}

return packets

end
MODULES['ReplicatedStorage/shared/util/setup'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 공식 SpaceFighter 예제(notreux/SpaceFighter)의 src/shared/util/setup.luau 그대로 재활용.
local exports = {}

--[[
    Retrieves all ModuleScripts from a given path and requires them.
    Returns a table mapping module names to the required module.
]]
function exports.getModulesByPath(path)
	local modules = {}
	for _, module in path:GetChildren() do
		if module:IsA("ModuleScript") then
			modules[module.Name] = require(module)
		end
	end

	return modules
end

--[[
    Iterates over a table of modules and calls the specified method on each,
    passing any additional arguments provided.
]]
function exports.run(modules, methodName, ...)
	for _, module in modules do
		if module[methodName] then
			module[methodName](...)
		end
	end
end

return exports

end
MODULES['ServerScriptService/server/modules/heroTracking'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 플레이어 추적(서버): 각 플레이어가 "지금 어느 씬의 어디에 있는지". 캐릭터는 엔진 공식 패턴대로 client-authoritative
-- (클라이언트가 직접 만들고 조작)이고, 그 위치는 클라이언트가 NetworkingService로 복제해 보내는 요청(ReplicationRequest)에
-- 이미 들어 있다 — server/modules/replication.luau가 그 요청 내용에서 위치를 읽어 여기(OnHeroReplicated)로 넘긴다.
-- 따라서 위치를 따로 보고받는 패킷은 없다(공격 · 인술 · 투척의 기준 위치도 여기 저장된 서버가 아는 위치를 쓴다).
-- 이동 위치를 매번 거절하는 것은 엔진 공식 문서가 비권장이라(오탐/지연) 하지 않는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local scenes = require(ReplicatedStorage.shared.config.scenes)

-- UserId -> Vector2(화면 좌표계 Position.Offset)
local positions = {}
-- UserId -> 그 플레이어가 지금 있는 씬 이름. 서버가 소유한다(접속 시 마을, 이후 서버가 승인한 이동/사망 리스폰으로만 바뀜). 서버는 몬스터가
-- 있는 씬과 플레이어의 씬이 같은지 알아야 한다 — 좌표만 보면 마을에 있는 플레이어가 사냥터
-- 몬스터의 어그로/공격 대상이 돼버린다.
local playerScenes = {}

local exports = {}

function exports.GetPlayerScene(userId: number)
	return playerScenes[userId]
end

-- UserId -> 그 플레이어의 "현재" 캐릭터 오브젝트 Id(씬을 옮길 때마다 새 캐릭터가 만들어져서 바뀐다).
local heroObjectIds = {}

-- 플레이어의 씬을 바꾼다. 씬이 바뀌면 서로 다른 씬에 있게 된 플레이어들의 캐릭터 사본을 상대 클라이언트에서 지운다 —
-- 안 지우면 마지막 위치에 멈춘 유령 캐릭터가 남는다(둘이 접속해 한 명이 포탈을 탔을 때 실측).
-- 씬이 바뀔 때 알림을 받는다(예: 몬스터 기여도 초기화) — callback(userId, 이전 씬 이름?, 새 씬 이름)
local sceneChangedCallbacks = {}
function exports.OnSceneChanged(callback: (number, string?, string) -> ())
	table.insert(sceneChangedCallbacks, callback)
end

function exports.SetPlayerScene(userId: number, sceneName: string)
	local previous = playerScenes[userId]
	playerScenes[userId] = sceneName
	if previous ~= sceneName then
		for _, callback in sceneChangedCallbacks do
			task.spawn(callback, userId, previous, sceneName)
		end
	end
	for _, other in Players:GetPlayers() do
		if other.UserId == userId then
			continue
		end
		local otherScene = playerScenes[other.UserId]
		if otherScene ~= sceneName then
			-- 이동한 플레이어의 캐릭터를 상대가 지우고, 상대의 캐릭터를 이동한 플레이어가 지운다.
			local movedPlayer = Players:GetPlayerByUserId(userId)
			if heroObjectIds[userId] then
				Net.FireClient("RemoveReplicated", other, userId, heroObjectIds[userId])
			end
			if movedPlayer and heroObjectIds[other.UserId] then
				Net.FireClient("RemoveReplicated", movedPlayer, other.UserId, heroObjectIds[other.UserId])
			end
		end
	end
end

function exports.GetHeroObjectId(userId: number): string?
	return heroObjectIds[userId]
end

-- 지금 그 씬에 있는 플레이어 목록(탑다운 씬 공유 상태를 그 씬 사람들에게만 보낼 때)
function exports.PlayersInScene(sceneName: string): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if playerScenes[player.UserId] == sceneName then
			table.insert(list, player)
		end
	end
	return list
end

function exports.GetPosition(userId: number): Vector2?
	return positions[userId]
end

-- replication.luau가 히어로 복제 요청을 받을 때마다 호출한다(약 15Hz). position은 UDim2.
-- 반환값: 이 요청을 처리해도(다른 클라이언트에 전달해도) 되는가. 이미 교체된(은퇴한) 옛 캐릭터의 늦게 도착한 갱신이면 false —
-- 그걸 전달하면 상대 클라이언트가 방금 지운 옛 캐릭터를 새 오브젝트로 착각해 다시 만들어 유령이 된다(사망/씬 이동 직후 실측).
local retiredHeroIds = {}

function exports.OnHeroReplicated(userId: number, position: UDim2, objectId: string): boolean
	if retiredHeroIds[objectId] then
		return false
	end
	positions[userId] = Vector2.new(position.X.Offset, position.Y.Offset)
	local previous = heroObjectIds[userId]
	if previous ~= objectId then
		heroObjectIds[userId] = objectId
		if previous then
			retiredHeroIds[previous] = true
			-- 캐릭터가 새로 만들어졌다(씬 이동 등) — 옛 캐릭터는 클라이언트에서 이미 사라졌으므로 서버 캐시와 모든 클라이언트의
			-- 옛 사본을 지운다.
			NetworkingService.RequestsCache[userId][previous] = nil
			Net.FireAllClients("RemoveReplicated", userId, previous)
		end
	end
	return true
end

function exports.load()
	-- 게임은 항상 마을에서 시작한다.
	local function onPlayerAdded(player: Player)
		playerScenes[player.UserId] = scenes.TOWN
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		positions[player.UserId] = nil
		playerScenes[player.UserId] = nil
		heroObjectIds[player.UserId] = nil
	end)
end

function exports.start() end
function exports.unload() end

return exports

end
MODULES['ServerScriptService/server/modules/ninjutsuService'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 유파 · 전직 · 스킬(서버) — 「오문 닌자전」 NINJA_DESIGN.md §0-1 · §0-6. 수치·종류·스킬 나무는 shared/config/ninjutsu.luau.
--  전직(메이플식): data.Job = 0(견습) ~ 4. 모두 마을 스승(ninjutsu.CHANGE_NPC) 곁에서.
--   ChooseSchool(유파): Job 0이면 1차 전직 — Lv.10 이상이어야 하고, 고른 유파에 든다(Job = 1). Job 1 이상이면 유파 바꾸기(엽전 CHANGE_COST —
--    옛 유파 스킬에 쓴 SP는 돌려받고 새 유파의 주력기 · 핵심 장치를 1레벨로 받는다).
--   JobAdvance(): 다음 전직 레벨(30 · 60 · 100)이 됐으면 Job + 1. (전직 시험은 나중에 붙인다.)
--   전직하면 SP_ON_JOB을 받고 그 전직의 주력기 · 핵심 장치를 1레벨로 배운다.
--  스킬 포인트: data.SP[전직] = 안 쓴 SP(레벨업마다 progressionService가 지금 전직에 SP_PER_LEVEL씩 넣는다).
--   LearnSkill(id): 그 스킬 전직의 SP 1을 써서 +1(마스터 레벨까지). data.Ninjutsu[id] = 스킬 레벨(0/없음 = 안 배움).
--   SetSkillSlot(칸, id): 배운 쓰는 인술을 단축칸(1~SLOTS)에 넣는다("" = 비움). 처음 배우면 빈 칸에 저절로 들어간다.
--   바뀌면 SchoolUpdated(유파, 스킬 레벨표, 전직 단계, SP, 단축칸).
--  UseNinjutsu(칸, 바라보는 방향): 그 칸에 넣은 인술. 서버가 배웠는지 · 쿨타임 · 기력(또는 생기)을 확인한 뒤 쓴다.
--   같은 씬 모두에게 NinjutsuCast(연출) → 피해는 townMonsters.Damage(source "nin:<인술 id>") — 기여도·반격·처치 규칙이 기본 공격과 같다.
--   대상이 없어 못 쓰는 인술(번개 — 가까운 적 없음, 치유 — 체력 가득)은 기력·쿨타임을 쓰지 않는다.
--  핵심 장치(유파마다 하나 — 그 패시브를 배웠을 때):
--   불씨(f_ember)  — 불 인술(ember)이 맞은 몬스터에 쌓임(사람마다 따로). 하나마다 interval초에 한 번 피해("nin:burn").
--   서리(i_frost)  — 얼음 인술(frost)이 맞은 몬스터에 쌓임. 하나마다 느려지고 stacks가 되면 얼어붙는다(멈춤).
--   생기(p_vigor)  — 풀 인술이 맞을 때마다 내게 쌓임. 회복 인술(vigorCost)이 쓴다.
--   견고(r_firm)   — 몬스터에게 맞을 때마다 내게 쌓임. 하나마다 받는 피해가 줄어든다.
--   전하(t_charge) — 공격이 맞을 때마다 내게 쌓임. 하나마다 기본 공격이 빨라진다.
--   내게 쌓이는 것은 CoreUpdated(스킬 id, 값, 최대, 남은 초)로 화면에 알린다.
--  2차 스킬의 종류(shared/config/ninjutsu.luau 머리말): zone(설치) · buff(파티 버프) · detonate(점화) · shatter(깨뜨리기) · discharge(방전)
--   · decoy(얼음 분신) · counter(되받아치기) + line/projectile의 덧붙임(hits · follow · segments · pull · shots · single · mark · firmBonus).
--  기력: 서버가 갖는다(저장하지 않음 — 접속하면 가득). 값이 바뀔 때만 EnergyUpdated(지금 값, 최대, 초당 회복) — 그 사이는 클라가 이어서 센다.
--   기본 공격이 맞으면(townMonsters.OnPlayerAttack) 맞은 몬스터 수 × ENERGY_PER_HIT.
--  두루마리(UseScroll — server/modules/shops.luau UseItem이 부른다): 자기 유파 두루마리 1개 → 지금 전직의 SP +1.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local balance = require(ReplicatedStorage.shared.config.balance)
local ninjutsu = require(ReplicatedStorage.shared.config.ninjutsu)
local npcTalk = require(ReplicatedStorage.shared.config.npcTalk)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local townMonsters = require(script.Parent.townMonsters)
local persistence = require(script.Parent.Parent.services.persistence)
local progressionService = require(script.Parent.Parent.services.progressionService)
local currencyService = require(script.Parent.Parent.services.currencyService)
local inventoryService = require(script.Parent.Parent.services.inventoryService)

local world = townWorld.data
local SK = ninjutsu.SKILLS
local NPC_PAD = 24 -- 대화 거리보다 이만큼(도트) 여유(복제 지연 보정)
local DIRS = { up = Vector2.new(0, -1), down = Vector2.new(0, 1), left = Vector2.new(-1, 0), right = Vector2.new(1, 0) }
local CORE_OF = { plant = "p_vigor", rock = "r_firm", thunder = "t_charge" } -- 내게 쌓이는 핵심 장치

local exports = {}
local energy = {} -- [userId] = { value, at(os.clock) }
local ready = {} -- [userId] = { [인술 id | "dash"] = 다시 쓸 수 있는 시각 }
local cores = {} -- [userId] = { id, value, untilT? } — 생기 · 견고 · 전하(유파에 따라 하나)
local counters = {} -- [userId] = 기본 공격이 맞은 횟수(달궈진 칼날 · 정전기)
local guardUntil = {} -- [userId] = 방어 인술이 끝나는 시각(견고가 더 쌓인다)
local counterUntil = {} -- [userId] = { untilT, skill, level, key } — 되받아치기 자세가 끝나는 시각
local haste = {} -- [userId] = { value, untilT } — 질풍(공격 속도 버프)
local zones = {} -- 설치한 자리 목록(불기둥 · 얼음 벽 · 치유꽃 · 번개 덫): { n, owner, id, key, x, y, untilT, dead }
local zoneSerial = 0

local function levelOf(data, id: string): number
	return if data then ninjutsu.LevelOf(data.Ninjutsu, id) else 0
end

-- ---- 기력(기력 단련 c_energy가 최대 · 회복을 늘린다) ----
local function energyStats(player: Player): (number, number)
	local l = levelOf(persistence.Get(player), "c_energy")
	return ninjutsu.ENERGY_MAX + SK.c_energy.maxPerLevel * l, ninjutsu.ENERGY_REGEN + SK.c_energy.regenPerLevel * l
end

local function energyOf(player: Player, now: number)
	local max, regen = energyStats(player)
	local e = energy[player.UserId]
	if not e then
		e = { value = max, at = now }
		energy[player.UserId] = e
	end
	e.value = math.min(max, e.value + (now - e.at) * regen)
	e.at = now
	return e
end

local function sendEnergy(player: Player)
	local e = energyOf(player, os.clock())
	local max, regen = energyStats(player)
	Net.FireClient("EnergyUpdated", player, e.value, max, regen)
end

function exports.GetEnergy(player: Player): number
	return energyOf(player, os.clock()).value
end

function exports.AddEnergy(player: Player, amount: number)
	local e = energyOf(player, os.clock())
	e.value = math.clamp(e.value + amount, 0, (energyStats(player)))
	sendEnergy(player)
end

-- ---- 도우미 ----
local function toScene(key: string, ...)
	for _, player in heroTracking.PlayersInScene(townWorld.SceneName(key)) do
		Net.FireClient("NinjutsuCast", player, key, ...)
	end
end

local function feetOf(player: Player): Vector2?
	local position = heroTracking.GetPosition(player.UserId)
	return position and position / world.scale
end

local function nearNpc(player: Player, npcType: string): boolean
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	local d = key and townWorld.Get(key)
	local feet = feetOf(player)
	if not d or not feet then
		return false
	end
	for _, n in d.npcs do
		if n.type == npcType and (Vector2.new(n.x, n.y) - feet).Magnitude <= npcTalk.RANGE + NPC_PAD then
			return true
		end
	end
	return false
end

-- ---- 스킬 포인트 · 단축칸 ----
local function ensure(data)
	data.Ninjutsu = data.Ninjutsu or {}
	if typeof(data.SP) ~= "table" then
		data.SP = { 0, 0, 0, 0 }
	end
	if typeof(data.SkillSlots) ~= "table" then
		data.SkillSlots = { "", "", "", "" }
	end
end

local function sendSkills(player: Player, data)
	Net.FireClient("SchoolUpdated", player, data.School, data.Ninjutsu, data.Job or 0, data.SP, data.SkillSlots)
end

-- 쓰는 인술이면 빈 단축칸에 넣는다(이미 있으면 그대로)
local function fillSlot(data, id: string)
	if not ninjutsu.IsActive(id) or table.find(data.SkillSlots, id) then
		return
	end
	for slot = 1, ninjutsu.SLOTS do
		if (data.SkillSlots[slot] or "") == "" then
			data.SkillSlots[slot] = id
			return
		end
	end
end

-- 그 전직의 주력기 · 핵심 장치를 1레벨로(이미 배웠으면 그대로)
local function learnAuto(data, job: number)
	for _, id in ninjutsu.AutoFor(data.School, job) do
		if levelOf(data, id) < 1 then
			data.Ninjutsu[id] = 1
		end
		fillSlot(data, id)
	end
end

local function grantJob(data, job: number)
	ensure(data)
	data.SP[job] = (data.SP[job] or 0) + ninjutsu.SP_ON_JOB
	learnAuto(data, job)
end

-- ---- 핵심 장치 ----
-- 내게 쌓이는 것(생기 · 견고 · 전하): 스킬 id · 지금 값(시간이 지나 사라졌으면 0) · 그 패시브 레벨. 안 배웠으면 nil
local function coreOf(player: Player, data): (string?, number, number)
	local id = CORE_OF[data and data.School or ""]
	local level = if id then levelOf(data, id) else 0
	if not id or level < 1 then
		return nil, 0, 0
	end
	local c = cores[player.UserId]
	if not c or c.id ~= id then
		c = { id = id, value = 0 }
		cores[player.UserId] = c
	end
	if c.untilT and os.clock() >= c.untilT then
		c.value, c.untilT = 0, nil
	end
	return id, c.value, level
end

local function setCore(player: Player, id: string, value: number)
	local def = SK[id]
	local c = cores[player.UserId]
	c.value = math.clamp(value, 0, def.stacks)
	c.untilT = if def.seconds and c.value > 0 then os.clock() + def.seconds else nil
	Net.FireClient("CoreUpdated", player, id, c.value, def.stacks, def.seconds)
end

function exports.GetCore(player: Player): number
	local _, value = coreOf(player, persistence.Get(player))
	return value
end

-- 내게 쌓이는 핵심 장치를 amount만큼 더한다(그 패시브를 배웠을 때만)
function exports.AddCore(player: Player, amount: number)
	local id, value = coreOf(player, persistence.Get(player))
	if id then
		setCore(player, id, value + amount)
	end
end

-- 불씨: 그 사람이 그 몬스터에 붙인 불씨를 n개 더한다. 붙어 있는 동안 interval초마다 피해.
local function addEmber(key: string, m, player: Player, n: number)
	local level = levelOf(persistence.Get(player), "f_ember")
	if level < 1 or n <= 0 then
		return
	end
	local def = SK.f_ember
	local now = os.clock()
	m.ember = m.ember or {}
	local e = m.ember[player.UserId]
	if e and now < e.untilT then
		e.stacks = math.min(def.stacks, e.stacks + n)
		e.untilT = now + def.seconds
		return
	end
	e = { stacks = math.min(def.stacks, n), untilT = now + def.seconds }
	m.ember[player.UserId] = e
	local function tick()
		if not m.ember or m.ember[player.UserId] ~= e or os.clock() >= e.untilT then
			return
		end
		local amount = math.max(1, math.round(inventoryService.GetAttackDamage(player) * (def.power + def.perLevel * level) * e.stacks))
		if townMonsters.Damage(key, m.id, player, amount, "nin:burn") then
			task.delay(def.interval, tick)
		else
			e.untilT = 0
		end
	end
	task.delay(def.interval, tick)
end

-- 서리: 그 몬스터에 n개 더한다. 하나마다 느려지고, stacks가 되면 얼어붙고 다시 0부터.
local function addFrost(key: string, m, player: Player, n: number)
	local level = levelOf(persistence.Get(player), "i_frost")
	if level < 1 or n <= 0 then
		return
	end
	local def = SK.i_frost
	local now = os.clock()
	local f = m.frost
	if not f or now >= f.untilT then
		f = { stacks = 0, untilT = 0 }
		m.frost = f
	end
	f.stacks += n
	f.untilT = now + def.seconds
	if f.stacks >= def.stacks then
		f.stacks = 0
		m.frozenUntil = now + def.freeze + def.perLevel * level -- 얼어붙음(깨뜨리기가 본다)
		townMonsters.Stun(key, m.id, def.freeze + def.perLevel * level)
	else
		townMonsters.Slow(key, m.id, 1 - def.slowPer * f.stacks, def.seconds)
	end
end

-- 맞은 몬스터에게 덧붙는 효과(불씨 · 서리 · 느려짐 · 멈춤 · 밀림 · 불붙음). away = 밀려나는 방향(단위 벡터)
local function applyEffects(key: string, m, player: Player, skill, attack: number, scale: number, away: Vector2?)
	if skill.ember then
		addEmber(key, m, player, skill.ember)
	end
	if skill.frost then
		addFrost(key, m, player, skill.frost)
	end
	if skill.slow then
		townMonsters.Slow(key, m.id, skill.slow.mult, skill.slow.seconds)
	end
	if skill.stun then
		townMonsters.Stun(key, m.id, skill.stun)
	end
	if skill.push and away then
		townMonsters.Push(key, m.id, away.X * skill.push, away.Y * skill.push)
	end
	if skill.burn then
		local tick = math.max(1, math.round(attack * skill.burn.power * scale))
		for i = 1, skill.burn.ticks do
			task.delay(i * skill.burn.interval, townMonsters.Damage, key, m.id, player, tick, "nin:burn")
		end
	end
end

-- 전하: 공격(기본 · 인술)이 맞으면 1
local function gainCharge(player: Player)
	local coreId, value = coreOf(player, persistence.Get(player))
	if coreId == "t_charge" then
		setCore(player, coreId, value + 1)
	end
end

-- 그 몬스터가 지금 얼어붙어 있는가(서리 5로 멈춘 동안)
local function frozen(m, now: number): boolean
	return m.frozenUntil ~= nil and now < m.frozenUntil
end

-- 2차 패시브가 주는 피해 배율: 타오르는 마음(불씨가 걸린 적 수) · 차가운 피(서리/얼어붙은 적) · 감전(내 번개에 맞은 적)
local function passiveMult(key: string, m, player: Player, data): number
	local uid = player.UserId
	local now = os.clock()
	local mult = 1
	local school = data.School
	if school == "fire" then
		local level = levelOf(data, "f_drain")
		if level >= 1 then
			local n = 0
			for _, other in townMonsters.Living(key) do
				local e = other.ember and other.ember[uid]
				if e and now < e.untilT and e.stacks > 0 then
					n += 1
				end
			end
			mult *= 1 + (SK.f_drain.base + SK.f_drain.perLevel * level) * math.min(SK.f_drain.cap, n)
		end
	elseif school == "ice" then
		local level = levelOf(data, "i_cold")
		if level >= 1 and (frozen(m, now) or (m.frost and now < m.frost.untilT and m.frost.stacks > 0)) then
			mult *= 1 + SK.i_cold.perLevel * level
		end
	elseif school == "thunder" then
		local level = levelOf(data, "t_shock")
		if level >= 1 and m.shock and now < (m.shock[uid] or 0) then
			mult *= 1 + SK.t_shock.base + SK.t_shock.perLevel * level
		end
	end
	return mult
end

-- 인술 한 번 맞음. source = "nin:<id>"(씨앗이 터질 때 "<id>:burst" 등), power를 주면 skill.power 대신 쓴다.
local function hit(key: string, m, player: Player, source: string, skill, attack: number, scale: number, mult: number, away: Vector2?, power: number?): boolean
	local data = persistence.Get(player)
	local amount = math.max(1, math.round(attack * (power or skill.power) * scale * mult * passiveMult(key, m, player, data)))
	if not townMonsters.Damage(key, m.id, player, amount, "nin:" .. source) then
		return false
	end
	applyEffects(key, m, player, skill, attack, scale, away)
	gainCharge(player) -- 전하: 인술이 맞을 때마다(번개 유파만 쌓인다)
	local now = os.clock()
	if skill.school == "thunder" and levelOf(data, "t_shock") >= 1 then -- 감전: 다음 번개부터 더 아프다
		m.shock = m.shock or {}
		m.shock[player.UserId] = now + SK.t_shock.seconds
	end
	if skill.root then -- 뿌리 표식(가시 씨앗 · 덩굴 묶기)
		m.rootUntil = now + skill.root
	end
	if skill.school == "plant" then -- 생기: 풀 인술이 맞을 때마다(뿌리 내림 — 뿌리 표식이 있는 적이면 더)
		local coreId, value, level = coreOf(player, data)
		if coreId == "p_vigor" then
			local gain = SK.p_vigor.perHit + SK.p_vigor.perLevel * level
			local root = levelOf(data, "p_root")
			if root >= 1 and m.rootUntil and now < m.rootUntil then
				gain *= 1 + SK.p_root.vigorPerLevel * root
			end
			setCore(player, coreId, value + gain)
		end
	end
	return true
end

-- ---- 대쉬(이동기) ----
-- 벽에 막히기 전까지 갈 수 있는 거리(2도트씩 살핀다 — 클라 topDownHero와 같은 셈)
function exports.DashDistance(key: string, feet: Vector2, dir: Vector2, distance: number): number
	local d = townWorld.Get(key)
	local box = world.playerFeet
	local reached = 0
	for step = 2, distance, 2 do
		local p = feet + dir * step
		if townWorld.BoxBlocked(d, p.X, p.Y, box.halfW, box.h) then
			break
		end
		reached = step
	end
	return reached
end

-- 같은 씬에서 그 자리 둘레 radius 안에 있는 플레이어들(파티 버프 · 치유꽃)
local function playersNear(key: string, at: Vector2, radius: number): { Player }
	local out = {}
	for _, other in heroTracking.PlayersInScene(townWorld.SceneName(key)) do
		local feet = feetOf(other)
		if feet and (feet - at).Magnitude <= radius then
			table.insert(out, other)
		end
	end
	return out
end

-- 설치(zone): 그 자리에 seconds초 동안 남아 interval초마다 둘레 radius에 효과. once면 처음 적이 닿을 때 한 번 터지고 사라진다(덫).
--  같은 사람이 같은 스킬을 limit개 넘게 놓으면 가장 오래된 것이 사라진다. 연출: NinjutsuCast(id … targets = { 번호 }) / 끝날 때 "zone_end"(distance = 번호).
local function endZone(z)
	if not z.dead then
		z.dead = true
		table.remove(zones, table.find(zones, z))
		toScene(z.key, z.owner.UserId, "zone_end", z.x, z.y, 0, 0, z.n, {})
	end
end

local function placeZone(player: Player, key: string, id: string, skill, level: number, at: Vector2)
	local mine = {}
	for _, z in zones do
		if z.owner == player and z.id == id then
			table.insert(mine, z)
		end
	end
	while #mine >= (skill.limit or 1) do
		endZone(table.remove(mine, 1))
	end
	zoneSerial += 1
	local z = { n = zoneSerial, owner = player, id = id, key = key, x = at.X, y = at.Y, untilT = os.clock() + skill.seconds, dead = false }
	table.insert(zones, z)
	local scale = ninjutsu.Scale(id, level)
	local function tick()
		if z.dead then
			return
		end
		if os.clock() >= z.untilT or not player.Parent or townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId)) ~= key then
			endZone(z)
			return
		end
		local attack = inventoryService.GetAttackDamage(player)
		local touched = false
		for _, m in townMonsters.Living(key) do
			if (Vector2.new(m.x, m.y) - at).Magnitude <= skill.radius then
				touched = true
				if skill.power then
					hit(key, m, player, id, skill, attack, scale, 1, nil)
				else
					applyEffects(key, m, player, skill, attack, scale, nil)
				end
			end
		end
		if skill.heal then
			for _, other in playersNear(key, at, skill.radius) do
				local d = persistence.Get(other)
				if d then
					progressionService.Heal(other, math.max(1, math.round(balance.maxHealthFor(d.Level) * skill.heal * scale)))
				end
			end
		end
		if skill.once and touched then
			endZone(z)
			return
		end
		task.delay(skill.interval, tick)
	end
	task.delay(skill.interval, tick)
	return z
end

-- 버프: 나와 둘레 radius 안의 같은 씬 플레이어에게. attack = 공격력 + · haste = 걸음/공격 속도 + · regen = 2초마다 최대 체력의 그 비율 회복
local function applyBuff(player: Player, key: string, id: string, skill, level: number, feet: Vector2)
	local b = skill.buff
	for _, other in playersNear(key, feet, skill.radius) do
		if b.attack then
			local value = b.attack + (b.attackPerLevel or 0) * level
			inventoryService.SetAttackBuff(other, 1 + value, skill.seconds)
			Net.FireClient("BuffUpdated", other, "attack", value, skill.seconds)
			Net.FireClient("Notify", other, ("%s: 공격력 +%d%% (%d초)"):format(skill.name, math.round(value * 100), skill.seconds))
		end
		if b.haste then
			local value = b.haste + (b.hastePerLevel or 0) * level
			haste[other.UserId] = { value = value, untilT = os.clock() + skill.seconds }
			Net.FireClient("BuffUpdated", other, "haste", value, skill.seconds)
			Net.FireClient("Notify", other, ("%s: 걸음 · 공격 속도 +%d%% (%d초)"):format(skill.name, math.round(value * 100), skill.seconds))
		end
		if b.regen then
			local untilT = os.clock() + skill.seconds
			local function tick()
				local d = persistence.Get(other)
				if not d or not other.Parent or os.clock() > untilT then
					return
				end
				progressionService.Heal(other, math.max(1, math.round(balance.maxHealthFor(d.Level) * b.regen * ninjutsu.Scale(id, level))))
				task.delay(2, tick)
			end
			task.delay(2, tick)
			Net.FireClient("BuffUpdated", other, "regen", b.regen, skill.seconds)
			Net.FireClient("Notify", other, ("%s: 조금씩 회복 (%d초)"):format(skill.name, skill.seconds))
		end
	end
end

-- 인술 실행. 못 쓰면(대상 없음 등) false + 이유 — 기력·쿨타임을 쓰지 않는다.
local function cast(player: Player, key: string, id: string, skill, level: number, feet: Vector2, dir: Vector2): (boolean, string?)
	local uid = player.UserId
	local attack = inventoryService.GetAttackDamage(player)
	local scale = ninjutsu.Scale(id, level)
	local kind = skill.kind
	if kind == "projectile" or kind == "seed" then
		local origin = feet - Vector2.new(0, ninjutsu.HAND_Y)
		-- 견고를 실어 던지는 인술(바위 던지기): 견고 하나마다 피해 +, 쓰면 견고를 다 쓴다
		local firmMult = 1
		if skill.firmBonus then
			local coreId, value = coreOf(player, persistence.Get(player))
			if coreId == "r_firm" and value > 0 then
				firmMult = 1 + skill.firmBonus * value
				setCore(player, coreId, 0)
			end
		end
		do
			local function fire()
				local hitT, first = skill.range, nil
				for _, m in townMonsters.Living(key) do
					local rel = Vector2.new(m.x, m.y - ninjutsu.BODY_Y) - origin
					local along = rel:Dot(dir)
					local side = math.abs(rel.X * dir.Y - rel.Y * dir.X)
					if along >= 0 and along <= hitT and side <= skill.width + 3 then
						hitT, first = along, m
					end
				end
				toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, hitT, {})
				task.delay(hitT / skill.speed, function()
					if kind == "seed" then
						-- 처음 닿은 몬스터에 박히고, fuse초 뒤 그 몬스터가 있는 자리 둘레에 터진다
						if first and hit(key, first, player, id, skill, attack, scale, 1, nil) then
							task.delay(skill.fuse, function()
								local at = Vector2.new(first.x, first.y)
								for _, m in townMonsters.Living(key) do
									if (Vector2.new(m.x, m.y) - at).Magnitude <= skill.radius then
										hit(key, m, player, id .. ":burst", skill, attack, scale, 1, nil, skill.burstPower)
									end
								end
							end)
						end
						return
					end
					if skill.single then
						-- 한 마리만 맞는 투척(뇌전 수리검): 표식이 이미 있으면 번개가 한 번 더 떨어진다
						if first then
							local mark = skill.mark
							local marked = mark and first.mark and os.clock() < (first.mark[uid] or 0)
							if hit(key, first, player, id, skill, attack, scale, 1, nil) and mark then
								if marked then
									hit(key, first, player, id .. ":mark", skill, attack, scale, 1, nil, mark.power)
								end
								first.mark = first.mark or {}
								first.mark[uid] = os.clock() + mark.seconds
							end
						end
						return
					end
					local at = origin + dir * hitT + Vector2.new(0, ninjutsu.BODY_Y) -- 발 높이로 내려서 잰다
					for _, m in townMonsters.Living(key) do
						if (Vector2.new(m.x, m.y) - at).Magnitude <= skill.radius then
							hit(key, m, player, id, skill, attack, scale, firmMult, dir)
						end
					end
				end)
			end
			fire() -- 첫 발은 바로, 나머지는 shotGap초씩 늦게(연달아 던지는 인술)
			for shot = 2, skill.shots or 1 do
				task.delay((shot - 1) * (skill.shotGap or 0), fire)
			end
		end
	elseif kind == "line" then
		-- hits · interval: 여러 번(follow면 그때그때 내 자리에서). segments: 줄을 나눠 앞에서부터 segDelay초씩 늦게 터진다(falloff배씩 약해짐).
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, skill.length, {})
		local segments = skill.segments or 1
		for h = 1, skill.hits or 1 do
			for seg = 1, segments do
				task.delay((skill.delay or 0) + (h - 1) * (skill.interval or 0) + (seg - 1) * (skill.segDelay or 0), function()
					local from = if skill.follow then feetOf(player) or feet else feet
					local origin = from - Vector2.new(0, ninjutsu.HAND_Y)
					local lo, hi = skill.length * (seg - 1) / segments, skill.length * seg / segments
					for _, m in townMonsters.Living(key) do
						local rel = Vector2.new(m.x, m.y - ninjutsu.BODY_Y) - origin
						local along = rel:Dot(dir)
						local side = math.abs(rel.X * dir.Y - rel.Y * dir.X)
						if along >= (if seg == 1 then 0 else lo) and along <= hi and side <= skill.width then
							if hit(key, m, player, id, skill, attack, scale, (skill.falloff or 1) ^ (seg - 1), dir) and skill.pull then
								townMonsters.Push(key, m.id, -dir.X * skill.pull, -dir.Y * skill.pull) -- 끌어당김
							end
						end
					end
				end)
			end
		end
	elseif kind == "circle" then
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, skill.radius, {})
		for i = 1, skill.hits or 1 do
			task.delay((skill.delay or 0) + (i - 1) * (skill.interval or 0), function()
				for _, m in townMonsters.Living(key) do
					local rel = Vector2.new(m.x, m.y) - feet
					if rel.Magnitude <= skill.radius then
						hit(key, m, player, id, skill, attack, scale, 1, if rel.Magnitude > 0 then rel.Unit else dir)
					end
				end
			end)
		end
		if skill.firmGain then -- 발 구르기: 견고 +
			local coreId, value = coreOf(player, persistence.Get(player))
			if coreId == "r_firm" then
				setCore(player, coreId, value + skill.firmGain)
			end
		end
	elseif kind == "shatter" then
		-- 깨뜨리기: 둘레의 얼어붙은 적은 "깨짐"(큰 피해 + 조각이 옆의 적에게), 얼지 않은 적은 서리
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, skill.radius, {})
		task.delay(skill.delay or 0, function()
			local now = os.clock()
			local living = townMonsters.Living(key)
			for _, m in living do
				if (Vector2.new(m.x, m.y) - feet).Magnitude <= skill.radius then
					if frozen(m, now) then
						m.frozenUntil = nil
						local plain = table.clone(skill)
						plain.frost = nil
						if hit(key, m, player, id, plain, attack, scale, skill.shatter.mult, nil) then
							for _, other in living do
								if other ~= m and (Vector2.new(other.x, other.y) - Vector2.new(m.x, m.y)).Magnitude <= skill.shatter.shardRadius then
									hit(key, other, player, id .. ":shard", plain, attack, scale, 1, nil, skill.shatter.shard)
								end
							end
						end
					else
						hit(key, m, player, id, skill, attack, scale, 1, nil)
					end
				end
			end
		end)
	elseif kind == "detonate" then
		-- 점화: 둘레에서 내 불씨가 걸린 적이 모두 터진다(불씨 수만큼 세게). 터질 때 옆의 적에게 불씨가 옮겨붙는다.
		local now = os.clock()
		local targets = {}
		local living = townMonsters.Living(key)
		for _, m in living do
			local e = m.ember and m.ember[uid]
			if e and now < e.untilT and e.stacks > 0 and (Vector2.new(m.x, m.y) - feet).Magnitude <= skill.radius then
				table.insert(targets, { m = m, stacks = e.stacks })
			end
		end
		if #targets == 0 then
			return false, "불씨가 걸린 적이 없어요"
		end
		local ids = {}
		for _, t in targets do
			table.insert(ids, t.m.id)
		end
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, skill.radius, ids)
		local plain = table.clone(skill)
		plain.ember = nil
		for _, t in targets do
			t.m.ember[uid].untilT = 0 -- 불씨를 다 쓴다
			if hit(key, t.m, player, id, plain, attack, scale, t.stacks, nil) then
				for _, other in living do
					if other ~= t.m and (Vector2.new(other.x, other.y) - Vector2.new(t.m.x, t.m.y)).Magnitude <= skill.spread then
						addEmber(key, other, player, skill.spreadEmber)
					end
				end
			end
		end
	elseif kind == "discharge" then
		-- 방전: 전하를 모두 써서 둘레에 번개(전하가 많을수록 넓고 세다)
		local coreId, value = coreOf(player, persistence.Get(player))
		if coreId ~= "t_charge" or value < 1 then
			return false, "전하가 없어요"
		end
		local radius = skill.radius + skill.radiusPer * value
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, radius, {})
		setCore(player, coreId, 0)
		task.delay(skill.delay or 0, function()
			for _, m in townMonsters.Living(key) do
				if (Vector2.new(m.x, m.y) - feet).Magnitude <= radius then
					hit(key, m, player, id, skill, attack, scale, 1, nil, skill.power + skill.powerPer * value)
				end
			end
			setCore(player, "t_charge", 0) -- 방전으로 맞힌 것은 전하로 치지 않는다
		end)
	elseif kind == "zone" then
		local at = feet + dir * (skill.offset or 0)
		local z = placeZone(player, key, id, skill, level, at)
		toScene(key, uid, id, at.X, at.Y, dir.X, dir.Y, skill.seconds, { z.n })
	elseif kind == "buff" then
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, 1.2, {})
		applyBuff(player, key, id, skill, level, feet)
	elseif kind == "decoy" then
		-- 얼음 분신: 나를 쫓던 둘레의 적이 seconds초 동안 나를 놓치고, 분신이 깨지며 둘레에 서리
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, skill.seconds, {})
		for _, m in townMonsters.Living(key) do
			if (Vector2.new(m.x, m.y) - feet).Magnitude <= skill.radius and m.aggro == uid then
				m.aggro, m.target = nil, nil
				townMonsters.Stun(key, m.id, skill.seconds)
			end
		end
		task.delay(skill.seconds, function()
			for _, m in townMonsters.Living(key) do
				if (Vector2.new(m.x, m.y) - feet).Magnitude <= skill.radius then
					addFrost(key, m, player, skill.frost)
				end
			end
		end)
	elseif kind == "counter" then
		-- 되받아치기: window초 동안 막는 자세 — 그 사이에 맞으면(OnPlayerHurt) 피해 없이 충격파로 되받아친다
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, skill.window, {})
		counterUntil[uid] = { untilT = os.clock() + skill.window, skill = skill, level = level, key = key, id = id }
	elseif kind == "chain" then
		local living = townMonsters.Living(key)
		local chain, used = {}, {}
		local from, reach = feet, skill.range
		for _ = 1, 1 + skill.jumps do
			local best, bestD = nil, reach
			for _, m in living do
				local d = (Vector2.new(m.x, m.y) - from).Magnitude
				if not used[m.id] and d <= bestD then
					best, bestD = m, d
				end
			end
			if not best then
				break
			end
			used[best.id] = true
			table.insert(chain, best)
			from, reach = Vector2.new(best.x, best.y), skill.jumpRange
		end
		if #chain == 0 then
			return false, "가까이에 적이 없어요"
		end
		local ids = {}
		for _, m in chain do
			table.insert(ids, m.id)
		end
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, 0, ids)
		for i, m in chain do
			hit(key, m, player, id, skill, attack, scale, skill.falloff ^ (i - 1), nil)
		end
	elseif kind == "heal" then
		local data = persistence.Get(player)
		local maxHealth = data and balance.maxHealthFor(data.Level)
		if not data or (data.Health or maxHealth) >= maxHealth then
			return false, "체력이 이미 가득해요"
		end
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, 0, {})
		progressionService.Heal(player, math.max(1, math.round(maxHealth * skill.ratio * scale)))
	elseif kind == "guard" then
		toScene(key, uid, id, feet.X, feet.Y, dir.X, dir.Y, skill.seconds, {})
		townMonsters.SetGuard(player, skill.mult, skill.seconds)
		guardUntil[uid] = os.clock() + skill.seconds
	else
		return false, nil
	end
	if skill.selfHeal then -- 쓰면서 내 체력도 회복(만개 등)
		local data = persistence.Get(player)
		if data then
			progressionService.Heal(player, math.max(1, math.round(balance.maxHealthFor(data.Level) * skill.selfHeal * scale)))
		end
	end
	return true, nil
end

-- 두루마리 쓰기: 자기 유파 것이면 지금 전직의 SP +1 → true(호출한 쪽이 1개 줄인다)
function exports.UseScroll(player: Player, def): boolean
	local data = persistence.Get(player)
	if not data or def.Type ~= "Scroll" then
		return false
	end
	if not ninjutsu.SCHOOL_INFO[data.School or ""] or (data.Job or 0) < 1 then
		Net.FireClient("Notify", player, "먼저 유파를 골라야 해요")
		return false
	end
	if def.School ~= data.School then
		Net.FireClient("Notify", player, ("%s 유파의 두루마리예요"):format(ninjutsu.SCHOOL_INFO[def.School].name))
		return false
	end
	ensure(data)
	data.SP[data.Job] = (data.SP[data.Job] or 0) + 1
	persistence.MarkDirty(player)
	sendSkills(player, data)
	Net.FireClient("Notify", player, ("스킬 포인트 +1 (%d차)"):format(data.Job))
	return true
end

function exports.load()
	Net.OnServer("ChooseSchool", function(player: Player, school: string)
		local data = persistence.Get(player)
		if not data or not ninjutsu.SCHOOL_INFO[school] or data.School == school then
			return
		end
		if not nearNpc(player, ninjutsu.CHANGE_NPC) then
			Net.FireClient("Notify", player, "유파는 마을 스승 곁에서 고를 수 있어요")
			return
		end
		ensure(data)
		local first = (data.Job or 0) == 0
		if first then
			-- 1차 전직: 견습 닌자가 유파에 든다
			if data.Level < ninjutsu.JOB_LEVELS[1] then
				Net.FireClient("Notify", player, ("Lv.%d부터 유파에 들 수 있어요"):format(ninjutsu.JOB_LEVELS[1]))
				return
			end
			data.Job = 1
			data.School = school
			grantJob(data, 1)
		else
			if (data.Gold or 0) < ninjutsu.CHANGE_COST then
				Net.FireClient("Notify", player, ("엽전이 모자라요(%d 필요)"):format(ninjutsu.CHANGE_COST))
				return
			end
			currencyService.AddGold(player, -ninjutsu.CHANGE_COST)
			-- 옛 유파 스킬에 쓴 SP는 돌려받는다(전직하며 그냥 받은 1레벨은 빼고). 공용 스킬은 그대로.
			local old = data.School
			local keep = {}
			for id, level in data.Ninjutsu do
				local s = SK[id]
				local job = ninjutsu.JobOf(id)
				if s and s.school == "" then
					keep[id] = level
				elseif s and job and s.school == old then
					local free = if table.find(ninjutsu.AutoFor(old, job), id) then 1 else 0
					data.SP[job] = (data.SP[job] or 0) + math.max(0, level - free)
				end
			end
			data.Ninjutsu = keep
			data.School = school
			data.SkillSlots = { "", "", "", "" }
			for job = 1, data.Job do
				learnAuto(data, job)
			end
		end
		ready[player.UserId] = nil
		cores[player.UserId] = nil
		persistence.MarkDirty(player)
		task.spawn(persistence.Save, player, false) -- 유파는 캐릭터의 정체성 — 바로 저장
		sendSkills(player, data)
		Net.FireClient("Notify", player, if first
			then ("1차 전직! %s 유파의 %s이(가) 되었어요"):format(ninjutsu.SCHOOL_INFO[school].name, ninjutsu.JOB_NAMES[1])
			else ("%s 유파로 옮겼어요"):format(ninjutsu.SCHOOL_INFO[school].name))
	end)

	-- 2 · 3 · 4차 전직: 다음 전직 레벨이 됐으면 스승 곁에서
	Net.OnServer("JobAdvance", function(player: Player)
		local data = persistence.Get(player)
		local job = data and data.Job or 0
		if not data or job < 1 or job >= #ninjutsu.JOB_LEVELS then
			return
		end
		if not nearNpc(player, ninjutsu.CHANGE_NPC) then
			Net.FireClient("Notify", player, "전직은 마을 스승 곁에서 할 수 있어요")
			return
		end
		local need = ninjutsu.JOB_LEVELS[job + 1]
		if data.Level < need then
			Net.FireClient("Notify", player, ("%d차 전직은 Lv.%d부터예요"):format(job + 1, need))
			return
		end
		data.Job = job + 1
		grantJob(data, data.Job)
		persistence.MarkDirty(player)
		task.spawn(persistence.Save, player, false)
		sendSkills(player, data)
		local id = ninjutsu.AutoFor(data.School, data.Job)[1]
		Net.FireClient("Notify", player, ("%d차 전직! %s이(가) 되어 %s을(를) 배웠어요"):format(data.Job, ninjutsu.JOB_NAMES[data.Job], id and SK[id].name or "스킬 포인트"))
	end)

	-- 스킬 배우기 · 올리기: 그 스킬 전직의 SP 1
	Net.OnServer("LearnSkill", function(player: Player, id: string)
		local data = persistence.Get(player)
		local job = ninjutsu.JobOf(id)
		if not data or not job or not ninjutsu.Belongs(id, data.School) or (data.Job or 0) < job then
			return
		end
		ensure(data)
		local level = levelOf(data, id)
		if level >= ninjutsu.MaxOf(id) then
			return
		end
		if (data.SP[job] or 0) < 1 then
			Net.FireClient("Notify", player, ("%d차 스킬 포인트가 없어요"):format(job))
			return
		end
		data.SP[job] -= 1
		data.Ninjutsu[id] = level + 1
		if level == 0 then
			fillSlot(data, id)
		end
		persistence.MarkDirty(player)
		sendSkills(player, data)
		if id == "c_energy" then
			sendEnergy(player)
		end
	end)

	-- 단축칸에 인술 넣기("" = 비움). 같은 인술은 한 칸에만.
	Net.OnServer("SetSkillSlot", function(player: Player, slot: number, id: string)
		local data = persistence.Get(player)
		if not data or slot ~= math.floor(slot) or slot < 1 or slot > ninjutsu.SLOTS then
			return
		end
		ensure(data)
		if id ~= "" and (not ninjutsu.IsActive(id) or not ninjutsu.Belongs(id, data.School) or levelOf(data, id) < 1) then
			return
		end
		for i = 1, ninjutsu.SLOTS do
			if id ~= "" and data.SkillSlots[i] == id then
				data.SkillSlots[i] = ""
			end
		end
		data.SkillSlots[slot] = id
		persistence.MarkDirty(player)
		sendSkills(player, data)
	end)

	Net.OnServer("UseNinjutsu", function(player: Player, slot: number, facing: string)
		local data = persistence.Get(player)
		if not data or slot ~= math.floor(slot) or slot < 1 or slot > ninjutsu.SLOTS then
			return
		end
		ensure(data)
		local id = data.SkillSlots[slot] or ""
		local skill = SK[id]
		local dir = DIRS[facing]
		if not skill or not dir or not ninjutsu.IsActive(id) then
			return
		end
		local level = levelOf(data, id)
		if level < 1 or not ninjutsu.Belongs(id, data.School) or (data.Job or 0) < (ninjutsu.JobOf(id) or math.huge) then
			return
		end
		local now = os.clock()
		local mine = ready[player.UserId] or {}
		ready[player.UserId] = mine
		if now < (mine[id] or 0) then
			return
		end
		local e = energyOf(player, now)
		if e.value < skill.cost then
			Net.FireClient("Notify", player, "기력이 모자라요")
			return
		end
		local coreId, coreValue = coreOf(player, data)
		if skill.vigorCost and (coreId ~= "p_vigor" or coreValue < skill.vigorCost) then
			Net.FireClient("Notify", player, "생기가 모자라요")
			return
		end
		local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
		local feet = feetOf(player)
		if not key or not feet then
			return
		end
		local ok, why = cast(player, key, id, skill, level, feet, dir)
		if not ok then
			if why then
				Net.FireClient("Notify", player, why)
			end
			return
		end
		e.value -= skill.cost
		mine[id] = now + skill.cooldown
		sendEnergy(player)
		if skill.vigorCost then
			setCore(player, "p_vigor", coreValue - skill.vigorCost)
		end
	end)

	-- 대쉬: 견습 = 구르기, 1차 전직부터 유파의 대쉬. 움직임은 클라이언트가 하고(위치는 복제로 따라온다),
	--  순수 이동기라 피해 · 상태 이상이 없다 — 서버는 쿨타임 · 기력만 확인하고 같은 씬에 연출을 알린다(NinjutsuCast "dash_<id>").
	Net.OnServer("UseDash", function(player: Player, facing: string)
		local data = persistence.Get(player)
		local dir = DIRS[facing]
		if not data or not dir then
			return
		end
		local id, dash = ninjutsu.DashFor(data.School, data.Job)
		local now = os.clock()
		local mine = ready[player.UserId] or {}
		ready[player.UserId] = mine
		if now < (mine.dash or 0) then
			return
		end
		local e = energyOf(player, now)
		if e.value < dash.cost then
			Net.FireClient("Notify", player, "기력이 모자라요")
			return
		end
		local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
		local feet = feetOf(player)
		if not key or not feet then
			return
		end
		local dist = exports.DashDistance(key, feet, dir, dash.distance)
		mine.dash = now + dash.cooldown
		if dash.cost > 0 then
			e.value -= dash.cost
			sendEnergy(player)
		end
		toScene(key, player.UserId, "dash_" .. id, feet.X, feet.Y, dir.X, dir.Y, dist, {})
	end)

	-- 기본 공격이 맞으면: 기력 · 전하 · 달궈진 칼날(불) · 정전기(번개)
	townMonsters.OnPlayerAttack(function(player: Player, key: string, _feet, _facing, hitIds)
		if #hitIds == 0 then
			return
		end
		exports.AddEnergy(player, #hitIds * ninjutsu.ENERGY_PER_HIT)
		gainCharge(player)
		local data = persistence.Get(player)
		local uid = player.UserId
		counters[uid] = (counters[uid] or 0) + 1
		for _, id in { "f_blade", "t_static" } do
			local def = SK[id]
			local level = levelOf(data, id)
			if level >= 1 and data.School == def.school and counters[uid] % def.every == 0 then
				local amount = math.max(1, math.round(inventoryService.GetAttackDamage(player) * (def.power + def.perLevel * level)))
				local done = 0
				for _, m in townMonsters.Living(key) do
					if table.find(hitIds, m.id) and (id ~= "t_static" or done == 0) then -- 정전기는 한 마리에게만
						done += 1
						if townMonsters.Damage(key, m.id, player, amount, "nin:" .. id) and def.ember then
							addEmber(key, m, player, def.ember)
						end
					end
				end
			end
		end
	end)

	-- 몬스터에게 맞을 때: 얼음 갑옷(피해 감소 + 때린 적에게 서리) · 견고(피해 감소 + 쌓임)
	townMonsters.OnPlayerHurt(function(player: Player, key: string, m, damage: number): number
		local data = persistence.Get(player)
		-- 되받아치기: 자세 중에 맞으면 피해 없이 둘레에 충격파 + 견고 가득
		local c = counterUntil[player.UserId]
		if c and os.clock() < c.untilT then
			counterUntil[player.UserId] = nil
			local feet = feetOf(player)
			local attack = inventoryService.GetAttackDamage(player)
			if feet then
				for _, other in townMonsters.Living(c.key) do
					if (Vector2.new(other.x, other.y) - feet).Magnitude <= c.skill.radius then
						hit(c.key, other, player, c.id, c.skill, attack, ninjutsu.Scale(c.id, c.level), 1, nil)
					end
				end
			end
			local coreId = coreOf(player, data)
			if coreId == "r_firm" then
				setCore(player, coreId, SK.r_firm.stacks)
			end
			return 0
		end
		local root = levelOf(data, "p_root")
		if root >= 1 and data.School == "plant" and m.rootUntil and os.clock() < m.rootUntil then
			damage *= 1 - SK.p_root.reducePerLevel * root -- 뿌리 표식이 있는 적은 덜 아프게 때린다
		end
		local heavy = levelOf(data, "r_heavy")
		if heavy >= 1 and data.School == "rock" then
			damage *= 1 - SK.r_heavy.perLevel * heavy
		end
		local armor = levelOf(data, "i_armor")
		if armor >= 1 and data.School == "ice" then
			damage *= 1 - SK.i_armor.perLevel * armor
			addFrost(key, m, player, SK.i_armor.frost)
		end
		local coreId, value, level = coreOf(player, data)
		if coreId == "r_firm" then
			local def = SK.r_firm
			damage *= 1 - (def.reduce + def.perLevel * level) * value
			local guarded = os.clock() < (guardUntil[player.UserId] or 0)
			setCore(player, coreId, value + (if guarded then def.guardGain else 1))
		end
		return damage
	end)

	-- 전하: 하나마다 기본 공격이 빨라진다(공격 간격 × 이 배율)
	townMonsters.OnAttackSpeed(function(player: Player): number
		local mult = 1
		local coreId, value, level = coreOf(player, persistence.Get(player))
		if coreId == "t_charge" then
			mult /= 1 + (SK.t_charge.speedPer + SK.t_charge.perLevel * level) * value
		end
		local h = haste[player.UserId]
		if h and os.clock() < h.untilT then
			mult /= 1 + h.value -- 질풍
		end
		return mult
	end)

	Players.PlayerRemoving:Connect(function(player)
		energy[player.UserId] = nil
		ready[player.UserId] = nil
		cores[player.UserId] = nil
		counters[player.UserId] = nil
		guardUntil[player.UserId] = nil
		counterUntil[player.UserId] = nil
		haste[player.UserId] = nil
		for i = #zones, 1, -1 do
			if zones[i].owner == player then
				endZone(zones[i])
			end
		end
	end)
end

function exports.start() end
function exports.unload() end

return exports

end
MODULES['ServerScriptService/server/modules/petService'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 펫(잡은 몬스터) 상자·파티(서버) — GAME_DESIGN §5. 저장 형태는 shared/config/pets.luau 맨 위 설명.
--  PetAction(행동, 상자 번호):
--   Add     — 함께 다니기(파티 끝에). 칸 수 = pets.SlotCount(레벨, 유료 칸)
--   Remove  — 상자로(파티에서 뺌)
--   Lead    — 대표로(파티 1번 — 다른 사람에게 보이는 한 마리)
--   Release — 놓아주기: 상자에서 사라진다(보상 없음). 뒤 번호들이 당겨지므로 파티 번호도 맞춘다.
--  바뀌면 PetsUpdated로 { Box, Party, Paid }를 보낸다. (파티 편성은 지금은 어디서나 — 마을 상자에서만 할지는 추후)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local pets = require(ReplicatedStorage.shared.config.pets)
local persistence = require(script.Parent.Parent.services.persistence)

local exports = {}

local function push(player: Player, data)
	persistence.MarkDirty(player)
	Net.FireClient("PetsUpdated", player, data.Pets)
end

function exports.load()
	Net.OnServer("PetAction", function(player: Player, action: string, index: number)
		local data = persistence.Get(player)
		local p = data and data.Pets
		if not p or index ~= math.floor(index) or index < 1 or index > #p.Box then
			return
		end
		local at = table.find(p.Party, index)
		if action == "Add" then
			if at or #p.Party >= pets.SlotCount(data.Level, p.Paid) then
				return
			end
			table.insert(p.Party, index)
		elseif action == "Remove" then
			if not at then
				return
			end
			table.remove(p.Party, at)
		elseif action == "Lead" then
			if at then
				table.remove(p.Party, at)
			elseif #p.Party >= pets.SlotCount(data.Level, p.Paid) then
				table.remove(p.Party) -- 칸이 꽉 찼으면 맨 끝을 상자로
			end
			table.insert(p.Party, 1, index)
		elseif action == "Release" then
			table.remove(p.Box, index)
			local party = {}
			for _, i in p.Party do
				if i ~= index then
					table.insert(party, if i > index then i - 1 else i)
				end
			end
			p.Party = party
			task.spawn(persistence.Save, player, false)
		end
		push(player, data)
	end)
end

function exports.start() end
function exports.unload() end

return exports

end
MODULES['ServerScriptService/server/modules/petSkillService'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 펫 패시브 스킬(M4, 서버) — 수치·패턴은 shared/config/petSkills.luau, 종별 스킬은 petSkills.generated(공방 내보내기).
--  플레이어가 공격할 때마다(townMonsters.OnPlayerAttack — 헛손질 포함) 함께 다니는 펫마다:
--   쿨타임(PET_COOLDOWN) 지났고 확률(패턴 proc)에 걸리면 → 같은 씬 모두에게 PetSkill(연출) → 피해/회복.
--  피해는 townMonsters.Damage(source "pet:<종 id>") — 주인 기여도에 합산, 반격·처치 규칙도 같다.
--  패턴:
--   bolt  — 발에서 BOLT_RANGE 안 가장 가까운 몬스터 한 마리, BOLT_FLIGHT초 뒤 맞음
--   burst — BURST_DELAY초 뒤 (그때의) 플레이어 둘레 BURST_RADIUS 안 모두
--   orbit — ORBIT_TIME초 동안 ORBIT_TICK초마다 둘레 ORBIT_RADIUS+ORBIT_BAND 안 모두
--   drop  — 이번에 맞힌 몬스터(없으면 DROP_RANGE 안 가장 가까운) 자리에 DROP_DELAY초 뒤, 그 둘레 DROP_RADIUS 안 모두
--   buff  — 체력이 덜 찼을 때만, 최대 체력의 HEAL_RATIO 회복
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local balance = require(ReplicatedStorage.shared.config.balance)
local petSkills = require(ReplicatedStorage.shared.config.petSkills)
local features = require(ReplicatedStorage.shared.config.features)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local townMonsters = require(script.Parent.townMonsters)
local persistence = require(script.Parent.Parent.services.persistence)
local progressionService = require(script.Parent.Parent.services.progressionService)

local world = townWorld.data
local exports = {}
local rng = Random.new()
local ready = {} -- [userId] = { [파티 칸] = 다시 쓸 수 있는 시각 }

local function toScene(key: string, ...)
	for _, player in heroTracking.PlayersInScene(townWorld.SceneName(key)) do
		Net.FireClient("PetSkill", player, key, ...)
	end
end

local function feetOf(player: Player): Vector2?
	local position = heroTracking.GetPosition(player.UserId)
	return position and position / world.scale
end

local function nearest(key: string, at: Vector2, range: number)
	local best, bestD = nil, range
	for _, m in townMonsters.Living(key) do
		local d = (Vector2.new(m.x, m.y) - at).Magnitude
		if d <= bestD then
			best, bestD = m, d
		end
	end
	return best
end

local function hitAround(key: string, player: Player, at: Vector2, radius: number, amount: number, source: string)
	for _, m in townMonsters.Living(key) do
		if (Vector2.new(m.x, m.y) - at).Magnitude <= radius then
			townMonsters.Damage(key, m.id, player, amount, source)
		end
	end
end

local function stillHere(player: Player, key: string): boolean
	return player.Parent ~= nil and townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId)) == key
end

-- 한 펫의 스킬 실행. 대상이 없어 못 쓰면 false(쿨타임을 쓰지 않음).
local function cast(player: Player, key: string, feet: Vector2, hitIds, slot: number, pet, skill): boolean
	local pattern = skill.pattern
	local amount = petSkills.Damage(pattern, pet.L or 1)
	local source = "pet:" .. pet.S -- 맞은 몬스터 위 연출을 그 펫 이펙트로(클라 town/petFx)
	local uid = player.UserId
	if pattern == "bolt" then
		local m = nearest(key, feet, petSkills.BOLT_RANGE)
		if not m then
			return false
		end
		toScene(key, uid, slot, pet.S, pattern, m.id, m.x, m.y)
		task.delay(petSkills.BOLT_FLIGHT, townMonsters.Damage, key, m.id, player, amount, source)
	elseif pattern == "burst" then
		toScene(key, uid, slot, pet.S, pattern, 0, feet.X, feet.Y)
		task.delay(petSkills.BURST_DELAY, function()
			local now = feetOf(player)
			if now and stillHere(player, key) then
				hitAround(key, player, now, petSkills.BURST_RADIUS, amount, source)
			end
		end)
	elseif pattern == "orbit" then
		toScene(key, uid, slot, pet.S, pattern, 0, feet.X, feet.Y)
		task.spawn(function()
			local t = 0
			while t < petSkills.ORBIT_TIME do
				t += task.wait(petSkills.ORBIT_TICK)
				local now = feetOf(player)
				if not now or not stillHere(player, key) then
					return
				end
				hitAround(key, player, now, petSkills.ORBIT_RADIUS + petSkills.ORBIT_BAND, amount, source)
			end
		end)
	elseif pattern == "drop" then
		local living = townMonsters.Living(key)
		local m = nil
		for _, c in living do
			if table.find(hitIds, c.id) then
				m = c
				break
			end
		end
		m = m or nearest(key, feet, petSkills.DROP_RANGE)
		if not m then
			return false
		end
		toScene(key, uid, slot, pet.S, pattern, m.id, m.x, m.y)
		local at = Vector2.new(m.x, m.y)
		task.delay(petSkills.DROP_DELAY, function()
			if stillHere(player, key) then
				hitAround(key, player, if m.dead then at else Vector2.new(m.x, m.y), petSkills.DROP_RADIUS, amount, source)
			end
		end)
	elseif pattern == "buff" then
		local data = persistence.Get(player)
		local maxHealth = data and balance.maxHealthFor(data.Level)
		if not data or (data.Health or maxHealth) >= maxHealth then
			return false -- 이미 가득이면 안 쓴다(연출만 나오는 걸 막음)
		end
		toScene(key, uid, slot, pet.S, pattern, 0, feet.X, feet.Y)
		progressionService.Heal(player, math.max(1, math.round(maxHealth * petSkills.HEAL_RATIO)))
	else
		return false
	end
	return true
end

local function onAttack(player: Player, key: string, feet: Vector2, _facing: string, hitIds)
	local data = persistence.Get(player)
	local p = data and data.Pets
	if not p or #p.Party == 0 then
		return
	end
	local now = os.clock()
	local mine = ready[player.UserId] or {}
	ready[player.UserId] = mine
	for slot, index in p.Party do
		local pet = p.Box[index]
		local skill = pet and petSkills.SkillOf(pet.S)
		local pattern = skill and petSkills.PATTERNS[skill.pattern]
		if not pattern or now < (mine[slot] or 0) or rng:NextNumber() >= pattern.proc then
			continue
		end
		if cast(player, key, feet, hitIds, slot, pet, skill) then
			mine[slot] = now + petSkills.PET_COOLDOWN
		end
	end
end

function exports.load()
	if not features.PETS then
		return -- 펫은 지금 꺼 둠(shared/config/features.luau)
	end
	townMonsters.OnPlayerAttack(onAttack)
	Players.PlayerRemoving:Connect(function(player)
		ready[player.UserId] = nil
	end)
end

function exports.start() end
function exports.unload() end

return exports

end
MODULES['ServerScriptService/server/modules/playerData'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 플레이어 데이터 오케스트레이션(서버 모듈 진입점). 실제 일은 server/services의 역할별 서비스가 한다:
--   persistence(저장/로드/세션 락/오토세이브) · playerSchema(저장 형태 + 버전 마이그레이션)
--   progressionService(경험치/레벨/체력/사망) · inventoryService(인벤토리/장비) · currencyService(골드)
-- 이 모듈은 접속/퇴장 생명주기와 클라이언트 요청(Net) 연결만 담당한다. 다른 서버 모듈(몬스터 등)은 필요한 서비스를 직접 require해서 쓴다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)

local persistence = require(script.Parent.Parent.services.persistence)
local inventoryService = require(script.Parent.Parent.services.inventoryService)

local exports = {}

function exports.load()
	-- 인자 타입/빈도 검사는 Net이 이미 끝냈다(shared/net/packets.luau의 정의) — 핸들러는 통과한 값만 받는다.
	Net.OnServer("EquipAction", function(player: Player, action, arg)
		if action == "Equip" and typeof(arg) == "number" then
			inventoryService.Equip(player, math.floor(arg))
		elseif action == "Unequip" and typeof(arg) == "string" then
			inventoryService.Unequip(player, arg)
		end
	end)

	-- 가방 드래그 앤 드롭: 같은 탭 안에서 칸 옮기기(빈 칸이면 이동, 아이템이 있으면 맞바꾸기, 같은 아이템이면 합치기)
	Net.OnServer("MoveItem", function(player: Player, tab: string, from: number, to: number)
		inventoryService.Move(player, tab, from, to)
	end)

	Net.OnServer("GetPlayerData", function(player: Player)
		return persistence.Load(player)
	end)

	local function onPlayerAdded(player: Player)
		local data = persistence.Load(player)
		Net.FireClient("InventoryUpdated", player, data.Inventory)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		persistence.Release(player)
	end)

	-- main.server.luau가 모듈을 load()하는 시점과 PlayerAdded가 먼저 fire되는 시점이 Studio 테스트 환경에 따라 어긋날 수
	-- 있어서, 이미 접속해 있는 플레이어도 처리한다.
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(persistence.SaveAll)
	persistence.StartAutosave()
end

function exports.start() end

function exports.unload()
	persistence.StopAutosave()
	persistence.SaveAll()
end

return exports

end
MODULES['ServerScriptService/server/modules/questService'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 본 줄거리 퀘스트(서버 권위) — 규칙은 shared/config/quests.luau, 자료는 공방 설계를 옮긴 shared/data/quests.generated.luau.
--  QuestTalk(npc 키): 그 NPC 곁에서 — 아직 안 받았으면 받고(주는 사람 · 레벨 확인), 받았으면 끝낸다(끝낼 사람 · 목표 확인).
--  처치는 townMonsters.OnKill, 가기는 heroTracking.OnSceneChanged로 센다. 바뀔 때마다 QuestUpdated(번호, 받았는가, 진행, 방금 끝낸 id)를 보낸다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local quests = require(ReplicatedStorage.shared.config.quests)
local npcTalk = require(ReplicatedStorage.shared.config.npcTalk)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local persistence = require(script.Parent.Parent.services.persistence)
local progressionService = require(script.Parent.Parent.services.progressionService)
local currencyService = require(script.Parent.Parent.services.currencyService)
local inventoryService = require(script.Parent.Parent.services.inventoryService)
local heroTracking = require(script.Parent.heroTracking)
local townMonsters = require(script.Parent.townMonsters)

local world = townWorld.data
local NPC_PAD = 24 -- 대화 거리보다 이만큼(도트) 여유(복제 지연 보정)

local exports = {}

local function nearNpc(player: Player, npcType: string): boolean
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	local d = key and townWorld.Get(key)
	local position = heroTracking.GetPosition(player.UserId)
	if not d or not position then
		return false
	end
	local feet = position / world.scale
	for _, n in d.npcs do
		if n.type == npcType and (Vector2.new(n.x, n.y) - feet).Magnitude <= npcTalk.RANGE + NPC_PAD then
			return true
		end
	end
	return false
end

local function stateOf(data)
	if typeof(data.Quest) ~= "table" then
		data.Quest = { Index = 1, Accepted = false, Progress = 0 }
	end
	return data.Quest
end

local function send(player: Player, s, doneId: string?)
	Net.FireClient("QuestUpdated", player, s.Index, s.Accepted, s.Progress, doneId)
end

-- 보상을 주고 다음 퀘스트로. 보상 아이템이 가방에 안 들어가면 끝내지 않는다(false).
local function complete(player: Player, data, q): boolean
	local s = stateOf(data)
	local itemId = quests.RewardItem(q, data.School)
	local need = if itemId then q.itemCount or 1 else 0
	if itemId and inventoryService.RoomFor(player, itemId) < need then
		Net.FireClient("Notify", player, "가방이 가득 차서 보상을 받을 수 없어요")
		return false
	end
	if q.kind == "collect" and not inventoryService.TakeItem(player, q.target, q.count) then
		return false
	end
	s.Index += 1
	s.Accepted = false
	s.Progress = 0
	persistence.MarkDirty(player)
	if q.gold > 0 then
		currencyService.AddGold(player, q.gold)
	end
	if itemId then
		inventoryService.AddItem(player, itemId, need)
	end
	send(player, s, q.id)
	if q.exp > 0 then
		progressionService.AddExperience(player, q.exp)
	end
	task.spawn(persistence.Save, player, false) -- 줄거리 진행은 잃으면 아프다 — 바로 저장
	return true
end

function exports.Talk(player: Player, npcType: string)
	local data = persistence.Get(player)
	if not data then
		return
	end
	local s = stateOf(data)
	local q = quests.Get(s.Index)
	if not q or not nearNpc(player, npcType) then
		return
	end
	if not s.Accepted then
		if npcType ~= q.giver then
			return
		end
		if data.Level < q.level then
			Net.FireClient("Notify", player, ("Lv.%d부터 받을 수 있어요"):format(q.level))
			return
		end
		s.Accepted = true
		s.Progress = 0
		persistence.MarkDirty(player)
		local here = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
		if quests.Instant(q) or (q.kind == "reach" and q.scene ~= nil and q.scene == here) then
			if complete(player, data, q) then
				return
			end
		end
		send(player, s)
		return
	end
	if quests.TurnIn(q) ~= npcType then
		return
	end
	local have = if q.kind == "collect" then inventoryService.CountItem(player, q.target) else 0
	if quests.Ready(q, s.Progress, have, data.Job or 0) then
		complete(player, data, q)
	end
end

function exports.load()
	Net.OnServer("QuestTalk", exports.Talk)

	-- 처치: 받은 퀘스트의 몬스터 · 보스면 센다
	townMonsters.OnKill(function(player: Player, speciesId: string)
		local data = persistence.Get(player)
		local s = data and stateOf(data)
		local q = s and s.Accepted and quests.Get(s.Index)
		if q and quests.CountsKill(q, speciesId) and s.Progress < q.count then
			s.Progress += 1
			persistence.MarkDirty(player)
			send(player, s)
		end
	end)

	-- 가기: 받은 퀘스트의 씬에 들어서면 바로 끝난다
	heroTracking.OnSceneChanged(function(userId: number, _previous: string?, sceneName: string)
		local player = Players:GetPlayerByUserId(userId)
		local data = player and persistence.Get(player)
		local s = data and stateOf(data)
		local q = s and s.Accepted and quests.Get(s.Index)
		if q and q.kind == "reach" and q.scene ~= nil and townWorld.KeyOf(sceneName) == q.scene then
			complete(player, data, q)
		end
	end)
end

function exports.start() end
function exports.unload() end

return exports

end
MODULES['ServerScriptService/server/modules/quickSlots'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 소비 단축칸 1·2·3(서버) — GAME_DESIGN §3. 가방에서 소비 아이템(방울·물약)을 칸에 놓고, 숫자키/터치로 바로 쓴다.
--  SetQuickSlot(칸, 아이템 id | ""): 소비("Use" 탭) 아이템만. 같은 아이템이 다른 칸에 있으면 그 칸은 비운다.
--  UseQuickSlot(칸, 바라보는 방향): 투척 무기 → townMonsters.ThrowWeapon(그 방향 직선으로 던져 피해) /
--   방울 → townMonsters.ThrowBell(포획 — 지금은 꺼 둠) / 음식·물약 → 체력 회복.
--  저장: data.QuickSlots = { id1, id2, id3 } (playerSchema v6). 바뀌면 QuickSlotsUpdated로 알린다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local items = require(ReplicatedStorage.shared.data.items)
local persistence = require(script.Parent.Parent.services.persistence)
local inventoryService = require(script.Parent.Parent.services.inventoryService)
local progressionService = require(script.Parent.Parent.services.progressionService)
local townMonsters = require(script.Parent.townMonsters)

local SLOTS = 3

local exports = {}

local function slotsOf(data)
	data.QuickSlots = data.QuickSlots or { "", "", "" }
	return data.QuickSlots
end

function exports.load()
	Net.OnServer("SetQuickSlot", function(player: Player, index: number, itemId: string)
		local data = persistence.Get(player)
		if not data or index ~= math.floor(index) or index < 1 or index > SLOTS then
			return
		end
		local def = items[itemId]
		if itemId ~= "" and (not def or def.Tab ~= "Use") then
			return
		end
		local slots = slotsOf(data)
		for i = 1, SLOTS do
			if itemId ~= "" and slots[i] == itemId then
				slots[i] = ""
			end
		end
		slots[index] = itemId
		persistence.MarkDirty(player)
		Net.FireClient("QuickSlotsUpdated", player, slots)
	end)

	Net.OnServer("UseQuickSlot", function(player: Player, index: number, facing: string)
		local data = persistence.Get(player)
		if not data or index ~= math.floor(index) or index < 1 or index > SLOTS then
			return
		end
		local itemId = slotsOf(data)[index]
		local def = itemId and items[itemId]
		if not def then
			return
		end
		if inventoryService.CountItem(player, itemId) <= 0 then
			Net.FireClient("Notify", player, ("%s이(가) 없어요"):format(def.Name))
			return
		end
		if def.Type == "Throw" then
			townMonsters.ThrowWeapon(player, itemId, facing) -- 「오문 닌자전」 투척 무기(수리검 · 쿠나이 · 폭탄)
		elseif def.Type == "Bell" then
			townMonsters.ThrowBell(player, itemId, facing)
		elseif def.Heal then
			if progressionService.Heal(player, def.Heal) <= 0 then
				Net.FireClient("Notify", player, "체력이 이미 가득해요")
				return
			end
			inventoryService.TakeItem(player, itemId, 1)
		end
	end)
end

function exports.start() end
function exports.unload() end

return exports

end
MODULES['ServerScriptService/server/modules/relevancy'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 관심 영역(relevancy): 서버가 각 클라이언트에게 "같은 씬에 있는 플레이어의 캐릭터"만 복제한다(Ryzom의 Frontend Service가
-- 시야 안의 엔티티만 클라이언트에 보내는 것에 해당 — 여기서는 시야 대신 씬 단위).
--
-- 엔진의 NetworkingService에는 이런 필터가 없어서 엔진 사본(Runtime/Networking.luau)에 RelevancyFilter/ResyncClient 훅을
-- 추가했다. 이 모듈이 그 필터를 등록한다. 다른 플레이어의 캐릭터(클라이언트 소유)는 "소유자의 씬 = 보는 플레이어의 씬"일 때만
-- 전달한다. 씬 이동으로 관심 영역이 바뀌면 travelService가 ResyncClient로 새 씬의 캐릭터를 전체 내용으로 다시 받게 하고,
-- heroTracking.SetPlayerScene이 씬이 갈라진 플레이어들의 캐릭터 사본을 서로의 클라이언트에서 지운다(유령 방지).
-- (몬스터 · 땅의 아이템은 엔진 복제가 아니라 Net 패킷으로 같은 씬 사람에게만 보낸다 — townMonsters · worldDrops.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")

local heroTracking = require(script.Parent.heroTracking)

local exports = {}

function exports.load()
	NetworkingService.RelevancyFilter = function(player: Player, request): boolean
		if request.ClientId ~= 0 then
			-- 클라이언트 소유 오브젝트(플레이어 캐릭터): 소유자와 보는 사람이 같은 씬에 있을 때만 전달한다.
			local ownerScene = heroTracking.GetPlayerScene(request.ClientId)
			local viewer = heroTracking.GetPlayerScene(player.UserId)
			return ownerScene == nil or viewer == nil or ownerScene == viewer
		end

		return true -- 서버가 만든 오브젝트는 거르지 않는다(지금은 없다)
	end
end

function exports.start() end

function exports.unload()
	NetworkingService.RelevancyFilter = nil
end

return exports

end
MODULES['ServerScriptService/server/modules/replication'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 플레이어 캐릭터(hero) 같이 클라이언트가 직접 만든 오브젝트를 다른 플레이어에게 보여주려면 NetworkingService를 거쳐야
-- 한다. 클라이언트가 새 오브젝트를 복제 요청하면(Runtime/Networking.luau의 buildRequests) 서버에서 "ReplicationRequest"가
-- 뜨는데, 요청을 승인(Approve)해야 다른 클라이언트에게 브로드캐스트된다 — 엔진이 자동으로 승인해주지 않는다.
--
-- 이 요청의 내용(request.Content)에는 히어로의 위치가 들어 있다. 서버 몬스터 AI/공격 판정이 그 위치를 알아야 하므로
-- 여기서 읽어 heroTracking에 넘긴다(별도 위치 보고 RemoteEvent 불필요). 위치를 검증해서 거절하지는 않는다 — 엔진 공식
-- 문서가 이동 검증을 비권장한다("aggressive validation can cause lag or false positives", "Rejection should be rare").
--
-- (참고: 공식 문서의 "Accept() + SetAuthority(Client) + characters[player] 추적" 패턴은 서버에 캐릭터 복사본을 만들고
-- 권위를 지정하는 방식이다. 우리는 아직 Approve() 릴레이를 유지한다 — 이 엔진 사본은 첫 요청 이후 권위가 "Server"인
-- 오브젝트의 요청을 걸러내기 때문에, Accept로 바꾸려면 SetAuthority까지 함께 검증해야 해서 다음 단계로 미뤘다.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")
local heroTracking = require(script.Parent.heroTracking)

local exports = {}

function exports.load()
	NetworkingService:On("ReplicationRequest", function(request)
		local content = request.Content
		if content and content.ClassName == "Character" and request.ClientId ~= 0 then
			local instanceData = content.Instance
			local position = instanceData and instanceData.Position
			if typeof(position) == "UDim2" then
				if not heroTracking.OnHeroReplicated(request.ClientId, position, content.ObjectId) then
					return -- 이미 교체된 옛 캐릭터의 늦은 갱신 — 전달하지 않는다.
				end
			end
		end
		request:Approve()
	end)
end

function exports.start() end

function exports.unload() end

return exports

end
MODULES['ServerScriptService/server/modules/shops'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- NPC 가게(사기·팔기) + 소비 아이템 사용 — 서버 권위.
--  사기(ShopBuy): 지금 씬에 그 가게 NPC(shared/config/shops.luau의 npc)가 있고 서버가 아는 발 위치가 가까울 때만.
--    가게가 파는 물건인지, 골드가 충분한지, 가방 자리가 있는지 확인한 뒤 골드를 빼고 아이템을 넣는다.
--  팔기(ShopSell): 같은 NPC 거리 조건(어느 가게든). SellPrice가 있는 아이템만(중요 물품 제외), 개수만큼 빼고 골드를 준다.
--  사용(UseItem): 소비 탭의 Heal 아이템(물약) — 체력이 가득하면 쓰지 않고, 아니면 1개 줄이고 회복(어디서나).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local npcTalk = require(ReplicatedStorage.shared.config.npcTalk)
local shops = require(ReplicatedStorage.shared.config.shops)
local items = require(ReplicatedStorage.shared.data.items)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local persistence = require(script.Parent.Parent.services.persistence)
local inventoryService = require(script.Parent.Parent.services.inventoryService)
local currencyService = require(script.Parent.Parent.services.currencyService)
local progressionService = require(script.Parent.Parent.services.progressionService)
local ninjutsuService = require(script.Parent.ninjutsuService)

local NPC_PAD = 24 -- 대화 거리보다 이만큼(도트) 여유(복제 지연 보정)
local MAX_BUY = 99

local exports = {}

-- 지금 씬에서 그 역할(npcType, nil이면 가게 NPC 아무나) 근처에 있는가
local function nearShopNpc(player: Player, npcType: string?): boolean
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	local d = key and townWorld.Get(key)
	local position = heroTracking.GetPosition(player.UserId)
	if not d or not position then
		return false
	end
	local feet = position / townWorld.data.scale
	for _, n in d.npcs do
		local isShop = false
		for _, shop in shops do
			if shop.npc == n.type then
				isShop = true
			end
		end
		if (if npcType then n.type == npcType else isShop)
			and (Vector2.new(n.x, n.y) - feet).Magnitude <= npcTalk.RANGE + NPC_PAD
		then
			return true
		end
	end
	return false
end

function exports.load()
	Net.OnServer("ShopBuy", function(player: Player, shopId: string, itemId: string, count: number)
		local shop = shops[shopId]
		local def = items[itemId]
		local data = persistence.Get(player)
		if not shop or not def or not def.Price or not data or not table.find(shop.goods, itemId) then
			return
		end
		count = math.clamp(math.floor(count), 1, MAX_BUY)
		if not nearShopNpc(player, shop.npc) then
			return
		end
		local cost = def.Price * count
		if data.Gold < cost then
			Net.FireClient("Notify", player, "골드가 모자라요")
			return
		end
		if inventoryService.RoomFor(player, itemId) < count then
			Net.FireClient("Notify", player, "가방에 자리가 없어요")
			return
		end
		currencyService.AddGold(player, -cost)
		inventoryService.AddItem(player, itemId, count)
	end)

	Net.OnServer("ShopSell", function(player: Player, tab: string, slot: number, count: number)
		if slot ~= math.floor(slot) or not nearShopNpc(player, nil) then
			return
		end
		local data = persistence.Get(player)
		local entry = data and inventoryService.FindEntry(data.Inventory, tab, slot)
		local def = entry and items[entry.ItemId]
		if not def or not def.SellPrice or def.NoDrop then
			return
		end
		local removed = inventoryService.Remove(player, tab, slot, math.clamp(math.floor(count), 1, entry.Count))
		if removed then
			currencyService.AddGold(player, def.SellPrice * removed.Count)
		end
	end)

	Net.OnServer("UseItem", function(player: Player, tab: string, slot: number)
		if slot ~= math.floor(slot) then
			return
		end
		local data = persistence.Get(player)
		local entry = data and inventoryService.FindEntry(data.Inventory, tab, slot)
		local def = entry and items[entry.ItemId]
		if def and def.Type == "Scroll" then
			-- 인술 두루마리: 자기 유파 것이고 올릴 인술이 있을 때만 1개 줄인다
			if ninjutsuService.UseScroll(player, def) then
				inventoryService.Remove(player, tab, slot, 1)
			end
			return
		end
		if not def or not def.Heal then
			return
		end
		if progressionService.Heal(player, def.Heal) <= 0 then
			Net.FireClient("Notify", player, "체력이 이미 가득해요")
			return
		end
		inventoryService.Remove(player, tab, slot, 1)
	end)
end

function exports.start() end
function exports.unload() end

return exports

end
MODULES['ServerScriptService/server/modules/townMonsters'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 탑다운 씬 몬스터(서버 권위, 온라인 공유). 공방 맵의 스폰 구역·직접 놓은 몬스터 그대로 씬마다 서버가 만들고 움직인다.
--  배회: 나타난 자리에서 반경 world.monsterRoam 안을 자유롭게(공방 js/world.js와 같은 규칙), 충돌은 씬 충돌 격자.
--  레벨·체력·경험치·공격력: shared/config/monsterLevels.luau(종마다 레벨 범위, 높을수록 드묾).
--  공격(TownAttack): 클라이언트는 바라보는 방향만 보낸다 — 서버가 아는 발 위치 앞 사각형(combat.ATTACK_REACH/WIDTH)
--  안의 몬스터에게 장비 공격력(inventoryService.GetAttackDamage)만큼 피해. 간격은 balance.TOWN_ATTACK_COOLDOWN으로 검증.
--  기여도(GAME_DESIGN §3): 몬스터마다 플레이어별 넣은 피해(damageBy)를 모은다. 개인 기준, 그 플레이어가 씬을 옮기면 지운다.
--  처치: 기여도 rewards.CONTRIB_MIN(10%) 이상인 사람 모두 경험치 + 도감(봤음) + 전리품(골드·그 몬스터 재료). 미만이면 "기여도 부족" 알림만.
--  포획(M2): 전투 중 단축칸 방울 → ThrowBell — 바라보는 방향 직선으로 날아가 처음 맞은 몬스터에게 시도(BellThrown 연출).
--   자격 = 아무도 안 때렸거나 던진 사람이 딜 1등. 확률 = 레벨·방울 × 체력 비율(capture.Chance). 결과 연출(TownCapture) 뒤
--   성공 = 펫 상자 + 도감 잡았음, 실패 = 도망. 어느 쪽이든 쓰러뜨린 게 아니라 전리품은 없다.
--  반격: 맞은 몬스터는 때린 사람을 쫓아가 공격한다(combat.MONSTER_*). 집에서 너무 멀어지거나, 한동안 안 맞거나,
--   그 사람이 씬을 떠나면 포기하고 돌아간다. 피해는 progressionService.DamagePlayer(사망 페널티·리스폰 포함).
--  combat.MONSTER_RESPAWN초 뒤 같은 구역에 새 레벨로 다시 나타남.
--  인술(N2, server/modules/ninjutsuService.luau): Living · Damage로 같은 규칙의 피해를 주고, 상태 이상은 Slow(느려짐) · Stun(멈춤) ·
--   Push(밀림), 받는 피해 줄이기는 SetGuard. 기본 공격이 맞으면 OnPlayerAttack 훅으로 기력이 찬다.
--  펫 스킬(M4, server/modules/petSkills.luau): OnPlayerAttack 훅으로 공격 직후를 받고, Damage로 같은 규칙(기여도·반격·처치)의 피해를 준다.
-- 같은 씬 플레이어에게만 보낸다(첫 인자 = 씬 키): 위치 10Hz(TownMonsterMoves), 피격/죽음/등장은 즉시.
-- 플레이어가 없는 씬은 움직이지 않는다(서버 부담).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Net = require(ReplicatedStorage.shared.net.net)
local balance = require(ReplicatedStorage.shared.config.balance)
local combat = require(ReplicatedStorage.shared.config.combat)
local monsterLevels = require(ReplicatedStorage.shared.config.monsterLevels)
local pets = require(ReplicatedStorage.shared.config.pets)
local rewards = require(ReplicatedStorage.shared.config.rewards)
local capture = require(ReplicatedStorage.shared.config.capture)
local features = require(ReplicatedStorage.shared.config.features)
local drops = require(ReplicatedStorage.shared.config.drops)
local weapons = require(ReplicatedStorage.shared.config.weapons)
local items = require(ReplicatedStorage.shared.data.items)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local worldDrops = require(script.Parent.worldDrops)
local persistence = require(script.Parent.Parent.services.persistence)
local progressionService = require(script.Parent.Parent.services.progressionService)
local currencyService = require(script.Parent.Parent.services.currencyService)
local inventoryService = require(script.Parent.Parent.services.inventoryService)

local world = townWorld.data
local FEET = world.monsterFeet
local SPEED = world.monsterSpeed
local ROAM = world.monsterRoam or 96
local WAIT = world.monsterWait or { 0.6, 2.2 }
local SEND_INTERVAL = 0.1

local exports = {}

local scenes = {} -- 씬 키 -> { d, monsters = { [id] = m } }
local nextId = 0
local rng = Random.new()
local lastAttackAt = {}

local function toScene(key: string, name: string, ...)
	for _, player in heroTracking.PlayersInScene(townWorld.SceneName(key)) do
		Net.FireClient(name, player, key, ...)
	end
end

local function blocked(d, x: number, y: number): boolean
	return townWorld.BoxBlocked(d, x, y, FEET.halfW, FEET.h)
end

local function randomIn(d, z): Vector2?
	for _ = 1, 40 do
		local x, y = rng:NextNumber(z.x0, z.x1), rng:NextNumber(z.y0, z.y1)
		if not blocked(d, x, y) then
			return Vector2.new(x, y)
		end
	end
	return nil
end

local function rollLevel(m)
	m.level = monsterLevels.RollLevel(m.row, rng) -- 종의 레벨 범위 안에서, 높은 레벨일수록 드물게
	m.maxHp = monsterLevels.MaxHealth(m.level)
	m.hp = m.maxHp
	m.damageBy = {} -- [userId] = { dmg = 넣은 피해, first = 처음 때린 시각 }
	m.aggro = nil -- 쫓는 플레이어 userId
	m.shiny = rng:NextNumber() < pets.SHINY_CHANCE -- 이로치(색만 다름) — 잡으면 펫에 저장
	m.stunUntil, m.slowUntil, m.slowMult = nil, nil, nil -- 인술 상태 이상(멈춤 · 느려짐)
end

-- 몬스터가 플레이어를 때릴 때 피해를 고치는 함수들: fn(player, 씬 키, 몬스터, 피해) → 피해(얼음 갑옷 · 견고 — ninjutsuService)
local hurtHooks = {}
-- 기본 공격 간격 배율을 주는 함수들: fn(player) → 배율(전하 — ninjutsuService)
local speedHooks = {}
-- 받는 피해 줄이기(인술 "바위 갑옷" 등): [userId] = { mult, untilT }
local guards = {}
local function guardMult(userId: number, now: number): number
	local g = guards[userId]
	return if g and now < g.untilT then g.mult else 1
end

-- 지금 이 몬스터의 이동 속도 배율(느려짐)
local function speedMult(m, now: number): number
	return if m.slowUntil and now < m.slowUntil then m.slowMult else 1
end

local function wire(m)
	return { id = m.id, row = m.row, level = m.level, hp = m.hp, maxHp = m.maxHp, x = m.x, y = m.y, shiny = m.shiny }
end

local function add(st, row: number, pos: Vector2, zone)
	nextId += 1
	local m = {
		id = nextId, row = row, zone = zone, home = pos, x = pos.X, y = pos.Y,
		target = nil, wait = rng:NextNumber(0, WAIT[2]), facingLeft = rng:NextNumber() < 0.5, moving = false, dirty = true, dead = false,
	}
	rollLevel(m)
	st.monsters[m.id] = m
end

local function buildScene(key: string, d)
	local st = { d = d, monsters = {}, sendClock = 0 }
	for _, m in d.mons do
		add(st, m.species, Vector2.new(m.x, m.y), nil)
	end
	for _, z in d.zones do
		local pool = z.species
		if #pool == 0 then
			pool = {}
			for i = 1, #world.species do
				table.insert(pool, i)
			end
		end
		for _ = 1, z.count do
			local pos = randomIn(d, z)
			if pos then
				add(st, pool[rng:NextInteger(1, #pool)], pos, z)
			end
		end
	end
	scenes[key] = st
end

local function pickTarget(d, m): Vector2?
	for _ = 1, 8 do
		local ang = rng:NextNumber(0, math.pi * 2)
		local r = ROAM * math.sqrt(rng:NextNumber())
		local tx, ty = m.home.X + math.cos(ang) * r, m.home.Y + math.sin(ang) * r
		if not blocked(d, tx, ty) then
			return Vector2.new(tx, ty)
		end
	end
	return nil
end

-- 쫓기·공격(맞은 몬스터). 계속 쫓으면 true, 포기했으면 false(평소 배회로 돌아감).
local function chase(key: string, st, m, dt: number): boolean
	local player = Players:GetPlayerByUserId(m.aggro)
	local position = player and heroTracking.GetPosition(m.aggro)
	local here = player and townWorld.KeyOf(heroTracking.GetPlayerScene(m.aggro)) == key
	local now = os.clock()
	local homeDist = (Vector2.new(m.x, m.y) - m.home).Magnitude
	if not here or not position or now > m.aggroUntil or homeDist > combat.MONSTER_LEASH then
		m.aggro = nil
		m.target = m.home -- 집으로 돌아간다
		return false
	end
	local feet = position / world.scale
	local dx, dy = feet.X - m.x, feet.Y - m.y
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist > combat.MONSTER_ATTACK_RANGE * 0.7 then
		local s = math.min(dist - combat.MONSTER_ATTACK_RANGE * 0.6, SPEED * combat.MONSTER_CHASE_SPEED * speedMult(m, now) * dt)
		local nx, ny = m.x + dx / dist * s, m.y + dy / dist * s
		if not blocked(st.d, nx, ny) then
			m.x, m.y = nx, ny
			m.moving = true
		end
	end
	m.facingLeft = dx < 0
	if dist <= combat.MONSTER_ATTACK_RANGE and now >= (m.nextAttack or 0) then
		m.nextAttack = now + combat.MONSTER_ATTACK_COOLDOWN
		toScene(key, "TownMonsterAttack", m.id)
		local damage = math.max(monsterLevels.AttackDamage(m.level) - inventoryService.GetDefense(player), 1)
		damage *= guardMult(m.aggro, now)
		for _, fn in hurtHooks do
			damage = fn(player, key, m, damage)
		end
		if damage > 0 then -- 0 이하 = 완전히 막음(되받아치기)
			progressionService.DamagePlayer(player, math.max(1, math.round(damage)))
		end
	end
	return true
end

local function step(key: string, st, dt: number)
	local d = st.d
	local now = os.clock()
	for _, m in st.monsters do
		if m.dead or m.capturing then
			continue
		end
		local wasMoving = m.moving
		m.moving = false
		if m.stunUntil and now < m.stunUntil then
			-- 멈춤(얼음 · 덩굴): 움직이지도 때리지도 못한다
			if wasMoving then
				m.dirty = true
			end
			continue
		end
		if m.aggro and chase(key, st, m, dt) then
			if m.moving or wasMoving then
				m.dirty = true
			end
			continue
		end
		if m.target then
			local dx, dy = m.target.X - m.x, m.target.Y - m.y
			local dist = math.sqrt(dx * dx + dy * dy)
			if dist < 1 then
				m.target = nil
				m.wait = rng:NextNumber(WAIT[1], WAIT[2])
			else
				local s = math.min(dist, SPEED * speedMult(m, now) * dt)
				local nx, ny = m.x + dx / dist * s, m.y + dy / dist * s
				if blocked(d, nx, ny) then
					m.target = nil
					m.wait = rng:NextNumber(0.3, 1)
				else
					m.x, m.y = nx, ny
					m.facingLeft = dx < 0
					m.moving = true
				end
			end
		else
			m.wait -= dt
			if m.wait <= 0 then
				m.target = pickTarget(d, m)
				if not m.target then
					m.wait = rng:NextNumber(0.5, 1.5)
				end
			end
		end
		if m.moving or wasMoving then
			m.dirty = true
		end
	end
end

local function broadcastMoves(key: string, st)
	local list = {}
	for _, m in st.monsters do
		if m.dirty and not m.dead then
			m.dirty = false
			table.insert(list, { m.id, math.round(m.x * 10) / 10, math.round(m.y * 10) / 10, m.facingLeft, m.moving })
		end
	end
	if #list > 0 then
		toScene(key, "TownMonsterMoves", list)
	end
end

-- 처치 보상(기여도 10% 이상인 사람 모두, GAME_DESIGN §3): 기본(경험치 + 도감 봤음) + 전리품(골드 + 그 몬스터 재료).
-- 그냥 사냥해서 쓰러뜨리는 것이 곧 "재료 받기"다. 포획은 전투 중 방울 던지기(아래 ThrowBell)로 따로 한다.
local killHooks = {}
local function rewardBase(player: Player, m)
	progressionService.AddExperience(player, monsterLevels.Experience(m.level))
	local species = world.species[m.row]
	if species then
		for _, fn in killHooks do
			fn(player, species.id)
		end
	end
	local data = persistence.Get(player)
	if data and species then
		data.Dex = data.Dex or {}
		if not data.Dex[species.id] then
			data.Dex[species.id] = pets.DEX_SEEN -- 봤음
			persistence.MarkDirty(player)
			Net.FireClient("DexDiscovered", player, m.row)
		end
	end
end

local function rewardLoot(player: Player, m)
	currencyService.AddGold(player, rewards.Gold(m.level, rng))
	local species = world.species[m.row]
	-- 그 몬스터가 사는 지역의 드롭 표(shared/config/drops.luau)
	for _, d in drops.Roll(species and species.element, rng) do
		inventoryService.AddItem(player, d.item, d.count)
	end
end

-- 지금 딜 1등(넣은 피해가 가장 많은 사람, 동점이면 먼저 때린 사람)의 userId — 아무도 안 때렸으면 nil
local function topDealer(m): number?
	local best, bestDmg, bestFirst = nil, -1, math.huge
	for userId, e in m.damageBy do
		if e.dmg > bestDmg or (e.dmg == bestDmg and e.first < bestFirst) then
			best, bestDmg, bestFirst = userId, e.dmg, e.first
		end
	end
	return best
end

-- 기여도 정산: 10% 이상은 보상, 미만은 알림만(개인 기준).
local function settle(m)
	for userId, e in m.damageBy do
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			continue
		end
		local share = e.dmg / m.maxHp
		if share >= rewards.CONTRIB_MIN then
			rewardBase(player, m)
			rewardLoot(player, m)
		else
			Net.FireClient("Notify", player, ("기여도 %d%% · 10%% 이상 때려야 보상을 받아요"):format(math.floor(share * 100)))
		end
	end
end

local function respawnLater(key: string, st, m)
	task.delay(combat.MONSTER_RESPAWN, function()
		if scenes[key] ~= st then
			return
		end
		local pos = if m.zone then randomIn(st.d, m.zone) else m.home
		pos = pos or m.home
		m.x, m.y, m.home = pos.X, pos.Y, pos
		rollLevel(m)
		m.dead = false
		m.capturing = false
		m.dirty = true
		m.wait = rng:NextNumber(0.5, WAIT[2])
		toScene(key, "TownMonsterSpawned", wire(m))
	end)
end

-- ---- 포획(M2, shared/config/capture.luau) — 전투 중 방울 던지기 ----
local lastThrowAt = {}
local DIRS = { up = Vector2.new(0, -1), down = Vector2.new(0, 1), left = Vector2.new(-1, 0), right = Vector2.new(1, 0) }

local function boxFull(player: Player): boolean
	local data = persistence.Get(player)
	local p = data and data.Pets
	return not p or #p.Box >= pets.Capacity(p.Boxes)
end

local function kill(key: string, st, m)
	m.dead = true
	m.target = nil
	m.aggro = nil
	toScene(key, "TownMonsterDied", m.id)
	settle(m)
	respawnLater(key, st, m)
end

-- 맞은 몬스터에게 포획 시도. 결과는 바로 굴리고, 연출(룬 문양 원 + 딸랑 3번) 시간 뒤에 적용한다.
local function tryCapture(key: string, st, m, player: Player, tier: number)
	local top = topDealer(m)
	if (top and top ~= player.UserId) or boxFull(player) then
		-- 다른 사람이 더 많이 싸우던 몬스터(또는 상자가 가득) — 방울이 튕겨 나간다
		toScene(key, "TownCapture", m.id, tier, "blocked")
		Net.FireClient("Notify", player, if top and top ~= player.UserId then "다른 사람이 먼저 싸우던 몬스터예요" else "몬스터 상자가 가득 찼어요")
		return
	end
	local species = world.species[m.row]
	local dings, success = capture.RollShakes(capture.Chance(m.level, tier, m.hp / m.maxHp, false, false), rng)
	m.capturing = true -- 연출 동안 멈추고, 맞지도 않는다
	m.target = nil
	m.aggro = nil
	toScene(key, "TownCapture", m.id, tier, if success then "success" else "fail", dings)
	task.delay(capture.RevealTime(dings), function()
		m.capturing = false
		m.dead = true -- 잡혔거나 도망감(쓰러뜨린 게 아니라 전리품은 없다)
		if success and player.Parent then
			local data = persistence.Get(player)
			if data and species then
				table.insert(data.Pets.Box, { S = species.id, L = m.level, C = if m.shiny then 1 else 0, B = tier, T = os.time() })
				-- 함께 다니는 칸이 비어 있으면 바로 넣는다
				if #data.Pets.Party < pets.SlotCount(data.Level, data.Pets.Paid) then
					table.insert(data.Pets.Party, #data.Pets.Box)
				end
				Net.FireClient("PetsUpdated", player, data.Pets)
				local first = data.Dex[species.id] ~= pets.DEX_CAUGHT
				data.Dex[species.id] = pets.DEX_CAUGHT
				persistence.MarkDirty(player)
				task.spawn(persistence.Save, player, false) -- 잡은 몬스터는 잃으면 가장 아프다 — 바로 저장
				Net.FireClient("Notify", player, ("%s%s(Lv.%d)와(과) 맺어졌어요!"):format(if m.shiny then "★이로치★ " else "", species.name, m.level))
				if first then
					Net.FireClient("DexDiscovered", player, m.row)
				end
			end
		elseif player.Parent then
			Net.FireClient("Notify", player, ("맺기 실패… %s이(가) 도망갔어요"):format(species and species.name or "몬스터"))
		end
		respawnLater(key, st, m)
	end)
end

-- 방울 던지기(단축칸 사용 — server/modules/quickSlots.luau가 부른다). 방울 1개를 먼저 쓰고, 바라보는 방향으로 직선
-- THROW_RANGE까지 날아가 처음 맞은 몬스터에게 포획 시도. 같은 씬 모두에게 날아가는 연출(BellThrown).
function exports.ThrowBell(player: Player, itemId: string, facing: string): boolean
	local def = items[itemId]
	if not features.CAPTURE or not def or def.Type ~= "Bell" then
		return false -- 포획은 지금 꺼 둠(shared/config/features.luau)
	end
	local now = os.clock()
	if lastThrowAt[player.UserId] and now - lastThrowAt[player.UserId] < capture.THROW_COOLDOWN then
		return false
	end
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	local st = key and scenes[key]
	local position = heroTracking.GetPosition(player.UserId)
	local dir = DIRS[facing]
	if not st or not position or not dir then
		return false
	end
	if not inventoryService.TakeItem(player, itemId, 1) then
		return false
	end
	lastThrowAt[player.UserId] = now
	-- 손 높이(발보다 조금 위)에서 출발
	local origin = position / world.scale - Vector2.new(0, 8)
	local hit, hitT = nil, capture.THROW_RANGE
	for _, m in st.monsters do
		if m.dead or m.capturing then
			continue
		end
		local rel = Vector2.new(m.x, m.y - 6) - origin -- 몬스터 몸 가운데쯤
		local t = rel:Dot(dir)
		local side = math.abs(rel.X * dir.Y - rel.Y * dir.X)
		if t >= 0 and t <= hitT and side <= capture.THROW_WIDTH then
			hit, hitT = m, t
		end
	end
	toScene(key, "BellThrown", player.UserId, origin.X, origin.Y, dir.X, dir.Y, hitT, def.Tier, if hit then hit.id else 0)
	if hit then
		task.delay(hitT / capture.THROW_SPEED, function()
			if scenes[key] == st and not hit.dead and not hit.capturing and player.Parent then
				tryCapture(key, st, hit, player, def.Tier)
			end
		end)
	end
	return true
end

-- 피해 주기(플레이어 공격 · 펫 스킬 공용): 기여도(실제로 깎은 체력만) · 반격 · 피격 알림 · 처치까지.
-- source = 맞은 몬스터 위 연출 구분(무기 id → 베기 VFX, "pet:<종 id>" → 펫 스킬 맞음 이펙트)
local function dealDamage(key: string, st, m, player: Player, amount: number, now: number, source: string)
	local dealt = math.min(m.hp, amount) -- 마지막 한 방이 넘쳐도 기여도는 최대 체력까지
	m.hp -= dealt
	local e = m.damageBy[player.UserId]
	if not e then
		e = { dmg = 0, first = now }
		m.damageBy[player.UserId] = e
	end
	e.dmg += dealt
	m.target = nil
	m.wait = 0.6
	-- 반격: 쫓는 사람이 없으면 이 사람을 쫓고, 맞을 때마다 포기 시간을 늘린다
	if not m.aggro then
		m.aggro = player.UserId
		m.nextAttack = now + 0.5
	end
	m.aggroUntil = now + combat.MONSTER_AGGRO_TIME
	toScene(key, "TownMonsterHit", m.id, m.hp, amount, player.UserId, source)
	if m.hp <= 0 then
		kill(key, st, m)
	end
end

-- 처치 보상을 받은 사람마다 부를 함수 등록: fn(player, 몬스터 종 id) — 퀘스트 처치 수(questService)
function exports.OnKill(fn)
	table.insert(killHooks, fn)
end

function exports.OnPlayerHurt(fn)
	table.insert(hurtHooks, fn)
end

function exports.OnAttackSpeed(fn)
	table.insert(speedHooks, fn)
end

local attackHooks = {}

-- 공격 직후 부를 함수 등록: fn(player, 씬 키, 발 위치(도트 Vector2), 바라보는 방향, 이번에 맞은 몬스터 id 목록)
function exports.OnPlayerAttack(fn)
	table.insert(attackHooks, fn)
end

-- 이 씬의 살아 있는(맞을 수 있는) 몬스터 목록 { m } — 읽기만 할 것(id, x, y)
function exports.Living(key: string)
	local st = scenes[key]
	local list = {}
	if st then
		for _, m in st.monsters do
			if not m.dead and not m.capturing then
				table.insert(list, m)
			end
		end
	end
	return list
end

-- 펫 스킬 피해: 그 플레이어가 아직 그 씬에 있고 몬스터가 살아 있을 때만. 준 피해만큼 그 플레이어 기여도.
function exports.Damage(key: string, monsterId: number, player: Player, amount: number, source: string): boolean
	local st = scenes[key]
	local m = st and st.monsters[monsterId]
	if not m or m.dead or m.capturing or not player.Parent then
		return false
	end
	if townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId)) ~= key then
		return false
	end
	dealDamage(key, st, m, player, amount, os.clock(), source)
	return true
end

-- ---- 인술 상태 이상(server/modules/ninjutsuService.luau가 부른다) — 같은 씬 모두에게 TownMonsterStatus(연출용) ----
local function statusTarget(key: string, monsterId: number)
	local st = scenes[key]
	local m = st and st.monsters[monsterId]
	return if m and not m.dead and not m.capturing then m else nil
end

-- 느려짐: seconds초 동안 이동 속도 × mult(이미 더 느린 상태면 시간만 늘린다)
function exports.Slow(key: string, monsterId: number, mult: number, seconds: number): boolean
	local m = statusTarget(key, monsterId)
	if not m then
		return false
	end
	local now = os.clock()
	m.slowMult = if m.slowUntil and now < m.slowUntil then math.min(m.slowMult, mult) else mult
	m.slowUntil = math.max(m.slowUntil or 0, now + seconds)
	toScene(key, "TownMonsterStatus", monsterId, "slow", seconds)
	return true
end

-- 멈춤: seconds초 동안 움직이지도 때리지도 못한다
function exports.Stun(key: string, monsterId: number, seconds: number): boolean
	local m = statusTarget(key, monsterId)
	if not m then
		return false
	end
	m.stunUntil = math.max(m.stunUntil or 0, os.clock() + seconds)
	m.target = nil
	m.dirty = true
	toScene(key, "TownMonsterStatus", monsterId, "stun", seconds)
	return true
end

-- 밀쳐 내기: (dx, dy)도트만큼 — 막힌 곳 앞에서 멈춘다
function exports.Push(key: string, monsterId: number, dx: number, dy: number): boolean
	local m = statusTarget(key, monsterId)
	if not m then
		return false
	end
	local d = scenes[key].d
	local steps = math.max(1, math.ceil(math.max(math.abs(dx), math.abs(dy)) / 2))
	for _ = 1, steps do
		local nx, ny = m.x + dx / steps, m.y + dy / steps
		if blocked(d, nx, ny) then
			break
		end
		m.x, m.y = nx, ny
	end
	m.target = nil
	m.dirty = true
	return true
end

-- 받는 피해 줄이기: seconds초 동안 몬스터에게 받는 피해 × mult
function exports.SetGuard(player: Player, mult: number, seconds: number)
	guards[player.UserId] = { mult = mult, untilT = os.clock() + seconds }
end

-- 투척 무기(단축칸 사용 — server/modules/quickSlots.luau가 부른다). 1개를 먼저 쓰고, 바라보는 방향으로 직선으로 날아가
-- 처음 닿은 몬스터에게 공격력 × power 피해. radius가 있으면(폭탄) 닿은 자리 — 안 닿으면 끝까지 간 자리 — 둘레 모두에게.
function exports.ThrowWeapon(player: Player, itemId: string, facing: string): boolean
	local def = items[itemId]
	local t = def and def.Throw
	if not t then
		return false
	end
	local now = os.clock()
	if lastThrowAt[player.UserId] and now - lastThrowAt[player.UserId] < combat.THROW_COOLDOWN then
		return false
	end
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	local st = key and scenes[key]
	local position = heroTracking.GetPosition(player.UserId)
	local dir = DIRS[facing]
	if not st or not position or not dir then
		return false
	end
	if not inventoryService.TakeItem(player, itemId, 1) then
		return false
	end
	lastThrowAt[player.UserId] = now
	local origin = position / world.scale - Vector2.new(0, 7) -- 손 높이
	local hit, hitT = nil, t.range
	for _, m in st.monsters do
		if m.dead or m.capturing then
			continue
		end
		local rel = Vector2.new(m.x, m.y - 6) - origin -- 몬스터 몸 가운데쯤
		local along = rel:Dot(dir)
		local side = math.abs(rel.X * dir.Y - rel.Y * dir.X)
		if along >= 0 and along <= hitT and side <= t.width + 3 then
			hit, hitT = m, along
		end
	end
	toScene(key, "ProjectileThrown", player.UserId, itemId, origin.X, origin.Y, dir.X, dir.Y, hitT, t.speed, t.radius or 0)
	local damage = math.max(1, math.round(inventoryService.GetAttackDamage(player) * t.power))
	task.delay(hitT / t.speed, function()
		if scenes[key] ~= st or not player.Parent then
			return
		end
		if t.radius then
			local at = origin + dir * hitT + Vector2.new(0, 6) -- 발 높이로 내려서 잰다
			for _, m in st.monsters do
				if not m.dead and not m.capturing and (Vector2.new(m.x, m.y) - at).Magnitude <= t.radius then
					dealDamage(key, st, m, player, damage, os.clock(), itemId)
				end
			end
		elseif hit and not hit.dead and not hit.capturing then
			dealDamage(key, st, hit, player, damage, os.clock(), itemId)
		end
	end)
	return true
end

-- 바라보는 방향 앞 사각형(발 기준) — 닿는 거리·폭은 무기 종류마다(shared/config/weapons.luau)
local function attackBox(x: number, y: number, facing: string, reach: number, width: number)
	local half = width / 2
	if facing == "left" then
		return x - reach, y - half, x, y + half
	elseif facing == "right" then
		return x, y - half, x + reach, y + half
	elseif facing == "up" then
		return x - half, y - reach, x + half, y
	end
	return x - half, y, x + half, y + reach
end

function exports.load()
	for key, d in world.scenes do
		buildScene(key, d)
	end

	Net.OnServer("GetTownState", function(player: Player)
		local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
		local st = key and scenes[key]
		if not st then
			return nil
		end
		local list = {}
		for _, m in st.monsters do
			if not m.dead then
				table.insert(list, wire(m))
			end
		end
		return { scene = key, monsters = list, drops = worldDrops.List(key) }
	end)

	Net.OnServer("TownAttack", function(player: Player, facing: string)
		local now = os.clock()
		local last = lastAttackAt[player.UserId]
		local data = persistence.Get(player)
		local weaponId = data and data.Equipment and data.Equipment.Weapon or "" -- 맞은 몬스터 위 베기 VFX를 무기에 맞게
		local class = weapons.ClassOf(items[weaponId]) -- 무기 종류마다 빠르기 · 범위 · 세기가 다르다
		local speed = class.speed
		for _, fn in speedHooks do
			speed *= fn(player)
		end
		if last and now - last < balance.TOWN_ATTACK_COOLDOWN * speed then
			return
		end
		local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
		local st = key and scenes[key]
		local position = heroTracking.GetPosition(player.UserId)
		if not st or not position then
			return
		end
		lastAttackAt[player.UserId] = now
		local feet = position / world.scale
		local x0, y0, x1, y1 = attackBox(feet.X, feet.Y, facing, class.reach, class.width)
		local damage = math.max(1, math.round(inventoryService.GetAttackDamage(player) * class.power))
		local hitIds = {}
		for _, m in st.monsters do
			if not m.dead and not m.capturing and m.x >= x0 and m.x <= x1 and m.y >= y0 and m.y <= y1 then
				table.insert(hitIds, m.id)
				dealDamage(key, st, m, player, damage, now, weaponId)
			end
		end
		-- 펫 스킬 등(공격 1번마다 발동 판정 — 헛손질이어도)
		for _, fn in attackHooks do
			task.spawn(fn, player, key, feet, facing, hitIds)
		end
	end)

	-- 씬을 옮기거나 나가면 그 씬 몬스터에 쌓인 그 사람의 기여도를 지우고, 쫓던 몬스터는 포기한다
	local function forget(userId: number, sceneName: string?)
		local key = townWorld.KeyOf(sceneName)
		local st = key and scenes[key]
		if not st then
			return
		end
		for _, m in st.monsters do
			m.damageBy[userId] = nil
			if m.aggro == userId then
				m.aggro = nil
				m.target = m.home
			end
		end
	end
	heroTracking.OnSceneChanged(function(userId, previous)
		forget(userId, previous)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAttackAt[player.UserId] = nil
		lastThrowAt[player.UserId] = nil
		guards[player.UserId] = nil
		forget(player.UserId, heroTracking.GetPlayerScene(player.UserId))
	end)

	exports.connection = RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 0.1)
		for key, st in scenes do
			if #heroTracking.PlayersInScene(townWorld.SceneName(key)) == 0 then
				continue
			end
			step(key, st, dt)
			st.sendClock += dt
			if st.sendClock >= SEND_INTERVAL then
				st.sendClock = 0
				broadcastMoves(key, st)
			end
		end
	end)
end

function exports.start() end

function exports.unload()
	if exports.connection then
		exports.connection:Disconnect()
		exports.connection = nil
	end
end

return exports

end
MODULES['ServerScriptService/server/modules/townRewards'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 탑다운 씬(공방에서 만든 씬) 치료사 회복(RequestHeal): 지금 씬에 치료사 NPC가 있고 서버가 아는 플레이어 발 위치가
-- 그 근처일 때만 체력을 가득 채운다. (몬스터 처치 경험치는 서버 권위 몬스터 townMonsters.luau가 직접 준다.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local balance = require(ReplicatedStorage.shared.config.balance)
local npcTalk = require(ReplicatedStorage.shared.config.npcTalk)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local persistence = require(script.Parent.Parent.services.persistence)

local HEAL_PAD = 24 -- 대화 거리보다 이만큼(도트) 여유(복제 지연 보정)

local exports = {}

local function currentTownScene(player: Player)
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	return key and townWorld.Get(key)
end

function exports.load()
	Net.OnServer("RequestHeal", function(player: Player)
		local d = currentTownScene(player)
		local position = heroTracking.GetPosition(player.UserId)
		local data = persistence.Get(player)
		if not d or not position or not data then
			return
		end
		local feet = position / townWorld.data.scale
		for _, n in d.npcs do
			if n.type == "healer" and (Vector2.new(n.x, n.y) - feet).Magnitude <= npcTalk.RANGE + HEAL_PAD then
				local maxHealth = balance.maxHealthFor(data.Level)
				data.Health = maxHealth
				persistence.MarkDirty(player)
				Net.FireClient("PlayerHealthChanged", player, maxHealth, maxHealth, 0, false)
				return
			end
		end
	end)
end

function exports.start() end
function exports.unload() end

return exports

end
MODULES['ServerScriptService/server/modules/travelService'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 씬 이동(포탈) 승인 서비스. 플레이어가 어느 씬에 있는지의 진실은 서버(heroTracking)가 갖는다 — 클라이언트가 제멋대로
-- 씬을 바꿔도 서버의 씬 정보는 그대로라서 몬스터 어그로/공격/드롭 등 서버 로직에는 영향이 없고, 정상적인 이동은 이 서비스의
-- 승인을 거쳐야 한다. 검증: (1) 지금 씬에 그 목적지로 가는 포탈(townWorld 씬 데이터의 portals)이 있는가 (2) 서버가 아는
-- 플레이어 발 위치가 그 포탈 칸 근처인가. 통과하면 서버 씬을 바꾸고 TravelApproved를 보내 클라이언트가 실제 씬 전환을 하게 한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)

local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")

-- 탑다운 씬 포탈 판정 여유(도트): 발이 포탈 칸에서 이만큼 벗어나 있어도 인정(복제 지연 보정).
local TOWN_PORTAL_PAD = 12

-- 탑다운 씬(공방에서 만든 씬) 사이 이동 검증: 지금 씬에 목적지로 가는 포탈이 있고, 서버가 아는 발 위치가 그 포탈 칸 근처인가.
-- 서버가 아는 위치는 캐릭터 Position(화면 px = 도트 × scale, 발 기준)이다.
local function townTravelAllowed(currentScene: string, destination: string, position: Vector2): boolean
	local fromKey = townWorld.KeyOf(currentScene)
	local toKey = townWorld.KeyOf(destination)
	if not fromKey or not toKey then
		return false
	end
	local scale = townWorld.data.scale
	local x, y = position.X / scale, position.Y / scale
	for _, p in townWorld.Get(fromKey).portals do
		if p.to == toKey
			and x > p.x0 - TOWN_PORTAL_PAD and x < p.x1 + TOWN_PORTAL_PAD
			and y > p.y0 - TOWN_PORTAL_PAD and y < p.y1 + TOWN_PORTAL_PAD
		then
			return true
		end
	end
	return false
end

local exports = {}

function exports.load()
	Net.OnServer("RequestTravel", function(player: Player, destination)
		local currentScene = heroTracking.GetPlayerScene(player.UserId)
		local position = heroTracking.GetPosition(player.UserId)
		if not currentScene or not position or currentScene == destination then
			return
		end

		if not townTravelAllowed(currentScene, destination, position) then
			return
		end
		heroTracking.SetPlayerScene(player.UserId, destination)
		NetworkingService:ResyncClient(player) -- 관심 영역이 바뀌었으니(relevancy.luau) 새 씬의 다른 플레이어를 전체 내용으로 다시 받게 한다
		Net.FireClient("TravelApproved", player, destination)
	end)
end

function exports.start() end
function exports.unload() end

return exports

end
MODULES['ServerScriptService/server/modules/upgradeService'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 무기 강화(서버) — 「오문 닌자전」 NINJA_DESIGN.md §7. 수치는 shared/config/weapons.luau(MAX_PLUS · BONUS · RATE · BARS · Cost).
--  UpgradeWeapon(칸): 0 = 지금 착용한 무기, 1 이상 = 가방 장비 탭의 그 칸. 대장간 NPC(weapons.UPGRADE_NPC) 곁에서만.
--   재료(주괴 × 목표 단계)와 엽전을 먼저 쓰고 확률을 굴린다 — 성공하면 +1, 실패하면 단계 그대로(깨지지 않는다).
--   강화 단계는 아이템마다 따로: 가방 칸의 Plus, 착용 중이면 data.EquipmentPlus[칸 이름](inventoryService가 착용·해제 때 옮긴다).
--   결과는 UpgradeResult(성공 여부, 아이템 id, 지금 단계) + 알림. 가방·장비 갱신은 InventoryUpdated · EquipmentUpdated.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local npcTalk = require(ReplicatedStorage.shared.config.npcTalk)
local weapons = require(ReplicatedStorage.shared.config.weapons)
local items = require(ReplicatedStorage.shared.data.items)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local persistence = require(script.Parent.Parent.services.persistence)
local inventoryService = require(script.Parent.Parent.services.inventoryService)
local currencyService = require(script.Parent.Parent.services.currencyService)

local NPC_PAD = 24 -- 대화 거리보다 이만큼(도트) 여유(복제 지연 보정)

local exports = {}
local rng = Random.new()

local function nearNpc(player: Player, npcType: string): boolean
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	local d = key and townWorld.Get(key)
	local position = heroTracking.GetPosition(player.UserId)
	if not d or not position then
		return false
	end
	local feet = position / townWorld.data.scale
	for _, n in d.npcs do
		if n.type == npcType and (Vector2.new(n.x, n.y) - feet).Magnitude <= npcTalk.RANGE + NPC_PAD then
			return true
		end
	end
	return false
end

-- 강화 시도. 돌려주는 값: "success" | "fail" | nil(조건이 안 맞아 아무 일도 없음)
function exports.Upgrade(player: Player, slot: number): string?
	local data = persistence.Get(player)
	if not data or slot ~= math.floor(slot) or slot < 0 then
		return nil
	end
	if not nearNpc(player, weapons.UPGRADE_NPC) then
		Net.FireClient("Notify", player, "강화는 대장간에서 할 수 있어요")
		return nil
	end
	data.EquipmentPlus = data.EquipmentPlus or {}
	local entry = if slot > 0 then inventoryService.FindEntry(data.Inventory, "Equip", slot) else nil
	local itemId = if slot > 0 then entry and entry.ItemId else data.Equipment.Weapon
	local def = itemId and items[itemId]
	if not def or def.Type ~= "Weapon" then
		return nil
	end
	local plus = (if slot > 0 then entry.Plus else data.EquipmentPlus.Weapon) or 0
	local cost = weapons.Cost(def, plus + 1)
	if not cost then
		Net.FireClient("Notify", player, "이미 최고 단계예요")
		return nil
	end
	if inventoryService.CountItem(player, cost.bar) < cost.bars then
		Net.FireClient("Notify", player, ("%s이(가) 모자라요(%d개 필요)"):format(items[cost.bar].Name, cost.bars))
		return nil
	end
	if (data.Gold or 0) < cost.gold then
		Net.FireClient("Notify", player, ("엽전이 모자라요(%d 필요)"):format(cost.gold))
		return nil
	end
	inventoryService.TakeItem(player, cost.bar, cost.bars)
	currencyService.AddGold(player, -cost.gold)
	local success = rng:NextNumber() < cost.rate
	if success then
		plus += 1
		if slot > 0 then
			entry.Plus = plus
		else
			data.EquipmentPlus.Weapon = plus
		end
	end
	persistence.MarkDirty(player)
	task.spawn(persistence.Save, player, false) -- 재료를 썼으니 바로 저장
	inventoryService.Refresh(player)
	Net.FireClient("UpgradeResult", player, success, itemId, plus)
	Net.FireClient("Notify", player, if success
		then ("강화 성공! %s +%d"):format(def.Name, plus)
		else ("강화 실패… %s은(는) +%d 그대로예요"):format(def.Name, plus))
	return if success then "success" else "fail"
end

function exports.load()
	Net.OnServer("UpgradeWeapon", function(player: Player, slot: number)
		exports.Upgrade(player, slot)
	end)
end

function exports.start() end
function exports.unload() end

return exports

end
MODULES['ServerScriptService/server/modules/worldDrops'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 월드 드랍(땅에 떨어진 아이템) — 서버가 소유하고 같은 씬의 모든 플레이어에게 보여준다(온라인 공유).
--  버리기(DropItem): 가방에서 꺼내(inventoryService.Take) 그 플레이어 발밑에 떨어뜨린다. 중요 물품은 못 버린다.
--  줍기(PickupDrop): 같은 씬 + 서버가 아는 발 위치가 가까울 때만. 먼저 주운 사람이 가져간다. 가방이 모자라면 들어간 만큼만.
--  수명: balance.WORLD_DROP_LIFETIME초가 지나면 사라진다.
-- 클라이언트에는 씬 키를 붙여 보낸다(WorldDropSpawned / WorldDropRemoved) — 목록은 townMonsters의 GetTownState가 같이 준다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local balance = require(ReplicatedStorage.shared.config.balance)
local items = require(ReplicatedStorage.shared.data.items)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local inventoryService = require(script.Parent.Parent.services.inventoryService)

local exports = {}

local drops = {} -- 씬 키 -> { [id] = { id, itemId, count, x, y, expiresAt } }
local nextId = 0

local function toScene(key: string, name: string, ...)
	for _, player in heroTracking.PlayersInScene(townWorld.SceneName(key)) do
		Net.FireClient(name, player, key, ...)
	end
end

local function wire(drop)
	return { id = drop.id, itemId = drop.itemId, count = drop.count, x = drop.x, y = drop.y, expiresIn = math.max(0, drop.expiresAt - os.clock()) }
end

-- 그 씬의 드랍 목록(씬에 막 들어온 플레이어용)
function exports.List(key: string)
	local list = {}
	for _, drop in drops[key] or {} do
		table.insert(list, wire(drop))
	end
	return list
end

-- 아이템을 땅에 떨어뜨린다(버리기, 나중에 몬스터 드롭도 여기로)
function exports.Spawn(key: string, itemId: string, count: number, x: number, y: number)
	if not items[itemId] or count <= 0 then
		return nil
	end
	nextId += 1
	local drop = { id = nextId, itemId = itemId, count = count, x = x, y = y, expiresAt = os.clock() + balance.WORLD_DROP_LIFETIME }
	drops[key] = drops[key] or {}
	drops[key][drop.id] = drop
	toScene(key, "WorldDropSpawned", wire(drop))
	return drop
end

local function remove(key: string, id: number, pickedBy: number?)
	if drops[key] and drops[key][id] then
		drops[key][id] = nil
		toScene(key, "WorldDropRemoved", id, pickedBy)
	end
end

local function sceneAndFeet(player: Player)
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	local position = heroTracking.GetPosition(player.UserId)
	if not key or not position then
		return nil, nil
	end
	return key, position / townWorld.data.scale
end

function exports.load()
	Net.OnServer("DropItem", function(player: Player, tab: string, slot: number)
		local key, feet = sceneAndFeet(player)
		if not key or slot ~= math.floor(slot) then
			return
		end
		local taken = inventoryService.Take(player, tab, slot)
		if not taken then
			return
		end
		-- 발밑 근처에 살짝 흩어서(여러 개를 버려도 겹치지 않게)
		local x = feet.X + math.random(-6, 6)
		local y = feet.Y + math.random(1, 5)
		exports.Spawn(key, taken.ItemId, taken.Count, x, y)
	end)

	Net.OnServer("PickupDrop", function(player: Player, id: number)
		local key, feet = sceneAndFeet(player)
		local drop = key and drops[key] and drops[key][id]
		if not drop then
			return
		end
		if (Vector2.new(drop.x, drop.y) - feet).Magnitude > balance.PICKUP_RANGE + balance.PICKUP_PAD then
			return
		end
		local added = inventoryService.AddItem(player, drop.itemId, drop.count)
		if added <= 0 then
			Net.FireClient("Notify", player, "가방에 자리가 없어요")
			return
		end
		drop.count -= added
		if drop.count <= 0 then
			remove(key, id, player.UserId)
		else
			toScene(key, "WorldDropSpawned", wire(drop)) -- 남은 개수로 갱신
			Net.FireClient("Notify", player, "가방이 가득 차서 일부만 주웠어요")
		end
	end)

	-- 수명이 다한 드랍 정리(1초마다)
	exports.running = true
	task.spawn(function()
		while exports.running do
			task.wait(1)
			local now = os.clock()
			for key, list in drops do
				for id, drop in list do
					if drop.expiresAt <= now then
						remove(key, id, nil)
					end
				end
			end
		end
	end)
end

function exports.start() end
function exports.unload()
	exports.running = false
end

return exports

end
MODULES['ServerScriptService/server/services/currencyService'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 재화(골드) 서비스.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local balance = require(ReplicatedStorage.shared.config.balance)
local Net = require(ReplicatedStorage.shared.net.net)
local persistence = require(script.Parent.persistence)

local exports = {}

function exports.AddGold(player: Player, amount: number)
	local data = persistence.Get(player)
	if not data or amount == 0 then
		return
	end
	data.Gold = math.max(data.Gold + amount, 0)
	persistence.MarkDirty(player)
	Net.FireClient("GoldUpdated", player, data.Gold)
	if amount > 0 then
		Net.FireClient("ItemAcquired", player, "Gold", amount)
	end
end

return exports

end
MODULES['ServerScriptService/server/services/inventoryService'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 인벤토리/장비 서비스: 아이템 추가(스택/빈 칸), 칸 옮기기(드래그 앤 드롭), 꺼내기(버리기), 장비 착용·해제,
-- 장비에서 계산하는 공격력/방어력. 가방은 탭(장비·소비·기타·캐시·중요)마다 칸이 따로 있고,
-- { Tab, Slot, ItemId, Count, Plus? } 촘촘한 배열로 저장한다(Plus = 무기 강화 단계 — 착용하면 data.EquipmentPlus로 옮겨 간다)(DataStore가 빈 칸이 있는 숫자 키 테이블을 못 저장함).
-- 아이템이 어느 탭에 들어가는지는 아이템 표(shared/data/items.luau)의 Tab이 정한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local balance = require(ReplicatedStorage.shared.config.balance)
local Net = require(ReplicatedStorage.shared.net.net)
local persistence = require(script.Parent.persistence)
local items = require(ReplicatedStorage.shared.data.items)
local weapons = require(ReplicatedStorage.shared.config.weapons)
local ninjutsu = require(ReplicatedStorage.shared.config.ninjutsu)

local SLOTS = balance.INVENTORY_SLOTS

local exports = {}

local function tabOf(itemId: string): string
	local def = items[itemId]
	return def and def.Tab or "Etc"
end

local function findEntry(inventory, tab: string, slot: number)
	for _, entry in inventory do
		if entry.Tab == tab and entry.Slot == slot then
			return entry
		end
	end
	return nil
end
exports.FindEntry = findEntry

local function push(player: Player, data)
	persistence.MarkDirty(player)
	Net.FireClient("InventoryUpdated", player, data.Inventory)
end

-- 이 아이템이 몇 개까지 들어갈 수 있는가(같은 스택 여유 + 빈 칸)
function exports.RoomFor(player: Player, itemId: string): number
	local data = persistence.Get(player)
	local def = items[itemId]
	if not data or not def then
		return 0
	end
	local tab = tabOf(itemId)
	local room = 0
	for _, e in data.Inventory do
		if e.Tab == tab and e.ItemId == itemId then
			room += def.StackMax - e.Count
		end
	end
	for slot = 1, SLOTS do
		if not findEntry(data.Inventory, tab, slot) then
			room += def.StackMax
		end
	end
	return room
end

-- 서버 모듈(줍기·드롭 등)이 아이템을 줄 때 쓴다. 그 아이템 탭의 같은 스택부터 StackMax까지 채우고, 남으면 빈 칸에 넣는다.
-- 실제로 들어간 개수를 돌려준다(가방이 가득 차면 일부만 들어가거나 0일 수 있음).
function exports.AddItem(player: Player, itemId: string, count: number): number
	local data = persistence.Get(player)
	local def = items[itemId]
	if not data or not def or count <= 0 then
		return 0
	end
	local tab = tabOf(itemId)
	local inventory = data.Inventory
	local remaining = count

	for _, entry in inventory do
		if remaining <= 0 then
			break
		end
		if entry.Tab == tab and entry.ItemId == itemId and entry.Count < def.StackMax then
			local add = math.min(def.StackMax - entry.Count, remaining)
			entry.Count += add
			remaining -= add
		end
	end
	for slot = 1, SLOTS do
		if remaining <= 0 then
			break
		end
		if not findEntry(inventory, tab, slot) then
			local add = math.min(def.StackMax, remaining)
			table.insert(inventory, { Tab = tab, Slot = slot, ItemId = itemId, Count = add })
			remaining -= add
		end
	end

	local added = count - remaining
	if added > 0 then
		push(player, data)
		Net.FireClient("ItemAcquired", player, itemId, added)
	end
	return added
end

-- 같은 탭 안에서 칸 옮기기(드래그 앤 드롭): 빈 칸이면 이동, 아이템이 있으면 서로 바꾸기, 같은 아이템이면 합치기(넘치면 남는다).
function exports.Move(player: Player, tab: string, from: number, to: number): boolean
	local data = persistence.Get(player)
	if not data or from == to or from ~= math.floor(from) or to ~= math.floor(to) or from < 1 or from > SLOTS or to < 1 or to > SLOTS then
		return false
	end
	local a = findEntry(data.Inventory, tab, from)
	if not a then
		return false
	end
	local b = findEntry(data.Inventory, tab, to)
	if b and b.ItemId == a.ItemId then
		local def = items[a.ItemId]
		local add = math.min(def.StackMax - b.Count, a.Count)
		if add > 0 then
			b.Count += add
			a.Count -= add
			if a.Count <= 0 then
				table.remove(data.Inventory, table.find(data.Inventory, a))
			end
			push(player, data)
			return true
		end
	end
	a.Slot = to
	if b then
		b.Slot = from
	end
	push(player, data)
	return true
end

-- 칸의 아이템을 통째로 꺼낸다(버리기) — 꺼낸 { ItemId, Count }를 돌려준다. 중요 물품(NoDrop)은 못 꺼낸다.
function exports.Take(player: Player, tab: string, slot: number)
	local data = persistence.Get(player)
	local entry = data and findEntry(data.Inventory, tab, slot)
	local def = entry and items[entry.ItemId]
	if not entry or not def or def.NoDrop then
		return nil
	end
	if (entry.Plus or 0) > 0 then
		Net.FireClient("Notify", player, "강화한 장비는 버릴 수 없어요") -- 땅에 떨어진 아이템은 강화 단계를 담지 못한다
		return nil
	end
	table.remove(data.Inventory, table.find(data.Inventory, entry))
	push(player, data)
	return { ItemId = entry.ItemId, Count = entry.Count }
end

-- 그 아이템을 모두 합쳐 몇 개 가졌나
function exports.CountItem(player: Player, itemId: string): number
	local data = persistence.Get(player)
	local n = 0
	for _, entry in data and data.Inventory or {} do
		if entry.ItemId == itemId then
			n += entry.Count
		end
	end
	return n
end

-- 아이템 id로 count개를 뺀다(여러 칸에 나뉘어 있어도). 모자라면 아무것도 안 빼고 false.
function exports.TakeItem(player: Player, itemId: string, count: number): boolean
	local data = persistence.Get(player)
	if not data or count <= 0 or exports.CountItem(player, itemId) < count then
		return false
	end
	local remaining = count
	for i = #data.Inventory, 1, -1 do
		local entry = data.Inventory[i]
		if remaining <= 0 then
			break
		end
		if entry.ItemId == itemId then
			local n = math.min(entry.Count, remaining)
			entry.Count -= n
			remaining -= n
			if entry.Count <= 0 then
				table.remove(data.Inventory, i)
			end
		end
	end
	push(player, data)
	return true
end

-- 칸에서 개수만큼 빼낸다(팔기·사용). 실제로 뺀 { ItemId, Count }를 돌려준다(없으면 nil).
function exports.Remove(player: Player, tab: string, slot: number, count: number)
	local data = persistence.Get(player)
	local entry = data and findEntry(data.Inventory, tab, slot)
	if not entry or count <= 0 then
		return nil
	end
	local n = math.min(count, entry.Count)
	entry.Count -= n
	if entry.Count <= 0 then
		table.remove(data.Inventory, table.find(data.Inventory, entry))
	end
	push(player, data)
	return { ItemId = entry.ItemId, Count = n }
end

local function equippedStat(player: Player, statName: string): number
	local data = persistence.Get(player)
	local total = 0
	if data then
		for _, itemId in data.Equipment do
			local def = items[itemId]
			if def and def[statName] then
				total += def[statName]
			end
		end
	end
	return total
end

-- 전투에 쓰이는 최종 수치(서버가 착용 장비에서 계산 — 몬스터 모듈이 호출).
--  공격력 = 레벨(balance.attackFor) + 착용 장비 Attack + 무기 강화 보너스(weapons.Bonus)
local attackBuffs = {} -- [userId] = { mult, untilT }
function exports.GetAttackDamage(player: Player): number
	local data = persistence.Get(player)
	local weaponDef = data and items[data.Equipment.Weapon or ""]
	local plus = data and data.EquipmentPlus and data.EquipmentPlus.Weapon
	local total = balance.attackFor(data and data.Level or 1) + equippedStat(player, "Attack") + weapons.Bonus(weaponDef, plus)
	-- 무기 단련(공용 패시브 c_mastery): 레벨마다 공격력 +
	local mastery = ninjutsu.LevelOf(data and data.Ninjutsu, "c_mastery")
	if mastery > 0 then
		total *= 1 + ninjutsu.SKILLS.c_mastery.perLevel * mastery
	end
	local buff = attackBuffs[player.UserId] -- 파티 버프(열기 등)
	if buff and os.clock() < buff.untilT then
		total *= buff.mult
	end
	return math.round(total)
end

-- 공격력 버프: seconds초 동안 공격력 × mult(ninjutsuService의 버프 인술)
function exports.SetAttackBuff(player: Player, mult: number, seconds: number)
	attackBuffs[player.UserId] = { mult = mult, untilT = os.clock() + seconds }
end

function exports.GetDefense(player: Player): number
	return balance.BASE_DEFENSE + equippedStat(player, "Defense")
end

local function pushEquipment(player: Player, data)
	push(player, data)
	Net.FireClient("EquipmentUpdated", player, data.Equipment, data.EquipmentPlus or {})
end

-- 가방·장비를 다시 보낸다(강화처럼 서비스 밖에서 칸 내용을 고친 뒤)
function exports.Refresh(player: Player)
	local data = persistence.Get(player)
	if data then
		pushEquipment(player, data)
	end
end

-- 장비 탭의 칸(slot)을 착용한다. 이미 끼고 있던 장비는 그 칸으로 돌아간다(교체).
function exports.Equip(player: Player, slot: number): boolean
	local data = persistence.Get(player)
	if not data then
		return false
	end
	local entry = findEntry(data.Inventory, "Equip", slot)
	local def = entry and items[entry.ItemId]
	if not def or not def.EquipSlot then
		return false
	end
	if def.Level and (data.Level or 1) < def.Level then
		Net.FireClient("Notify", player, ("Lv.%d부터 쓸 수 있어요"):format(def.Level))
		return false
	end
	data.EquipmentPlus = data.EquipmentPlus or {}
	local previous, previousPlus = data.Equipment[def.EquipSlot], data.EquipmentPlus[def.EquipSlot]
	table.remove(data.Inventory, table.find(data.Inventory, entry))
	data.Equipment[def.EquipSlot] = entry.ItemId
	data.EquipmentPlus[def.EquipSlot] = entry.Plus -- 강화 단계도 같이 옮긴다(없으면 nil)
	if previous then
		table.insert(data.Inventory, { Tab = "Equip", Slot = slot, ItemId = previous, Count = 1, Plus = previousPlus })
	end
	pushEquipment(player, data)
	return true
end

function exports.Unequip(player: Player, equipSlot: string): boolean
	local data = persistence.Get(player)
	local itemId = data and data.Equipment[equipSlot]
	if not itemId then
		return false
	end
	for slot = 1, SLOTS do
		if not findEntry(data.Inventory, "Equip", slot) then
			local plus = data.EquipmentPlus and data.EquipmentPlus[equipSlot]
			table.insert(data.Inventory, { Tab = "Equip", Slot = slot, ItemId = itemId, Count = 1, Plus = plus })
			data.Equipment[equipSlot] = nil
			if data.EquipmentPlus then
				data.EquipmentPlus[equipSlot] = nil
			end
			pushEquipment(player, data)
			return true
		end
	end
	return false -- 장비 탭이 가득 차서 해제할 자리가 없다.
end

return exports

end
MODULES['ServerScriptService/server/services/persistence'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 플레이어 데이터 영속성(DataStore) 서비스: 로드/저장/세션 락/오토세이브. 게임 규칙은 모른다 — 접속 중에는 메모리 세션
-- 테이블이 진실이고, 다른 서비스(progression/inventory/currency)가 그 테이블을 바꾼 뒤 MarkDirty만 부른다.
--
-- 참고: 사용자의 이전 프로젝트(Origin-W-I-L-D)와 OpenMMO의 Persistence 패턴 — (1) DataStore 호출을 재시도 + Studio에서
-- API 접근이 막혀 있으면 메모리 목업으로 폴백, (2) UpdateAsync 기반 세션 락으로 같은 계정이 다른 서버(JobId)에서
-- 동시에 저장 중일 때 덮어쓰지 않게 함, (3) 바뀐 사람만 표시해뒀다가 주기적으로 한 번에 저장하는 dirty-flag + 배치
-- 오토세이브(로그아웃 시엔 그와 별개로 항상 즉시 저장). 저장 형태와 버전 마이그레이션은 playerSchema.luau가 맡는다.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local playerSchema = require(script.Parent.playerSchema)

local store = DataStoreService:GetDataStore("PlayerData_v1")

local MAX_RETRIES = 3
local RETRY_DELAY = 1 -- seconds
local SESSION_STALE_SECONDS = 30 -- 이보다 오래된 락은 서버가 죽은 걸로 보고 새로 가져간다
local AUTOSAVE_INTERVAL = 30 -- seconds, dirty 표시된 플레이어만 이 주기로 배치 저장
local AUTOSAVE_STAGGER = 0.5 -- seconds, 배치 저장 중 플레이어 사이에 살짝 간격을 둬서 DataStore 쓰로틀링 방지

-- UserId -> 데이터 테이블(메모리 세션, 접속 중에는 이걸 기준으로 읽고 쓴다)
local sessions = {}
-- UserId -> true, Load()가 이미 진행 중임을 표시(같은 키로 DataStore 요청이 동시에 중복으로 나가는 걸 막는다).
local loading = {}
-- UserId -> true, 마지막 저장 이후 데이터가 바뀌어 다음 오토세이브 때 저장해야 함을 표시.
local dirty = {}
local autosaveRunning = false

local exports = {}

-- pcall + 재시도 공통 래퍼. 성공하면 (true, 결과), 재시도 다 실패하면 (false, 마지막 에러).
local function withRetry(fn)
	local lastErr
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY)
		end
	end
	return false, lastErr
end

local function loadUncached(player: Player)
	local key = "Player_" .. player.UserId
	local locked = false

	local ok, result = withRetry(function()
		return store:UpdateAsync(key, function(existing)
			existing = existing or playerSchema.default()
			local session = existing._session

			if session and session.JobId ~= game.JobId and (os.time() - (session.Timestamp or 0)) < SESSION_STALE_SECONDS then
				locked = true
				return nil -- 다른 서버가 아직 들고 있는 걸로 보임 — 덮어쓰지 않고 중단
			end

			locked = false
			existing._session = { JobId = game.JobId, Timestamp = os.time() }
			return existing
		end)
	end)

	local data
	if ok and result then
		data = result
	elseif locked then
		warn(("persistence: %s의 데이터가 다른 서버에서 사용 중이라 이번 세션은 임시(저장 안 됨) 데이터로 시작합니다."):format(player.Name))
		data = playerSchema.default()
		data._mock = true
	else
		-- Studio에서 API 접근이 막혀 있거나 DataStore 자체가 실패하는 경우 — 완전히 막히는 대신 메모리로만 굴러가는
		-- 목업으로 폴백해서 최소한 테스트는 가능하게 한다.
		warn(("persistence: %s의 DataStore 로드 실패, 메모리 임시 데이터로 대체합니다 - %s"):format(player.Name, tostring(result)))
		data = playerSchema.default()
		data._mock = true
	end

	playerSchema.migrate(data)
	sessions[player.UserId] = data
	return data
end

-- 세션 데이터를 불러온다(이미 있으면 그대로). DataStore 호출로 yield할 수 있다.
function exports.Load(player: Player)
	if sessions[player.UserId] then
		return sessions[player.UserId]
	end

	if loading[player.UserId] then
		repeat
			task.wait()
		until not loading[player.UserId]
		return sessions[player.UserId]
	end

	loading[player.UserId] = true
	local data = loadUncached(player)
	loading[player.UserId] = nil
	return data
end

-- 이미 불러온 세션 데이터(없으면 nil). 다른 서비스가 읽고 쓰는 유일한 진입점.
function exports.Get(player: Player)
	return sessions[player.UserId]
end

-- 데이터를 바꾼 서비스가 호출해서 "다음 오토세이브 때 저장 대상"으로 표시한다.
function exports.MarkDirty(player: Player)
	dirty[player.UserId] = true
end

function exports.Save(player: Player, isLogout: boolean)
	local data = sessions[player.UserId]
	if not data then
		return
	end

	if data._mock then
		-- 애초에 세션 락을 못 잡았거나 로드가 실패한 경우라 실제 저장소에 쓰면 안 된다(락을 진짜로 들고 있는 다른 서버
		-- 데이터를 덮어쓸 수 있음).
		return
	end

	local key = "Player_" .. player.UserId
	local payload = table.clone(data)
	payload._mock = nil
	payload._session = if isLogout then nil else { JobId = game.JobId, Timestamp = os.time() }

	local ok = withRetry(function()
		return store:UpdateAsync(key, function(existing)
			-- 저장 시점에도 다른 서버가 이미 락을 가져간 상태면(드물지만 가능) 덮어쓰지 않는다.
			if existing and existing._session and existing._session.JobId ~= game.JobId then
				return nil
			end
			return payload
		end)
	end)

	if ok then
		dirty[player.UserId] = nil
	else
		warn(("persistence: %s의 데이터 저장 실패(재시도 %d회 소진) - 다음 오토세이브 때 재시도됨"):format(player.Name, MAX_RETRIES))
	end
end

-- 플레이어가 나갈 때: 즉시 저장하고(세션 락 해제) 메모리에서 지운다.
function exports.Release(player: Player)
	exports.Save(player, true)
	sessions[player.UserId] = nil
	dirty[player.UserId] = nil
end

-- 서버가 닫힐 때(Studio Stop 포함): PlayerRemoving의 비동기 저장이 끝나기 전에 서버가 죽어 저장이 유실될 수 있으므로,
-- 모든 플레이어 저장이 끝날 때까지 기다린다(BindToClose 안에서 호출).
function exports.SaveAll()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			exports.Save(player, true)
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait()
	end
end

-- 바뀐 사람만 모아뒀다가 AUTOSAVE_INTERVAL마다 한 번에 저장한다(서버 크래시로 인한 유실 범위를 이 주기 이내로 줄임).
local function runAutosaveLoop()
	while autosaveRunning do
		task.wait(AUTOSAVE_INTERVAL)

		for userId in dirty do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				exports.Save(player, false)
			else
				dirty[userId] = nil -- 이미 나간 플레이어면 표시만 지운다(로그아웃 시 이미 저장됐음)
			end
			task.wait(AUTOSAVE_STAGGER)
		end
	end
end

function exports.StartAutosave()
	if autosaveRunning then
		return
	end
	autosaveRunning = true
	task.spawn(runAutosaveLoop)
end

function exports.StopAutosave()
	autosaveRunning = false
end

return exports

end
MODULES['ServerScriptService/server/services/playerSchema'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 플레이어 저장 데이터의 형태(스키마)와 버전 마이그레이션. 저장 데이터에는 SchemaVersion이 들어가고, 불러올 때마다 저장된
-- 버전에서 CURRENT_VERSION까지 마이그레이션을 순서대로 적용한다 — 필드를 추가/변경할 때 예전 저장 데이터가 깨지지 않게
-- 하는 단 하나의 통로다(예전에는 필드를 추가할 때마다 로드 코드에 `or {}` 같은 임기응변을 끼워 넣었다).
--
-- 새 필드/변경을 넣는 법: CURRENT_VERSION을 1 올리고, migrations[새 버전] = function(data) ... end 를 추가한다.
-- default()는 "가장 최신 버전의 신규 플레이어" 형태여야 한다(SchemaVersion = CURRENT_VERSION).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local balance = require(ReplicatedStorage.shared.config.balance)
local pets = require(ReplicatedStorage.shared.config.pets)

local exports = {}

exports.CURRENT_VERSION = 13

local STARTER_GOLD = 300 -- 처음 시작할 때 주는 골드(v3부터 — 기존 플레이어도 v3로 올라갈 때 한 번 받는다)

-- 포획 시험용 방울(v5부터 — 맺음석 세공(M6)·튜토리얼(M7)이 생기기 전까지 모두에게 한 번 지급)
local STARTER_BELLS = { { ItemId = "Bell1", Count = 10 }, { ItemId = "Bell2", Count = 3 } }

-- 처음 시작할 때 가방에 넣어 주는 물건(v2부터 — 기존 플레이어도 v2로 올라갈 때 한 번 받는다)
local STARTER_ITEMS = {
	{ Tab = "Equip", Slot = 1, ItemId = "WoodenSword", Count = 1 },
	{ Tab = "Equip", Slot = 2, ItemId = "LeafArmor", Count = 1 },
	{ Tab = "Use", Slot = 1, ItemId = "RedPotion", Count = 5 },
	{ Tab = "Etc", Slot = 1, ItemId = "SproutFragment", Count = 3 },
	{ Tab = "Key", Slot = 1, ItemId = "RainbowEgg", Count = 1 },
}
-- 「오문 닌자전」 시작 물건(v7부터 — 기존 플레이어도 v7로 올라갈 때 한 번 받는다): 수리검 · 주먹밥
local NINJA_STARTER = { { ItemId = "Shuriken", Count = 30 }, { ItemId = "Onigiri", Count = 5 } }
local NINJA_QUICKSLOTS = { "Shuriken", "Onigiri", "" }

-- 소비 탭 빈 칸에 차례로 넣는다(칸이 모자라면 들어가는 만큼만)
local function addToUseTab(inventory, list)
	local used = {}
	for _, e in inventory do
		if e.Tab == "Use" then
			used[e.Slot] = true
		end
	end
	local slot = 1
	for _, b in list do
		while used[slot] do
			slot += 1
		end
		if slot > balance.INVENTORY_SLOTS then
			break
		end
		table.insert(inventory, { Tab = "Use", Slot = slot, ItemId = b.ItemId, Count = b.Count })
		used[slot] = true
	end
end

-- 「오문 닌자전」 새 플레이어의 가방(v10부터): 닌자도 + 수리검 + 주먹밥. 예전 시작 물건(STARTER_ITEMS · STARTER_BELLS)은
-- 옛 버전 마이그레이션이 지나가는 길에만 쓰이고, v10이 전부 팩 아이템으로 바꾸거나 없앤다.
local NEW_PLAYER_ITEMS = {
	{ Tab = "Equip", Slot = 1, ItemId = "Ninjato", Count = 1 },
	{ Tab = "Use", Slot = 1, ItemId = "Shuriken", Count = 30 },
	{ Tab = "Use", Slot = 2, ItemId = "Onigiri", Count = 5 },
}
-- 옛 아이템 → 팩 아이템(v10). 여기 없고 아이템 표에도 없는 것(방울 · 몬스터 재료 · 새싹 조각 · 무지개 알)은 없앤다.
local LEGACY_ITEMS = { WoodenSword = "Ninjato", LeafArmor = "GuardCharm", RedPotion = "Onigiri", OrangePotion = "Sushi", WhitePotion = "Yakitori" }
-- 옛 아이템이 들어가던 탭(v2 마이그레이션이 아이템 표 대신 본다 — 표에서 옛 아이템을 없앴으므로)
local LEGACY_TABS = { WoodenSword = "Equip", LeafArmor = "Equip", RedPotion = "Use", OrangePotion = "Use", WhitePotion = "Use" }

local function newPets()
	return { Box = {}, Party = {}, Slots = pets.SLOTS_START, Boxes = pets.BOXES_START }
end

function exports.default()
	return {
		SchemaVersion = exports.CURRENT_VERSION,
		Level = 1,
		Experience = 0,
		MaxExperience = balance.maxExperienceFor(1),
		Health = balance.maxHealthFor(1),
		Gold = STARTER_GOLD,
		-- { { Tab = string, Slot = number, ItemId = string, Count = number }, ... } — 탭(장비·소비·기타·캐시·중요)마다
		-- 칸 번호가 따로 있다. 빈 칸이 있는 숫자 키 테이블은 DataStore가 안전하게 저장하지 못해서 칸 번호를 값 안에 넣은 촘촘한 배열로 둔다.
		Inventory = (function()
			local list = {}
			for _, e in NEW_PLAYER_ITEMS do
				table.insert(list, table.clone(e))
			end
			return list
		end)(),
		-- { Weapon = ItemId?, Armor = ItemId? } — 착용 중인 장비(비어 있으면 키 없음).
		Equipment = {},
		-- 착용 장비의 강화 단계 { Weapon = 0~10 }(가방에 있을 때는 그 칸의 Plus — shared/config/weapons.luau)
		EquipmentPlus = {},
		-- 도감: { [종류 id] = 1(봤음 — 쓰러뜨림) | 2(잡았음) } (shared/config/pets.luau DEX_SEEN / DEX_CAUGHT)
		Dex = {},
		-- 펫(잡은 몬스터): 형식은 shared/config/pets.luau 맨 위 설명
		Pets = newPets(),
		-- 생활 숙련도 경험치: Mine = 맺음석 캐기, Craft = 방울 세공
		Life = { Mine = 0, Craft = 0 },
		-- 소비 단축칸 1·2·3(아이템 id, 빈 칸 = "") — 숫자키/터치로 바로 사용(방울 = 던지기)
		QuickSlots = table.clone(NINJA_QUICKSLOTS),
		-- 유파(shared/config/ninjutsu.luau SCHOOLS의 id, "" = 아직 안 고름) · 인술 단계 { [인술 id] = 1~5 }(없으면 1단계)
		School = "",
		Ninjutsu = {},
		-- 전직 단계: 0 = 견습(유파 없음) · 1~4 = n차 전직(Lv.10 · 30 · 60 · 100, 1차 때 유파를 고른다)
		Job = 0,
		-- 스킬(shared/config/ninjutsu.luau 스킬 나무): Ninjutsu = { [스킬 id] = 레벨 }, SP = 전직(1~4)별 안 쓴 스킬 포인트, SkillSlots = 단축칸의 스킬 id("" = 빈 칸)
		SP = { 0, 0, 0, 0 },
		SkillSlots = { "", "", "", "" },
		-- 본 줄거리 퀘스트(shared/config/quests.luau): 지금 퀘스트 번호 · 받았는가 · 진행(처치 수 등)
		Quest = { Index = 1, Accepted = false, Progress = 0 },
	}
end

-- 각 함수는 "이전 버전 데이터를 그 번호 버전으로 올린다".
local migrations = {
	-- v0(버전 필드가 없던 초기 저장 데이터) → v1: 뼈대 시절 이후 추가된 필드들을 채운다.
	[1] = function(data)
		data.Level = data.Level or 1
		data.Experience = data.Experience or 0
		data.MaxExperience = data.MaxExperience or balance.maxExperienceFor(data.Level)
		data.Gold = data.Gold or 0
		data.Inventory = data.Inventory or {}
		data.Equipment = data.Equipment or {}
	end,
	-- v1 → v2: 가방이 탭(장비·소비·기타·캐시·중요)으로 나뉜다 — 기존 아이템을 종류별 탭으로 옮겨 칸을 1번부터 다시 매긴다.
	-- 도감(Dex) 추가, 시작 물건 지급.
	[2] = function(data)
		local items = require(ReplicatedStorage.shared.data.items)
		local nextSlot = {}
		local moved = {}
		for _, e in data.Inventory or {} do
			local def = items[e.ItemId]
			local legacyTab = LEGACY_TABS[e.ItemId]
			if def or legacyTab then
				local tab = legacyTab or def.Tab or "Etc"
				nextSlot[tab] = (nextSlot[tab] or 0) + 1
				table.insert(moved, { Tab = tab, Slot = nextSlot[tab], ItemId = e.ItemId, Count = e.Count })
			end
		end
		for _, e in STARTER_ITEMS do
			nextSlot[e.Tab] = (nextSlot[e.Tab] or 0) + 1
			if nextSlot[e.Tab] <= balance.INVENTORY_SLOTS then
				table.insert(moved, { Tab = e.Tab, Slot = nextSlot[e.Tab], ItemId = e.ItemId, Count = e.Count })
			end
		end
		data.Inventory = moved
		data.Dex = data.Dex or {}
	end,
	-- v2 → v3: 가게(포션 상점)가 생겨서 시작 골드를 준다.
	[3] = function(data)
		data.Gold = (data.Gold or 0) + STARTER_GOLD
	end,
	-- v3 → v4(몬스터 수집 RPG 전환, GAME_DESIGN.md): 도감이 봤음/잡았음 두 상태가 되고(예전 true = 봤음), 펫 상자와 생활 숙련도가 생긴다.
	[4] = function(data)
		local dex = {}
		for id, v in data.Dex or {} do
			if v then
				dex[id] = if v == pets.DEX_CAUGHT then pets.DEX_CAUGHT else pets.DEX_SEEN
			end
		end
		data.Dex = dex
		data.Pets = data.Pets or newPets()
		data.Life = data.Life or { Mine = 0, Craft = 0 }
	end,
	-- v4 → v5: 포획(M2) 시험용 방울을 "소비" 탭 빈 칸에 넣는다(칸이 모자라면 들어가는 만큼만).
	[5] = function(data)
		local used = {}
		for _, e in data.Inventory or {} do
			if e.Tab == "Use" then
				used[e.Slot] = true
			end
		end
		local slot = 1
		for _, b in STARTER_BELLS do
			while used[slot] do
				slot += 1
			end
			if slot > balance.INVENTORY_SLOTS then
				break
			end
			table.insert(data.Inventory, { Tab = "Use", Slot = slot, ItemId = b.ItemId, Count = b.Count })
			used[slot] = true
		end
	end,
	-- v5 → v6: 포획이 전투 중 방울 던지기로 바뀌며 소비 단축칸 1·2·3이 생긴다(처음엔 흐린 방울 · 빨간 물약).
	[6] = function(data)
		data.QuickSlots = data.QuickSlots or { "Bell1", "RedPotion", "" }
	end,
	-- v6 → v7(「오문 닌자전」 전환, NINJA_DESIGN.md): 투척 무기·음식을 한 번 지급하고, 단축칸의 방울(포획은 꺼 둠)을 수리검·주먹밥으로 바꾼다.
	[7] = function(data)
		data.Inventory = data.Inventory or {}
		addToUseTab(data.Inventory, NINJA_STARTER)
		local slots = data.QuickSlots or { "", "", "" }
		local taken = {}
		for i = 1, 3 do
			local id = slots[i] or ""
			if string.sub(id, 1, 4) == "Bell" then
				id = ""
			end
			slots[i] = id
			taken[id] = true
		end
		for _, id in NINJA_QUICKSLOTS do
			if id ~= "" and not taken[id] then
				for i = 1, 3 do
					if slots[i] == "" then
						slots[i] = id
						taken[id] = true
						break
					end
				end
			end
		end
		data.QuickSlots = slots
	end,
	-- v7 → v8(N2 유파와 인술): 유파(아직 안 고름)와 인술 단계표가 생긴다 — 접속하면 유파 고르기 창이 뜬다.
	[8] = function(data)
		data.School = data.School or ""
		data.Ninjutsu = data.Ninjutsu or {}
	end,
	-- v8 → v9(N3 장비와 강화): 착용 장비의 강화 단계표가 생긴다.
	[9] = function(data)
		data.EquipmentPlus = data.EquipmentPlus or {}
	end,
	-- v9 → v10(에셋 · UI 전면 교체): 아이템이 전부 팩 아이템이 됐다. 옛 아이템은 짝이 되는 팩 아이템으로 바꾸고
	-- (나무 검 → 닌자도, 잎사귀 갑옷 → 수호 부적, 물약 → 음식), 짝이 없는 것은 없앤다. 같은 아이템은 한 칸에 합친다.
	[10] = function(data)
		local items = require(ReplicatedStorage.shared.data.items)
		local kept, usedSlots = {}, {}
		local function freeSlot(tab: string, prefer: number?): number?
			usedSlots[tab] = usedSlots[tab] or {}
			if prefer and prefer >= 1 and prefer <= balance.INVENTORY_SLOTS and not usedSlots[tab][prefer] then
				return prefer
			end
			for slot = 1, balance.INVENTORY_SLOTS do
				if not usedSlots[tab][slot] then
					return slot
				end
			end
			return nil
		end
		for _, e in data.Inventory or {} do
			local id = LEGACY_ITEMS[e.ItemId] or e.ItemId
			local def = items[id]
			local remaining = if def then (e.Count or 1) else 0
			if def and def.StackMax > 1 then
				for _, k in kept do
					if remaining > 0 and k.ItemId == id and k.Count < def.StackMax then
						local add = math.min(def.StackMax - k.Count, remaining)
						k.Count += add
						remaining -= add
					end
				end
			end
			while def and remaining > 0 do
				local slot = freeSlot(def.Tab, if e.Tab == def.Tab then e.Slot else nil)
				if not slot then
					break -- 그 탭이 가득 — 남는 것은 버려진다
				end
				local add = math.min(def.StackMax, remaining)
				usedSlots[def.Tab][slot] = true
				table.insert(kept, { Tab = def.Tab, Slot = slot, ItemId = id, Count = add, Plus = e.Plus })
				remaining -= add
			end
		end
		data.Inventory = kept
		local equipment = {}
		for slotName, itemId in data.Equipment or {} do
			local id = LEGACY_ITEMS[itemId] or itemId
			local def = items[id]
			if def and def.EquipSlot == slotName then
				equipment[slotName] = id
			end
		end
		data.Equipment = equipment
		local slots, seen = data.QuickSlots or { "", "", "" }, {}
		for i = 1, 3 do
			local id = LEGACY_ITEMS[slots[i] or ""] or slots[i] or ""
			local def = items[id]
			if not def or def.Tab ~= "Use" or seen[id] then
				id = ""
			end
			seen[id] = true
			slots[i] = id
		end
		data.QuickSlots = slots
	end,
	-- v10 → v11(전직): 전직 단계가 생긴다. 이미 유파가 있는 사람은 그 레벨까지의 전직을 한 것으로 친다(레벨이 10이 안 돼도 1차).
	[11] = function(data)
		if data.Job == nil then
			local ninjutsu = require(ReplicatedStorage.shared.config.ninjutsu)
			data.Job = if (data.School or "") ~= "" then math.max(1, ninjutsu.JobFor(data.Level or 1)) else 0
		end
	end,
	-- v12 → v13(스킬 나무 · SP): 옛 "전직마다 인술 하나 + 두루마리 단계"를 스킬 레벨 · SP · 단축칸으로 바꾼다.
	--  전직한 구간마다 그 레벨까지의 SP를 주고, 각 전직의 주력기 · 핵심 장치를 배운 것으로 친다(옛 두루마리 단계는 그 스킬의 레벨로).
	[13] = function(data)
		local ninjutsu = require(ReplicatedStorage.shared.config.ninjutsu)
		local old = if typeof(data.Ninjutsu) == "table" then data.Ninjutsu else {}
		data.Ninjutsu = {}
		data.SP = { 0, 0, 0, 0 }
		data.SkillSlots = { "", "", "", "" }
		local slot = 1
		if ninjutsu.TREE[data.School or ""] then
			for job = 1, math.min(data.Job or 0, #ninjutsu.JOB_LEVELS) do
				data.SP[job] = math.max(ninjutsu.SP_ON_JOB, ninjutsu.SpEarned(job, data.Level or 1))
				for _, id in ninjutsu.AutoFor(data.School, job) do
					local level = if typeof(old[id]) == "number" then old[id] else 1
					data.Ninjutsu[id] = math.clamp(math.floor(level), 1, ninjutsu.MaxOf(id))
					if ninjutsu.IsActive(id) and slot <= ninjutsu.SLOTS then
						data.SkillSlots[slot] = id
						slot += 1
					end
				end
			end
		end
	end,
	-- v11 → v12(퀘스트): 본 줄거리 퀘스트가 생긴다. 누구나 첫 퀘스트부터.
	[12] = function(data)
		if typeof(data.Quest) ~= "table" then
			data.Quest = { Index = 1, Accepted = false, Progress = 0 }
		end
	end,
}

-- 저장 데이터를 최신 버전으로 올리고 값 범위를 정리한다. 이미 최신이면 마이그레이션은 건너뛴다.
function exports.migrate(data)
	local version = data.SchemaVersion or 0
	if version > exports.CURRENT_VERSION then
		warn(("playerSchema: 저장 데이터 버전(%d)이 이 서버(%d)보다 새 버전이다 — 그대로 사용하지만 필드 호환이 안 될 수 있다"):format(
			version, exports.CURRENT_VERSION
		))
		return data
	end
	while version < exports.CURRENT_VERSION do
		version += 1
		migrations[version](data)
	end
	data.SchemaVersion = exports.CURRENT_VERSION

	-- 체력은 서버가 소유한다: 저장된 값이 없거나(첫 접속) 0 이하(죽은 채 저장)면 가득 채운 상태로, 최대 체력을 넘으면 잘라낸다.
	local maxHealth = balance.maxHealthFor(data.Level)
	if typeof(data.Health) ~= "number" or data.Health <= 0 then
		data.Health = maxHealth
	end
	data.Health = math.min(data.Health, maxHealth)

	return data
end

return exports

end
MODULES['ServerScriptService/server/services/progressionService'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 성장/체력 서비스: 경험치·레벨업·피해·사망. 플레이어 진행 상황의 진실은 서버 세션 데이터(persistence)이고, 이 서비스가
-- 규칙(shared/config/balance.luau)에 따라 그 데이터를 바꾸고 결과를 클라이언트에 통지한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local balance = require(ReplicatedStorage.shared.config.balance)
local ninjutsu = require(ReplicatedStorage.shared.config.ninjutsu)
local Net = require(ReplicatedStorage.shared.net.net)
local persistence = require(script.Parent.persistence)
local scenes = require(ReplicatedStorage.shared.config.scenes)
local heroTracking = require(script.Parent.Parent.modules.heroTracking)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local NetworkingService = UpsideEngine.GetService("NetworkingService")

local exports = {}

-- 서버 모듈(몬스터 처치 등)이 경험치를 줄 때 쓴다. 레벨업이 여러 번 겹쳐도 처리하고,
-- 바뀐 값은 클라이언트에 밀어주며 오토세이브 대상으로 표시한다.
function exports.AddExperience(player: Player, amount: number)
	local data = persistence.Get(player)
	if not data or amount <= 0 then
		return
	end

	data.Experience += amount
	local leveledUp = false
	local gained = 0
	while data.Experience >= data.MaxExperience do
		data.Experience -= data.MaxExperience
		data.Level += 1
		data.MaxExperience = balance.maxExperienceFor(data.Level)
		leveledUp = true
		gained += 1
	end
	-- 스킬 포인트: 전직한 뒤로는 레벨업마다 지금 전직에 SP_PER_LEVEL(shared/config/ninjutsu.luau 스킬 나무)
	if ninjutsu.GrantLevelSp(data, gained) then
		Net.FireClient("SchoolUpdated", player, data.School, data.Ninjutsu or {}, data.Job, data.SP, data.SkillSlots or {})
	end

	persistence.MarkDirty(player)
	if leveledUp then
		-- 레벨업은 잃어버리면 가장 아픈 이벤트라 30초 오토세이브를 기다리지 않고 바로 저장.
		task.spawn(persistence.Save, player, false)
	end
	Net.FireClient("StatsUpdated", player, data.Level, data.Experience, data.MaxExperience, leveledUp)
	if leveledUp then
		-- 레벨업하면 체력을 가득 채운다(최대 체력도 늘어남) — 서버가 정하고 클라이언트에 알린다.
		local maxHealth = balance.maxHealthFor(data.Level)
		data.Health = maxHealth
		Net.FireClient("PlayerHealthChanged", player, maxHealth, maxHealth, 0, false)
	end
end

-- 체력 회복(물약·치료사). 실제로 오른 양을 돌려준다(이미 가득이면 0).
function exports.Heal(player: Player, amount: number): number
	local data = persistence.Get(player)
	if not data or amount <= 0 then
		return 0
	end
	local maxHealth = balance.maxHealthFor(data.Level)
	local before = data.Health or maxHealth
	data.Health = math.min(before + amount, maxHealth)
	local healed = data.Health - before
	if healed > 0 then
		persistence.MarkDirty(player)
		Net.FireClient("PlayerHealthChanged", player, data.Health, maxHealth, 0, false)
	end
	return healed
end

-- 플레이어가 피해를 입는다(몬스터 공격 등). 체력의 진실은 서버 세션이다 — 계산 결과만 클라이언트에 알린다.
-- 체력이 0이 되면 사망 처리: 서버가 체력을 가득 채워 리스폰 상태로 만들고, 클라이언트에는 died=true로 알려
-- 클라이언트가 리스폰 연출(이동)을 수행하게 한다(리스폰 위치/씬 결정도 C3에서 서버로 옮길 예정).
function exports.DamagePlayer(player: Player, amount: number)
	local data = persistence.Get(player)
	if not data or amount <= 0 then
		return
	end
	local maxHealth = balance.maxHealthFor(data.Level)
	local newHealth = math.max((data.Health or maxHealth) - amount, 0)
	local died = newHealth <= 0
	data.Health = if died then maxHealth else newHealth
	persistence.MarkDirty(player)
	if died then
		-- 사망 페널티(GAME_DESIGN §7): 지금 레벨 필요 경험치의 5% + 가진 골드의 5%. 레벨은 내려가지 않는다.
		local lostExp = math.min(data.Experience, math.floor(data.MaxExperience * balance.DEATH_EXP_LOSS))
		data.Experience -= lostExp
		local lostGold = math.floor((data.Gold or 0) * balance.DEATH_GOLD_LOSS)
		data.Gold = (data.Gold or 0) - lostGold
		Net.FireClient("StatsUpdated", player, data.Level, data.Experience, data.MaxExperience, false)
		Net.FireClient("GoldUpdated", player, data.Gold)
		Net.FireClient("Notify", player, ("쓰러졌어요… 경험치 %d, 골드 %d를 잃었어요"):format(lostExp, lostGold))
		-- 리스폰 씬을 서버가 정한다: 탑다운 씬이면 시작 씬(회복소가 있는 마을), 예전 사이드뷰 씬이면 예전 마을.
		-- 클라이언트는 died 신호를 받고 그 씬의 시작 위치(⭐)로 옮긴다.
		local current = heroTracking.GetPlayerScene(player.UserId)
		local respawn = if townWorld.KeyOf(current) then townWorld.StartSceneName() else scenes.TOWN
		heroTracking.SetPlayerScene(player.UserId, respawn)
		NetworkingService:ResyncClient(player)
	end
	Net.FireClient("PlayerHealthChanged", player, data.Health, maxHealth, amount, died)
end

return exports

end
MODULES['Client/ui/pixelText'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 도트 글씨 — 에셋 공방(js/font.js — 레트로 비트맵 글꼴 「갈무리」, SIL OFL)에서 만든 글자판 이미지에서 한 글자씩 잘라 붙여 문자열을 그린다.
-- 로블록스에는 글꼴 파일을 올릴 수 없어서 쓰는 방식(비트맵 글꼴). 한글 11,172자·영문·숫자·기호를 지원하고,
-- 글자판에 없는 글자는 "?"로 그린다. 입력칸(TextBox)에는 못 쓴다.
--
-- 좌표 단위는 "UI 도트"(글자판 픽셀 그대로). 화면 크기는 부모에 걸린 정수 UIScale(pixelUI.Scale)이 키운다.
--   local label = pixelText.new(parent, { Text = "안녕", Font = "body", Color = Color3, Shadow = Color3?, Align = "left"|"center"|"right",
--                                         MaxWidth = 폭?, MaxLines = 줄 수? })
--   label.Frame.Position = UDim2.fromOffset(x, y) / label:SetText("...") / label:SetColor(c) / label.Width, label.Height
-- 글씨가 칸을 넘지 않게: MaxWidth를 주면 그 폭에 맞춰 줄을 바꾸고(띄어쓰기에서 먼저, 낱말이 길면 글자에서), MaxLines를 주면
--  그 줄 수를 넘는 부분은 "…"로 줄인다. 칸이 정해진 자리의 글씨는 반드시 MaxWidth(와 MaxLines)를 줄 것.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local fontData = require(ReplicatedStorage.shared.data["pixelFont.generated"])
local townIds = require(ReplicatedStorage.shared.config["townAssets.generated"])

local JAMO_START = 0x3131
local JAMO_END = 0x3163
local HANGUL_START = 0xAC00
local HANGUL_END = 0xD7A3

local exports = {}

-- 글자 → 글자판 번호(0부터)와 폭
local function glyphInfo(font, code: number): (number, number)
	local base = 95 + #font.extra
	if code >= 32 and code <= 126 then
		return code - 32, font.asciiAdv[code - 31]
	elseif code >= HANGUL_START and code <= HANGUL_END then
		return base + (JAMO_END - JAMO_START + 1) + (code - HANGUL_START), font.hangulAdv or font.cellW
	elseif code >= JAMO_START and code <= JAMO_END then
		return base + (code - JAMO_START), font.hangulAdv or font.cellW
	end
	for i, ch in font.extra do
		if utf8.codepoint(ch) == code then
			return 95 + i - 1, font.extraAdv[i]
		end
	end
	return 63 - 32, font.asciiAdv[63 - 31] -- "?"
end

local function lineWidth(font, line: string): number
	local w = 0
	for _, code in utf8.codes(line) do
		local _, adv = glyphInfo(font, code)
		w += adv
	end
	return w
end

function exports.Measure(text: string, fontKey: string?): (number, number)
	local font = fontData[fontKey or "body"]
	local w, n = 0, 0
	for line in (text .. "\n"):gmatch("(.-)\n") do
		w = math.max(w, lineWidth(font, line))
		n += 1
	end
	return w, n * font.line
end

-- 폭에 맞춰 줄바꿈: 띄어쓰기에서 먼저 끊고, 한 낱말이 폭보다 길면 글자에서 끊는다(공방 js/font.js wrap과 같은 규칙).
function exports.Wrap(text: string, maxWidth: number, fontKey: string?): string
	local font = fontData[fontKey or "body"]
	local out = {}
	for para in (text .. "\n"):gmatch("(.-)\n") do
		local line = ""
		for word in (para .. " "):gmatch("(.-) ") do
			local try = if line == "" then word else line .. " " .. word
			if lineWidth(font, try) <= maxWidth then
				line = try
			else
				if line ~= "" then
					table.insert(out, line)
				end
				line = ""
				for _, code in utf8.codes(word) do
					local ch = utf8.char(code)
					if line ~= "" and lineWidth(font, line .. ch) > maxWidth then
						table.insert(out, line)
						line = ""
					end
					line ..= ch
				end
			end
		end
		table.insert(out, line)
	end
	return table.concat(out, "\n")
end

-- 한 줄이 폭을 넘으면 끝을 "…"로 줄인다
local function fitLine(font, line: string, maxWidth: number): string
	if lineWidth(font, line) <= maxWidth then
		return line
	end
	local kept = ""
	for _, code in utf8.codes(line) do
		local try = kept .. utf8.char(code)
		if lineWidth(font, try .. "…") > maxWidth then
			break
		end
		kept = try
	end
	return (kept:gsub("%s+$", "")) .. "…"
end

-- 칸에 맞추기: 폭(maxWidth)을 넘으면 줄을 바꾸고, 줄 수(maxLines)를 넘으면 마지막 줄 끝을 "…"로 줄인다.
-- maxLines = 1이면 줄을 바꾸지 않고 한 줄로 줄인다.
function exports.Fit(text: string, maxWidth: number, maxLines: number?, fontKey: string?): string
	local font = fontData[fontKey or "body"]
	if maxLines == 1 then
		return fitLine(font, (text:gsub("\n", " ")), maxWidth)
	end
	local lines = {}
	for line in (exports.Wrap(text, maxWidth, fontKey) .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, line)
	end
	if maxLines and #lines > maxLines then
		local last = lines[maxLines] .. "…"
		while #lines > maxLines do
			table.remove(lines)
		end
		-- "…"를 붙여도 폭 안에 들어오게
		local kept = ""
		for _, code in utf8.codes(lines[maxLines]) do
			local try = kept .. utf8.char(code)
			if lineWidth(font, try .. "…") > maxWidth then
				break
			end
			kept = try
		end
		lines[maxLines] = if lineWidth(font, last) <= maxWidth then last else kept .. "…"
	end
	return table.concat(lines, "\n")
end

local Label = {}
Label.__index = Label

-- 칸 제한(MaxWidth · MaxLines)이 있으면 그 안에 들어가게 고친 글
function Label:_fitted(text: string): string
	if self._maxWidth then
		return exports.Fit(text, self._maxWidth, self._maxLines, self._fontKey)
	end
	return text
end

function Label:_render()
	for _, child in self._glyphs do
		child:Destroy()
	end
	table.clear(self._glyphs)
	local font = self._font
	local pages = (townIds.FONT and townIds.FONT[self._fontKey]) or {}
	local shown = self:_fitted(self._text)
	local width, height = exports.Measure(shown, self._fontKey)
	self.Width, self.Height = width, height
	self.Frame.Size = UDim2.fromOffset(width, height)

	local layers = {}
	if self._shadow then
		table.insert(layers, { color = self._shadow, dx = 1, dy = 1, z = 0 })
	end
	table.insert(layers, { color = self._color, dx = 0, dy = 0, z = 1 })

	local y = 0
	for line in (shown .. "\n"):gmatch("(.-)\n") do
		local lw = lineWidth(font, line)
		local x = if self._align == "center" then math.floor((width - lw) / 2) elseif self._align == "right" then width - lw else 0
		for _, code in utf8.codes(line) do
			local index, adv = glyphInfo(font, code)
			if code ~= 32 then
				local page = index // font.perPage
				local k = index % font.perPage
				for _, layer in layers do
					local img = Instance.new("ImageLabel")
					img.Name = "g"
					img.BackgroundTransparency = 1
					img.BorderSizePixel = 0
					img.Image = pages[page + 1] or ""
					img.ImageRectOffset = Vector2.new((k % font.cols) * font.cellW, (k // font.cols) * font.cellH)
					img.ImageRectSize = Vector2.new(font.cellW, font.cellH)
					img.Size = UDim2.fromOffset(font.cellW, font.cellH)
					img.Position = UDim2.fromOffset(x + layer.dx, y + layer.dy)
					img.ResampleMode = Enum.ResamplerMode.Pixelated
					img.ImageColor3 = layer.color
					img.ImageTransparency = if layer.z == 0 and self._shadowHidden then 1 else 0
					img.ZIndex = self._zIndex + layer.z
					img.Parent = self.Frame
					table.insert(self._glyphs, img)
				end
			end
			x += adv
		end
		y += font.line
	end
end

function Label:SetText(text: string)
	text = tostring(text)
	if text == self._text then
		return
	end
	self._text = text
	self:_render()
end

-- 칸 크기가 바뀌었을 때(같은 글씨를 다른 폭에 맞춰 다시 그린다)
function Label:SetMaxWidth(maxWidth: number?, maxLines: number?)
	self._maxWidth, self._maxLines = maxWidth, maxLines
	self:_render()
end

function Label:SetColor(color: Color3)
	self._color = color
	for _, g in self._glyphs do
		if g.ZIndex == self._zIndex + 1 then
			g.ImageColor3 = color
		end
	end
end

-- 그림자 색 바꾸기(nil이면 숨김)
function Label:SetShadow(color: Color3?)
	self._shadowHidden = color == nil
	if color then
		self._shadow = color
	end
	for _, g in self._glyphs do
		if g.ZIndex == self._zIndex then
			g.ImageTransparency = if color then 0 else 1
			if color then
				g.ImageColor3 = color
			end
		end
	end
end

function Label:Destroy()
	self.Frame:Destroy()
end

function exports.new(parent: Instance, props)
	local fontKey = props.Font or "body"
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "PixelText"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.Position = props.Position or UDim2.fromOffset(0, 0)
	frame.ZIndex = props.ZIndex or 5
	frame.Parent = parent
	local self = setmetatable({
		Frame = frame,
		_font = fontData[fontKey],
		_fontKey = fontKey,
		_text = tostring(props.Text or ""),
		_color = props.Color or Color3.fromRGB(20, 27, 27), -- 팩 외곽선 색(uiKit colors.ink)
		_shadow = props.Shadow,
		_align = props.Align or "left",
		_zIndex = props.ZIndex or 5,
		_maxWidth = props.MaxWidth, -- 이 폭을 넘으면 줄바꿈
		_maxLines = props.MaxLines, -- 이 줄 수를 넘으면 …로 줄임
		_glyphs = {},
	}, Label)
	self:_render()
	return self
end

return exports

end
MODULES['Client/ui/pixelUI'] = function(script, game, require, task, os, typeof, Vector2, Random, Color3, UDim2, Enum, Instance, warn, print, workspace, tick)
-- 도트 UI 부품 — 「오문 닌자전」 UI 키트(Ninja Adventure 팩 UI로 만든 아틀라스 assets/ninja/ui.png, 공방 tools/export_ninja_ui.mjs).
-- 나무 테마: 흰 패널 + 주황·갈색 테두리, 주황 입체 버튼, 회녹색 칸, 팩 아이콘(스킬 · 키 · 얼굴), 도트 글씨(pixelText — 한글 글꼴은 우리 것).
-- 패널·버튼·칸은 9분할(ScaleType.Slice)이라 어떤 크기로 늘려도 모서리가 안 깨진다.
-- 부품 이름은 shared/data/uiKit.generated.luau의 rects. 예전 분홍 키트(ui_parts)는 더 쓰지 않는다.
--
-- 좌표 단위는 "UI 도트". 화면 배율은 Scale(root)가 화면 높이에 맞춰 정수배(1·2·3·4…)로 건다 — 정수라야 도트가 고르다.
-- (예시 화면 480x270 = 1080p에서 4배 — 공방 「닌자 맵」 탭 「UI」)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local kit = require(ReplicatedStorage.shared.data["uiKit.generated"])
-- 팩 아이템 아이콘(별도 시트 — 이름 icon_nj_<키>). 키트에 없는 이름은 여기서 찾는다.
local itemIcons = require(ReplicatedStorage.shared.data["itemIcons.generated"])
local townIds = require(ReplicatedStorage.shared.config["townAssets.generated"])
local function rectOf(name: string)
	return kit.rects[name] or itemIcons.rects[name]
end
local pixelText = require(script.Parent.pixelText)

local DESIGN_HEIGHT = 270 -- 화면 높이 / 이 값 = UI 배율(내림, 최소 1)

local exports = {}
exports.Text = pixelText
exports.colors = {}
for name, c in kit.colors do
	exports.colors[name] = Color3.fromRGB(c[1], c[2], c[3])
end
local C = exports.colors

function exports.CurrentScale(): number
	local camera = Workspace.CurrentCamera
	local h = camera and camera.ViewportSize.Y or 810
	return math.max(1, math.floor(h / DESIGN_HEIGHT))
end

-- root(GuiObject)에 정수 UIScale을 걸고 화면 크기가 바뀌면 따라간다.
function exports.Scale(root: GuiObject)
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root
	local function update()
		uiScale.Scale = exports.CurrentScale()
	end
	update()
	local conn
	local function hook()
		if conn then
			conn:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			conn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	hook()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook)
	return uiScale
end

-- 부품 하나(ImageLabel 또는 ImageButton). size = Vector2(도트). 9분할 부품은 크기에 맞춰 늘어난다.
function exports.Part(parent: Instance, name: string, x: number, y: number, w: number?, h: number?, class: string?)
	local r = rectOf(name)
	assert(r, "pixelUI: 부품이 없습니다 " .. tostring(name))
	local img = Instance.new(class or "ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Image = (if kit.rects[name] then townIds.UI else townIds.ITEMS) or ""
	img.ImageRectOffset = Vector2.new(r.x, r.y)
	img.ImageRectSize = Vector2.new(r.w, r.h)
	img.ResampleMode = Enum.ResamplerMode.Pixelated
	img.Position = UDim2.fromOffset(x, y)
	img.Size = UDim2.fromOffset(w or r.w, h or r.h)
	if r.slice then
		local s = r.slice
		img.ScaleType = Enum.ScaleType.Slice
		img.SliceCenter = Rect.new(s[1], s[2], r.w - s[3], r.h - s[4])
	else
		img.ScaleType = Enum.ScaleType.Stretch
	end
	if img:IsA("GuiButton") then
		-- 로블록스 기본 "선택 표시"(누른 뒤 둘러지는 테두리)를 끈다 — 우리 버튼은 눌림 그림으로 표시한다.
		img.Selectable = false
		img.SelectionImageObject = nil
	end
	img.Parent = parent
	return img
end

-- 키트에 그 부품이 있는가(새 부품을 아직 업로드하기 전에도 안전하게 대체하려고)
function exports.Has(name: string): boolean
	return rectOf(name) ~= nil
end

-- 부품 원래 크기(도트)
function exports.Size(name: string): Vector2
	local r = rectOf(name)
	return Vector2.new(r.w, r.h)
end

-- 부품 그림 위치(같은 크기 부품끼리 그림만 바꿀 때 — 예: 탭 켜짐/꺼짐)
function exports.RectOffset(name: string): Vector2
	local r = kit.rects[name]
	return Vector2.new(r.x, r.y)
end

function exports.Panel(parent: Instance, x: number, y: number, w: number, h: number)
	return exports.Part(parent, "panel", x, y, w, h)
end

-- 아이콘: (x, y)에서 size x size 상자(기본 12) 가운데에 그림 자기 크기 그대로(정수배 — 상자 12 = 1배, 24 = 2배) 놓는다.
-- 팩 아이콘은 크기가 제각각(하트 14x12, 엽전 10x10, 아이템 16x16)이라 상자에 억지로 늘리지 않는다 — 도트가 뭉개진다.
function exports.Icon(parent: Instance, name: string, x: number, y: number, size: number?)
	local box = size or 12
	local r = rectOf("icon_" .. name)
	assert(r, "pixelUI: 아이콘이 없습니다 " .. tostring(name))
	local k = math.max(1, box // 12)
	local w, h = r.w * k, r.h * k
	local img = exports.Part(parent, "icon_" .. name, x + (box - w) // 2, y + (box - h) // 2, w, h)
	img.ZIndex = 4
	return img
end

-- 글씨. 글씨가 칸을 넘지 않게: 부모 칸의 크기가 도트로 정해져 있으면 그 안에 들어가도록 폭(MaxWidth) · 줄 수(MaxLines)를 저절로 잡는다
--  — 폭을 넘으면 줄을 바꾸고, 줄 수를 넘으면 "…"로 줄인다. 자리가 더 좁게 정해진 글씨(옆에 버튼이 있는 줄 등)는 props.MaxWidth ·
--  MaxLines를 직접 준다. 오른쪽·가운데 맞춤(Align)이거나 만든 뒤 자리를 다시 잡는 글씨는 저절로 잡지 않는다(Clamp = false로도 끔).
local PANEL_PAD = 10 -- 패널 테두리 안쪽 여백(패널 그림의 테두리가 6칸 + 숨 쉴 틈)
function exports.Label(parent: Instance, text: string, x: number, y: number, props)
	props = props or {}
	props.Text = text
	props.Position = UDim2.fromOffset(x, y)
	if props.MaxWidth == nil and props.Align == nil and props.Clamp ~= false and parent:IsA("GuiObject") then
		local size = (parent :: GuiObject).Size
		local isPanel = parent.Name == "panel"
		local room = size.X.Offset - x - (if isPanel then PANEL_PAD else 1)
		if size.X.Scale == 0 and room >= 12 then
			props.MaxWidth = room
			if props.MaxLines == nil and size.Y.Scale == 0 and size.Y.Offset > 0 then
				local _, lineHeight = pixelText.Measure("", props.Font)
				props.MaxLines = math.max(1, (size.Y.Offset - y - (if isPanel then 6 else 0)) // lineHeight)
			end
		end
	end
	return pixelText.new(parent, props)
end

-- 입체 버튼. Color = "primary"(주황 — 주된 행동) | "plain"(밝은 주황 — 그 밖). 누르는 동안 눌린 그림으로 바뀌고 내용이 1칸 내려간다.
-- 내용: Text(글씨) · Icon(icon_<이름>) · Image(부품 이름 그대로 — 스킬 아이콘처럼 큰 그림, 자기 크기로 가운데)
function exports.Button(parent: Instance, x: number, y: number, w: number, h: number, props)
	props = props or {}
	local color = props.Color or "primary"
	local btn = exports.Part(parent, "button_" .. color, x, y, w, h, "ImageButton")
	btn.AutoButtonColor = false
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = btn
	local textColor = if color == "primary" then C.white else C.ink
	local shadow = if color == "primary" then C.accentD else nil
	local label, icon
	local contentW = 0
	if props.Text then
		contentW += pixelText.Measure(props.Text, "body")
	end
	if props.Icon then
		contentW += if props.Text then 14 else 12
	end
	local cx = math.floor((w - contentW) / 2)
	local cy = math.floor((h - 2 - (if props.Text then 11 else 12)) / 2)
	if props.Image then
		local r = rectOf(props.Image)
		exports.Part(content, props.Image, (w - r.w) // 2, (h - 3 - r.h) // 2).ZIndex = 4
	end
	if props.Icon then
		icon = exports.Icon(content, props.Icon, cx, math.floor((h - 2 - 12) / 2))
		cx += 14
	end
	if props.Text then
		-- 버튼 글씨는 한 줄, 버튼 폭 안에서(넘으면 …)
		label = pixelText.new(content, { Text = props.Text, Color = textColor, Position = UDim2.fromOffset(math.max(cx, 2), cy), Shadow = shadow, MaxWidth = w - 4, MaxLines = 1 })
	end
	local obj = { Instance = btn, Label = label, enabled = true }
	local function look(pressed: boolean)
		if not obj.enabled then
			local r = kit.rects.button_disabled
			btn.ImageRectOffset = Vector2.new(r.x, r.y)
			content.Position = UDim2.fromOffset(0, 0)
			return
		end
		local r = kit.rects["button_" .. color .. (if pressed then "_pressed" else "")]
		btn.ImageRectOffset = Vector2.new(r.x, r.y)
		content.Position = UDim2.fromOffset(0, if pressed then 1 else 0)
	end
	btn.MouseButton1Down:Connect(function()
		look(true)
	end)
	btn.MouseButton1Up:Connect(function()
		look(false)
	end)
	btn.MouseLeave:Connect(function()
		look(false)
	end)
	btn.Activated:Connect(function()
		if obj.enabled and props.OnClick then
			props.OnClick()
		end
	end)
	function obj:SetEnabled(on: boolean)
		obj.enabled = on
		if label then
			-- 꺼진 버튼(어두운 갈색)은 밝은 글씨만(그림자 숨김)
			label:SetColor(if on then textColor else C.paper)
			label:SetShadow(if on then shadow else nil)
		end
		look(false)
	end
	function obj:SetText(text: string)
		if label then
			label:SetText(text)
		end
	end
	return obj
end

-- 게이지(체력 red·경험치 yellow·sky·mint). w = 전체 폭(도트), 높이 9.
function exports.Bar(parent: Instance, x: number, y: number, w: number, color: string)
	local frame = exports.Part(parent, "bar_frame", x, y, w, 9)
	local fill = exports.Part(frame, "bar_fill_" .. color, 1, 1, 0, 7)
	fill.ZIndex = frame.ZIndex + 1
	local obj = { Instance = frame }
	function obj:SetRatio(r: number)
		fill.Size = UDim2.fromOffset(math.floor((w - 2) * math.clamp(r, 0, 1) + 0.5), 7)
	end
	obj:SetRatio(0)
	return obj
end

-- 인벤토리 칸(누를 수 있음). 선택하면 주황 테두리.
function exports.Slot(parent: Instance, x: number, y: number, size: number)
	local btn = exports.Part(parent, "slot", x, y, size, size, "ImageButton")
	btn.AutoButtonColor = false
	local obj = { Instance = btn }
	function obj:SetSelected(on: boolean)
		local r = kit.rects[if on then "slot_selected" else "slot"]
		btn.ImageRectOffset = Vector2.new(r.x, r.y)
	end
	return obj
end

-- 개수·레벨 표시용 알약 모양(주황 또는 어두운 바탕)
function exports.Pill(parent: Instance, x: number, y: number, w: number, h: number, dark: boolean?)
	return exports.Part(parent, if dark then "pill_dark" else "pill", x, y, w, h)
end

-- 패널 위에 걸치는 제목판(제목 16px 글씨). cx = 가운데 x.
function exports.TitleTag(parent: Instance, text: string, cx: number, y: number)
	local w = pixelText.Measure(text, "title") + 16
	local plate = exports.Part(parent, "tag", cx - math.floor(w / 2), y, w, 26)
	plate.ZIndex = 6
	local label = pixelText.new(plate, { Text = text, Font = "title", Color = C.paper, Position = UDim2.fromOffset(8, 3), ZIndex = 7 })
	return plate, label
end

return exports

end
runTest('01_shared', function()
-- 공용 데이터: 아이템 표 · 가게 · 드롭 표 · 몬스터 레벨 · 씬 도우미
local items = req("ReplicatedStorage/shared/data/items")
local shops = req("ReplicatedStorage/shared/config/shops")
local drops = req("ReplicatedStorage/shared/config/drops")
local townWorld = req("ReplicatedStorage/shared/data/townWorld")
local monsterLevels = req("ReplicatedStorage/shared/config/monsterLevels")
local itemIcons = req("ReplicatedStorage/shared/data/itemIcons.generated")
local kit = req("ReplicatedStorage/shared/data/uiKit.generated")
local world = townWorld.data

-- 닌자 아이템이 표에 합쳐졌는가 · 투척 무기 수치
for _, id in { "Shuriken", "Kunai", "Bomb" } do
	local def = items[id]
	expect(def and def.Type == "Throw" and def.Tab == "Use", id .. " 투척 무기")
	expect(def.Throw.power > 0 and def.Throw.range > 0 and def.Throw.speed > 0, id .. " 수치")
end
expect(items.Bomb.Throw.radius and items.Bomb.Throw.radius > 0, "폭탄 범위")
expect(items.Onigiri.Heal == 40, "주먹밥 회복량")

-- 모든 아이템: 아이콘 이름이 실제로 있는가(도트 UI 키트 또는 팩 아이템 시트)
for id, def in items do
	if def.KitIcon and def.KitIcon ~= "" then
		local name = "icon_" .. def.KitIcon
		expect(kit.rects[name] ~= nil or itemIcons.rects[name] ~= nil, ("%s 아이콘 %s 없음"):format(id, name))
	end
end

-- 아이템은 전부 팩 그림(옛 도트 UI 키트 아이콘을 쓰는 아이템이 없어야 한다)
for id, def in items do
	expect(typeof(def.KitIcon) == "string" and string.sub(def.KitIcon, 1, 3) == "nj_" and itemIcons.rects["icon_" .. def.KitIcon] ~= nil, id .. " 은 팩 아이콘")
end
for _, legacy in { "WoodenSword", "LeafArmor", "RedPotion", "OrangePotion", "WhitePotion", "Bell1", "RainbowEgg", "SproutFragment", "Mat_piyo" } do
	expect(items[legacy] == nil, "옛 아이템이 표에 없음 " .. legacy)
end

-- UI 키트(팩 UI): 게임 코드가 쓰는 부품 · 색이 전부 있다
for _, name in { "panel", "tag", "tab_on", "tab_off", "button_primary", "button_primary_pressed", "button_plain", "button_plain_pressed", "button_disabled",
	"pill", "pill_dark", "slot", "slot_selected", "bar_frame", "bar_fill_red", "bar_fill_yellow", "bar_fill_sky", "bar_fill_mint", "bubble", "dialog_face",
	"icon_heart", "icon_coin", "icon_bag", "icon_book", "icon_gear", "icon_close", "icon_energy", "act_attack", "act_talk",
	"key_q", "key_r", "key_1", "key_2", "key_3", "key_e", "key_f" } do
	expect(kit.rects[name] ~= nil, "UI 부품 " .. name)
end
for _, name in { "ink", "white", "paper", "accent", "accentD", "accentL", "goodD", "grayD" } do
	expect(kit.colors[name] ~= nil, "UI 색 " .. name)
end
-- 그림 자리만 바꿔 끼우는 짝은 크기 · 9분할이 같아야 한다
for _, pair in { { "tab_on", "tab_off" }, { "slot", "slot_selected" }, { "button_primary", "button_primary_pressed" }, { "button_primary", "button_disabled" }, { "button_plain", "button_plain_pressed" }, { "button_plain", "button_disabled" } } do
	local a, b = kit.rects[pair[1]], kit.rects[pair[2]]
	expect(a.w == b.w and a.h == b.h and table.concat(a.slice, ",") == table.concat(b.slice, ","), ("%s / %s 크기 · 9분할 같음"):format(pair[1], pair[2]))
end
local ninjutsuConfig = req("ReplicatedStorage/shared/config/ninjutsu")
for id in ninjutsuConfig.SKILLS do
	local on, off = kit.rects["skill_" .. id], kit.rects["skill_" .. id .. "_off"]
	expect(on ~= nil and off ~= nil and on.w == off.w and on.h == off.h, "인술 아이콘 " .. id)
end
for _, id in ninjutsuConfig.SCHOOLS do
	expect(kit.rects["face_school_" .. id] ~= nil, "유파 얼굴 그림 " .. id)
end
for _, t in world.npcTypes do
	expect(kit.rects["face_" .. t.id] ~= nil, "NPC 얼굴 그림 " .. t.id)
end

-- 가게: 파는 물건이 전부 아이템 표에 있고 값이 있다
for shopId, shop in shops do
	for _, id in shop.goods do
		expect(items[id] ~= nil and (items[id].Price or 0) > 0, ("가게 %s의 %s"):format(shopId, id))
	end
end

-- 드롭 표: 지역이 전부 있고, 아이템이 실제로 있고, 확률이 0~1
for _, r in world.regions do
	local list = drops.REGION[r.id]
	expect(list ~= nil and #list > 0, "드롭 표 없음 " .. r.id)
	for _, d in list or {} do
		expect(items[d.item] ~= nil, ("드롭 아이템 없음 %s/%s"):format(r.id, d.item))
		expect(d.chance > 0 and d.chance <= 1, "확률 범위 " .. d.item)
	end
end
-- 굴림 통계: 들판에서 2000번 굴리면 풀잎이 35% 근처
local rng = RandomNew(7)
local grass, total = 0, 2000
for _ = 1, total do
	for _, d in drops.Roll("field", rng) do
		if d.item == "GrassBlade" then grass += 1 end
	end
end
expect(math.abs(grass / total - 0.35) < 0.04, ("풀잎 드롭률 %.3f"):format(grass / total))
eq(#drops.Roll("없는지역", rng), 0, "모르는 지역은 드롭 없음")

-- 몬스터 레벨: 종 범위 안에서만 나오고, 낮은 레벨이 더 흔하다
local lo, hi = monsterLevels.LevelRange(1)
eq(lo, 1, "말랑이 최소 레벨"); eq(hi, 4, "말랑이 최대 레벨")
local counts = {}
for _ = 1, 3000 do
	local l = monsterLevels.RollLevel(1, rng)
	expect(l >= lo and l <= hi, "레벨 범위 밖 " .. l)
	counts[l] = (counts[l] or 0) + 1
end
expect(counts[1] > counts[4], "낮은 레벨이 더 흔함")

-- 씬 도우미
eq(townWorld.StartSceneName(), "town_village", "시작 씬")
eq(townWorld.KeyOf("town_field1"), "field1", "씬 키")
expect(townWorld.KeyOf("town_없는씬") == nil, "없는 씬")
local off = townWorld.MonsterFrameOffset(18, 2 * 4 + 1) -- 18번째 종(둘째 줄 2번째), 왼쪽 보기, 걷기 2번째 장
eq(off.X, 1 * 64 + 2 * 16, "시트 x"); eq(off.Y, 1 * 64 + 1 * 16, "시트 y")
local d = townWorld.Get("village")
expect(not townWorld.BoxBlocked(d, d.spawn.x, d.spawn.y, world.playerFeet.halfW, world.playerFeet.h), "마을 시작 자리")
expect(townWorld.IsBlocked(d, -1, 10), "맵 밖은 막힘")

end)
runTest('02_schema', function()
-- 저장 데이터: 새 플레이어 기본값 · 옛 저장 데이터를 지금 버전으로 올리기(옛 아이템은 팩 아이템으로 바뀌거나 없어진다)
local schema = req("ServerScriptService/server/services/playerSchema")
local items = req("ReplicatedStorage/shared/data/items")

local function count(data, id)
	local n = 0
	for _, e in data.Inventory do
		if e.ItemId == id then n += e.Count end
	end
	return n
end
local function slotsUnique(data)
	local seen = {}
	for _, e in data.Inventory do
		local key = e.Tab .. ":" .. e.Slot
		if seen[key] then return false end
		seen[key] = true
	end
	return true
end

-- 새 플레이어
local fresh = schema.default()
eq(fresh.SchemaVersion, schema.CURRENT_VERSION, "새 플레이어 버전")
eq(count(fresh, "Shuriken"), 30, "새 플레이어 수리검")
eq(count(fresh, "Onigiri"), 5, "새 플레이어 주먹밥")
eq(count(fresh, "Ninjato"), 1, "새 플레이어 닌자도")
eq(fresh.Job, 0, "새 플레이어 = 견습(전직 0)")
eq(#fresh.Inventory, 3, "새 플레이어 가방에는 팩 아이템 세 가지만")
eq(fresh.QuickSlots[1], "Shuriken", "단축칸 1")
eq(fresh.QuickSlots[2], "Onigiri", "단축칸 2")
expect(slotsUnique(fresh), "새 플레이어 가방 칸 겹침 없음")
for _, e in fresh.Inventory do
	expect(items[e.ItemId] ~= nil, "시작 물건이 아이템 표에 있음 " .. e.ItemId)
end

-- 옛 저장 데이터(v6, 방울을 단축칸에 둔 사람) → v7
local old = {
	SchemaVersion = 6, Level = 12, Experience = 30, MaxExperience = 650, Health = 200, Gold = 777,
	Inventory = {
		{ Tab = "Equip", Slot = 1, ItemId = "WoodenSword", Count = 1 },
		{ Tab = "Use", Slot = 1, ItemId = "RedPotion", Count = 3 },
		{ Tab = "Use", Slot = 2, ItemId = "Bell1", Count = 7 },
	},
	Equipment = { Weapon = "WoodenSword" }, Dex = { piyo = 1 },
	Pets = { Box = {}, Party = {}, Slots = 1, Boxes = 8 }, Life = { Mine = 0, Craft = 0 },
	QuickSlots = { "Bell1", "RedPotion", "" },
}
local migrate = schema.migrate or schema.Migrate or schema.upgrade or schema.Upgrade or schema.normalize or schema.Normalize
expect(migrate ~= nil, "마이그레이션 함수가 있음")
if migrate then
	local data = migrate(old) or old
	eq(data.SchemaVersion, schema.CURRENT_VERSION, "옛 데이터 버전")
	eq(data.Level, 12, "레벨 유지"); eq(data.Gold, 777, "엽전 유지")
	eq(count(data, "Shuriken"), 30, "수리검 지급")
	eq(count(data, "Onigiri"), 5 + 3, "주먹밥 지급 5 + 옛 빨간 물약 3개가 주먹밥으로")
	eq(count(data, "Bell1"), 0, "방울은 없어짐"); eq(count(data, "RedPotion"), 0, "옛 물약은 남지 않음")
	eq(count(data, "WoodenSword"), 0, "옛 나무 검은 남지 않음")
	eq(data.Equipment.Weapon, "Ninjato", "끼고 있던 나무 검 → 닌자도")
	expect(slotsUnique(data), "가방 칸 겹침 없음")
	for _, e in data.Inventory do
		expect(items[e.ItemId] ~= nil, "남은 물건은 전부 아이템 표에 있음 " .. e.ItemId)
	end
	eq(data.QuickSlots[1], "Shuriken", "단축칸 1: 방울 자리 → 수리검")
	eq(data.QuickSlots[2], "Onigiri", "단축칸 2: 빨간 물약 → 주먹밥")
	eq(data.QuickSlots[3], "", "단축칸 3: 같은 아이템은 한 칸만")
	local hasShuriken = false
	for i = 1, 3 do
		if data.QuickSlots[i] == "Shuriken" then hasShuriken = true end
	end
	expect(hasShuriken, "단축칸에 수리검이 들어감")
	-- 한 번 더 올려도 또 지급되지 않는다
	local again = migrate(data) or data
	eq(count(again, "Shuriken"), 30, "두 번 지급 안 됨")
end

-- 아주 옛 저장 데이터(v1 — 탭이 없던 시절): 옛 아이템이 사라지지 않고 팩 아이템으로 바뀐다
do
	local v1 = { SchemaVersion = 1, Level = 3, Experience = 0, MaxExperience = 200, Gold = 10, Equipment = { Armor = "LeafArmor" },
		Inventory = { { Slot = 1, ItemId = "WoodenSword", Count = 1 }, { Slot = 2, ItemId = "OrangePotion", Count = 2 }, { Slot = 3, ItemId = "Mat_piyo", Count = 9 } } }
	local data = schema.migrate(v1)
	expect(count(data, "Ninjato") >= 1, "v1 나무 검 → 닌자도")
	eq(count(data, "Sushi"), 2, "v1 주황 물약 → 초밥")
	eq(count(data, "Mat_piyo"), 0, "v1 몬스터 재료는 없어짐")
	eq(data.Equipment.Armor, "GuardCharm", "v1 잎사귀 갑옷 → 수호 부적")
	expect(slotsUnique(data), "v1 가방 칸 겹침 없음")
	for _, e in data.Inventory do
		expect(items[e.ItemId] ~= nil, "v1 남은 물건은 전부 아이템 표에 있음 " .. e.ItemId)
	end
end

-- v10 → v11(전직): 유파가 이미 있으면 그 레벨까지 전직한 것으로, 없으면 견습
do
	local a = schema.default(); a.SchemaVersion, a.Job, a.School, a.Level = 10, nil, "fire", 3
	eq(schema.migrate(a).Job, 1, "유파가 있는 Lv.3 → 1차(그대로 둠)")
	local b = schema.default(); b.SchemaVersion, b.Job, b.School, b.Level = 10, nil, "ice", 64
	eq(schema.migrate(b).Job, 3, "유파가 있는 Lv.64 → 3차")
	local c = schema.default(); c.SchemaVersion, c.Job, c.School, c.Level = 10, nil, "", 40
	eq(schema.migrate(c).Job, 0, "유파가 없으면 견습")
end

end)
runTest('03_combat', function()
-- 서버 전투(townMonsters · quickSlots): 가짜 플레이어 둘로 공격 · 쿨타임 · 처치 보상 · 기여도 · 투척 무기 · 폭탄 · 반격 · 리스폰
local world = req("ReplicatedStorage/shared/data/townWorld").data
local items = req("ReplicatedStorage/shared/data/items")
local balance = req("ReplicatedStorage/shared/config/balance")
local combat = req("ReplicatedStorage/shared/config/combat")
local monsterLevels = req("ReplicatedStorage/shared/config/monsterLevels")
local schema = req("ServerScriptService/server/services/playerSchema")

-- ---- 가짜 플레이어 · 서비스 ----
local p1 = { UserId = 1, Name = "닌자1", Parent = {} }
local p2 = { UserId = 2, Name = "닌자2", Parent = {} }
local byId = { [1] = p1, [2] = p2 }
local data = { [p1] = schema.default(), [p2] = schema.default() }
local where = { [1] = "town_field1", [2] = "town_field1" }
local pos = { [1] = V(0, 0), [2] = V(0, 0) } -- 화면 px(= 도트 × world.scale)
local function standAt(player, x, y) pos[player.UserId] = V(x * world.scale, y * world.scale) end

local events = {} -- { name, player, args }
local handlers = {}
local function sent(name, player)
	local out = {}
	for _, e in events do
		if e.name == name and (player == nil or e.player == player) then table.insert(out, e) end
	end
	return out
end
local function clear() table.clear(events) end

MOCK("ReplicatedStorage/shared/net/net", {
	FireClient = function(name, player, ...) table.insert(events, { name = name, player = player, args = { ... } }) end,
	OnServer = function(name, fn) handlers[name] = fn end,
})
MOCK("ServerScriptService/server/modules/heroTracking", {
	PlayersInScene = function(sceneName)
		local list = {}
		for id, s in where do
			if s == sceneName then table.insert(list, byId[id]) end
		end
		return list
	end,
	GetPosition = function(userId) return pos[userId] end,
	GetPlayerScene = function(userId) return where[userId] end,
	OnSceneChanged = function() end,
})
MOCK("ServerScriptService/server/modules/worldDrops", { List = function() return {} end })
MOCK("ServerScriptService/server/services/persistence", {
	Get = function(player) return data[player] end,
	MarkDirty = function() end,
	Save = function() end,
})
local expGiven, hurt = {}, {}
MOCK("ServerScriptService/server/services/progressionService", {
	AddExperience = function(player, n) expGiven[player] = (expGiven[player] or 0) + n end,
	DamagePlayer = function(player, n) hurt[player] = (hurt[player] or 0) + n end,
	Heal = function() return 0 end, -- 체력이 가득한 상태로 둔다
})
MOCK("ServerScriptService/server/services/currencyService", {
	AddGold = function(player, n) data[player].Gold += n end,
})
local heartbeat
SERVICE("Players", { GetPlayerByUserId = function(_, id) return byId[id] end, PlayerRemoving = { Connect = function() end } })
SERVICE("RunService", { Heartbeat = { Connect = function(_, fn) heartbeat = fn; return { Disconnect = function() end } end } })

local inventory = req("ServerScriptService/server/services/inventoryService")
local townMonsters = req("ServerScriptService/server/modules/townMonsters")
local quickSlots = req("ServerScriptService/server/modules/quickSlots")
townMonsters.load()
quickSlots.load()

-- ---- 1) 씬 상태 ----
local state = handlers.GetTownState(p1)
eq(state.scene, "field1", "내 씬")
local zoneTotal = 0
for _, z in world.scenes.field1.zones do zoneTotal += z.count end
eq(#state.monsters, zoneTotal, "구역 수만큼 몬스터가 나타남")
for _, w in state.monsters do
	local lo, hi = monsterLevels.LevelRange(w.row)
	expect(w.level >= lo and w.level <= hi, "몬스터 레벨 범위")
	eq(w.maxHp, monsterLevels.MaxHealth(w.level), "최대 체력")
end
where[1] = "town_village"
eq(#handlers.GetTownState(p1).monsters, 0, "마을에는 몬스터 없음")
where[1] = "town_field1"

local function living() return townMonsters.Living("field1") end
local function lastHit(id)
	local found
	for _, e in sent("TownMonsterHit") do
		if e.args[2] == id then found = e end
	end
	return found
end
local ATTACK = balance.BASE_ATTACK -- 맨손(무기 미착용)
eq(inventory.GetAttackDamage(p1), ATTACK, "맨손 공격력")

-- ---- 2) 기본 공격: 앞 범위 판정 · 쿨타임 ----
local m = living()[1]
m.maxHp, m.hp = 100, 100
standAt(p1, m.x - 10, m.y) -- 몬스터 왼쪽 10도트, 오른쪽을 보고 때린다
clear()
handlers.TownAttack(p1, "right")
eq(m.hp, 100 - ATTACK, "한 대 맞은 체력")
local hit = lastHit(m.id)
expect(hit and hit.args[3] == 100 - ATTACK and hit.args[4] == ATTACK and hit.args[5] == 1, "TownMonsterHit 내용")
eq(#sent("TownMonsterHit", p2), 1, "같은 씬의 다른 사람도 피격을 받음")
handlers.TownAttack(p1, "right")
eq(m.hp, 100 - ATTACK, "쿨타임 안의 두 번째 공격은 무시")
advance(balance.TOWN_ATTACK_COOLDOWN + 0.05)
handlers.TownAttack(p1, "left")
eq(m.hp, 100 - ATTACK, "반대쪽을 보면 안 맞음")
advance(balance.TOWN_ATTACK_COOLDOWN + 0.05)
standAt(p1, m.x - combat.ATTACK_REACH - 6, m.y)
handlers.TownAttack(p1, "right")
eq(m.hp, 100 - ATTACK, "범위 밖은 안 맞음")

-- ---- 3) 기여도 10% 규칙 + 처치 보상 ----
local big = living()[2]
big.maxHp, big.hp = 1000, 1000
advance(1)
standAt(p2, big.x - 10, big.y)
handlers.TownAttack(p2, "right") -- p2는 10 피해(1%) — 기여도 부족
eq(big.hp, 1000 - ATTACK, "p2 한 대")
local goldBefore, itemsBefore = data[p1].Gold, #data[p1].Inventory
clear()
expect(townMonsters.Damage("field1", big.id, p1, 2000, "test"), "p1이 마무리")
expect(big.dead, "쓰러짐")
eq(#sent("TownMonsterDied", p1), 1, "죽음 알림")
eq(expGiven[p1], monsterLevels.Experience(big.level), "p1 경험치")
expect(expGiven[p2] == nil, "p2는 기여도 부족 → 경험치 없음")
expect(data[p1].Gold > goldBefore, "p1 엽전")
local species = world.species[big.row]
eq(data[p1].Dex[species.id], 1, "도감 봤음")
local notice = sent("Notify", p2)
expect(#notice == 1 and string.find(notice[1].args[1], "기여도") ~= nil, "p2 기여도 부족 알림")
expect(#data[p1].Inventory >= itemsBefore, "드롭은 가방으로")
-- 리스폰
clear()
advance(combat.MONSTER_RESPAWN + 0.1)
expect(not big.dead and big.hp == big.maxHp, "리스폰")
eq(#sent("TownMonsterSpawned", p1), 1, "리스폰 알림")

-- 드롭 통계: 들판 몬스터 300마리 → 풀잎이 가방에 들어온다
local function countItem(player, id) return inventory.CountItem(player, id) end
local grassBefore = countItem(p1, "GrassBlade")
for _ = 1, 300 do
	local t = living()[3]
	t.maxHp, t.hp = 10, 10
	townMonsters.Damage("field1", t.id, p1, 10, "test")
	advance(combat.MONSTER_RESPAWN + 0.1)
end
local gained = countItem(p1, "GrassBlade") - grassBefore
expect(gained > 75 and gained < 135, ("풀잎 드롭 %d개(300마리 × 35%% = 기대 약 105개 — 99개를 넘으면 다음 칸에 쌓인다)"):format(gained))

-- ---- 4) 투척 무기 ----
local target = living()[4]
target.maxHp, target.hp = 500, 500
-- 다른 몬스터가 사이에 끼지 않게 멀리 치운다
for _, o in living() do
	if o ~= target then o.x, o.y = 8, 8 end
end
target.x, target.y = 300, 200
standAt(p1, 250, 200)
advance(1)
local shBefore = countItem(p1, "Shuriken")
clear()
expect(townMonsters.ThrowWeapon(p1, "Shuriken", "right"), "수리검 던지기")
eq(countItem(p1, "Shuriken"), shBefore - 1, "1개 소모")
local thrown = sent("ProjectileThrown", p1)[1]
expect(thrown and thrown.args[3] == "Shuriken" and math.abs(thrown.args[8] - 50) < 1, "날아가는 거리 = 몬스터까지 50도트")
eq(target.hp, 500, "아직 날아가는 중")
expect(not townMonsters.ThrowWeapon(p1, "Shuriken", "right"), "투척 쿨타임")
eq(countItem(p1, "Shuriken"), shBefore - 1, "쿨타임 때는 소모 안 됨")
advance(50 / items.Shuriken.Throw.speed + 0.02)
eq(target.hp, 500 - math.round(ATTACK * items.Shuriken.Throw.power), "도착하면 공격력 × 0.8 피해")
-- 빗나감: 반대쪽으로
advance(1)
clear()
expect(townMonsters.ThrowWeapon(p1, "Shuriken", "left"), "빗나가도 던져짐")
eq(sent("ProjectileThrown", p1)[1].args[8], items.Shuriken.Throw.range, "빗나가면 끝까지 날아감")
advance(1)
eq(target.hp, 500 - math.round(ATTACK * items.Shuriken.Throw.power), "빗나가면 피해 없음")
-- 사거리 밖
standAt(p1, 300 - items.Shuriken.Throw.range - 20, 200)
townMonsters.ThrowWeapon(p1, "Shuriken", "right")
advance(1)
eq(target.hp, 500 - math.round(ATTACK * items.Shuriken.Throw.power), "사거리 밖은 안 맞음")
-- 없는 아이템
expect(not townMonsters.ThrowWeapon(p1, "Kunai", "right"), "없는 쿠나이는 못 던짐")
expect(not townMonsters.ThrowWeapon(p1, "Onigiri", "right"), "투척 무기가 아니면 안 됨")

-- 폭탄: 둘레 모두
inventory.AddItem(p1, "Bomb", 2)
local a, b, far = living()[5], living()[6], living()[7]
for _, o in { a, b, far } do o.maxHp, o.hp = 500, 500 end
target.x, target.y = 8, 8
a.x, a.y = 300, 200
b.x, b.y = 312, 206
far.x, far.y = 300 + items.Bomb.Throw.radius + 30, 200
standAt(p1, 260, 200)
advance(1)
expect(townMonsters.ThrowWeapon(p1, "Bomb", "right"), "폭탄 던지기")
advance(1)
local bombDamage = math.round(ATTACK * items.Bomb.Throw.power)
eq(a.hp, 500 - bombDamage, "폭탄: 맞은 몬스터")
eq(b.hp, 500 - bombDamage, "폭탄: 옆 몬스터도")
eq(far.hp, 500, "폭탄: 범위 밖은 안 맞음")

-- ---- 5) 반격: 맞은 몬스터가 쫓아와 때린다 ----
standAt(p1, 270, 200)
hurt[p1] = nil
for _ = 1, 80 do
	advance(0.1)
	heartbeat(0.1)
end
expect((hurt[p1] or 0) > 0, "쫓아와서 공격함")
local d = math.sqrt((a.x - 270) ^ 2 + (a.y - 200) ^ 2)
expect(d <= combat.MONSTER_ATTACK_RANGE + 2, ("몬스터가 가까이 옴(거리 %.1f)"):format(d))

-- ---- 6) 단축칸: 수리검 던지기 · 방울(포획)은 꺼져 있음 ----
advance(1)
clear()
handlers.UseQuickSlot(p1, 1, "right") -- 1번 칸 = 수리검(v7 기본)
eq(#sent("ProjectileThrown", p1), 1, "단축칸 1 → 수리검")
handlers.UseQuickSlot(p1, 2, "right") -- 2번 칸 = 주먹밥, 체력 가득
local full = sent("Notify", p1)
expect(#full == 1 and string.find(full[1].args[1], "가득") ~= nil, "체력 가득이면 안 먹음")
expect(not townMonsters.ThrowBell(p1, "Bell1", "right"), "포획은 꺼져 있음")
handlers.SetQuickSlot(p1, 3, "Kunai")
eq(data[p1].QuickSlots[3], "Kunai", "단축칸 3에 쿠나이 놓기")
handlers.SetQuickSlot(p1, 3, "Ninjato")
eq(data[p1].QuickSlots[3], "Kunai", "소비 탭이 아닌 것은 못 놓음")

end)
runTest('04_ninjutsu', function()
-- 유파와 인술(N2): 설정 정합성 · 유파 고르기/바꾸기 · 기력 · 쿨타임 · 인술 종류별 판정(투사체 · 직선 · 둘레 · 연쇄 · 회복 · 방어)
--  · 상태 이상(느려짐 · 멈춤 · 밀림 · 불붙음) · 두루마리(단계) · 두루마리 드롭률
local world = req("ReplicatedStorage/shared/data/townWorld").data
local townWorld = req("ReplicatedStorage/shared/data/townWorld")
local items = req("ReplicatedStorage/shared/data/items")
local itemIcons = req("ReplicatedStorage/shared/data/itemIcons.generated")
local balance = req("ReplicatedStorage/shared/config/balance")
local combat = req("ReplicatedStorage/shared/config/combat")
local drops = req("ReplicatedStorage/shared/config/drops")
local monsterLevels = req("ReplicatedStorage/shared/config/monsterLevels")
local ninjutsu = req("ReplicatedStorage/shared/config/ninjutsu")
local packets = req("ReplicatedStorage/shared/net/packets")
local schema = req("ServerScriptService/server/services/playerSchema")
local SK = ninjutsu.SKILLS

-- ---- 1) 설정 정합성 ----
eq(#ninjutsu.SCHOOLS, #world.schools, "유파 수 = 캐릭터 시트 유파 수")
for i, id in ninjutsu.SCHOOLS do
	eq(world.schools[i].id, id, "유파 순서 = 시트 줄 순서 " .. id)
	eq(ninjutsu.SchoolIndex(id), i - 1, "유파 번호 " .. id)
	local info = ninjutsu.SCHOOL_INFO[id]
	expect(info ~= nil and #info.skills == #ninjutsu.JOB_LEVELS, "유파 정보 · 전직마다 인술 하나 " .. id)
	for slot, sid in info.skills do
		local s = SK[sid]
		expect(s ~= nil and s.school == id, ("인술 %s 는 %s 유파"):format(sid, id))
		eq(ninjutsu.SkillFor(id, slot), sid, "칸 → 인술 " .. sid)
	end
end
eq(ninjutsu.SchoolIndex(""), 0, "유파 없음 → 0번 줄")
-- 전직 레벨 10 · 30 · 60 · 100(사용자 지시)
eq(table.concat(ninjutsu.JOB_LEVELS, ","), "10,30,60,100", "전직 레벨")
eq(ninjutsu.JobFor(1), 0, "Lv.1 = 견습"); eq(ninjutsu.JobFor(9), 0, "Lv.9 = 견습"); eq(ninjutsu.JobFor(10), 1, "Lv.10 = 1차")
eq(ninjutsu.JobFor(59), 2, "Lv.59 = 2차"); eq(ninjutsu.JobFor(60), 3, "Lv.60 = 3차"); eq(ninjutsu.JobFor(100), 4, "Lv.100 = 4차")
for job = 0, #ninjutsu.JOB_LEVELS do
	expect(typeof(ninjutsu.JOB_NAMES[job]) == "string", "계급 이름 " .. job)
end
expect(packets.JobAdvance ~= nil, "패킷 등록 JobAdvance")
expect(ninjutsu.SkillFor("", 1) == nil, "유파 없음 → 인술 없음")
local NEED = {
	projectile = { "range", "speed", "width", "radius", "power" },
	line = { "length", "width", "power" },
	circle = { "radius", "power" },
	chain = { "range", "jumps", "jumpRange", "power", "falloff" },
	heal = { "ratio" },
	guard = { "mult", "seconds" },
}
NEED.seed = { "range", "speed", "width", "radius", "power", "fuse", "burstPower" }
NEED.zone = { "radius", "seconds", "interval" }
NEED.buff = { "radius", "seconds" }
NEED.detonate = { "radius", "power", "spread" }
NEED.shatter = { "radius", "power" }
NEED.discharge = { "radius", "radiusPer", "power", "powerPer" }
NEED.decoy = { "radius", "seconds", "frost" }
NEED.counter = { "window", "radius", "power" }
for id, s in SK do
	expect(typeof(s.name) == "string" and typeof(s.desc) == "string", "이름 · 설명 " .. id)
	if s.kind == "passive" then
		continue -- 패시브 · 핵심 장치(쓰는 인술이 아님) — 09_skills.luau
	end
	expect(NEED[s.kind] ~= nil, "알려진 종류 " .. id)
	expect((s.cost > 0 or s.vigorCost ~= nil) and s.cost <= ninjutsu.ENERGY_MAX and s.cooldown > 0, "기력(또는 생기) · 쿨타임 " .. id)
	for _, f in NEED[s.kind] or {} do
		expect(typeof(s[f]) == "number", ("%s.%s"):format(id, f))
	end
end
eq(ninjutsu.LevelScale(1), 1, "1단계 보정")
eq(ninjutsu.LevelScale(99), 1 + (ninjutsu.MAX_LEVEL - 1) * ninjutsu.LEVEL_BONUS, "최고 단계 보정")
for _, name in { "ChooseSchool", "UseNinjutsu", "SchoolUpdated", "EnergyUpdated", "NinjutsuCast", "TownMonsterStatus" } do
	expect(packets[name] ~= nil, "패킷 등록 " .. name)
end
for _, id in ninjutsu.SCHOOLS do
	expect(packets.ChooseSchool.Args[1](id), "ChooseSchool 인자 " .. id)
end
expect(not packets.ChooseSchool.Args[1]("water"), "없는 유파는 거름")
for _, sid in drops.SCROLLS do
	local def = items[sid]
	expect(def ~= nil and def.Type == "Scroll" and ninjutsu.SCHOOL_INFO[def.School] ~= nil, "두루마리 아이템 " .. sid)
	expect(def ~= nil and itemIcons.rects["icon_" .. def.KitIcon] ~= nil, "두루마리 아이콘 " .. sid)
end

-- ---- 2) 저장 형태 ----
local fresh = schema.default()
eq(fresh.School, "", "새 플레이어: 유파 없음")
expect(typeof(fresh.Ninjutsu) == "table" and next(fresh.Ninjutsu) == nil, "새 플레이어: 인술 단계표 비어 있음")
local old = schema.default()
old.SchemaVersion, old.School, old.Ninjutsu = 7, nil, nil
schema.migrate(old)
expect(old.School == "" and typeof(old.Ninjutsu) == "table" and old.SchemaVersion == schema.CURRENT_VERSION, "v7 → v8 마이그레이션")

-- ---- 가짜 플레이어 · 서비스 ----
local p1 = { UserId = 1, Name = "닌자1", Parent = {} }
local p2 = { UserId = 2, Name = "닌자2", Parent = {} }
local byId = { [1] = p1, [2] = p2 }
local data = { [p1] = schema.default(), [p2] = schema.default() }
local where = { [1] = "town_field1", [2] = "town_field1" }
local pos = { [1] = V(0, 0), [2] = V(0, 0) }
local function standAt(player, x, y) pos[player.UserId] = V(x * world.scale, y * world.scale) end

local events, handlers = {}, {}
local function sent(name, player)
	local out = {}
	for _, e in events do
		if e.name == name and (player == nil or e.player == player) then table.insert(out, e) end
	end
	return out
end
local function clear() table.clear(events) end
local function noticed(player, word)
	for _, e in sent("Notify", player) do
		if string.find(e.args[1], word, 1, true) then return true end
	end
	return false
end

MOCK("ReplicatedStorage/shared/net/net", {
	FireClient = function(name, player, ...) table.insert(events, { name = name, player = player, args = { ... } }) end,
	OnServer = function(name, fn) handlers[name] = fn end,
})
MOCK("ServerScriptService/server/modules/heroTracking", {
	PlayersInScene = function(sceneName)
		local list = {}
		for id, s in where do
			if s == sceneName then table.insert(list, byId[id]) end
		end
		return list
	end,
	GetPosition = function(userId) return pos[userId] end,
	GetPlayerScene = function(userId) return where[userId] end,
	OnSceneChanged = function() end,
})
MOCK("ServerScriptService/server/modules/worldDrops", { List = function() return {} end })
MOCK("ServerScriptService/server/services/persistence", {
	Get = function(player) return data[player] end,
	MarkDirty = function() end,
	Save = function() end,
})
local hurts = {} -- 몬스터에게 맞은 피해 기록
MOCK("ServerScriptService/server/services/progressionService", {
	AddExperience = function() end,
	DamagePlayer = function(player, n) table.insert(hurts, { player = player, n = n }) end,
	Heal = function(player, n)
		local d = data[player]
		local before = d.Health
		d.Health = math.min(balance.maxHealthFor(d.Level), before + n)
		return d.Health - before
	end,
})
MOCK("ServerScriptService/server/services/currencyService", {
	AddGold = function(player, n) data[player].Gold += n end,
})
local heartbeat
SERVICE("Players", { GetPlayerByUserId = function(_, id) return byId[id] end, PlayerRemoving = { Connect = function() end } })
SERVICE("RunService", { Heartbeat = { Connect = function(_, fn) heartbeat = fn; return { Disconnect = function() end } end } })

local inventory = req("ServerScriptService/server/services/inventoryService")
local townMonsters = req("ServerScriptService/server/modules/townMonsters")
local ninjutsuService = req("ServerScriptService/server/modules/ninjutsuService")
local shops = req("ServerScriptService/server/modules/shops")
townMonsters.load()
ninjutsuService.load()
shops.load()

-- 스킬 나무(저장 v13) 호환: 아래 종류별 시험은 "칸 n = 그 유파의 옛 n차 인술(SCHOOL_INFO.skills)"로 쓴다 —
--  인술을 쓰기 직전에 그 네 인술을 1레벨로 배운 것으로 하고 단축칸을 그렇게 맞춘다(전직 단계도 4로 보고 쓴다 — 전직별 잠금은 09 · 10이 본다).
--  스킬 나무 · SP · 단축칸 · 핵심 장치 자체의 시험은 09_skills.luau.
do
	local use = handlers.UseNinjutsu
	handlers.UseNinjutsu = function(player, slot, facing)
		local d = data[player]
		local info = d and ninjutsu.SCHOOL_INFO[d.School or ""]
		if info then
			d.Ninjutsu = d.Ninjutsu or {}
			d.SkillSlots = table.clone(info.skills)
			for _, id in info.skills do
				if (d.Ninjutsu[id] or 0) < 1 then d.Ninjutsu[id] = 1 end
			end
		end
		local job = d and d.Job
		if d then d.Job = 4 end
		use(player, slot, facing)
		if d then d.Job = job end
	end
end

local ATTACK = balance.BASE_ATTACK
local field = world.scenes.field1
local FEET = world.monsterFeet
local function living() return townMonsters.Living("field1") end
-- 몬스터를 전부 구석으로 치우고(체력 넉넉히), 쓸 것만 자리에 놓는다. 집도 같이 옮긴다(멀어지면 쫓기를 포기하므로).
local function place(m, x, y)
	m.x, m.y, m.home = x, y, V(x, y)
	m.target, m.aggro, m.stunUntil, m.slowUntil = nil, nil, nil, nil
end
local function reset()
	advance(5) -- 앞 시험이 남긴 것(불붙음 등)을 먼저 흘려보낸다
	local list = living()
	for _, m in list do
		m.maxHp, m.hp = 100000, 100000
		m.damageBy = {}
		place(m, 8, 8)
	end
	return list
end
local function lost(m) return 100000 - m.hp end
local function refill() advance(30) end -- 기력 가득 + 쿨타임 끝
local function near(a, b, tol) return math.abs(a - b) <= (tol or 0.01) end
-- 피해 기대값: 지금 p1의 공격력(레벨이 오르면 공격력도 오른다) × 배율
local function dmg(power, mult) return math.max(1, math.round(inventory.GetAttackDamage(p1) * power * (mult or 1))) end
-- 시험 자리(들판 한가운데)가 비어 있어야 밀림 · 쫓기 시험이 된다
for x = 240, 340, 4 do
	expect(not townWorld.BoxBlocked(field, x, 200, FEET.halfW, FEET.h), ("시험 자리 (%d, 200) 비어 있음"):format(x))
end

-- ---- 3) 1차 전직(유파 고르기) · 유파 바꾸기 · 2~4차 전직 ----
local elder
for _, n in world.scenes.village.npcs do
	if n.type == ninjutsu.CHANGE_NPC then elder = n end
end
expect(elder ~= nil, "마을에 스승 NPC가 있음")
local function atElder() where[1] = "town_village"; standAt(p1, elder.x, elder.y + 10) end
local function atField() where[1] = "town_field1"; standAt(p1, 250, 200) end
atField()
clear()
handlers.UseNinjutsu(p1, 1, "right")
eq(#sent("NinjutsuCast"), 0, "유파가 없으면(견습) 인술을 못 씀")
eq(data[p1].Job, 0, "새 플레이어 = 견습")
data[p1].Level = 10
handlers.ChooseSchool(p1, "fire")
expect(data[p1].School == "" and noticed(p1, "스승"), "스승 곁이 아니면 전직 못 함")
atElder()
data[p1].Level = 9
clear()
handlers.ChooseSchool(p1, "fire")
expect(data[p1].School == "" and data[p1].Job == 0 and noticed(p1, "Lv.10"), "Lv.10이 안 되면 1차 전직 못 함")
data[p1].Level = 10
clear()
handlers.ChooseSchool(p1, "fire")
expect(data[p1].School == "fire" and data[p1].Job == 1, "Lv.10 + 스승 곁 → 1차 전직(유파에 듦)")
eq(data[p1].Gold, schema.default().Gold, "1차 전직은 엽전을 안 씀")
local su = sent("SchoolUpdated", p1)
expect(#su == 1 and su[1].args[1] == "fire" and su[1].args[3] == 1, "SchoolUpdated(유파, 단계표, 전직 단계)")
clear()
handlers.ChooseSchool(p1, "fire")
eq(#sent("SchoolUpdated", p1), 0, "같은 유파는 무시")
data[p1].Gold = ninjutsu.CHANGE_COST - 1
clear()
handlers.ChooseSchool(p1, "ice")
expect(data[p1].School == "fire" and noticed(p1, "엽전"), "엽전이 모자라면 유파를 못 바꿈")
data[p1].Gold = ninjutsu.CHANGE_COST + 50
handlers.ChooseSchool(p1, "ice")
expect(data[p1].School == "ice" and data[p1].Gold == 50 and data[p1].Job == 1, "스승 곁 + 엽전 → 유파 바꿈(전직 단계는 그대로)")
data[p1].School = "fire"
-- 2차 전직
clear()
handlers.JobAdvance(p1)
expect(data[p1].Job == 1 and noticed(p1, "Lv.30"), "Lv.30이 안 되면 2차 전직 못 함")
data[p1].Level = 30
atField()
handlers.JobAdvance(p1)
eq(data[p1].Job, 1, "스승 곁이 아니면 전직 못 함")
atElder()
clear()
handlers.JobAdvance(p1)
eq(data[p1].Job, 2, "Lv.30 + 스승 곁 → 2차 전직")
su = sent("SchoolUpdated", p1)
expect(#su == 1 and su[1].args[3] == 2, "전직하면 SchoolUpdated")
handlers.JobAdvance(p1)
eq(data[p1].Job, 2, "레벨이 안 되면 3차 전직 못 함")
data[p1].Level = 100
handlers.JobAdvance(p1); handlers.JobAdvance(p1); handlers.JobAdvance(p1)
eq(data[p1].Job, 4, "4차까지만")
-- 아래 시험은 1차 전직 상태(Lv.1 공격력)에서 시작한다
data[p1].Level, data[p1].Job = 1, 1
data[p1].Health = balance.maxHealthFor(1)
atField()

-- ---- 4) 화염구(투사체 → 터짐 → 불붙음) · 기력 · 쿨타임 ----
local list = reset()
local a, b, far = list[1], list[2], list[3]
place(a, 300, 200)
place(b, 312, 206)
place(far, 350, 200)
standAt(p1, 250, 200)
refill()
eq(ninjutsuService.GetEnergy(p1), ninjutsu.ENERGY_MAX, "기력은 최대를 넘지 않음")
clear()
handlers.UseNinjutsu(p1, 1, "right")
local c = sent("NinjutsuCast", p1)
expect(#c == 1 and c[1].args[3] == "fire_ball" and c[1].args[2] == 1 and near(c[1].args[8], 50, 1), "NinjutsuCast(화염구, 날아간 거리 = 50)")
eq(#sent("NinjutsuCast", p2), 1, "같은 씬의 다른 사람도 연출을 받음")
expect(near(ninjutsuService.GetEnergy(p1), ninjutsu.ENERGY_MAX - SK.fire_ball.cost), "기력 소모")
local eu = sent("EnergyUpdated", p1)
expect(#eu == 1 and near(eu[1].args[1], ninjutsu.ENERGY_MAX - SK.fire_ball.cost) and eu[1].args[2] == ninjutsu.ENERGY_MAX and eu[1].args[3] == ninjutsu.ENERGY_REGEN, "EnergyUpdated")
eq(lost(a), 0, "아직 날아가는 중")
handlers.UseNinjutsu(p1, 1, "right")
eq(#sent("NinjutsuCast", p1), 1, "쿨타임 안에는 다시 못 씀")
advance(50 / SK.fire_ball.speed + 0.02)
eq(lost(a), dmg(SK.fire_ball.power), "화염구: 맞은 몬스터")
eq(lost(b), dmg(SK.fire_ball.power), "화염구: 터진 자리 옆 몬스터")
eq(lost(far), 0, "화염구: 범위 밖")
local hitEvent
for _, e in sent("TownMonsterHit", p1) do
	if e.args[2] == a.id then hitEvent = e end
end
expect(hitEvent ~= nil and hitEvent.args[6] == "nin:fire_ball", "피격 출처 = nin:fire_ball")
advance(4)
eq(lost(a), dmg(SK.fire_ball.power), "불씨(f_ember)를 안 배웠으면 더 타지 않음 — 불씨는 09_skills.luau")
-- 기력 회복(초당 REGEN)
local e0 = ninjutsuService.GetEnergy(p1)
advance(2)
expect(near(ninjutsuService.GetEnergy(p1), math.min(ninjutsu.ENERGY_MAX, e0 + 2 * ninjutsu.ENERGY_REGEN)), "기력 회복 속도")
-- 빗나감: 끝까지 날아가 터진다
refill()
clear()
handlers.UseNinjutsu(p1, 1, "left")
eq(sent("NinjutsuCast", p1)[1].args[8], SK.fire_ball.range, "빗나가면 끝까지 날아감")
local before = lost(a)
advance(2)
eq(lost(a), before, "빗나가면 피해 없음")
-- 기력이 모자라면 못 씀
refill()
ninjutsuService.AddEnergy(p1, -(ninjutsu.ENERGY_MAX - 5))
clear()
handlers.UseNinjutsu(p1, 1, "right")
expect(#sent("NinjutsuCast", p1) == 0 and noticed(p1, "기력"), "기력이 모자라면 못 씀")
-- 기본 공격이 맞으면 기력이 찬다
standAt(p1, 290, 200)
local e1 = ninjutsuService.GetEnergy(p1)
handlers.TownAttack(p1, "right")
expect(near(ninjutsuService.GetEnergy(p1), e1 + ninjutsu.ENERGY_PER_HIT, 0.05), "기본 공격 한 마리 맞힘 → 기력 +" .. ninjutsu.ENERGY_PER_HIT)
advance(1)
e1 = ninjutsuService.GetEnergy(p1)
handlers.TownAttack(p1, "left")
expect(near(ninjutsuService.GetEnergy(p1), e1, 0.05), "헛손질은 기력이 안 참")

-- ---- 5) 칸 번호 ----
data[p1].Job = 4 -- 아래 시험은 인술 칸이 모두 열린 상태로
clear()
handlers.UseNinjutsu(p1, 5, "down")
handlers.UseNinjutsu(p1, 1.5, "down")
eq(#sent("NinjutsuCast", p1), 0, "없는 칸 번호는 무시")

-- ---- 6) 얼음: 가시(직선 · 꿰뚫음 · 느려짐) / 빙결(멈춤) ----
data[p1].School = "ice"
list = reset()
local off, beyond
a, b, off, beyond = list[1], list[2], list[3], list[4]
place(a, 290, 200)
place(b, 330, 203)
place(off, 300, 230)
place(beyond, 250 + SK.ice_spike.length + 8, 200)
standAt(p1, 250, 200)
refill()
clear()
data[p1].Ninjutsu = data[p1].Ninjutsu or {}
data[p1].Ninjutsu.i_frost = 1 -- 서리를 배워야 느려진다
handlers.UseNinjutsu(p1, 1, "right")
advance(SK.ice_spike.delay + 0.02)
data[p1].Ninjutsu.i_frost = nil
eq(lost(a), dmg(SK.ice_spike.power), "얼음 가시: 첫 몬스터")
eq(lost(b), dmg(SK.ice_spike.power), "얼음 가시: 꿰뚫고 뒤 몬스터도")
eq(lost(off), 0, "얼음 가시: 옆으로 벗어난 몬스터")
eq(lost(beyond), 0, "얼음 가시: 길이 밖")
local status = sent("TownMonsterStatus", p1)
expect(#status == 2 and status[1].args[3] == "slow" and status[1].args[4] == SK.i_frost.seconds, "TownMonsterStatus(slow) — 서리 1")
-- 느려진 몬스터는 쫓아오는 속도가 mult배(맞았으니 p1을 쫓는다)
local startX = b.x
for _ = 1, 10 do
	advance(0.1)
	heartbeat(0.1)
end
local moved = math.sqrt((b.x - startX) ^ 2 + (b.y - 203) ^ 2)
local expectMove = world.monsterSpeed * combat.MONSTER_CHASE_SPEED * (1 - SK.i_frost.slowPer) * 1
expect(near(moved, expectMove, 0.6), ("느려진 몬스터 1초 이동 %.2f(기대 %.2f)"):format(moved, expectMove))
b.slowUntil = 0 -- 느려짐 끝(서리는 8초라 기다리면 쫓기를 그만두므로 바로 끝낸다)
startX = b.x
local startY = b.y
for _ = 1, 10 do
	advance(0.1)
	heartbeat(0.1)
end
moved = math.sqrt((b.x - startX) ^ 2 + (b.y - startY) ^ 2)
expect(near(moved, world.monsterSpeed * combat.MONSTER_CHASE_SPEED, 0.8), ("느려짐이 풀리면 원래 속도(%.2f)"):format(moved))
-- 멈춤: 멈춘 몬스터는 움직이지도 때리지도 못한다
list = reset()
a = list[1]
place(a, 262, 200)
standAt(p1, 250, 200)
refill()
table.clear(hurts)
townMonsters.Damage("field1", a.id, p1, 1, "test") -- 맞았으니 쫓아와 때리려 한다
townMonsters.Stun("field1", a.id, 2.5)
for _ = 1, 20 do
	advance(0.1)
	heartbeat(0.1)
end
expect(a.x == 262 and a.y == 200 and #hurts == 0, "멈춘 동안(2초) 움직이지도 때리지도 못함")
for _ = 1, 30 do
	advance(0.1)
	heartbeat(0.1)
end
expect(#hurts > 0, "멈춤이 풀리면 다시 공격")

-- ---- 7) 풀: 덩굴 묶기(멈춤) / 치유의 잎 ----
data[p1].School = "plant"
list = reset()
a = list[1]
place(a, 270, 200)
refill()
clear()
handlers.UseNinjutsu(p1, 1, "right")
advance(SK.plant_bind.delay + 0.02)
eq(lost(a), dmg(SK.plant_bind.power), "덩굴 묶기 피해")
local st = sent("TownMonsterStatus", p1)
expect(#st == 1 and st[1].args[3] == "stun" and st[1].args[4] == SK.plant_bind.stun, "TownMonsterStatus(stun)")
reset()
refill()
local maxHealth = balance.maxHealthFor(data[p1].Level)
data[p1].Health = maxHealth
data[p1].Ninjutsu.p_vigor = 1 -- 치유의 잎은 생기를 쓴다(생기 자체의 시험은 09_skills.luau)
ninjutsuService.AddCore(p1, 100)
clear()
local eFull = ninjutsuService.GetEnergy(p1)
handlers.UseNinjutsu(p1, 2, "down")
expect(#sent("NinjutsuCast", p1) == 0 and noticed(p1, "가득") and near(ninjutsuService.GetEnergy(p1), eFull), "체력이 가득하면 치유를 안 씀(기력 그대로)")
data[p1].Health = 10
handlers.UseNinjutsu(p1, 2, "down")
eq(data[p1].Health, 10 + math.round(maxHealth * SK.plant_heal.ratio), "치유의 잎: 최대 체력의 ratio만큼")
expect(near(ninjutsuService.GetEnergy(p1), eFull - SK.plant_heal.cost), "치유: 기력 소모")
data[p1].Health = maxHealth

-- ---- 8) 바위: 가시(밀쳐 내기) / 갑옷(받는 피해 절반) ----
data[p1].School = "rock"
list = reset()
a = list[1]
place(a, 280, 200)
standAt(p1, 250, 200)
refill()
handlers.UseNinjutsu(p1, 1, "right")
advance(SK.rock_spike.delay + 0.02)
eq(lost(a), dmg(SK.rock_spike.power), "바위 가시 피해")
expect(near(a.x, 280 + SK.rock_spike.push, 0.01) and a.y == 200, ("밀려남(x = %.1f)"):format(a.x))
-- 벽 쪽으로는 막힌 곳 앞에서 멈춘다(맵 밖으로 안 나감)
place(a, 6, 200)
standAt(p1, 30, 200)
refill()
handlers.UseNinjutsu(p1, 1, "left")
advance(SK.rock_spike.delay + 0.02)
expect(a.x >= 0 and not townWorld.BoxBlocked(field, a.x, a.y, FEET.halfW, FEET.h) or a.x == 6, "밀려도 막힌 곳에는 안 들어감")
-- 갑옷
list = reset()
a = list[1]
place(a, 258, 200)
standAt(p1, 250, 200)
refill()
local base = math.max(monsterLevels.AttackDamage(a.level) - inventory.GetDefense(p1), 1)
townMonsters.Damage("field1", a.id, p1, 1, "test") -- 맞았으니 쫓아와 때린다
clear()
handlers.UseNinjutsu(p1, 2, "down")
local g = sent("NinjutsuCast", p1)
expect(#g == 1 and g[1].args[3] == "rock_guard" and g[1].args[8] == SK.rock_guard.seconds, "NinjutsuCast(바위 갑옷, 지속 시간)")
table.clear(hurts)
for _ = 1, 25 do
	advance(0.1)
	heartbeat(0.1)
end
expect(#hurts > 0 and hurts[1].n == math.max(1, math.round(base * SK.rock_guard.mult)), ("갑옷 중 받는 피해 절반(기본 %d)"):format(base))
townMonsters.Damage("field1", a.id, p1, 1, "test")
advance(SK.rock_guard.seconds)
table.clear(hurts)
townMonsters.Damage("field1", a.id, p1, 1, "test")
for _ = 1, 25 do
	advance(0.1)
	heartbeat(0.1)
end
expect(#hurts > 0 and hurts[1].n == base, "갑옷이 끝나면 원래 피해")

-- ---- 9) 번개: 연쇄(가까운 적 → 옆 적 둘) / 뇌우(세 번) ----
data[p1].School = "thunder"
list = reset()
local c3, d4
a, b, c3, d4 = list[1], list[2], list[3], list[4]
place(a, 290, 200)
place(b, 320, 210)
place(c3, 350, 200)
place(d4, 420, 200)
standAt(p1, 250, 200)
refill()
clear()
handlers.UseNinjutsu(p1, 1, "up") -- 방향과 상관없이 가까운 적
local bolt = sent("NinjutsuCast", p1)
local ids = bolt[1] and bolt[1].args[9]
expect(ids ~= nil and #ids == 3 and ids[1] == a.id and ids[2] == b.id and ids[3] == c3.id, "번개: 맞힌 순서(가까운 순으로 옮겨 감)")
local f = SK.thunder_bolt.falloff
eq(lost(a), dmg(SK.thunder_bolt.power), "번개: 첫 적")
eq(lost(b), dmg(SK.thunder_bolt.power, f), "번개: 둘째(× falloff)")
eq(lost(c3), dmg(SK.thunder_bolt.power, f * f), "번개: 셋째(× falloff²)")
eq(lost(d4), 0, "번개: 넷째로는 안 옮겨 감")
reset()
refill()
clear()
local eBefore = ninjutsuService.GetEnergy(p1)
handlers.UseNinjutsu(p1, 1, "right")
expect(#sent("NinjutsuCast", p1) == 0 and noticed(p1, "가까이") and near(ninjutsuService.GetEnergy(p1), eBefore), "번개: 적이 없으면 안 씀(기력 그대로)")
handlers.UseNinjutsu(p1, 1, "right")
list = reset()
a = list[1]
place(a, 270, 200)
refill()
handlers.UseNinjutsu(p1, 2, "right")
advance(SK.thunder_storm.delay + 0.02)
eq(lost(a), dmg(SK.thunder_storm.power), "뇌우: 첫 번째")
advance(SK.thunder_storm.interval * (SK.thunder_storm.hits - 1) + 0.02)
eq(lost(a), SK.thunder_storm.hits * dmg(SK.thunder_storm.power), "뇌우: 세 번 모두")

-- ---- 10) 두루마리: 자기 유파 것만 · 단계 +1 · 피해 +15% ----
data[p1].School = "fire"
data[p1].Level, data[p1].Job = 1, 1
data[p1].Ninjutsu, data[p1].SP = {}, { 0, 0, 0, 0 }
inventory.AddItem(p1, "ScrollIce", 1)
inventory.AddItem(p1, "ScrollFire", 2)
local function slotOf(id)
	for _, e in data[p1].Inventory do
		if e.ItemId == id then return e.Tab, e.Slot end
	end
end
clear()
local tab, slot = slotOf("ScrollIce")
handlers.UseItem(p1, tab, slot)
expect(inventory.CountItem(p1, "ScrollIce") == 1 and noticed(p1, "얼음"), "다른 유파 두루마리는 못 씀(안 줄어듦)")
tab, slot = slotOf("ScrollFire")
handlers.UseItem(p1, tab, slot)
eq(data[p1].SP[1], 1, "두루마리 → 지금 전직(1차)의 SP +1")
eq(inventory.CountItem(p1, "ScrollFire"), 1, "두루마리 1개 소모")
data[p1].Job = 2
tab, slot = slotOf("ScrollFire")
handlers.UseItem(p1, tab, slot)
expect(data[p1].SP[2] == 1 and data[p1].SP[1] == 1, "2차 닌자가 쓰면 2차 SP가 오름")
data[p2].School, data[p2].Job = "", 0
inventory.AddItem(p2, "ScrollFire", 1)
clear()
for _, e in data[p2].Inventory do
	if e.ItemId == "ScrollFire" then handlers.UseItem(p2, e.Tab, e.Slot) end
end
expect(inventory.CountItem(p2, "ScrollFire") == 1 and noticed(p2, "유파"), "유파가 없으면 두루마리를 못 씀")

-- ---- 10-1) 3 · 4차 전직 인술: 전직 단계에 따라 칸이 열리고, 유파마다 실제로 쓰인다 ----
data[p1].Level = 100
data[p1].Health = balance.maxHealthFor(100)
for _, school in ninjutsu.SCHOOLS do
	data[p1].School, data[p1].Job, data[p1].Ninjutsu = school, 2, {}
	list = reset()
	place(list[1], 280, 200)
	place(list[2], 300, 206)
	standAt(p1, 250, 200)
	refill()
	clear()
	data[p1].Job = 4
	for slot = 3, 4 do
		local id = ninjutsu.SkillFor(school, slot)
		refill()
		clear()
		local before = lost(list[1])
		handlers.UseNinjutsu(p1, slot, "right")
		local cast = sent("NinjutsuCast", p1)
		expect(#cast == 1 and cast[1].args[3] == id, ("%s: %d번 칸 = %s"):format(school, slot, id))
		advance(3)
		expect(lost(list[1]) > before, id .. ": 앞의 몬스터가 피해를 입음")
	end
end
-- 만개: 쓰면서 내 체력도 회복
data[p1].School, data[p1].Job = "plant", 4
reset()
refill()
data[p1].Health = 100
handlers.UseNinjutsu(p1, 4, "right")
eq(data[p1].Health, 100 + math.round(balance.maxHealthFor(100) * SK.plant_bloom.selfHeal), "만개: 최대 체력의 25% 회복")
data[p1].Level, data[p1].Job, data[p1].School = 1, 1, "fire"
data[p1].Health = balance.maxHealthFor(1)

-- ---- 11) 두루마리 드롭률 ----
local rng = RandomNew(777)
local N, scrolls, perSchool = 30000, 0, {}
for _ = 1, N do
	for _, d in drops.Roll("field", rng) do
		if items[d.item].Type == "Scroll" then
			scrolls += 1
			perSchool[d.item] = (perSchool[d.item] or 0) + 1
		end
	end
end
local want = N * drops.SCROLL_CHANCE
expect(scrolls > want * 0.8 and scrolls < want * 1.2, ("두루마리 %d개(기대 약 %d개)"):format(scrolls, want))
for _, sid in drops.SCROLLS do
	expect((perSchool[sid] or 0) > want / 5 * 0.6, "유파마다 고르게 " .. sid)
end
eq(#drops.Roll("없는지역", rng), 0, "없는 지역은 드롭 없음")

-- ---- 12) 화면에 나오는 글은 도트 글꼴에 있는 글자만(없는 글자는 "?"로 나온다) ----
local font = req("ReplicatedStorage/shared/data/pixelFont.generated").body
local npcTalk = req("ReplicatedStorage/shared/config/npcTalk")
local extra = {}
for _, ch in font.extra do extra[utf8.codepoint(ch)] = true end
local function badChar(text)
	for _, code in utf8.codes(text) do
		local ok = code == 10 or (code >= 32 and code <= 126) or (code >= 0xAC00 and code <= 0xD7A3) or (code >= 0x3131 and code <= 0x3163) or extra[code]
		if not ok then return utf8.char(code) end
	end
	return nil
end
local function checkText(text, what)
	local bad = badChar(text)
	expect(bad == nil, ("%s: 글꼴에 없는 글자 [%s] — %s"):format(what, tostring(bad), text))
end
for id, s in SK do
	checkText(s.name, "인술 이름 " .. id)
	checkText(s.desc, "인술 설명 " .. id)
end
for id, info in ninjutsu.SCHOOL_INFO do
	checkText(info.name, "유파 이름 " .. id)
	checkText(info.title, "유파 호 " .. id)
	checkText(info.desc, "유파 설명 " .. id)
end
for id, def in items do
	if typeof(def) == "table" and def.Name then
		checkText(def.Name, "아이템 이름 " .. id)
		checkText(def.Description or "", "아이템 설명 " .. id)
	end
end
for _, group in { npcTalk.LINES or {}, npcTalk.lines or {} } do
	for role, v in group do
		for _, line in (if typeof(v) == "table" then v else { v }) do
			checkText(line, "NPC 대사 " .. role)
		end
	end
end
-- 알림(Notify)으로 보낸 글도 전부
for _, e in sent("Notify") do
	checkText(e.args[1], "알림")
end

end)
runTest('05_weapons', function()
-- 장비와 강화(N3): 무기 표 정합성 · 레벨당 공격력 · 레벨 제한 · 무기 종류별 범위/빠르기/세기 · 강화(재료 · 확률 · 단계 옮기기) · 무기 드롭
local world = req("ReplicatedStorage/shared/data/townWorld").data
local items = req("ReplicatedStorage/shared/data/items")
local itemIcons = req("ReplicatedStorage/shared/data/itemIcons.generated")
local ninjaWeapons = req("ReplicatedStorage/shared/data/ninjaWeapons")
local balance = req("ReplicatedStorage/shared/config/balance")
local drops = req("ReplicatedStorage/shared/config/drops")
local shopsConfig = req("ReplicatedStorage/shared/config/shops")
local weapons = req("ReplicatedStorage/shared/config/weapons")
local packets = req("ReplicatedStorage/shared/net/packets")
local schema = req("ServerScriptService/server/services/playerSchema")
local font = req("ReplicatedStorage/shared/data/pixelFont.generated").body

local extra = {}
for _, ch in font.extra do extra[utf8.codepoint(ch)] = true end
local function checkText(text, what)
	for _, code in utf8.codes(text) do
		local ok = code == 10 or (code >= 32 and code <= 126) or (code >= 0xAC00 and code <= 0xD7A3) or (code >= 0x3131 and code <= 0x3163) or extra[code]
		if not ok then
			expect(false, ("%s: 글꼴에 없는 글자 [%s] — %s"):format(what, utf8.char(code), text))
			return
		end
	end
	expect(true, what)
end

-- ---- 1) 표 정합성 ----
local count = 0
for id, def in ninjaWeapons do
	count += 1
	expect(items[id] == def, "items에 합쳐짐 " .. id)
	expect(weapons.CLASSES[def.Class] ~= nil, "무기 종류 " .. id)
	expect(def.Type == "Weapon" and def.EquipSlot == "Weapon" and def.Tab == "Equip" and def.StackMax == 1, "무기 기본 항목 " .. id)
	expect(def.Level >= 1 and def.Level <= 100 and def.Attack > 0 and def.SellPrice > 0, "레벨 · 공격력 · 파는 값 " .. id)
	expect(itemIcons.rects["icon_" .. def.KitIcon] ~= nil, "아이콘 " .. id .. " (" .. def.KitIcon .. ")")
	checkText(def.Name, "무기 이름 " .. id)
	checkText(def.Description, "무기 설명 " .. id)
end
expect(count >= 12, "무기 12종 이상(" .. count .. ")")
for key, c in weapons.CLASSES do
	expect(c.reach > 0 and c.width > 0 and c.speed > 0 and c.power > 0, "종류 수치 " .. key)
	checkText(c.name, "종류 이름 " .. key)
	checkText(c.desc, "종류 설명 " .. key)
	-- 서버 공격 간격 < 클라 공격 동작 길이(4장 + 쉬는 시간) — 정상 연타가 막히지 않게
	local combat = req("ReplicatedStorage/shared/config/combat")
	local clientPeriod = (combat.ATTACK_FRAME_TIME * 4 + combat.ATTACK_COOLDOWN) * c.speed
	expect(balance.TOWN_ATTACK_COOLDOWN * c.speed < clientPeriod, "서버 간격 < 클라 동작 " .. key)
end
local regionOf = {}
for _, r in world.regions do regionOf[r.id] = r end
for region, pool in drops.WEAPONS do
	local r = regionOf[region]
	expect(r ~= nil and drops.REGION[region] ~= nil, "드롭 지역 " .. region)
	for _, id in pool do
		local def = ninjaWeapons[id]
		expect(def ~= nil, ("%s 드롭 무기 %s"):format(region, id))
		expect(def ~= nil and r ~= nil and def.Level <= r.levelMax, ("%s 무기 %s 레벨이 그 지역 안"):format(region, id))
	end
end
for _, id in shopsConfig.merchant.goods do
	expect(items[id] ~= nil and items[id].Price ~= nil and items[id].Price > 0, "잡화 상점 물건 값 " .. id)
end
local fxSheet = req("ReplicatedStorage/shared/data/ninjaFx.generated")
for key, c in weapons.CLASSES do
	expect(fxSheet.rects[c.hitFx] ~= nil, "맞음 이펙트 " .. key)
end
expect(fxSheet.rects[weapons.UNARMED.hitFx] ~= nil and fxSheet.rects[weapons.THROW_HIT_FX] ~= nil, "맨손 · 투척 맞음 이펙트")
expect(fxSheet.rects.explosion ~= nil and fxSheet.rects.spark ~= nil and fxSheet.rects.boost ~= nil, "폭발 · 레벨업 이펙트")
eq(#weapons.RATE, weapons.MAX_PLUS, "강화 확률표 길이")
for _, b in weapons.BARS do
	expect(items[b.item] ~= nil, "강화 주괴 " .. b.item)
end
for id, def in ninjaWeapons do
	local last = 0
	for plus = 1, weapons.MAX_PLUS do
		local bonus = weapons.Bonus(def, plus)
		expect(bonus > last, ("%s +%d 보너스가 늘어남"):format(id, plus))
		last = bonus
		local cost = weapons.Cost(def, plus)
		expect(cost ~= nil and items[cost.bar] ~= nil and cost.bars == plus and cost.gold > 0 and cost.rate == weapons.RATE[plus], ("%s +%d 값"):format(id, plus))
	end
	expect(weapons.Cost(def, weapons.MAX_PLUS + 1) == nil, "최고 단계 위는 없음 " .. id)
end
eq(weapons.Bonus(ninjaWeapons.Katana, 0), 0, "+0 보너스 없음")
eq(weapons.Cost(ninjaWeapons.Ninjato, 1).bar, "CopperBar", "들판 무기 = 구리")
eq(weapons.Cost(ninjaWeapons.GreatSword, 1).bar, "GoldBar", "Lv.60 무기 = 금")
eq(weapons.ClassOf(nil), weapons.UNARMED, "무기 없음 = 맨손")
eq(weapons.ClassOf({ Attack = 3 }), weapons.UNARMED, "종류가 없는 무기 = 맨손 수치")
eq(balance.attackFor(1), balance.BASE_ATTACK, "Lv.1 공격력")
eq(balance.attackFor(10), balance.BASE_ATTACK + 9 * balance.ATTACK_PER_LEVEL, "Lv.10 공격력")
expect(packets.UpgradeWeapon ~= nil and packets.UpgradeResult ~= nil, "패킷 등록")
local old = schema.default()
old.SchemaVersion, old.EquipmentPlus = 8, nil
schema.migrate(old)
expect(typeof(old.EquipmentPlus) == "table" and old.SchemaVersion == schema.CURRENT_VERSION, "v8 → v9 마이그레이션")

-- ---- 가짜 플레이어 · 서비스 ----
local p1 = { UserId = 1, Name = "닌자1", Parent = {} }
local byId = { [1] = p1 }
local data = { [p1] = schema.default() }
local where = { [1] = "town_field1" }
local pos = { [1] = V(0, 0) }
local function standAt(x, y) pos[1] = V(x * world.scale, y * world.scale) end
local events, handlers = {}, {}
local function sent(name)
	local out = {}
	for _, e in events do
		if e.name == name then table.insert(out, e) end
	end
	return out
end
local function clear() table.clear(events) end
local function noticed(word)
	for _, e in sent("Notify") do
		if string.find(e.args[1], word, 1, true) then return true end
	end
	return false
end
MOCK("ReplicatedStorage/shared/net/net", {
	FireClient = function(name, player, ...) table.insert(events, { name = name, player = player, args = { ... } }) end,
	OnServer = function(name, fn) handlers[name] = fn end,
})
MOCK("ServerScriptService/server/modules/heroTracking", {
	PlayersInScene = function(sceneName) return if where[1] == sceneName then { p1 } else {} end,
	GetPosition = function(userId) return pos[userId] end,
	GetPlayerScene = function(userId) return where[userId] end,
	OnSceneChanged = function() end,
})
MOCK("ServerScriptService/server/modules/worldDrops", { List = function() return {} end })
MOCK("ServerScriptService/server/services/persistence", {
	Get = function(player) return data[player] end,
	MarkDirty = function() end,
	Save = function() end,
})
MOCK("ServerScriptService/server/services/progressionService", {
	AddExperience = function() end, DamagePlayer = function() end, Heal = function() return 0 end,
})
MOCK("ServerScriptService/server/services/currencyService", {
	AddGold = function(player, n) data[player].Gold += n end,
})
SERVICE("Players", { GetPlayerByUserId = function(_, id) return byId[id] end, PlayerRemoving = { Connect = function() end } })
SERVICE("RunService", { Heartbeat = { Connect = function() return { Disconnect = function() end } end } })

local inventory = req("ServerScriptService/server/services/inventoryService")
local townMonsters = req("ServerScriptService/server/modules/townMonsters")
local upgradeService = req("ServerScriptService/server/modules/upgradeService")
townMonsters.load()
upgradeService.load()
local d = data[p1]
-- 새 플레이어의 시작 닌자도는 치워 둔다(아래 시험은 닌자도를 직접 넣어서 쓴다 — 두 자루면 어느 것인지 헷갈린다)
for i = #d.Inventory, 1, -1 do
	if d.Inventory[i].ItemId == "Ninjato" then table.remove(d.Inventory, i) end
end
local function slotOf(id)
	for _, e in d.Inventory do
		if e.ItemId == id and e.Tab == "Equip" then return e.Slot, e end
	end
end

-- ---- 2) 착용: 레벨 제한 · 공격력 ----
eq(inventory.GetAttackDamage(p1), balance.attackFor(1), "맨손 공격력 = 레벨 공격력")
inventory.AddItem(p1, "Katana", 1)
clear()
expect(not inventory.Equip(p1, (slotOf("Katana"))) and noticed("Lv.10"), "레벨이 모자라면 못 낌")
expect(d.Equipment.Weapon == nil, "착용 안 됨")
d.Level = 10
expect(inventory.Equip(p1, (slotOf("Katana"))), "Lv.10이면 카타나를 낌")
eq(inventory.GetAttackDamage(p1), balance.attackFor(10) + ninjaWeapons.Katana.Attack, "공격력 = 레벨 + 무기")
expect(slotOf("Katana") == nil, "낀 무기는 가방에서 빠짐")

-- ---- 3) 무기 종류: 범위 · 세기 · 빠르기 ----
local list = townMonsters.Living("field1")
local function resetMons()
	for _, m in list do
		m.maxHp, m.hp, m.damageBy = 100000, 100000, {}
		m.x, m.y = 8, 8
	end
end
local function lost(m) return 100000 - m.hp end
local function swing(id)
	-- 무기를 바꿔 끼고(가방에 없으면 넣어서) 쿨타임이 지난 뒤 오른쪽으로 한 번 휘두른다
	if d.Equipment.Weapon ~= id then
		if not slotOf(id) then inventory.AddItem(p1, id, 1) end
		expect(inventory.Equip(p1, (slotOf(id))), "착용 " .. id)
	end
	advance(2)
	handlers.TownAttack(p1, "right")
end
d.Level = 60
local a, b, c = list[1], list[2], list[3]
standAt(200, 200)
-- 도검(닿는 거리 20, 폭 22): 앞 15는 맞고, 앞 30은 안 맞고, 옆으로 9 벗어난 것은 맞는다
resetMons()
a.x, a.y = 215, 200
b.x, b.y = 230, 200
c.x, c.y = 210, 209
swing("Katana")
local sword = weapons.CLASSES.sword
eq(lost(a), math.round(inventory.GetAttackDamage(p1) * sword.power), "도검: 앞 15")
eq(lost(b), 0, "도검: 앞 30은 안 닿음")
expect(lost(c) > 0, "도검: 옆 9도 맞음(폭 22)")
-- 장병기(닿는 거리 36, 폭 12): 앞 30도 맞고, 옆 9는 안 맞는다
resetMons()
a.x, a.y = 215, 200
b.x, b.y = 230, 200
c.x, c.y = 210, 209
swing("Spear")
local polearm = weapons.CLASSES.polearm
eq(lost(a), math.round(inventory.GetAttackDamage(p1) * polearm.power), "장병기: 앞 15(피해 × 1.1)")
expect(lost(b) > 0, "장병기: 앞 30도 닿음")
eq(lost(c), 0, "장병기: 옆 9는 안 맞음(폭 12)")
-- 대형(× 1.6, 느림): 간격이 0.35 × 1.45초
resetMons()
a.x, a.y = 215, 200
swing("Club")
local heavy = weapons.CLASSES.heavy
local one = math.round(inventory.GetAttackDamage(p1) * heavy.power)
eq(lost(a), one, "대형: 피해 × 1.6")
advance(balance.TOWN_ATTACK_COOLDOWN + 0.02)
handlers.TownAttack(p1, "right")
eq(lost(a), one, "대형: 도검 간격으로는 아직 못 침")
advance(balance.TOWN_ATTACK_COOLDOWN * (heavy.speed - 1))
handlers.TownAttack(p1, "right")
eq(lost(a), one * 2, "대형: 제 간격이 지나면 침")
-- 쌍수(× 0.8, 빠름): 간격이 0.35 × 0.7초
resetMons()
a.x, a.y = 212, 200
swing("Sai")
local dual = weapons.CLASSES.dual
one = math.round(inventory.GetAttackDamage(p1) * dual.power)
advance(balance.TOWN_ATTACK_COOLDOWN * dual.speed + 0.02)
handlers.TownAttack(p1, "right")
eq(lost(a), one * 2, "쌍수: 도검보다 짧은 간격으로 연타")
-- 채찍(닿는 거리 30, 폭 36): 옆 16도 맞는다
resetMons()
a.x, a.y = 225, 216
swing("Whip")
expect(lost(a) > 0, "채찍: 앞 25 · 옆 16도 맞음")
-- 맞은 몬스터 위 베기 연출에 쓰는 무기 id
local hitEvents = sent("TownMonsterHit")
eq(hitEvents[#hitEvents].args[6], "Whip", "피격 출처 = 낀 무기 id")

-- ---- 4) 강화 ----
resetMons()
d.Level = 10
expect(inventory.Equip(p1, (slotOf("Katana"))), "카타나로 바꿔 낌")
inventory.AddItem(p1, "Ninjato", 1)
local nSlot = slotOf("Ninjato")
local nDef = ninjaWeapons.Ninjato
d.Gold = 100000
clear()
eq(upgradeService.Upgrade(p1, nSlot), nil, "대장간이 아니면 강화 안 됨")
expect(noticed("대장간"), "대장간 안내")
local smith
for _, n in world.scenes.village.npcs do
	if n.type == weapons.UPGRADE_NPC then smith = n end
end
expect(smith ~= nil, "마을에 대장장이 NPC가 있음")
where[1] = "town_village"
standAt(smith.x, smith.y + 12)
clear()
eq(upgradeService.Upgrade(p1, nSlot), nil, "주괴가 없으면 강화 안 됨")
expect(noticed("모자라요"), "재료 부족 안내")
inventory.AddItem(p1, "CopperBar", 99)
local gold0, bars0 = d.Gold, inventory.CountItem(p1, "CopperBar")
local spentGold, spentBars = 0, 0
for target = 1, 3 do
	local cost = weapons.Cost(nDef, target)
	clear()
	eq(upgradeService.Upgrade(p1, nSlot), "success", ("+%d 강화(확률 100%%)"):format(target))
	spentGold += cost.gold
	spentBars += cost.bars
	local r = sent("UpgradeResult")
	expect(#r == 1 and r[1].args[1] == true and r[1].args[2] == "Ninjato" and r[1].args[3] == target, "UpgradeResult")
end
local _, nEntry = slotOf("Ninjato")
eq(nEntry.Plus, 3, "가방 칸에 +3")
eq(d.Gold, gold0 - spentGold, "엽전 소모")
eq(inventory.CountItem(p1, "CopperBar"), bars0 - spentBars, "주괴 소모(1 + 2 + 3)")
-- 가방에 있는 무기의 강화는 공격력에 안 들어간다 → 끼면 들어간다 → 빼면 가방 칸으로 돌아온다
eq(inventory.GetAttackDamage(p1), balance.attackFor(10) + ninjaWeapons.Katana.Attack, "가방의 +3은 공격력에 없음")
clear()
expect(inventory.Equip(p1, nSlot), "닌자도 +3 착용")
eq(d.EquipmentPlus.Weapon, 3, "착용 칸으로 강화 단계가 옮겨 감")
eq(inventory.GetAttackDamage(p1), balance.attackFor(10) + nDef.Attack + weapons.Bonus(nDef, 3), "공격력 = 레벨 + 무기 + 강화")
local eqEvent = sent("EquipmentUpdated")
expect(#eqEvent >= 1 and eqEvent[#eqEvent].args[2].Weapon == 3, "EquipmentUpdated에 강화 단계")
local _, kEntry = slotOf("Katana")
expect(kEntry ~= nil and kEntry.Plus == nil, "빼낸 카타나는 강화 없음")
-- 착용 중인 무기 강화(칸 0)
inventory.AddItem(p1, "CopperBar", 99)
local results = { success = 0, fail = 0 }
local before = d.EquipmentPlus.Weapon
local r4 = upgradeService.Upgrade(p1, 0)
expect(r4 == "success" or r4 == "fail", "착용 무기 강화(+4, 80%)")
eq(d.EquipmentPlus.Weapon, before + (if r4 == "success" then 1 else 0), "성공하면 +1, 실패하면 그대로")
expect(inventory.Unequip(p1, "Weapon"), "무기 해제")
_, nEntry = slotOf("Ninjato")
eq(nEntry.Plus, before + (if r4 == "success" then 1 else 0), "해제하면 가방 칸으로 강화 단계가 돌아옴")
expect(d.EquipmentPlus.Weapon == nil, "착용 칸 강화 단계는 비워짐")
-- 강화한 장비는 못 버린다 / 안 한 장비는 버려진다
clear()
expect(inventory.Take(p1, "Equip", nEntry.Slot) == nil and noticed("버릴 수 없어요"), "강화한 장비는 못 버림")
local kSlot = slotOf("Katana")
expect(inventory.Take(p1, "Equip", kSlot) ~= nil, "강화 안 한 장비는 버려짐")
-- 확률: +3에서 +4(80%)를 2000번 — 실패해도 단계 그대로, 재료는 매번 든다
d.Gold = 100000000
local tries = 2000
for _ = 1, tries do
	nEntry.Plus = 3
	if inventory.CountItem(p1, "CopperBar") < 4 then inventory.AddItem(p1, "CopperBar", 99) end
	local barsBefore = inventory.CountItem(p1, "CopperBar")
	local r = upgradeService.Upgrade(p1, nEntry.Slot)
	results[r] += 1
	eq(nEntry.Plus, if r == "success" then 4 else 3, "성공 +4 / 실패 +3 그대로")
	eq(inventory.CountItem(p1, "CopperBar"), barsBefore - 4, "성공이든 실패든 주괴 4개")
end
local rate = results.success / tries
expect(math.abs(rate - weapons.RATE[4]) < 0.04, ("+4 성공률 %.3f(기대 %.2f)"):format(rate, weapons.RATE[4]))
-- 최고 단계
nEntry.Plus = weapons.MAX_PLUS
clear()
eq(upgradeService.Upgrade(p1, nEntry.Slot), nil, "최고 단계에서는 더 안 됨")
expect(noticed("최고"), "최고 단계 안내")
-- 무기가 아닌 것 · 없는 칸
eq(upgradeService.Upgrade(p1, 23), nil, "빈 칸")
eq(upgradeService.Upgrade(p1, 0), nil, "착용 무기가 없으면 아무 일 없음")
eq(upgradeService.Upgrade(p1, 1.5), nil, "칸 번호가 정수가 아님")
-- 엽전 부족
nEntry.Plus = 0
d.Gold = 0
clear()
eq(upgradeService.Upgrade(p1, nEntry.Slot), nil, "엽전이 없으면 안 됨")
expect(noticed("엽전"), "엽전 부족 안내")
for _, e in sent("Notify") do
	checkText(e.args[1], "알림")
end

-- ---- 5) 무기 드롭 ----
local rng = RandomNew(4242)
local N, got, wrong = 40000, 0, 0
for _ = 1, N do
	for _, drop in drops.Roll("bamboo", rng) do
		if items[drop.item].Type == "Weapon" then
			got += 1
			if not table.find(drops.WEAPONS.bamboo, drop.item) then wrong += 1 end
		end
	end
end
local want = N * drops.WEAPON_CHANCE
expect(got > want * 0.85 and got < want * 1.15, ("무기 드롭 %d개(기대 약 %d개)"):format(got, want))
eq(wrong, 0, "그 지역 무기만 나옴")

-- ---- 6) 부적(방어구 대신): 표 · 착용 · 받는 피해 · 드롭 ----
local charmCount = 0
for id, def in items do
	if typeof(def) == "table" and def.Type == "Charm" then
		charmCount += 1
		expect(def.EquipSlot == "Armor" and def.Tab == "Equip" and def.StackMax == 1 and def.Defense > 0 and def.Level >= 1, "부적 기본 항목 " .. id)
		expect(itemIcons.rects["icon_" .. def.KitIcon] ~= nil, "부적 아이콘 " .. id)
		checkText(def.Name, "부적 이름 " .. id)
		checkText(def.Description, "부적 설명 " .. id)
	end
end
expect(charmCount >= 3, "부적 3종 이상")
for region, pool in drops.CHARMS do
	local r = regionOf[region]
	for _, id in pool do
		expect(items[id] ~= nil and items[id].Type == "Charm" and r ~= nil and items[id].Level <= r.levelMax, ("%s 드롭 부적 %s"):format(region, id))
	end
end
d.Level = 1
eq(inventory.GetDefense(p1), balance.BASE_DEFENSE, "부적 없음 = 기본 방어력")
inventory.AddItem(p1, "WindCharm", 1)
inventory.AddItem(p1, "GuardCharm", 1)
clear()
expect(not inventory.Equip(p1, (slotOf("WindCharm"))) and noticed("Lv.15"), "레벨이 모자란 부적은 못 참")
expect(inventory.Equip(p1, (slotOf("GuardCharm"))), "수호 부적 착용")
eq(inventory.GetDefense(p1), balance.BASE_DEFENSE + items.GuardCharm.Defense, "방어력 = 기본 + 부적")
eq(d.Equipment.Armor, "GuardCharm", "부적은 옛 방어구 칸에")
eq(upgradeService.Upgrade(p1, (slotOf("WindCharm"))), nil, "부적은 강화 대상이 아님")
local crng = RandomNew(99)
local cgot = 0
for _ = 1, 40000 do
	for _, drop in drops.Roll("desert", crng) do
		if items[drop.item].Type == "Charm" then
			cgot += 1
			eq(drop.item, "IronCharm", "사막 부적")
		end
	end
end
local cwant = 40000 * drops.CHARM_CHANCE
expect(cgot > cwant * 0.8 and cgot < cwant * 1.2, ("부적 드롭 %d개(기대 약 %d개)"):format(cgot, cwant))
for _, drop in drops.Roll("field", crng) do
	expect(items[drop.item].Type ~= "Charm", "들판에서는 부적이 안 나옴")
end

end)
runTest('06_text', function()
-- 글씨가 칸을 넘지 않는가: 도트 글씨의 줄바꿈 · 줄임(client/modules/ui/pixelText.luau)과, 실제 게임 글(아이템 · 인술 · 유파 · NPC 대사)이
-- 각 창의 글 자리에 잘리지 않고 들어가는지. 자리 크기는 각 창 코드의 수치를 옮겨 적었다(창 배치를 바꾸면 여기도 고칠 것).
local text = req("Client/ui/pixelText")
local items = req("ReplicatedStorage/shared/data/items")
local ninjutsu = req("ReplicatedStorage/shared/config/ninjutsu")
local weapons = req("ReplicatedStorage/shared/config/weapons")
local npcTalk = req("ReplicatedStorage/shared/config/npcTalk")
local shops = req("ReplicatedStorage/shared/config/shops")
local world = req("ReplicatedStorage/shared/data/townWorld").data
local font = req("ReplicatedStorage/shared/data/pixelFont.generated")

local function lines(s)
	return string.split(s, "\n")
end
local function widest(s, fontKey)
	local w = 0
	for _, l in lines(s) do
		w = math.max(w, (text.Measure(l, fontKey)))
	end
	return w
end

-- ---- 1) 줄바꿈 · 줄임 규칙 ----
eq(text.Wrap("가나다", 100), "가나다", "짧은 글은 그대로")
eq(text.Wrap("가나 다라", 30), "가나\n다라", "띄어쓰기에서 줄바꿈")
eq(text.Wrap("가나다라마", 30), "가나\n다라\n마", "낱말이 폭보다 길면 글자에서 줄바꿈")
eq(text.Wrap("가나\n다라", 100), "가나\n다라", "원래 줄바꿈은 지킴")
eq(text.Fit("가나다라마바사", 40, 1), "가나…", "한 줄: 넘으면 …")
expect(widest(text.Fit("가나다라마바사", 40, 1)) <= 40, "한 줄 줄임 폭")
eq(text.Fit("가나다", 40, 1), "가나다", "한 줄: 들어가면 그대로")
local fitted = text.Fit("가나다라 마바사아 자차카타 파하", 50, 2)
expect(#lines(fitted) == 2 and widest(fitted) <= 50 and string.sub(fitted, -3) == "…", "두 줄 제한: 넘으면 마지막 줄 끝이 … (" .. fitted .. ")")
eq(text.Fit("가나 다라", 60, 2), "가나 다라", "두 줄 제한: 들어가면 그대로")
-- 어떤 글이든: 줄바꿈 결과의 모든 줄이 폭 안, 글자는 하나도 빠지지 않음(띄어쓰기 · 줄바꿈 빼고)
local samples = {}
for id, def in items do
	table.insert(samples, def.Name)
	table.insert(samples, def.Description)
end
for _, s in ninjutsu.SKILLS do
	table.insert(samples, s.desc)
end
for _, v in npcTalk.LINES do
	for _, l in (if typeof(v) == "table" then v else { v }) do
		table.insert(samples, l)
	end
end
local strip = function(s) return (string.gsub(s, "[%s]", "")) end
for _, s in samples do
	for _, width in { 60, 122, 236 } do
		local wrapped = text.Wrap(s, width)
		expect(widest(wrapped) <= width, ("줄바꿈 폭 %d: %s"):format(width, s))
		eq(strip(wrapped), strip(s), "줄바꿈해도 글자가 빠지지 않음")
		local cut = text.Fit(s, width, 2)
		expect(widest(cut) <= width and #lines(cut) <= 2, ("두 줄 제한 폭 %d: %s"):format(width, s))
	end
end

-- 잘리지 않고 들어가는가(… 없이)
local function fits(s, width, maxLines, fontKey)
	return text.Fit(s, width, maxLines, fontKey) == (if maxLines == 1 then s else text.Wrap(s, width, fontKey))
end

-- ---- 2) 가방 창(globals/inventory.luau): 이름 = 제목 글꼴 한 줄 · 폭 INFO_W, 설명 = 소비 5줄 / 그 밖 6줄 ----
local INFO_W = 300 - (14 + 6 * 24 + 8) - 12
for id, def in items do
	local name = def.Name .. (if def.Type == "Weapon" then " +10" else "")
	expect(fits(name, INFO_W, 1, "title"), ("가방 이름 자리(%d)에 들어감: %s (%d)"):format(INFO_W, name, (text.Measure(name, "title"))))
	local desc = def.Description
	if def.Type == "Weapon" and def.Class then
		local class = weapons.ClassOf(def)
		desc ..= ("\n%s · Lv.%d\n공격력 +%d\n%s"):format(class.name, def.Level, def.Attack + weapons.Bonus(def, 10), class.desc)
	elseif def.Type == "Charm" then
		desc ..= ("\nLv.%d부터"):format(def.Level)
	end
	local maxLines = if def.Tab == "Use" then 5 else 6
	local n = #lines(text.Wrap(desc, INFO_W))
	expect(n <= maxLines, ("가방 설명 %d줄(자리 %d줄): %s"):format(n, maxLines, id))
end

-- ---- 3) 가게(globals/shop.luau): 이름 자리 = 엽전 아이콘(170) - 36 - 4 ----
local NAME_W = 170 - 36 - 4
for _, shop in shops do
	for _, id in shop.goods do
		expect(fits(items[id].Name, NAME_W, 1), "가게 이름 자리: " .. items[id].Name)
	end
	expect((text.Measure(shop.title, "title")) + 16 <= 300, "가게 제목판: " .. shop.title)
end
for id, def in items do
	if def.SellPrice then
		expect(fits(("%s x%d"):format(def.Name, def.StackMax), NAME_W, 1), "가게(팔기) 이름 자리: " .. def.Name)
		-- 값(네 자리까지)이 버튼 둘 앞에 들어간다: 버튼 = 글씨 + 12, 사이 3
		local buttons = (text.Measure("1개")) + 12 + 3 + (text.Measure("10개")) + 12 + 3
		expect((text.Measure(tostring(def.SellPrice))) <= (300 - 12 - buttons) - (170 + 14), "가게 값 자리: " .. def.Name)
	end
end

-- ---- 4) 강화 창(globals/upgrade.luau): 폭 250 — 글 자리 222, 주괴 줄 206, 결과 줄(버튼 앞) 146 ----
for id, def in items do
	if def.Type == "Weapon" then
		local class = weapons.ClassOf(def)
		expect(fits(("%s +9 · %s"):format(def.Name, class.name), 222, 1), "강화 이름 줄: " .. id)
		local cost = weapons.Cost(def, weapons.MAX_PLUS)
		expect(fits(("%s %d개 (가진 것 %d)"):format(items[cost.bar].Name, cost.bars, 999), 206, 1), "강화 주괴 줄: " .. id)
		expect(fits(("엽전 %d"):format(cost.gold), 206, 1), "강화 엽전 줄: " .. id)
		expect(fits(("성공! %s +%d"):format(def.Name, 10), 146, 1), "강화 결과 줄: " .. id)
		expect(fits(("공격력 %d > %d"):format(def.Attack + weapons.Bonus(def, 9), def.Attack + weapons.Bonus(def, 10)), 222, 1), "강화 공격력 줄: " .. id)
	end
end
expect(fits("실패… 단계는 그대로", 146, 1) and fits("실패해도 단계는 그대로", 146, 1) and fits("강화할 무기가 없어요.", 222, 1), "강화 안내 글")
expect(fits("성공 확률 100%", 222, 1), "강화 확률 줄")

-- ---- 5) 유파 고르기 창(globals/ninjutsu.luau): 폭 444, 버튼 70 ----
local PANEL_W, BUTTON_W = 444, 70
for _, id in ninjutsu.SCHOOLS do
	local info = ninjutsu.SCHOOL_INFO[id]
	local nameW = (text.Measure(("%s · %s"):format(info.name, info.title)))
	-- 윗줄 = 이름 + 설명, 아랫줄 = 전직별 인술 이름 넷
	local skills = {}
	for _, sid in info.skills do
		table.insert(skills, ninjutsu.SKILLS[sid].name)
	end
	expect(fits(info.desc, PANEL_W - 14 - BUTTON_W - 6 - (58 + nameW + 10), 1), "유파 창 설명 줄: " .. id)
	expect(fits(table.concat(skills, " · "), PANEL_W - 14 - BUTTON_W - 6 - 58, 1), "유파 창 인술 줄: " .. id)
end
for _, note in { "Lv.10이 되면 스승에게서 유파를 골라 1차 전직을 합니다.", "유파를 고르세요. 1차 전직 · 하닌이 됩니다.",
	("닌자 마스터 · 전직을 모두 마쳤어요 · 유파 바꾸기 엽전 %d"):format(ninjutsu.CHANGE_COST), ("중닌 · 다음 전직 Lv.60 · 유파 바꾸기 엽전 %d"):format(ninjutsu.CHANGE_COST) } do
	expect(fits(note, PANEL_W - 14 - 34, 1), "유파 창 안내: " .. note)
end
for _, label in { "입문", "바꾸기", "지금 유파", "2차 전직", "4차 전직" } do
	expect(fits(label, BUTTON_W - 4, 1), "유파 창 버튼: " .. label)
end

-- ---- 6) 대화 상자(town/npcs.luau): 이름표 58, 글 자리 = 300 - 50 - 8, 두 줄씩 쪽 넘김 ----
local TEXT_W = 300 - 50 - 8
for _, t in world.npcTypes do
	expect(fits(t.name, 58, 1), "대화 이름표: " .. t.name)
end
for role, v in npcTalk.LINES do
	for _, l in (if typeof(v) == "table" then v else { v }) do
		expect(widest(text.Wrap(l, TEXT_W)) <= TEXT_W, "대화 글 폭: " .. role)
	end
end

-- ---- 7) HUD(globals/hud.luau): 레벨 알약 · 숫자 자리 ----
local pillW = (text.Measure("Lv.100")) + 8
expect(fits("Lv.100", pillW - 6, 1), "레벨 알약")
expect(fits("2080", 34, 1) and fits("100%", 34, 1) and fits("EXP", 24, 1), "체력 · 경험치 숫자 자리")
expect((text.Measure("9,999,999")) <= 94 - 12 - 14, "엽전 자리(999만 — 아이콘 오른쪽 ~ 오른쪽 맞춤 94)")
-- 인술 칸(26): 잠긴 칸 글씨 · 쿨타임 숫자
expect((text.Measure("Lv")) <= 24 and (text.Measure("100")) <= 24 and (text.Measure("14")) <= 22, "인술 칸 글씨(잠긴 칸은 Lv / 숫자 두 줄)")
-- 가방 · 강화 창 칸(22): 개수와 강화 단계 글씨
expect((text.Measure("99")) <= 20 and (text.Measure("+9")) <= 20 and (text.Measure("10")) <= 20, "칸 구석 글씨(개수 99 · 강화 +9 · 10)")
-- 글꼴 규칙: 영문·기호 폭이 칸을 넘지 않는다
for key, f in font do
	for i, adv in f.asciiAdv do
		expect(adv <= f.cellW + (if key == "title" then 2 else 1), ("%s 글꼴 %d번째 영문 폭"):format(key, i))
	end
end

end)
runTest('07_quests', function()
-- 본 줄거리 퀘스트: 자료 정합성(공방 설계를 옮긴 quests.generated) · 저장 형태 · 받기/끝내기 흐름(말 걸기 · 처치 · 모으기 · 가기 · 전직)
--  · 레벨 제한 · 가방이 가득 찼을 때 · 추적창 글이 칸에 들어가는가 · 글꼴에 없는 글자가 없는가
local world = req("ReplicatedStorage/shared/data/townWorld").data
local items = req("ReplicatedStorage/shared/data/items")
local balance = req("ReplicatedStorage/shared/config/balance")
local quests = req("ReplicatedStorage/shared/config/quests")
local ninjutsu = req("ReplicatedStorage/shared/config/ninjutsu")
local packets = req("ReplicatedStorage/shared/net/packets")
local schema = req("ServerScriptService/server/services/playerSchema")
local text = req("Client/ui/pixelText")
local font = req("ReplicatedStorage/shared/data/pixelFont.generated")

local LIST = quests.LIST
local function indexOf(id)
	for i, q in LIST do
		if q.id == id then return i end
	end
	error("퀘스트 없음 " .. id)
end

-- ---- 1) 자료 정합성 ----
expect(quests.COUNT >= 50, "퀘스트 수")
local speciesById, npcTypes = {}, {}
for _, s in world.species do speciesById[s.id] = s end
for _, sc in world.scenes do
	for _, n in sc.npcs do npcTypes[n.type] = true end
end
local KINDS = { talk = true, kill = true, collect = true, reach = true, boss = true, job = true, ride = true }
local seen, prevLevel = {}, 0
local function known(s)
	for _, code in utf8.codes(s) do
		local ok = (code >= 32 and code <= 126) or (code >= 0xAC00 and code <= 0xD7A3) or (code >= 0x3131 and code <= 0x3163)
		if not ok then
			for _, ch in font.body.extra do
				if utf8.codepoint(ch) == code then ok = true end
			end
		end
		if not ok then return false end
	end
	return true
end
local TRACK_W = 172 - 20 -- globals/quest.luau 추적창 글 폭
local function fits(s) return text.Fit(s, TRACK_W, 1) == s end
for i, q in LIST do
	expect(not seen[q.id], "id가 겹치지 않음 " .. q.id)
	seen[q.id] = true
	expect(KINDS[q.kind] == true, "알려진 종류 " .. q.id)
	expect(q.level >= prevLevel and q.level >= 1 and q.level <= 100, "레벨이 차례대로 " .. q.id)
	prevLevel = q.level
	expect(typeof(q.giver) == "string" and typeof(q.giverName) == "string" and typeof(q.targetName) == "string", "주는 사람 · 목표 이름 " .. q.id)
	expect(q.exp >= 0 and q.gold >= 0 and q.count >= 1, "보상 · 개수 " .. q.id)
	if q.kind == "kill" then
		expect(speciesById[q.target] ~= nil, "처치 대상이 몬스터 표에 있음 " .. q.id)
		eq(speciesById[q.target] and speciesById[q.target].name, q.targetName, "몬스터 이름 " .. q.id)
	elseif q.kind == "collect" then
		expect(items[q.target] ~= nil, "모을 아이템이 있음 " .. q.id)
	elseif q.kind == "reach" then
		expect(q.scene == nil or world.scenes[q.scene] ~= nil, "갈 씬 " .. q.id)
	elseif q.kind == "job" then
		eq(q.level, ninjutsu.JOB_LEVELS[tonumber(q.target)], "전직 퀘스트 레벨 = 전직 레벨 " .. q.id)
	end
	if q.item then
		expect(q.item == "SchoolScroll" or items[q.item] ~= nil, "보상 아이템 " .. q.id)
		expect((q.itemCount or 0) >= 1, "보상 개수 " .. q.id)
	end
	-- 글: 글꼴에 있는 글자만, 추적창 한 줄에 들어감
	for _, s in { q.title, q.text, q.offer, q.done, q.giverName, q.targetName } do
		expect(known(s), ("글꼴에 없는 글자 %s: %s"):format(q.id, s))
	end
	expect(fits(q.title), ("추적창 제목 자리에 들어감 %s: %s"):format(q.id, q.title))
	local job = tonumber(q.target) or 0
	for _, line in {
		quests.Objective(q, false, 0, 0, 0, 1), quests.Objective(q, false, 0, 0, 0, 100),
		quests.Objective(q, true, 0, 0, 0, 100), quests.Objective(q, true, q.count, q.count, job, 100),
	} do
		expect(fits(line), ("추적창 할 일 자리에 들어감 %s: %s (%d)"):format(q.id, line, (text.Measure(line))))
	end
end
-- 지금 지은 맵만으로 할 수 있는 앞부분: 주는 사람이 마을에 있다
for _, id in { "m001", "m002", "m003", "m004", "m101", "m102" } do
	expect(npcTypes[LIST[indexOf(id)].giver] == true, "주는 사람이 게임에 있음 " .. id)
end
expect(packets.QuestTalk ~= nil and packets.QuestUpdated ~= nil, "패킷 등록")
expect(packets.QuestTalk.Args[1]("elder") and not packets.QuestTalk.Args[1](3), "QuestTalk 인자")

-- 규칙 함수
local kill, collect, talk, reach, job = LIST[indexOf("m002")], LIST[indexOf("m004")], LIST[indexOf("m001")], LIST[indexOf("m103")], LIST[indexOf("m106")]
eq(quests.TurnIn(kill), kill.giver, "처치: 주는 사람에게 돌아가 끝냄")
eq(quests.TurnIn(reach), nil, "가기: 닿으면 끝")
expect(quests.Instant(talk) and not quests.Instant(kill), "주는 사람 = 말 걸 사람이면 받자마자 끝")
expect(not quests.Ready(kill, 4, 0, 0) and quests.Ready(kill, 5, 0, 0), "처치 수")
expect(not quests.Ready(collect, 0, 0, 0) and quests.Ready(collect, 0, 1, 0), "모은 개수")
expect(not quests.Ready(job, 0, 0, 0) and quests.Ready(job, 0, 0, 1), "전직 단계")
eq(quests.Objective(kill, false, 0, 0, 0, 1), "Lv.2부터 · 스승", "할 일: 레벨이 모자람")
eq(quests.Objective(kill, false, 0, 0, 0, 2), "스승에게 가기", "할 일: 받으러 가기")
eq(quests.Objective(kill, true, 3, 0, 0, 2), "말랑이 3/5", "할 일: 처치 수")
eq(quests.Objective(kill, true, 5, 0, 0, 2), "스승에게 돌아가기", "할 일: 돌아가기")
eq(quests.Objective(collect, true, 0, 0, 0, 3), "구리 주괴 0/1", "할 일: 모으기")
eq(quests.Objective(reach, true, 0, 0, 0, 9), "나비 언덕 1 가기", "할 일: 가기")
eq(quests.Objective(job, true, 0, 0, 0, 10), "1차 전직 하기", "할 일: 전직")
eq(quests.RewardItem(job, "ice"), "ScrollIce", "유파 두루마리 보상")
eq(quests.RewardItem(job, ""), nil, "유파가 없으면 두루마리 없음")

-- ---- 2) 저장 형태 ----
local fresh = schema.default()
expect(fresh.Quest.Index == 1 and fresh.Quest.Accepted == false and fresh.Quest.Progress == 0, "새 플레이어: 첫 퀘스트부터")
local old = schema.default()
old.SchemaVersion, old.Quest = 11, nil
schema.migrate(old)
expect(old.SchemaVersion == schema.CURRENT_VERSION and old.Quest.Index == 1, "v11 → v12 마이그레이션")

-- ---- 가짜 플레이어 · 서비스 ----
local p1 = { UserId = 1, Name = "닌자1", Parent = {} }
local byId = { [1] = p1 }
local data = { [p1] = schema.default() }
local where = { [1] = "town_village" }
local pos = { [1] = V(0, 0) }
local events, handlers = {}, {}
local function sent(name)
	local out = {}
	for _, e in events do
		if e.name == name then table.insert(out, e) end
	end
	return out
end
local function clear() table.clear(events) end
local function noticed(word)
	for _, e in sent("Notify") do
		if string.find(e.args[1], word, 1, true) then return true end
	end
	return false
end
local sceneChanged
MOCK("ReplicatedStorage/shared/net/net", {
	FireClient = function(name, player, ...) table.insert(events, { name = name, player = player, args = { ... } }) end,
	OnServer = function(name, fn) handlers[name] = fn end,
})
MOCK("ServerScriptService/server/modules/heroTracking", {
	PlayersInScene = function(sceneName) return if where[1] == sceneName then { p1 } else {} end,
	GetPosition = function(userId) return pos[userId] end,
	GetPlayerScene = function(userId) return where[userId] end,
	OnSceneChanged = function(fn) sceneChanged = sceneChanged or {}; table.insert(sceneChanged, fn) end,
})
MOCK("ServerScriptService/server/modules/worldDrops", { List = function() return {} end })
MOCK("ServerScriptService/server/services/persistence", {
	Get = function(player) return data[player] end,
	MarkDirty = function() end,
	Save = function() end,
})
local gained = 0
MOCK("ServerScriptService/server/services/progressionService", {
	AddExperience = function(_, n) gained += n end,
	DamagePlayer = function() end,
	Heal = function() return 0 end,
})
MOCK("ServerScriptService/server/services/currencyService", {
	AddGold = function(player, n) data[player].Gold += n end,
})
SERVICE("Players", { GetPlayerByUserId = function(_, id) return byId[id] end, PlayerRemoving = { Connect = function() end } })
SERVICE("RunService", { Heartbeat = { Connect = function() return { Disconnect = function() end } end } })

local inventory = req("ServerScriptService/server/services/inventoryService")
local townMonsters = req("ServerScriptService/server/modules/townMonsters")
local questService = req("ServerScriptService/server/modules/questService")
townMonsters.load()
questService.load()
expect(handlers.QuestTalk ~= nil, "QuestTalk 핸들러 등록")

local npcAt = {}
for _, n in world.scenes.village.npcs do npcAt[n.type] = n end
local function at(npcType)
	where[1] = "town_village"
	pos[1] = V(npcAt[npcType].x * world.scale, (npcAt[npcType].y + 10) * world.scale)
end
local function away() where[1] = "town_village"; pos[1] = V(0, 0) end
local function talkTo(npcType) at(npcType); handlers.QuestTalk(p1, npcType) end
-- 그 씬에서 그 종 몬스터 n마리를 쓰러뜨린다(혼자 다 때림)
local function slay(key, speciesId, n)
	where[1] = "town_" .. key
	local done = 0
	for _, m in townMonsters.Living(key) do
		if done >= n then break end
		if world.species[m.row].id == speciesId then
			townMonsters.Damage(key, m.id, p1, m.maxHp, "test")
			done += 1
		end
	end
	eq(done, n, ("%s에서 %s %d마리 처치"):format(key, speciesId, n))
end
local Q = data[p1].Quest
local function last() local l = sent("QuestUpdated"); return l[#l] end

-- ---- 3) 흐름: 서장 ----
-- m001 스승의 부름(말 걸기, 받자마자 끝)
away()
handlers.QuestTalk(p1, "elder")
eq(Q.Index, 1, "스승 곁이 아니면 아무 일도 없음")
talkTo("merchant")
eq(Q.Index, 1, "주는 사람이 아니면 아무 일도 없음")
clear(); gained = 0
talkTo("elder")
expect(Q.Index == 2 and Q.Accepted == false, "m001: 스승에게 말을 걸면 바로 끝나고 다음 퀘스트로")
eq(gained, LIST[1].exp, "m001 경험치")
local u = last()
expect(u ~= nil and u.args[1] == 2 and u.args[2] == false and u.args[4] == "m001", "QuestUpdated(번호, 받았는가, 진행, 끝낸 id)")

-- m002 첫 수련(말랑이 5)
data[p1].Level = 1
clear()
talkTo("elder")
expect(Q.Accepted == false and noticed("Lv.2"), "레벨이 모자라면 못 받음")
data[p1].Level = 2
slay("field1", "Slime", 2)
eq(Q.Progress, 0, "받기 전에 잡은 것은 세지 않음")
talkTo("elder")
expect(Q.Index == 2 and Q.Accepted == true and Q.Progress == 0, "m002 받음")
clear()
slay("field1", "Slime", 3)
eq(Q.Progress, 3, "말랑이 3마리")
eq(#sent("QuestUpdated"), 3, "잡을 때마다 QuestUpdated")
talkTo("elder")
eq(Q.Index, 2, "다 못 채우면 못 끝냄")
slay("field1", "Slime", 4)
eq(Q.Progress, 5, "목표보다 더 세지 않음")
talkTo("merchant")
eq(Q.Index, 2, "끝낼 사람이 아니면 못 끝냄")
local gold, rice = data[p1].Gold, inventory.CountItem(p1, "Onigiri")
gained = 0
talkTo("elder")
expect(Q.Index == 3 and Q.Accepted == false and Q.Progress == 0, "m002 끝")
eq(data[p1].Gold, gold + kill.gold, "m002 엽전")
eq(inventory.CountItem(p1, "Onigiri"), rice + 5, "m002 주먹밥 5")
eq(gained, kill.exp, "m002 경험치")

-- m003 닌자의 도구(잡화상, 바로 끝) — 가방이 가득 차 있으면 끝나지 않는다
local keep = data[p1].Inventory
local full = {}
for slot = 1, balance.INVENTORY_SLOTS do
	table.insert(full, { Tab = "Use", Slot = slot, ItemId = "Sushi", Count = items.Sushi.StackMax })
end
data[p1].Inventory = full
clear()
talkTo("merchant")
expect(Q.Index == 3 and Q.Accepted == true and noticed("가방"), "가방이 가득 차면 보상을 못 받아 끝나지 않음(받은 상태로 남음)")
data[p1].Inventory = keep
local stars = inventory.CountItem(p1, "Shuriken")
talkTo("merchant")
expect(Q.Index == 4, "m003: 자리가 생기면 다시 말을 걸어 끝냄")
eq(inventory.CountItem(p1, "Shuriken"), stars + 30, "m003 수리검 30")

-- m004 칼을 벼리다(구리 주괴 1 → 대장장이)
data[p1].Level = 3
talkTo("blacksmith")
expect(Q.Index == 4 and Q.Accepted, "m004 받음")
inventory.TakeItem(p1, "CopperBar", inventory.CountItem(p1, "CopperBar")) -- 앞에서 주운 것은 치운다
talkTo("blacksmith")
eq(Q.Index, 4, "주괴가 없으면 못 끝냄")
inventory.AddItem(p1, "CopperBar", 1)
talkTo("blacksmith")
eq(Q.Index, 5, "m004 끝")
eq(inventory.CountItem(p1, "CopperBar"), 3, "주괴 1개를 내고 3개를 받음")

-- ---- 4) 1장 ----
-- m101 버섯돌이 12(약방 주인)
talkTo("potion")
expect(Q.Index == 5 and Q.Accepted, "m101 받음")
slay("field3", "Mushroom", 12)
eq(Q.Progress, 12, "버섯돌이 12마리")
talkTo("potion")
eq(Q.Index, 6, "m101 끝")
-- m102 풀잎 10
data[p1].Level = 4
talkTo("potion")
inventory.TakeItem(p1, "GrassBlade", inventory.CountItem(p1, "GrassBlade"))
inventory.AddItem(p1, "GrassBlade", 9)
talkTo("potion")
eq(Q.Index, 6, "풀잎 9장으로는 못 끝냄")
inventory.AddItem(p1, "GrassBlade", 3)
talkTo("potion")
eq(Q.Index, 7, "m102 끝")
eq(inventory.CountItem(p1, "GrassBlade"), 2, "풀잎 10장만 냄")
-- m103 가기(나비 언덕 1 = hill1): 그 씬에 들어서면 바로 끝난다
data[p1].Level = 6
eq(LIST[7].id, "m103", "일곱 번째 = m103")
eq(LIST[7].scene, "hill1", "m103이 가리키는 씬")
local fire = function(sceneName)
	where[1] = sceneName
	for _, fn in sceneChanged do fn(1, "town_village", sceneName) end
end
fire("town_hill1")
eq(Q.Index, 7, "받기 전에 가 본 것은 치지 않음")
talkTo("elder")
expect(Q.Index == 7 and Q.Accepted, "m103 받음")
fire("town_field1")
eq(Q.Index, 7, "다른 씬에 들어가도 끝나지 않음")
clear(); gained = 0
fire("town_hill1")
expect(Q.Index == 8 and last().args[4] == "m103", "가기: 그 씬에 들어서면 바로 끝남")
eq(gained, LIST[7].exp, "m103 경험치")
-- m104 도토리쥐 15(창고지기) — 나비 언덕 3 · 큰 웅덩이
data[p1].Level = 7
talkTo("storage")
expect(Q.Index == 8 and Q.Accepted, "m104 받음")
slay("hill3", "Mouse", 8)
slay("pond", "Mouse", 7)
eq(Q.Progress, 15, "도토리쥐 15마리(두 맵에 걸쳐)")
talkTo("storage")
eq(Q.Index, 9, "m104 끝")
-- 줄기가 이어져 있다: 마을 → 새싹 들판 1 → 2 → 3 → 나비 언덕 1 → 2 → 3 → 큰 웅덩이, 그리고 되돌아오는 포탈
local chain = { "village", "field1", "field2", "field3", "hill1", "hill2", "hill3", "pond" }
for i = 1, #chain - 1 do
	local function linked(a, b)
		for _, p in world.scenes[a].portals do
			if p.to == b then return true end
		end
		return false
	end
	expect(linked(chain[i], chain[i + 1]) and linked(chain[i + 1], chain[i]), ("포탈 %s ↔ %s"):format(chain[i], chain[i + 1]))
end

-- ---- 5) 전직 퀘스트(m106): 스승에게 받고, 전직한 뒤 다시 말을 걸면 끝 ----
Q.Index, Q.Accepted, Q.Progress = indexOf("m106"), false, 0
data[p1].Level = 10
talkTo("elder")
expect(Q.Accepted, "m106 받음")
talkTo("elder")
eq(Q.Index, indexOf("m106"), "전직 전에는 못 끝냄")
data[p1].Job, data[p1].School = 1, "fire"
local scrolls = inventory.CountItem(p1, "ScrollFire")
talkTo("elder")
eq(Q.Index, indexOf("m106") + 1, "m106 끝")
eq(inventory.CountItem(p1, "ScrollFire"), scrolls + 1, "내 유파의 두루마리 1")

-- ---- 6) 다 끝낸 뒤 ----
Q.Index, Q.Accepted, Q.Progress = quests.COUNT + 1, false, 0
clear()
talkTo("elder")
eq(#sent("QuestUpdated"), 0, "퀘스트를 다 끝냈으면 아무 일도 없음")

end)
runTest('08_dash', function()
-- 대쉬(이동기): 설정 정합성(유파마다 무게가 다름 — 불 · 번개 빠름, 얼음 중간, 풀 · 바위 무거움) · 견습 구르기 / 유파 대쉬 고르기
--  · 쿨타임 · 기력 · 벽까지의 거리 · 순수 이동기(피해 · 상태 이상 없음) · 연출 알림 · 이펙트 이름
local world = req("ReplicatedStorage/shared/data/townWorld").data
local townWorld = req("ReplicatedStorage/shared/data/townWorld")
local ninjutsu = req("ReplicatedStorage/shared/config/ninjutsu")
local packets = req("ReplicatedStorage/shared/net/packets")
local fxSheet = req("ReplicatedStorage/shared/data/ninjaFx.generated")
local schema = req("ServerScriptService/server/services/playerSchema")
local D = ninjutsu.DASH

-- ---- 1) 설정 ----
for _, id in { "novice", "fire", "ice", "plant", "rock", "thunder" } do
	local d = D[id]
	expect(d ~= nil, "대쉬 정의 " .. id)
	for _, f in { "windup", "distance", "time", "cooldown", "cost" } do
		expect(typeof(d[f]) == "number", ("%s.%s"):format(id, f))
	end
	expect(typeof(d.name) == "string" and typeof(d.desc) == "string" and typeof(d.feel) == "string", "이름 · 설명 " .. id)
	expect(d.distance > 0 and d.time > 0 and d.cooldown > 0 and d.cost >= 0 and d.cost <= ninjutsu.ENERGY_MAX, "수치 범위 " .. id)
	for _, k in { "start", "path", "finish" } do
		if d.fx[k] then
			expect(fxSheet.rects[d.fx[k]] ~= nil, ("%s 이펙트 %s가 시트에 있음"):format(id, d.fx[k]))
		end
	end
	if d.fx.path then
		expect(typeof(d.fx.pathStep) == "number" and d.fx.pathStep > 0, "길 이펙트 간격 " .. id)
	end
	if d.fx.pathHold then
		expect(fxSheet.rects[d.fx.path].hold ~= nil, "머무는 이펙트에는 머무는 장이 있음 " .. id)
	end
	expect(d.hit == nil and d.trail == nil and d.guard == nil, "대쉬는 순수 이동기 — 피해 · 상태 이상 · 방어 효과 없음 " .. id)
end
-- 무게: 처음부터 끝까지 걸리는 시간(준비 + 이동)으로 한 칸을 가는 빠르기
local function pace(id) return D[id].distance / (D[id].windup + D[id].time) end
expect(pace("thunder") > pace("fire") and pace("fire") > pace("ice"), "번개 > 불 > 얼음(빠른 순)")
expect(pace("ice") > pace("plant") and pace("plant") > pace("rock"), "얼음 > 풀 > 바위")
expect(D.fire.windup == 0 and D.thunder.windup == 0, "불 · 번개는 준비 동작이 없음")
expect(D.plant.windup >= 0.15 and D.rock.windup >= 0.15, "풀 · 바위는 준비 동작이 있음(무거움)")
expect(D.ice.windup < D.plant.windup, "얼음은 중간")
expect(D.rock.cooldown > D.plant.cooldown and D.plant.cooldown > D.ice.cooldown and D.ice.cooldown > D.fire.cooldown, "무거울수록 쿨타임이 김")
do
	local id, def = ninjutsu.DashFor("", 0)
	expect(id == "novice" and def == D.novice, "견습 = 구르기")
	eq((ninjutsu.DashFor("fire", 0)), "novice", "전직 전에는 유파가 있어도 구르기")
	eq((ninjutsu.DashFor("fire", 1)), "fire", "1차 전직부터 유파의 대쉬")
	eq((ninjutsu.DashFor("rock", 4)), "rock", "4차도 그대로")
	eq((ninjutsu.DashFor("water", 2)), "novice", "모르는 유파 → 구르기")
end
expect(packets.UseDash ~= nil and packets.UseDash.Args[1]("left") and not packets.UseDash.Args[1]("north"), "패킷 UseDash")
expect(Enum.KeyCode[ninjutsu.DASH_KEY] ~= nil, "대쉬 키")

-- ---- 가짜 플레이어 · 서비스 ----
local p1 = { UserId = 1, Name = "닌자1", Parent = {} }
local byId = { [1] = p1 }
local data = { [p1] = schema.default() }
local where = { [1] = "town_field1" }
local pos = { [1] = V(0, 0) }
local function standAt(x, y) pos[1] = V(x * world.scale, y * world.scale) end
local events, handlers = {}, {}
local function sent(name)
	local out = {}
	for _, e in events do
		if e.name == name then table.insert(out, e) end
	end
	return out
end
local function clear() table.clear(events) end
local function noticed(word)
	for _, e in sent("Notify") do
		if string.find(e.args[1], word, 1, true) then return true end
	end
	return false
end
MOCK("ReplicatedStorage/shared/net/net", {
	FireClient = function(name, player, ...) table.insert(events, { name = name, player = player, args = { ... } }) end,
	OnServer = function(name, fn) handlers[name] = fn end,
})
MOCK("ServerScriptService/server/modules/heroTracking", {
	PlayersInScene = function(sceneName) return if where[1] == sceneName then { p1 } else {} end,
	GetPosition = function(userId) return pos[userId] end,
	GetPlayerScene = function(userId) return where[userId] end,
	OnSceneChanged = function() end,
})
MOCK("ServerScriptService/server/modules/worldDrops", { List = function() return {} end })
MOCK("ServerScriptService/server/services/persistence", {
	Get = function(player) return data[player] end,
	MarkDirty = function() end,
	Save = function() end,
})
MOCK("ServerScriptService/server/services/progressionService", {
	AddExperience = function() end,
	DamagePlayer = function() end,
	Heal = function() return 0 end,
})
MOCK("ServerScriptService/server/services/currencyService", { AddGold = function() end })
SERVICE("Players", { GetPlayerByUserId = function(_, id) return byId[id] end, PlayerRemoving = { Connect = function() end } })
SERVICE("RunService", { Heartbeat = { Connect = function() return { Disconnect = function() end } end } })

local inventory = req("ServerScriptService/server/services/inventoryService")
local townMonsters = req("ServerScriptService/server/modules/townMonsters")
local ninjutsuService = req("ServerScriptService/server/modules/ninjutsuService")
townMonsters.load()
ninjutsuService.load()
expect(handlers.UseDash ~= nil, "UseDash 핸들러 등록")

local field = world.scenes.field1
local X0, Y0 = 250, 200 -- 들판 한가운데(테스트 04와 같은 빈 자리)
for x = X0, X0 + 90, 4 do
	expect(not townWorld.BoxBlocked(field, x, Y0, world.playerFeet.halfW, world.playerFeet.h), ("시험 자리 (%d, %d) 비어 있음"):format(x, Y0))
end
-- 몬스터를 모두 구석으로 치우고 체력을 넉넉히, 둘만 골라 길 위(on) · 길 밖(off)에 놓는다
local function arrange(onX)
	advance(8) -- 앞 시험이 남긴 자리 효과를 흘려보낸다
	local list = townMonsters.Living("field1")
	for _, m in list do
		m.maxHp, m.hp, m.damageBy = 100000, 100000, {}
		m.x, m.y, m.home = 8, 8, V(8, 8)
		m.target, m.aggro, m.stunUntil, m.slowUntil = nil, nil, nil, nil
	end
	local on, off = list[1], list[2]
	on.x, on.y, on.home = onX, Y0, V(onX, Y0)
	off.x, off.y, off.home = onX, Y0 + 40, V(onX, Y0 + 40)
	return on, off
end
local function lost(m) return 100000 - m.hp end
local function become(school, job)
	data[p1].School, data[p1].Job = school, job
	advance(60) -- 쿨타임 끝 · 기력 가득
	clear()
end
local function attackOf() return inventory.GetAttackDamage(p1) end
local function casts() return sent("NinjutsuCast") end
local function status(kind)
	local n = 0
	for _, e in sent("TownMonsterStatus") do
		if e.args[3] == kind then n += 1 end
	end
	return n
end

-- ---- 2) 견습 구르기: 기력 없이, 쿨타임, 효과 없음 ----
standAt(X0, Y0)
become("", 0)
local on, off = arrange(X0 + 20)
local before = ninjutsuService.GetEnergy(p1)
handlers.UseDash(p1, "right")
local c = casts()
expect(#c == 1 and c[1].args[3] == "dash_novice", "구르기 → NinjutsuCast(dash_novice)")
eq(c[1].args[8], D.novice.distance, "막힌 곳이 없으면 끝까지")
expect(c[1].args[6] == 1 and c[1].args[7] == 0, "방향(오른쪽)")
advance(1)
eq(lost(on), 0, "구르기는 피해가 없음")
eq(ninjutsuService.GetEnergy(p1), before, "구르기는 기력을 쓰지 않음")
clear()
handlers.UseDash(p1, "right")
eq(#casts(), 0, "쿨타임 중에는 못 씀")
advance(D.novice.cooldown)
handlers.UseDash(p1, "right")
eq(#casts(), 1, "쿨타임이 지나면 다시")
handlers.UseDash(p1, "north")
eq(#casts(), 1, "모르는 방향은 무시")

-- ---- 3) 벽까지의 거리 ----
eq(ninjutsuService.DashDistance("field1", V(X0, Y0), V(1, 0), 64), 64, "빈 길: 끝까지")
do
	-- 왼쪽으로 계속 가면 가장자리 나무에 막힌다: 막히기 직전 자리에서 대쉬하면 거리가 줄어든다
	local x = X0
	while x > 8 and not townWorld.BoxBlocked(field, x - 2, Y0, world.playerFeet.halfW, world.playerFeet.h) do x -= 2 end
	expect(x > 8, "왼쪽 어딘가에 막힌 곳이 있음")
	eq(ninjutsuService.DashDistance("field1", V(x, Y0), V(-1, 0), 64), 0, "벽 바로 앞: 0")
	eq(ninjutsuService.DashDistance("field1", V(x + 10, Y0), V(-1, 0), 64), 10, "벽 10도트 앞: 10")
end

-- ---- 4) 유파 대쉬: 순수 이동기 — 길 위에 적이 있어도 피해 · 멈춤 · 느려짐 · 밀림이 없다 ----
for _, school in { "fire", "thunder", "ice", "plant", "rock" } do
	become(school, 1)
	on, off = arrange(X0 + 30)
	local x0, y0 = on.x, on.y
	before = ninjutsuService.GetEnergy(p1)
	handlers.UseDash(p1, "right")
	eq(casts()[1].args[3], "dash_" .. school, "유파 대쉬 " .. school)
	eq(casts()[1].args[8], D[school].distance, "거리 " .. school)
	eq(math.round(before - ninjutsuService.GetEnergy(p1)), D[school].cost, "기력 소모 " .. school)
	advance(6)
	eq(lost(on), 0, "길 위의 적도 피해 없음 " .. school)
	eq(#sent("TownMonsterStatus"), 0, "상태 이상 없음 " .. school)
	eq(#sent("TownMonsterHit"), 0, "맞음 알림 없음 " .. school)
	expect(on.x == x0 and on.y == y0, "밀려나지 않음 " .. school)
end

-- ---- 9) 기력이 모자라면 못 씀 ----
become("fire", 1)
ninjutsuService.AddEnergy(p1, -ninjutsu.ENERGY_MAX)
clear()
handlers.UseDash(p1, "right")
expect(#casts() == 0 and noticed("기력"), "기력이 모자라면 대쉬를 못 씀")

end)
runTest('09_skills', function()
-- 스킬 나무(메이플식 1~4차): 설정 정합성 · 저장 올리기(v13) · 전직할 때 받는 것 · SP로 배우기 · 단축칸 · 레벨업 SP
--  · 핵심 장치(불씨 · 서리 · 생기 · 견고 · 전하) · 1차 새 스킬(가시 씨앗 · 달궈진 칼날 · 얼음 갑옷 · 정전기) · 유파 바꾸기 · 공용 패시브
local world = req("ReplicatedStorage/shared/data/townWorld").data
local items = req("ReplicatedStorage/shared/data/items")
local balance = req("ReplicatedStorage/shared/config/balance")
local monsterLevels = req("ReplicatedStorage/shared/config/monsterLevels")
local ninjutsu = req("ReplicatedStorage/shared/config/ninjutsu")
local weapons = req("ReplicatedStorage/shared/config/weapons")
local packets = req("ReplicatedStorage/shared/net/packets")
local fxSheet = req("ReplicatedStorage/shared/data/ninjaFx.generated")
local schema = req("ServerScriptService/server/services/playerSchema")
local SK = ninjutsu.SKILLS

-- ---- 1) 설정 ----
local seenIds = {}
for _, school in ninjutsu.SCHOOLS do
	local tree = ninjutsu.TREE[school]
	expect(tree ~= nil and #tree == #ninjutsu.JOB_LEVELS, "유파마다 전직 4개 " .. school)
	local cores = 0
	for job, list in tree do
		for i, id in list do
			local s = SK[id]
			expect(s ~= nil and s.school == school, ("%s %d차 %s"):format(school, job, id))
			expect(not seenIds[id], "한 스킬은 한 곳에만 " .. id)
			seenIds[id] = true
			eq(ninjutsu.JobOf(id), job, "JobOf " .. id)
			expect(ninjutsu.MaxOf(id) >= 5 and ninjutsu.MaxOf(id) <= 30, "마스터 레벨 " .. id)
			expect(ninjutsu.Belongs(id, school) and not ninjutsu.Belongs(id, if school == "fire" then "ice" else "fire"), "Belongs " .. id)
			if i == 1 then
				expect(ninjutsu.IsActive(id), ("%s %d차 첫 스킬 = 주력기(쓰는 인술)"):format(school, job))
			end
			if s.core then
				cores += 1
				expect(job == 1 and s.kind == "passive", "핵심 장치는 1차 패시브 " .. id)
			end
			if s.fx then
				for _, k in { "shot", "burst", "hit", "burstHit", "markHit", "self", "ring", "row", "front", "zone" } do
					expect(s.fx[k] == nil or fxSheet.rects[s.fx[k]] ~= nil, ("%s 이펙트 %s"):format(id, tostring(s.fx[k])))
				end
			end
		end
	end
	eq(cores, 1, "유파마다 핵심 장치 하나 " .. school)
	expect(#tree[1] >= 3, "1차 고유 스킬 3개 넘게 " .. school)
	local auto = ninjutsu.AutoFor(school, 1)
	expect(#auto == 2 and auto[1] == tree[1][1] and SK[auto[2]].core == true, "1차 전직 때 주력기 + 핵심 장치 " .. school)
	eq(#ninjutsu.TreeFor(school, 1), #tree[1] + #ninjutsu.COMMON[1], "TreeFor = 고유 + 공용 " .. school)
end
for job, list in ninjutsu.COMMON do
	for _, id in list do
		expect(SK[id] ~= nil and SK[id].school == "" and SK[id].kind == "passive", "공용 스킬 " .. id)
		eq(ninjutsu.JobOf(id), job, "공용 JobOf " .. id)
		expect(ninjutsu.Belongs(id, "fire") and ninjutsu.Belongs(id, "rock"), "공용은 모든 유파 " .. id)
	end
end
expect(not ninjutsu.IsActive("f_ember") and ninjutsu.IsActive("fire_ball") and not ninjutsu.IsActive("nothing"), "IsActive")
eq(ninjutsu.Scale("fire_ball", 1), 1, "1레벨 보정")
expect(math.abs(ninjutsu.Scale("fire_ball", ninjutsu.MaxOf("fire_ball")) - (1 + ninjutsu.GROW)) < 1e-9, "마스터 보정 = 1 + GROW")
expect(ninjutsu.Scale("fire_ball", 99) == ninjutsu.Scale("fire_ball", ninjutsu.MaxOf("fire_ball")), "마스터를 넘지 않음")
eq(ninjutsu.LevelOf({ fire_ball = 3 }, "fire_ball"), 3, "LevelOf")
eq(ninjutsu.LevelOf({}, "fire_ball"), 0, "안 배움 = 0")
eq(ninjutsu.LevelOf(nil, "fire_ball"), 0, "표가 없어도 0")
eq(ninjutsu.SpEarned(1, 9), 0, "전직 레벨 전 = 0")
eq(ninjutsu.SpEarned(1, 10), ninjutsu.SP_ON_JOB, "전직한 레벨 = 전직 SP")
eq(ninjutsu.SpEarned(1, 12), ninjutsu.SP_ON_JOB + 2 * ninjutsu.SP_PER_LEVEL, "구간 안에서 오른 레벨마다")
eq(ninjutsu.SpEarned(1, 80), ninjutsu.SP_ON_JOB + 19 * ninjutsu.SP_PER_LEVEL, "다음 전직 레벨 앞까지만")
eq(ninjutsu.SpEarned(2, 35), ninjutsu.SP_ON_JOB + 5 * ninjutsu.SP_PER_LEVEL, "2차 구간")
do
	local d = { Job = 0 }
	expect(not ninjutsu.GrantLevelSp(d, 2) and d.SP == nil, "견습은 레벨업 SP 없음")
	d = { Job = 2, SP = { 1, 0, 0, 0 } }
	expect(ninjutsu.GrantLevelSp(d, 2) and d.SP[2] == 2 * ninjutsu.SP_PER_LEVEL and d.SP[1] == 1, "레벨업 SP는 지금 전직에")
end
for _, name in { "LearnSkill", "SetSkillSlot", "CoreUpdated", "SchoolUpdated" } do
	expect(packets[name] ~= nil, "패킷 등록 " .. name)
end

-- ---- 2) 저장 ----
local fresh = schema.default()
expect(#fresh.SP == 4 and fresh.SP[1] == 0 and #fresh.SkillSlots == ninjutsu.SLOTS and fresh.SkillSlots[1] == "", "새 플레이어: SP 0 · 빈 단축칸")
do
	local old = schema.default()
	old.SchemaVersion, old.SP, old.SkillSlots = 12, nil, nil
	old.School, old.Job, old.Level, old.Ninjutsu = "fire", 1, 12, { fire_ball = 3 }
	schema.migrate(old)
	eq(old.SP[1], ninjutsu.SP_ON_JOB + 2 * ninjutsu.SP_PER_LEVEL, "v13: 1차 구간에서 얻은 SP")
	expect(old.Ninjutsu.fire_ball == 3 and old.Ninjutsu.f_ember == 1, "v13: 옛 두루마리 단계는 레벨로 · 핵심 장치는 배운 것으로")
	expect(old.SkillSlots[1] == "fire_ball" and old.SkillSlots[2] == "", "v13: 단축칸")
	local two = schema.default()
	two.SchemaVersion, two.SP, two.SkillSlots = 12, nil, nil
	two.School, two.Job, two.Level, two.Ninjutsu = "ice", 2, 35, {}
	schema.migrate(two)
	expect(two.SP[1] == ninjutsu.SpEarned(1, 35) and two.SP[2] == ninjutsu.SpEarned(2, 35) and two.SP[3] == 0, "v13: 전직한 구간마다 SP")
	expect(two.SkillSlots[1] == "ice_spike" and two.SkillSlots[2] == "ice_lance", "v13: 전직마다 주력기가 단축칸에")
	local none = schema.default()
	none.SchemaVersion, none.SP, none.SkillSlots = 12, nil, nil
	schema.migrate(none)
	expect(none.SP[1] == 0 and next(none.Ninjutsu) == nil and none.SkillSlots[1] == "", "v13: 견습은 그대로")
end

-- ---- 가짜 플레이어 · 서비스 ----
local p1 = { UserId = 1, Name = "닌자1", Parent = {} }
local byId = { [1] = p1 }
local data = { [p1] = schema.default() }
local where = { [1] = "town_field1" }
local pos = { [1] = V(0, 0) }
local function standAt(x, y) pos[1] = V(x * world.scale, y * world.scale) end
local events, handlers = {}, {}
local function sent(name)
	local out = {}
	for _, e in events do
		if e.name == name then table.insert(out, e) end
	end
	return out
end
local function clear() table.clear(events) end
local function noticed(word)
	for _, e in sent("Notify") do
		if string.find(e.args[1], word, 1, true) then return true end
	end
	return false
end
local function hitsFrom(source)
	local n = 0
	for _, e in sent("TownMonsterHit") do
		if e.args[6] == source then n += 1 end
	end
	return n
end
local function status(kind)
	local n = 0
	for _, e in sent("TownMonsterStatus") do
		if e.args[3] == kind then n += 1 end
	end
	return n
end
MOCK("ReplicatedStorage/shared/net/net", {
	FireClient = function(name, player, ...) table.insert(events, { name = name, player = player, args = { ... } }) end,
	OnServer = function(name, fn) handlers[name] = fn end,
})
MOCK("ServerScriptService/server/modules/heroTracking", {
	PlayersInScene = function(sceneName) return if where[1] == sceneName then { p1 } else {} end,
	GetPosition = function(userId) return pos[userId] end,
	GetPlayerScene = function(userId) return where[userId] end,
	OnSceneChanged = function() end,
})
MOCK("ServerScriptService/server/modules/worldDrops", { List = function() return {} end })
MOCK("ServerScriptService/server/services/persistence", {
	Get = function(player) return data[player] end,
	MarkDirty = function() end,
	Save = function() end,
})
local hurts = {}
MOCK("ServerScriptService/server/services/progressionService", {
	AddExperience = function() end,
	DamagePlayer = function(_, n) table.insert(hurts, n) end,
	Heal = function(player, n)
		local d = data[player]
		local before = d.Health
		d.Health = math.min(balance.maxHealthFor(d.Level), before + n)
		return d.Health - before
	end,
})
MOCK("ServerScriptService/server/services/currencyService", { AddGold = function(player, n) data[player].Gold += n end })
local heartbeat
SERVICE("Players", { GetPlayerByUserId = function(_, id) return byId[id] end, PlayerRemoving = { Connect = function() end } })
SERVICE("RunService", { Heartbeat = { Connect = function(_, fn) heartbeat = fn; return { Disconnect = function() end } end } })

local inventory = req("ServerScriptService/server/services/inventoryService")
local townMonsters = req("ServerScriptService/server/modules/townMonsters")
local ninjutsuService = req("ServerScriptService/server/modules/ninjutsuService")
townMonsters.load()
ninjutsuService.load()

local elder
for _, n in world.scenes.village.npcs do
	if n.type == ninjutsu.CHANGE_NPC then elder = n end
end
local X0, Y0 = 250, 200
local function atElder() where[1] = "town_village"; standAt(elder.x, elder.y + 10) end
local function atField() where[1] = "town_field1"; standAt(X0, Y0) end
-- 새 캐릭터로 1차 전직(Lv.10)
local function newNinja(school)
	advance(120) -- 앞 시험의 쿨타임 · 자리 효과 · 핵심 장치를 흘려보낸다
	data[p1] = schema.default()
	data[p1].Level = 10
	data[p1].Health = balance.maxHealthFor(10)
	atElder()
	handlers.ChooseSchool(p1, school)
	atField()
	clear()
	table.clear(hurts)
	return data[p1]
end
-- 몬스터를 모두 구석으로 치우고 체력을 넉넉히. 앞에서부터 n마리를 돌려준다.
local function monsters()
	local list = townMonsters.Living("field1")
	for _, m in list do
		m.maxHp, m.hp, m.damageBy = 1000000, 1000000, {}
		m.x, m.y, m.home = 8, 8, V(8, 8)
		m.target, m.aggro, m.stunUntil, m.slowUntil, m.ember, m.frost = nil, nil, nil, nil, nil, nil
	end
	return list
end
local function put(m, x, y) m.x, m.y, m.home = x, y, V(x, y) end
local function lost(m) return 1000000 - m.hp end
local function atk() return inventory.GetAttackDamage(p1) end
local function dmg(power) return math.max(1, math.round(atk() * power)) end
local function slots() return table.concat(data[p1].SkillSlots, ",") end
-- 몬스터 m이 p1을 n번 때릴 때까지 시간을 보낸다
local function getHit(m, n)
	townMonsters.Damage("field1", m.id, p1, 1, "test")
	for _ = 1, 300 do
		if #hurts >= n then break end
		advance(0.1)
		heartbeat(0.1)
	end
end
local SWORD_GAP = balance.TOWN_ATTACK_COOLDOWN * weapons.ClassOf(items.Ninjato).speed

-- ---- 3) 1차 전직: SP · 주력기 · 핵심 장치 · 단축칸 ----
local d = newNinja("fire")
expect(d.Job == 1 and d.School == "fire", "1차 전직")
eq(d.SP[1], ninjutsu.SP_ON_JOB, "전직 SP")
expect(d.Ninjutsu.fire_ball == 1 and d.Ninjutsu.f_ember == 1 and d.Ninjutsu.f_blade == nil, "주력기 · 핵심 장치만 1레벨")
eq(slots(), "fire_ball,,,", "주력기가 1번 칸에")

-- ---- 4) 배우기 · 단축칸 ----
clear()
handlers.LearnSkill(p1, "f_blade")
expect(d.Ninjutsu.f_blade == 1 and d.SP[1] == ninjutsu.SP_ON_JOB - 1, "SP 1로 배움")
eq(slots(), "fire_ball,,,", "패시브는 단축칸에 안 들어감")
local su = sent("SchoolUpdated")
expect(#su == 1 and su[1].args[4][1] == d.SP[1] and su[1].args[5][1] == "fire_ball", "SchoolUpdated(유파, 레벨표, 전직, SP, 단축칸)")
handlers.LearnSkill(p1, "ice_spike")
expect(d.Ninjutsu.ice_spike == nil, "다른 유파 스킬은 못 배움")
handlers.LearnSkill(p1, "f_breath")
expect(d.Ninjutsu.f_breath == nil, "아직 안 한 전직의 스킬은 못 배움")
handlers.LearnSkill(p1, "nothing")
handlers.LearnSkill(p1, "fire_ball")
handlers.LearnSkill(p1, "fire_ball")
expect(d.Ninjutsu.fire_ball == 3 and d.SP[1] == 0, "주력기 +2")
clear()
handlers.LearnSkill(p1, "fire_ball")
expect(d.Ninjutsu.fire_ball == 3 and noticed("스킬 포인트"), "SP가 없으면 못 올림")
d.SP[1] = 50
for _ = 1, 30 do handlers.LearnSkill(p1, "f_ember") end
eq(d.Ninjutsu.f_ember, ninjutsu.MaxOf("f_ember"), "마스터 레벨까지만")
eq(d.SP[1], 50 - (ninjutsu.MaxOf("f_ember") - 1), "마스터 뒤에는 SP가 안 줄어듦")
-- 단축칸
handlers.SetSkillSlot(p1, 3, "fire_ball")
eq(slots(), ",,fire_ball,", "칸 옮기기(같은 인술은 한 칸에만)")
handlers.SetSkillSlot(p1, 2, "f_ember")
handlers.SetSkillSlot(p1, 2, "f_breath")
handlers.SetSkillSlot(p1, 9, "fire_ball")
eq(slots(), ",,fire_ball,", "패시브 · 안 배운 인술 · 없는 칸은 무시")
handlers.SetSkillSlot(p1, 3, "")
eq(slots(), ",,,", "칸 비우기")
clear()
handlers.UseNinjutsu(p1, 1, "right")
eq(#sent("NinjutsuCast"), 0, "빈 칸은 아무 일도 없음")
handlers.SetSkillSlot(p1, 1, "fire_ball")
-- 2차 전직: SP · 2차 주력기
d.Level = 30
atElder()
handlers.JobAdvance(p1)
expect(d.Job == 2 and d.SP[2] == ninjutsu.SP_ON_JOB and d.Ninjutsu.f_breath == 1, "2차 전직: SP + 2차 주력기")
eq(slots(), "fire_ball,f_breath,,", "2차 주력기가 빈 칸에")

-- ---- 5) 불: 불씨(쌓임 · 주기 피해 · 최대) + 스킬 레벨 보정 + 달궈진 칼날 ----
d = newNinja("fire")
local list = monsters()
local a, far = list[1], list[2]
put(a, X0 + 50, Y0)
put(far, X0 + 50, Y0 + 60)
handlers.UseNinjutsu(p1, 1, "right")
advance(0.5)
eq(lost(a), dmg(SK.fire_ball.power), "화염구 1레벨")
eq(a.ember[1].stacks, 1, "불씨 1")
local E = SK.f_ember
local tick1 = math.max(1, math.round(atk() * (E.power + E.perLevel * 1) * 1))
advance(E.seconds + 1)
eq(lost(a), dmg(SK.fire_ball.power) + (E.seconds - 1) * tick1, "불씨: 붙어 있는 동안 1초마다 피해")
expect(hitsFrom("nin:burn") == E.seconds - 1, "불씨 피해 출처 = nin:burn")
eq(lost(far), 0, "안 맞은 적은 불씨 없음")
local settled = lost(a)
advance(5)
eq(lost(a), settled, "불씨가 꺼지면 피해 없음")
-- 쌓임: 꺼지기 전에 다시 맞히면 +1(최대 stacks)
for i = 1, E.stacks + 1 do
	handlers.UseNinjutsu(p1, 1, "right")
	advance(SK.fire_ball.cooldown + 0.1)
	if i <= E.stacks then eq(a.ember[1].stacks, i, ("불씨 %d"):format(i)) end
end
eq(a.ember[1].stacks, E.stacks, "불씨는 최대를 넘지 않음")
-- 스킬 레벨: 화염구 5레벨
list = monsters()
a = list[1]
put(a, X0 + 50, Y0)
d.Ninjutsu.fire_ball, d.Ninjutsu.f_ember = 5, nil
advance(20)
handlers.UseNinjutsu(p1, 1, "right")
advance(0.5)
eq(lost(a), math.max(1, math.round(atk() * SK.fire_ball.power * ninjutsu.Scale("fire_ball", 5))), "화염구 5레벨 피해 보정")
advance(3)
expect(a.ember == nil or a.ember[1] == nil, "불씨를 안 배웠으면 안 붙음")
-- 달궈진 칼날: 기본 공격이 3번째로 맞을 때
d.Ninjutsu.f_ember, d.Ninjutsu.f_blade = 1, 2
list = monsters()
a = list[1]
put(a, X0 + 10, Y0)
clear()
for i = 1, SK.f_blade.every do
	advance(1)
	handlers.TownAttack(p1, "right")
	eq(hitsFrom("nin:f_blade"), if i == SK.f_blade.every then 1 else 0, ("달궈진 칼날: %d번째 공격"):format(i))
end
expect(a.ember ~= nil and a.ember[1].stacks == 1, "달궈진 칼날: 불씨 1")

-- ---- 6) 얼음: 서리(느려짐 → 5에서 얼어붙음) + 얼음 갑옷 ----
d = newNinja("ice")
expect(d.Ninjutsu.ice_spike == 1 and d.Ninjutsu.i_frost == 1, "빙문 1차: 얼음 가시 + 서리")
list = monsters()
a = list[1]
put(a, X0 + 30, Y0)
local F = SK.i_frost
for i = 1, F.stacks do
	clear()
	handlers.UseNinjutsu(p1, 1, "right")
	advance(SK.ice_spike.delay + 0.05)
	if i < F.stacks then
		expect(a.frost.stacks == i and status("slow") == 1 and status("stun") == 0, ("서리 %d: 느려짐"):format(i))
	else
		expect(a.frost.stacks == 0 and status("stun") == 1, "서리 5: 얼어붙고 다시 0부터")
	end
	put(a, X0 + 30, Y0)
	a.aggro, a.target = nil, nil
	advance(SK.ice_spike.cooldown)
end
advance(F.seconds + 1)
handlers.UseNinjutsu(p1, 1, "right")
advance(SK.ice_spike.delay + 0.05)
eq(a.frost.stacks, 1, "서리는 시간이 지나면 사라지고 다시 1부터")
-- 얼음 갑옷
handlers.LearnSkill(p1, "i_armor")
list = monsters()
a = list[1]
a.level = 50
put(a, X0 + 8, Y0)
local base = math.max(monsterLevels.AttackDamage(50) - inventory.GetDefense(p1), 1)
table.clear(hurts)
getHit(a, 1)
expect(#hurts >= 1 and hurts[1] == math.max(1, math.round(base * (1 - SK.i_armor.perLevel * 1))), ("얼음 갑옷: 받는 피해 감소(기본 %d → %s)"):format(base, tostring(hurts[1])))
expect(a.frost ~= nil and a.frost.stacks >= 1, "얼음 갑옷: 나를 때린 적에게 서리")

-- ---- 7) 풀: 가시 씨앗(박힘 → 터짐) + 생기 + 치유의 잎 ----
d = newNinja("plant")
expect(d.Ninjutsu.p_seed == 1 and d.Ninjutsu.p_vigor == 1 and d.Ninjutsu.plant_heal == nil, "초문 1차: 가시 씨앗 + 생기")
handlers.LearnSkill(p1, "plant_heal")
eq(slots(), "p_seed,plant_heal,,", "치유의 잎을 배우면 빈 칸에")
list = monsters()
local b
a, b, far = list[1], list[2], list[3]
put(a, X0 + 50, Y0)
put(b, X0 + 50, Y0 + 12)
put(far, X0 + 50, Y0 + 70)
clear()
local S = SK.p_seed
handlers.UseNinjutsu(p1, 1, "right")
advance(0.5)
expect(lost(a) == dmg(S.power) and lost(b) == 0, "씨앗: 처음 닿은 적에게만 박힘")
local V1 = SK.p_vigor.perHit + SK.p_vigor.perLevel * 1
expect(math.abs(ninjutsuService.GetCore(p1) - V1) < 1e-6, "생기: 풀 인술이 맞으면 쌓임")
local cu = sent("CoreUpdated")
expect(#cu == 1 and cu[1].args[1] == "p_vigor" and cu[1].args[3] == SK.p_vigor.stacks, "CoreUpdated(생기, 값, 최대)")
advance(S.fuse)
expect(lost(a) == dmg(S.power) + dmg(S.burstPower) and lost(b) == dmg(S.burstPower), "씨앗: 2초 뒤 둘레에 터짐")
eq(lost(far), 0, "씨앗: 범위 밖")
expect(hitsFrom("nin:p_seed:burst") == 2, "터짐 출처 = nin:p_seed:burst")
expect(math.abs(ninjutsuService.GetCore(p1) - V1 * 3) < 1e-6, "생기: 맞은 횟수만큼")
advance(30)
expect(math.abs(ninjutsuService.GetCore(p1) - V1 * 3) < 1e-6, "생기는 시간이 지나도 남음")
-- 치유의 잎: 생기 30
d.Health = 10
clear()
handlers.UseNinjutsu(p1, 2, "down")
expect(d.Health == 10 and noticed("생기"), "생기가 모자라면 치유를 못 씀")
ninjutsuService.AddCore(p1, 100)
eq(ninjutsuService.GetCore(p1), SK.p_vigor.stacks, "생기 최대")
handlers.UseNinjutsu(p1, 2, "down")
eq(d.Health, 10 + math.round(balance.maxHealthFor(10) * SK.plant_heal.ratio), "치유의 잎: 회복")
eq(ninjutsuService.GetCore(p1), SK.p_vigor.stacks - SK.plant_heal.vigorCost, "치유의 잎: 생기 30 소모")

-- ---- 8) 바위: 견고(맞을 때마다 쌓임 → 받는 피해 감소, 방어 중에는 더 쌓임, 시간이 지나면 사라짐) ----
d = newNinja("rock")
expect(d.Ninjutsu.rock_spike == 1 and d.Ninjutsu.r_firm == 1, "암문 1차: 바위 주먹 + 견고")
handlers.LearnSkill(p1, "rock_guard")
eq(slots(), "rock_spike,rock_guard,,", "바위 갑옷은 1차 스킬")
list = monsters()
a = list[1]
a.level = 50
put(a, X0 + 8, Y0)
base = math.max(monsterLevels.AttackDamage(50) - inventory.GetDefense(p1), 1)
local R = SK.r_firm
table.clear(hurts)
getHit(a, 2)
eq(hurts[1], base, "견고 0: 원래 피해")
eq(hurts[2], math.max(1, math.round(base * (1 - (R.reduce + R.perLevel * 1) * 1))), "견고 1: 피해 감소")
eq(ninjutsuService.GetCore(p1), 2, "두 번 맞음 → 견고 2")
handlers.UseNinjutsu(p1, 2, "down")
table.clear(hurts)
getHit(a, 1)
eq(ninjutsuService.GetCore(p1), 2 + R.guardGain, "바위 갑옷 중에 맞으면 견고가 더 쌓임")
put(a, 8, 8)
a.aggro, a.target = nil, nil
advance(R.seconds + 0.5)
eq(ninjutsuService.GetCore(p1), 0, "견고는 시간이 지나면 사라짐")

-- ---- 9) 번개: 전하(맞을 때마다 쌓임 → 공격이 빨라짐, 3초 안 맞히면 사라짐) + 정전기 ----
d = newNinja("thunder")
expect(d.Ninjutsu.thunder_bolt == 1 and d.Ninjutsu.t_charge == 1, "뇌문 1차: 번개 + 전하")
list = monsters()
a = list[1]
put(a, X0 + 10, Y0)
local T = SK.t_charge
-- 전하가 없을 때: 공격 간격보다 빨리는 못 친다
clear()
handlers.TownAttack(p1, "right")
eq(ninjutsuService.GetCore(p1), 1, "기본 공격이 맞으면 전하 1")
advance(SWORD_GAP * 0.9)
handlers.TownAttack(p1, "right")
eq(ninjutsuService.GetCore(p1), 1, "전하 1로는 아직 간격이 모자람")
ninjutsuService.AddCore(p1, 100)
eq(ninjutsuService.GetCore(p1), T.stacks, "전하 최대")
advance(SWORD_GAP * 0.9)
local before = lost(a)
handlers.TownAttack(p1, "right")
expect(lost(a) > before, "전하가 가득하면 같은 간격으로도 공격이 나감(공격이 빨라짐)")
advance(T.seconds + 0.2)
eq(ninjutsuService.GetCore(p1), 0, "3초 동안 못 맞히면 전하가 사라짐")
-- 인술이 맞아도 전하
handlers.UseNinjutsu(p1, 1, "right")
eq(ninjutsuService.GetCore(p1), 1, "번개가 맞으면 전하")
-- 정전기: 4번째로 맞을 때 한 번 더
handlers.LearnSkill(p1, "t_static")
advance(10)
clear()
local got = 0
for _ = 1, SK.t_static.every * 2 do
	advance(1)
	handlers.TownAttack(p1, "right")
end
expect(hitsFrom("nin:t_static") == 2 or hitsFrom("nin:t_static") == 1, ("정전기: %d번 공격에 추가타 %d번"):format(SK.t_static.every * 2, hitsFrom("nin:t_static")))
got = hitsFrom("nin:t_static")
expect(got >= 1, "정전기 추가타")

-- ---- 10) 유파 바꾸기: 옛 유파에 쓴 SP는 돌려받고, 공용은 그대로 ----
d = newNinja("fire")
handlers.LearnSkill(p1, "f_blade")
handlers.LearnSkill(p1, "f_blade")
handlers.LearnSkill(p1, "c_mastery")
eq(d.SP[1], 0, "SP를 다 씀")
d.Gold = ninjutsu.CHANGE_COST
atElder()
handlers.ChooseSchool(p1, "ice")
expect(d.School == "ice" and d.Gold == 0, "유파 바꿈(엽전)")
eq(d.SP[1], 2, "달궈진 칼날에 쓴 SP 2를 돌려받음(그냥 받은 1레벨은 빼고)")
expect(d.Ninjutsu.c_mastery == 1 and d.Ninjutsu.f_blade == nil and d.Ninjutsu.fire_ball == nil, "공용은 남고 옛 유파 스킬은 없어짐")
expect(d.Ninjutsu.ice_spike == 1 and d.Ninjutsu.i_frost == 1, "새 유파의 주력기 · 핵심 장치")
eq(slots(), "ice_spike,,,", "단축칸은 새 유파로")

-- ---- 11) 공용 패시브: 기력 단련 · 무기 단련 ----
d = newNinja("fire")
clear()
local attack0 = atk()
handlers.LearnSkill(p1, "c_energy")
local eu = sent("EnergyUpdated")
expect(#eu == 1 and eu[1].args[2] == ninjutsu.ENERGY_MAX + SK.c_energy.maxPerLevel, "기력 단련: 최대 기력")
expect(math.abs(eu[1].args[3] - (ninjutsu.ENERGY_REGEN + SK.c_energy.regenPerLevel)) < 1e-9, "기력 단련: 회복")
handlers.LearnSkill(p1, "c_mastery")
eq(atk(), math.round(attack0 * (1 + SK.c_mastery.perLevel)), "무기 단련: 공격력")

-- ---- 12) 스킬 창(globals/ninjutsu.luau buildSkillWindow)의 글 자리: 잘리지 않고 들어가는가 ----
local text = req("Client/ui/pixelText")
local SW = 372
local LIST_W, INFO_W = 168, SW - 190 - 14
local function fits(str, width, lines)
	return text.Fit(str, width, lines) == (if lines == 1 then str else text.Wrap(str, width))
end
for id, sk in SK do
	if ninjutsu.JobOf(id) then
		expect(fits(sk.name, LIST_W - 30, 1), "스킬 창 목록 이름 " .. sk.name)
		expect(fits(("Lv %d/%d"):format(ninjutsu.MaxOf(id), ninjutsu.MaxOf(id)), LIST_W - 30, 1), "스킬 창 레벨 " .. id)
		local kind = if sk.core then "핵심 장치" elseif sk.kind == "passive" then "패시브" else "쓰는 인술"
		expect(fits(("%s · Lv %d/%d"):format(kind, ninjutsu.MaxOf(id), ninjutsu.MaxOf(id)), INFO_W, 1), "스킬 창 종류 줄 " .. id)
		expect(fits(sk.desc, INFO_W, 4), ("스킬 창 설명(4줄) %s: %s"):format(id, sk.desc))
		if ninjutsu.IsActive(id) then
			local cost = if sk.vigorCost then ("생기 %d"):format(sk.vigorCost) else ("기력 %d"):format(sk.cost)
			expect(fits(("%s · 쿨타임 %s초"):format(cost, tostring(sk.cooldown)), INFO_W, 1), "스킬 창 기력 줄 " .. id)
		end
	end
end
for _, sk in { SK.p_vigor, SK.r_firm, SK.t_charge } do
	expect(fits(("%s %d/%d"):format(sk.name, sk.stacks, sk.stacks), 26 * 4 + 4 * 3, 1), "핵심 장치 표시 " .. sk.name)
end

-- =====================================================================================================
-- 2차 스킬(유파마다 5개): 새 종류(설치 · 버프 · 점화 · 깨뜨리기 · 방전 · 분신 · 되받아치기)와 덧붙임(여러 번 · 나눠 터짐 · 끌어당김 · 연달아 · 표식)
-- =====================================================================================================
local function zoneEnds()
	local n = 0
	for _, e in sent("NinjutsuCast") do
		if e.args[3] == "zone_end" then n += 1 end
	end
	return n
end
-- 2차 전직까지 한 새 캐릭터: 2차 스킬을 모두 1레벨로 배우고(SP 넉넉히) want를 2 · 3 · 4번 칸에 넣는다
local function ninja2(school, want)
	local nd = newNinja(school)
	nd.Level = 30
	nd.Health = balance.maxHealthFor(30)
	atElder()
	handlers.JobAdvance(p1)
	nd.SP[2] = 50
	for _, id in ninjutsu.TREE[school][2] do
		if (nd.Ninjutsu[id] or 0) < 1 then handlers.LearnSkill(p1, id) end
	end
	for i, id in want or {} do
		handlers.SetSkillSlot(p1, i + 1, id)
	end
	atField()
	for _, m in townMonsters.Living("field1") do
		m.mark, m.shock, m.rootUntil, m.frozenUntil, m.nextAttack = nil, nil, nil, nil, nil
	end
	advance(120)
	clear()
	table.clear(hurts)
	return nd
end
for _, school in ninjutsu.SCHOOLS do
	local two = ninjutsu.TREE[school][2]
	eq(#two, 5, "2차 고유 스킬 5개 " .. school)
	local kinds, passives = {}, 0
	for _, id in two do
		if ninjutsu.IsActive(id) then kinds[SK[id].kind] = true else passives += 1 end
	end
	local n = 0
	for _ in kinds do n += 1 end
	expect(n >= 3 and passives >= 1, ("2차는 쓰는 법이 3가지 넘게 + 패시브 %s(%d가지)"):format(school, n))
end
expect(packets.BuffUpdated ~= nil, "패킷 등록 BuffUpdated")
local b, c, l0

-- ---- 13) 불 2차: 화염 방사 · 점화 · 불기둥 · 열기 · 타오르는 마음 ----
d = ninja2("fire", { "f_breath", "f_ignite", "f_pillar" })
eq(slots(), "fire_ball,f_breath,f_ignite,f_pillar", "화문 2차 단축칸")
d.Ninjutsu.f_ember, d.Ninjutsu.f_drain = nil, nil -- 불씨 없이 맞는 횟수만 본다
list = monsters()
a = list[1]
put(a, X0 + 30, Y0)
handlers.UseNinjutsu(p1, 2, "right")
advance(SK.f_breath.delay + SK.f_breath.interval * 3 + 0.05)
eq(hitsFrom("nin:f_breath"), SK.f_breath.hits, "화염 방사: 네 번 태움")
eq(lost(a), SK.f_breath.hits * dmg(SK.f_breath.power), "화염 방사 피해")
-- 점화: 불씨가 걸린 적이 불씨 수만큼 터지고, 옆의 적에게 불씨가 옮겨붙는다
d.Ninjutsu.f_ember = 1
list = monsters()
a, b = list[1], list[2]
put(a, X0 + 50, Y0)
put(b, X0 + 50, Y0 + 40)
clear()
handlers.UseNinjutsu(p1, 3, "right")
expect(#sent("NinjutsuCast") == 0 and noticed("불씨"), "점화: 불씨가 걸린 적이 없으면 못 씀")
handlers.UseNinjutsu(p1, 1, "right")
advance(0.6)
eq(a.ember[1].stacks, 1, "화염구로 불씨 1")
put(b, X0 + 50, Y0 + 20) -- 터질 때 옆에 있는 적
local beforeA = lost(a)
clear()
handlers.UseNinjutsu(p1, 3, "right")
eq(lost(a) - beforeA, dmg(SK.f_ignite.power * 1), "점화: 불씨 1개만큼 터짐")
expect(a.ember[1].untilT == 0 and b.ember ~= nil and b.ember[1].stacks == 1, "점화: 불씨를 다 쓰고 옆의 적에게 옮겨붙음")
-- 불기둥: 설치 — 6초 동안 0.5초마다
d.Ninjutsu.f_ember = nil
list = monsters()
a = list[1]
put(a, X0 + SK.f_pillar.offset + 4, Y0)
advance(30)
clear()
handlers.UseNinjutsu(p1, 4, "right")
local zc = sent("NinjutsuCast")
expect(#zc == 1 and zc[1].args[3] == "f_pillar" and zc[1].args[4] == X0 + SK.f_pillar.offset and zc[1].args[8] == SK.f_pillar.seconds and #zc[1].args[9] == 1, "불기둥: NinjutsuCast(자리, 지속 시간, { 번호 })")
advance(SK.f_pillar.seconds + 1)
eq(hitsFrom("nin:f_pillar"), SK.f_pillar.seconds / SK.f_pillar.interval - 1, "불기둥: 서 있는 동안 0.5초마다 태움")
eq(zoneEnds(), 1, "불기둥: 시간이 다 되면 사라짐(zone_end)")
-- 열기: 공격력 버프(120초)
handlers.SetSkillSlot(p1, 4, "f_heat")
advance(60)
clear()
local a0 = atk()
handlers.UseNinjutsu(p1, 4, "right")
local H = SK.f_heat
eq(atk(), math.round(a0 * (1 + H.buff.attack + H.buff.attackPerLevel * 1)), "열기: 공격력 +")
local bu = sent("BuffUpdated")
expect(#bu == 1 and bu[1].args[1] == "attack" and bu[1].args[3] == H.seconds and noticed("열기"), "BuffUpdated(attack, 값, 초)")
advance(H.seconds + 1)
eq(atk(), a0, "열기가 끝나면 원래 공격력")
-- 타오르는 마음: 내 불씨가 걸린 적 수만큼 인술 피해 +
d.Ninjutsu.f_ember, d.Ninjutsu.f_drain = 1, 1
list = monsters()
a, b = list[1], list[2]
put(a, X0 + 50, Y0)
put(b, X0 + 50, Y0 + 12)
handlers.UseNinjutsu(p1, 1, "right") -- 둘 다 맞고 불씨가 붙는다
advance(0.6)
expect(a.ember[1].stacks == 1 and b.ember[1].stacks == 1, "두 마리에 불씨")
advance(SK.fire_ball.cooldown)
clear()
handlers.UseNinjutsu(p1, 1, "right")
advance(0.6)
local direct = 0
for _, e in sent("TownMonsterHit") do
	if e.args[2] == a.id and e.args[6] == "nin:fire_ball" then direct = e.args[4] end
end
eq(direct, math.max(1, math.round(atk() * SK.fire_ball.power * (1 + (SK.f_drain.base + SK.f_drain.perLevel * 1) * 2))), "타오르는 마음: 불씨 걸린 적 2마리만큼 피해 +")

-- ---- 14) 얼음 2차: 빙창 · 깨뜨리기 · 얼음 벽 · 얼음 분신 · 차가운 피 ----
d = ninja2("ice", { "i_shatter", "i_wall", "i_decoy" })
expect(d.Ninjutsu.ice_lance == 1, "빙창은 2차 주력기")
d.Ninjutsu.i_cold = nil
list = monsters()
a, b, c = list[1], list[2], list[3]
put(a, X0 + 30, Y0)
put(b, X0 + 60, Y0) -- 내 둘레 밖, a의 조각이 닿는 자리
put(c, X0 - 20, Y0)
a.frozenUntil = math.huge -- 얼어붙은 적
handlers.UseNinjutsu(p1, 2, "right")
advance(SK.i_shatter.delay + 0.05)
eq(lost(a), dmg(SK.i_shatter.power * SK.i_shatter.shatter.mult), "깨뜨리기: 얼어붙은 적은 깨짐(큰 피해)")
eq(lost(b), dmg(SK.i_shatter.shatter.shard), "깨뜨리기: 조각이 옆의 적에게")
expect(lost(c) == dmg(SK.i_shatter.power) and c.frost.stacks == SK.i_shatter.frost, "깨뜨리기: 얼지 않은 적은 피해 + 서리 2")
expect(a.frozenUntil == nil and hitsFrom("nin:i_shatter:shard") == 1, "깨진 적은 더는 얼어 있지 않음 · 조각 출처")
-- 얼음 벽: 닿은 적이 멈춰 선다
list = monsters()
a = list[1]
put(a, X0 + SK.i_wall.offset + 2, Y0)
clear()
handlers.UseNinjutsu(p1, 3, "right")
advance(SK.i_wall.seconds + 1)
expect(status("stun") >= 5 and lost(a) == 0 and zoneEnds() == 1, "얼음 벽: 서 있는 동안 닿은 적을 멈춰 세움(피해 없음)")
-- 얼음 분신: 나를 쫓던 적이 나를 놓치고, 분신이 깨지며 서리
list = monsters()
a = list[1]
put(a, X0 + 20, Y0)
a.aggro = 1
handlers.UseNinjutsu(p1, 4, "right")
expect(a.aggro == nil, "얼음 분신: 나를 쫓던 적이 나를 놓침")
advance(SK.i_decoy.seconds + 0.1)
eq(a.frost.stacks, SK.i_decoy.frost, "얼음 분신: 깨지며 서리 2")
-- 차가운 피: 서리가 걸린 적에게 인술 피해 +
d.Ninjutsu.i_cold = 1
advance(20)
list = monsters()
a = list[1]
put(a, X0 + 30, Y0)
handlers.UseNinjutsu(p1, 1, "right") -- 얼음 가시(맞는 순간에는 아직 서리가 없다)
advance(SK.ice_spike.delay + 0.05)
eq(lost(a), dmg(SK.ice_spike.power), "서리가 없는 적: 보정 없음")
advance(SK.ice_spike.cooldown)
l0 = lost(a)
put(a, X0 + 30, Y0)
handlers.UseNinjutsu(p1, 1, "right")
advance(SK.ice_spike.delay + 0.05)
eq(lost(a) - l0, math.max(1, math.round(atk() * SK.ice_spike.power * (1 + SK.i_cold.perLevel * 1))), "차가운 피: 서리가 걸린 적에게 피해 +")

-- ---- 15) 풀 2차: 덩굴 채찍 · 덩굴 묶기 · 치유꽃 · 뿌리 내림 · 숲의 숨결 ----
d = ninja2("plant", { "p_whip", "p_flower", "p_breath" })
d.Ninjutsu.p_root = nil
list = monsters()
a = list[1]
put(a, X0 + 40, Y0)
handlers.UseNinjutsu(p1, 2, "right")
advance(SK.p_whip.delay + 0.3)
eq(lost(a), dmg(SK.p_whip.power), "덩굴 채찍 피해")
expect(a.x < X0 + 40 - SK.p_whip.pull * 0.5, ("덩굴 채찍: 내 쪽으로 끌려옴(%.1f)"):format(a.x))
-- 치유꽃: 심은 자리 둘레의 아군이 1초마다 회복
monsters()
d.Health = 10
handlers.UseNinjutsu(p1, 3, "right")
advance(5.5)
eq(d.Health, 10 + 5 * math.max(1, math.round(balance.maxHealthFor(30) * SK.p_flower.heal)), "치유꽃: 1초마다 회복")
standAt(X0 + 200, Y0)
local hp = d.Health
advance(5)
eq(d.Health, hp, "치유꽃: 멀어지면 회복하지 않음")
standAt(X0, Y0)
-- 숲의 숨결: 2초마다 회복(120초)
advance(30)
d.Health = 10
handlers.UseNinjutsu(p1, 4, "right")
advance(6.5)
eq(d.Health, 10 + 3 * math.max(1, math.round(balance.maxHealthFor(30) * SK.p_breath.buff.regen)), "숲의 숨결: 2초마다 회복")
-- 뿌리 내림: 뿌리 표식이 있는 적을 치면 생기가 더 쌓임
d.Ninjutsu.p_root = 1
list = monsters()
a = list[1]
put(a, X0 + 50, Y0)
advance(200)
ninjutsuService.AddCore(p1, -1000)
handlers.UseNinjutsu(p1, 1, "right")
advance(0.5)
local V2 = (SK.p_vigor.perHit + SK.p_vigor.perLevel * 1) * (1 + SK.p_root.vigorPerLevel * 1)
expect(a.rootUntil ~= nil and math.abs(ninjutsuService.GetCore(p1) - V2) < 1e-6, "뿌리 내림: 씨앗이 박히면 뿌리 표식 · 생기 +10%")

-- ---- 16) 바위 2차: 지면 강타 · 되받아치기 · 바위 던지기 · 발 구르기 · 무거운 몸 ----
d = ninja2("rock", { "r_crack", "r_counter", "r_throw" })
d.Ninjutsu.r_heavy = nil
list = monsters()
a, b, c = list[1], list[2], list[3]
put(a, X0 + 12, Y0)
put(b, X0 + 36, Y0)
put(c, X0 + 60, Y0)
local K = SK.r_crack
handlers.UseNinjutsu(p1, 2, "right")
advance(K.delay + 0.02)
expect(lost(a) == dmg(K.power) and lost(b) == 0 and lost(c) == 0, "지면 강타: 첫 균열")
advance(K.segDelay)
expect(lost(b) == math.max(1, math.round(atk() * K.power * K.falloff)) and lost(c) == 0, "지면 강타: 둘째 균열(한 박자 늦게, 약하게)")
advance(K.segDelay)
eq(lost(c), math.max(1, math.round(atk() * K.power * K.falloff ^ 2)), "지면 강타: 셋째 균열")
eq(lost(a), dmg(K.power), "지면 강타: 한 번씩만 맞음")
-- 되받아치기: 자세 중에 맞으면 피해 없이 충격파 + 견고 가득
list = monsters()
a = list[1]
a.level = 50
put(a, X0 + 8, Y0)
a.aggro, a.nextAttack = 1, 0
table.clear(hurts)
handlers.UseNinjutsu(p1, 3, "right")
heartbeat(0.1)
expect(#hurts == 0 and lost(a) == dmg(SK.r_counter.power), ("되받아치기: 피해 없이 되받아침(맞은 횟수 %d, 몬스터 피해 %d)"):format(#hurts, lost(a)))
eq(ninjutsuService.GetCore(p1), SK.r_firm.stacks, "되받아치기: 견고 가득")
-- 바위 던지기: 견고를 실어 던진다
list = monsters()
a = list[1]
put(a, X0 + 50, Y0)
advance(SK.r_firm.seconds + 1)
ninjutsuService.AddCore(p1, 2)
clear()
handlers.UseNinjutsu(p1, 4, "right")
eq(ninjutsuService.GetCore(p1), 0, "바위 던지기: 견고를 다 씀")
advance(1)
eq(lost(a), math.max(1, math.round(atk() * SK.r_throw.power * (1 + SK.r_throw.firmBonus * 2))), "바위 던지기: 견고 2만큼 피해 +")
eq(status("stun"), 1, "바위 던지기: 멈춤")
-- 발 구르기: 둘레 멈춤 + 견고 1
handlers.SetSkillSlot(p1, 4, "r_stomp")
list = monsters()
a = list[1]
put(a, X0 + 20, Y0)
clear()
handlers.UseNinjutsu(p1, 4, "right")
eq(ninjutsuService.GetCore(p1), SK.r_stomp.firmGain, "발 구르기: 견고 1")
advance(SK.r_stomp.delay + 0.05)
expect(lost(a) == dmg(SK.r_stomp.power) and status("stun") == 1, "발 구르기: 피해 + 멈춤")
-- 무거운 몸: 받는 피해 감소
d.Ninjutsu.r_heavy = 1
advance(SK.r_firm.seconds + 5)
list = monsters()
a = list[1]
a.level = 50
put(a, X0 + 8, Y0)
table.clear(hurts)
getHit(a, 1)
eq(hurts[1], math.max(1, math.round((monsterLevels.AttackDamage(50) - inventory.GetDefense(p1)) * (1 - SK.r_heavy.perLevel * 1))), "무거운 몸: 받는 피해 -")

-- ---- 17) 번개 2차: 뇌전 수리검 · 방전 · 번개 덫 · 질풍 · 감전 ----
d = ninja2("thunder", { "t_star", "t_discharge", "t_trap" })
d.Ninjutsu.t_shock = nil
list = monsters()
a = list[1]
put(a, X0 + 50, Y0)
handlers.UseNinjutsu(p1, 2, "right")
eq(#sent("NinjutsuCast"), 1, "뇌전 수리검: 첫 발은 바로")
advance(1)
eq(#sent("NinjutsuCast"), SK.t_star.shots, "뇌전 수리검: 세 발을 연달아")
eq(hitsFrom("nin:t_star"), SK.t_star.shots, "뇌전 수리검: 세 번 맞음")
eq(hitsFrom("nin:t_star:mark"), SK.t_star.shots - 1, "표식: 표식이 붙은 뒤의 수리검마다 번개가 떨어짐")
eq(lost(a), SK.t_star.shots * dmg(SK.t_star.power) + (SK.t_star.shots - 1) * dmg(SK.t_star.mark.power), "뇌전 수리검 + 표식 번개 피해")
-- 방전: 전하를 다 써서 둘레에
advance(SK.t_charge.seconds + 1)
list = monsters()
a = list[1]
put(a, X0 + 50, Y0)
clear()
handlers.UseNinjutsu(p1, 3, "right")
expect(#sent("NinjutsuCast") == 0 and noticed("전하"), "방전: 전하가 없으면 못 씀")
ninjutsuService.AddCore(p1, 100)
local stacks = SK.t_charge.stacks
handlers.UseNinjutsu(p1, 3, "right")
local dc = sent("NinjutsuCast")
eq(dc[#dc].args[8], SK.t_discharge.radius + SK.t_discharge.radiusPer * stacks, "방전: 전하가 많을수록 넓음")
advance(SK.t_discharge.delay + 0.05)
eq(lost(a), math.max(1, math.round(atk() * (SK.t_discharge.power + SK.t_discharge.powerPer * stacks))), "방전: 전하가 많을수록 셈")
eq(ninjutsuService.GetCore(p1), 0, "방전: 전하를 다 씀")
-- 번개 덫: 밟으면 한 번 터지고 사라진다
list = monsters()
a = list[1]
clear()
handlers.UseNinjutsu(p1, 4, "right")
advance(3)
eq(hitsFrom("nin:t_trap"), 0, "번개 덫: 아무도 안 밟으면 그대로")
put(a, X0 + SK.t_trap.offset + 2, Y0)
advance(0.6)
expect(hitsFrom("nin:t_trap") == 1 and status("stun") == 1 and zoneEnds() == 1, "번개 덫: 밟으면 감전(피해 + 멈춤)되고 사라짐")
advance(3)
eq(hitsFrom("nin:t_trap"), 1, "번개 덫: 한 번만")
-- 질풍: 공격이 빨라진다
handlers.SetSkillSlot(p1, 4, "t_haste")
advance(60)
list = monsters()
a = list[1]
put(a, X0 + 10, Y0)
handlers.TownAttack(p1, "right")
advance(SWORD_GAP * 0.93)
before = lost(a)
handlers.TownAttack(p1, "right")
eq(lost(a), before, "질풍 없이는 이 간격으로 못 침")
advance(10)
clear()
handlers.UseNinjutsu(p1, 4, "right")
expect(sent("BuffUpdated")[1].args[1] == "haste" and noticed("질풍"), "BuffUpdated(haste)")
handlers.TownAttack(p1, "right")
advance(SWORD_GAP * 0.93)
before = lost(a)
handlers.TownAttack(p1, "right")
expect(lost(a) > before, "질풍: 같은 간격으로도 공격이 나감")
-- 감전: 내 번개에 맞은 적은 내 인술에 더 아프다
d.Ninjutsu.t_shock = 1
advance(30)
list = monsters()
a = list[1]
put(a, X0 + 40, Y0)
handlers.UseNinjutsu(p1, 1, "right")
eq(lost(a), dmg(SK.thunder_bolt.power), "감전 전: 보정 없음")
l0 = lost(a)
advance(SK.thunder_bolt.cooldown + 0.01)
put(a, X0 + 40, Y0)
handlers.UseNinjutsu(p1, 1, "right")
eq(lost(a) - l0, math.max(1, math.round(atk() * SK.thunder_bolt.power * (1 + SK.t_shock.base + SK.t_shock.perLevel * 1))), "감전: 감전된 동안 다시 맞으면 피해 +")

end)
finish()