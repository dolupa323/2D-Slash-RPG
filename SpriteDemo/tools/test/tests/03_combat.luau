-- 서버 전투(townMonsters · quickSlots): 가짜 플레이어 둘로 공격 · 쿨타임 · 처치 보상 · 기여도 · 투척 무기 · 폭탄 · 반격 · 리스폰
local world = req("ReplicatedStorage/shared/data/townWorld").data
local items = req("ReplicatedStorage/shared/data/items")
local balance = req("ReplicatedStorage/shared/config/balance")
local combat = req("ReplicatedStorage/shared/config/combat")
local monsterLevels = req("ReplicatedStorage/shared/config/monsterLevels")
local schema = req("ServerScriptService/server/services/playerSchema")

-- ---- 가짜 플레이어 · 서비스 ----
local p1 = { UserId = 1, Name = "닌자1", Parent = {} }
local p2 = { UserId = 2, Name = "닌자2", Parent = {} }
local byId = { [1] = p1, [2] = p2 }
local data = { [p1] = schema.default(), [p2] = schema.default() }
local where = { [1] = "town_field1", [2] = "town_field1" }
local pos = { [1] = V(0, 0), [2] = V(0, 0) } -- 화면 px(= 도트 × world.scale)
local function standAt(player, x, y) pos[player.UserId] = V(x * world.scale, y * world.scale) end

local events = {} -- { name, player, args }
local handlers = {}
local function sent(name, player)
	local out = {}
	for _, e in events do
		if e.name == name and (player == nil or e.player == player) then table.insert(out, e) end
	end
	return out
end
local function clear() table.clear(events) end

MOCK("ReplicatedStorage/shared/net/net", {
	FireClient = function(name, player, ...) table.insert(events, { name = name, player = player, args = { ... } }) end,
	OnServer = function(name, fn) handlers[name] = fn end,
})
MOCK("ServerScriptService/server/modules/heroTracking", {
	PlayersInScene = function(sceneName)
		local list = {}
		for id, s in where do
			if s == sceneName then table.insert(list, byId[id]) end
		end
		return list
	end,
	GetPosition = function(userId) return pos[userId] end,
	GetPlayerScene = function(userId) return where[userId] end,
	OnSceneChanged = function() end,
})
MOCK("ServerScriptService/server/modules/worldDrops", { List = function() return {} end })
MOCK("ServerScriptService/server/services/persistence", {
	Get = function(player) return data[player] end,
	MarkDirty = function() end,
	Save = function() end,
})
local expGiven, hurt = {}, {}
MOCK("ServerScriptService/server/services/progressionService", {
	AddExperience = function(player, n) expGiven[player] = (expGiven[player] or 0) + n end,
	DamagePlayer = function(player, n) hurt[player] = (hurt[player] or 0) + n end,
	Heal = function() return 0 end, -- 체력이 가득한 상태로 둔다
})
MOCK("ServerScriptService/server/services/currencyService", {
	AddGold = function(player, n) data[player].Gold += n end,
})
local heartbeat
SERVICE("Players", { GetPlayerByUserId = function(_, id) return byId[id] end, PlayerRemoving = { Connect = function() end } })
SERVICE("RunService", { Heartbeat = { Connect = function(_, fn) heartbeat = fn; return { Disconnect = function() end } end } })

local inventory = req("ServerScriptService/server/services/inventoryService")
local townMonsters = req("ServerScriptService/server/modules/townMonsters")
local quickSlots = req("ServerScriptService/server/modules/quickSlots")
townMonsters.load()
quickSlots.load()

