-- 「달의 계승자」 — 매크로 확인(2026-10-23).
--  사용자: "현재 게임에서 매크로 유저들이 많아 어떻게 잡을지 해결해봐"
--  보는 것: ① 셈(sim/macro.luau) — 사냥 중일 때만 · 처음 30분은 아니다 · 너무 고른 연타는 앞당긴다 · 문제의 꼴 · 통과 · 틀림 · 놓침 · 놓칠수록 긴 기다림 · 24시간 지난 놓침은 잊는다 · 저장
--   ② 방(sim/room.luau) — 보상이 멈춘 사람은 경험치 0 · 퀘스트 처치 수 없음 · 떨어지는 것의 주인이 아니다 · 문제가 떠 있는 동안 맞지 않는다(Hero.hurt)
--   ③ 서버(modules/macroGuard.luau · world.luau) — 사냥 맵에서 쉬지 않고 잡으면 문제가 온다 · 대답으로 통과 · 놓치면 보상 멈춤(계정에 남는다) · 관리자 「보내기 · 풀기」
local Macro = req("ReplicatedStorage/shared/lune/sim/macro")
local D = Macro.DATA
local CHARS = req("ReplicatedStorage/shared/lune/data/chars.generated")

-- ① 셈
for _, kind in D.pool do
	expect(CHARS.chars[kind] and CHARS.chars[kind].clips.idle ~= nil, "문제의 몬스터 그림이 있다: " .. kind)
