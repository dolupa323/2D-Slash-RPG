-- 「달의 계승자」 — 파티 플레이(서버의 흐름 그대로 — 2026-10-23).
--  사용자: "지금 파티하고 파티원이 사냥해도 다른파티원한테 경험치가 안들어온다는데 확인하고, 파티인상태에서 무니의 버프가 다른 파티원들에게도 적용되어야해
--   그리고 다른 캐릭터들도 다른 파티원도 같이 받는다고 적혀있는것들은 파티 버프 적용이 되어야해 그리고 무니 스킬에 아군 회복에 본인도 포함 되어야해"
--  보는 것: ① 파티원 A가 잡으면 같은 맵의 B도 경험치를 받는다 ② 무니의 버프(달의 숨결 · 달의 축복 · 수정 방벽 · 달의 성역)가 파티원에게도 걸린다
--   ③ 파티원에게도 걸린다고 적힌 다른 직업의 버프(달의 함성 · 죽음의 가호 · 불씨 나눔 · 달의 용사)도 ④ 무니의 달빛 치유가 무니 자신과 파티원을 함께 회복한다
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
COMBAT.rules.critChance = 0
local Buffs = req("ReplicatedStorage/shared/lune/sim/buffs")
local TICK = 1 / 20

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
World.start()
local function run(seconds)
	for _ = 1, math.floor(seconds / TICK + 0.5) do
		World.tick(TICK)
	end
end
local function join(uid, name, cls)
	local p = { UserId = uid, Name = name, DisplayName = name, attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end, Kick = function() end }
	handlers.Ready(p)
	local made = handlers.Chars(p, "create", name, cls)
	handlers.Chars(p, "enter", made.id)
	World.jump(p, "hunt")
	local s = World.session(p)
	s.hero.level, s.hero.job = 120, 4
	s.hero.maxHp = math.max(s.hero.maxHp, 5000)
	s.hero.hp = s.hero.maxHp
	return p, s
end
local pa, a = join(8601, "파티도끼", "axion")
local pb, b = join(8602, "파티무니", "mooni")
handlers.Party(pa, "invite", 8602)
handlers.Party(pb, "accept")
expect(World.sameParty(8601, 8602), "둘은 파티")
run(1)

-- 둘을 졸개 옆에 세운다
local room = World.room("hunt")
local foe = nil
for _, mob in room.mobs do
	if mob.state ~= "gone" and mob.state ~= "dead" then
		foe = mob
		break
	end
end
expect(foe ~= nil, "사냥터에 졸개가 있다")
local function stand(p, s, x, y)
	s.trust, s.stale = true, nil
	handlers.Move(p, x, y, 1)
	s.hero.x, s.hero.y = x, y
end
-- ① 경험치
if foe then
	stand(pa, a, foe.x - 16, foe.y)
	stand(pb, b, foe.x - 30, foe.y)
	a.hero.dmgBoost = 100
	local xb0, xa0 = b.hero.xp, a.hero.xp
	local lvb0 = b.hero.level
	for _ = 1, 12 do
		if foe.state == "dead" or foe.hp <= 0 then
			break
		end
		handlers.Skill(pa, "ax_combo", 1, a.hero.x, a.hero.y, 1)
		run(0.25) -- 도끼 내려찍기(2026-10-28 액시온 리마스터): 모으는 구간 뒤에 내려찍는 구간을 보낸다
		handlers.Skill(pa, "ax_combo", 2, a.hero.x, a.hero.y, 1)
		run(0.8)
	end
	expect(foe.hp <= 0 or foe.state == "dead" or foe.state == "gone", "A가 졸개를 잡았다")
	expect(a.hero.xp > xa0 or a.hero.level > 120, "잡은 A는 경험치를 받았다")
	expect(b.hero.xp > xb0 or b.hero.level > lvb0, ("치지 않은 파티원 B도 경험치를 받았다(B %d → %d)"):format(xb0, b.hero.xp))
end

-- ①-2 2차 기술(쓰는 기술 — sim/caster.luau)로 잡아도 · 무니(B)가 잡아도
local function nextFoe()
	for _, mob in room.mobs do
		if mob.state ~= "gone" and mob.state ~= "dead" and mob.hp > 0 then
			return mob
		end
	end
	return nil
