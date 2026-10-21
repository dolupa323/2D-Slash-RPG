-- 조작 입력. 기본 키는 공방 「기본 · UI」 탭의 키 표를 따른다(← → 걷기 · ↑ 문과 주민 · ↓ 아래 발판 · Space 뛰기).
--  키는 "하는 일 → 키" 표(BIND)를 거쳐 읽는다 — 유저가 키를 바꾸는 화면(키 설정)이 이 표를 고치게 된다.
--  스마트폰 단추(터치)도 같은 "하는 일" 이름으로 Input.press / Input.release를 부른다.
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local Input = {}

-- 하는 일 → 기본 키
Input.BIND = {
	left = Enum.KeyCode.Left,
	right = Enum.KeyCode.Right,
	up = Enum.KeyCode.Up,
	down = Enum.KeyCode.Down,
	jump = Enum.KeyCode.Space,
	pickup = Enum.KeyCode.Z, -- 떨어진 것 줍기(누르고 있으면 차례로 줍는다)
	ride = Enum.KeyCode.N, -- 탈것 타기 · 내리기(2026-10-20 — 제가 정한 키: 다른 일이 쓰지 않는 글쇠)
}
-- 물약과 기술의 키는 여기에 없다 — 키는 퀵슬롯의 칸에 붙는다("slot:<칸>" — boot.luau가 묶는다). 스마트폰 단추는 "potion" · "skill:<기술 id>"를 그대로 누른다(키 없이 Input.press로)

-- 하는 일에 키를 묶는다: action = "slot:<칸>" · "win:<창>"
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
local byKey: { [string]: boolean } = {} -- 키보드로 누른 하는 일(아래 Input.poll이 뗄 수 있는 것 — 폰 단추로 누른 것은 건드리지 않는다)
local wasDown: { [string]: boolean } = {} -- 지난 장면에 그 키가 눌려 있었는가(Input.poll)

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

-- 읽지 않은 「누른 순간」을 모두 버린다(누르고 있는 것은 그대로) — 막이 걷히거나 · 일어나거나 · 장면이 끝나 조작이 돌아올 때(2026-10-18 검토:
--  문을 지나며 화면이 까만 동안 ↑를 한 번 더 누르면, 막이 걷히자마자 그 ↑로 들어온 문을 다시 지나 되돌아갔다 — 기술 · 뛰기 · 창 열기도 같았다)
function Input.flush()
	table.clear(pressed)
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

-- Roblox 채팅의 입력줄에 글을 치는 중인가(boot가 chat.luau의 Chat.focused를 넣는다). 그 입력줄은 Roblox의 화면이라 GetFocusedTextBox로는 보이지 않는다 —
--  이것을 보지 않으면 채팅에 친 글자(Q · W · A …)가 스킬로 나간다(2026-10-13: 채팅을 Roblox의 기본 채팅으로 바꿨다. Enter로 열던 우리 채팅 판은 없다)
Input.typing = nil :: (() -> boolean)?
Input.paused = false -- 캐릭터 고르기 화면에 가 있는 동안에는 게임의 키를 받지 않는다(boot.luau의 toSelect)

function Input.init()
	UserInputService.InputBegan:Connect(function(input)
		-- 로블록스 기본 조작이 방향키를 먼저 가져가므로 "처리됨" 표시는 보지 않는다. 글자를 치는 중(채팅 등)에만 받지 않는다.
		if input.UserInputType ~= Enum.UserInputType.Keyboard or UserInputService:GetFocusedTextBox() or Input.paused or (Input.typing ~= nil and Input.typing()) then
			return -- paused = 캐릭터 고르기 화면에 가 있다(게임의 키를 받지 않는다)
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
		if input.KeyCode.Value == 0 then
			Input.imeAt = os.clock() -- 무슨 키인지 모르는 글쇠(한글 입력 상태로 보인다 — 아래 Input.poll)
			return
		end
		local action = actionOf(input.KeyCode)
		if action then
			Input.press(action)
			byKey[action] = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local action = actionOf(input.KeyCode)
		if action then
			Input.release(action)
			byKey[action] = nil
		end
	end)
	-- 창이 뒤로 가면 누르고 있던 키를 모두 뗀 것으로 친다
	UserInputService.WindowFocusReleased:Connect(function()
		table.clear(held)
		table.clear(pressed)
		table.clear(byKey)
	end)
	-- 장면마다 키의 지금 상태로 맞춘다(게임의 장면 LuneFrame — 카메라 바로 앞 — 보다 먼저)
	RunService:BindToRenderStep("LuneInputPoll", Enum.RenderPriority.Input.Value, function()
		Input.poll(os.clock())
	end)
