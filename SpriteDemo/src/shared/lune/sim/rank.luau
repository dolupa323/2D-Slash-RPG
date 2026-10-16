-- 명예의 전당 — 순위판 셋(레벨 · 전투력 · 후원)의 셈.
--  사용자 2026-10-10: "대형 마을마다 명예의 전당 건물 을 만들어서 최대 로벅스 결제자, 전투력 랭킹, 레벨 랭킹 이렇게 캐릭터 닉네임 보여주는 명예의 전당을 만듭니다."
--  여기는 셈만 한다(점수 · 열쇠 · 화면에 보낼 꼴). 순위의 저장(OrderedDataStore)은 서버의 store.luau, 올리고 읽는 때는 world.luau.
--   level = 캐릭터의 레벨 순위(같은 레벨이면 경험치가 많은 쪽이 위) · power = 캐릭터의 전투력 순위 · robux = 계정이 게임에 쓴 로벅스의 순위(이름은 그때 하던 캐릭터).
--  ※ 판에 올리는 수(TOP) · 다시 읽는 간격(REFRESH)은 내 제안이다.
local Rank = {}
Rank.BOARDS = { "level", "power", "robux" }
Rank.NAMES = { level = "레벨", power = "전투력", robux = "후원" }
Rank.TOP = 10 -- 판마다 보이는 수
Rank.REFRESH = 60 -- 서버가 순위를 다시 읽는 간격(초)
local XP_STEPS = 1000000 -- 같은 레벨 안에서 경험치를 가르는 눈금

-- 레벨 순위의 점수: 레벨이 먼저, 그다음 그 레벨에서 모은 경험치의 비율
function Rank.levelScore(level: number, xp: number, need: number): number
	local part = if need > 0 then math.clamp(xp / need, 0, 0.999999) else 0
	return level * XP_STEPS + math.floor(part * XP_STEPS)
end

function Rank.levelOf(score: number): number
	return score // XP_STEPS
end

-- 순위판의 열쇠: 캐릭터(레벨 · 전투력) = "c<사람 번호>_<캐릭터 번호>" · 계정(후원) = "u<사람 번호>"
function Rank.charKey(userId: number, cid: number): string
	return ("c%d_%d"):format(userId, cid)
end
function Rank.userKey(userId: number): string
	return ("u%d"):format(userId)
end
-- 열쇠의 사람 번호(모르는 꼴이면 nil) — 관리자의 줄을 거를 때(2026-10-15)
function Rank.userOf(key: string): number?
	local id = string.match(key, "^c(%d+)_") or string.match(key, "^u(%d+)$")
	return if id then tonumber(id) else nil
end

-- 판에 적는 값의 글(레벨은 Lv.N · 전투력과 후원은 숫자)
function Rank.valueText(board: string, score: number): string
	if board == "level" then
		return ("Lv.%d"):format(Rank.levelOf(score))
	end
	return tostring(score)
end

-- 화면에 보낼 판 하나: rows = { { key, score } … }(높은 차례) · infoOf(key) = { name, class } 또는 nil(이름을 모르는 줄은 뺀다)
function Rank.view(board: string, rows, infoOf)
	local out = {}
	for _, row in rows do
		local info = infoOf(row.key)
		if info and typeof(info.name) == "string" and info.name ~= "" then
			table.insert(out, { name = info.name, class = info.class, value = Rank.valueText(board, row.score), score = row.score })
			if #out >= Rank.TOP then
				break
			end
		end
	end
	return out
end

return Rank
