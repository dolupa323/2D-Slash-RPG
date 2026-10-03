-- 창 관리자(가방·도감·몬스터 상자·설정·가게·장비) — 웹/PC 창처럼 여러 개를 동시에 띄워 두고 쓴다.
--  · 열린 창은 모두 입력을 받는다(예전 "맨 위 하나만" 스택 방식은 폐기 — 2026-10-01).
--  · 창을 누르면 맨 앞으로(DisplayOrder). 제목줄(창 위쪽 띠)이나 위로 튀어나온 제목판을 끌면 창이 움직인다(마우스·터치). 화면 밖으로는 못 나감.
--  · 처음 여는 창은 조금씩 비켜서(계단식) 열려 겹치지 않게. 옮긴 자리는 세션 동안 기억한다.
--  · 메뉴 버튼(Toggle): 맨 앞에 열려 있으면 닫고, 뒤에 있으면 앞으로, 닫혀 있으면 연다.
-- modules/ 루트라 sceneLoader가 load/unload를 부르지 않는다 — 각 창 모듈이 UI를 만들 때 Register, 지울 때 Unregister.
-- Register(name, gui, panel): panel의 부모(Frame — 가운데 고정·UIScale)가 실제로 움직이는 창 틀이다.
local UserInputService = game:GetService("UserInputService")

local exports = {}

local BASE_DISPLAY_ORDER = 20
local TITLE_H = 24 -- 끌 수 있는 제목줄 높이(도트)
local CASCADE = 22 -- 새로 여는 창을 이만큼씩 비켜서(px)

-- name -> { gui, panel, holder, home = 처음 자리(UDim2), moved = 옮긴 자리(UDim2?) }
local registry = {}
local stack = {} -- 열린 창 이름(마지막이 맨 앞)
local dragging = nil -- { name, startPos: Vector2, origin: UDim2 }

local function relayout()
	for depth, name in stack do
		local entry = registry[name]
		if entry then
			entry.gui.DisplayOrder = BASE_DISPLAY_ORDER + depth
		end
	end
end

local function focus(name: string)
	local index = table.find(stack, name)
	if index and index ~= #stack then
		table.remove(stack, index)
		table.insert(stack, name)
		relayout()
	end
end
exports.Focus = focus

-- 창이 화면 밖으로 나가지 않게(제목줄이 늘 보이게)
local function clampToScreen(entry)
	local holder = entry.holder
	local gui = entry.gui
	local screen = gui.AbsoluteSize
	local size = holder.AbsoluteSize
	if screen.X <= 0 or size.X <= 0 then
		return
	end
	local pos = holder.AbsolutePosition
	local dx, dy = 0, 0
	if pos.X < -size.X + 60 then
		dx = -size.X + 60 - pos.X
	elseif pos.X > screen.X - 60 then
		dx = screen.X - 60 - pos.X
	end
	if pos.Y < 0 then
		dy = -pos.Y
	elseif pos.Y > screen.Y - 30 then
		dy = screen.Y - 30 - pos.Y
	end
	if dx ~= 0 or dy ~= 0 then
		holder.Position += UDim2.fromOffset(dx, dy)
	end
end

UserInputService.InputChanged:Connect(function(input)
	if not dragging or not (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		return
	end
	local entry = registry[dragging.name]
	if not entry then
		dragging = nil
		return
	end
	local delta = Vector2.new(input.Position.X, input.Position.Y) - dragging.startPos
	entry.holder.Position = dragging.origin + UDim2.fromOffset(delta.X, delta.Y)
end)

UserInputService.InputEnded:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		local entry = registry[dragging.name]
		if entry then
			clampToScreen(entry)
			entry.moved = entry.holder.Position
		end
		dragging = nil
	end
end)

function exports.Register(name: string, gui: ScreenGui, panel: GuiObject)
	local holder = panel.Parent :: GuiObject
	if not holder:IsA("GuiObject") or holder.Size.X.Scale >= 1 then
		holder = panel -- 부모가 화면 전체 틀이면(예전 장비 창) 패널 자체를 움직인다
	end
	local entry = { gui = gui, panel = panel, holder = holder, home = holder.Position, moved = nil }
	local old = registry[name]
	if old and old.moved then
		entry.moved = old.moved -- 씬이 바뀌어 다시 만들어진 창도 옮겨 둔 자리 그대로
	end
	registry[name] = entry
	panel.Visible = false
	panel.Interactable = true
	panel.ImageColor3 = Color3.new(1, 1, 1)

	-- 제목줄: 끌면 창이 움직인다(버튼들보다 아래 층 — 닫기 버튼 등은 그대로 눌린다)
	local handle = Instance.new("Frame")
	handle.Name = "TitleDrag"
	handle.BackgroundTransparency = 1
	handle.Size = UDim2.new(1, 0, 0, TITLE_H)
	handle.ZIndex = 0
	handle.Active = false
	handle.Parent = panel
	local function startDrag(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			focus(name)
			dragging = { name = name, startPos = Vector2.new(input.Position.X, input.Position.Y), origin = holder.Position }
		end
	end
	handle.InputBegan:Connect(startDrag)
	-- 창 위로 튀어나온 제목판(UI.TitleTag — 부품 이름 "tag")도 잡고 끌 수 있게(판과 그 위 글씨 모두)
	for _, child in panel:GetChildren() do
		if child.Name == "tag" and child:IsA("GuiObject") then
			child.Active = true
			child.InputBegan:Connect(startDrag)
			for _, d in child:GetDescendants() do
				if d:IsA("GuiObject") then
					d.InputBegan:Connect(startDrag)
				end
			end
		end
	end
	-- 창 아무 데나 누르면 맨 앞으로
	panel.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			focus(name)
		end
	end)

	local index = table.find(stack, name)
	if index then
		table.remove(stack, index)
	end
end

function exports.Unregister(name: string)
	local entry = registry[name]
	if entry then
		-- 옮긴 자리는 남겨 둔다(같은 이름으로 다시 Register하면 이어 씀)
		registry[name] = { moved = entry.moved, gui = entry.gui, panel = entry.panel, holder = entry.holder, home = entry.home, dead = true }
	end
	local index = table.find(stack, name)
	if index then
		table.remove(stack, index)
		relayout()
	end
end

function exports.IsOpen(name: string): boolean
	return table.find(stack, name) ~= nil
end

function exports.Open(name: string)
	local entry = registry[name]
	if not entry or entry.dead then
		return
	end
	if table.find(stack, name) then
		focus(name)
		return
	end
	-- 자리: 옮겨 둔 자리, 없으면 처음 자리에서 열린 창 수만큼 계단식으로 비켜서
	entry.holder.Position = entry.moved or (entry.home + UDim2.fromOffset(CASCADE * #stack, CASCADE * #stack))
	table.insert(stack, name)
	entry.panel.Visible = true
	relayout()
	task.defer(clampToScreen, entry)
end

function exports.Close(name: string)
	local entry = registry[name]
	local index = table.find(stack, name)
	if not entry or not index then
		return
	end
	table.remove(stack, index)
	entry.panel.Visible = false
	relayout()
end

-- 메뉴 버튼용: 맨 앞에 열려 있으면 닫고, 뒤에 있으면 맨 앞으로, 닫혀 있으면 연다.
function exports.Toggle(name: string)
	if stack[#stack] == name then
		exports.Close(name)
	elseif table.find(stack, name) then
		focus(name)
	else
		exports.Open(name)
	end
end

return exports
