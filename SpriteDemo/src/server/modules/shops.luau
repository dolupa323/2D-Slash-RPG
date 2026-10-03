-- NPC 가게(사기·팔기) + 소비 아이템 사용 — 서버 권위.
--  사기(ShopBuy): 지금 씬에 그 가게 NPC(shared/config/shops.luau의 npc)가 있고 서버가 아는 발 위치가 가까울 때만.
--    가게가 파는 물건인지, 골드가 충분한지, 가방 자리가 있는지 확인한 뒤 골드를 빼고 아이템을 넣는다.
--  팔기(ShopSell): 같은 NPC 거리 조건(어느 가게든). SellPrice가 있는 아이템만(중요 물품 제외), 개수만큼 빼고 골드를 준다.
--  사용(UseItem): 소비 탭의 Heal 아이템(물약) — 체력이 가득하면 쓰지 않고, 아니면 1개 줄이고 회복(어디서나).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local npcTalk = require(ReplicatedStorage.shared.config.npcTalk)
local shops = require(ReplicatedStorage.shared.config.shops)
local items = require(ReplicatedStorage.shared.data.items)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local persistence = require(script.Parent.Parent.services.persistence)
local inventoryService = require(script.Parent.Parent.services.inventoryService)
local currencyService = require(script.Parent.Parent.services.currencyService)
local progressionService = require(script.Parent.Parent.services.progressionService)
local ninjutsuService = require(script.Parent.ninjutsuService)

local NPC_PAD = 24 -- 대화 거리보다 이만큼(도트) 여유(복제 지연 보정)
local MAX_BUY = 99

local exports = {}

-- 지금 씬에서 그 역할(npcType, nil이면 가게 NPC 아무나) 근처에 있는가
local function nearShopNpc(player: Player, npcType: string?): boolean
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	local d = key and townWorld.Get(key)
	local position = heroTracking.GetPosition(player.UserId)
	if not d or not position then
		return false
	end
	local feet = position / townWorld.data.scale
	for _, n in d.npcs do
		local isShop = false
		for _, shop in shops do
			if shop.npc == n.type then
				isShop = true
			end
		end
		if (if npcType then n.type == npcType else isShop)
			and (Vector2.new(n.x, n.y) - feet).Magnitude <= npcTalk.RANGE + NPC_PAD
		then
			return true
		end
	end
	return false
end

function exports.load()
	Net.OnServer("ShopBuy", function(player: Player, shopId: string, itemId: string, count: number)
		local shop = shops[shopId]
		local def = items[itemId]
		local data = persistence.Get(player)
		if not shop or not def or not def.Price or not data or not table.find(shop.goods, itemId) then
			return
		end
		count = math.clamp(math.floor(count), 1, MAX_BUY)
		if not nearShopNpc(player, shop.npc) then
			return
		end
		local cost = def.Price * count
		if data.Gold < cost then
			Net.FireClient("Notify", player, "골드가 모자라요")
			return
		end
		if inventoryService.RoomFor(player, itemId) < count then
			Net.FireClient("Notify", player, "가방에 자리가 없어요")
			return
		end
		currencyService.AddGold(player, -cost)
		inventoryService.AddItem(player, itemId, count)
	end)

	Net.OnServer("ShopSell", function(player: Player, tab: string, slot: number, count: number)
		if slot ~= math.floor(slot) or not nearShopNpc(player, nil) then
			return
		end
		local data = persistence.Get(player)
		local entry = data and inventoryService.FindEntry(data.Inventory, tab, slot)
		local def = entry and items[entry.ItemId]
		if not def or not def.SellPrice or def.NoDrop then
			return
		end
		local removed = inventoryService.Remove(player, tab, slot, math.clamp(math.floor(count), 1, entry.Count))
		if removed then
			currencyService.AddGold(player, def.SellPrice * removed.Count)
		end
	end)

	Net.OnServer("UseItem", function(player: Player, tab: string, slot: number)
		if slot ~= math.floor(slot) then
			return
		end
		local data = persistence.Get(player)
		local entry = data and inventoryService.FindEntry(data.Inventory, tab, slot)
		local def = entry and items[entry.ItemId]
		if def and def.Type == "Scroll" then
			-- 인술 두루마리: 자기 유파 것이고 올릴 인술이 있을 때만 1개 줄인다
			if ninjutsuService.UseScroll(player, def) then
				inventoryService.Remove(player, tab, slot, 1)
			end
			return
		end
		if not def or not def.Heal then
			return
		end
		if progressionService.Heal(player, def.Heal) <= 0 then
			Net.FireClient("Notify", player, "체력이 이미 가득해요")
			return
		end
		inventoryService.Remove(player, tab, slot, 1)
	end)
end

function exports.start() end
function exports.unload() end

return exports
