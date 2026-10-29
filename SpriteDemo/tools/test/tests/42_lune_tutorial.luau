-- 「달의 계승자」 — 튜토리얼 「달빛 꿈」(2026-10-14): 새 캐릭터는 사당에서 깨어나기 전의 꿈에서 시작해, 미션 열하나로 조작을 익힌다(메이플스토리 「테라 블링크」처럼).
--  사용자: "처음 게임을 시작하고 별도의 스타트맵을만들어서 거기서 조작을 알려주는 튜토리얼이 필요해 메이플스토리의 테라블링크를 예로들면 되겠다"
--  자료: 공방 js/lune/design/tutorial.js · 맵 maps.js의 dream → shared/lune/sim/tutorial.luau · 서버 world.luau(Net "Tut" · 문 · 잡기 · 줍기 · 물약).
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local Tut = req("ReplicatedStorage/shared/lune/sim/tutorial")
local pixelText = req("Client/ui/pixelText")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small", KIT.font.small, {}) -- 미션 판의 둘째 줄 · 샛별의 말(작은 글씨)
pixelText.Register("body", KIT.font.body, {}) -- 미션 판의 첫 줄(본문 글씨)

-- ---- 1) 자료 ----
local sc = SCENES.scenes[Tut.SCENE]
expect(sc ~= nil, "꿈의 장면이 있다")
eq(Tut.TOTAL, 13, "미션 열셋(둘째 판 — 능력치 · 스킬 찍기를 더했다)")
eq(Tut.kind(Tut.STEPS[Tut.TOTAL]), "exit", "마지막 미션은 빛나는 문으로 나가기")
eq(#sc.portals, 1, "꿈의 문은 하나(사당으로 깨어난다)")
eq(sc.portals[1].to, Tut.DATA.exit, "꿈의 문은 사당으로")
local seen = {}
for i, def in Tut.STEPS do
	expect(not seen[def.id], "미션 이름이 겹치지 않는다 " .. def.id)
	seen[def.id] = true
	local kind = Tut.kind(def)
	expect(Tut.CLIENT[kind] or Tut.SERVER[kind] or kind == "exit", ("%d째 미션의 갈래를 안다 — %s"):format(i, kind))
	if def.check.zone then
		local found = false
		for _, z in sc.tut do
			found = found or z.id == def.check.zone
		end
		expect(found, "맵에 그 미션의 자리가 있다 " .. def.check.zone)
	end
	-- 판의 둘째 줄이 판에 들어간다(PC — 긴 키 이름으로 · 스마트폰)
	local key = function()
		return "PgDn"
	end
	for _, touch in { false, true } do
		local text = Tut.line(def, touch, key, "Ctrl 키 「삼단 베기」", "Shift")
		expect(not string.find(text, "{", 1, true), "바꿔 넣지 못한 자리가 없다 " .. text)
		local w = pixelText.Measure(text, "small")
		expect(w <= Tut.DATA.panel.w - 24, ("판의 둘째 줄이 판에 들어간다 %s(%d)"):format(text, w))
	end
	local head = Tut.head({ step = i, n = 0, done = false }) .. " · " .. def.title .. " 3/3"
	local hw = pixelText.Measure(head, "body")
	local sw = pixelText.Measure(def.say, "small")
	expect(12 + hw + 10 + sw <= Tut.DATA.panel.w - 12, ("판의 첫 줄(제목 + 샛별의 말)이 판에 들어간다 — %s %s(%d)"):format(head, def.say, 12 + hw + 10 + sw))
end
-- 높이: 「뛰기」는 한 번 뛰기로(57점), 「두 번 뛰기」는 한 번으로는 못 오르고 두 번으로는 오른다
do
	local G = req("ReplicatedStorage/shared/lune/config/game")
	local one = G.JUMP ^ 2 / (2 * G.GRAVITY)
	local two = one + (G.JUMP * G.JUMP2) ^ 2 / (2 * G.GRAVITY)
	local ground, ledge, high = 11 * 16, 0, 0
	for _, z in sc.tut do
		if z.id == "ledge" then
			ledge = z.y
		elseif z.id == "high" then
			high = z.y
		end
	end
	expect(ground - ledge < one, "바위 턱은 한 번 뛰어 오른다")
	expect(ledge - high > one and ledge - high < two - 8, "높은 바위는 한 번으로는 못 오르고 두 번 뛰면 오른다")
end

-- ---- 2) 순수한 셈 ----
do
	local t = Tut.new()
	eq(Tut.report(t, 2), false, "차례가 아닌 미션은 넘기지 않는다")
	eq(Tut.report(t, 1), true, "걷기를 끝냈다")
	eq(Tut.onEvent(t, "kill"), false, "지금 미션이 아닌 일은 세지 않는다")
	t.step = 7
	eq(Tut.report(t, 7), false, "서버가 세는 미션(잡기)은 화면이 넘길 수 없다")
	Tut.onEvent(t, "kill")
	Tut.onEvent(t, "kill")
	eq(t.step, 7, "셋 가운데 둘")
	eq(Tut.count(t), "2/3", "판의 셈")
	eq(Tut.onEvent(t, "kill"), true, "셋째에 넘긴다")
	eq(t.step, 8, "다음은 줍기")
	expect(Tut.met(Tut.STEPS[1], { walked = 48 }), "48점 걸으면 걷기 미션")
	expect(not Tut.met(Tut.STEPS[1], { walked = 20 }), "20점으로는 아직")
	eq(Tut.zoneAt(sc.tut, (sc.tut[1].a + sc.tut[1].b) / 2, sc.tut[1].y, true), sc.tut[1].id, "그 자리에 서 있으면 그 자리")
	eq(Tut.zoneAt(sc.tut, (sc.tut[1].a + sc.tut[1].b) / 2, sc.tut[1].y, false), nil, "떠 있으면 아니다")
	expect(Tut.unpack(nil).done, "튜토리얼이 생기기 전의 캐릭터는 마친 것")
