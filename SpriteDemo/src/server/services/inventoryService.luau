-- 인벤토리/장비 서비스: 아이템 추가(스택/빈 칸), 칸 옮기기(드래그 앤 드롭), 꺼내기(버리기), 장비 착용·해제,
-- 장비에서 계산하는 공격력/방어력. 가방은 탭(장비·소비·기타·캐시·중요)마다 칸이 따로 있고,
-- { Tab, Slot, ItemId, Count, Plus? } 촘촘한 배열로 저장한다(Plus = 무기 강화 단계 — 착용하면 data.EquipmentPlus로 옮겨 간다)(DataStore가 빈 칸이 있는 숫자 키 테이블을 못 저장함).
-- 아이템이 어느 탭에 들어가는지는 아이템 표(shared/data/items.luau)의 Tab이 정한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local balance = require(ReplicatedStorage.shared.config.balance)
local Net = require(ReplicatedStorage.shared.net.net)
local persistence = require(script.Parent.persistence)
local items = require(ReplicatedStorage.shared.data.items)
local weapons = require(ReplicatedStorage.shared.config.weapons)
local ninjutsu = require(ReplicatedStorage.shared.config.ninjutsu)

local SLOTS = balance.INVENTORY_SLOTS

local exports = {}

local function tabOf(itemId: string): string
	local def = items[itemId]
	return def and def.Tab or "Etc"
end

local function findEntry(inventory, tab: string, slot: number)
	for _, entry in inventory do
		if entry.Tab == tab and entry.Slot == slot then
			return entry
		end
	end
	return nil
end
exports.FindEntry = findEntry

local function push(player: Player, data)
	persistence.MarkDirty(player)
	Net.FireClient("InventoryUpdated", player, data.Inventory)
end

-- 이 아이템이 몇 개까지 들어갈 수 있는가(같은 스택 여유 + 빈 칸)
function exports.RoomFor(player: Player, itemId: string): number
	local data = persistence.Get(player)
	local def = items[itemId]
	if not data or not def then
		return 0
	end
	local tab = tabOf(itemId)
	local room = 0
	for _, e in data.Inventory do
		if e.Tab == tab and e.ItemId == itemId then
			room += def.StackMax - e.Count
		end
	end
	for slot = 1, SLOTS do
		if not findEntry(data.Inventory, tab, slot) then
			room += def.StackMax
		end
	end
	return room
end

-- 서버 모듈(줍기·드롭 등)이 아이템을 줄 때 쓴다. 그 아이템 탭의 같은 스택부터 StackMax까지 채우고, 남으면 빈 칸에 넣는다.
-- 실제로 들어간 개수를 돌려준다(가방이 가득 차면 일부만 들어가거나 0일 수 있음).
function exports.AddItem(player: Player, itemId: string, count: number): number
	local data = persistence.Get(player)
	local def = items[itemId]
	if not data or not def or count <= 0 then
		return 0
	end
	local tab = tabOf(itemId)
	local inventory = data.Inventory
	local remaining = count

	for _, entry in inventory do
		if remaining <= 0 then
			break
		end
		if entry.Tab == tab and entry.ItemId == itemId and entry.Count < def.StackMax then
			local add = math.min(def.StackMax - entry.Count, remaining)
			entry.Count += add
			remaining -= add
		end
	end
	for slot = 1, SLOTS do
		if remaining <= 0 then
			break
		end
		if not findEntry(inventory, tab, slot) then
			local add = math.min(def.StackMax, remaining)
			table.insert(inventory, { Tab = tab, Slot = slot, ItemId = itemId, Count = add })
			remaining -= add
		end
	end

	local added = count - remaining
	if added > 0 then
		push(player, data)
		Net.FireClient("ItemAcquired", player, itemId, added)
	end
	return added
end

-- 같은 탭 안에서 칸 옮기기(드래그 앤 드롭): 빈 칸이면 이동, 아이템이 있으면 서로 바꾸기, 같은 아이템이면 합치기(넘치면 남는다).
function exports.Move(player: Player, tab: string, from: number, to: number): boolean
	local data = persistence.Get(player)
	if not data or from == to or from ~= math.floor(from) or to ~= math.floor(to) or from < 1 or from > SLOTS or to < 1 or to > SLOTS then
		return false
	end
	local a = findEntry(data.Inventory, tab, from)
	if not a then
		return false
	end
	local b = findEntry(data.Inventory, tab, to)
	if b and b.ItemId == a.ItemId then
		local def = items[a.ItemId]
		local add = math.min(def.StackMax - b.Count, a.Count)
		if add > 0 then
			b.Count += add
			a.Count -= add
			if a.Count <= 0 then
				table.remove(data.Inventory, table.find(data.Inventory, a))
			end
			push(player, data)
			return true
		end
	end
	a.Slot = to
	if b then
		b.Slot = from
	end
	push(player, data)
	return true
end

-- 칸의 아이템을 통째로 꺼낸다(버리기) — 꺼낸 { ItemId, Count }를 돌려준다. 중요 물품(NoDrop)은 못 꺼낸다.
function exports.Take(player: Player, tab: string, slot: number)
	local data = persistence.Get(player)
	local entry = data and findEntry(data.Inventory, tab, slot)
	local def = entry and items[entry.ItemId]
	if not entry or not def or def.NoDrop then
		return nil
	end
	if (entry.Plus or 0) > 0 then
		Net.FireClient("Notify", player, "강화한 장비는 버릴 수 없어요") -- 땅에 떨어진 아이템은 강화 단계를 담지 못한다
		return nil
	end
	table.remove(data.Inventory, table.find(data.Inventory, entry))
	push(player, data)
	return { ItemId = entry.ItemId, Count = entry.Count }
