-- 인벤토리/장비 서비스: 아이템 추가(스택/빈 칸), 장비 착용·해제, 장비에서 계산하는 공격력/방어력. 인벤토리는
-- { Slot, ItemId, Count } 촘촘한 배열로 저장한다(DataStore가 빈 칸이 있는 숫자 키 테이블을 못 저장함).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local balance = require(ReplicatedStorage.shared.config.balance)
local Net = require(ReplicatedStorage.shared.net.net)
local persistence = require(script.Parent.persistence)
local items = require(ReplicatedStorage.shared.data.items)

local INVENTORY_SLOTS = balance.INVENTORY_SLOTS

local exports = {}

local function findSlotEntry(inventory, slot)
	for _, entry in inventory do
		if entry.Slot == slot then
			return entry
		end
	end
	return nil
end

-- 서버 모듈(몬스터 드롭 등)이 아이템을 줄 때 쓴다. 같은 아이템의 기존 스택부터 StackMax까지
-- 채우고, 남으면 빈 칸에 새로 넣는다. 실제로 들어간 개수를 돌려준다(가방이 가득 차면 일부만
-- 들어가거나 0일 수 있음).
function exports.AddItem(player: Player, itemId: string, count: number): number
	local data = persistence.Get(player)
	local def = items[itemId]
	if not data or not def or count <= 0 then
		return 0
	end

	local inventory = data.Inventory
	local remaining = count

	for _, entry in inventory do
		if remaining <= 0 then
			break
		end
		if entry.ItemId == itemId and entry.Count < def.StackMax then
			local room = def.StackMax - entry.Count
			local add = math.min(room, remaining)
			entry.Count += add
			remaining -= add
		end
	end

	for slot = 1, INVENTORY_SLOTS do
		if remaining <= 0 then
			break
		end
		if not findSlotEntry(inventory, slot) then
			local add = math.min(def.StackMax, remaining)
			table.insert(inventory, { Slot = slot, ItemId = itemId, Count = add })
			remaining -= add
		end
	end

	local added = count - remaining
	if added > 0 then
		persistence.MarkDirty(player)
		Net.FireClient("InventoryUpdated", player, inventory)
		Net.FireClient("ItemAcquired", player, itemId, added)
	end
	return added
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
function exports.GetAttackDamage(player: Player): number
	return balance.BASE_ATTACK + equippedStat(player, "Attack")
end

function exports.GetDefense(player: Player): number
	return balance.BASE_DEFENSE + equippedStat(player, "Defense")
end

local function pushEquipment(player: Player, data)
	persistence.MarkDirty(player)
	Net.FireClient("InventoryUpdated", player, data.Inventory)
	Net.FireClient("EquipmentUpdated", player, data.Equipment)
end

function exports.Equip(player: Player, slot: number): boolean
	local data = persistence.Get(player)
	if not data then
		return false
	end
	local entry = findSlotEntry(data.Inventory, slot)
	local def = entry and items[entry.ItemId]
	if not def or not def.EquipSlot then
		return false
	end

	local previous = data.Equipment[def.EquipSlot]
	table.remove(data.Inventory, table.find(data.Inventory, entry))
	data.Equipment[def.EquipSlot] = entry.ItemId
	if previous then
		-- 방금 비워진 그 칸에 기존 장비를 돌려놓는다(교체).
		table.insert(data.Inventory, { Slot = slot, ItemId = previous, Count = 1 })
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
	for slot = 1, INVENTORY_SLOTS do
		if not findSlotEntry(data.Inventory, slot) then
			table.insert(data.Inventory, { Slot = slot, ItemId = itemId, Count = 1 })
			data.Equipment[equipSlot] = nil
			pushEquipment(player, data)
			return true
		end
	end
	return false -- 가방이 가득 차서 해제할 자리가 없다.
end

return exports
