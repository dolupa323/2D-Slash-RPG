-- 조작 입력. 기본 키는 공방 「기본 · UI」 탭의 키 표를 따른다(← → 걷기 · ↑ 문과 주민 · ↓ 아래 발판 · Space 뛰기).
--  키는 "하는 일 → 키" 표(BIND)를 거쳐 읽는다 — 유저가 키를 바꾸는 화면(키 설정)이 이 표를 고치게 된다.
--  스마트폰 단추(터치)도 같은 "하는 일" 이름으로 Input.press / Input.release를 부른다.
local UserInputService = game:GetService("UserInputService")

local Input = {}

-- 하는 일 → 기본 키
Input.BIND = {
	left = Enum.KeyCode.Left,
	right = Enum.KeyCode.Right,
	up = Enum.KeyCode.Up,
	down = Enum.KeyCode.Down,
	jump = Enum.KeyCode.Space,
	pickup = Enum.KeyCode.Z, -- 떨어진 것 줍기(누르고 있으면 차례로 줍는다)
	potion = Enum.KeyCode.LeftControl,
}

-- 기술 키를 더한다(직업마다 다르다): action = "skill:<기술 id>"
function Input.bind(action: string, key: Enum.KeyCode)
	Input.BIND[action] = key
end

local defaults: { [string]: Enum.KeyCode } = {}
local captureFn: ((Enum.KeyCode) -> ())? = nil

-- 다음에 누르는 키 하나를 가로챈다(키 설정 창이 쓴다). nil을 주면 그만둔다
function Input.capture(fn: ((Enum.KeyCode) -> ())?)
	captureFn = fn
end

-- 하는 일의 키를 바꾼다. 그 키를 이미 다른 일이 쓰고 있으면 둘이 자리를 바꾼다
function Input.rebind(action: string, key: Enum.KeyCode)
	local old = Input.BIND[action]
	for other, bound in Input.BIND do
		if other ~= action and bound == key then
			Input.BIND[other] = old
		end
	end
	Input.BIND[action] = key
end

-- 지금의 표를 "기본"으로 적어 둔다(기술 · 창의 키까지 다 묶은 뒤에 한 번 부른다)
function Input.markDefaults()
	defaults = table.clone(Input.BIND)
end

function Input.reset()
	for action, key in defaults do
		Input.BIND[action] = key
	end
end

-- 저장할 꼴: 기본과 다른 것만 { [하는 일] = 키 이름 }
function Input.export()
	local out = {}
	for action, key in Input.BIND do
		if defaults[action] ~= key then
			out[action] = key.Name
		end
	end
	return out
end

-- 저장된 것을 입힌다(모르는 일 · 모르는 키는 건너뛴다)
function Input.import(map)
	if typeof(map) ~= "table" then
		return
	end
	for action, name in map do
		if Input.BIND[action] ~= nil and typeof(name) == "string" then
			local ok, key = pcall(function()
				return (Enum.KeyCode :: any)[name]
			end)
			if ok and key then
				Input.rebind(action, key)
			end
		end
	end
end

local held: { [string]: boolean } = {}
local pressed: { [string]: boolean } = {} -- 누른 순간(한 번 읽으면 지워진다)

function Input.press(action: string)
	if not held[action] then
		pressed[action] = true
	end
	held[action] = true
end

function Input.release(action: string)
	held[action] = nil
end

function Input.held(action: string): boolean
	return held[action] == true
end

-- 누른 순간이었는가(읽으면 지운다)
function Input.take(action: string): boolean
	local was = pressed[action] == true
	pressed[action] = nil
	return was
end

function Input.axis(): number
	return (if held.right then 1 else 0) - (if held.left then 1 else 0)
end

local function actionOf(key: Enum.KeyCode): string?
	for action, bound in Input.BIND do
		if bound == key then
			return action
		end
	end
	return nil
end

Input.onEnter = nil :: (() -> ())? -- Enter를 눌렀을 때(채팅 열기)

function Input.init()
	UserInputService.InputBegan:Connect(function(input)
		-- 로블록스 기본 조작이 방향키를 먼저 가져가므로 "처리됨" 표시는 보지 않는다. 글자를 치는 중(채팅 등)에만 받지 않는다.
		if input.UserInputType ~= Enum.UserInputType.Keyboard or UserInputService:GetFocusedTextBox() then
			return
		end
		-- Enter는 채팅을 연다(키 설정으로 바꾸는 키가 아니다)
		if (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) and not captureFn then
			if Input.onEnter then
				Input.onEnter()
			end
			return
		end
		if captureFn then
			-- 키 설정 중: 이 키를 새 키로 넘긴다(Esc와 알 수 없는 키는 받지 않는다)
			if input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Enum.KeyCode.Unknown then
				local fn = captureFn
				captureFn = nil
				fn(input.KeyCode)
			end
			return
		end
		local action = actionOf(input.KeyCode)
		if action then
			Input.press(action)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local action = actionOf(input.KeyCode)
		if action then
			Input.release(action)
		end
	end)
	-- 창이 뒤로 가면 누르고 있던 키를 모두 뗀 것으로 친다
	UserInputService.WindowFocusReleased:Connect(function()
		table.clear(held)
		table.clear(pressed)
	end)
end

return Input
