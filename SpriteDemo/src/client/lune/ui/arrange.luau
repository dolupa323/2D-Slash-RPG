-- 화면 배치(2026-11-12 사용자: "지금 채팅창처럼 모든 ui 가 끌어서 자리를 옮길수 있어야해 지금 모바일에서 잘려보이는경우 엄청많아").
--  메뉴(PC 「더보기」 · 폰 메뉴)의 「화면 배치」로 들어간다: 화면의 판마다 민트 테두리와 이름이 덮이고, 끌면(마우스 · 손가락) 옮겨진다. 위 가운데 띠의 「완료」 = 저장하고 끝 · 「처음대로」 = 모두 처음 자리.
--  옮긴 만큼은 stage.luau Stage.moved[판의 이름](판이 다시 지어질 때도 Stage.place가 더한다 · 화면 밖으로는 나가지 않는다 — Stage.fit) ·
--   채팅 창은 제 자리 셈이 따로라(chat.luau Chat.pos) 그것을 고친다. 저장 = 계정의 화면 설정(viewOpts.luau ViewOpts.ui — 기기 종류 pc · touch마다).
--  창(가방 · 퀘스트 …)은 이 모드가 아니어도 제목 줄을 끌면 옮겨진다(ui/windows.luau). 폰의 움직임 · 기술 단추는 따로(설정 → 폰 단추 배치 · 메뉴의 「단추 옮기기」 — touch.luau).
--  매크로 확인 창 · 띠는 옮기지 않는다(가려 두지 못하게).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local UI = require(ReplicatedStorage.shared.lune.data["ui.generated"])
local Stage = require(script.Parent.Parent.stage)
local Ui = require(script.Parent.ui)

local A = UI.layout.arrange -- (공방 ui.js의 UILAYOUT.arrange)
local C = Ui.COLOR

local Arrange = {}
-- 옮길 수 있는 판: { 판의 이름(Stage.place의 name), 보일 이름 } — [제가 정한 것] 목록
Arrange.LIST = {
	{ "Vitals", "체력 · 경험치" },
	{ "Skills", "퀵슬롯" },
	{ "Menu", "메뉴" },
	{ "Buffs", "버프" },
	{ "Quests", "퀘스트 알리미" },
	{ "Party", "파티" },
	{ "GainLog", "획득 기록" },
	{ "Chat", "채팅" },
	{ "Boss", "보스 체력" },
	{ "MapName", "맵 이름" },
	{ "GuideBanner", "알림" },
	{ "Rift", "토벌 · 던전" },
	{ "Voyage", "배" },
	{ "MvpPanel", "MVP" },
}
Arrange.active = false
Arrange.onSave = nil :: (() -> ())? -- 저장(boot가 단다 — ViewOpts.ui에 옮겨 담고 서버의 Sound로)
Arrange.chat = nil :: any -- 채팅 모듈(boot가 단다 — 순환 require를 피한다): { pos, setPos(pos) }

local layer: Frame? = nil
local conns = {} :: { RBXScriptConnection }
local items = {} -- { name, label, frame, box = 덮개, at, x, y, w, h }

-- 판의 지금 자리(화면 틀의 점 — 왼쪽 위)
local function topLeft(frame: GuiObject): (number, number)
	local us = math.max(Stage.uiScale or 1, 0.01)
	local base = Stage.ui.AbsolutePosition
	return (frame.AbsolutePosition.X - base.X) / us, (frame.AbsolutePosition.Y - base.Y) / us
end

local function follow(it)
	local x, y = topLeft(it.frame)
	it.box.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
end

local function alive(frame: Instance?): boolean
	if not frame or not frame.Parent or not frame:IsDescendantOf(Stage.ui) then
		return false
	end
	local f: Instance? = frame
	while f and f ~= Stage.ui do
		if f:IsA("GuiObject") and not (f :: GuiObject).Visible then
			return false
		end
		f = f.Parent
	end
	return true
end

-- 한 판을 끌어 옮긴 만큼(dx, dy — 화면 틀의 점)
local function shift(it, base, dx: number, dy: number)
	if it.name == "Chat" and Arrange.chat then
		Arrange.chat.setPos({ x = math.floor(base.x + dx + 0.5), y = math.floor(base.y + dy + 0.5) })
		local f = Stage.placed.Chat
		if f and f.frame then
			it.frame = f.frame -- (채팅 창은 자리를 바꾸면 다시 지어진다)
		end
	else
		local rec = Stage.placed[it.name]
		if not rec or rec.frame ~= it.frame then
			return
		end
		local want = { x = base.x + dx, y = base.y + dy }
		local fx, fy = Stage.fit(rec.at, rec.x + want.x, rec.y + want.y, rec.w, rec.h)
		local ox, oy = math.floor(fx - rec.x + 0.5), math.floor(fy - rec.y + 0.5)
		Stage.moved[it.name] = if ox == 0 and oy == 0 then nil else { x = ox, y = oy }
		it.frame.Position = Stage.movedPosition(it.name, rec.at, rec.x, rec.y, rec.w, rec.h)
	end
	follow(it)
