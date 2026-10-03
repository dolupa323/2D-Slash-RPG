-- 소비 단축칸 1·2·3(서버) — GAME_DESIGN §3. 가방에서 소비 아이템(방울·물약)을 칸에 놓고, 숫자키/터치로 바로 쓴다.
--  SetQuickSlot(칸, 아이템 id | ""): 소비("Use" 탭) 아이템만. 같은 아이템이 다른 칸에 있으면 그 칸은 비운다.
--  UseQuickSlot(칸, 바라보는 방향): 투척 무기 → townMonsters.ThrowWeapon(그 방향 직선으로 던져 피해) /
--   방울 → townMonsters.ThrowBell(포획 — 지금은 꺼 둠) / 음식·물약 → 체력 회복.
--  저장: data.QuickSlots = { id1, id2, id3 } (playerSchema v6). 바뀌면 QuickSlotsUpdated로 알린다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local items = require(ReplicatedStorage.shared.data.items)
local persistence = require(script.Parent.Parent.services.persistence)
local inventoryService = require(script.Parent.Parent.services.inventoryService)
local progressionService = require(script.Parent.Parent.services.progressionService)
local townMonsters = require(script.Parent.townMonsters)

local SLOTS = 3

local exports = {}

local function slotsOf(data)
	data.QuickSlots = data.QuickSlots or { "", "", "" }
	return data.QuickSlots
end

function exports.load()
	Net.OnServer("SetQuickSlot", function(player: Player, index: number, itemId: string)
		local data = persistence.Get(player)
		if not data or index ~= math.floor(index) or index < 1 or index > SLOTS then
			return
		end
		local def = items[itemId]
		if itemId ~= "" and (not def or def.Tab ~= "Use") then
			return
		end
		local slots = slotsOf(data)
		for i = 1, SLOTS do
			if itemId ~= "" and slots[i] == itemId then
				slots[i] = ""
			end
		end
		slots[index] = itemId
		persistence.MarkDirty(player)
		Net.FireClient("QuickSlotsUpdated", player, slots)
	end)

	Net.OnServer("UseQuickSlot", function(player: Player, index: number, facing: string)
		local data = persistence.Get(player)
		if not data or index ~= math.floor(index) or index < 1 or index > SLOTS then
			return
		end
		local itemId = slotsOf(data)[index]
		local def = itemId and items[itemId]
		if not def then
			return
		end
		if inventoryService.CountItem(player, itemId) <= 0 then
			Net.FireClient("Notify", player, ("%s이(가) 없어요"):format(def.Name))
			return
		end
		if def.Type == "Throw" then
			townMonsters.ThrowWeapon(player, itemId, facing) -- 「오문 닌자전」 투척 무기(수리검 · 쿠나이 · 폭탄)
		elseif def.Type == "Bell" then
			townMonsters.ThrowBell(player, itemId, facing)
		elseif def.Heal then
			if progressionService.Heal(player, def.Heal) <= 0 then
				Net.FireClient("Notify", player, "체력이 이미 가득해요")
				return
			end
			inventoryService.TakeItem(player, itemId, 1)
		end
	end)
end

function exports.start() end
function exports.unload() end

return exports
