-- 탑다운 씬의 NPC — 공방 맵 탭에서 "NPC" 팔레트로 놓은 자리에 서 있다(대기 2장, 정면).
-- 그림: townAssets.NPCS 시트(공방 js/npc.js) — 역할마다 한 줄, 크기는 플레이어와 같은 캐릭터 배율.
-- 길 막기: NPC 발 상자는 공방 buildGrid가 충돌 격자에 이미 넣어서 내보낸다(여기서 따로 안 함).
--
-- 상호작용: 플레이어가 가까이(npcTalk.RANGE) 가면 NPC 머리 위에 "E 대화"(터치 기기는 "대화") 말풍선이 뜨고,
-- "Interact" 액션(PC E·스페이스 키, HUD "대화" 버튼)을 누르면 화면 아래에 대화창이 열린다.
-- 다시 누르거나 X를 누르거나 멀리 걸어가면 닫힌다. 대사는 shared/config/npcTalk.luau.
-- 가게 NPC(shared/config/shops.luau — 포션상)는 말을 걸면 대화창 대신 가게 창(구매·판매, globals/shop.luau)이 열린다.
-- 치료사는 말을 걸면 화면이 잠깐 어두워졌다 밝아지고(그 사이 서버 townRewards가 체력을 가득 채움) 대화창이 열린다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local packages = ReplicatedStorage:WaitForChild("packages")
local UpsideEngine = require(packages:WaitForChild("UpsideEngine"))
local CrossPlatformService = UpsideEngine.GetService("CrossPlatformService")
local townAssets = require(ReplicatedStorage.shared.config.townAssets)
local npcTalk = require(ReplicatedStorage.shared.config.npcTalk)
local Net = require(ReplicatedStorage.shared.net.net)
local map = require(script.Parent.map)
local UI = require(script.Parent.Parent.ui.pixelUI)
local shop = require(script.Parent.Parent.globals.shop)

local world = map.world
local S = map.S
local CS = townAssets.CHAR_SCALE
local SHEET = world.npcSheet
local CELL = Vector2.new(SHEET.cellW, SHEET.cellH)
local IDLE_FRAME_TIME = 0.6
local C = UI.colors

local exports = {}

local function heroPos(): Vector2?
	local hero = require(script.Parent.Parent.topDownHero) -- 늦게 불러서 순환 require를 피한다
	return hero.pos
end

-- 가장 가까운(범위 안) NPC
local function nearest(list, pos: Vector2?)
	if not pos then
		return nil
	end
	local best, bestDist = nil, npcTalk.RANGE
	for _, n in list do
		local dist = (n.pos - pos).Magnitude
		if dist <= bestDist then
			best, bestDist = n, dist
		end
	end
	return best
end

-- 머리 위 말풍선("E 대화") — 월드(GameFrame) 안에 캐릭터 배율로
local function makePrompt(gameFrame: Instance)
	local text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "대화" else "E 대화"
	local w = UI.Text.Measure(text, "body") + 10
	local holder = Instance.new("Frame")
	holder.Name = "NpcPrompt"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Size = UDim2.fromOffset(w * CS, 16 * CS)
	holder.Visible = false
	holder.ZIndex = 5000
	holder.Parent = gameFrame
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.fromOffset(w, 16)
	inner.Parent = holder
	local scale = Instance.new("UIScale")
	scale.Scale = CS
	scale.Parent = inner
	local pill = UI.Pill(inner, 0, 0, w, 16, true)
	pill.ZIndex = 5000
	UI.Label(pill, text, 5, 2, { Color = C.white, ZIndex = 5001 })
	return holder
end