end
for _, case in { { pa, a, b, "ax_crescent", "2차 기술(초승달 가르기)" }, { pb, b, a, "mn_spin", "무니의 1차 기술(회전 베기)" } } do
	run(6)
	local f = nextFoe()
	if f then
		local p, me, mate, id = case[1], case[2], case[3], case[4]
		stand(p, me, f.x - 16, f.y)
		stand(if mate == a then pa else pb, mate, f.x - 40, f.y)
		me.hero.dmgBoost = 100
		me.hero.skills[id] = 10
		local x0, l0 = mate.hero.xp, mate.hero.level
		for _ = 1, 15 do
			if f.hp <= 0 or f.state == "dead" or f.state == "gone" then
				break
			end
			stand(p, me, f.x - 16, f.y)
			handlers.Skill(p, id, 1, me.hero.x, me.hero.y, 1)
			run(0.5)
			handlers.Skill(p, id, 2, me.hero.x, me.hero.y, 1)
			run(0.5)
		end
		expect(f.hp <= 0 or f.state == "dead" or f.state == "gone", case[5] .. "로 잡았다")
		expect(mate.hero.xp > x0 or mate.hero.level > l0, ("%s로 잡아도 파티원이 경험치를 받는다(%d → %d)"):format(case[5], x0, mate.hero.xp))
	end
end

-- ②③ 버프
local function castBuff(p, s, id)
	s.hero.skills[id] = math.max(s.hero.skills[id] or 0, 1)
	s.hero.cds[id] = nil
	handlers.Skill(p, id, 1, s.hero.x, s.hero.y, 1)
	run(0.2)
end
stand(pa, a, 300, room.mobs[1] and room.mobs[1].y or a.hero.y)
stand(pb, b, 330, a.hero.y)
for _, id in { "mn_tide", "mn_bless", "mn_wall", "mn_sanct" } do
	castBuff(pb, b, id)
	expect(Buffs.has(b.hero, id), "무니 자신에게 걸렸다: " .. id)
	expect(Buffs.has(a.hero, id), "곁의 파티원(액시온)에게도 걸렸다: " .. id)
	-- 받은 파티원의 화면 오른쪽 위 버프 칸에도 뜬다(2026-10-24 사용자 "파티원에게도 버프아이콘이 뜨냐고"): 받은 사람에게 간 내 상태(Self)의 버프 목록에 들었다 → boot paintBuffs가 매 장 skill_<id> 그림으로 그린다
	local shown = false
	for i = #sent, 1, -1 do
		local e = sent[i]
		if e.name == "Self" and e.player == pa then
			for _, bf in (e.args[1].buffs and e.args[1].buffs.list or {}) do
				shown = shown or bf.id == id
			end
			break
		end
	end
	expect(shown, "받은 파티원의 화면(오른쪽 위 버프 칸)에 간 목록에 들었다: " .. id)
	a.hero.buffs[id], b.hero.buffs[id] = nil, nil
end
-- 파티원에게 걸리는 버프는 모두 버프 칸 그림(skill_<id>)이 있다
local KITDATA = req("ReplicatedStorage/shared/lune/data/kit.generated")
local function hasIcon(id)
	local function walk(t, depth)
		if depth > 4 or type(t) ~= "table" then
			return false
		end
		if t["skill_" .. id] ~= nil then
			return true
		end
		for _, v in t do
			if walk(v, depth + 1) then
				return true
			end
		end
		return false
	end
	return walk(KITDATA, 0)
end
for id, def in COMBAT.buffs do
	if def.fx.party then
		expect(hasIcon(id), "파티 버프의 버프 칸 그림이 있다: skill_" .. id)
	end
end
for _, pair in { { pa, a, "ax_roar" }, { pb, b, "c_hero" } } do
	castBuff(pair[1], pair[2], pair[3])
	local other = if pair[2] == a then b else a
	expect(Buffs.has(other.hero, pair[3]), "파티원에게도 걸린다고 적힌 버프: " .. pair[3])
end
-- 같은 맵이면 다른 층에 있어도(같은 맵의 파티원 모두 — party 9999)
stand(pa, a, 330, b.hero.y - 200)
a.hero.buffs.mn_bless = nil
castBuff(pb, b, "mn_bless")
expect(Buffs.has(a.hero, "mn_bless"), "같은 맵의 파티원 모두 = 다른 층(200도트 위)에 있어도")

-- ④ 달빛 치유
stand(pa, a, 300, b.hero.y)
stand(pb, b, 330, b.hero.y)
a.hero.hp = math.floor(a.hero.maxHp * 0.3)
b.hero.hp = math.floor(b.hero.maxHp * 0.3)
local ha, hb = a.hero.hp, b.hero.hp
b.hero.skills.mn_heal = 10
b.hero.cds.mn_heal = nil
handlers.Skill(pb, "mn_heal", 1, b.hero.x, b.hero.y, 1)
run(2.5)
expect(a.hero.hp > ha, ("달빛 치유: 곁의 파티원이 회복했다(%d → %d)"):format(ha, a.hero.hp))
expect(b.hero.hp > hb, ("달빛 치유: 무니 자신도 회복했다(%d → %d)"):format(hb, b.hero.hp))
-- ④-2 레벨이 20 넘게 차이 나는 파티원(2026-10-24 사용자: "무니 힐 이랑 버프 아직도 파티원 적용 안된다" — 전에는 경험치 나누기의 목록(레벨 차이 20 안쪽)을 써서 못 받았다)
a.hero.level = 60
run(0.2)
for _, id in { "mn_tide", "mn_bless", "mn_wall", "mn_sanct" } do
	a.hero.buffs[id], b.hero.buffs[id] = nil, nil
	castBuff(pb, b, id)
	expect(Buffs.has(a.hero, id), "레벨 차이 60인 파티원에게도 걸렸다: " .. id)
	a.hero.buffs[id], b.hero.buffs[id] = nil, nil
