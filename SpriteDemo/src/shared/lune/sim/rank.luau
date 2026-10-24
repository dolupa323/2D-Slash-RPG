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
local N = require(script.Parent.Parent.config.numbers)
-- 만렙끼리의 차례(2026-10-24 사용자: "만렙이면 찍은 순서대로 제일먼저찍은사람이 1위 여야하는데"): 만렙이 되면 경험치가 0으로 멈춰 모두 점수가 같았다 →
--  로블록스의 순위 저장소는 같은 점수를 아무 차례로나 돌려줘 먼저 찍은 사람이 위에 온다는 보장이 없었다. 이제 만렙의 점수 = 만렙 x 눈금 + (눈금 - 1 - 오른 때의 분)
--  오른 때의 분 = MAX_EPOCH(2026-10-01 0시 한국 시간)부터 센 분 — 먼저 오를수록 점수가 크다. 눈금(100만 분)이 약 1.9년이라 2028년 9월 무렵부터는 그 뒤에 오른 사람끼리 같은 점수가 된다(제가 정한 것)
Rank.MAX_EPOCH = 1790780400 -- 2026-10-01 00:00 한국 시간(= 2026-09-30 15:00 UTC)
-- 오른 때를 적기 전(2026-10-24)에 만렙이 된 캐릭터의 오른 때 — 계정 저장소의 시간별 저장본(UTC 한 시간에 하나 · 30일)에서 찾았다(사용자: "당연히 찾아야지").
--  처음 Lv.150으로 저장된 저장본과 그 앞 저장본(Lv.149의 경험치 · 논 시간)으로 셈한 때: 그 앞 한 시간의 시간당 경험치 그대로 남은 경험치를 벌었다고 본 것(분 단위는 어림 — 차례는 확실하다).
--   강타(무니) 한국 16:34쯤 — 15:59 저장본 Lv.149 45.4% · 16:42 저장본 Lv.150 / 0NJ4(살라맨더) 18:01쯤 — 17:59 Lv.149 96.1% · 18:59 Lv.150 / 여왕(리퍼) 18:36쯤 — 17:59 Lv.149 38.2% · 18:59 Lv.150
--  열쇠 = 순위판의 열쇠(c<사람 번호>_<캐릭터 번호>). 서버가 그 캐릭터를 볼 때 이 때가 더 이르면 이 때로 고친다(world.luau pushRank)
Rank.MAX_FIX = {
	c7932577222_1 = 1792827226, -- 강타 2026-10-24 07:33:46 UTC
	c9233200460_1 = 1792832484, -- 0NJ4 2026-10-24 09:01:24 UTC
	c2995182643_1 = 1792834566, -- 여왕 2026-10-24 09:36:06 UTC
}

-- 레벨 순위의 점수: 레벨이 먼저, 그다음 그 레벨에서 모은 경험치의 비율. 만렙이면 오른 때(maxAt — 먼저 오른 쪽이 위)
function Rank.levelScore(level: number, xp: number, need: number, maxAt: number?): number
	if level >= N.MAX_LEVEL then
		local minutes = math.clamp(math.floor(((maxAt or os.time()) - Rank.MAX_EPOCH) / 60), 0, XP_STEPS - 1)
		return N.MAX_LEVEL * XP_STEPS + (XP_STEPS - 1 - minutes)
	end
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
	local out, keys = {}, {} -- keys = 줄마다의 열쇠(화면에는 보내지 않는다 — 박제한 캐릭터의 줄을 뺄 때)
	for _, row in rows do
		local info = infoOf(row.key)
		if info and typeof(info.name) == "string" and info.name ~= "" then
			table.insert(out, { name = info.name, class = info.class, value = Rank.valueText(board, row.score), score = row.score })
			keys[#out] = row.key
			if #out >= Rank.TOP then
				break
			end
		end
	end
	return out, keys
end

-- 만렙 최초 달성(박제 — 2026-10-24 사용자 "150만렙 맨 처음 찍는 유저 나타나면 … 레벨 랭킹 1위 실시간 박제되게"):
--  레벨 판의 1위에 그 캐릭터를 고정한다(그때의 이름 · 직업 그대로). 판에 같은 캐릭터의 줄이 있으면 뺀다. rows = Rank.view가 만든 판 · rec = { key, name, class } · keys = rows의 줄마다의 열쇠
Rank.FIRST_TITLE = "축하" -- 축하 알림의 머리(화면 위 큰 알림)
Rank.FIRST_TEXT = "「{name}」님이 처음으로 Lv.{level}에 올랐습니다! 레벨 순위 1위에 영원히 새겨집니다."
function Rank.pinFirst(rows, rec, keys, maxLevel: number)
	local out = { { name = rec.name, class = rec.class, value = Rank.valueText("level", maxLevel * XP_STEPS), score = maxLevel * XP_STEPS, first = true } }
	for i, row in rows do
		if (keys == nil or keys[i] ~= rec.key) and row.name ~= rec.name then
			table.insert(out, row)
			if #out >= Rank.TOP then
				break
			end
		end
	end
	return out
end

return Rank
