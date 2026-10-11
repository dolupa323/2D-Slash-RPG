-- 막 — 장면이 바뀔 때(문 · 마을로 돌아가기 · 관리 이동 · 게임에 들어올 때) 화면을 검게 덮고, 그 사이에 새 장면이 쓰는 그림을 다 불러온 뒤에 걷는다.
--  사용자 2026-10-11: "게임 시작시, 포탈 이용시 페이드 아웃 로딩 걸고 그 사이에 이미지 정확히 다 로드 해야합니다. 지금 그냥 포탈로 넘어간다음에 이미지들 로드 안되서 바로 안뜹니다."
--  전에는 처음에 그림의 번호(글)만 한꺼번에 미리 불러 두고, 문을 지나면 새 장면을 바로 그렸다 — 그 장면의 그림이 화면에 올라오기 전의 빈 모습이 잠깐 보였다.
--  이제는 새 장면을 막 뒤에서 그려 놓고, 거기에 실제로 쓰인 그림(ImageLabel)들이 다 불러와졌는지 보고 나서 막을 걷는다.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Curtain = {}
Curtain.OUT, Curtain.IN = 0.16, 0.26 -- 덮는 시간 · 걷는 시간(초)
Curtain.MAX_WAIT = 8 -- 그림을 기다리는 가장 긴 시간(초) — 끝내 오지 않는 그림이 있어도 화면은 열린다
Curtain.DOTS_AFTER = 0.5 -- 이보다 오래 걸리면 오른쪽 아래에 점 셋이 깜빡인다(불러오는 중)
Curtain.COLOR = Color3.fromRGB(11, 15, 22) -- 화면 부품의 가장 어두운 색(ui.js의 ink)
Curtain.DOT = Color3.fromRGB(143, 240, 212)

local gui: ScreenGui? = nil
local shade: Frame = nil
local dots: { Frame } = {}
local level = 0 -- 0 = 걷혀 있다 · 1 = 다 덮였다
local failed: { [string]: boolean } = {} -- 끝내 불러오지 못한 그림(다음부터는 기다리지 않는다)
Curtain.last = { images = 0, waited = 0, timedOut = 0 } -- 마지막으로 기다린 것(확인용)

function Curtain.init()
	if gui then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "LuneCurtain"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 1000 -- 게임 화면(LuneStage — 0)의 모든 것 위
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- 막(Shade — 10)이 그림 조각(Warm — 1)을 덮는다
	shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.ZIndex = 10
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Curtain.COLOR
	shade.BackgroundTransparency = 1
	shade.BorderSizePixel = 0
	shade.Visible = false
	shade.Parent = g
	for i = 1, 3 do
		local d = Instance.new("Frame")
		d.Name = "Dot" .. i
		d.Size = UDim2.fromOffset(8, 8)
		d.AnchorPoint = Vector2.new(1, 1)
		d.Position = UDim2.new(1, -28 - (3 - i) * 16, 1, -28)
		d.BackgroundColor3 = Curtain.DOT
		d.BorderSizePixel = 0
		d.Visible = false
		d.Parent = shade
		dots[i] = d
	end
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
end

local function setLevel(k: number)
	level = math.clamp(k, 0, 1)
	shade.BackgroundTransparency = 1 - level
	shade.Visible = level > 0
	shade.Active = level > 0 -- 덮여 있는 동안은 뒤의 단추가 눌리지 않는다
end

local function showDots(on: boolean, now: number?)
	for i, d in dots do
		d.Visible = on
		if on and now then
			d.BackgroundTransparency = if math.floor(now * 3) % 3 == i - 1 then 0 else 0.7
		end
	end
end

local function fade(to: number, seconds: number)
	local from = level
	if seconds <= 0 or from == to then
		setLevel(to)
		return
	end
	local t = 0
	while t < seconds do
		t += RunService.Heartbeat:Wait()
		setLevel(from + (to - from) * math.min(1, t / seconds))
	end
	setLevel(to)
end

-- 화면을 덮는다(다 덮일 때까지 기다린다). seconds를 안 주면 Curtain.OUT
function Curtain.cover(seconds: number?)
	Curtain.init()
	fade(1, seconds or Curtain.OUT)
end

-- 막을 걷는다(다 걷힐 때까지 기다린다)
function Curtain.lift(seconds: number?)
	Curtain.init()
	showDots(false)
	fade(0, seconds or Curtain.IN)
end