end
a.hero.hp = math.floor(a.hero.maxHp * 0.3)
local hgap = a.hero.hp
b.hero.cds.mn_heal = nil
handlers.Skill(pb, "mn_heal", 1, b.hero.x, b.hero.y, 1)
run(2.5)
expect(a.hero.hp > hgap, ("달빛 치유: 레벨 차이 60인 파티원도 회복했다(%d → %d)"):format(hgap, a.hero.hp))
a.hero.level = 120
-- ⑤ 수정 수호령(2026-10-23): 다친 아군(무니 자신도)이 있으면 치는 대신 치유한다
b.hero.skills.mn_guard = 15
b.hero.cds.mn_guard = nil
a.hero.hp = a.hero.maxHp
b.hero.hp = math.floor(b.hero.maxHp * 0.5)
handlers.Skill(pb, "mn_guard", 1, b.hero.x, b.hero.y, 1)
local hg = b.hero.hp
run(4.5)
expect(b.hero.hp > hg, ("수정 수호령이 무니 자신을 치유했다(%d → %d)"):format(hg, b.hero.hp))
b.hero.hp = b.hero.maxHp
a.hero.hp = math.floor(a.hero.maxHp * 0.5)
local hga = a.hero.hp
run(4.5)
expect(a.hero.hp > hga, ("수정 수호령이 곁의 파티원을 치유했다(%d → %d)"):format(hga, a.hero.hp))
a.hero.level = 60 -- 레벨 차이가 커도(2026-10-24)
a.hero.hp = math.floor(a.hero.maxHp * 0.5)
local hgg = a.hero.hp
run(4.5)
expect(a.hero.hp > hgg, ("수정 수호령: 레벨 차이 60인 파티원도 치유했다(%d → %d)"):format(hgg, a.hero.hp))
a.hero.level = 120
-- ⑦ 받은 사람에게 실제로 듣는가(2026-10-24 사용자: "무니 지금 죽음의가호 랑 이것저것 적용안되니는 버그가 너무많다 … 파티케어 스킬이 엄청나게 많은데 여기서 적용안되는 버그")
--  걸렸는지(Buffs.has)만이 아니라: 받는 피해가 줄었나 · 쓰러질 피해를 버텼나 · 되살아났나 · 수정 둘레에서 치유됐나
do
	local mob = nextFoe() or room.mobs[1]
	local function hitOnce(h)
		h.invuln, h.alive, h.inCine = 0, true, false
		h.hp = h.maxHp
		local before = h.hp
		room:hurtHero({}, h, mob, 200) -- (사냥터 졸개는 영웅에게 한 자리 수라 줄어든 몫이 반올림에 묻힌다 — 세게)
		return before - h.hp
	end
	local function clear(h)
		for id in h.buffs do
			h.buffs[id] = nil
		end
	end
	clear(a.hero)
	clear(b.hero)
	stand(pa, a, 300, b.hero.y)
	stand(pb, b, 330, b.hero.y)
	local plain = hitOnce(a.hero)
	expect(plain > 0, "맞으면 아프다(견줄 값 " .. plain .. ")")
	for _, id in { "mn_bless", "mn_wall", "mn_sanct" } do
		clear(a.hero)
		castBuff(pb, b, id)
		local got = hitOnce(a.hero)
		expect(got < plain, ("%s: 받은 파티원이 덜 아프다(%d → %d)"):format(id, plain, got))
		clear(a.hero)
		clear(b.hero)
	end
	-- 피해 +: 달의 성역(원 안) · 달의 용사
	for _, id in { "mn_sanct", "c_hero" } do
		castBuff(pb, b, id)
		expect(Buffs.dmg(a.hero) > 1, id .. ": 받은 파티원의 주는 피해가 오른다")
		clear(a.hero)
		clear(b.hero)
	end
	-- 공격 속도: 달의 숨결 — 서버의 셈 · 받은 사람의 화면에 가는 값
	castBuff(pb, b, "mn_tide")
	expect(Buffs.haste(a.hero) > 1, "mn_tide: 받은 파티원의 공격 속도가 빨라진다")
	local selfHaste = nil
	for i = #sent, 1, -1 do
		local e = sent[i]
		if e.name == "Self" and e.player == pa then
			selfHaste = e.args[1].haste
			break
		end
	end
	expect(selfHaste ~= nil and selfHaste > 1, "mn_tide: 받은 파티원의 화면에도 빨라진 값이 간다(" .. tostring(selfHaste) .. ")")
	clear(a.hero)
	clear(b.hero)
	-- 죽음의 가호(리퍼): 받은 파티원이 쓰러질 피해를 한 번 버틴다
	local pr, r = join(8604, "파티리퍼", "reaper")
	handlers.Party(pa, "invite", 8604)
	handlers.Party(pr, "accept")
	run(0.5)
	stand(pr, r, 320, b.hero.y)
	stand(pa, a, 300, b.hero.y)
	castBuff(pr, r, "rp_ward")
	expect(Buffs.has(a.hero, "rp_ward"), "죽음의 가호가 파티원에게 걸렸다")
	a.hero.invuln, a.hero.alive = 0, true
	a.hero.hp = 1
	room:hurtHero({}, a.hero, mob, 50)
	expect(a.hero.alive and a.hero.hp >= 1, "죽음의 가호: 받은 파티원이 쓰러질 피해를 버텼다")
	expect(not Buffs.has(a.hero, "rp_ward"), "죽음의 가호: 한 번 버티면 사라진다")
	a.hero.invuln = 0
	a.hero.hp = 1
	room:hurtHero({}, a.hero, mob, 50)
	expect(not a.hero.alive, "죽음의 가호가 없으면 쓰러진다")
	-- 소생(무니 4차): 쓰러진 파티원을 일으킨다
	b.hero.skills.mn_revive = 5
	b.hero.cds.mn_revive = nil
	stand(pb, b, 330, a.hero.y)
	run(0.2)
	handlers.Skill(pb, "mn_revive", 1, b.hero.x, b.hero.y, 1)
	run(1.5)
	expect(a.hero.alive, "소생: 쓰러진 파티원이 일어났다")
	World.removePlayer(pr)
	-- 달빛 치유: 수정 둘레에서도(설명 "수정이 있으면 수정 둘레에서도 치유가 인다") — 무니에게서 멀어도 내 수정 곁이면
	a.hero.alive, a.hero.invuln = true, 0
	stand(pb, b, 100, b.hero.y)
	stand(pa, a, 100 + 400, b.hero.y)
	table.insert(room.crystals, { id = 99901, x = a.hero.x + 10, y = a.hero.y, owner = b.hero.id, till = room.time + 20 })
	a.hero.hp = math.floor(a.hero.maxHp * 0.3)
	local hc = a.hero.hp
	b.hero.cds.mn_heal = nil
	handlers.Skill(pb, "mn_heal", 1, b.hero.x, b.hero.y, 1)
	run(1)
	expect(a.hero.hp > hc, ("달빛 치유: 무니와 400 떨어져도 무니의 수정 곁의 파티원이 회복했다(%d → %d)"):format(hc, a.hero.hp))
	room.crystals = {}
	a.hero.hp = a.hero.maxHp
