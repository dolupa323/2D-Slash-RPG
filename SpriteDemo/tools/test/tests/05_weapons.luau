-- 장비와 강화(N3): 무기 표 정합성 · 레벨당 공격력 · 레벨 제한 · 무기 종류별 범위/빠르기/세기 · 강화(재료 · 확률 · 단계 옮기기) · 무기 드롭
local world = req("ReplicatedStorage/shared/data/townWorld").data
local items = req("ReplicatedStorage/shared/data/items")
local itemIcons = req("ReplicatedStorage/shared/data/itemIcons.generated")
local ninjaWeapons = req("ReplicatedStorage/shared/data/ninjaWeapons")
local balance = req("ReplicatedStorage/shared/config/balance")
local drops = req("ReplicatedStorage/shared/config/drops")
local shopsConfig = req("ReplicatedStorage/shared/config/shops")
local weapons = req("ReplicatedStorage/shared/config/weapons")
local packets = req("ReplicatedStorage/shared/net/packets")
local schema = req("ServerScriptService/server/services/playerSchema")
local font = req("ReplicatedStorage/shared/data/pixelFont.generated").body

local extra = {}
for _, ch in font.extra do extra[utf8.codepoint(ch)] = true end
local function checkText(text, what)
	for _, code in utf8.codes(text) do
		local ok = code == 10 or (code >= 32 and code <= 126) or (code >= 0xAC00 and code <= 0xD7A3) or (code >= 0x3131 and code <= 0x3163) or extra[code]
		if not ok then
			expect(false, ("%s: 글꼴에 없는 글자 [%s] — %s"):format(what, utf8.char(code), text))
			return
		end
	end
	expect(true, what)
end

-- ---- 1) 표 정합성 ----
local count = 0
for id, def in ninjaWeapons do
	count += 1
	expect(items[id] == def, "items에 합쳐짐 " .. id)
	expect(weapons.CLASSES[def.Class] ~= nil, "무기 종류 " .. id)
	expect(def.Type == "Weapon" and def.EquipSlot == "Weapon" and def.Tab == "Equip" and def.StackMax == 1, "무기 기본 항목 " .. id)
	expect(def.Level >= 1 and def.Level <= 100 and def.Attack > 0 and def.SellPrice > 0, "레벨 · 공격력 · 파는 값 " .. id)
	expect(itemIcons.rects["icon_" .. def.KitIcon] ~= nil, "아이콘 " .. id .. " (" .. def.KitIcon .. ")")
	checkText(def.Name, "무기 이름 " .. id)
	checkText(def.Description, "무기 설명 " .. id)
end
expect(count >= 12, "무기 12종 이상(" .. count .. ")")
for key, c in weapons.CLASSES do
	expect(c.reach > 0 and c.width > 0 and c.speed > 0 and c.power > 0, "종류 수치 " .. key)
	checkText(c.name, "종류 이름 " .. key)
	checkText(c.desc, "종류 설명 " .. key)
	-- 서버 공격 간격 < 클라 공격 동작 길이(4장 + 쉬는 시간) — 정상 연타가 막히지 않게
	local combat = req("ReplicatedStorage/shared/config/combat")
	local clientPeriod = (combat.ATTACK_FRAME_TIME * 4 + combat.ATTACK_COOLDOWN) * c.speed
	expect(balance.TOWN_ATTACK_COOLDOWN * c.speed < clientPeriod, "서버 간격 < 클라 동작 " .. key)
end
local regionOf = {}
for _, r in world.regions do regionOf[r.id] = r end
for region, pool in drops.WEAPONS do
	local r = regionOf[region]
	expect(r ~= nil and drops.REGION[region] ~= nil, "드롭 지역 " .. region)
	for _, id in pool do
		local def = ninjaWeapons[id]
		expect(def ~= nil, ("%s 드롭 무기 %s"):format(region, id))
		expect(def ~= nil and r ~= nil and def.Level <= r.levelMax, ("%s 무기 %s 레벨이 그 지역 안"):format(region, id))
	end
