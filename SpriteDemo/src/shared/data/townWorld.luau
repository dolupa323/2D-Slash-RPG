-- 공방에서 만든 탑다운 씬들(townWorld.generated) 공용 도우미 — 클라이언트·서버가 같이 쓴다.
-- 로블록스 씬 이름 = "town_" .. 씬 키. 모듈 폴더는 전부 client/modules/town 하나를 같이 쓴다.
local world = require(script.Parent["townWorld.generated"])

local PREFIX = "town_"

local exports = {}
exports.data = world

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
