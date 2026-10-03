-- 본 줄거리 퀘스트(서버 권위) — 규칙은 shared/config/quests.luau, 자료는 공방 설계를 옮긴 shared/data/quests.generated.luau.
--  QuestTalk(npc 키): 그 NPC 곁에서 — 아직 안 받았으면 받고(주는 사람 · 레벨 확인), 받았으면 끝낸다(끝낼 사람 · 목표 확인).
--  처치는 townMonsters.OnKill, 가기는 heroTracking.OnSceneChanged로 센다. 바뀔 때마다 QuestUpdated(번호, 받았는가, 진행, 방금 끝낸 id)를 보낸다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.shared.net.net)
local quests = require(ReplicatedStorage.shared.config.quests)
local npcTalk = require(ReplicatedStorage.shared.config.npcTalk)
local townWorld = require(ReplicatedStorage.shared.data.townWorld)
local persistence = require(script.Parent.Parent.services.persistence)
local progressionService = require(script.Parent.Parent.services.progressionService)
local currencyService = require(script.Parent.Parent.services.currencyService)
local inventoryService = require(script.Parent.Parent.services.inventoryService)
local heroTracking = require(script.Parent.heroTracking)
local townMonsters = require(script.Parent.townMonsters)

local world = townWorld.data
local NPC_PAD = 24 -- 대화 거리보다 이만큼(도트) 여유(복제 지연 보정)

local exports = {}

local function nearNpc(player: Player, npcType: string): boolean
	local key = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
	local d = key and townWorld.Get(key)
	local position = heroTracking.GetPosition(player.UserId)
	if not d or not position then
		return false
	end
	local feet = position / world.scale
	for _, n in d.npcs do
		if n.type == npcType and (Vector2.new(n.x, n.y) - feet).Magnitude <= npcTalk.RANGE + NPC_PAD then
			return true
		end
	end
	return false
end

local function stateOf(data)
	if typeof(data.Quest) ~= "table" then
		data.Quest = { Index = 1, Accepted = false, Progress = 0 }
	end
	return data.Quest
end

local function send(player: Player, s, doneId: string?)
	Net.FireClient("QuestUpdated", player, s.Index, s.Accepted, s.Progress, doneId)
end

-- 보상을 주고 다음 퀘스트로. 보상 아이템이 가방에 안 들어가면 끝내지 않는다(false).
local function complete(player: Player, data, q): boolean
	local s = stateOf(data)
	local itemId = quests.RewardItem(q, data.School)
	local need = if itemId then q.itemCount or 1 else 0
	if itemId and inventoryService.RoomFor(player, itemId) < need then
		Net.FireClient("Notify", player, "가방이 가득 차서 보상을 받을 수 없어요")
		return false
	end
	if q.kind == "collect" and not inventoryService.TakeItem(player, q.target, q.count) then
		return false
	end
	s.Index += 1
	s.Accepted = false
	s.Progress = 0
	persistence.MarkDirty(player)
	if q.gold > 0 then
		currencyService.AddGold(player, q.gold)
	end
	if itemId then
		inventoryService.AddItem(player, itemId, need)
	end
	send(player, s, q.id)
	if q.exp > 0 then
		progressionService.AddExperience(player, q.exp)
	end
	task.spawn(persistence.Save, player, false) -- 줄거리 진행은 잃으면 아프다 — 바로 저장
	return true
end

function exports.Talk(player: Player, npcType: string)
	local data = persistence.Get(player)
	if not data then
		return
	end
	local s = stateOf(data)
	local q = quests.Get(s.Index)
	if not q or not nearNpc(player, npcType) then
		return
	end
	if not s.Accepted then
		if npcType ~= q.giver then
			return
		end
		if data.Level < q.level then
			Net.FireClient("Notify", player, ("Lv.%d부터 받을 수 있어요"):format(q.level))
			return
		end
		s.Accepted = true
		s.Progress = 0
		persistence.MarkDirty(player)
		local here = townWorld.KeyOf(heroTracking.GetPlayerScene(player.UserId))
		if quests.Instant(q) or (q.kind == "reach" and q.scene ~= nil and q.scene == here) then
			if complete(player, data, q) then
				return
			end
		end
		send(player, s)
		return
	end
	if quests.TurnIn(q) ~= npcType then
		return
	end
	local have = if q.kind == "collect" then inventoryService.CountItem(player, q.target) else 0
	if quests.Ready(q, s.Progress, have, data.Job or 0) then
		complete(player, data, q)
	end
end

function exports.load()
	Net.OnServer("QuestTalk", exports.Talk)

	-- 처치: 받은 퀘스트의 몬스터 · 보스면 센다
	townMonsters.OnKill(function(player: Player, speciesId: string)
		local data = persistence.Get(player)
		local s = data and stateOf(data)
		local q = s and s.Accepted and quests.Get(s.Index)
		if q and quests.CountsKill(q, speciesId) and s.Progress < q.count then
			s.Progress += 1
			persistence.MarkDirty(player)
			send(player, s)
		end
	end)

	-- 가기: 받은 퀘스트의 씬에 들어서면 바로 끝난다
	heroTracking.OnSceneChanged(function(userId: number, _previous: string?, sceneName: string)
		local player = Players:GetPlayerByUserId(userId)
		local data = player and persistence.Get(player)
		local s = data and stateOf(data)
		local q = s and s.Accepted and quests.Get(s.Index)
		if q and q.kind == "reach" and q.scene ~= nil and townWorld.KeyOf(sceneName) == q.scene then
			complete(player, data, q)
		end
	end)
end

function exports.start() end
function exports.unload() end

return exports
