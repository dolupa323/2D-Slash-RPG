-- 탑다운 씬의 NPC — 공방 맵 탭에서 "NPC" 팔레트로 놓은 자리에 서 있다(대기 2장, 정면).
-- 그림: townAssets.NPCS 시트(공방 js/npc.js) — 역할마다 한 줄, 크기는 플레이어와 같은 캐릭터 배율.
-- 길 막기: NPC 발 상자는 공방 buildGrid가 충돌 격자에 이미 넣어서 내보낸다(여기서 따로 안 함).
--
-- 상호작용: 플레이어가 가까이(npcTalk.RANGE) 가면 NPC 머리 위에 "E 대화"(터치 기기는 "대화") 말풍선이 뜨고,
-- "Interact" 액션(PC E·스페이스 키, HUD "대화" 버튼)을 누르면 화면 아래에 대화창이 열린다.
-- 다시 누르거나 X를 누르거나 멀리 걸어가면 닫힌다. 대사는 shared/config/npcTalk.luau.
-- 본 줄거리 퀘스트를 주거나 끝내는 NPC는 그 대사가 먼저 나온다(globals/quest.luau — 서버 questService가 판정).
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
local ninjutsu = require(script.Parent.Parent.globals.ninjutsu)
local ninjutsuConfig = require(ReplicatedStorage.shared.config.ninjutsu)
local upgrade = require(script.Parent.Parent.globals.upgrade)
local weaponsConfig = require(ReplicatedStorage.shared.config.weapons)
local quest = require(script.Parent.Parent.globals.quest)

local world = map.world
local S = map.S
local CS = townAssets.CHAR_SCALE
local UI_SCALE = 2 -- 말풍선 글씨 배율(그림 배율과 따로)
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
	holder.Size = UDim2.fromOffset(w * UI_SCALE, 16 * UI_SCALE)
	holder.Visible = false
	holder.ZIndex = 5000
	holder.Parent = gameFrame
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.fromOffset(w, 16)
	inner.Parent = holder
	local scale = Instance.new("UIScale")
	scale.Scale = UI_SCALE
	scale.Parent = inner
	local pill = UI.Pill(inner, 0, 0, w, 16, true)
	pill.ZIndex = 5000
	UI.Label(pill, text, 5, 2, { Color = C.white, ZIndex = 5001 })
	return holder
end

-- 화면 아래 대화창
local function openTalk(n, say: string?)
	exports.closeTalk()
	local line = say or npcTalk.LINES[n.type] or npcTalk.DEFAULT
	if type(line) == "table" then -- 여러 마디 중 하나
		line = line[math.random(1, #line)]
	end
	-- 팩 대화 상자(Ui/Dialog/DialogBoxFaceset 300x58): 왼쪽 위 갈색 이름표 + 왼쪽 얼굴 그림(38x38) + 오른쪽 글.
	-- 대화창을 누르거나 상호작용 키를 다시 누르면 닫힌다. 글이 길면 줄바꿈(\n)으로 두 줄까지.
	local size = UI.Size("dialog_face")
	local gui = Instance.new("ScreenGui")
	gui.Name = "NpcTalk"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, 0)
	box.Size = UDim2.fromOffset(size.X + 12, size.Y + 6 + 40) -- 아래 HUD(단축칸) 위로 띄운다
	box.Parent = gui
	UI.Scale(box)
	local panel = UI.Part(box, "dialog_face", 6, 0, nil, nil, "ImageButton")
	panel.AutoButtonColor = false
	panel.Activated:Connect(function()
		if exports.talk and not exports.talk.advance() then
			exports.closeTalk()
		end
	end)
	if UI.Has("face_" .. n.type) then
		UI.Part(panel, "face_" .. n.type, 5, 15).ZIndex = 4
	end
	UI.Label(panel, n.name, 12, 0, { Color = C.paper, ZIndex = 8, MaxWidth = 58, MaxLines = 1 }) -- 이름표(갈색 판) 폭 안에서
	-- 글: 얼굴 그림 오른쪽 칸(폭 TEXT_W) 안에서 줄을 바꾸고, 두 줄씩 한 쪽 — 누르거나 상호작용 키로 다음 쪽, 마지막 쪽에서 닫힌다
	local TEXT_W = size.X - 50 - 8
	local pages = {}
	do
		local lines = string.split(UI.Text.Wrap(line, TEXT_W), "\n")
		for i = 1, #lines, 2 do
			table.insert(pages, table.concat({ lines[i], lines[i + 1] }, "\n"))
		end
	end
	local page = 1
	local textLabel = UI.Label(panel, pages[1], 50, 17, { Color = C.ink, ZIndex = 8, MaxWidth = TEXT_W, MaxLines = 2 })
	local pageLabel = UI.Label(panel, "", size.X - 34, 43, { Color = C.accentD, ZIndex = 8, Clamp = false })
	local function showPage()
		textLabel:SetText(pages[page])
		pageLabel:SetText(if #pages > 1 then ("%d/%d"):format(page, #pages) else "")
	end
	showPage()
	-- 다음 쪽이 있으면 넘기고 true, 마지막 쪽이면 false(닫을 차례)
	local function advance(): boolean
		if page < #pages then
			page += 1
			showPage()
			return true
		end
		return false
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	exports.talk = { gui = gui, npc = n, advance = advance }
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
		-- 이 NPC에게 받을/끝낼 본 줄거리 퀘스트가 있으면(globals/quest.luau) 그 대사가 가게 · 강화 · 전직 창보다 먼저 나온다
		local questSay = if current and not exports.talk and not exports.shopNpc then quest.Talk(current.type) else nil
		if exports.talk then
			if not exports.talk.advance() then -- 다음 쪽이 없으면 닫는다
				exports.closeTalk()
			end
		elseif exports.shopNpc then
			shop.close() -- 가게 창이 열려 있으면 상호작용 키로 닫기
			exports.shopNpc = nil
		elseif questSay then
			openTalk(current, questSay)
		elseif current and shop.ShopFor(current.type) then
			-- 가게 NPC(포션상 등): 가게 창(구매·판매)을 연다
			exports.shopNpc = current
			shop.open(shop.ShopFor(current.type))
		elseif current and current.type == weaponsConfig.UPGRADE_NPC then
			upgrade.open() -- 대장장이: 무기 강화 창(globals/upgrade.luau)
		elseif current and current.type == ninjutsuConfig.CHANGE_NPC and ninjutsu.ShouldOpenWindow() then
			-- 스승: 전직 창(globals/ninjutsu.luau) — Lv.10이 되기 전의 견습에게는 그냥 말을 건넨다
			ninjutsu.OpenSchoolWindow()
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
