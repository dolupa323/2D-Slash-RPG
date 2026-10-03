-- 저장 데이터: 새 플레이어 기본값 · 옛 저장 데이터를 지금 버전으로 올리기(옛 아이템은 팩 아이템으로 바뀌거나 없어진다)
local schema = req("ServerScriptService/server/services/playerSchema")
local items = req("ReplicatedStorage/shared/data/items")

local function count(data, id)
	local n = 0
	for _, e in data.Inventory do
		if e.ItemId == id then n += e.Count end
	end
	return n
end
local function slotsUnique(data)
	local seen = {}
	for _, e in data.Inventory do
		local key = e.Tab .. ":" .. e.Slot
		if seen[key] then return false end
		seen[key] = true
	end
	return true
end

-- 새 플레이어
local fresh = schema.default()
eq(fresh.SchemaVersion, schema.CURRENT_VERSION, "새 플레이어 버전")
eq(count(fresh, "Shuriken"), 30, "새 플레이어 수리검")
eq(count(fresh, "Onigiri"), 5, "새 플레이어 주먹밥")
eq(count(fresh, "Ninjato"), 1, "새 플레이어 닌자도")
eq(fresh.Job, 0, "새 플레이어 = 견습(전직 0)")
eq(#fresh.Inventory, 3, "새 플레이어 가방에는 팩 아이템 세 가지만")
eq(fresh.QuickSlots[1], "Shuriken", "단축칸 1")
eq(fresh.QuickSlots[2], "Onigiri", "단축칸 2")
expect(slotsUnique(fresh), "새 플레이어 가방 칸 겹침 없음")
for _, e in fresh.Inventory do
	expect(items[e.ItemId] ~= nil, "시작 물건이 아이템 표에 있음 " .. e.ItemId)
end

-- 옛 저장 데이터(v6, 방울을 단축칸에 둔 사람) → v7
local old = {
	SchemaVersion = 6, Level = 12, Experience = 30, MaxExperience = 650, Health = 200, Gold = 777,
	Inventory = {
		{ Tab = "Equip", Slot = 1, ItemId = "WoodenSword", Count = 1 },
		{ Tab = "Use", Slot = 1, ItemId = "RedPotion", Count = 3 },
		{ Tab = "Use", Slot = 2, ItemId = "Bell1", Count = 7 },
	},
	Equipment = { Weapon = "WoodenSword" }, Dex = { piyo = 1 },
	Pets = { Box = {}, Party = {}, Slots = 1, Boxes = 8 }, Life = { Mine = 0, Craft = 0 },
	QuickSlots = { "Bell1", "RedPotion", "" },
}
local migrate = schema.migrate or schema.Migrate or schema.upgrade or schema.Upgrade or schema.normalize or schema.Normalize
expect(migrate ~= nil, "마이그레이션 함수가 있음")
if migrate then
	local data = migrate(old) or old
	eq(data.SchemaVersion, schema.CURRENT_VERSION, "옛 데이터 버전")
	eq(data.Level, 12, "레벨 유지"); eq(data.Gold, 777, "엽전 유지")
	eq(count(data, "Shuriken"), 30, "수리검 지급")
	eq(count(data, "Onigiri"), 5 + 3, "주먹밥 지급 5 + 옛 빨간 물약 3개가 주먹밥으로")
	eq(count(data, "Bell1"), 0, "방울은 없어짐"); eq(count(data, "RedPotion"), 0, "옛 물약은 남지 않음")
	eq(count(data, "WoodenSword"), 0, "옛 나무 검은 남지 않음")
	eq(data.Equipment.Weapon, "Ninjato", "끼고 있던 나무 검 → 닌자도")
	expect(slotsUnique(data), "가방 칸 겹침 없음")
	for _, e in data.Inventory do
		expect(items[e.ItemId] ~= nil, "남은 물건은 전부 아이템 표에 있음 " .. e.ItemId)
	end
	eq(data.QuickSlots[1], "Shuriken", "단축칸 1: 방울 자리 → 수리검")
	eq(data.QuickSlots[2], "Onigiri", "단축칸 2: 빨간 물약 → 주먹밥")
	eq(data.QuickSlots[3], "", "단축칸 3: 같은 아이템은 한 칸만")
	local hasShuriken = false
	for i = 1, 3 do
		if data.QuickSlots[i] == "Shuriken" then hasShuriken = true end
	end
	expect(hasShuriken, "단축칸에 수리검이 들어감")
	-- 한 번 더 올려도 또 지급되지 않는다
	local again = migrate(data) or data
	eq(count(again, "Shuriken"), 30, "두 번 지급 안 됨")
end

-- 아주 옛 저장 데이터(v1 — 탭이 없던 시절): 옛 아이템이 사라지지 않고 팩 아이템으로 바뀐다
do
	local v1 = { SchemaVersion = 1, Level = 3, Experience = 0, MaxExperience = 200, Gold = 10, Equipment = { Armor = "LeafArmor" },
		Inventory = { { Slot = 1, ItemId = "WoodenSword", Count = 1 }, { Slot = 2, ItemId = "OrangePotion", Count = 2 }, { Slot = 3, ItemId = "Mat_piyo", Count = 9 } } }
	local data = schema.migrate(v1)
	expect(count(data, "Ninjato") >= 1, "v1 나무 검 → 닌자도")
	eq(count(data, "Sushi"), 2, "v1 주황 물약 → 초밥")
	eq(count(data, "Mat_piyo"), 0, "v1 몬스터 재료는 없어짐")
	eq(data.Equipment.Armor, "GuardCharm", "v1 잎사귀 갑옷 → 수호 부적")
	expect(slotsUnique(data), "v1 가방 칸 겹침 없음")
	for _, e in data.Inventory do
		expect(items[e.ItemId] ~= nil, "v1 남은 물건은 전부 아이템 표에 있음 " .. e.ItemId)
	end
end

-- v10 → v11(전직): 유파가 이미 있으면 그 레벨까지 전직한 것으로, 없으면 견습
do
	local a = schema.default(); a.SchemaVersion, a.Job, a.School, a.Level = 10, nil, "fire", 3
	eq(schema.migrate(a).Job, 1, "유파가 있는 Lv.3 → 1차(그대로 둠)")
	local b = schema.default(); b.SchemaVersion, b.Job, b.School, b.Level = 10, nil, "ice", 64
	eq(schema.migrate(b).Job, 3, "유파가 있는 Lv.64 → 3차")
	local c = schema.default(); c.SchemaVersion, c.Job, c.School, c.Level = 10, nil, "", 40
	eq(schema.migrate(c).Job, 0, "유파가 없으면 견습")
end