-- ---- 1) 씬 상태 ----
local state = handlers.GetTownState(p1)
eq(state.scene, "field1", "내 씬")
local zoneTotal = 0
for _, z in world.scenes.field1.zones do zoneTotal += z.count end
eq(#state.monsters, zoneTotal, "구역 수만큼 몬스터가 나타남")
for _, w in state.monsters do
	local lo, hi = monsterLevels.LevelRange(w.row)
	expect(w.level >= lo and w.level <= hi, "몬스터 레벨 범위")
	eq(w.maxHp, monsterLevels.MaxHealth(w.level), "최대 체력")
end
where[1] = "town_village"
eq(#handlers.GetTownState(p1).monsters, 0, "마을에는 몬스터 없음")
where[1] = "town_field1"

local function living() return townMonsters.Living("field1") end
local function lastHit(id)
	local found
	for _, e in sent("TownMonsterHit") do
		if e.args[2] == id then found = e end
	end
	return found
end
local ATTACK = balance.BASE_ATTACK -- 맨손(무기 미착용)
eq(inventory.GetAttackDamage(p1), ATTACK, "맨손 공격력")

-- ---- 2) 기본 공격: 앞 범위 판정 · 쿨타임 ----
local m = living()[1]
m.maxHp, m.hp = 100, 100
standAt(p1, m.x - 10, m.y) -- 몬스터 왼쪽 10도트, 오른쪽을 보고 때린다
clear()
handlers.TownAttack(p1, "right")
eq(m.hp, 100 - ATTACK, "한 대 맞은 체력")
local hit = lastHit(m.id)
expect(hit and hit.args[3] == 100 - ATTACK and hit.args[4] == ATTACK and hit.args[5] == 1, "TownMonsterHit 내용")
eq(#sent("TownMonsterHit", p2), 1, "같은 씬의 다른 사람도 피격을 받음")
handlers.TownAttack(p1, "right")
eq(m.hp, 100 - ATTACK, "쿨타임 안의 두 번째 공격은 무시")
advance(balance.TOWN_ATTACK_COOLDOWN + 0.05)
handlers.TownAttack(p1, "left")
eq(m.hp, 100 - ATTACK, "반대쪽을 보면 안 맞음")
advance(balance.TOWN_ATTACK_COOLDOWN + 0.05)
standAt(p1, m.x - combat.ATTACK_REACH - 6, m.y)
handlers.TownAttack(p1, "right")
eq(m.hp, 100 - ATTACK, "범위 밖은 안 맞음")

-- ---- 3) 기여도 10% 규칙 + 처치 보상 ----
local big = living()[2]
big.maxHp, big.hp = 1000, 1000
advance(1)
standAt(p2, big.x - 10, big.y)
handlers.TownAttack(p2, "right") -- p2는 10 피해(1%) — 기여도 부족
eq(big.hp, 1000 - ATTACK, "p2 한 대")
local goldBefore, itemsBefore = data[p1].Gold, #data[p1].Inventory
clear()
expect(townMonsters.Damage("field1", big.id, p1, 2000, "test"), "p1이 마무리")
expect(big.dead, "쓰러짐")
eq(#sent("TownMonsterDied", p1), 1, "죽음 알림")
eq(expGiven[p1], monsterLevels.Experience(big.level), "p1 경험치")
expect(expGiven[p2] == nil, "p2는 기여도 부족 → 경험치 없음")
expect(data[p1].Gold > goldBefore, "p1 엽전")
local species = world.species[big.row]
eq(data[p1].Dex[species.id], 1, "도감 봤음")
local notice = sent("Notify", p2)
expect(#notice == 1 and string.find(notice[1].args[1], "기여도") ~= nil, "p2 기여도 부족 알림")
expect(#data[p1].Inventory >= itemsBefore, "드롭은 가방으로")
-- 리스폰
clear()
advance(combat.MONSTER_RESPAWN + 0.1)
expect(not big.dead and big.hp == big.maxHp, "리스폰")
eq(#sent("TownMonsterSpawned", p1), 1, "리스폰 알림")

-- 드롭 통계: 들판 몬스터 300마리 → 풀잎이 가방에 들어온다
local function countItem(player, id) return inventory.CountItem(player, id) end
local grassBefore = countItem(p1, "GrassBlade")
for _ = 1, 300 do
	local t = living()[3]
	t.maxHp, t.hp = 10, 10
	townMonsters.Damage("field1", t.id, p1, 10, "test")
	advance(combat.MONSTER_RESPAWN + 0.1)
end
local gained = countItem(p1, "GrassBlade") - grassBefore
expect(gained > 75 and gained < 135, ("풀잎 드롭 %d개(300마리 × 35%% = 기대 약 105개 — 99개를 넘으면 다음 칸에 쌓인다)"):format(gained))

-- ---- 4) 투척 무기 ----
local target = living()[4]
target.maxHp, target.hp = 500, 500
-- 다른 몬스터가 사이에 끼지 않게 멀리 치운다
for _, o in living() do
	if o ~= target then o.x, o.y = 8, 8 end
end
target.x, target.y = 300, 200
standAt(p1, 250, 200)
advance(1)
local shBefore = countItem(p1, "Shuriken")
clear()
expect(townMonsters.ThrowWeapon(p1, "Shuriken", "right"), "수리검 던지기")
eq(countItem(p1, "Shuriken"), shBefore - 1, "1개 소모")
local thrown = sent("ProjectileThrown", p1)[1]
expect(thrown and thrown.args[3] == "Shuriken" and math.abs(thrown.args[8] - 50) < 1, "날아가는 거리 = 몬스터까지 50도트")
eq(target.hp, 500, "아직 날아가는 중")
expect(not townMonsters.ThrowWeapon(p1, "Shuriken", "right"), "투척 쿨타임")
eq(countItem(p1, "Shuriken"), shBefore - 1, "쿨타임 때는 소모 안 됨")
advance(50 / items.Shuriken.Throw.speed + 0.02)
eq(target.hp, 500 - math.round(ATTACK * items.Shuriken.Throw.power), "도착하면 공격력 × 0.8 피해")
-- 빗나감: 반대쪽으로
advance(1)
clear()
expect(townMonsters.ThrowWeapon(p1, "Shuriken", "left"), "빗나가도 던져짐")
eq(sent("ProjectileThrown", p1)[1].args[8], items.Shuriken.Throw.range, "빗나가면 끝까지 날아감")
advance(1)
eq(target.hp, 500 - math.round(ATTACK * items.Shuriken.Throw.power), "빗나가면 피해 없음")
-- 사거리 밖
standAt(p1, 300 - items.Shuriken.Throw.range - 20, 200)
townMonsters.ThrowWeapon(p1, "Shuriken", "right")
advance(1)
eq(target.hp, 500 - math.round(ATTACK * items.Shuriken.Throw.power), "사거리 밖은 안 맞음")
-- 없는 아이템
expect(not townMonsters.ThrowWeapon(p1, "Kunai", "right"), "없는 쿠나이는 못 던짐")
expect(not townMonsters.ThrowWeapon(p1, "Onigiri", "right"), "투척 무기가 아니면 안 됨")

-- 폭탄: 둘레 모두
inventory.AddItem(p1, "Bomb", 2)
local a, b, far = living()[5], living()[6], living()[7]
for _, o in { a, b, far } do o.maxHp, o.hp = 500, 500 end
target.x, target.y = 8, 8
a.x, a.y = 300, 200
b.x, b.y = 312, 206
far.x, far.y = 300 + items.Bomb.Throw.radius + 30, 200
standAt(p1, 260, 200)
advance(1)
expect(townMonsters.ThrowWeapon(p1, "Bomb", "right"), "폭탄 던지기")
advance(1)
local bombDamage = math.round(ATTACK * items.Bomb.Throw.power)
eq(a.hp, 500 - bombDamage, "폭탄: 맞은 몬스터")
eq(b.hp, 500 - bombDamage, "폭탄: 옆 몬스터도")
eq(far.hp, 500, "폭탄: 범위 밖은 안 맞음")

-- ---- 5) 반격: 맞은 몬스터가 쫓아와 때린다 ----
standAt(p1, 270, 200)
hurt[p1] = nil
for _ = 1, 80 do
	advance(0.1)
	heartbeat(0.1)
end
expect((hurt[p1] or 0) > 0, "쫓아와서 공격함")
local d = math.sqrt((a.x - 270) ^ 2 + (a.y - 200) ^ 2)
expect(d <= combat.MONSTER_ATTACK_RANGE + 2, ("몬스터가 가까이 옴(거리 %.1f)"):format(d))

-- ---- 6) 단축칸: 수리검 던지기 · 방울(포획)은 꺼져 있음 ----
advance(1)
clear()
handlers.UseQuickSlot(p1, 1, "right") -- 1번 칸 = 수리검(v7 기본)
eq(#sent("ProjectileThrown", p1), 1, "단축칸 1 → 수리검")
handlers.UseQuickSlot(p1, 2, "right") -- 2번 칸 = 주먹밥, 체력 가득
local full = sent("Notify", p1)
expect(#full == 1 and string.find(full[1].args[1], "가득") ~= nil, "체력 가득이면 안 먹음")
expect(not townMonsters.ThrowBell(p1, "Bell1", "right"), "포획은 꺼져 있음")
handlers.SetQuickSlot(p1, 3, "Kunai")
eq(data[p1].QuickSlots[3], "Kunai", "단축칸 3에 쿠나이 놓기")
handlers.SetQuickSlot(p1, 3, "Ninjato")
eq(data[p1].QuickSlots[3], "Kunai", "소비 탭이 아닌 것은 못 놓음")
