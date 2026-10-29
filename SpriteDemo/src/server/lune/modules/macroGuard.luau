-- 매크로 확인의 서버(2026-10-23 사용자: "현재 게임에서 매크로 유저들이 많아 어떻게 잡을지 해결해봐") — 셈은 shared/lune/sim/macro.luau · 설계 공방 js/lune/design/macro.js.
--  world.luau가 부른다: start(세션이 생겼다) · onKill · onMove · onSkill · tick(1초마다쯤) · onRemote(화면의 대답 · 「다시 확인」) · save(계정에 남긴다) · force · clear · list(관리 창).
--  하는 일: 사냥 맵에서 쉬지 않고 잡는 사람에게 때가 되면 문제를 보낸다(MacroView { check }) → 화면이 고른 칸을 보낸다(Macro "answer") → 서버가 채점한다.
--   놓치면(시간이 다 됐거나 세 번 틀림) 「사냥 보상 멈춤」 — hero.noReward(방이 경험치 · 달돈 · 떨어지는 것 · 퀘스트 처치 수를 주지 않는다 — sim/room.luau).
--   문제가 떠 있는 동안: hero.inCheck(맞지 않는다 — sim/hero.luau의 Hero.hurt) · 보상도 없다. 둘 다 저장하지 않는 표시다.
--  정지(밴)는 하지 않는다 — 기록을 관리 창에 남겨 사람이 본다(로스트아크 2022: 자동 정지로 정상 이용자가 정지되어 이틀 만에 내렸다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Macro = require(lune.sim.macro)
local SCENES = require(lune.data["scenes.generated"])
local Tutorial = require(lune.sim.tutorial)
local Voyage = require(lune.sim.voyage)
local Net = require(lune.net.net)
local Analytics = require(script.Parent.analytics)
local MD = require(lune.data["macro.generated"])
local COMBAT = require(lune.data["combat.generated"])

local Guard = {}
local rng = Random.new()
local LOG_MAX = 60
Guard.log = {} -- 이 서버의 최근 일(관리 창): { t, uid, name, what = "issue" · "pass" · "wrong" · "fail" · "force" · "clear", n = 놓친 수, wait = 기다릴 초 }

local function note(s, what: string, n: number?, wait: number?)
	table.insert(Guard.log, 1, { t = os.time(), uid = s.player.UserId, name = s.name or s.player.Name, what = what, n = n, wait = wait })
	while #Guard.log > LOG_MAX do
		table.remove(Guard.log)
	end
end

-- 사냥 맵인가(몬스터가 있고 · 마을 · 실내 · 토벌 · 던전 · 보스 방 · 꿈 · 배 위가 아니다)
function Guard.huntScene(key: string?): boolean
	if not key then
		return false
	end
	local base = SCENES.base(key) or key
	local sc = SCENES.scenes[base]
	if not sc or not sc.mobs or #sc.mobs == 0 then
		return false
	end
	if sc.rest or sc.rift or sc.dungeon or (sc.bosses and #sc.bosses > 0) then
		return false
	end
	return not Tutorial.isDream(base) and not Voyage.onShip(base)
end

-- 문제가 닫혔다(통과 · 놓침 · 시간 끝 · 관리자가 풂): MD.after초 동안 맞지 않는다 — 문제를 푸는 동안 둘러싼 몬스터에게 닫히자마자 쓰러지지 않게
--  (2026-10-28 사용자 "현재 매크로 방지문제가 뜨면 그걸 푸는동안 죽어버려 방지문제를 푸는동안은 무적이여야해" — 떠 있는 동안은 Hero.hurt가 막고 몬스터 · 날파리가 노리지 않는다)
local function shield(s)
	if s.hero then
		s.hero.invuln = math.max(s.hero.invuln or 0, MD.after)
	end
end

-- 방이 보는 표시(저장하지 않는다)
local function mark(s)
	local st = s.macro
	if st and s.hero then
		s.hero.noReward = Macro.stopped(st) or Macro.pending(st) or nil
		s.hero.inCheck = Macro.pending(st) or nil
	end
end

-- 화면에 알린다: 떠 있는 문제 · 보상 멈춤(다시 확인까지 남은 초) · 방금의 결과
local function push(s, result: string?)
	local st = s.macro
	if not st then
		return
	end
	local now = os.time()
	Net.FireClient("MacroView", s.player, {
		check = Macro.view(st, now),
		stopped = Macro.stopped(st),
		retryIn = Macro.retryIn(st, now),
		result = result,
	})
end

function Guard.start(s)
	local acct = s.acct
	s.macro = Macro.new(os.time(), if acct then acct.macro else nil)
	if acct then
		acct.macro = s.macro.saved -- 같은 것을 가리킨다(저장하면 그대로 남는다)
	end
	mark(s)
	if Macro.stopped(s.macro) then
		push(s, nil) -- 보상 멈춤인 채 들어왔다: 화면 위의 「사냥 보상 멈춤」
	end
end

function Guard.onKill(s)
	if s.macro then
		Macro.onKill(s.macro, os.time())
	end
end

function Guard.onMove(s, x: number, y: number)
	if s.macro then
		Macro.onMove(s.macro, x, y, os.time())
	end
end

function Guard.onSkill(s, id: string)
	if s.macro then
		Macro.onSkill(s.macro, id, os.clock())
		-- 게임 창이 앞에 없는데(다른 창을 보고 있다 · 내려 두었다) 스킬이 들어왔다 = 사람이 누른 것이 아니다(2026-10-24)
		if s.macroBlur then
			Macro.onBlind(s.macro, os.time())
		end
	end
end

-- 장면이 바뀌었다(마을 · 실내 = 쉼)
function Guard.onScene(s, key: string)
	local base = SCENES.base(key) or key
	local sc = SCENES.scenes[base]
	if s.macro and sc and sc.rest then
		Macro.onRest(s.macro, os.time())
	end
end

-- 1초마다쯤
function Guard.tick(s, key: string?)
	if not s.macro and s.acct then
		Guard.start(s) -- 계정이 열린 세션을 처음 볼 때(손님 · 새 계정 · 옛 계정 모두 — 2026-10-23)
	end
	local st = s.macro
	if not st or not s.hero then
		return
	end
	mark(s)
	local now = os.time()
	-- 문제가 떠 있으면 5초마다 다시 보낸다(2026-10-24 사용자: "매크로 뭐 다른 ui 열면 안열린다고" — 다른 창 · 상점에 가려지거나 닫혀도 다시 뜬다. 화면은 같은 문제면 시간만 고친다)
	if Macro.pending(st) and now - (s.macroPushAt or 0) >= 5 then
		s.macroPushAt = now
		push(s, nil)
	end
	local what = Macro.tick(st, now, { hunt = Guard.huntScene(key) }, function()
		return rng:NextNumber()
	end)
	if what == "issue" then
		Macro.issue(st, now, function(n)
			return rng:NextInteger(1, n)
		end)
		note(s, "issue")
		Analytics.custom(s, "MacroCheck", 1, "issue")
		mark(s)
		push(s, nil)
	elseif what == "expire" then
		local n, wait = Macro.fail(st, now)
		shield(s)
		note(s, "fail", n, wait)
		Analytics.custom(s, "MacroCheck", 1, "fail")
		mark(s)
		push(s, "fail")
		s.dirty = true
	end
end

-- 화면이 보낸 것: "answer"(token, 고른 칸들) · "again"(보상 멈춤에서 다시 확인) → 돌려주는 값 { result, check?, stopped, retryIn }
function Guard.onRemote(s, action: string, a: any, b: any)
	local st = s.macro
	if not st then
		return { result = "bad" }
	end
	local now = os.time()
	if action == "answer" then
		local r = Macro.answer(st, a, b, now)
		if r == "pass" or r == "fail" then
			shield(s) -- 문제가 닫혔다
		end
		if r == "pass" or r == "fail" or r == "wrong" then
			local n = if r == "fail" then #st.saved.fails else nil
			note(s, r, n, if r == "fail" then Macro.retryIn(st, now) else nil)
			Analytics.custom(s, "MacroCheck", 1, r)
			s.dirty = true
		end
		mark(s)
		return { result = r, check = Macro.view(st, now), stopped = Macro.stopped(st), retryIn = Macro.retryIn(st, now) }
	elseif action == "again" then
		if Macro.stopped(st) and not Macro.pending(st) and Macro.retryIn(st, now) <= 0 then
			Macro.issue(st, now, function(n)
				return rng:NextInteger(1, n)
			end)
			note(s, "issue")
			mark(s)
		end
		return { result = nil, check = Macro.view(st, now), stopped = Macro.stopped(st), retryIn = Macro.retryIn(st, now) }
	elseif action == "focus" then
		-- 게임 창이 앞에 있는가(화면이 UserInputService.WindowFocused · WindowFocusReleased로 알린다 — 2026-10-24)
		s.macroBlur = a == false or nil
		return { result = nil }
	end
	return { result = "bad" }
end

-- 매크로 방지 날파리(2026-10-28 — design/afk.js의 when): 이 사람에게 날파리를 보낼 때인가 — 「사냥 보상 멈춤」 · 매크로 의심(오래 쉬지 않은 것은 빼고)이 그 단계
--  (사용자 "그냥 뜨는게 아니라 어느정도 매크로라고 판명되면 뜨는걸로하자" — 전에는 2분 동안 아무것도 안 하면 왔다)
function Guard.flyWanted(s): boolean
	local st = s.macro
	if not st or Macro.pending(st) then
		return false
	end
	local W = COMBAT.afk.when
	-- 2026-10-28 사용자 "진짜 매크로여야 나오는수준으로": 「사냥 보상 멈춤」인데도 그 뒤로 kills마리 넘게 잡았을 때만(잠깐 자리를 비워 확인을 놓친 사람은 그동안 잡지 않는다)
	if W.stopped and Macro.stopped(st) and Macro.stopKills(st) >= (W.kills or 0) then
		return true
	end
	return #W.levels > 0 and table.find(W.levels, Macro.level(st, os.time(), true)) ~= nil
end

-- 관리자
function Guard.force(s)
	if s.macro then
		Macro.forceNow(s.macro)
		note(s, "force")
	end
end
function Guard.clear(s)
	if s.macro then
		Macro.clear(s.macro)
		shield(s)
		note(s, "clear")
		mark(s)
		push(s, "pass")
		s.dirty = true
	end
end
-- 관리 창의 줄(이 서버의 사람들 — 의심이 높은 차례): { uid, name, level, suspect, huntMin, fails, stopped, pending }
function Guard.list(sessions)
	local now = os.time()
	local out = {}
	for _, s in sessions do
		local st = s.macro
		if st and s.hero then
			table.insert(out, { uid = s.player.UserId, name = s.name or s.player.Name, level = s.hero.level, suspect = Macro.level(st, now), huntMin = math.floor(Macro.huntFor(st, now) / 60), fails = #st.saved.fails, stopped = Macro.stopped(st), pending = Macro.pending(st) })
		end
	end
	local rank = { high = 3, mid = 2, low = 1 }
	table.sort(out, function(p, q)
		if rank[p.suspect] ~= rank[q.suspect] then
			return rank[p.suspect] > rank[q.suspect]
		end
		return p.fails > q.fails
	end)
	return out
end

return Guard