end

local function cover(name: string, label: string)
	local rec = Stage.placed[name]
	if not rec or not alive(rec.frame) then
		return
	end
	local frame = rec.frame
	local w, h = math.max(16, frame.AbsoluteSize.X / math.max(Stage.uiScale or 1, 0.01)), math.max(12, frame.AbsoluteSize.Y / math.max(Stage.uiScale or 1, 0.01))
	local box = Instance.new("TextButton")
	box.Name = "Move_" .. name
	box.Text = ""
	box.AutoButtonColor = false
	box.BackgroundColor3 = C.accent
	box.BackgroundTransparency = 0.82
	box.BorderSizePixel = 0
	box.Size = UDim2.fromOffset(math.floor(w), math.floor(h))
	box.Parent = layer
	local edge = Instance.new("UIStroke")
	edge.Color = C.accent
	edge.Thickness = 1
	edge.Parent = box
	Ui.text(box, label, 2, 2, math.max(10, math.floor(w) - 4), { color = C.accent, outline = true })
	local it = { name = name, label = label, frame = frame, box = box }
	follow(it)
	local start, active, base = nil, nil, nil
	box.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		start, active = Vector2.new(input.Position.X, input.Position.Y), input
		if name == "Chat" and Arrange.chat then
			base = Arrange.chat.pos or { x = 0, y = 0 }
		else
			base = Stage.moved[name] or { x = 0, y = 0 }
		end
	end)
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if not start or not active then
			return
		end
		local same = input == active or (active.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
		if not same then
			return
		end
		local us = math.max(Stage.uiScale or 1, 0.01)
		shift(it, base, (input.Position.X - start.X) / us, (input.Position.Y - start.Y) / us)
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if start and (input == active or input.UserInputType == Enum.UserInputType.MouseButton1) then
			start, active = nil, nil
		end
	end))
	table.insert(items, it)
end

-- 들어간다(설정 창의 「바꾸기」)
function Arrange.open()
	if Arrange.active then
		return
	end
	Arrange.active = true
	layer = Stage.group(Stage.ui, "Arrange", 980)
	for _, e in Arrange.LIST do
		cover(e[1], e[2])
	end
	-- 위 가운데 띠: 안내 · 「처음대로」 · 「완료」
	local B = A.bar
	local bar = Stage.place(layer :: Frame, "ArrangeBar", "tc", math.floor((Stage.REF_W - B.w) / 2), B.y, B.w, B.h)
	Ui.panel(bar, 0, 0, B.w, B.h)
	Ui.text(bar, B.title, 8, math.floor((B.h - Ui.M.small) / 2), B.w - B.btnW * 2 - 28, { color = C.text })
	Ui.button(bar, B.reset, B.w - B.btnW * 2 - 14, 6, B.btnW, function()
		Arrange.reset()
	end, { h = B.h - 12 })
	Ui.button(bar, B.done, B.w - B.btnW - 8, 6, B.btnW, function()
		Arrange.close(true)
	end, { main = true, h = B.h - 12 })
	Stage.placed.ArrangeBar = nil -- (띠는 옮길 판이 아니다)
end

-- 끝낸다(save = 저장한다)
function Arrange.close(save: boolean?)
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	table.clear(items)
	if layer then
		layer:Destroy()
		layer = nil
	end
	Arrange.active = false
	if save and Arrange.onSave then
		Arrange.onSave()
	end
end

-- 모두 처음 자리로(창의 자리까지 — 설정 창의 「처음대로」 · 띠의 「처음대로」)
function Arrange.reset()
	for name, _ in Stage.moved do
		Stage.moved[name] = nil
	end
	for name, rec in Stage.placed do
		if rec.frame and rec.frame.Parent and string.sub(name, 1, 7) ~= "Window_" then
			rec.frame.Position = Stage.movedPosition(name, rec.at, rec.x, rec.y, rec.w, rec.h)
		end
	end
	if Arrange.chat then
		Arrange.chat.setPos(nil)
	end
	if Arrange.onReset then
		Arrange.onReset()
	end
	for _, it in items do
		local f = Stage.placed[it.name]
		if f and f.frame then
			it.frame = f.frame
		end
		follow(it)
	end
	if not Arrange.active and Arrange.onSave then
		Arrange.onSave()
	end
end
Arrange.onReset = nil :: (() -> ())? -- 창을 다시 놓는다(boot가 단다 — Windows.relayout)

return Arrange
