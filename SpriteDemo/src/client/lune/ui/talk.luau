-- 주민과의 대화 — 그 주민 머리 위의 흰 말풍선(산나비처럼: 흰 속 · 어두운 테두리 한 점 · 아래 그림자 · 꼬리. 얼굴 칸 · 이름표를 따로 두지 않는다).
--  주민 앞에서 ↑를 누르면 뜨고, 한 번 더 누르면 다음 말, 마지막 말 뒤에는 닫힌다. 말풍선을 눌러도 ↑와 같다(스마트폰).
--  말풍선 위에는 퀘스트의 이름(노랑), 아래에는 지금 ↑가 하는 일(「↑ 다음」 · 「↑ 받는다」 · 「↑ 끝낸다」 · 「↑ 닫기」)이 적힌다. 말이 더 남았으면 말풍선 귀퉁이에 파란 점.
--  말은 장면 자료(공방 js/lune/design/town.js에서 내보낸 것)의 lines, 또는 퀘스트의 대사(받을 때 · 하는 중 · 돌려줄 때 — data/quests.generated.luau).
--  퀘스트의 대사는 마지막 말에서 ↑(또는 말풍선)를 누르면 그 일(받기 · 돌려주기)이 일어난다 — 그 전에 자리를 뜨면 아무 일도 없다.
--  말풍선은 글씨의 층(화면 틀의 고운 격자)에 그리고, 화면마다 주민의 자리(게임 세계의 도트)를 따라간다(Talk.place).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage.shared.lune.ui.format)
local pixelText = require(script.Parent.Parent.Parent.modules.ui.pixelText)
local Stage = require(script.Parent.Parent.stage)
local Overlay = require(script.Parent.Parent.overlay)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local B = Format.BUBBLE -- 자동 검사가 주민의 말이 이 폭 · 줄 수에 들어가는지 본다
local LINE = Ui.M.bodyLine

local Talk = {}
Talk.npc = nil :: any
Talk.index = 0
Talk.TEXT_W = B.textW
Talk.LINES = B.lines
Talk.onToggle = nil :: ((any) -> ())? -- 말풍선이 뜨고 닫힐 때(뜨면 그 주민, 닫히면 nil) — 그 주민 머리 위의 퀘스트 표시가 그동안 숨는다

local root: Frame
local bubble: Frame
local back, tail, body, title, key, hint, more
local lines: { string } = {}
local onEnd: (() -> ())? = nil
local endHint: string? = nil
local size = { w = 0, h = 0 }

function Talk.init()
	root = Stage.group(Overlay.root, "Talk", 60)
	root.Visible = false
	bubble = Ui.group(root, 0, 0, 1, 1, "Bubble")
	back = Ui.part(bubble, "uBubble", 0, 0, 12, 14)
	tail = Ui.part(bubble, "uTail", 0, 0)
	tail.ZIndex = 2
	body = Ui.text(bubble, "", B.padX, B.padY, Talk.TEXT_W, { font = "body", lines = Talk.LINES, line = LINE, color = C.bubbleInk, z = 3 })
	more = Ui.box(bubble, 0, 0, 4, 4, C.mark)
	more.Name = "More"
	more.ZIndex = 3
	title = Ui.text(bubble, "", 2, -14, 300, { color = C.gold, outline = true })
	key = Ui.keycap(bubble, "↑", 0, 0)
	hint = Ui.text(bubble, "", 0, 0, 120, { color = C.accent, outline = true })
	local hit = Ui.hit(bubble)
	hit.Name = "Next"
	hit.Activated:Connect(function()
		if Talk.npc then
			Talk.next(Talk.npc)
		end
	end)
end

-- 말 한 토막이 말풍선에서 차지하는 크기(폭 · 줄 수)
function Talk.measure(text: string): (number, number)
	local fitted = pixelText.Fit(text, Talk.TEXT_W, Talk.LINES, "body")
	local w = pixelText.Measure(fitted, "body")
	return w, #string.split(fitted, "\n")
end

local function show()
	local text = lines[Talk.index]
	body:set(text)
	local tw, count = Talk.measure(text)
	local last = Talk.index >= #lines
	local hintText = if last and endHint then endHint elseif last then "닫기" else "다음"
	local w = math.max(tw, 60) + B.padX * 2
	local h = (count - 1) * LINE + 14 + B.padY * 2 -- 글 한 줄의 칸이 13(내림선 포함)
	size.w, size.h = w, h
	back.Size = UDim2.fromOffset(w, h + 2) -- 아래 두 점은 그림자
	bubble.Size = UDim2.fromOffset(w, h + B.tail)
	more.Position = UDim2.fromOffset(w - 10, h - 9)
	more.Visible = not last
	-- 말풍선 아래 오른쪽: 키 딱지와 그 키가 지금 하는 일
	hint:set(hintText)
	local hw = Ui.measure(hintText)
	hint:move(w - hw, h + 7)
	hint:color(if last and endHint then C.accent else C.text)
	key:move(w - hw - 5 - math.floor(key.width / 2), h + 5)
	if not root.Visible and Talk.onToggle then
		Talk.onToggle(Talk.npc)
	end
	root.Visible = true
	Talk.place()
end

-- 말풍선을 그 주민 머리 위에 놓는다(화면마다 — 카메라가 움직이면 따라간다). 화면 밖으로 나가지 않게 옆으로 민다(꼬리는 주민 쪽에 남는다)
function Talk.place()
	local npc = Talk.npc
	if not npc or not root.Visible then
		return
	end
	local cx = Overlay.x(npc.x)
	local bottom = Overlay.y(npc.y - (npc.h or 24) - B.up)
	local left = math.clamp(cx - math.floor(size.w / 2), 8, math.max(8, Stage.uiW - size.w - 8))
	bubble.Position = UDim2.fromOffset(left, bottom - size.h - B.tail)
	tail.Position = UDim2.fromOffset(math.clamp(cx - left - 4, 6, size.w - 15), size.h - 1)
end

-- 말을 시작한다. questName = 말풍선 위에 적을 글(퀘스트 이름) · finish = 마지막 말 뒤에 일어날 일 · finishHint = 그 일의 이름(「받는다」)
function Talk.start(npc, list: { string }, questName: string?, finish: (() -> ())?, finishHint: string?)
	Talk.npc, Talk.index = npc, 1
	lines, onEnd, endHint = list, finish, finishHint
	title:set(questName or "")
	show()
end

-- 지금 이 주민과 말하는 중인가
function Talk.with(npc): boolean
	return Talk.npc == npc and Talk.index > 0
end

-- 다음 말로(말하는 중이 아니면 그 주민의 평소 말을 시작한다). 대화가 끝났으면 false.
function Talk.next(npc): boolean
	if Talk.npc ~= npc then
		Talk.start(npc, npc.lines)
		return true
	end
	Talk.index += 1
	if Talk.index > #lines then
		local finish = onEnd
		Talk.close()
		if finish then
			finish()
		end
		return false
	end
	show()
	return true
end

function Talk.close()
	Talk.npc, Talk.index = nil, 0
	lines, onEnd, endHint = {}, nil, nil
	if root then
		if root.Visible and Talk.onToggle then
			Talk.onToggle(nil)
		end
		root.Visible = false
	end
end

return Talk
