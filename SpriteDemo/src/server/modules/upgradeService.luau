-- 무기 강화(서버) — 「오문 닌자전」 NINJA_DESIGN.md §7. 수치는 shared/config/weapons.luau(MAX_PLUS · BONUS · RATE · BARS · Cost).
--  UpgradeWeapon(칸): 0 = 지금 착용한 무기, 1 이상 = 가방 장비 탭의 그 칸. 대장간 NPC(weapons.UPGRADE_NPC) 곁에서만.
--   재료(주괴 × 목표 단계)와 엽전을 먼저 쓰고 확률을 굴린다 — 성공하면 +1, 실패하면 단계 그대로(깨지지 않는다).
--   강화 단계는 아이템마다 따로: 가방 칸의 Plus, 착용 중이면 data.EquipmentPlus[칸 이름](inventoryService가 착용·해제 때 옮긴다).
--   결과는 UpgradeResult(성공 여부, 아이템 id, 지금 단계) + 알림. 가방·장비 갱신은 InventoryUpdated · EquipmentUpdated.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local npcTalk = require(ReplicatedStorage.shared.config.npcTalk)
local weapons = require(ReplicatedStorage.shared.config.weapons)
local items = require(ReplicatedStorage.shared.data.items)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local persistence = require(script.Parent.Parent.services.persistence)
local inventoryService = require(script.Parent.Parent.services.inventoryService)
local currencyService = require(script.Parent.Parent.services.currencyService)

local NPC_PAD = 24 -- 대화 거리보다 이만큼(도트) 여유(복제 지연 보정)

local exports = {}
local rng = Random.new()

local function nearNpc(player: Player, npcType: string): boolean
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	local d = key and townWorld.Get(key)
	local position = heroTracking.GetPosition(player.UserId)
	if not d or not position then
		return false
	end
	local feet = position / townWorld.data.scale
	for _, n in d.npcs do
		if n.type == npcType and (Vector2.new(n.x, n.y) - feet).Magnitude <= npcTalk.RANGE + NPC_PAD then
			return true
		end
	end
	return false
end

-- 강화 시도. 돌려주는 값: "success" | "fail" | nil(조건이 안 맞아 아무 일도 없음)
function exports.Upgrade(player: Player, slot: number): string?
	local data = persistence.Get(player)
	if not data or slot ~= math.floor(slot) or slot < 0 then
		return nil
	end
	if not nearNpc(player, weapons.UPGRADE_NPC) then
		Net.FireClient("Notify", player, "강화는 대장간에서 할 수 있어요")
		return nil
	end
	data.EquipmentPlus = data.EquipmentPlus or {}
	local entry = if slot > 0 then inventoryService.FindEntry(data.Inventory, "Equip", slot) else nil
	local itemId = if slot > 0 then entry and entry.ItemId else data.Equipment.Weapon
	local def = itemId and items[itemId]
	if not def or def.Type ~= "Weapon" then
		return nil
	end
	local plus = (if slot > 0 then entry.Plus else data.EquipmentPlus.Weapon) or 0
	local cost = weapons.Cost(def, plus + 1)
	if not cost then
		Net.FireClient("Notify", player, "이미 최고 단계예요")
		return nil
	end
	if inventoryService.CountItem(player, cost.bar) < cost.bars then
		Net.FireClient("Notify", player, ("%s이(가) 모자라요(%d개 필요)"):format(items[cost.bar].Name, cost.bars))
		return nil
	end
	if (data.Gold or 0) < cost.gold then
		Net.FireClient("Notify", player, ("엽전이 모자라요(%d 필요)"):format(cost.gold))
		return nil
	end
	inventoryService.TakeItem(player, cost.bar, cost.bars)
	currencyService.AddGold(player, -cost.gold)
	local success = rng:NextNumber() < cost.rate
	if success then
		plus += 1
		if slot > 0 then
			entry.Plus = plus
		else
			data.EquipmentPlus.Weapon = plus
		end
	end
	persistence.MarkDirty(player)
	task.spawn(persistence.Save, player, false) -- 재료를 썼으니 바로 저장
	inventoryService.Refresh(player)
	Net.FireClient("UpgradeResult", player, success, itemId, plus)
	Net.FireClient("Notify", player, if success
		then ("강화 성공! %s +%d"):format(def.Name, plus)
		else ("강화 실패… %s은(는) +%d 그대로예요"):format(def.Name, plus))
	return if success then "success" else "fail"
end

function exports.load()
	Net.OnServer("UpgradeWeapon", function(player: Player, slot: number)
		exports.Upgrade(player, slot)
	end)
end

function exports.start() end
function exports.unload() end

return exports
