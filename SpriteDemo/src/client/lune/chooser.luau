-- 직업 고르기 — 처음 온 사람에게 한 번 나온다. 달 아래 다섯 영웅이 나란히 서 있고, 하나를 고르면 그 영웅의 달 · 무기 · 싸우는 법이 뜬다.
--  ← → 로 고르고 Space(또는 Enter)로 정한다. 눌러서(터치) 고를 수도 있다 — 고른 영웅을 한 번 더 누르면 정해진다.
--  자료는 shared/lune/data/classes.generated.luau(공방의 전직 설계와 줄거리에서 내보낸 것). 글씨는 제 칸을 넘지 않게 폭을 준다.
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lune = ReplicatedStorage.shared.lune
local G = require(lune.config.game)
local CLASSES = require(lune.data["classes.generated"])
local COMBAT = require(lune.data["combat.generated"])
local SCENES = require(lune.data["scenes.generated"])
local ASSETS = require(lune.data["assets.generated"])
local Stage = require(script.Parent.stage)
local Sprite = require(script.Parent.sprite)
local pixelText = require(script.Parent.Parent.modules.ui.pixelText)

local INK = Color3.fromRGB(18, 22, 28)
local WHITE = Color3.fromRGB(238, 246, 246)
local Kit = require(script.Parent.ui.kit)
local GRAY = Color3.fromRGB(138, 143, 150)
local MINT = Color3.fromRGB(62, 255, 215)
local PINK = Color3.fromRGB(255, 62, 159)

local GROUND_Y = 124 -- 영웅들이 서는 높이
local GAP = 70 -- 영웅 사이의 간격(이름이 겹치지 않을 만큼)
local PANEL = { x = 24, y = 142, w = 336, h = 52 }

local Chooser = {}

-- 글을 (cx, y)에 가운데 맞춰 놓는다
local function center(label, cx: number, y: number)
	label.Frame.Position = UDim2.fromOffset(math.floor(cx - label.Width / 2 + 0.5), y)
end

