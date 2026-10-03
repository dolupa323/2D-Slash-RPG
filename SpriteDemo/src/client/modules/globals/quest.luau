-- 본 줄거리 퀘스트(화면 쪽) — 규칙 shared/config/quests.luau, 판정은 서버 questService.
--  오른쪽 위(엽전 아래) 추적창: 퀘스트 이름 + 지금 할 일 한 줄("말랑이 3/5" · "스승에게 돌아가기" …). 다 끝내면 사라진다.
--  NPC에게 말을 걸 때 town/npcs.luau가 Talk(npc 키)를 먼저 부른다 — 받을/끝낼 퀘스트가 있으면 그 대사를 돌려주고 서버에 알린다.
--  데이터: 처음 GetPlayerData의 Quest + 서버 QuestUpdated(번호, 받았는가, 진행, 방금 끝낸 id).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local Net = require(ReplicatedStorage.shared.net.net)
local quests = require(ReplicatedStorage.shared.config.quests)
local UI = require(script.Parent.Parent.ui.pixelUI)
local inventory = require(script.Parent.inventory)
local ninjutsu = require(script.Parent.ninjutsu)
local notify = require(script.Parent.notify)

local C = UI.colors
local MARGIN = 6
local TOP = 38 -- 엽전 패널(높이 28) 아래
local W, H = 172, 42
local TEXT_W = W - 20
local REFRESH = 0.4 -- 레벨 · 가방이 바뀌어도 따라가게 이 간격(초)으로 다시 쓴다

local exports = {}
exports.index = 1
exports.accepted = false
exports.progress = 0

local function level(): number
	local character = CrossPlatformService.Character
	return character and character.Level or 1
end

local function have(itemId: string): number
	local n = 0
	for _, entry in inventory.getInventory() or {} do
		if entry.ItemId == itemId then
			n += entry.Count
		end
	end
	return n
end

local function ready(q): boolean
	return quests.Ready(q, exports.progress, if q.kind == "collect" then have(q.target) else 0, ninjutsu.job)
end

local function redraw()
	local q = quests.Get(exports.index)
	if not exports.box then
		return
	end
	exports.box.Visible = q ~= nil
	if not q then
		return
	end
	local line = quests.Objective(q, exports.accepted, exports.progress, if q.kind == "collect" then have(q.target) else 0, ninjutsu.job, level())
	exports.title:SetText(q.title)
	exports.line:SetText(line)
end

-- NPC에게 말을 걸었다: 이 NPC에게 받을/끝낼 퀘스트가 있으면 서버에 알리고 대사를 돌려준다(없으면 nil — 평소대로)
function exports.Talk(npcType: string): string?
	local q = quests.Get(exports.index)
	if not q then
		return nil
	end
	if not exports.accepted then
		if npcType ~= q.giver or level() < q.level then
			return nil
		end
		Net.FireServer("QuestTalk", npcType)
		return if quests.Instant(q) then q.done else q.offer
	end
	if quests.TurnIn(q) ~= npcType or not ready(q) then
		return nil
	end
	Net.FireServer("QuestTalk", npcType)
	return q.done
end

local function apply(index: number, accepted: boolean, progress: number, doneId: string?)
	exports.index, exports.accepted, exports.progress = index, accepted, progress
	if doneId then
		for _, q in quests.LIST do
			if q.id == doneId then
				notify.Toast("퀘스트 완료 · " .. q.title, "book")
				if quests.TurnIn(q) == nil then
					notify.Toast(q.done) -- 가기 · 탈것: 닿았을 때의 글
				end
				local parts = {}
				if q.exp > 0 then
					table.insert(parts, ("경험치 +%d"):format(q.exp))
				end
				if q.gold > 0 then
					table.insert(parts, ("엽전 +%d"):format(q.gold))
				end
				if #parts > 0 then
					notify.Toast(table.concat(parts, " · "))
				end
				break
			end
		end
	end
	redraw()
end

function exports.load(scene: Scene)
	if exports.screenGui then
		return
	end
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Quest"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 1
	local box = Instance.new("Frame")
	box.Name = "Tracker"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(1, 0)
	box.Position = UDim2.new(1, 0, 0, 0)
	box.Size = UDim2.fromOffset(W + MARGIN * 2, TOP + H)
	box.Visible = false
	box.Parent = screenGui
	UI.Scale(box)
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(MARGIN, TOP)
	inner.Size = UDim2.fromOffset(W, H)
	inner.Parent = box
	UI.Panel(inner, 0, 0, W, H)
	exports.title = UI.Label(inner, "", 10, 8, { Color = C.accentD, MaxWidth = TEXT_W, MaxLines = 1 })
	exports.line = UI.Label(inner, "", 10, 22, { Color = C.ink, MaxWidth = TEXT_W, MaxLines = 1 })
	exports.box = box
	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	exports.screenGui = screenGui

	Net.OnClient("QuestUpdated", apply)
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock >= REFRESH then
			clock = 0
			redraw()
		end
	end)
	task.spawn(function()
		local ok, data = pcall(Net.Invoke, "GetPlayerData")
		if ok and typeof(data) == "table" and typeof(data.Quest) == "table" then
			apply(data.Quest.Index or 1, data.Quest.Accepted == true, data.Quest.Progress or 0)
		else
			redraw()
		end
	end)
end

function exports.start(scene: Scene) end
function exports.unload(scene: Scene) end

return exports