end

-- 키의 지금 상태로 맞춘다(2026-10-21 사용자: "로블록스에서 한글쓴다음에 키가 안먹히는 버그가있거든? 로블록스에서 유명한 버그야 이거 확인해봐"):
--  알려진 것 — Windows에서 한/영 키가 「한」인 동안 Roblox에서 글자 키가 먹지 않거나, 누른 키가 영어로 다시 누를 때까지 눌린 채로 남는다
--  (나무위키 「Roblox」의 2019년 기록 · DevForum 「Movement key in Korean doesn't work」 2021 — 게임 안에서만, Studio에서는 나지 않는다고 했다). 채팅에 한글을 친 뒤 그대로 두면 이 상태다.
--  우리 게임은 이동이 방향키 · 뛰기가 Space라 그대로지만, 퀵슬롯(Q W E R A S D F X) · 줍기(Z) · 탈것(N) · 창의 키는 글자다 — 누름 · 뗌 소식만 믿으면 스킬 키가 눌린 채로 남아 계속 나가거나 먹지 않는다.
--  그래서 ① 묶인 키마다 UserInputService:IsKeyDown을 장면마다 본다: 뗐는데 눌린 채인 것은 떼고(키보드로 누른 것만) · 이번 장면에 새로 눌린 것을 모르면 누른다(소식과 둘 중 먼저 온 것 —
--   글을 치는 중 · 캐릭터 고르기 · 키 설정 · Roblox 메뉴가 열린 동안에는 누르지 않는다. 그동안 눌려 있던 키는 뗐다가 다시 눌러야 먹는다)
--  ② 무슨 키인지 모르는 글쇠(KeyCode 0 — Unknown · None)가 오고 그 장면에 묶인 키가 하나도 눌려 있지 않으면 한 번으로 센다 → 3초 안에 두 번이면 Input.onIme(boot가 큰 알림 「한글 입력 상태」)를 부른다(1분에 한 번).
--  IsKeyDown이 한글 상태에서 맞게 나오는지 · 한글 상태의 글쇠가 KeyCode 0으로 오는지는 이 컴퓨터에서 확인하지 못했다(Studio에서는 이 버그가 나지 않는다고 한다) — 맞지 않으면 둘 다 아무 일도 하지 않는다
Input.onIme = nil :: (() -> ())?
Input.IME_WORDS = { head = "한글 입력 상태", line = "글자 키가 먹지 않으면 한/영 키를 눌러 영문으로 바꿔 주세요" } -- 큰 알림의 제목 · 아랫줄(제가 정한 글)
Input.imeAt = nil :: number?
local imeMiss: { number } = {}
local imeShown = -math.huge
Input.IME_GAP, Input.IME_WINDOW, Input.IME_COUNT = 60, 3, 2
-- 알아내기(자동 검사가 바꿔 끼운다)
Input.isDown = function(key: Enum.KeyCode): boolean
	return UserInputService:IsKeyDown(key)
end
Input.blocked = function(): boolean
	return Input.paused or captureFn ~= nil or UserInputService:GetFocusedTextBox() ~= nil or (Input.typing ~= nil and Input.typing()) or GuiService.MenuIsOpen
end

function Input.poll(now: number)
	local blocked = Input.blocked()
	local anyDown = false
	for action, key in Input.BIND do
		local down = Input.isDown(key)
		if down then
			anyDown = true
			if not wasDown[action] and not held[action] and not blocked then
				Input.press(action)
				byKey[action] = true
			end
		elseif byKey[action] then
			byKey[action] = nil
			held[action] = nil
		end
		wasDown[action] = down or nil
	end
	if Input.imeAt then
		Input.imeAt = nil
		if not anyDown then
			table.insert(imeMiss, now)
			while imeMiss[1] and now - imeMiss[1] > Input.IME_WINDOW do
				table.remove(imeMiss, 1)
			end
			if #imeMiss >= Input.IME_COUNT and now - imeShown >= Input.IME_GAP then
				imeShown = now
				table.clear(imeMiss)
				if Input.onIme then
					Input.onIme()
				end
			end
		end
	end
end

return Input