-- 직업을 고를 때까지 기다렸다가 고른 직업의 이름을 돌려준다
function Chooser.run(): string
	local root = Stage.group(Stage.view, "Chooser", 200)
	root.BackgroundTransparency = 0
	local town = SCENES.scenes[SCENES.start]
	root.BackgroundColor3 = Color3.fromRGB(tonumber(town.sky:sub(2, 3), 16), tonumber(town.sky:sub(4, 5), 16), tonumber(town.sky:sub(6, 7), 16))
	-- 달이 뜬 하늘과 먼 산(마을과 같은 그림)
	for i, l in town.layers do
		if i <= 2 then
			local img = Stage.image(root, "Layer" .. i, ASSETS[l.img] or "", l.w, l.h)
			img.Position = UDim2.fromOffset(0, l.y)
		end
	end
	-- 서 있는 바닥
	local floor = Instance.new("Frame")
	floor.Position = UDim2.fromOffset(0, GROUND_Y)
	floor.Size = UDim2.fromOffset(G.VIEW_W, G.VIEW_H - GROUND_Y)
	floor.BackgroundColor3 = INK
	floor.BorderSizePixel = 0
	floor.ZIndex = 3
	floor.Parent = root

	local title = pixelText.new(root, { Text = "달이 고른 자 — 누구의 뒤를 이을 것인가", Font = "body", Color = WHITE, Shadow = INK, Align = "center", MaxWidth = G.VIEW_W - 16, MaxLines = 1 })
	center(title, G.VIEW_W / 2, 8)
	title.Frame.ZIndex = 6

	local order = CLASSES.order
	local n = #order
	local x0 = G.VIEW_W / 2 - GAP * (n - 1) / 2
	local slots = {}
	for i, id in order do
		local c = CLASSES.classes[id]
		local x = x0 + (i - 1) * GAP
		local sprite = Sprite.new(root, id, 5)
		local name = pixelText.new(root, { Text = c.name, Font = "body", Color = WHITE, Shadow = INK, Align = "center", MaxWidth = GAP, MaxLines = 1 })
		center(name, x, GROUND_Y + 3)
		name.Frame.ZIndex = 6
		-- 눌러서 고르는 자리(보이지 않는 단추)
		local button = Instance.new("TextButton")
		button.Name = "Pick_" .. id
		button.Text = ""
		button.BackgroundTransparency = 1
		button.Position = UDim2.fromOffset(math.floor(x - GAP / 2), GROUND_Y - 44)
		button.Size = UDim2.fromOffset(GAP, 62)
		button.ZIndex = 8
		button.Parent = root
		slots[i] = { id = id, class = c, x = x, sprite = sprite, name = name, button = button }
	end

	-- 고른 영웅의 설명
	local panel = Instance.new("Frame")
	panel.Position = UDim2.fromOffset(PANEL.x, PANEL.y)
	panel.Size = UDim2.fromOffset(PANEL.w, PANEL.h)
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.ZIndex = 5
	panel.Parent = root
	local plate = Kit.part(root, "frame", PANEL.x - 3, PANEL.y - 2, PANEL.w + 6, PANEL.h + 4)
	plate.ZIndex = 4
	local head = pixelText.new(panel, { Text = "", Font = "body", Color = MINT, Shadow = INK, MaxWidth = PANEL.w - 12, MaxLines = 1 })
	head.Frame.Position = UDim2.fromOffset(6, 3)
	head.Frame.ZIndex = 6
	local role = pixelText.new(panel, { Text = "", Font = "body", Color = WHITE, MaxWidth = PANEL.w - 12, MaxLines = 3 })
	role.Frame.Position = UDim2.fromOffset(6, 17)
	role.Frame.ZIndex = 6
	local hint = pixelText.new(root, { Text = "← → 고르기 · Space 정하기", Font = "body", Color = GRAY, Align = "center", MaxWidth = G.VIEW_W - 16, MaxLines = 1 })
	center(hint, G.VIEW_W / 2, PANEL.y + PANEL.h + 5)
	hint.Frame.ZIndex = 6

	local picked = math.ceil(n / 2)
	local chosen: string? = nil
	local pickedAt = 0
	local clock = 0

	local function show()
		local slot = slots[picked]
		local c = slot.class
		head:SetColor(if c.tone == "pink" then PINK else MINT)
		head:SetText(("%s의 계승자 · %s · %s"):format(c.hero, c.face, c.weapon))
		role:SetText(c.role)
		for i, s in slots do
			s.name:SetColor(if i == picked then WHITE else GRAY)
		end
		pickedAt = clock
	end
	local function pick(i: number)
		if i == picked then
			chosen = slots[i].id -- 고른 영웅을 한 번 더 누르면 정해진다
		else
			picked = i
			show()
		end
	end
	show()

	local connections = {}
	for i, s in slots do
		table.insert(connections, s.button.Activated:Connect(function()
			pick(i)
		end))
	end
	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.Left then
			picked = (picked - 2) % n + 1
			show()
		elseif key == Enum.KeyCode.Right then
			picked = picked % n + 1
			show()
		elseif key == Enum.KeyCode.Space or key == Enum.KeyCode.Return then
			chosen = slots[picked].id
		end
	end))

	-- 고른 영웅은 사냥기를 한 번씩 써 보이고, 나머지는 서 있다(흐리게)
	local function mobSkill(id: string)
		for _, sk in COMBAT.skills do
			if sk.who == id and sk.type == "mob" then
				return sk
			end
		end
		return nil
	end
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		clock += dt
		for i, s in slots do
			local char = s.sprite.char
			local clip, frame = "idle", Sprite.frameAt(char, "idle", clock + i * 0.2, false)
			if i == picked then
				local sk = mobSkill(s.id)
				local t = (clock - pickedAt) % 3 - 0.8 -- 0.8초 서 있다가 기술을 쓴다
				if sk and t >= 0 then
					for _, seg in sk.segs do
						if t < seg.time then
							clip, frame = seg.clip, seg.from + math.min(seg.to - seg.from, math.floor(t * seg.fps)) + 1
							break
						end
						t -= seg.time
					end
				end
			end
			s.sprite:set(clip, frame, s.x, GROUND_Y, 1)
			s.sprite.label.ImageTransparency = if i == picked then 0 else 0.45
		end
	end))

	while not chosen do
		task.wait()
	end
	for _, c in connections do
		c:Disconnect()
	end
	Chooser.root = root -- 서버의 답을 받을 때까지 화면을 그대로 둔다 — 부른 쪽이 close()로 닫는다
	return chosen :: string
end

function Chooser.close()
	if Chooser.root then
		Chooser.root:Destroy()
		Chooser.root = nil
	end
end

return Chooser
