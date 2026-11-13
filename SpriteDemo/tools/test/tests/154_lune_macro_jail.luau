-- 「달의 계승자」 — 매크로 감옥(2026-11-11 사용자: "매크로 점수 너무 높으면 사냥 정지 아무것도 없는 검정방에 가둬버려 처음엔 5분가두고 그다음에 또 높으면 10분가두고").
--  공방 design/macro.js의 jail · sim/macro.luau(jailDue · jailStart · pack) · server macroGuard.luau(Guard.jail · jailWant) · world.luau(World.jailStep · 들어올 때 · 귀환 주문서)
--  보는 것: ① 셈 — 점수 80 아래 · 사냥 10분 아래 · 문제가 떠 있으면 가두지 않는다 / 1번째 5분 · 2번째 10분 · 3번째도 10분 / 저장했다 읽어도 같다
--   ② 서버 — 심각 + 사냥 10분 → 검정 방(그 사람 혼자) · 화면에 알림 · 귀환 주문서가 쓰이지 않는다(줄지 않는다) · 시간이 다 되면 잡혀 온 자리로
--   ③ 두 번째는 10분 · 관리자 「풀기」로 바로 나온다 · 갇힌 채 나갔다 들어오면 검정 방에서 시작한다
local Macro = req("ReplicatedStorage/shared/lune/sim/macro")
local D = Macro.DATA
local J = D.jail
eq(J.time[1], 300, "1번째 감옥 = 5분(사용자의 숫자)")
eq(J.time[2], 600, "2번째 감옥 = 10분(사용자의 숫자)")

-- ⓪ 증거(2026-11-14 사용자 "지금 매크로가 아니라 애먼사람만 정지시키고있는데?"): 별똥별을 줍지 않고 룬을 풀지 않는 보통 사람 = 80점 「심각」이지만
--  증거(확인을 놓친 채 사냥 · 한 프레임도 안 되는 키 누름)가 없으면 감옥 · 의심 높음 · 자동 경고가 없다. 확인을 놓친 채 사냥을 이었으면 있다
do
	local now = 10 * 86400
	local st = Macro.new(now - 3600, nil)
	st.saved.days[Macro.dayKey(now)] = { m = 60, rc = 60 }
	st.saved.br = string.rep("0", 20)
	local t = Macro.total(st.saved, now)
	expect(t.score >= J.min and t.grade == "severe", ("별똥별 · 룬만으로 %d점(심각)"):format(t.score))
	eq(t.proof, false, "증거 없음")
	st.total = t
	st.jailHunt = J.hunt
	expect(not Macro.jailDue(st, now), "증거가 없으면 가두지 않는다")
	expect(Macro.level(st, now) ~= "high", "증거가 없으면 의심 높음이 아니다(확인은 중간까지)")
	expect(not Macro.warnDue(st, now), "증거가 없으면 자동 경고도 없다")
	-- 확인이 떠 있는데도 사냥을 이어 간 놓침 셋(넷 가운데)
	st.saved.days[Macro.dayKey(now)].ci = 4
	st.saved.days[Macro.dayKey(now)].cf = 3
	local t2 = Macro.total(st.saved, now)
	eq(t2.proof, true, "확인을 놓친 채 사냥한 몫이 크면 증거")
	st.total = t2
	expect(Macro.jailDue(st, now), "증거가 있고 80점 넘으면 가둔다")
	eq(Macro.level(st, now), "high", "증거가 있는 심각 = 의심 높음")
end

