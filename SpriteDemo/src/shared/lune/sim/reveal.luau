-- 보스의 출현(2026-11-05 사용자: "내가 퍼블리시를 하면 보스가 바로 열리는게 아니라 1시간에 한번 랜덤 대사로 용암거인이 출현한다는 떡밥 메시지를 계속 전체서버 공지로 멋지게 출력하고,
--  게임 왼쪽 아래에 캐릭터 ui 닉네임 위에 빨간시간이 표시되고 그시간이 다되면 보스 출현이야 1시간정도로 해줘 보스는 바로 열리는게아니고").
--  공방 design/weekboss.js의 reveal = { wait(초), marks(남은 초마다 알림), lines(알림의 말) }. 출현 시각은 서버가 정한다(server modules/reveal.luau — 세계 기록 reveal_<보스>)
--  → 서버 · 화면 모두 Reveal.at[보스]에 적어 둔다(화면은 서버가 보낸 Reveal로). 그 시각이 오기 전에는 그 보스가 닫혀 있다 —
--  보스 퀘스트(sim/quests.luau의 state) · 입장(sim/weekly.luau의 canEnter) · 스케줄러(sim/schedule.luau) · 파티 찾기 · 최초 격파(server world.luau)가 Reveal.open을 본다.
local CITY = require(script.Parent.Parent.data["city.generated"])

local Reveal = {}
Reveal.at = {} :: { [string]: number } -- [보스] = 출현 시각(os.time) — 모르면 없다(그동안은 닫혀 있다)
Reveal.clock = os.time -- (자동 검사가 바꾼다)

local BY = {}
for _, b in CITY.weekly.bosses do
	BY[b.id] = b
end

-- 출현을 기다리는 보스인가(reveal이 있다)
function Reveal.def(bossId: any)
	local b = if typeof(bossId) == "string" then BY[bossId] else nil
	return if b and b.reveal then b.reveal else nil
end

-- 열렸는가: 출현을 기다리지 않는 보스는 늘 · 기다리는 보스는 출현 시각을 알고 그때가 지났을 때만
function Reveal.open(bossId: any, now: number?): boolean
	if not Reveal.def(bossId) then
		return true
	end
	local at = Reveal.at[bossId]
	return at ~= nil and (now or Reveal.clock()) >= at
end

-- 출현까지 남은 초(모르면 nil · 열렸으면 0)
function Reveal.left(bossId: any, now: number?): number?
	if not Reveal.def(bossId) then
		return 0
	end
	local at = Reveal.at[bossId]
	if at == nil then
		return nil
	end
	return math.max(0, at - (now or Reveal.clock()))
end

-- 남은 시간의 글 「47:12」(한 시간이 넘으면 「1:02:05」)
function Reveal.clockText(sec: number): string
	sec = math.max(0, math.ceil(sec))
	local h, m, s = sec // 3600, (sec % 3600) // 60, sec % 60
	if h > 0 then
		return ("%d:%02d:%02d"):format(h, m, s)
	end
	return ("%02d:%02d"):format(m, s)
end

-- 지난 때(prevLeft → nowLeft 사이)에 걸친 알림의 차례(marks의 몇째 — 없으면 nil). 남은 초가 그 mark를 지나는 순간 한 번
function Reveal.markCrossed(def, prevLeft: number, nowLeft: number): number?
	for i, m in def.marks or {} do
		if prevLeft > m and nowLeft <= m then
			return i
		end
	end
	return nil
end

-- 그 차례의 말(모든 서버가 같은 줄 — 차례로 고른다: 출현 시각을 씨앗으로 섞어 해마다 · 판마다 다른 줄)
function Reveal.line(def, bossId: string, i: number): string
	local lines = def.lines or {}
	if #lines == 0 then
		return ""
	end
	if i == #(def.marks or {}) then
		return lines[#lines] -- 마지막 알림 = 마지막 줄(「곧 터진다」)
	end
	local seed = (Reveal.at[bossId] or 0) // 60
	return lines[((seed + i * 5) % math.max(1, #lines - 1)) + 1]
end

return Reveal
