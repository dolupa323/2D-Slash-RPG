-- 튜토리얼 「달빛 꿈」(2026-10-14) — 새 캐릭터가 사당에서 깨어나기 전의 꿈에서 조작을 하나씩 익힌다(메이플스토리 「테라 블링크」의 번호 붙은 미션처럼).
--  사용자: "처음 게임을 시작하고 별도의 스타트맵을만들어서 거기서 조작을 알려주는 튜토리얼이 필요해 메이플스토리의 테라블링크를 예로들면 되겠다" · 고르신 것: 깨기 전의 꿈 · 안내자 샛별.
--  자료는 공방 js/lune/design/tutorial.js(→ data/ui.generated.luau의 tutorial). 화면이 필요 없는 셈만 여기에 둔다 — 서버(진행을 저장) · 화면(미션 판) · 자동 검사가 같이 쓴다.
--  캐릭터의 tut = { step = 지금 할 미션(1부터), n = 그 미션에서 센 수(수련 인형), done = 꿈에서 깨어났는가 }.
--  미션이 끝나는 때(check)는 둘로 나뉜다: 서버가 아는 일(kill · pickup · potion · stat · sp — 잡기 · 줍기 · 물약 · 능력치 · 스킬 찍기)은 서버가 세고,
--  화면만 아는 일(walk · zone · drop · talk · skill · window)은 화면이 "끝냈다"고 알리면 서버가 그 미션의 차례인지만 보고 넘긴다(꿈의 보상은 없다 — 속여도 얻는 것이 없다).
--  마지막 미션(exit)은 빛나는 문으로 나가는 것 — 서버의 문(onTravel)이 그 차례일 때만 열어 준다.
local UIG = require(script.Parent.Parent.data["ui.generated"])

local T = {}
T.DATA = UIG.tutorial
T.SCENE = T.DATA.scene
T.STEPS = T.DATA.steps
T.TOTAL = #T.DATA.steps
T.SERVER = { kill = true, pickup = true, potion = true, stat = true, sp = true } -- 서버가 세는 일(능력치 · 스킬 찍기는 2026-10-14 둘째 판)
T.CLIENT = { walk = true, zone = true, drop = true, talk = true, skill = true, window = true } -- 화면이 알리는 일

-- 새 캐릭터의 튜토리얼(꿈에서 시작한다)
function T.new()
	return { step = 1, n = 0, done = false }
end

-- 다 마친 것(이미 있던 캐릭터 · 자란 캐릭터 · 건너뛴 캐릭터)
function T.finished()
	return { step = T.TOTAL + 1, n = 0, done = true }
end

-- 저장된 것을 되살린다: 꼴이 이상하거나 없으면(튜토리얼이 생기기 전의 캐릭터) 마친 것으로
function T.unpack(v: any)
	if typeof(v) ~= "table" or typeof(v.step) ~= "number" or v.step ~= math.floor(v.step) or v.step < 1 or v.step > T.TOTAL + 1 then
		return T.finished()
	end
	return { step = v.step, n = if typeof(v.n) == "number" then math.max(0, math.floor(v.n)) else 0, done = v.done == true }
end

function T.pack(t)
	return { step = t.step, n = t.n, done = t.done }
end

-- 지금 할 미션의 자료(없으면 nil — 다 했다)
function T.current(t)
	if not t or t.done then
		return nil
	end
	return T.STEPS[t.step]
end

-- 그 미션의 할 일의 갈래(check의 첫 열쇠): "walk" · "zone" · "drop" · "talk" · "skill" · "kill" · "pickup" · "potion" · "window" · "exit"
function T.kind(def): string
	for k in def.check do
		return k
	end
	return ""
end

-- 다음 미션으로(한 칸)
local function advance(t)
	t.step += 1
	t.n = 0
end

-- 서버가 아는 일이 일어났다(잡기 · 줍기 · 물약). 지금 미션이 그 일이면 세고, 다 했으면 넘긴다. 넘겼으면 true
function T.onEvent(t, kind: string): boolean
	local def = T.current(t)
	if not def or T.kind(def) ~= kind then
		return false
	end
	local need = if kind == "kill" then def.check.kill else 1
	t.n += 1
	if t.n >= need then
		advance(t)
		return true
	end
	return false
end

-- 화면이 "n째 미션을 끝냈다"고 알렸다: 그 미션이 지금 차례이고 화면만 아는 일이면 넘긴다. 넘겼으면 true
function T.report(t, n: any): boolean
	local def = T.current(t)
	if not def or n ~= t.step or not T.CLIENT[T.kind(def)] then
		return false
	end
	advance(t)
	return true
end

-- 빛나는 문으로 나갈 수 있는가(마지막 미션의 차례)
function T.canExit(t): boolean
	local def = T.current(t)
	return def ~= nil and T.kind(def) == "exit"
end

-- 꿈에서 깨어났다(문으로 나갔다 · 건너뛰었다)
function T.finish(t)
	t.step, t.n, t.done = T.TOTAL + 1, 0, true
end

-- ---------- 화면이 보는 것 ----------
-- 화면만 아는 일이 끝났는가. s = { walked(처음 자리에서 걸은 점), zone(지금 선 미션 자리의 id), drop(얇은 발판을 내려왔다), talked(말을 끝낸 주민 id), skill(첫 사냥기를 썼다), windows(열린 창 { [id] = true }) }
function T.met(def, s): boolean
	local c = def.check
	if c.walk then
		return (s.walked or 0) >= c.walk
	elseif c.zone then
		return s.zone == c.zone
	elseif c.drop then
		return s.drop == true
	elseif c.talk then
		return s.talked == c.talk
	elseif c.skill then
		return s.skill == true
	elseif c.window then
		return s.windows ~= nil and s.windows[c.window] == true
	end
	return false
end

-- 그 자리(맵의 tut 구역)에 서 있는가: zones = 장면의 tut([{ id, a, b, y }] — 도트) → 선 구역의 id
function T.zoneAt(zones, x: number, y: number, ground: boolean): string?
	if not ground or not zones then
		return nil
	end
	for _, z in zones do
		if x >= z.a and x < z.b and math.abs(y - z.y) <= 2 then
			return z.id
		end
	end
	return nil
end

-- 미션 판의 글. touch = 스마트폰 단추인가 · key(하는 일) → 키 이름 · skill = 첫 사냥기의 「키 이름」 · potion = 물약이 놓인 칸의 「키」
function T.head(t): string
	local W = T.DATA.words
	local def = T.current(t)
	local n = if def then t.step else T.TOTAL
	return (string.gsub(string.gsub(string.gsub(W.head, "{name}", T.DATA.name), "{n}", tostring(n)), "{total}", tostring(T.TOTAL)))
end

function T.line(def, touch: boolean, key: (string) -> string, skill: string?, potion: string?): string
	local text = if touch then def.touch else def.pc
	text = string.gsub(text, "{key:([%w:]+)}", function(what)
		return key(what)
	end)
	text = string.gsub(text, "{skill}", skill or key("skill"))
	text = string.gsub(text, "{potion}", potion or "물약 칸의 키")
	return text
end

-- 수련 인형 미션의 셈(「수련 인형 잡기 2/3」처럼 — 판의 첫 줄 뒤에)
function T.count(t): string?
	local def = T.current(t)
	if def and def.check.kill then
		return ("%d/%d"):format(t.n, def.check.kill)
	end
	return nil
end

return T
