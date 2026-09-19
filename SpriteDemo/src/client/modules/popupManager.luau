-- 팝업 스택 매니저 (ROADMAP Phase 4, Cheruton의 스택 기반 팝업 매니저 패턴). 가방/장비/설정
-- 같은 패널이 여러 개 열려 있을 수 있어도, 항상 "맨 위(가장 나중에 연)" 패널만 입력을 받는다
-- — 아래 패널은 열린 채로 유지되지만 어둡게 가라앉고 눌러도 반응하지 않는다. 맨 위 패널을
-- 닫으면 그 아래 패널이 다시 입력을 받는다. modules/ 루트라 sceneLoader가 자동으로
-- load/unload를 부르지 않는다(travelState와 같은 패턴) — 각 패널 모듈이 UI를 만들 때
-- Register, 지울 때 Unregister를 직접 부른다.
--
-- Cheruton은 팝업이 열려 있으면 게임 전체를 일시정지시키지만, 우리는 서버가 멈추면 안 되는
-- 멀티플레이어 게임이라 일시정지는 하지 않는다(ROADMAP 비교표 참고) — 입력 우선순위만 관리한다.
local exports = {}

local BASE_DISPLAY_ORDER = 20
local DIM_COLOR = Color3.fromRGB(140, 140, 140)

-- name -> { gui = ScreenGui, panel = ImageLabel }
local registry = {}
-- 열린 순서대로 쌓인 이름 목록(마지막이 맨 위).
local stack = {}

local function indexInStack(name: string): number?
	return table.find(stack, name)
end

-- 스택 순서대로 DisplayOrder를 다시 매기고, 맨 위만 입력을 받게 한다.
local function relayout()
	for depth, name in stack do
		local entry = registry[name]
		if entry then
			local isTop = depth == #stack
			entry.gui.DisplayOrder = BASE_DISPLAY_ORDER + depth
			entry.panel.Interactable = isTop
			entry.panel.ImageColor3 = if isTop then Color3.new(1, 1, 1) else DIM_COLOR
		end
	end
end

function exports.Register(name: string, gui: ScreenGui, panel: ImageLabel)
	registry[name] = { gui = gui, panel = panel }
	panel.Visible = false
	local index = indexInStack(name)
	if index then
		table.remove(stack, index)
	end
end

function exports.Unregister(name: string)
	registry[name] = nil
	local index = indexInStack(name)
	if index then
		table.remove(stack, index)
		relayout()
	end
end

function exports.IsOpen(name: string): boolean
	return indexInStack(name) ~= nil
end

function exports.Open(name: string)
	local entry = registry[name]
	if not entry then
		return
	end
	local index = indexInStack(name)
	if index then
		table.remove(stack, index) -- 이미 열려 있으면 맨 위로 끌어올린다.
	end
	table.insert(stack, name)
	entry.panel.Visible = true
	relayout()
end

function exports.Close(name: string)
	local entry = registry[name]
	local index = indexInStack(name)
	if not entry or not index then
		return
	end
	table.remove(stack, index)
	entry.panel.Visible = false
	entry.panel.Interactable = true
	entry.panel.ImageColor3 = Color3.new(1, 1, 1)
	relayout()
end

-- 메뉴 버튼용: 맨 위에 열려 있으면 닫고, 아니면(닫혀 있거나 아래에 깔려 있으면) 맨 위로 연다.
function exports.Toggle(name: string)
	if stack[#stack] == name then
		exports.Close(name)
	else
		exports.Open(name)
	end
end

return exports
