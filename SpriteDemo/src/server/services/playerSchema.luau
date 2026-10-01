-- 플레이어 저장 데이터의 형태(스키마)와 버전 마이그레이션. 저장 데이터에는 SchemaVersion이 들어가고, 불러올 때마다 저장된
-- 버전에서 CURRENT_VERSION까지 마이그레이션을 순서대로 적용한다 — 필드를 추가/변경할 때 예전 저장 데이터가 깨지지 않게
-- 하는 단 하나의 통로다(예전에는 필드를 추가할 때마다 로드 코드에 `or {}` 같은 임기응변을 끼워 넣었다).
--
-- 새 필드/변경을 넣는 법: CURRENT_VERSION을 1 올리고, migrations[새 버전] = function(data) ... end 를 추가한다.
-- default()는 "가장 최신 버전의 신규 플레이어" 형태여야 한다(SchemaVersion = CURRENT_VERSION).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local balance = require(ReplicatedStorage.shared.config.balance)
local pets = require(ReplicatedStorage.shared.config.pets)

local exports = {}

exports.CURRENT_VERSION = 6

local STARTER_GOLD = 300 -- 처음 시작할 때 주는 골드(v3부터 — 기존 플레이어도 v3로 올라갈 때 한 번 받는다)

-- 포획 시험용 방울(v5부터 — 맺음석 세공(M6)·튜토리얼(M7)이 생기기 전까지 모두에게 한 번 지급)
local STARTER_BELLS = { { ItemId = "Bell1", Count = 10 }, { ItemId = "Bell2", Count = 3 } }

-- 처음 시작할 때 가방에 넣어 주는 물건(v2부터 — 기존 플레이어도 v2로 올라갈 때 한 번 받는다)
local STARTER_ITEMS = {
	{ Tab = "Equip", Slot = 1, ItemId = "WoodenSword", Count = 1 },
	{ Tab = "Equip", Slot = 2, ItemId = "LeafArmor", Count = 1 },
	{ Tab = "Use", Slot = 1, ItemId = "RedPotion", Count = 5 },
	{ Tab = "Etc", Slot = 1, ItemId = "SproutFragment", Count = 3 },
	{ Tab = "Key", Slot = 1, ItemId = "RainbowEgg", Count = 1 },
}
local function starterItems()
	local list = {}
	for _, e in STARTER_ITEMS do
		table.insert(list, table.clone(e))
	end
	local useSlot = 1
	for _, e in list do
		if e.Tab == "Use" then
			useSlot = math.max(useSlot, e.Slot + 1)
		end
	end
	for _, b in STARTER_BELLS do
		table.insert(list, { Tab = "Use", Slot = useSlot, ItemId = b.ItemId, Count = b.Count })
		useSlot += 1
	end
	return list
end

local function newPets()
	return { Box = {}, Party = {}, Slots = pets.SLOTS_START, Boxes = pets.BOXES_START }
end

function exports.default()
	return {
		SchemaVersion = exports.CURRENT_VERSION,
		Level = 1,
		Experience = 0,
		MaxExperience = balance.maxExperienceFor(1),
		Health = balance.maxHealthFor(1),
		Gold = STARTER_GOLD,
		-- { { Tab = string, Slot = number, ItemId = string, Count = number }, ... } — 탭(장비·소비·기타·캐시·중요)마다
		-- 칸 번호가 따로 있다. 빈 칸이 있는 숫자 키 테이블은 DataStore가 안전하게 저장하지 못해서 칸 번호를 값 안에 넣은 촘촘한 배열로 둔다.
		Inventory = starterItems(),
		-- { Weapon = ItemId?, Armor = ItemId? } — 착용 중인 장비(비어 있으면 키 없음).
		Equipment = {},
		-- 도감: { [종류 id] = 1(봤음 — 쓰러뜨림) | 2(잡았음) } (shared/config/pets.luau DEX_SEEN / DEX_CAUGHT)
		Dex = {},
		-- 펫(잡은 몬스터): 형식은 shared/config/pets.luau 맨 위 설명
		Pets = newPets(),
		-- 생활 숙련도 경험치: Mine = 맺음석 캐기, Craft = 방울 세공
		Life = { Mine = 0, Craft = 0 },
		-- 소비 단축칸 1·2·3(아이템 id, 빈 칸 = "") — 숫자키/터치로 바로 사용(방울 = 던지기)
		QuickSlots = { "Bell1", "RedPotion", "" },
	}
end

