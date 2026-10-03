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

exports.CURRENT_VERSION = 13

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
-- 「오문 닌자전」 시작 물건(v7부터 — 기존 플레이어도 v7로 올라갈 때 한 번 받는다): 수리검 · 주먹밥
local NINJA_STARTER = { { ItemId = "Shuriken", Count = 30 }, { ItemId = "Onigiri", Count = 5 } }
local NINJA_QUICKSLOTS = { "Shuriken", "Onigiri", "" }

-- 소비 탭 빈 칸에 차례로 넣는다(칸이 모자라면 들어가는 만큼만)
local function addToUseTab(inventory, list)
	local used = {}
	for _, e in inventory do
		if e.Tab == "Use" then
			used[e.Slot] = true
		end
	end
	local slot = 1
	for _, b in list do
		while used[slot] do
			slot += 1
		end
		if slot > balance.INVENTORY_SLOTS then
			break
		end
		table.insert(inventory, { Tab = "Use", Slot = slot, ItemId = b.ItemId, Count = b.Count })
		used[slot] = true
	end
end

-- 「오문 닌자전」 새 플레이어의 가방(v10부터): 닌자도 + 수리검 + 주먹밥. 예전 시작 물건(STARTER_ITEMS · STARTER_BELLS)은
-- 옛 버전 마이그레이션이 지나가는 길에만 쓰이고, v10이 전부 팩 아이템으로 바꾸거나 없앤다.
local NEW_PLAYER_ITEMS = {
	{ Tab = "Equip", Slot = 1, ItemId = "Ninjato", Count = 1 },
	{ Tab = "Use", Slot = 1, ItemId = "Shuriken", Count = 30 },
	{ Tab = "Use", Slot = 2, ItemId = "Onigiri", Count = 5 },
}
-- 옛 아이템 → 팩 아이템(v10). 여기 없고 아이템 표에도 없는 것(방울 · 몬스터 재료 · 새싹 조각 · 무지개 알)은 없앤다.
local LEGACY_ITEMS = { WoodenSword = "Ninjato", LeafArmor = "GuardCharm", RedPotion = "Onigiri", OrangePotion = "Sushi", WhitePotion = "Yakitori" }
-- 옛 아이템이 들어가던 탭(v2 마이그레이션이 아이템 표 대신 본다 — 표에서 옛 아이템을 없앴으므로)
local LEGACY_TABS = { WoodenSword = "Equip", LeafArmor = "Equip", RedPotion = "Use", OrangePotion = "Use", WhitePotion = "Use" }

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
		Inventory = (function()
			local list = {}
			for _, e in NEW_PLAYER_ITEMS do
				table.insert(list, table.clone(e))
			end
			return list
		end)(),
		-- { Weapon = ItemId?, Armor = ItemId? } — 착용 중인 장비(비어 있으면 키 없음).
		Equipment = {},
		-- 착용 장비의 강화 단계 { Weapon = 0~10 }(가방에 있을 때는 그 칸의 Plus — shared/config/weapons.luau)
		EquipmentPlus = {},
		-- 도감: { [종류 id] = 1(봤음 — 쓰러뜨림) | 2(잡았음) } (shared/config/pets.luau DEX_SEEN / DEX_CAUGHT)
		Dex = {},
		-- 펫(잡은 몬스터): 형식은 shared/config/pets.luau 맨 위 설명
		Pets = newPets(),
		-- 생활 숙련도 경험치: Mine = 맺음석 캐기, Craft = 방울 세공
		Life = { Mine = 0, Craft = 0 },
		-- 소비 단축칸 1·2·3(아이템 id, 빈 칸 = "") — 숫자키/터치로 바로 사용(방울 = 던지기)
		QuickSlots = table.clone(NINJA_QUICKSLOTS),
		-- 유파(shared/config/ninjutsu.luau SCHOOLS의 id, "" = 아직 안 고름) · 인술 단계 { [인술 id] = 1~5 }(없으면 1단계)
		School = "",
		Ninjutsu = {},
		-- 전직 단계: 0 = 견습(유파 없음) · 1~4 = n차 전직(Lv.10 · 30 · 60 · 100, 1차 때 유파를 고른다)
		Job = 0,
		-- 스킬(shared/config/ninjutsu.luau 스킬 나무): Ninjutsu = { [스킬 id] = 레벨 }, SP = 전직(1~4)별 안 쓴 스킬 포인트, SkillSlots = 단축칸의 스킬 id("" = 빈 칸)
		SP = { 0, 0, 0, 0 },
		SkillSlots = { "", "", "", "" },
		-- 본 줄거리 퀘스트(shared/config/quests.luau): 지금 퀘스트 번호 · 받았는가 · 진행(처치 수 등)
		Quest = { Index = 1, Accepted = false, Progress = 0 },
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
			local legacyTab = LEGACY_TABS[e.ItemId]
			if def or legacyTab then
				local tab = legacyTab or def.Tab or "Etc"
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
	-- v6 → v7(「오문 닌자전」 전환, NINJA_DESIGN.md): 투척 무기·음식을 한 번 지급하고, 단축칸의 방울(포획은 꺼 둠)을 수리검·주먹밥으로 바꾼다.
	[7] = function(data)
		data.Inventory = data.Inventory or {}
		addToUseTab(data.Inventory, NINJA_STARTER)
		local slots = data.QuickSlots or { "", "", "" }
		local taken = {}
		for i = 1, 3 do
			local id = slots[i] or ""
			if string.sub(id, 1, 4) == "Bell" then
				id = ""
			end
			slots[i] = id
			taken[id] = true
		end
		for _, id in NINJA_QUICKSLOTS do
			if id ~= "" and not taken[id] then
				for i = 1, 3 do
					if slots[i] == "" then
						slots[i] = id
						taken[id] = true
						break
					end
				end
			end
		end
		data.QuickSlots = slots
	end,
	-- v7 → v8(N2 유파와 인술): 유파(아직 안 고름)와 인술 단계표가 생긴다 — 접속하면 유파 고르기 창이 뜬다.
	[8] = function(data)
		data.School = data.School or ""
		data.Ninjutsu = data.Ninjutsu or {}
	end,
	-- v8 → v9(N3 장비와 강화): 착용 장비의 강화 단계표가 생긴다.
	[9] = function(data)
		data.EquipmentPlus = data.EquipmentPlus or {}
	end,
	-- v9 → v10(에셋 · UI 전면 교체): 아이템이 전부 팩 아이템이 됐다. 옛 아이템은 짝이 되는 팩 아이템으로 바꾸고
	-- (나무 검 → 닌자도, 잎사귀 갑옷 → 수호 부적, 물약 → 음식), 짝이 없는 것은 없앤다. 같은 아이템은 한 칸에 합친다.
	[10] = function(data)
		local items = require(ReplicatedStorage.shared.data.items)
		local kept, usedSlots = {}, {}
		local function freeSlot(tab: string, prefer: number?): number?
			usedSlots[tab] = usedSlots[tab] or {}
			if prefer and prefer >= 1 and prefer <= balance.INVENTORY_SLOTS and not usedSlots[tab][prefer] then
				return prefer
			end
			for slot = 1, balance.INVENTORY_SLOTS do
				if not usedSlots[tab][slot] then
					return slot
				end
			end
			return nil
		end
		for _, e in data.Inventory or {} do
			local id = LEGACY_ITEMS[e.ItemId] or e.ItemId
			local def = items[id]
			local remaining = if def then (e.Count or 1) else 0
			if def and def.StackMax > 1 then
				for _, k in kept do
					if remaining > 0 and k.ItemId == id and k.Count < def.StackMax then
						local add = math.min(def.StackMax - k.Count, remaining)
						k.Count += add
						remaining -= add
					end
				end
			end
			while def and remaining > 0 do
				local slot = freeSlot(def.Tab, if e.Tab == def.Tab then e.Slot else nil)
				if not slot then
					break -- 그 탭이 가득 — 남는 것은 버려진다
				end
				local add = math.min(def.StackMax, remaining)
				usedSlots[def.Tab][slot] = true
				table.insert(kept, { Tab = def.Tab, Slot = slot, ItemId = id, Count = add, Plus = e.Plus })
				remaining -= add
			end
		end
		data.Inventory = kept
		local equipment = {}
		for slotName, itemId in data.Equipment or {} do
			local id = LEGACY_ITEMS[itemId] or itemId
			local def = items[id]
			if def and def.EquipSlot == slotName then
				equipment[slotName] = id
			end
		end
		data.Equipment = equipment
		local slots, seen = data.QuickSlots or { "", "", "" }, {}
		for i = 1, 3 do
			local id = LEGACY_ITEMS[slots[i] or ""] or slots[i] or ""
			local def = items[id]
			if not def or def.Tab ~= "Use" or seen[id] then
				id = ""
			end
			seen[id] = true
			slots[i] = id
		end
		data.QuickSlots = slots
	end,
	-- v10 → v11(전직): 전직 단계가 생긴다. 이미 유파가 있는 사람은 그 레벨까지의 전직을 한 것으로 친다(레벨이 10이 안 돼도 1차).
	[11] = function(data)
		if data.Job == nil then
			local ninjutsu = require(ReplicatedStorage.shared.config.ninjutsu)
			data.Job = if (data.School or "") ~= "" then math.max(1, ninjutsu.JobFor(data.Level or 1)) else 0
		end
	end,
	-- v12 → v13(스킬 나무 · SP): 옛 "전직마다 인술 하나 + 두루마리 단계"를 스킬 레벨 · SP · 단축칸으로 바꾼다.
	--  전직한 구간마다 그 레벨까지의 SP를 주고, 각 전직의 주력기 · 핵심 장치를 배운 것으로 친다(옛 두루마리 단계는 그 스킬의 레벨로).
	[13] = function(data)
		local ninjutsu = require(ReplicatedStorage.shared.config.ninjutsu)
		local old = if typeof(data.Ninjutsu) == "table" then data.Ninjutsu else {}
		data.Ninjutsu = {}
		data.SP = { 0, 0, 0, 0 }
		data.SkillSlots = { "", "", "", "" }
		local slot = 1
		if ninjutsu.TREE[data.School or ""] then
			for job = 1, math.min(data.Job or 0, #ninjutsu.JOB_LEVELS) do
				data.SP[job] = math.max(ninjutsu.SP_ON_JOB, ninjutsu.SpEarned(job, data.Level or 1))
				for _, id in ninjutsu.AutoFor(data.School, job) do
					local level = if typeof(old[id]) == "number" then old[id] else 1
					data.Ninjutsu[id] = math.clamp(math.floor(level), 1, ninjutsu.MaxOf(id))
					if ninjutsu.IsActive(id) and slot <= ninjutsu.SLOTS then
						data.SkillSlots[slot] = id
						slot += 1
					end
				end
			end
		end
	end,
	-- v11 → v12(퀘스트): 본 줄거리 퀘스트가 생긴다. 누구나 첫 퀘스트부터.
	[12] = function(data)
		if typeof(data.Quest) ~= "table" then
			data.Quest = { Index = 1, Accepted = false, Progress = 0 }
		end
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