end

-- 그 아이템을 모두 합쳐 몇 개 가졌나
function exports.CountItem(player: Player, itemId: string): number
	local data = persistence.Get(player)
	local n = 0
	for _, entry in data and data.Inventory or {} do
		if entry.ItemId == itemId then
			n += entry.Count
		end
	end
	return n
end

-- 아이템 id로 count개를 뺀다(여러 칸에 나뉘어 있어도). 모자라면 아무것도 안 빼고 false.
function exports.TakeItem(player: Player, itemId: string, count: number): boolean
	local data = persistence.Get(player)
	if not data or count <= 0 or exports.CountItem(player, itemId) < count then
		return false
	end
	local remaining = count
	for i = #data.Inventory, 1, -1 do
		local entry = data.Inventory[i]
		if remaining <= 0 then
			break
		end
		if entry.ItemId == itemId then
			local n = math.min(entry.Count, remaining)
			entry.Count -= n
			remaining -= n
			if entry.Count <= 0 then
				table.remove(data.Inventory, i)
			end
		end
	end
	push(player, data)
	return true
end

-- 칸에서 개수만큼 빼낸다(팔기·사용). 실제로 뺀 { ItemId, Count }를 돌려준다(없으면 nil).
function exports.Remove(player: Player, tab: string, slot: number, count: number)
	local data = persistence.Get(player)
	local entry = data and findEntry(data.Inventory, tab, slot)
	if not entry or count <= 0 then
		return nil
	end
	local n = math.min(count, entry.Count)
	entry.Count -= n
	if entry.Count <= 0 then
		table.remove(data.Inventory, table.find(data.Inventory, entry))
	end
	push(player, data)
	return { ItemId = entry.ItemId, Count = n }
end

local function equippedStat(player: Player, statName: string): number
	local data = persistence.Get(player)
	local total = 0
	if data then
		for _, itemId in data.Equipment do
			local def = items[itemId]
			if def and def[statName] then
				total += def[statName]
			end
		end
	end
	return total
end

-- 전투에 쓰이는 최종 수치(서버가 착용 장비에서 계산 — 몬스터 모듈이 호출).
--  공격력 = 레벨(balance.attackFor) + 착용 장비 Attack + 무기 강화 보너스(weapons.Bonus)
function exports.GetAttackDamage(player: Player): number
	local data = persistence.Get(player)
	local weaponDef = data and items[data.Equipment.Weapon or ""]
	local plus = data and data.EquipmentPlus and data.EquipmentPlus.Weapon
	local total = balance.attackFor(data and data.Level or 1) + equippedStat(player, "Attack") + weapons.Bonus(weaponDef, plus)
	-- 무기 단련(공용 패시브 c_mastery): 레벨마다 공격력 +
	local mastery = ninjutsu.LevelOf(data and data.Ninjutsu, "c_mastery")
	return if mastery > 0 then math.round(total * (1 + ninjutsu.SKILLS.c_mastery.perLevel * mastery)) else total
end

function exports.GetDefense(player: Player): number
	return balance.BASE_DEFENSE + equippedStat(player, "Defense")
end

local function pushEquipment(player: Player, data)
	push(player, data)
	Net.FireClient("EquipmentUpdated", player, data.Equipment, data.EquipmentPlus or {})
end

-- 가방·장비를 다시 보낸다(강화처럼 서비스 밖에서 칸 내용을 고친 뒤)
function exports.Refresh(player: Player)
	local data = persistence.Get(player)
	if data then
		pushEquipment(player, data)
	end
end

-- 장비 탭의 칸(slot)을 착용한다. 이미 끼고 있던 장비는 그 칸으로 돌아간다(교체).
function exports.Equip(player: Player, slot: number): boolean
	local data = persistence.Get(player)
	if not data then
		return false
	end
	local entry = findEntry(data.Inventory, "Equip", slot)
	local def = entry and items[entry.ItemId]
	if not def or not def.EquipSlot then
		return false
	end
	if def.Level and (data.Level or 1) < def.Level then
		Net.FireClient("Notify", player, ("Lv.%d부터 쓸 수 있어요"):format(def.Level))
		return false
	end
	data.EquipmentPlus = data.EquipmentPlus or {}
	local previous, previousPlus = data.Equipment[def.EquipSlot], data.EquipmentPlus[def.EquipSlot]
	table.remove(data.Inventory, table.find(data.Inventory, entry))
	data.Equipment[def.EquipSlot] = entry.ItemId
	data.EquipmentPlus[def.EquipSlot] = entry.Plus -- 강화 단계도 같이 옮긴다(없으면 nil)
	if previous then
		table.insert(data.Inventory, { Tab = "Equip", Slot = slot, ItemId = previous, Count = 1, Plus = previousPlus })
	end
	pushEquipment(player, data)
	return true
end

function exports.Unequip(player: Player, equipSlot: string): boolean
	local data = persistence.Get(player)
	local itemId = data and data.Equipment[equipSlot]
	if not itemId then
		return false
	end
	for slot = 1, SLOTS do
		if not findEntry(data.Inventory, "Equip", slot) then
			local plus = data.EquipmentPlus and data.EquipmentPlus[equipSlot]
			table.insert(data.Inventory, { Tab = "Equip", Slot = slot, ItemId = itemId, Count = 1, Plus = plus })
			data.Equipment[equipSlot] = nil
			if data.EquipmentPlus then
				data.EquipmentPlus[equipSlot] = nil
			end
			pushEquipment(player, data)
			return true
		end
	end
	return false -- 장비 탭이 가득 차서 해제할 자리가 없다.
end

return exports