end

-- ---- 3) 서버 ----
local handlers = {}
local sent = {}
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
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local disk, names = {}, {}
MOCK("ServerScriptService/server/lune/modules/store", {
	loadAccount = function(id) return disk[id] end,
	saveAccount = function(id, data) disk[id] = data; return true end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id) names[key] = id; return true end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end,
	rankRaise = function() end,
	rankRemove = function() end,
	rankTop = function() return {} end,
	rankInfoSet = function() end,
	rankInfoGet = function() return nil end,
	rankInfoRemove = function() end,
	isOffline = function() return false end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()

local p = { UserId = 4201, Name = "꿈꾼다", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end }
handlers.Ready(p)
local made = handlers.Chars(p, "create", "꿈꾼다", "riven")
local first = handlers.Chars(p, "enter", made.id)
local s = World.session(p)
local h = s.hero
expect(Tut.isDream(first.scene) and first.scene ~= Tut.SCENE, "새 캐릭터는 꿈에서 시작한다(사람마다 따로 된 꿈의 방 — dream#번호 · 2026-10-21) — " .. tostring(first.scene))
eq(first.self.tut.step, 1, "첫 미션부터")
expect(first.self.tutSkip ~= true, "처음 하는 계정은 건너뛸 수 없다")
eq(handlers.Tut(p, "skip", nil), nil, "건너뛰기를 보내도 듣지 않는다")
eq(s.scene, first.scene, "꿈에 그대로 있다")
-- 문은 아직 열리지 않는다
local gate = sc.portals[1]
h.x, h.y = gate.x, gate.y
eq(handlers.Travel(p, gate.to), nil, "미션을 다 하기 전에는 빛나는 문이 열리지 않는다")
-- 화면만 아는 미션(1~6): 차례대로만
eq(handlers.Tut(p, "done", 3).tut.step, 1, "차례가 아닌 미션은 넘기지 않는다")
for n = 1, 6 do
	eq(handlers.Tut(p, "done", n).tut.step, n + 1, ("%d째 미션을 넘긴다"):format(n))
end
eq(handlers.Tut(p, "done", 7).tut.step, 7, "잡기는 화면이 넘길 수 없다")
-- 잡기: 수련 인형 셋(Lv.1) — 사냥기로 잡는다. 잡을 때마다 내 앞에 물약 하나가 떨어진다
local room = World.room(s.scene)
for _, mob in room.mobs do
	eq(mob.lv, Tut.DATA.dummyLv, "꿈의 수련 인형은 가장 약하다")
end
local skillId, skill = nil, nil
for id, sk in COMBAT.skills do
	if sk.who == "riven" and sk.type == "mob" and sk.job == 1 then
		skillId, skill = id, sk
	end
end
local function countDrops(): number
	local n = 0
	for _, d in room.drops do
		if d.owner == h.id and d.kind == "goods" then
			n += 1
		end
	end
	return n
end
local killed = 0
for _ = 1, 3 do
	local target = nil
	for _, mob in room.mobs do
		if mob.hp > 0 and not target then
			target = mob
		end
	end
	if target then
		local guard = 0
		while target.hp > 0 and guard < 400 do
			guard += 1
			h.x, h.y = target.x - 20, target.y
			s.trust, s.stale = true, nil
			handlers.Skill(p, skillId, 1, h.x, h.y, 1)
			for _ = 1, 6 do
				World.tick(1 / 20)
			end
		end
	end
end
for _, mob in room.mobs do
	if mob.hp <= 0 then
		killed += 1 -- (사냥기 한 번에 여럿이 쓰러지기도 한다)
	end
end
eq(killed, 3, "수련 인형 셋을 잡았다")
eq(h.tut.step, 8, "잡기 미션을 넘겼다(줍기로)")
eq(h.level, 2, "수련 인형을 다 잡으면 Lv.2가 된다(미션의 경험치 — 자연스럽게)")
expect((h.ap or 0) > 0 and (h.sp or 0) > 0, "Lv.2에 받은 능력치 · 스킬 점수가 있다")
expect(countDrops() >= 3, "잡을 때마다 물약이 떨어졌다 " .. countDrops())
-- 줍기 → 물약(이 차례가 되면 꿈속에서 조금 다친다)
for id, d in room.drops do
	if d.owner == h.id and d.kind == "goods" then
		h.x, h.y = d.x, d.y
		handlers.Pickup(p, id)
		break
	end
end
eq(h.tut.step, 9, "주웠다 — 물약 미션")
expect(h.hp <= h.maxHp * 0.6 + 1, "물약 미션의 차례에 체력이 60%로 줄었다")
handlers.Potion(p)
eq(h.tut.step, 10, "물약을 마셨다 — 가방 미션")
eq(handlers.Tut(p, "done", 10).tut.step, 11, "가방을 열었다 — 능력치 미션")
eq(handlers.Tut(p, "done", 11).tut.step, 11, "능력치 찍기는 화면이 넘길 수 없다(서버가 본다)")
handlers.StatAuto(p)
eq(h.tut.step, 12, "능력치를 찍었다 — 스킬 미션")
handlers.SkillAuto(p)
eq(h.tut.step, 13, "스킬을 찍었다 — 마지막 미션")
eq(h.level, 2, "그 뒤의 미션은 경험치가 없다(Lv.2로 깬다)")
-- 빛나는 문
h.x, h.y = gate.x, gate.y
local woke = handlers.Travel(p, gate.to)
do
	local gains = 0
	for _, e in sent do
		if e.name == "Gain" and e.player == p then
			gains += 1
		end
	end
	expect(gains >= 6, "미션을 깰 때마다 경험치가 뜬다 " .. gains)
end
expect(woke ~= nil and woke.scene == Tut.DATA.exit and s.scene == Tut.DATA.exit, "빛나는 문으로 나가 사당에서 깨어난다")
expect(h.tut.done, "튜토리얼이 끝났다")
-- 다시 들어와도 사당(꿈에는 다시 들어가지 않는다) · 이 계정의 둘째 캐릭터는 건너뛸 수 있다
World.removePlayer(p)
local again = handlers.Ready(p)
expect(not Tut.isDream(again.scene), "꿈에서 깬 캐릭터는 꿈으로 돌아가지 않는다")
World.removePlayer(p)
local p2 = p
handlers.Ready(p2)
local leave = handlers.Chars(p2, "leave", nil, nil)
local made2 = handlers.Chars(p2, "create", "또꿈꾼다", "axion")
expect(made2 and made2.ok, "둘째 캐릭터를 만든다")
local second = handlers.Chars(p2, "enter", made2.id)
expect(second ~= nil and Tut.isDream(second.scene), "둘째 캐릭터도 꿈에서 시작한다")
expect(second and second.self.tutSkip == true, "한 번 끝낸 계정은 「건너뛰기」가 보인다")
local skipped = handlers.Tut(p2, "skip", nil)
expect(skipped ~= nil and skipped.scene == Tut.DATA.exit and World.session(p2).hero.tut.done, "건너뛰면 사당에서 깨어난다")
