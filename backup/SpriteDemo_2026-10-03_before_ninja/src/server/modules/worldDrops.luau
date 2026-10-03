-- 월드 드랍(땅에 떨어진 아이템) — 서버가 소유하고 같은 씬의 모든 플레이어에게 보여준다(온라인 공유).
--  버리기(DropItem): 가방에서 꺼내(inventoryService.Take) 그 플레이어 발밑에 떨어뜨린다. 중요 물품은 못 버린다.
--  줍기(PickupDrop): 같은 씬 + 서버가 아는 발 위치가 가까울 때만. 먼저 주운 사람이 가져간다. 가방이 모자라면 들어간 만큼만.
--  수명: balance.WORLD_DROP_LIFETIME초가 지나면 사라진다.
-- 클라이언트에는 씬 키를 붙여 보낸다(WorldDropSpawned / WorldDropRemoved) — 목록은 townMonsters의 GetTownState가 같이 준다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local balance = require(ReplicatedStorage.shared.config.balance)
local items = require(ReplicatedStorage.shared.data.items)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local heroTracking = require(script.Parent.heroTracking)
local inventoryService = require(script.Parent.Parent.services.inventoryService)

local exports = {}

local drops = {} -- 씬 키 -> { [id] = { id, itemId, count, x, y, expiresAt } }
local nextId = 0

local function toScene(key: string, name: string, ...)
	for _, player in heroTracking.PlayersInScene(townWorld.SceneName(key)) do
		Net.FireClient(name, player, key, ...)
	end
end

local function wire(drop)
	return { id = drop.id, itemId = drop.itemId, count = drop.count, x = drop.x, y = drop.y, expiresIn = math.max(0, drop.expiresAt - os.clock()) }
end

-- 그 씬의 드랍 목록(씬에 막 들어온 플레이어용)
function exports.List(key: string)
	local list = {}
	for _, drop in drops[key] or {} do
		table.insert(list, wire(drop))
	end
	return list
end

-- 아이템을 땅에 떨어뜨린다(버리기, 나중에 몬스터 드롭도 여기로)
function exports.Spawn(key: string, itemId: string, count: number, x: number, y: number)
	if not items[itemId] or count <= 0 then
		return nil
	end
	nextId += 1
	local drop = { id = nextId, itemId = itemId, count = count, x = x, y = y, expiresAt = os.clock() + balance.WORLD_DROP_LIFETIME }
	drops[key] = drops[key] or {}
	drops[key][drop.id] = drop
	toScene(key, "WorldDropSpawned", wire(drop))
	return drop
end

local function remove(key: string, id: number, pickedBy: number?)
	if drops[key] and drops[key][id] then
		drops[key][id] = nil
		toScene(key, "WorldDropRemoved", id, pickedBy)
	end
end

local function sceneAndFeet(player: Player)
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	local position = heroTracking.GetPosition(player.UserId)
	if not key or not position then
		return nil, nil
	end
	return key, position / townWorld.data.scale
end

function exports.load()
	Net.OnServer("DropItem", function(player: Player, tab: string, slot: number)
		local key, feet = sceneAndFeet(player)
		if not key or slot ~= math.floor(slot) then
			return
		end
		local taken = inventoryService.Take(player, tab, slot)
		if not taken then
			return
		end
		-- 발밑 근처에 살짝 흩어서(여러 개를 버려도 겹치지 않게)
		local x = feet.X + math.random(-6, 6)
		local y = feet.Y + math.random(1, 5)
		exports.Spawn(key, taken.ItemId, taken.Count, x, y)
	end)

	Net.OnServer("PickupDrop", function(player: Player, id: number)
		local key, feet = sceneAndFeet(player)
		local drop = key and drops[key] and drops[key][id]
		if not drop then
			return
		end
		if (Vector2.new(drop.x, drop.y) - feet).Magnitude > balance.PICKUP_RANGE + balance.PICKUP_PAD then
			return
		end
		local added = inventoryService.AddItem(player, drop.itemId, drop.count)
		if added <= 0 then
			Net.FireClient("Notify", player, "가방에 자리가 없어요")
			return
		end
		drop.count -= added
		if drop.count <= 0 then
			remove(key, id, player.UserId)
		else
			toScene(key, "WorldDropSpawned", wire(drop)) -- 남은 개수로 갱신
			Net.FireClient("Notify", player, "가방이 가득 차서 일부만 주웠어요")
		end
	end)

	-- 수명이 다한 드랍 정리(1초마다)
	exports.running = true
	task.spawn(function()
		while exports.running do
			task.wait(1)
			local now = os.clock()
			for key, list in drops do
				for id, drop in list do
					if drop.expiresAt <= now then
						remove(key, id, nil)
					end
				end
			end
		end
	end)
end

function exports.start() end
function exports.unload()
	exports.running = false
end

return exports
