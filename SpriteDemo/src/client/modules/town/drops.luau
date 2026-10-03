-- 탑다운 씬의 월드 드랍(땅에 떨어진 아이템) — 서버(server/modules/worldDrops.luau)가 소유하고 같은 씬 모두에게 보인다.
--  그림: 아이템 아이콘이 발밑 그림자 위에서 살짝 둥실거린다. 사라지기 10초 전부터 깜빡인다.
--  줍기: 가까이(balance.PICKUP_RANGE) 가면 위에 "E 줍기"(터치 기기는 "줍기")가 뜨고, 상호작용(E·스페이스·HUD "대화")을
--  누르면 서버에 줍기 요청 — 서버가 거리·가방 자리를 확인하고 먼저 주운 사람이 가져간다. NPC보다 줍기가 먼저다(npcs.luau).
-- 목록은 monsters.luau가 GetTownState로 받아 ApplyList로 넘겨준다. 이벤트 첫 인자는 씬 키(다른 씬 것은 버린다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Net = require(ReplicatedStorage.shared.net.net)
local UpsideEngine = require(ReplicatedStorage:WaitForChild("packages"):WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local balance = require(ReplicatedStorage.shared.config.balance)
local items = require(ReplicatedStorage.shared.data.items)
local townAssets = require(ReplicatedStorage.shared.config.townAssets)
local map = require(script.Parent.map)
local UI = require(script.Parent.Parent.ui.pixelUI)

local S = map.S
local CS = 2 -- 아이콘·말풍선 배율(UI 크기 — 캐릭터 그림 배율과 따로, townAssets.CHAR_SCALE를 쓰지 않는다)
local C = UI.colors
local BLINK_BEFORE = 10

local exports = {}
local byId = {}

local function heroPos(): Vector2?
	return require(script.Parent.Parent.topDownHero).pos
end

-- 씬 화면은 ZIndex 전역 정렬 — 드랍 그림 전체를 발 높이 순서(map.ZIndexFor)에 맞춘다
local function setZ(root: GuiObject, z: number)
	root.ZIndex = z
	for _, g in root:GetDescendants() do
		if g:IsA("GuiObject") then
			g.ZIndex = z + 1
		end
	end
end

local function create(w)
	local def = items[w.itemId]
	if not def or not exports.gameFrame then
		return
	end
	local old = byId[w.id]
	if old then
		old.holder:Destroy()
	end
	local holder = Instance.new("Frame")
	holder.Name = "Drop_" .. w.id
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Size = UDim2.fromOffset(16 * CS, 20 * CS)
	holder.Position = UDim2.fromOffset(w.x * S, w.y * S)
	holder.Parent = exports.gameFrame
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.fromOffset(16, 20)
	inner.Parent = holder
	local scale = Instance.new("UIScale")
	scale.Scale = CS
	scale.Parent = inner
	-- 그림자
	local shadow = Instance.new("Frame")
	shadow.BackgroundColor3 = Color3.fromRGB(79, 107, 63)
	shadow.BackgroundTransparency = 0.7
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(3, 17)
	shadow.Size = UDim2.fromOffset(10, 3)
	shadow.Parent = inner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = shadow
	-- 아이콘(둥실)
	local bob = Instance.new("Frame")
	bob.BackgroundTransparency = 1
	bob.Size = UDim2.fromOffset(16, 16)
	bob.Parent = inner
	local inventory = require(script.Parent.Parent.globals.inventory)
	inventory.DrawItem(bob, def, 2, 2, 12)
	if w.count > 1 then
		UI.Label(bob, tostring(w.count), 10, 8, { Color = C.white, Shadow = C.ink })
	end
	setZ(holder, map.ZIndexFor(w.y))
	byId[w.id] = { id = w.id, holder = holder, bob = bob, pos = Vector2.new(w.x, w.y), expiresAt = os.clock() + w.expiresIn, clock = math.random() * 2 }
end

local function removeDrop(id: number, pickedByMe: boolean)
	local d = byId[id]
	if not d then
		return
	end
	byId[id] = nil
	if pickedByMe then
		-- 주우면 위로 톡 튀었다 사라짐
		local holder = d.holder
		task.spawn(function()
			for i = 1, 6 do
				if not holder.Parent then
					return
				end
				holder.Position -= UDim2.fromOffset(0, 3 * CS)
				holder.Visible = i % 2 == 1
				task.wait(0.04)
			end
			holder:Destroy()
		end)
	else
		d.holder:Destroy()
	end
end

-- GetTownState의 drops 목록(씬에 들어왔을 때)
function exports.ApplyList(key: string, list)
	if exports.key == nil then
		exports.pending = { key = key, list = list } -- 이 모듈 load가 아직이면 load 때 적용(씬 모듈 load 순서는 정해져 있지 않다)
		return
	end
	if key ~= exports.key then
		return
	end
	for _, w in list or {} do
		create(w)
	end
end

-- 가장 가까운(줍기 거리 안) 드랍
local function nearest(): any
	local pos = heroPos()
	if not pos then
		return nil
	end
	local best, bestDist = nil, balance.PICKUP_RANGE
	for _, d in byId do
		local dist = (d.pos - pos).Magnitude
		if dist <= bestDist then
			best, bestDist = d, dist
		end
	end
	return best
end

-- 줍기 거리 안에 드랍이 있는가(npcs.luau가 상호작용 키를 양보할지 볼 때)
function exports.HasNearby(): boolean
	return nearest() ~= nil
end

function exports.load(scene: Scene)
	local d = map.Use(scene)
	if not d then
		return
	end
	exports.key = map.key
	exports.gameFrame = scene.Instance.GameFrame
	local myId = game:GetService("Players").LocalPlayer.UserId
	local conns = {}
	exports.conns = conns
	table.insert(conns, Net.OnClient("WorldDropSpawned", function(key, w)
		if key == exports.key then
			create(w)
		end
	end))
	table.insert(conns, Net.OnClient("WorldDropRemoved", function(key, id, pickedBy)
		if key == exports.key then
			removeDrop(id, pickedBy == myId)
		end
	end))

	-- "E 줍기" 말풍선
	local text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "줍기" else "E 줍기"
	local w = UI.Text.Measure(text, "body") + 10
	local prompt = Instance.new("Frame")
	prompt.Name = "PickupPrompt"
	prompt.BackgroundTransparency = 1
	prompt.AnchorPoint = Vector2.new(0.5, 1)
	prompt.Size = UDim2.fromOffset(w * CS, 16 * CS)
	prompt.Visible = false
	prompt.Parent = exports.gameFrame
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.fromOffset(w, 16)
	inner.Parent = prompt
	local scale = Instance.new("UIScale")
	scale.Scale = CS
	scale.Parent = inner
	local pill = UI.Pill(inner, 0, 0, w, 16, true)
	UI.Label(pill, text, 5, 2, { Color = C.white, ZIndex = 9101 })
	setZ(prompt, 9100)
	exports.prompt = prompt

	-- 상호작용 키(E·스페이스·HUD "대화"): 가까운 드랍 줍기 요청(NPC보다 먼저)
	exports.inputConnection = CrossPlatformService:On("InputBegin", function(input)
		local action = input.Action and input.Action:lower()
		local near = action == "interact" and nearest()
		if near then
			Net.FireServer("PickupDrop", near.id)
		end
	end)

	local pending = exports.pending
	exports.pending = nil
	if pending then
		exports.ApplyList(pending.key, pending.list)
	end

	exports.connection = RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, drop in byId do
			drop.clock += dt
			drop.bob.Position = UDim2.fromOffset(0, math.floor(math.sin(drop.clock * 3) * 1.5 + 0.5))
			local left = drop.expiresAt - now
			drop.holder.Visible = left > BLINK_BEFORE or math.floor(left * 4) % 2 == 0
		end
		local near = nearest()
		prompt.Visible = near ~= nil
		if near then
			prompt.Position = UDim2.fromOffset(near.pos.X * S, near.pos.Y * S - 18 * CS)
		end
	end)
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	if exports.connection then
		exports.connection:Disconnect()
		exports.connection = nil
	end
	for _, c in exports.conns or {} do
		c:Disconnect()
	end
	exports.conns = nil
	if exports.inputConnection then
		exports.inputConnection:Disconnect()
		exports.inputConnection = nil
	end
	exports.pending = nil
	for id in byId do
		removeDrop(id, false)
	end
	if exports.prompt then
		exports.prompt:Destroy()
		exports.prompt = nil
	end
	exports.key = nil
	exports.gameFrame = nil
end

return exports