-- 화면 아래 대화창
local function openTalk(n)
	exports.closeTalk()
	local line = npcTalk.LINES[n.type] or npcTalk.DEFAULT
	if type(line) == "table" then -- 여러 마디 중 하나
		line = line[math.random(1, #line)]
	end
	-- 공방 UI 탭 "대화·알림" 아래 대화창 그대로: 440x60 패널, 왼쪽 위 분홍 이름표, 오른쪽 아래 ▼(깜빡임).
	-- 대화창을 누르거나 상호작용 키를 다시 누르면 닫힌다.
	local _, textH = UI.Text.Measure(line, "body")
	local w = 440
	local h = math.max(60, textH + 30)

	local gui = Instance.new("ScreenGui")
	gui.Name = "NpcTalk"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, 0)
	box.Size = UDim2.fromOffset(w + 12, h + 6 + 10)
	box.Parent = gui
	UI.Scale(box)
	local panel = UI.Part(box, "panel", 6, 10, w, h, "ImageButton")
	panel.AutoButtonColor = false
	panel.Activated:Connect(function()
		exports.closeTalk()
	end)
	local nameW = UI.Text.Measure(n.name, "body") + 14
	UI.Pill(panel, 10, -9, nameW, 16)
	UI.Label(panel, n.name, 17, -8, { Color = C.white, ZIndex = 8 })
	UI.Label(panel, line, 12, 14, { Color = C.ink })
	-- ▼
	local arrow = Instance.new("Frame")
	arrow.BackgroundTransparency = 1
	arrow.Position = UDim2.fromOffset(w - 18, h - 16)
	arrow.Size = UDim2.fromOffset(7, 4)
	arrow.Parent = panel
	for i = 0, 3 do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = C.pinkD
		row.BorderSizePixel = 0
		row.Position = UDim2.fromOffset(i, i)
		row.Size = UDim2.fromOffset(7 - i * 2, 1)
		row.ZIndex = 6
		row.Parent = arrow
	end
	task.spawn(function()
		while arrow.Parent do
			arrow.Visible = not arrow.Visible
			task.wait(0.45)
		end
	end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	exports.talk = { gui = gui, npc = n }
end

-- 회복 연출: 검게 0.35초 → (서버에 회복 요청) 잠깐 유지 → 0.35초에 걸쳐 밝아짐
local FADE_TIME = 0.35
local FADE_HOLD = 0.4
local function fadeHeal()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HealFade"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	local black = Instance.new("Frame")
	black.BackgroundColor3 = Color3.fromRGB(20, 14, 30)
	black.BackgroundTransparency = 1
	black.BorderSizePixel = 0
	black.Size = UDim2.fromScale(1, 1)
	black.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local info = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local out = TweenService:Create(black, info, { BackgroundTransparency = 0 })
	out:Play()
	out.Completed:Wait()
	Net.FireServer("RequestHeal")
	task.wait(FADE_HOLD)
	local back = TweenService:Create(black, info, { BackgroundTransparency = 1 })
	back:Play()
	back.Completed:Wait()
	gui:Destroy()
end

function exports.closeTalk()
	if exports.talk then
		exports.talk.gui:Destroy()
		exports.talk = nil
	end
end

function exports.load(scene: Scene)
	local d = map.Use(scene)
	if not d then
		return
	end
	local gameFrame = scene.Instance.GameFrame
	local list = {}
	for i, n in d.npcs or {} do
		local label = Instance.new("ImageLabel")
		label.Name = "Npc_" .. n.type .. "_" .. i
		label.Image = townAssets.NPCS
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.ScaleType = Enum.ScaleType.Stretch
		label.ResampleMode = Enum.ResamplerMode.Pixelated
		label.AnchorPoint = Vector2.new(0.5, SHEET.feetY / SHEET.cellH) -- 발바닥이 위치점
		label.Size = UDim2.fromOffset(CELL.X * CS, CELL.Y * CS)
		label.ImageRectSize = CELL
		label.ImageRectOffset = Vector2.new(0, (n.row - 1) * CELL.Y)
		label.Position = UDim2.fromOffset(n.x * S, n.y * S)
		label.ZIndex = map.ZIndexFor(n.y)
		label.Parent = gameFrame
		table.insert(list, { label = label, row = n.row - 1, type = n.type, name = n.name, pos = Vector2.new(n.x, n.y), clock = (i % 3) * 0.2 })
	end
	exports.list = list
	if #list == 0 then
		return
	end

	local prompt = makePrompt(gameFrame)
	exports.prompt = prompt
	local current = nil

	exports.connection = RunService.Heartbeat:Connect(function(dt)
		for _, n in list do
			n.clock += dt
			local frame = math.floor(n.clock / IDLE_FRAME_TIME) % SHEET.frames
			n.label.ImageRectOffset = Vector2.new(frame * CELL.X, n.row * CELL.Y)
		end
		current = nearest(list, heroPos())
		if current and not exports.talk then
			prompt.Visible = true
			-- 머리 위(발에서 캐릭터 키만큼 위)
			prompt.Position = UDim2.fromOffset(current.pos.X * S, current.pos.Y * S - (SHEET.feetY - 1) * CS)
		else
			prompt.Visible = false
		end
		-- 멀리 걸어가면 대화창·가게 창을 닫는다
		if exports.talk then
			local pos = heroPos()
			if not pos or (exports.talk.npc.pos - pos).Magnitude > npcTalk.RANGE + 12 then
				exports.closeTalk()
			end
		end
		if exports.shopNpc then
			local pos = heroPos()
			if not shop.isOpen() then
				exports.shopNpc = nil
			elseif not pos or (exports.shopNpc.pos - pos).Magnitude > npcTalk.RANGE + 12 then
				shop.close()
				exports.shopNpc = nil
			end
		end
	end)

	exports.inputConnection = CrossPlatformService:On("InputBegin", function(input)
		local action = input.Action and input.Action:lower()
		if action ~= "interact" then
			return
		end
		if exports.healing then
			return
		end
		-- 발밑 가까이 떨어진 아이템이 있으면 줍기가 먼저(drops.luau가 처리)
		if not exports.talk and require(script.Parent.drops).HasNearby() then
			return
		end
		if exports.talk then
			exports.closeTalk()
		elseif exports.shopNpc then
			shop.close() -- 가게 창이 열려 있으면 상호작용 키로 닫기
			exports.shopNpc = nil
		elseif current and shop.ShopFor(current.type) then
			-- 가게 NPC(포션상 등): 가게 창(구매·판매)을 연다
			exports.shopNpc = current
			shop.open(shop.ShopFor(current.type))
		elseif current and current.type == "healer" then
			-- 치료사: 화면이 잠깐 어두워졌다 밝아지는 사이 서버가 체력을 가득 채운다(RequestHeal → PlayerHealthChanged)
			local n = current
			exports.healing = true
			task.spawn(function()
				fadeHeal()
				exports.healing = false
				openTalk(n)
			end)
		elseif current then
			openTalk(current)
		end
	end)
end

function exports.start(scene: Scene) end

function exports.unload(scene: Scene)
	exports.closeTalk()
	exports.shopNpc = nil
	for _, key in { "connection", "inputConnection" } do
		if exports[key] then
			exports[key]:Disconnect()
			exports[key] = nil
		end
	end
	if exports.prompt then
		exports.prompt:Destroy()
		exports.prompt = nil
	end
	for _, n in exports.list or {} do
		n.label:Destroy()
	end
	exports.list = nil
end

return exports