end
for _, id in shopsConfig.merchant.goods do
	expect(items[id] ~= nil and items[id].Price ~= nil and items[id].Price > 0, "잡화 상점 물건 값 " .. id)
end
local fxSheet = req("ReplicatedStorage/shared/data/ninjaFx.generated")
for key, c in weapons.CLASSES do
	expect(fxSheet.rects[c.hitFx] ~= nil, "맞음 이펙트 " .. key)
end
expect(fxSheet.rects[weapons.UNARMED.hitFx] ~= nil and fxSheet.rects[weapons.THROW_HIT_FX] ~= nil, "맨손 · 투척 맞음 이펙트")
expect(fxSheet.rects.explosion ~= nil and fxSheet.rects.spark ~= nil and fxSheet.rects.boost ~= nil, "폭발 · 레벨업 이펙트")
eq(#weapons.RATE, weapons.MAX_PLUS, "강화 확률표 길이")
for _, b in weapons.BARS do
	expect(items[b.item] ~= nil, "강화 주괴 " .. b.item)
end
for id, def in ninjaWeapons do
	local last = 0
	for plus = 1, weapons.MAX_PLUS do
		local bonus = weapons.Bonus(def, plus)
		expect(bonus > last, ("%s +%d 보너스가 늘어남"):format(id, plus))
		last = bonus
		local cost = weapons.Cost(def, plus)
		expect(cost ~= nil and items[cost.bar] ~= nil and cost.bars == plus and cost.gold > 0 and cost.rate == weapons.RATE[plus], ("%s +%d 값"):format(id, plus))
	end
	expect(weapons.Cost(def, weapons.MAX_PLUS + 1) == nil, "최고 단계 위는 없음 " .. id)
end
eq(weapons.Bonus(ninjaWeapons.Katana, 0), 0, "+0 보너스 없음")
eq(weapons.Cost(ninjaWeapons.Ninjato, 1).bar, "CopperBar", "들판 무기 = 구리")
eq(weapons.Cost(ninjaWeapons.GreatSword, 1).bar, "GoldBar", "Lv.60 무기 = 금")
eq(weapons.ClassOf(nil), weapons.UNARMED, "무기 없음 = 맨손")
eq(weapons.ClassOf({ Attack = 3 }), weapons.UNARMED, "종류가 없는 무기 = 맨손 수치")
eq(balance.attackFor(1), balance.BASE_ATTACK, "Lv.1 공격력")
eq(balance.attackFor(10), balance.BASE_ATTACK + 9 * balance.ATTACK_PER_LEVEL, "Lv.10 공격력")
expect(packets.UpgradeWeapon ~= nil and packets.UpgradeResult ~= nil, "패킷 등록")
local old = schema.default()
old.SchemaVersion, old.EquipmentPlus = 8, nil
schema.migrate(old)
expect(typeof(old.EquipmentPlus) == "table" and old.SchemaVersion == schema.CURRENT_VERSION, "v8 → v9 마이그레이션")

-- ---- 가짜 플레이어 · 서비스 ----
local p1 = { UserId = 1, Name = "닌자1", Parent = {} }
local byId = { [1] = p1 }
local data = { [p1] = schema.default() }
local where = { [1] = "town_field1" }
local pos = { [1] = V(0, 0) }
local function standAt(x, y) pos[1] = V(x * world.scale, y * world.scale) end
local events, handlers = {}, {}
local function sent(name)
	local out = {}
	for _, e in events do
		if e.name == name then table.insert(out, e) end
	end
	return out
end
local function clear() table.clear(events) end
local function noticed(word)
	for _, e in sent("Notify") do
		if string.find(e.args[1], word, 1, true) then return true end
	end
	return false
end
MOCK("ReplicatedStorage/shared/net/net", {
	FireClient = function(name, player, ...) table.insert(events, { name = name, player = player, args = { ... } }) end,
	OnServer = function(name, fn) handlers[name] = fn end,
})
MOCK("ServerScriptService/server/modules/heroTracking", {
	PlayersInScene = function(sceneName) return if where[1] == sceneName then { p1 } else {} end,
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
MOCK("ServerScriptService/server/services/progressionService", {
	AddExperience = function() end, DamagePlayer = function() end, Heal = function() return 0 end,
})
MOCK("ServerScriptService/server/services/currencyService", {
	AddGold = function(player, n) data[player].Gold += n end,
})
SERVICE("Players", { GetPlayerByUserId = function(_, id) return byId[id] end, PlayerRemoving = { Connect = function() end } })
SERVICE("RunService", { Heartbeat = { Connect = function() return { Disconnect = function() end } end } })

local inventory = req("ServerScriptService/server/services/inventoryService")
local townMonsters = req("ServerScriptService/server/modules/townMonsters")
local upgradeService = req("ServerScriptService/server/modules/upgradeService")
townMonsters.load()
upgradeService.load()
local d = data[p1]
-- 새 플레이어의 시작 닌자도는 치워 둔다(아래 시험은 닌자도를 직접 넣어서 쓴다 — 두 자루면 어느 것인지 헷갈린다)
for i = #d.Inventory, 1, -1 do
	if d.Inventory[i].ItemId == "Ninjato" then table.remove(d.Inventory, i) end
end
local function slotOf(id)
	for _, e in d.Inventory do
		if e.ItemId == id and e.Tab == "Equip" then return e.Slot, e end
	end
end

-- ---- 2) 착용: 레벨 제한 · 공격력 ----
eq(inventory.GetAttackDamage(p1), balance.attackFor(1), "맨손 공격력 = 레벨 공격력")
inventory.AddItem(p1, "Katana", 1)
clear()
expect(not inventory.Equip(p1, (slotOf("Katana"))) and noticed("Lv.10"), "레벨이 모자라면 못 낌")
expect(d.Equipment.Weapon == nil, "착용 안 됨")
d.Level = 10
expect(inventory.Equip(p1, (slotOf("Katana"))), "Lv.10이면 카타나를 낌")
eq(inventory.GetAttackDamage(p1), balance.attackFor(10) + ninjaWeapons.Katana.Attack, "공격력 = 레벨 + 무기")
expect(slotOf("Katana") == nil, "낀 무기는 가방에서 빠짐")

-- ---- 3) 무기 종류: 범위 · 세기 · 빠르기 ----
local list = townMonsters.Living("field1")
local function resetMons()
	for _, m in list do
		m.maxHp, m.hp, m.damageBy = 100000, 100000, {}
		m.x, m.y = 8, 8
	end
end
local function lost(m) return 100000 - m.hp end
local function swing(id)
	-- 무기를 바꿔 끼고(가방에 없으면 넣어서) 쿨타임이 지난 뒤 오른쪽으로 한 번 휘두른다
	if d.Equipment.Weapon ~= id then
		if not slotOf(id) then inventory.AddItem(p1, id, 1) end
		expect(inventory.Equip(p1, (slotOf(id))), "착용 " .. id)
	end
	advance(2)
	handlers.TownAttack(p1, "right")
end
d.Level = 60
local a, b, c = list[1], list[2], list[3]
standAt(200, 200)
-- 도검(닿는 거리 20, 폭 22): 앞 15는 맞고, 앞 30은 안 맞고, 옆으로 9 벗어난 것은 맞는다
resetMons()
a.x, a.y = 215, 200
b.x, b.y = 230, 200
c.x, c.y = 210, 209
swing("Katana")
local sword = weapons.CLASSES.sword
eq(lost(a), math.round(inventory.GetAttackDamage(p1) * sword.power), "도검: 앞 15")
eq(lost(b), 0, "도검: 앞 30은 안 닿음")
expect(lost(c) > 0, "도검: 옆 9도 맞음(폭 22)")
-- 장병기(닿는 거리 36, 폭 12): 앞 30도 맞고, 옆 9는 안 맞는다
resetMons()
a.x, a.y = 215, 200
b.x, b.y = 230, 200
c.x, c.y = 210, 209
swing("Spear")
local polearm = weapons.CLASSES.polearm
eq(lost(a), math.round(inventory.GetAttackDamage(p1) * polearm.power), "장병기: 앞 15(피해 × 1.1)")
expect(lost(b) > 0, "장병기: 앞 30도 닿음")
eq(lost(c), 0, "장병기: 옆 9는 안 맞음(폭 12)")
-- 대형(× 1.6, 느림): 간격이 0.35 × 1.45초
resetMons()
a.x, a.y = 215, 200
swing("Club")
local heavy = weapons.CLASSES.heavy
local one = math.round(inventory.GetAttackDamage(p1) * heavy.power)
eq(lost(a), one, "대형: 피해 × 1.6")
advance(balance.TOWN_ATTACK_COOLDOWN + 0.02)
handlers.TownAttack(p1, "right")
eq(lost(a), one, "대형: 도검 간격으로는 아직 못 침")
advance(balance.TOWN_ATTACK_COOLDOWN * (heavy.speed - 1))
handlers.TownAttack(p1, "right")
eq(lost(a), one * 2, "대형: 제 간격이 지나면 침")
-- 쌍수(× 0.8, 빠름): 간격이 0.35 × 0.7초
resetMons()
a.x, a.y = 212, 200
swing("Sai")
local dual = weapons.CLASSES.dual
one = math.round(inventory.GetAttackDamage(p1) * dual.power)
advance(balance.TOWN_ATTACK_COOLDOWN * dual.speed + 0.02)
handlers.TownAttack(p1, "right")
eq(lost(a), one * 2, "쌍수: 도검보다 짧은 간격으로 연타")
-- 채찍(닿는 거리 30, 폭 36): 옆 16도 맞는다
resetMons()
a.x, a.y = 225, 216
swing("Whip")
expect(lost(a) > 0, "채찍: 앞 25 · 옆 16도 맞음")
-- 맞은 몬스터 위 베기 연출에 쓰는 무기 id
local hitEvents = sent("TownMonsterHit")
eq(hitEvents[#hitEvents].args[6], "Whip", "피격 출처 = 낀 무기 id")

-- ---- 4) 강화 ----
resetMons()
d.Level = 10
expect(inventory.Equip(p1, (slotOf("Katana"))), "카타나로 바꿔 낌")
inventory.AddItem(p1, "Ninjato", 1)
local nSlot = slotOf("Ninjato")
local nDef = ninjaWeapons.Ninjato
d.Gold = 100000
clear()
eq(upgradeService.Upgrade(p1, nSlot), nil, "대장간이 아니면 강화 안 됨")
expect(noticed("대장간"), "대장간 안내")
local smith
for _, n in world.scenes.village.npcs do
	if n.type == weapons.UPGRADE_NPC then smith = n end
end
expect(smith ~= nil, "마을에 대장장이 NPC가 있음")
where[1] = "town_village"
standAt(smith.x, smith.y + 12)
clear()
eq(upgradeService.Upgrade(p1, nSlot), nil, "주괴가 없으면 강화 안 됨")
expect(noticed("모자라요"), "재료 부족 안내")
inventory.AddItem(p1, "CopperBar", 99)
local gold0, bars0 = d.Gold, inventory.CountItem(p1, "CopperBar")
local spentGold, spentBars = 0, 0
for target = 1, 3 do
	local cost = weapons.Cost(nDef, target)
	clear()
	eq(upgradeService.Upgrade(p1, nSlot), "success", ("+%d 강화(확률 100%%)"):format(target))
	spentGold += cost.gold
	spentBars += cost.bars
	local r = sent("UpgradeResult")
	expect(#r == 1 and r[1].args[1] == true and r[1].args[2] == "Ninjato" and r[1].args[3] == target, "UpgradeResult")
end
local _, nEntry = slotOf("Ninjato")
eq(nEntry.Plus, 3, "가방 칸에 +3")
eq(d.Gold, gold0 - spentGold, "엽전 소모")
eq(inventory.CountItem(p1, "CopperBar"), bars0 - spentBars, "주괴 소모(1 + 2 + 3)")
-- 가방에 있는 무기의 강화는 공격력에 안 들어간다 → 끼면 들어간다 → 빼면 가방 칸으로 돌아온다
eq(inventory.GetAttackDamage(p1), balance.attackFor(10) + ninjaWeapons.Katana.Attack, "가방의 +3은 공격력에 없음")
clear()
expect(inventory.Equip(p1, nSlot), "닌자도 +3 착용")
eq(d.EquipmentPlus.Weapon, 3, "착용 칸으로 강화 단계가 옮겨 감")
eq(inventory.GetAttackDamage(p1), balance.attackFor(10) + nDef.Attack + weapons.Bonus(nDef, 3), "공격력 = 레벨 + 무기 + 강화")
local eqEvent = sent("EquipmentUpdated")
expect(#eqEvent >= 1 and eqEvent[#eqEvent].args[2].Weapon == 3, "EquipmentUpdated에 강화 단계")
local _, kEntry = slotOf("Katana")
expect(kEntry ~= nil and kEntry.Plus == nil, "빼낸 카타나는 강화 없음")
-- 착용 중인 무기 강화(칸 0)
inventory.AddItem(p1, "CopperBar", 99)
local results = { success = 0, fail = 0 }
local before = d.EquipmentPlus.Weapon
local r4 = upgradeService.Upgrade(p1, 0)
expect(r4 == "success" or r4 == "fail", "착용 무기 강화(+4, 80%)")
eq(d.EquipmentPlus.Weapon, before + (if r4 == "success" then 1 else 0), "성공하면 +1, 실패하면 그대로")
expect(inventory.Unequip(p1, "Weapon"), "무기 해제")
_, nEntry = slotOf("Ninjato")
eq(nEntry.Plus, before + (if r4 == "success" then 1 else 0), "해제하면 가방 칸으로 강화 단계가 돌아옴")
expect(d.EquipmentPlus.Weapon == nil, "착용 칸 강화 단계는 비워짐")
-- 강화한 장비는 못 버린다 / 안 한 장비는 버려진다
clear()
expect(inventory.Take(p1, "Equip", nEntry.Slot) == nil and noticed("버릴 수 없어요"), "강화한 장비는 못 버림")
local kSlot = slotOf("Katana")
expect(inventory.Take(p1, "Equip", kSlot) ~= nil, "강화 안 한 장비는 버려짐")
-- 확률: +3에서 +4(80%)를 2000번 — 실패해도 단계 그대로, 재료는 매번 든다
d.Gold = 100000000
local tries = 2000
for _ = 1, tries do
	nEntry.Plus = 3
	if inventory.CountItem(p1, "CopperBar") < 4 then inventory.AddItem(p1, "CopperBar", 99) end
	local barsBefore = inventory.CountItem(p1, "CopperBar")
	local r = upgradeService.Upgrade(p1, nEntry.Slot)
	results[r] += 1
	eq(nEntry.Plus, if r == "success" then 4 else 3, "성공 +4 / 실패 +3 그대로")
	eq(inventory.CountItem(p1, "CopperBar"), barsBefore - 4, "성공이든 실패든 주괴 4개")
end
local rate = results.success / tries
expect(math.abs(rate - weapons.RATE[4]) < 0.04, ("+4 성공률 %.3f(기대 %.2f)"):format(rate, weapons.RATE[4]))
-- 최고 단계
nEntry.Plus = weapons.MAX_PLUS
clear()
eq(upgradeService.Upgrade(p1, nEntry.Slot), nil, "최고 단계에서는 더 안 됨")
expect(noticed("최고"), "최고 단계 안내")
-- 무기가 아닌 것 · 없는 칸
eq(upgradeService.Upgrade(p1, 23), nil, "빈 칸")
eq(upgradeService.Upgrade(p1, 0), nil, "착용 무기가 없으면 아무 일 없음")
eq(upgradeService.Upgrade(p1, 1.5), nil, "칸 번호가 정수가 아님")
-- 엽전 부족
nEntry.Plus = 0
d.Gold = 0
clear()
eq(upgradeService.Upgrade(p1, nEntry.Slot), nil, "엽전이 없으면 안 됨")
expect(noticed("엽전"), "엽전 부족 안내")
for _, e in sent("Notify") do
	checkText(e.args[1], "알림")
end

-- ---- 5) 무기 드롭 ----
local rng = RandomNew(4242)
local N, got, wrong = 40000, 0, 0
for _ = 1, N do
	for _, drop in drops.Roll("bamboo", rng) do
		if items[drop.item].Type == "Weapon" then
			got += 1
			if not table.find(drops.WEAPONS.bamboo, drop.item) then wrong += 1 end
		end
	end
end
local want = N * drops.WEAPON_CHANCE
expect(got > want * 0.85 and got < want * 1.15, ("무기 드롭 %d개(기대 약 %d개)"):format(got, want))
eq(wrong, 0, "그 지역 무기만 나옴")

-- ---- 6) 부적(방어구 대신): 표 · 착용 · 받는 피해 · 드롭 ----
local charmCount = 0
for id, def in items do
	if typeof(def) == "table" and def.Type == "Charm" then
		charmCount += 1
		expect(def.EquipSlot == "Armor" and def.Tab == "Equip" and def.StackMax == 1 and def.Defense > 0 and def.Level >= 1, "부적 기본 항목 " .. id)
		expect(itemIcons.rects["icon_" .. def.KitIcon] ~= nil, "부적 아이콘 " .. id)
		checkText(def.Name, "부적 이름 " .. id)
		checkText(def.Description, "부적 설명 " .. id)
	end
end
expect(charmCount >= 3, "부적 3종 이상")
for region, pool in drops.CHARMS do
	local r = regionOf[region]
	for _, id in pool do
		expect(items[id] ~= nil and items[id].Type == "Charm" and r ~= nil and items[id].Level <= r.levelMax, ("%s 드롭 부적 %s"):format(region, id))
	end
end
d.Level = 1
eq(inventory.GetDefense(p1), balance.BASE_DEFENSE, "부적 없음 = 기본 방어력")
inventory.AddItem(p1, "WindCharm", 1)
inventory.AddItem(p1, "GuardCharm", 1)
clear()
expect(not inventory.Equip(p1, (slotOf("WindCharm"))) and noticed("Lv.15"), "레벨이 모자란 부적은 못 참")
expect(inventory.Equip(p1, (slotOf("GuardCharm"))), "수호 부적 착용")
eq(inventory.GetDefense(p1), balance.BASE_DEFENSE + items.GuardCharm.Defense, "방어력 = 기본 + 부적")
eq(d.Equipment.Armor, "GuardCharm", "부적은 옛 방어구 칸에")
eq(upgradeService.Upgrade(p1, (slotOf("WindCharm"))), nil, "부적은 강화 대상이 아님")
local crng = RandomNew(99)
local cgot = 0
for _ = 1, 40000 do
	for _, drop in drops.Roll("desert", crng) do
		if items[drop.item].Type == "Charm" then
			cgot += 1
			eq(drop.item, "IronCharm", "사막 부적")
		end
	end
end
local cwant = 40000 * drops.CHARM_CHANCE
expect(cgot > cwant * 0.8 and cgot < cwant * 1.2, ("부적 드롭 %d개(기대 약 %d개)"):format(cgot, cwant))
for _, drop in drops.Roll("field", crng) do
	expect(items[drop.item].Type ~= "Charm", "들판에서는 부적이 안 나옴")
end
