-- 「달의 계승자」 — 탄 채 대쉬 · 호박불 늑대의 빠르기(2026-11-03 사용자 "할로윈 늑대 라이딩을 다른 로벅스 라이딩이랑 동일한 이동속도로 상향시키고, 다른 로벅스 라이딩과
--  랭킹보상으로 지급된 라이딩에 대쉬 기능을 추가해 할로윈늑대는 대쉬 없고 … 지금은 탈것 타고 대쉬하면 탈것 내려지거든? 그게아니라 탈것대쉬가 나가야하는거야"). 보는 것:
--  ① 탈것 표: 로벅스 탈것(달빛 늑대 · 수정 사슴 · 쇠 멧돼지 · 이끼 골렘 · 황금 골렘)과 랭킹 보상(백금 · 실버 · 동색 사슴)에 대쉬 · 호박불 늑대 · 쿠폰의 떠도는 책에는 없다 ·
--     호박불 늑대의 빠르기 = 로벅스 탈것(따로 적지 않음) · 대쉬의 거리 · 빠르기가 서버의 이동 몫 안 · 잔상이 갈라져 보이는 간격(이어서 사용자 "샤샤샥처럼 그 탈것의 그림자가 연속적으로")
--  ② 직업마다 1차 대쉬가 「move」 하나 — 화면(boot.luau trySkill)이 이 종류를 탄 채 대쉬로 받는다
--  ③ 서버 RideDash: 대쉬가 있는 탈것을 탄 동안만 · 다시 쓰기 안에서는 받지 않는다 · 같은 방의 다른 사람에게만 RideDashed(영웅 번호 · 자리 · 쪽) · 내리지 않는다 ·
--     멀리 떨어진 자리를 말하면 서버의 자리로 · 호박불 늑대는 받지 않는다 · 기술(직업의 대쉬)을 보내면 전처럼 내린다
local RIDE = req("ReplicatedStorage/shared/lune/data/ride.generated")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")

-- ① 탈것 표
local WANT = { mount_wolf = true, mount_deer = true, mount_boar = true, mount_golem = true, mount_golem_gold = true, mount_deer_gold = true, mount_deer_silver = true, mount_deer_bronze = true }
local NONE = { mount_wolf_hw = true, mount_book = true }
local seen = 0
for _, m in RIDE.mounts do
	if WANT[m.id] then
		seen += 1
		local d = m.dash
		expect(typeof(d) == "table" and d.speed > 0 and d.dist > 0 and d.cd > 0, m.id .. ": 탄 채 대쉬가 있다")
		if d then
			expect(d.dist <= 180, m.id .. ": 대쉬 거리가 서버의 이동 몫(모아 180점) 안 — " .. d.dist)
			expect(d.speed <= 520, m.id .. ": 대쉬 빠르기가 가장 빠른 직업 대쉬(리븐 520) 안 — " .. d.speed)
			expect(d.cd >= d.dist / d.speed, m.id .. ": 다시 쓰기가 대쉬 시간보다 길다(이어 붙여 날아가지 않게)")
			expect(d.dist / d.cd <= 300 * 0.6, m.id .. ": 대쉬만 이어 써도 1초에 서버 몫(300점)의 60% 안")
			-- 잔상(이어서 사용자 "샤샤샥처럼 그 탈것의 그림자가 연속적으로"): 하나하나 갈라져 보이게 간격 24점 이상 · 대쉬 동안 셋 넘게 · 대쉬가 끝난 뒤 곧 사라진다
			expect(typeof(d.every) == "number" and d.every * d.speed >= 24, m.id .. ": 잔상 사이 24점 이상(촘촘하면 한 덩어리로 번진다) — " .. tostring(d.every and d.every * d.speed))
			expect(d.every and (d.dist / d.speed) / d.every >= 2.5, m.id .. ": 내달리는 동안 잔상이 셋쯤 넘게")
			expect(typeof(d.life) == "number" and d.life > 0 and d.life <= 0.5 and typeof(d.alpha) == "number" and d.alpha > 0 and d.alpha < 1, m.id .. ": 잔상의 수명 · 진하기")
		end
	elseif NONE[m.id] then
		expect(m.dash == nil, m.id .. ": 탄 채 대쉬가 없다(대쉬 키 = 내리고 그 직업의 대쉬)")
	end
	if m.id == "mount_wolf_hw" then
		expect(m.speed == nil, "호박불 늑대의 빠르기 = 로벅스 탈것(따로 적지 않음 — mountSpeed)")
	end
	if not m.free and not string.find(m.id, "^mount_golem") then
		expect(m.speed == nil, m.id .. ": 로벅스 탈것은 mountSpeed")
	end
end
eq(seen, 8, "대쉬가 있어야 할 탈것 여덟이 모두 표에 있다")
expect(typeof(RIDE.mountDash) == "table" and RIDE.mountDash.speed > 0, "탄 채 대쉬의 기본값(mountDash)")

-- ② 직업마다 1차 대쉬 = move 하나
for who in CLASSES.classes do
	local n = 0
	for _, def in COMBAT.skills do
		if def.who == who and def.type == "move" then
			n += 1
			expect(typeof(def.speed) == "number" and typeof(def.dist) == "number", who .. ": 1차 대쉬 " .. tostring(def.id))
		end
	end
	eq(n, 1, who .. ": 1차 기술 가운데 이동기(대쉬)는 하나 — 탄 채 누르면 탈것 대쉬")
end

-- ③ 서버
local function json(v)
	if typeof(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = json(x)
	end
	return out
end
local disk = {}
local handlers, fired = {}, {}
MOCK("ReplicatedStorage/shared/lune/net/net", {
	FireClient = function(name, player, ...)
		table.insert(fired, { name = name, player = player, args = { ... } })
	end,
	OnServer = function(name, fn)
		handlers[name] = fn
	end,
})
local function signal()
	return { Connect = function() end }
end
SERVICE("MessagingService", { PublishAsync = function() end, SubscribeAsync = function() end })
SERVICE("Players", { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end })
SERVICE("RunService", { Heartbeat = signal() })
SERVICE("TextService", { FilterStringAsync = function(_, text) return { GetNonChatStringForBroadcastAsync = function() return text end } end })
local names = {}
MOCK("ServerScriptService/server/lune/modules/store", {
	lock = function() return true end,
	unlock = function() end,
	loadAccount = function(id) return json(disk[id]) end,
	saveAccount = function(id, value)
		disk[id] = json(value)
		return true
	end,
	loadOld = function() return nil end,
	nameOwner = function(key) return names[key] end,
	claimName = function(key, id)
		if names[key] ~= nil and names[key] ~= id then
			return false
		end
		names[key] = id
		return true
	end,
	freeName = function(key) names[key] = nil end,
	rankSet = function() end,
	rankRaise = function() end,
	rankRemove = function() end,
	rankTop = function() return {} end,
	rankInfoSet = function() end,
	rankInfoGet = function() return nil end,
	rankInfoRemove = function() end,
	isOffline = function() return false end,
	marketRead = function() return true, nil end,
	marketUpdate = function(_, fn) return true, nil, nil, json(fn(nil)) end,
})
local World = req("ServerScriptService/server/lune/modules/world")
World.start()
local function person(id: number, name: string)
	local p = { UserId = id, Name = "u" .. id, DisplayName = "u" .. id, attrs = {} }
	p.SetAttribute = function(self, k, v) self.attrs[k] = v end
	p.Kick = function() end
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, "riven")
	handlers.Chars(p, "enter", made.id)
	return p, World.session(p)
end
local p1, s1 = person(7401, "말달리는손님")
local p2, s2 = person(7402, "구경하는손님")
s1.scene, s2.scene = "town", "town" -- (둘을 같은 방에)
s1.hero.x, s1.hero.y = 300, 240
local function dashed()
	local mine, theirs = 0, nil
	for _, f in fired do
		if f.name == "RideDashed" then
			if f.player == p1 then
				mine += 1
			elseif f.player == p2 then
				theirs = f.args
			end
		end
	end
	table.clear(fired)
	return mine, theirs
end
table.clear(fired)
handlers.RideDash(p1, 300, 240, 1)
local _, t0 = dashed()
expect(t0 == nil, "탄 것이 없으면 알리지 않는다")
s1.acct.bm.mounts.mount_wolf, s1.acct.bm.mount, s1.riding = true, "mount_wolf", true
World.now += 2
handlers.RideDash(p1, 305, 240, -1)
local mine, t1 = dashed()
expect(t1 ~= nil and t1[1] == s1.hero.id and t1[2] == 305 and t1[3] == 240 and t1[4] == -1, "달빛 늑대를 탄 채 = 같은 방 사람에게 알린다(영웅 번호 · 자리 · 쪽)")
eq(mine, 0, "나에게는 보내지 않는다(내 화면이 먼저 그렸다)")
expect(s1.riding == true, "탄 채 대쉬는 내리지 않는다")
handlers.RideDash(p1, 305, 240, 1)
local _, t2 = dashed()
expect(t2 == nil, "다시 쓰기 안에서는 받지 않는다")
World.now += 1
handlers.RideDash(p1, 9999, 240, 1)
local _, t3 = dashed()
expect(t3 ~= nil and t3[2] == s1.hero.x, "멀리 떨어진 자리를 말하면 서버가 아는 자리로")
s1.acct.bm.mounts.mount_wolf_hw, s1.acct.bm.mount = true, "mount_wolf_hw"
World.now += 2
handlers.RideDash(p1, 300, 240, 1)
local _, t4 = dashed()
expect(t4 == nil, "호박불 늑대는 탄 채 대쉬가 없다")
s1.acct.bm.mount = "mount_deer_silver"
s1.acct.bm.mounts.mount_deer_silver = true
World.now += 2
handlers.RideDash(p1, 300, 240, 1)
local _, t5 = dashed()
expect(t5 ~= nil, "랭킹 보상 실버 사슴도 탄 채 대쉬")
-- 기술(직업의 대쉬)을 보내면 전처럼 내린다 — 대쉬가 없는 탈것일 때 화면이 그렇게 한다
handlers.Skill(p1, "rv_dash", 1, s1.hero.x, s1.hero.y, 1)
expect(s1.riding == false, "기술을 보내면 내린다(전과 같다)")
