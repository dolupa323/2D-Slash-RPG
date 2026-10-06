-- 스마트폰(터치) 단추 — 공방 「기본 · UI」 탭의 스마트폰 화면 배치(data/ui.generated.luau의 touch)를 그대로 그린다.
--  단추는 키와 같은 "하는 일" 이름으로 Input.press / Input.release를 부른다 — 게임은 키로 눌렀는지 손가락으로 눌렀는지 모른다.
--  사용자 결정(2026-10-06): 스마트폰 터치 조작을 지원한다. 터치 화면이면 저절로 켜진다(Studio에서는 화면 틀의 속성 Touch = true로 켜 볼 수 있다).
--  아직: 스킬 단추 여섯(쪽 넘기기)은 자리만 있다 — 1차에는 올릴 기술이 없다.
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage.shared.lune.data["ui.generated"])
local Stage = require(script.Parent.stage)
local Input = require(script.Parent.input)
local pixelText = require(script.Parent.Parent.modules.ui.pixelText)
local Kit = require(script.Parent.ui.kit)

local INK = Color3.fromRGB(18, 22, 28)
local WHITE = Color3.fromRGB(238, 246, 246)
local EDGE = { pad = Color3.fromRGB(62, 255, 215), big = Color3.fromRGB(255, 126, 162), skill = Color3.fromRGB(255, 215, 106), etc = Color3.fromRGB(172, 255, 215) }

local Touch = {}
Touch.on = false

-- 단추 이름 → 하는 일. skillOf(갈래) = 그 직업의 사냥기 · 보스기 · 이동기 기술 이름
local function actionOf(name: string, skillOf: (string) -> string?): string?
	if name == "사냥기" then
		return skillOf("mob")
	elseif name == "보스기" then
		return skillOf("boss")
	elseif name == "대쉬" then
		return skillOf("move")
	elseif name == "뛰기" then
		return "jump"
	elseif name == "물약" then
		return "potion"
	elseif name == "줍기 · 말 걸기" then
		return "act" -- 상황 단추: 떨어진 것이 가까우면 줍고, 아니면 ↑(문 · 주민)
	elseif name == "메뉴" then
		return "menu"
	elseif name == "채팅" then
		return "chat"
	end
	return nil
end

local function round(frame: Frame)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
end

function Touch.init(opts)
	local root = Stage.group(Stage.view, "Touch", 120)
	root.Visible = false
	Touch.root = root

	for _, t in UI.touch do
		if t.kind ~= "hud" then
			local frame = Instance.new("Frame")
			frame.Name = "T" .. t.no
			frame.Position = UDim2.fromOffset(t.x, t.y)
			frame.Size = UDim2.fromOffset(t.w, t.h)
			frame.BackgroundColor3 = INK
			frame.BackgroundTransparency = 0.45
			frame.BorderSizePixel = 0
			frame.Parent = root
			round(frame)
			local stroke = Instance.new("UIStroke")
			stroke.Color = EDGE[t.kind] or WHITE
			stroke.Thickness = 1
			stroke.Parent = frame

			local hit = Instance.new("TextButton")
			hit.Text = ""
			hit.BackgroundTransparency = 1
			hit.Size = UDim2.fromScale(1, 1)
			hit.ZIndex = 3
			hit.Parent = frame

			if t.kind == "pad" then
				-- 이동 패드: 가운데에서 민 쪽으로 걷는다. 위로 밀면 ↑(문 · 주민), 아래로 밀면 ↓(발판)
				local finger = nil
				local function aim(pos: Vector3)
					local center = frame.AbsolutePosition + frame.AbsoluteSize / 2
					local dx, dy = pos.X - center.X, pos.Y - center.Y
					local dead = frame.AbsoluteSize.X * 0.14
					local function set(action: string, on: boolean)
						if on then
							Input.press(action)
						else
							Input.release(action)
						end
					end
					set("left", dx < -dead)
					set("right", dx > dead)
					set("up", dy < -frame.AbsoluteSize.Y * 0.3)
					set("down", dy > frame.AbsoluteSize.Y * 0.3)
				end
				local function stop()
					finger = nil
					for _, a in { "left", "right", "up", "down" } do
						Input.release(a)
					end
				end
				hit.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
						finger = input
						aim(input.Position)
					end
				end)
				UserInputService.InputChanged:Connect(function(input)
					if finger and (input == finger or (finger.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)) then
						aim(input.Position)
					end
				end)
				UserInputService.InputEnded:Connect(function(input)
					if finger and (input == finger or input.UserInputType == finger.UserInputType) then
						stop()
					end
				end)
			else
				local action = actionOf(t.name, opts.skillOf)
				local label = opts.labelOf(t.name)
				if t.name == "물약" then
					-- 물약 단추: 병 그림과 남은 수(키가 적힌 물약 칸이 숨어 있으므로 여기에 적는다)
					local cx = math.floor(t.w / 2)
					Kit.box(frame, cx - 3, 4, 6, 6, Color3.fromRGB(255, 62, 159))
					Kit.box(frame, cx - 1, 2, 2, 2, WHITE)
					Touch.potionText = Kit.text(frame, "", 0, 10, t.w, { align = "center" })
				elseif label then
					local text = pixelText.new(frame, { Text = label, Font = "body", Color = WHITE, Align = "center", MaxWidth = t.w, MaxLines = 1 })
					text.Frame.Position = UDim2.fromOffset(math.floor((t.w - text.Width) / 2), math.floor((t.h - 13) / 2))
				end
				if action then
					hit.MouseButton1Down:Connect(function()
						if action == "menu" then
							opts.onMenu()
						elseif action == "chat" then
							opts.onChat()
						elseif action == "act" then
							opts.onAct(true)
						else
							Input.press(action)
						end
					end)
					local function up()
						if action == "act" then
							opts.onAct(false)
						elseif action ~= "menu" and action ~= "chat" then
							Input.release(action)
						end
					end
					hit.MouseButton1Up:Connect(up)
					hit.MouseLeave:Connect(up)
				else
					frame.BackgroundTransparency = 0.75 -- 아직 쓰지 않는 자리
					stroke.Transparency = 0.6
				end
			end
		end
	end

	-- 남은 물약의 수
	function Touch.setPotions(n: number)
		if Touch.potionText then
			Touch.potionText:set(tostring(n))
		end
	end

	local function decide()
		local forced = Stage.gui:GetAttribute("Touch")
		local on = forced == true or (forced == nil and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
		Touch.on = on
		root.Visible = on
		if opts.onToggle then
			opts.onToggle(on)
		end
	end
	Stage.gui:GetAttributeChangedSignal("Touch"):Connect(decide)
	decide()
end

return Touch