-- 각 함수는 "이전 버전 데이터를 그 번호 버전으로 올린다".
local migrations = {
	-- v0(버전 필드가 없던 초기 저장 데이터) → v1: 뼈대 시절 이후 추가된 필드들을 채운다.
	[1] = function(data)
		data.Level = data.Level or 1
		data.Experience = data.Experience or 0
		data.MaxExperience = data.MaxExperience or balance.maxExperienceFor(data.Level)
		data.Gold = data.Gold or 0
		data.Inventory = data.Inventory or {}
		data.Equipment = data.Equipment or {}
	end,
	-- v1 → v2: 가방이 탭(장비·소비·기타·캐시·중요)으로 나뉜다 — 기존 아이템을 종류별 탭으로 옮겨 칸을 1번부터 다시 매긴다.
	-- 도감(Dex) 추가, 시작 물건 지급.
	[2] = function(data)
		local items = require(ReplicatedStorage.shared.data.items)
		local nextSlot = {}
		local moved = {}
		for _, e in data.Inventory or {} do
			local def = items[e.ItemId]
			if def then
				local tab = def.Tab or "Etc"
				nextSlot[tab] = (nextSlot[tab] or 0) + 1
				table.insert(moved, { Tab = tab, Slot = nextSlot[tab], ItemId = e.ItemId, Count = e.Count })
			end
		end
		for _, e in STARTER_ITEMS do
			nextSlot[e.Tab] = (nextSlot[e.Tab] or 0) + 1
			if nextSlot[e.Tab] <= balance.INVENTORY_SLOTS then
				table.insert(moved, { Tab = e.Tab, Slot = nextSlot[e.Tab], ItemId = e.ItemId, Count = e.Count })
			end
		end
		data.Inventory = moved
		data.Dex = data.Dex or {}
	end,
	-- v2 → v3: 가게(포션 상점)가 생겨서 시작 골드를 준다.
	[3] = function(data)
		data.Gold = (data.Gold or 0) + STARTER_GOLD
	end,
	-- v3 → v4(몬스터 수집 RPG 전환, GAME_DESIGN.md): 도감이 봤음/잡았음 두 상태가 되고(예전 true = 봤음), 펫 상자와 생활 숙련도가 생긴다.
	[4] = function(data)
		local dex = {}
		for id, v in data.Dex or {} do
			if v then
				dex[id] = if v == pets.DEX_CAUGHT then pets.DEX_CAUGHT else pets.DEX_SEEN
			end
		end
		data.Dex = dex
		data.Pets = data.Pets or newPets()
		data.Life = data.Life or { Mine = 0, Craft = 0 }
	end,
	-- v4 → v5: 포획(M2) 시험용 방울을 "소비" 탭 빈 칸에 넣는다(칸이 모자라면 들어가는 만큼만).
	[5] = function(data)
		local used = {}
		for _, e in data.Inventory or {} do
			if e.Tab == "Use" then
				used[e.Slot] = true
			end
		end
		local slot = 1
		for _, b in STARTER_BELLS do
			while used[slot] do
				slot += 1
			end
			if slot > balance.INVENTORY_SLOTS then
				break
			end
			table.insert(data.Inventory, { Tab = "Use", Slot = slot, ItemId = b.ItemId, Count = b.Count })
			used[slot] = true
		end
	end,
	-- v5 → v6: 포획이 전투 중 방울 던지기로 바뀌며 소비 단축칸 1·2·3이 생긴다(처음엔 흐린 방울 · 빨간 물약).
	[6] = function(data)
		data.QuickSlots = data.QuickSlots or { "Bell1", "RedPotion", "" }
	end,
}

-- 저장 데이터를 최신 버전으로 올리고 값 범위를 정리한다. 이미 최신이면 마이그레이션은 건너뛴다.
function exports.migrate(data)
	local version = data.SchemaVersion or 0
	if version > exports.CURRENT_VERSION then
		warn(("playerSchema: 저장 데이터 버전(%d)이 이 서버(%d)보다 새 버전이다 — 그대로 사용하지만 필드 호환이 안 될 수 있다"):format(
			version, exports.CURRENT_VERSION
		))
		return data
	end
	while version < exports.CURRENT_VERSION do
		version += 1
		migrations[version](data)
	end
	data.SchemaVersion = exports.CURRENT_VERSION

	-- 체력은 서버가 소유한다: 저장된 값이 없거나(첫 접속) 0 이하(죽은 채 저장)면 가득 채운 상태로, 최대 체력을 넘으면 잘라낸다.
	local maxHealth = balance.maxHealthFor(data.Level)
	if typeof(data.Health) ~= "number" or data.Health <= 0 then
		data.Health = maxHealth
	end
	data.Health = math.min(data.Health, maxHealth)

	return data
end

return exports
