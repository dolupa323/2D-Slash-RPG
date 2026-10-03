-- 드롭 서비스: 몬스터 드롭 표(shared/data/lootTables.luau)를 굴려서 골드/아이템을 플레이어에게 준다.
local currencyService = require(script.Parent.currencyService)
local inventoryService = require(script.Parent.inventoryService)

local exports = {}

-- 드롭 표(shared/data/lootTables.luau의 한 몬스터 항목)를 굴려서 플레이어에게 준다.
function exports.RollLoot(player: Player, lootTable)
	for _, drop in lootTable do
		if math.random() < drop.Chance then
			local amount = math.random(drop.Min, drop.Max)
			if drop.ItemId == "Gold" then
				currencyService.AddGold(player, amount)
			else
				inventoryService.AddItem(player, drop.ItemId, amount)
			end
		end
	end
end

return exports
