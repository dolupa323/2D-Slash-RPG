-- 플레이어 데이터 오케스트레이션(서버 모듈 진입점). 실제 일은 server/services의 역할별 서비스가 한다:
--   persistence(저장/로드/세션 락/오토세이브) · playerSchema(저장 형태 + 버전 마이그레이션)
--   progressionService(경험치/레벨/체력/사망) · inventoryService(인벤토리/장비) · currencyService(골드) · lootService(드롭)
-- 이 모듈은 접속/퇴장 생명주기와 클라이언트 요청(Net) 연결만 담당한다. 다른 서버 모듈(몬스터 등)은 필요한 서비스를 직접 require해서 쓴다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)

local persistence = require(script.Parent.Parent.services.persistence)
local inventoryService = require(script.Parent.Parent.services.inventoryService)

local exports = {}

function exports.load()
	-- 인자 타입/빈도 검사는 Net이 이미 끝냈다(shared/net/packets.luau의 정의) — 핸들러는 통과한 값만 받는다.
	Net.OnServer("EquipAction", function(player: Player, action, arg)
		if action == "Equip" and typeof(arg) == "number" then
			inventoryService.Equip(player, math.floor(arg))
		elseif action == "Unequip" and typeof(arg) == "string" then
			inventoryService.Unequip(player, arg)
		end
	end)

	Net.OnServer("GetPlayerData", function(player: Player)
		return persistence.Load(player)
	end)

	local function onPlayerAdded(player: Player)
		local data = persistence.Load(player)
		Net.FireClient("InventoryUpdated", player, data.Inventory)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		persistence.Release(player)
	end)

	-- main.server.luau가 모듈을 load()하는 시점과 PlayerAdded가 먼저 fire되는 시점이 Studio 테스트 환경에 따라 어긋날 수
	-- 있어서, 이미 접속해 있는 플레이어도 처리한다.
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(persistence.SaveAll)
	persistence.StartAutosave()
end

function exports.start() end

function exports.unload()
	persistence.StopAutosave()
	persistence.SaveAll()
end

return exports
