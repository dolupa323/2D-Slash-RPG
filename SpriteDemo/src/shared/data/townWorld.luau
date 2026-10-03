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
