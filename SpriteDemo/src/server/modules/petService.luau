-- 펫(잡은 몬스터) 상자·파티(서버) — GAME_DESIGN §5. 저장 형태는 shared/config/pets.luau 맨 위 설명.
--  PetAction(행동, 상자 번호):
--   Add     — 함께 다니기(파티 끝에). 칸 수 = pets.SlotCount(레벨, 유료 칸)
--   Remove  — 상자로(파티에서 뺌)
--   Lead    — 대표로(파티 1번 — 다른 사람에게 보이는 한 마리)
--   Release — 놓아주기: 상자에서 사라진다(보상 없음). 뒤 번호들이 당겨지므로 파티 번호도 맞춘다.
--  바뀌면 PetsUpdated로 { Box, Party, Paid }를 보낸다. (파티 편성은 지금은 어디서나 — 마을 상자에서만 할지는 추후)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local pets = require(ReplicatedStorage.shared.config.pets)
local persistence = require(script.Parent.Parent.services.persistence)

local exports = {}

local function push(player: Player, data)
	persistence.MarkDirty(player)
	Net.FireClient("PetsUpdated", player, data.Pets)
end

function exports.load()
	Net.OnServer("PetAction", function(player: Player, action: string, index: number)
		local data = persistence.Get(player)
		local p = data and data.Pets
		if not p or index ~= math.floor(index) or index < 1 or index > #p.Box then
			return
		end
		local at = table.find(p.Party, index)
		if action == "Add" then
			if at or #p.Party >= pets.SlotCount(data.Level, p.Paid) then
				return
			end
			table.insert(p.Party, index)
		elseif action == "Remove" then
			if not at then
				return
			end
			table.remove(p.Party, at)
		elseif action == "Lead" then
			if at then
				table.remove(p.Party, at)
			elseif #p.Party >= pets.SlotCount(data.Level, p.Paid) then
				table.remove(p.Party) -- 칸이 꽉 찼으면 맨 끝을 상자로
			end
			table.insert(p.Party, 1, index)
		elseif action == "Release" then
			table.remove(p.Box, index)
			local party = {}
			for _, i in p.Party do
				if i ~= index then
					table.insert(party, if i > index then i - 1 else i)
				end
			end
			p.Party = party
			task.spawn(persistence.Save, player, false)
		end
		push(player, data)
	end)
end

function exports.start() end
function exports.unload() end

return exports
