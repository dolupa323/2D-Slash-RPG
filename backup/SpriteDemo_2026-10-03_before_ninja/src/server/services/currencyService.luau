-- 재화(골드) 서비스.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local balance = require(ReplicatedStorage.shared.config.balance)
local Net = require(ReplicatedStorage.shared.net.net)
local persistence = require(script.Parent.persistence)

local exports = {}

function exports.AddGold(player: Player, amount: number)
	local data = persistence.Get(player)
	if not data or amount == 0 then
		return
	end
	data.Gold = math.max(data.Gold + amount, 0)
	persistence.MarkDirty(player)
	Net.FireClient("GoldUpdated", player, data.Gold)
	if amount > 0 then
		Net.FireClient("ItemAcquired", player, "Gold", amount)
	end
end

return exports