-- ① 셈
do
	local st = Macro.new(0, nil)
	st.total = { score = J.min - 1 }
	st.jailHunt = J.hunt
	expect(not Macro.jailDue(st, 100), "점수가 " .. J.min .. " 아래면 가두지 않는다")
	st.total = { score = J.min }
	st.jailHunt = J.hunt - 1
	expect(not Macro.jailDue(st, 100), "사냥한 1분이 " .. J.hunt .. "분 아래면 가두지 않는다")
	Macro.jailMinute(st)
	expect(Macro.jailDue(st, 100), "점수 " .. J.min .. " · 사냥 " .. J.hunt .. "분 → 가둔다")
	st.check = { token = 1 }
	expect(not Macro.jailDue(st, 100), "매크로 확인이 떠 있으면 그 문제가 끝난 뒤에")
	st.check = nil
	local sec, n = Macro.jailStart(st, 100, { k = "hunt", x = 50, y = 60, cid = 3 })
	eq(sec, 300, "1번째 = 300초")
	eq(n, 1, "횟수 1")
	expect(Macro.jailed(st, 399) and not Macro.jailed(st, 400), "300초 동안 갇힌다")
	eq(Macro.jailLeft(st, 250), 150, "남은 시간")
	eq(st.jailHunt, 0, "사냥한 1분을 0부터 다시 센다")
	expect(not Macro.jailDue(st, 200), "갇혀 있는 동안은 또 가두지 않는다")
	-- 저장 → 읽기
	local back = Macro.unpack(Macro.pack(st.saved))
	eq(back.jail.n, 1, "저장: 횟수")
	eq(back.jail.untilT, 400, "저장: 언제까지")
	expect(back.jail.from and back.jail.from.k == "hunt" and back.jail.from.x == 50 and back.jail.from.cid == 3, "저장: 잡혀 온 자리 · 캐릭터")
	eq(#back.jail.log, 1, "저장: 기록")
	expect(Macro.jailedRaw(Macro.pack(st.saved), 300), "저장된 계정 자료만으로도 갇혀 있는지 안다(들어올 때)")
	expect(not Macro.jailedRaw(Macro.pack(st.saved), 400), "시간이 지났으면 아니다")
	Macro.jailFree(st)
	st.jailHunt = J.hunt
	eq((Macro.jailStart(st, 1000, nil)), 600, "2번째 = 600초")
	Macro.jailFree(st)
	eq((Macro.jailStart(st, 2000, nil)), 600, "3번째도 600초(마지막 것)")
	eq(Macro.unpack(nil).jail.n, 0, "새 계정은 0번")
	expect(Macro.pack(Macro.newSaved()).jail == nil, "갇힌 적이 없으면 저장하지 않는다")
end

-- ①-2 사람으로 본다(2026-11-12 사용자: "사람다운 신호가 사람이라고 판단되면 감옥에 넣지않기로 하자"):
--  Ryuville의 꼴 — 행동 평균 0.64 · 창 밖 2번 · 미끼 34/40 · 확인 41번 모두 통과 · 룬의 저주 속 2분 → 종합 80(심각)이었지만 사람으로 보아 감옥 · 자동 경고 없음
--  2026-11-13(사용자 "일반 유저를 매크로라고 낙인을 찍는경우가 많고" · "창내림 세는것도 의미가 없고"): 행동의 무게 0.7 → 0.45 · 창 밖은 점수에서 뺐다 → 종합 45(주의)
do
	local now = 1700000000
	local saved = Macro.newSaved()
	local key = Macro.dayKey(now)
	saved.days[key] = { m = 549, ls = 0.64 * 549, bl = 2, ci = 41, cp = 41, cf = 0, rc = 2, bg = 34, bm = 6 }
	saved.br = string.rep("1", 34) .. string.rep("0", 6)
	local t = Macro.total(saved, now)
	eq(t.score, 45, "Ryuville의 꼴: 종합 45(주의 — 행동만으로는 감옥 80에 닿지 않는다 · 창 밖은 점수에 없다)")
	expect(t.human == true, "미끼 85% · 확인 41번 모두 · 룬 0 · 손 0 → 사람으로 본다")
	local st = Macro.new(now, saved)
	st.total, st.jailHunt = t, J.hunt
	expect(not Macro.jailDue(st, now), "사람으로 보면 감옥에 넣지 않는다")
	expect(not Macro.warnDue(st, now), "자동 경고도 보내지 않는다")
	expect(Macro.recordView(saved, now).human == true, "관리 창의 기록에 「사람으로 봄」")
	-- 하나라도 어긋나면 사람으로 보지 않는다
	saved.days[key].cf = 1
	t = Macro.total(saved, now)
	expect(not t.human, "확인을 한 번 놓쳤다 → 사람으로 보지 않는다")
	st.total = t
	eq(Macro.jailDue(st, now), t.score >= J.min, "그때는 점수대로(" .. t.score .. ")")
	saved.days[key].cf, saved.days[key].bl = 0, 5
	expect(Macro.total(saved, now).human, "창 밖 입력 5번이어도 사람으로 본다(2026-11-13 — 창 밖은 뺐다)")
	eq(Macro.total(saved, now).score, 45, "창 밖 입력은 점수에도 없다")
	saved.days[key].kt, saved.days[key].kz = 400, 330
	expect(not Macro.total(saved, now).human, "키를 한 프레임도 안 되게 누른 것이 80% 넘는다 → 사람으로 보지 않는다(2026-11-13 손의 기록)")
	saved.days[key].kt, saved.days[key].kz = nil, nil
	saved.days[key].bl = 2
	saved.br = string.rep("1", 20) .. string.rep("0", 20)
	expect(not Macro.total(saved, now).human, "미끼를 절반만 주웠다 → 사람으로 보지 않는다")
end

-- ② 서버
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
-- (서버의 모듈이 보는 시계 = 시험 틀의 가짜 시계: tools/test/mock.luau의 osMock.time)
local function serverNow()
	return 1700000000 + math.floor(clock.now)
end
local World = req("ServerScriptService/server/lune/modules/world")
local Guard = req("ServerScriptService/server/lune/modules/macroGuard")
local Bag = req("ReplicatedStorage/shared/lune/sim/bag")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local sc = SCENES.scenes[J.scene]
expect(sc ~= nil and sc.jail and sc.inst == "solo", "검정 방이 게임에 있다(그 사람 혼자)")
eq(#sc.portals + #sc.mobs + #(sc.npcs or {}) + #sc.layers, 0, "문 · 몬스터 · 주민 · 그림이 없다")
eq(sc.sky, "#000000", "검정")
expect(not Guard.huntScene(J.scene), "검정 방은 사냥 맵이 아니다")

World.start()
local p = { UserId = 8540, Name = "감옥시험", DisplayName = "감옥시험", attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
handlers.Ready(p)
local made = handlers.Chars(p, "create", "감옥시험", "axion")
handlers.Chars(p, "enter", made.id)
World.jump(p, "hunt")
local s = World.session(p)
s.hero.tut.done = true
World.tick(1.1)
expect(s.macro ~= nil, "매크로 셈이 시작했다")

-- 심각(종합 85 — 오늘 확인을 잡으면서 놓친 것 4번 · 키를 한 프레임도 안 되게 400번)인 사람이 사냥 맵에서 사냥 중 · 사냥한 1분이 10분 찼다
--  (2026-11-13 전에는 「창 밖 입력 5번」으로 80이었다 — 창 밖은 점수에서 뺐다)
local function readyToJail()
	local now = serverNow()
	Macro.note(s.macro, "ci", 4, now)
	Macro.note(s.macro, "cf", 4, now)
	Macro.note(s.macro, "kt", 400, now)
	Macro.note(s.macro, "kz", 400, now)
	for i = 1, 8 do
		Macro.onKill(s.macro, now)
	end
	s.macro.jailHunt = J.hunt
	s.macroMin = nil -- (1분마다의 셈을 이번 1초에 — 시험의 시계)
	s.loading = nil -- (화면이 장면을 다 열었다)
end
local function lastView()
	local v = nil
	for _, f in sent do
		if f.name == "MacroView" and f.player == p then
			v = f.args[1]
		end
	end
	return v
end
readyToJail()
local hx, hy = s.hero.x, s.hero.y
table.clear(sent)
World.tick(1.1)
expect(Macro.total(s.macro.saved, serverNow()).score >= J.min, "종합 점수가 " .. J.min .. " 넘는다")
eq(SCENES.base(s.scene) or s.scene, J.scene, "검정 방으로 옮겨졌다")
expect(s.scene ~= J.scene and string.find(s.scene, "#", 1, true) ~= nil, "그 사람만의 방(" .. tostring(s.scene) .. ")")
local v = lastView()
expect(v and v.jailNew == 5 and v.jail >= 299, "화면: 「5분 동안 사냥이 정지됩니다」 · 남은 시간")
eq(s.macro.saved.jail.n, 1, "횟수 1")

-- 귀환 주문서가 쓰이지 않는다(주문서도 줄지 않는다)
Bag.give(s.hero, "scroll_return", 1)
table.clear(sent)
handlers.Potion(p, "scroll_return")
local why = nil
for _, f in sent do
	if f.name == "ItemDone" and f.player == p then
		why = f.args[1].why
	end
end
eq(why, J.words.scroll, "귀환 주문서: 「사냥 정지 중에는 쓸 수 없다」")
eq(Bag.count(s.hero, "scroll_return"), 1, "주문서는 그대로")
eq(SCENES.base(s.scene) or s.scene, J.scene, "그대로 검정 방")

-- 시간이 다 됐다 → 잡혀 온 자리로
s.macro.saved.jail.untilT = serverNow() - 1
s.loading = nil
table.clear(sent)
World.tick(1.1)
eq(s.scene, "hunt", "잡혀 온 사냥 맵으로 돌아왔다")
expect(math.abs(s.hero.x - hx) <= 16, "잡혀 온 자리 언저리(" .. hx .. " → " .. s.hero.x .. ")")
v = lastView()
expect(v and v.jailOut == true and v.jail == 0, "화면: 「사냥 정지가 끝났습니다」 · 띠를 닫는다")
expect(s.macro.saved.jail.from == nil, "잡혀 온 자리는 한 번만 쓴다")

-- ③ 두 번째 = 10분 · 관리자 「풀기」
readyToJail()
table.clear(sent)
World.tick(1.1)
eq(SCENES.base(s.scene) or s.scene, J.scene, "두 번째도 검정 방")
v = lastView()
expect(v and v.jailNew == 10, "두 번째는 10분")
Guard.clear(s)
s.loading = nil
World.tick(1.1)
eq(s.scene, "hunt", "관리자가 풀면 바로 나온다")
eq(s.macro.saved.jail.n, 2, "횟수는 그대로 2")

-- 갇힌 채 나갔다 들어오면 검정 방에서 시작한다
readyToJail()
World.tick(1.1)
eq(SCENES.base(s.scene) or s.scene, J.scene, "세 번째 감옥")
World.removePlayer(p)
expect(disk[p.UserId] ~= nil, "계정을 저장했다")
handlers.Ready(p)
handlers.Chars(p, "enter", made.id)
local s2 = World.session(p)
eq(SCENES.base(s2.scene) or s2.scene, J.scene, "다시 들어와도 검정 방에서 시작한다")
s2.loading = nil
World.tick(1.1)
eq(SCENES.base(s2.scene) or s2.scene, J.scene, "시간이 남아 있으면 그대로")
s2.macro.saved.jail.untilT = serverNow() - 1
World.tick(1.1)
eq(s2.scene, "hunt", "끝나면 잡혀 온 자리로(같은 캐릭터)")
World.removePlayer(p)