end
expect(#D.pool >= D.cells, "몬스터가 칸보다 많다")
local rng = Random.new(5)
local function rnd()
	return rng:NextNumber()
end
local function rint(n)
	return rng:NextInteger(1, n)
end
local function hunt(st, t0, minutes, every)
	local t = t0
	while t < t0 + minutes * 60 do
		Macro.onKill(st, t)
		t += every
	end
	return t
end
do
	local st = Macro.new(0, nil)
	expect(Macro.tick(st, 10, { hunt = true }, rnd) == nil, "사냥을 하지 않으면 문제가 없다")
	local t = hunt(st, 0, 4, 6)
	expect(Macro.hunting(st, t), "6초마다 잡으면 사냥 중")
	expect(Macro.tick(st, t, { hunt = true }, rnd) == nil, "처음 5분은 띄우지 않는다(의심 낮음 — 2026-10-24: 30분 → 5분)")
	expect(Macro.tick(st, t, { hunt = false }, rnd) == nil, "사냥 맵이 아니면 띄우지 않는다")
	t = hunt(st, t, 22, 6)
	eq(Macro.tick(st, t, { hunt = true }, rnd), "issue", "쉬지 않고 26분 잡으면 문제를 낸다(의심 낮음 15~25분 — 2026-10-24 사용자: \"매크로검사 주기 짧게해라\")")
	-- 쉼: 5분 넘게 잡지 않으면 처음부터
	local st2 = Macro.new(0, nil)
	local t2 = hunt(st2, 0, 100, 6)
	t2 += D.rest + 1
	t2 = hunt(st2, t2, 6, 6) -- (이 시험은 움직임을 적지 않아 「한자리 사냥」 = 의심 중간(8~12분)이다 — 그보다 짧게)
	expect(Macro.tick(st2, t2, { hunt = true }, rnd) == nil, "쉬었다가 다시 잡기 시작하면 쉬지 않은 시간을 다시 잰다")
	-- 마을에 잠깐 들른 것은 쉼이 아니다 · REST_STAY초 넘게 머물면 쉼(2026-10-24)
	local st3 = Macro.new(0, nil)
	local t3 = hunt(st3, 0, 10, 6)
	Macro.onRest(st3, t3)
	Macro.tick(st3, t3 + 30, { hunt = false }, rnd)
	t3 = hunt(st3, t3 + 40, 16, 6)
	eq(Macro.tick(st3, t3, { hunt = true }, rnd), "issue", "마을에 40초 들렀다 와도 시계는 이어진다(26분 → 문제)")
	local st4 = Macro.new(0, nil)
	local t4 = hunt(st4, 0, 10, 6)
	Macro.onRest(st4, t4)
	Macro.tick(st4, t4 + Macro.REST_STAY + 5, { hunt = false }, rnd)
	t4 = hunt(st4, t4 + Macro.REST_STAY + 10, 6, 6)
	expect(Macro.tick(st4, t4, { hunt = true }, rnd) == nil, "마을에 2분 넘게 머물렀다면 쉼 — 다시 잰다")
	-- 너무 고른 연타 = high(접속 30분 전이라도 앞당긴다)
	local st3 = Macro.new(0, nil)
	local c = 0
	for _ = 1, 40 do
		c += 1.5
		Macro.onSkill(st3, "ax_slam", c)
	end
	eq(Macro.level(st3, 100), "high", "같은 스킬을 1.5초 간격 그대로 40번 = 의심 높음")
	local st4 = Macro.new(0, nil)
	c = 0
	for i = 1, 40 do
		c += 1.2 + (i % 7) * 0.31
		Macro.onSkill(st4, "ax_slam", c)
	end
	eq(Macro.level(st4, 100), "low", "사람처럼 들쭉날쭉하면 의심 낮음")
	local st5 = Macro.new(0, nil)
	for _ = 1, 60 do
		Macro.onSkill(st5, "ax_slam", 0.6 * _) -- 동작이 끝나기를 기다린 연타(1초 안쪽) — 세지 않는다
	end
	eq(#st5.gaps, 0, "1초 안쪽의 간격은 세지 않는다(연타가 동작 끝에 걸려 늘 고르게 오는 것)")
end
do
	-- 문제의 꼴 · 통과
	local st = Macro.new(0, nil)
	local view = Macro.issue(st, 100, rint)
	eq(#view.top, D.pick, "위의 셋")
	eq(#view.cells, D.cells, "아래 아홉")
	expect(view.answer == nil, "화면에 답을 보내지 않는다")
	local picks = {}
	for i, cell in view.cells do
		if table.find(view.top, cell.kind) then
			table.insert(picks, i)
		end
	end
	eq(#picks, D.pick, "아래 아홉에 위의 셋이 하나씩 있다")
	local kinds = {}
	for _, cell in view.cells do
		expect(not kinds[cell.kind], "아래 아홉은 모두 다르다")
		kinds[cell.kind] = true
	end
	eq(Macro.answer(st, "nope", picks, 101), "bad", "다른 문제의 번호는 받지 않는다")
	eq(Macro.answer(st, view.token, { picks[1], picks[1], picks[2] }, 101), "wrong", "겹친 칸 = 틀림")
	eq(Macro.answer(st, view.token, picks, 102), "pass", "맞게 고르면 통과")
	expect(not Macro.pending(st) and not Macro.stopped(st), "통과하면 문제가 사라지고 보상은 그대로")
end
do
	-- 놓침 · 놓칠수록 길게 · 24시간 지나면 잊는다
	local st = Macro.new(0, nil)
	local v = Macro.issue(st, 0, rint)
	local wrong = {}
	for i, cell in v.cells do
		if not table.find(v.top, cell.kind) and #wrong < 3 then
			table.insert(wrong, i)
		end
	end
	eq(Macro.answer(st, v.token, wrong, 1), "wrong", "틀림 1")
	eq(Macro.answer(st, v.token, wrong, 2), "wrong", "틀림 2")
	eq(Macro.answer(st, v.token, wrong, 3), "fail", "세 번 틀리면 놓침")
	expect(Macro.stopped(st), "놓치면 보상 멈춤")
	eq(Macro.retryIn(st, 3), D.stop[1], "첫 놓침은 곧바로 다시 확인할 수 있다")
	local v2 = Macro.issue(st, 10, rint)
	eq(Macro.tick(st, 10 + D.time + 1, { hunt = true }, rnd), "expire", "시간이 다 되면 놓침")
	Macro.fail(st, 10 + D.time + 1)
	eq(Macro.retryIn(st, 10 + D.time + 1), D.stop[2], "24시간 안의 두 번째 놓침 = 10분 기다림")
	expect(v2.token ~= v.token, "문제마다 번호가 다르다")
	local later = 10 + D.forget + 100
	Macro.issue(st, later, rint)
	Macro.fail(st, later)
	eq(#st.saved.fails, 1, "24시간이 지난 놓침은 세지 않는다")
	eq(Macro.retryIn(st, later), D.stop[1], "그래서 다시 첫 놓침의 기다림")
	-- 저장
	local back = Macro.unpack(Macro.pack(st.saved))
	expect(back.stopped and #back.fails == 1 and back.stopUntil == st.saved.stopUntil, "저장하고 다시 읽어도 보상 멈춤 · 놓친 때가 그대로")
	local st2 = Macro.new(later + 5, back)
	expect(Macro.stopped(st2), "다시 들어와도 보상 멈춤")
	-- 보상 멈춤 중에는 저절로 문제를 내지 않는다(그 사람이 「다시 확인」을 누른다)
	local t = hunt(st2, later + 5, 200, 6)
	expect(Macro.tick(st2, t, { hunt = true }, rnd) == nil, "보상 멈춤 중에는 저절로 문제를 내지 않는다")
	Macro.clear(st2)
	expect(not Macro.stopped(st2) and #st2.saved.fails == 0, "관리자가 풀면 보상 멈춤 · 놓친 기록이 지워진다")
end

-- ② 방
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local function ready(room, heroes)
	local mob = room.mobs[1]
	for _ = 1, 200 do
		room:step(heroes, 1 / 20)
		if mob.state ~= "spawn" and mob.state ~= "gone" and mob.state ~= "dead" then
			break
		end
	end
	return mob
end
local function hit(mul)
	return { box = { -400, 400, 200, 200 }, mul = mul, seg = 1, at = 0 }
end
do
	local scene = table.clone(SCENES.scenes.hunt)
	scene.mobs = { scene.mobs[1] }
	local room = Room.new("hunt", scene, Random.new(9))
	local a = Hero.new(8501, "axion")
	local mob = room.mobs[1]
	a.x, a.y, a.invuln = mob.x, mob.y, 99
	ready(room, { [8501] = a })
	a.noReward = true
	local xp0 = a.xp
	local out = room:skillHit(a, hit(9999), a.x, a.y, 1, 1)
	eq(#out.kills, 1, "보상이 멈춘 사람도 잡을 수는 있다")
	local k = out.kills[1]
	eq(a.xp, xp0, "경험치가 오르지 않는다")
	expect(k.credit == nil or table.find(k.credit, 8501) == nil, "퀘스트 · 일일 의뢰의 처치 수를 세지 않는다")
	expect(k.drop == nil and #(k.loot or {}) == 0, "떨어지는 것이 없다(주인이 될 사람이 없다)")
	local b = Hero.new(8502, "riven")
	b.inCheck = true
	b.invuln = 0
	eq(Hero.hurt(b, 50), 0, "문제가 떠 있는 동안 맞지 않는다")
	b.inCheck = nil
	expect(Hero.hurt(b, 5) > 0, "문제가 사라지면 다시 맞는다")
end

-- ③ 서버
local handlers, sent = {}, {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		table.insert(sent, { name = name, player = player, args = { ... } })
	end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("MessagingService", { PublishAsync = function() end, SubscribeAsync = function() end })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end,
	rankRaise = function() end, rankRemove = function() end, rankTop = function() return {} end,
	rankInfoSet = function() end, rankInfoGet = function() return nil end, rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, fn(nil) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
local Guard = req("ServerScriptService/server/lune/modules/macroGuard")
World.start()
local p = { UserId = 8510, Name = "매크로시험", DisplayName = "매크로시험", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
handlers.Ready(p)
local made = handlers.Chars(p, "create", "매크로시험", "axion")
handlers.Chars(p, "enter", made.id)
World.jump(p, "hunt")
local s = World.session(p)
expect(Guard.huntScene("hunt"), "달그림자 사냥터는 사냥 맵")
expect(not Guard.huntScene("town"), "마을은 사냥 맵이 아니다")
World.tick(1.1)
expect(s.macro ~= nil and s.acct.macro == s.macro.saved, "세션이 매크로 확인을 시작했다(계정에 남는 것과 같은 것)")
-- 관리자가 보낸다 → 다음 1초에 문제
Guard.force(s)
table.clear(sent)
World.tick(1.1)
local check = nil
for _, f in sent do
	if f.name == "MacroView" and f.player == p and f.args[1].check then
		check = f.args[1].check
	end
end
expect(check ~= nil and check.answer == nil, "문제가 화면에 갔다(답은 없다)")
expect(s.hero.inCheck == true and s.hero.noReward == true, "문제가 떠 있는 동안: 맞지 않고 보상도 없다")
-- 2026-10-24 사용자 "매크로 뭐 다른 ui 열면 안열린다고 … 매크로 완전히 파훼할수있어야해":
--  ① 문제가 떠 있으면 5초마다 다시 보낸다(다른 창에 가려지거나 닫혀도 다시 뜬다) ② 떠 있는 동안 스킬을 받지 않는다
do
	table.clear(sent)
	for _ = 1, 6 do
		World.tick(1.1)
	end
	local again = 0
	for _, f in sent do
		if f.name == "MacroView" and f.player == p and f.args[1].check and f.args[1].check.token == (check and check.token) then
			again += 1
		end
	end
	expect(again >= 1, "떠 있는 문제를 5초마다 다시 보낸다(" .. again .. "번)")
	s.skill = nil
	handlers.Skill(p, "ax_combo", 1, s.hero.x, s.hero.y, 1)
	expect(s.skill == nil, "문제가 떠 있는 동안 스킬을 받지 않는다")
end
-- 2026-10-28 사용자 "현재 매크로 방지문제가 뜨면 그걸 푸는동안 죽어버려 방지문제를 푸는동안은 무적이여야해": 몬스터 한가운데 체력 1로 20초를 서 있어도 쓰러지지 않는다
do
	local room = World.room(s.scene)
	local mob = nil
	for _, m in room.mobs do
		if not m.afk and not m.away then
			mob = m
			break
		end
	end
	local hp0 = s.hero.hp
	s.hero.hp, s.hero.invuln = 1, 0
	local hurt = 0
	for _ = 1, 400 do
		if mob then
			s.hero.x, s.hero.y = mob.x, mob.y -- 몬스터에 붙어 있다
		end
		World.tick(1 / 20)
		if s.hero.hp < 1 or not s.hero.alive then
			hurt += 1
		end
	end
	expect(s.hero.alive and s.hero.hp == 1, "문제가 떠 있는 동안 몬스터 곁에 20초 서 있어도 맞지 않는다")
	local chasing = 0
	for _, m in room.mobs do
		if m.target == s.hero.id and (m.state == "atk" or m.state == "run") then
			chasing += 1
		end
	end
	eq(chasing, 0, "문제를 푸는 동안 몬스터가 노리지 않는다")
	s.hero.hp = hp0
end
if check then
	local wrong = {}
	for i, cell in check.cells do
		if not table.find(check.top, cell.kind) and #wrong < 3 then
			table.insert(wrong, i)
		end
	end
	for _ = 1, 3 do
		handlers.Macro(p, "answer", check.token, wrong)
	end
	expect(s.macro.saved.stopped and s.acct.macro.stopped, "세 번 틀리면 보상 멈춤(계정에 남는다)")
	expect(s.hero.noReward == true and not s.hero.inCheck, "보상 멈춤: 보상 없음 · 맞기는 한다")
	expect(s.hero.invuln >= 2.9, ("놓쳐 문제가 닫힌 뒤에도 3초 맞지 않는다(%.1f초 — 2026-10-28)"):format(s.hero.invuln))
	local again = handlers.Macro(p, "again")
	expect(again and again.check ~= nil, "첫 놓침은 「다시 확인」으로 곧바로 새 문제")
	if again and again.check then
		local right = {}
		for i, cell in again.check.cells do
			if table.find(again.check.top, cell.kind) then
				table.insert(right, i)
			end
		end
		s.hero.invuln = 0
		local r = handlers.Macro(p, "answer", again.check.token, right)
		expect(r and r.result == "pass" and not r.stopped, "맞히면 통과 · 보상 멈춤이 풀린다")
		expect(s.hero.invuln >= 2.9, ("통과해 문제가 닫힌 뒤 3초 맞지 않는다(%.1f초 — 둘러싼 몬스터에게 바로 쓰러지지 않게)"):format(s.hero.invuln))
		World.tick(1.1)
		expect(not s.hero.noReward and not s.hero.inCheck, "통과한 뒤에는 보상 · 맞기가 그대로")
	end
end
-- ③ 게임 창이 앞에 없는데 스킬이 들어오면(로블록스는 그때 키를 받지 않는다 — 프로그램이 보낸 것) 다섯 번 만에 바로 문제(2026-10-24)
do
	World.tick(1.1)
	expect(s.macro.check == nil, "(통과해서 떠 있는 문제가 없다)")
	s.skill = nil
	handlers.Skill(p, "ax_combo", 1, s.hero.x, s.hero.y, 1)
	expect(s.skill ~= nil and s.skill.id == "ax_combo", "문제가 없으면 스킬을 받는다(위의 「받지 않는다」를 재는 방법이 맞다)")
	World.tick(2)
	handlers.Macro(p, "focus", false)
	expect(s.macroBlur == true, "게임 창이 뒤로 갔다는 알림을 받았다")
	for i = 1, Macro.BLIND.n do
		Guard.onSkill(s, "ax_combo")
	end
	for _ = 1, 20 do
		Macro.onKill(s.macro, os.time()) -- 사냥 중
	end
	table.clear(sent)
	World.tick(1.1)
	expect(s.macro.check ~= nil, "창이 뒤에 있는 동안 스킬 " .. Macro.BLIND.n .. "번 → 통과한 지 얼마 안 됐어도 바로 문제")
	handlers.Macro(p, "focus", true)
	expect(not s.macroBlur, "게임 창이 다시 앞으로")
end
-- ④ 마을에 들러 쉼으로 치는 것은 10분부터(2026-10-24 — 몇 분마다 2분씩 들르는 매크로)
eq(Macro.REST_STAY, 600, "마을 · 실내에 600초 넘게 머물러야 쉼")
World.removePlayer(p)
-- ⑤ 파티를 맺고 잠수한 사람: 파티원이 잡아도 매크로 확인의 처치로 세지 않는다(경험치는 그대로 나눠 받는다)
--  (2026-10-26 사용자: "사냥터에서 그냥 아무것도 안하고 잠수하고있었는데 매크로 정지당했다고억울하다고하면" — 전에는 경험치를 나눠 받는 파티원도 처치로 세었다)
do
	local function join(uid, name, cls)
		local q = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
		handlers.Ready(q)
		local m = handlers.Chars(q, "create", name, cls)
		handlers.Chars(q, "enter", m.id)
		World.jump(q, "hunt")
		local qs = World.session(q)
		qs.hero.level, qs.hero.job = 60, 2
		qs.hero.tut.done = true
		return q, qs
	end
	local pa, a = join(8521, "사냥하는도끼", "axion")
	local pb, b = join(8522, "잠수하는무니", "mooni")
	handlers.Party(pa, "invite", 8522)
	handlers.Party(pb, "accept")
	expect(World.sameParty(8521, 8522), "둘은 파티 · 같은 사냥터")
	World.tick(1.1)
	expect(a.macro ~= nil and b.macro ~= nil, "둘 다 매크로 확인이 시작됐다")
	local room = World.room("hunt")
	local xb0, kills = b.hero.xp, 0
	a.hero.dmgBoost = 1000
	for _ = 1, 80 do
		local foe
		for _, mob in room.mobs do
			if mob.state ~= "gone" and mob.state ~= "dead" and mob.state ~= "spawn" and mob.hp > 0 then
				foe = mob
				break
			end
		end
		if foe then
			a.trust, a.stale = true, nil
			a.hero.x, a.hero.y, a.hero.dir = foe.x - 16, foe.y, 1
			handlers.Move(pa, a.hero.x, a.hero.y, 1)
			handlers.Skill(pa, "ax_combo", 1, a.hero.x, a.hero.y, 1)
			for _ = 1, 5 do
				World.tick(1 / 20) -- 도끼 내려찍기(2026-10-28 액시온 리마스터): 모으는 구간 뒤에 내려찍는 구간을 보낸다
			end
			handlers.Skill(pa, "ax_combo", 2, a.hero.x, a.hero.y, 1)
		end
		for _ = 1, 12 do
			World.tick(1 / 20)
		end
		kills = #a.macro.kills
		if kills >= 8 then
			break
		end
	end
	expect(kills >= 6, "때린 사람(도끼)은 처치가 세진다 — " .. kills)
	eq(#b.macro.kills, 0, "잠수한 파티원(무니)은 처치가 세지지 않는다")
	local now = a.macro.kills[#a.macro.kills] or 0 -- (서버 모듈의 시계 — 시험은 고정된 때를 쓴다)
	expect(Macro.hunting(a.macro, now) and not Macro.hunting(b.macro, now), "도끼만 「사냥 중」")
	expect(b.hero.xp > xb0 or b.hero.level > 60, "잠수한 파티원도 경험치는 그대로 나눠 받는다")
	World.removePlayer(pa)
	World.removePlayer(pb)
end
