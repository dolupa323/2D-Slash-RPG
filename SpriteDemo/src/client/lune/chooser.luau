-- 직업 고르기 — 처음 온 사람에게 한 번 나온다. 달 아래 다섯 영웅이 나란히 서 있고, 하나를 고르면 그 영웅의 달 · 무기 · 싸우는 법이 뜬다.
--  ← → 로 고르고 Space(또는 Enter)로 정한다. 눌러서(터치) 고를 수도 있다 — 고른 영웅을 한 번 더 누르면 정해진다.
--  자료는 shared/lune/data/classes.generated.luau(공방의 전직 설계와 줄거리에서 내보낸 것). 글씨는 제 칸을 넘지 않게 폭을 준다.
--  하늘 · 영웅들은 게임 세계의 층에, 글(제목 · 이름 · 설명 판)은 화면 틀의 층(고운 격자)에 그린다 — 늘 보이는 화면과 같은 방식.
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
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR
local INK = Color3.fromRGB(18, 22, 28)
local WHITE, GRAY, MINT, PINK = C.text, C.dim, C.accent, C.pink

local GROUND_Y = 124 -- 영웅들이 서는 높이(게임의 도트)
local GAP = 70 -- 영웅 사이의 간격(게임의 도트 — 이름이 겹치지 않을 만큼)
local PANEL = { w = 520, h = 86, up = 44 } -- 설명 판(화면 틀의 점): 아래 가운데에, 화면 아래에서 up만큼 위

local Chooser = {}

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

	-- 글의 층(화면 틀): 제목 · 영웅의 이름 · 설명 판 · 누르는 자리
	local over = Stage.group(Stage.ui, "Chooser", 200)
	local titleBox = Stage.place(over, "Title", "tc", Stage.REF_W / 2 - 300, 22, 600, 16)
	Ui.text(titleBox, "달이 고른 자 — 누구의 뒤를 이을 것인가", 0, 0, 600, { font = "body", align = "center", outline = true })

	local order = CLASSES.order
	local n = #order
	local x0 = G.VIEW_W / 2 - GAP * (n - 1) / 2
	local slots = {}
	for i, id in order do
		local c = CLASSES.classes[id]
		local x = x0 + (i - 1) * GAP
		local sprite = Sprite.new(root, id, 5)
		local name = Ui.tag(over, c.name, WHITE, 200)
		-- 눌러서 고르는 자리(보이지 않는 단추)
		local button = Instance.new("TextButton")
		button.Name = "Pick_" .. id
		button.Text = ""
		button.BackgroundTransparency = 1
		button.ZIndex = 8
		button.Parent = over
		slots[i] = { id = id, class = c, x = x, sprite = sprite, name = name, button = button }
	end
	-- 이름과 누르는 자리는 영웅의 자리(게임의 도트)를 따라 놓는다 — 화면 틀의 배율이 바뀌면 다시 놓는다
	local function place()
		local r = Stage.ratio
		for _, s in slots do
			local cx, gy = math.floor(s.x * r + 0.5), math.floor(GROUND_Y * r + 0.5)
			s.name.Frame.Position = UDim2.fromOffset(cx - math.floor(s.name.Width / 2), gy + 6)
			s.button.Position = UDim2.fromOffset(cx - math.floor(GAP * r / 2), gy - math.floor(44 * r))
			s.button.Size = UDim2.fromOffset(math.floor(GAP * r), math.floor(44 * r) + 24)
		end
	end
	place()
	Stage.onResize(function()
		if over.Parent then
			place()
		end
	end)

	-- 고른 영웅의 설명: 아래 가운데의 판
	local holder = Stage.place(over, "Panel", "bc", Stage.REF_W / 2 - PANEL.w / 2, Stage.REF_H - PANEL.up - PANEL.h, PANEL.w, PANEL.h + 24)
	local panel = Ui.panel(holder, 0, 0, PANEL.w, PANEL.h)
	local head = Ui.text(panel, "", 18, 14, PANEL.w - 36, { font = "body", color = MINT })
	local role = Ui.text(panel, "", 18, 36, PANEL.w - 36, { lines = 3, line = 15 })
	Ui.text(holder, "← → 고르기 · Space 정하기", 0, PANEL.h + 8, PANEL.w, { align = "center", color = GRAY, outline = true })

	local picked = math.ceil(n / 2)
	local chosen: string? = nil
	local pickedAt = 0
	local clock = 0

	local function show()
		local slot = slots[picked]
		local c = slot.class
		head:color(if c.tone == "pink" then PINK else MINT)
		head:set(("%s의 계승자 · %s · %s"):format(c.hero, c.face, c.weapon))
		role:set(c.role)
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
	Chooser.over = over
	return chosen :: string
end

function Chooser.close()
	if Chooser.root then
		Chooser.root:Destroy()
		Chooser.root = nil
	end
	if Chooser.over then
		Chooser.over:Destroy()
		Chooser.over = nil
	end
end

return Chooser