end
-- ⑥ 혼자인 무니(2026-10-24 사용자 "무니 수정 수호령 치유된다고 써있는데 … 실제로 플레이해보면 회복안되는데?"): 파티 없이 · 조금만 다쳐도 2초마다 치유한다
World.removePlayer(pa)
World.removePlayer(pb)
local pc, c = join(8603, "혼자무니", "mooni")
stand(pc, c, 330, room.mobs[1] and room.mobs[1].y or c.hero.y)
c.hero.skills.mn_guard = 1
c.hero.cds.mn_guard = nil
local function healedSent(p)
	local n = 0
	for _, e in sent do
		if e.name == "Healed" and e.player == p then
			n += 1
		end
	end
	return n
end
for _, share in { 0.5, 0.95 } do
	c.hero.hp = math.floor(c.hero.maxHp * share)
	c.hero.cds.mn_guard = nil
	local h0, n0 = c.hero.hp, healedSent(pc)
	handlers.Skill(pc, "mn_guard", 1, c.hero.x, c.hero.y, 1)
	run(4.5)
	expect(c.hero.hp > h0, ("혼자인 무니 · 체력 %d%%: 수정 수호령이 치유했다(%d → %d)"):format(share * 100, h0, c.hero.hp))
	expect(healedSent(pc) > n0, ("혼자인 무니 · 체력 %d%%: 화면에 회복 알림(Healed)을 보냈다"):format(share * 100))
end
World.removePlayer(pc)