function Curtain.covered(): boolean
	return level >= 1
end

-- 그 틀들 아래에서 쓰이는 그림들(그림마다 한 번씩): 보이는 것도, 숨겨져 있는 것(조금 뒤에 나타날 몬스터 · 쓰러졌을 때의 비석)도, 카메라 밖에 놓인 것도 모두
function Curtain.images(roots: { Instance }): { string }
	local seen, list = {}, {}
	for _, root in roots do
		for _, d in root:GetDescendants() do
			if d:IsA("ImageLabel") or d:IsA("ImageButton") then
				local image = (d :: any).Image
				if image ~= "" and not seen[image] and not failed[image] then
					seen[image] = true
					table.insert(list, image)
				end
			end
		end
	end
	return list
end

-- 그 틀들에 쓰인 그림이 다 불러와질 때까지 기다린다(가장 길게 timeout초). 막을 친 뒤, 새 장면을 그린 다음에 부른다.
--  로블록스는 숨겨져 있거나 화면 밖에 놓인 그림을 미리 불러와 두지 않는다(그것이 처음 그려질 때에야 올라온다 — 그래서 문을 지난 뒤 땅과 몬스터가 한 박자 늦게 떴다).
--  그래서 그림마다 작은 조각(4점짜리)을 막 뒤에 실제로 그려 놓고, 조각마다 「불러옴」(IsLoaded)이 설 때까지 기다린다 — 그 그림은 이제 바로 그려진다. 조각은 막을 걷기 전에 치운다.
--  돌려주는 것: 기다린 시간(초) · 그림의 수 · 끝내 오지 않은 수
function Curtain.load(roots: { Instance }, timeout: number?): (number, number, number)
	Curtain.init()
	local images = Curtain.images(roots)
	local warm = Instance.new("Frame")
	warm.Name = "Warm"
	warm.Size = UDim2.fromOffset(4, 4)
	warm.BackgroundTransparency = 1
	warm.BorderSizePixel = 0
	warm.ZIndex = 1 -- 막(Shade — 10)의 뒤: 막이 덮여 있는 동안은 보이지 않는다
	local pieces = {}
	for i, image in images do
		local piece = Instance.new("ImageLabel")
		piece.Name = "Piece"
		piece.Size = UDim2.fromOffset(4, 4)
		piece.Position = UDim2.fromOffset((i - 1) % 64 * 4, math.floor((i - 1) / 64) * 4)
		piece.BackgroundTransparency = 1
		piece.BorderSizePixel = 0
		piece.Image = image
		piece.Parent = warm
		pieces[i] = piece
	end
	warm.Parent = gui
	local finished = #pieces == 0
	if not finished then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(pieces)
			end)
			finished = true
		end)
	end
	local limit = timeout or Curtain.MAX_WAIT
	local t0 = os.clock()
	local missing = 0
	local timedOut = 0
	while true do
		local now = os.clock()
		missing = 0
		for _, piece in pieces do
			if not piece.IsLoaded then
				missing += 1
			end
		end
		if finished and missing == 0 then
			break
		elseif now - t0 >= limit then
			-- 끝내 오지 않았다: 그 그림들은 다음부터 기다리지 않는다(장면이 바뀔 때마다 멈춰 서지 않게)
			for _, piece in pieces do
				if not piece.IsLoaded then
					failed[piece.Image] = true
					timedOut += 1
				end
			end
			break
		end
		showDots(now - t0 >= Curtain.DOTS_AFTER, now)
		RunService.Heartbeat:Wait()
	end
	-- 새 장면이 한 번 그려진 뒤에 걷는다(카메라가 제자리를 잡고, 장면의 그림들이 방금 불러온 것으로 그려진다)
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	warm:Destroy()
	local waited = os.clock() - t0
	Curtain.last = { images = #images, waited = waited, timedOut = timedOut }
	-- 확인용: 마지막으로 기다린 것을 막의 속성으로 적어 둔다(Studio에서 읽어 본다) — 그림의 수 · 기다린 시간 · 끝내 오지 않은 수 · 지금까지 기다린 횟수
	if gui then
		gui:SetAttribute("Images", #images)
		gui:SetAttribute("Waited", math.floor(waited * 1000 + 0.5) / 1000)
		gui:SetAttribute("TimedOut", timedOut)
		gui:SetAttribute("Loads", (gui:GetAttribute("Loads") or 0) + 1)
	end
	return waited, #images, timedOut
end

return Curtain
