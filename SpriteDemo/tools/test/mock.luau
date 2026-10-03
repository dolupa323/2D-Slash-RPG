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
