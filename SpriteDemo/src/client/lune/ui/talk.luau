-- 주민과의 대화 — 둘로 나눈다(2026-10-14):
--  사용자: "npc 대화 뜨는건 그냥 idle 일때 혼잣말할때만 말풍선 형태로 말하고 상호작용해서 퀘스트 받거나 대화할때는 일반 도트 게임처럼 … 대화창이떠서 말을 듣는"
--  둘째 판(같은 날): "대화창 색감이 우리 게임 ui와 맞지않습니다. 그리고 글씨는 한글자씩 도트게임스타일로 … 캐릭터이미지 안떠도 됩니다. 그리고 좌우로 너무 대화창 넓습니다.
--    또, 모바일에서도 정확히 나오게 크로스 플랫폼 고려해서"
--  ① 대화창(Talk.start · next · accept · decline · close): ↑로 말을 걸면 화면 아래 가운데의 어두운 판(창과 같은 판 uPanel). 판의 위 테두리에 이름표(어두운 판 · 민트 테두리 · 흰 이름 + 노랑 퀘스트 이름),
--     대사는 한 글자씩(DIALOG.cps) · 강조 낱말(몬스터 · 물건 · 곳 · 사람)은 민트. 말이 다 나오면 오른쪽 아래에 「↑ 다음 · 닫기 · 완료」, 받을 퀘스트의 마지막 말이면 「수락 · 거절」 단추.
--     나오는 중에 ↑ · 스페이스 · 판을 누르면 그 말이 한 번에 다 나오고, 한 번 더 누르면 다음 말. X · Esc = 거절(닫기). 판 · 단추를 눌러도 같다(스마트폰).
--     폭은 DIALOG.w(화면 틀이 좁으면 양옆 margin을 남기고 줄인다) — 화면 틀이 바뀌면(창 크기 · 폰을 돌림) 매 화면 다시 놓는다(Talk.place).
--  ② 혼잣말(Talk.say): 주민 머리 위의 흰 말풍선(산나비처럼) — 단추 · 안내 없이 한 줄, IDLE.show초 뒤에 사라진다. 누가 언제 말할지는 boot.luau가 정한다(IDLE).
--  모양은 공방 시험 탭(js/lune/ui/paint.js의 dialog · bubble)과 같게 짓는다. 값은 공방 js/lune/design/ui.js의 DIALOG · BUBBLE · IDLE(→ shared/lune/ui/format.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Format = require(ReplicatedStorage.shared.lune.ui.format)
local pixelText = require(script.Parent.Parent.Parent.modules.ui.pixelText)
local Stage = require(script.Parent.Parent.stage)
local Overlay = require(script.Parent.Parent.overlay)
local Ui = require(script.Parent.ui)
local WORDS = require(ReplicatedStorage.shared.lune.data["ui.generated"]).words

local C = Ui.COLOR
local M = Ui.M
local B = Format.BUBBLE -- 혼잣말 말풍선(자동 검사가 주민의 말이 이 폭 · 줄 수에 들어가는지 본다)
local D = Format.DIALOG -- 대화창
local LINE = M.bodyLine
local MAX_SEGS = 8 -- 한 줄에 나뉘는 조각(강조 낱말 앞뒤)의 수 — 넘으면 나머지를 한 조각에 붙인다

local Talk = {}
Talk.npc = nil :: any
Talk.index = 0
Talk.TEXT_W = Format.DIALOG_TEXT_W -- 대화창 대사의 폭(자동 검사가 퀘스트 대사가 이 폭 · 줄 수에 들어가는지 본다)
Talk.LINES = D.lines
Talk.BUBBLE_W = B.textW
Talk.onFinish = nil :: ((any) -> ())? -- 대화를 끝까지 들었다(마지막 말 뒤에 넘겼다 — 튜토리얼의 「말 걸기」 미션)
Talk.onToggle = nil :: ((any) -> ())? -- 대화창이 뜨고 닫힐 때(뜨면 그 주민, 닫히면 nil) — 머리 위 퀘스트 표시 · 아래쪽 화면 · 터치 단추를 그동안 숨긴다
-- 여러 사람이 말하는 대화(2026-10-15 — 퀘스트 연출): 말 앞에 「@id 」가 붙으면 그 사람의 이름표로 바꾼다(@hero = 내 캐릭터). 이름은 boot.luau가 알려 준다
Talk.nameOf = nil :: ((string) -> string?)?
Talk.CINE = { id = "__cine", name = "", x = 0, y = 0, cine = true } -- 장면(cineView.luau)이 대화창에 말을 띄울 때의 「주민」 — 이름은 말마다 바뀐다

local root: Frame
-- 대화창
local box: Frame
local panel: Frame
local plateEdge: { Frame }, plateIn: Frame
local nameText, titleText
local rows: { { any } } = {} -- 줄마다 조각 글
local hintText, hintKey
local acceptBtn, declineBtn
local lines: { string } = {}
local onEnd: (() -> ())? = nil
local endHint: string? = nil
local started = 0 -- 지금 말이 나오기 시작한 때(os.clock)
local fitted: { string } = {} -- 지금 말을 폭에 맞춰 바꾼 줄들
local total = 0 -- 지금 말의 글자 수
local drawn = -1 -- 그려 둔 글자 수(바뀔 때만 다시 그린다)
local layoutKey = "" -- 놓은 화면 틀(바뀌면 다시 놓는다)
local nameStr, hintStr = "", "" -- 이름표의 이름 · 아래 줄의 안내(폭을 재는 데 쓴다)
local baseName = "" -- 말을 건 주민의 이름(「@id 」가 붙은 말이 끝나면 이 이름으로 돌아온다)
local curText = "" -- 지금 말(「@id 」를 뗀 것)
-- 고르는 말(Talk.menu — 2026-10-18, 메이플스토리의 NPC 대화처럼): 한 주민에게 할 일이 둘 넘게 있으면 줄마다 하나씩 보이고 고른다
local menuItems: { any }? = nil -- 지금 고르는 줄들 { text, color } — nil이면 고르는 중이 아니다
local menuPick: ((number) -> ())? = nil
local menuSel = 1
local menuRows = {} -- 줄마다 글
local menuHits = {} -- 줄마다 누르는 판(스마트폰 · 마우스)
local menuBar: Frame -- 고른 줄 밑의 띠
-- 혼잣말
local chat: Frame
local chatBack, chatTail, chatBody
local chatNpc: any = nil
local chatTill = 0
local chatSize = { w = 0, h = 0 }

local function utf8len(s: string): number
	return utf8.len(s) or #s
end

function Talk.init()
	root = Stage.group(Overlay.root, "Talk", 60)
	-- ① 대화창
	box = Ui.group(root, 0, 0, 1, 1, "Dialog")
	box.Visible = false
	panel = Ui.panel(box, 0, 0, 1, 1)
	local hit = Ui.hit(box) -- 판 아무 데나 누르면 다음(스마트폰) — 단추는 이 위에 놓는다
	hit.Name = "Next"
	hit.Activated:Connect(function()
		if Talk.npc and Talk.npc ~= Talk.CINE then -- 장면의 말은 장면이 넘긴다(화면 위의 누르는 판 — cineView.luau)
			Talk.next(Talk.npc)
		end
	end)
	-- 이름표: 민트 한 점 테두리(모서리 한 점 깎기 — 사각형 둘을 겹친다) · 어두운 속
	plateEdge = { Ui.box(box, 0, 0, 1, 1, C.accent), Ui.box(box, 0, 0, 1, 1, C.accent) }
	plateIn = Ui.box(box, 0, 0, 1, 1, C.ink)
	nameText = Ui.text(box, "", 0, 0, 200, { font = "body", color = C.text })
	titleText = Ui.text(box, "", 0, 0, 240, { color = C.gold })
	for r = 1, D.lines do
		rows[r] = {}
		for k = 1, MAX_SEGS do
			rows[r][k] = Ui.text(box, "", 0, 0, 2000, { font = "body", color = C.text })
		end
	end
	-- 고르는 말의 줄: 고른 줄 밑에 어두운 민트 띠 · 줄을 누르면 그것을 고른다
	menuBar = Ui.box(box, 0, 0, 1, 1, C.accentDark)
	menuBar.Visible = false
	for r = 1, D.lines do
		menuRows[r] = Ui.text(box, "", 0, 0, 2000, { font = "body", color = C.text })
		menuRows[r]:show(false)
		local holder = Ui.group(box, 0, 0, 1, 1, "MenuRow" .. r)
		holder.ZIndex = 10
		holder.Visible = false
		Ui.hit(holder).Activated:Connect(function()
			if menuItems and Talk.npc and r <= #menuItems then
				menuSel = r
				Talk.next(Talk.npc)
			end
		end)
		menuHits[r] = holder
	end
	hintText = Ui.text(box, "", 0, 0, 120, { color = C.dim })
	hintKey = Ui.keycap(box, "↑", 0, 0)
	acceptBtn = Ui.button(box, WORDS.accept or "수락", 0, 0, D.button[1], function()
		Talk.accept()
	end, { main = true, h = D.button[2] })
	declineBtn = Ui.button(box, WORDS.decline or "거절", 0, 0, D.button[1], function()
		Talk.decline()
	end, { h = D.button[2] })
	-- X · Esc = 거절(닫기) — 대화창이 떠 있을 때만
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not Talk.npc or Talk.npc == Talk.CINE then -- 장면의 말: Esc는 장면의 건너뛰기(cineView.luau)
			return
		end
		if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Escape then
			Talk.decline()
		end
	end)
	-- ② 혼잣말 말풍선
	chat = Ui.group(root, 0, 0, 1, 1, "Chat")
	chat.Visible = false
	chatBack = Ui.part(chat, "uBubble", 0, 0, 12, 14)
	chatTail = Ui.part(chat, "uTail", 0, 0)
	chatTail.ZIndex = 2
	chatBody = Ui.text(chat, "", B.padX, B.padY, B.textW, { font = "body", lines = B.lines, line = LINE, color = C.bubbleInk, z = 3 })
end

-- 대화창의 자리와 크기: 화면 아래 가운데 · 폭 = DIALOG.w(좁은 화면 틀이면 양옆 margin을 남기고 줄인다)
local function dims()
	local w = math.min(D.w, Stage.uiW - D.margin * 2)
	local h = D.padY + D.lines * LINE + D.foot
	return math.floor((Stage.uiW - w) / 2), Stage.uiH - D.bottom - h, w, h
end

-- 버튼 · 안내 · 이름표의 자리(화면 틀이 바뀌거나 말이 바뀔 때)
local function layout()
	local x, y, w, h = dims()
	box.Position = UDim2.fromOffset(x, y)
	box.Size = UDim2.fromOffset(w, h)
	panel.Size = UDim2.fromOffset(w, h)
	panel:FindFirstChild("Back").Size = UDim2.fromOffset(w, h)
	-- 이름표: 판의 위 테두리에 걸친다
	local nameW = Ui.measure(nameStr, "body")
	local tW = select(1, titleText:size())
	local titleW = if tW > 0 then math.min(tW, w - nameW - 60) + 12 else 0
	local pw, ph, px, py = nameW + 12 + titleW, D.plateH, D.padX - 6, -math.floor(D.plateH / 2)
	plateEdge[1].Position, plateEdge[1].Size = UDim2.fromOffset(px + 1, py), UDim2.fromOffset(pw - 2, ph)
	plateEdge[2].Position, plateEdge[2].Size = UDim2.fromOffset(px, py + 1), UDim2.fromOffset(pw, ph - 2)
	plateIn.Position, plateIn.Size = UDim2.fromOffset(px + 1, py + 1), UDim2.fromOffset(pw - 2, ph - 2)
	local plate = nameStr ~= "" -- 이름이 없는 말(장면의 속마음)은 이름표를 달지 않는다
	plateEdge[1].Visible, plateEdge[2].Visible, plateIn.Visible = plate, plate, plate
	nameText:show(plate)
	titleText:show(plate)
	nameText:move(D.padX, py + math.floor((ph - M.body) / 2))
	titleText:move(D.padX + nameW + 12, py + math.floor((ph - M.small) / 2))
	-- 아래 줄: 「수락 · 거절」 또는 「↑ 다음」
	local bw, bh = D.button[1], D.button[2]
	local cy = h - bh - 6
	local dx = w - D.padX - bw
	declineBtn.frame.Position = UDim2.fromOffset(dx, cy)
	acceptBtn.frame.Position = UDim2.fromOffset(dx - 8 - bw, cy)
	local hw = Ui.measure(hintStr)
	hintText:move(w - D.padX - hw, cy + 8)
	hintKey:move(w - D.padX - hw - 12, cy + 6)
	-- 고르는 말의 줄 · 띠 · 누르는 판
	for r = 1, D.lines do
		local ty = D.padY + (r - 1) * LINE
		menuRows[r]:move(D.padX + 8, ty)
		menuHits[r].Position = UDim2.fromOffset(D.padX - 4, ty - 3)
		menuHits[r].Size = UDim2.fromOffset(w - D.padX * 2 + 8, LINE)
	end
	if menuItems then
		menuBar.Position = UDim2.fromOffset(D.padX - 4, D.padY + (menuSel - 1) * LINE - 3)
		menuBar.Size = UDim2.fromOffset(w - D.padX * 2 + 8, LINE)
	end
end

-- 고르는 말을 그린다(줄 · 고른 줄의 띠) — 고르는 중이 아니면 모두 감춘다
local function paintMenu()
	for r = 1, D.lines do
		local item = menuItems and menuItems[r]
		menuRows[r]:set(if item then item.text else "")
		if item then
			menuRows[r]:color(item.color or C.text)
		end
		menuRows[r]:show(item ~= nil)
		menuHits[r].Visible = item ~= nil
	end
	menuBar.Visible = menuItems ~= nil
end

-- 대사를 나온 글자까지 그린다(줄은 다 나왔을 때의 자리 그대로 — 한 글자씩 나와도 줄이 바뀌거나 출렁이지 않는다)
local function paintText(shown: number)
	if menuItems then -- 고르는 말: 대사 줄은 비운다(줄마다 고를 것이 선다)
		for r = 1, D.lines do
			for k = 1, MAX_SEGS do
				rows[r][k]:set("")
				rows[r][k]:show(false)
			end
		end
		return
	end
	local segs = Format.talkSegments(curText, fitted, shown)
	for r = 1, D.lines do
		local list = segs[r] or {}
		local cx = D.padX
		local ty = D.padY + (r - 1) * LINE
		for k = 1, MAX_SEGS do
			local item = rows[r][k]
			local seg = list[k]
			if seg and k == MAX_SEGS and #list > MAX_SEGS then -- 조각이 너무 많으면 나머지를 이 조각에 붙인다(색은 앞의 것)
				local rest = {}
				for q = k, #list do
					table.insert(rest, list[q].t)
				end
				seg = { t = table.concat(rest), key = false }
			end
			if seg then
				item:set(seg.t)
				item:color(if seg.key then C.accent else C.text)
				item:move(cx, ty)
				item:show(true)
				cx += Ui.measure(seg.t, "body")
			else
				item:set("")
				item:show(false)
			end
		end
	end
end

local function full(): boolean
	return drawn >= total
end

-- 말이 다 나왔을 때의 아래 줄
local function paintFoot()
	local last = Talk.index >= #lines
	local done = full()
	local offer = done and last and endHint == "수락"
	acceptBtn.frame.Visible = offer
	declineBtn.frame.Visible = offer
	hintStr = if menuItems then "고르기" elseif Talk.npc == Talk.CINE then "다음" elseif last and endHint then endHint elseif last then "닫기" else "다음" -- 장면의 말은 늘 「다음」(장면이 이어진다)
	hintText:set(hintStr)
	hintText:color(if last and endHint then C.accent else C.dim)
	layout() -- 자리를 먼저 놓고(키 딱지는 자리를 옮기면 다시 보인다) 보일지를 정한다
	hintText:show(done and not offer)
	hintKey.frame.Visible = done and not offer
end

-- 말 앞의 「@id 」: 그 사람의 이름과 뗀 말(없으면 nil과 그 말 그대로)
function Talk.speaker(text: string): (string?, string)
	local id, rest = string.match(text, "^@(%w+) (.*)$")
	if id then
		return (Talk.nameOf and Talk.nameOf(id)) or id, rest
	end
	return nil, text
end

local function show()
	local who, text = Talk.speaker(lines[Talk.index] or "")
	curText = text
	nameStr = who or baseName
	nameText:set(nameStr)
	fitted = string.split(pixelText.Fit(text, Talk.TEXT_W, D.lines, "body"), "\n")
	total = 0
	for _, ln in fitted do
		total += utf8len(ln)
	end
	started, drawn = os.clock(), -1
	if not box.Visible and Talk.onToggle then
		Talk.onToggle(Talk.npc)
	end
	box.Visible = true
	layoutKey = ""
	Talk.place()
end

-- 매 화면: 글자를 한 글자씩 내보내고, 화면 틀이 바뀌었으면 다시 놓고, 혼잣말 말풍선은 그 주민을 따라간다
function Talk.place()
	if box and box.Visible then
		local key = Stage.uiW .. "x" .. Stage.uiH
		if key ~= layoutKey then
			layoutKey = key
			paintFoot() -- 다시 놓고 아래 줄의 보임도 다시 정한다
		end
		local shown = math.min(total, math.floor((os.clock() - started) * D.cps))
		if shown ~= drawn then
			drawn = shown
			paintText(shown)
			paintFoot()
		end
	end
	if chat and chatNpc then
		if os.clock() > chatTill or chatNpc == Talk.npc then
			chat.Visible, chatNpc = false, nil
		else
			-- 말풍선은 그 주민의 머리 위 그대로(2026-10-21 사용자 "npc 가 보이지않는 영역까지 가면 말풍선만 끌려서 와버립니다. 말풍선은 npc 위치에 있어야하는데" —
			--  전에는 화면 안쪽으로 붙잡아(clamp) 주민이 화면 밖으로 나가도 말풍선이 화면 가장자리에 남아 캐릭터를 따라왔다). 주민이 화면 밖이면 숨기고, 다시 보이면 남은 시간만큼 다시 뜬다
			local cx = Overlay.x(chatNpc.x)
			local bottom = Overlay.y(chatNpc.y - (chatNpc.h or 24) - B.up)
			local left = cx - math.floor(chatSize.w / 2)
			chat.Position = UDim2.fromOffset(left, bottom - chatSize.h - B.tail)
			chatTail.Position = UDim2.fromOffset(math.floor(chatSize.w / 2) - 4, chatSize.h - 1)
			chat.Visible = cx >= 0 and cx <= Stage.uiW -- 주민(말풍선의 꼬리)이 화면 안에 있을 때만
		end
	end
end

-- 말을 시작한다. questName = 이름표 뒤의 퀘스트 이름 · finish = 마지막 말 뒤에 일어날 일 · finishHint = 그 일의 이름(「수락」이면 「수락 · 거절」 단추, 「완료」면 「↑ 완료」)
function Talk.start(npc, list: { string }, questName: string?, finish: (() -> ())?, finishHint: string?)
	-- 고르는 말이 떠 있던 중에 다른 말(장면 · 이야기)이 오면 고르는 말을 걷는다 — 남아 있으면 말이 비고 다음 ↑가 옛 고르기를 했다(2026-10-18 검토)
	if menuItems then
		menuItems, menuPick = nil, nil
		paintMenu()
	end
	Talk.npc, Talk.index = npc, 1
	lines, onEnd, endHint = list, finish, finishHint
	baseName = npc.name or npc.id or ""
	nameStr = baseName
	nameText:set(nameStr)
	titleText:set(questName or "")
	if chatNpc == npc then
		chat.Visible, chatNpc = false, nil
	end
	show()
end

-- 장면(퀘스트 연출)의 한 말: name = 이름표(nil이면 이름표 없이 — 속마음) · text = 말. text가 nil이면 닫는다. 넘기는 것은 장면이 한다(Talk.cineFull · Talk.cineReveal)
function Talk.cine(name: string?, text: string?)
	if not text then
		if Talk.npc == Talk.CINE then
			Talk.close()
		end
		return
	end
	Talk.CINE.name = name or ""
	Talk.start(Talk.CINE, { text }, nil, nil, nil)
end
function Talk.cineFull(): boolean
	return full()
end
function Talk.cineReveal()
	started = os.clock() - 999
	Talk.place()
end

-- 고르는 말을 띄운다(2026-10-18): items = { { text, color } }(D.lines개까지 — 넘는 것은 버린다) · onPick(i) = 고른 줄
--  ↓ = 다음 줄(Talk.menuMove) · ↑ · 스페이스 = 고른다(Talk.next) · 줄을 누르면 그것 · X · Esc = 닫기
function Talk.menu(npc, items: { any }, onPick: (number) -> ())
	local list = {}
	for i = 1, math.min(#items, D.lines) do
		list[i] = items[i]
	end
	menuItems, menuPick, menuSel = list, onPick, 1
	Talk.npc, Talk.index = npc, 1
	lines, onEnd, endHint = { "" }, nil, nil
	baseName = npc.name or npc.id or ""
	nameStr = baseName
	nameText:set(nameStr)
	titleText:set("")
	if chatNpc == npc then
		chat.Visible, chatNpc = false, nil
	end
	paintMenu()
	show()
end

-- 고르는 중인가 · 고른 줄(자동 검사가 본다)
function Talk.inMenu(): boolean
	return menuItems ~= nil
end
function Talk.menuSelected(): number
	return menuSel
end

-- 고른 줄을 옮긴다(d = 1 아래 · -1 위 — 끝에서는 처음으로)
function Talk.menuMove(d: number)
	if not menuItems or #menuItems == 0 then
		return
	end
	menuSel = ((menuSel - 1 + d) % #menuItems) + 1
	layout()
end

-- 지금 이 주민과 말하는 중인가
function Talk.with(npc): boolean
	return Talk.npc == npc and Talk.index > 0
end

-- 다음 말로: 나오는 중이면 그 말을 한 번에 다 보이고, 다 나왔으면 다음 말(마지막 말 뒤에는 그 일 — 수락 · 완료). 말하는 중이 아니면 그 주민의 평소 말을 시작한다. 대화가 끝났으면 false
function Talk.next(npc): boolean
	if menuItems and Talk.npc == npc then -- 고르는 말: 고른 줄의 일을 한다(그 일이 새 말을 시작한다)
		local pick, i = menuPick, menuSel
		Talk.close()
		if pick then
			pick(i)
		end
		return true
	end
	if Talk.npc ~= npc then
		Talk.start(npc, npc.lines)
		return true
	end
	if not full() then
		started = os.clock() - 999
		Talk.place()
		return true
	end
	if Talk.index >= #lines then
		local finish = onEnd
		Talk.close()
		if Talk.onFinish then
			Talk.onFinish(npc)
		end
		if finish then
			finish()
		end
		return false
	end
	Talk.index += 1
	show()
	return true
end

-- 「수락」 단추(↑ · 스페이스와 같다)
function Talk.accept()
	if Talk.npc then
		Talk.next(Talk.npc)
	end
end

-- 「거절」 단추 · X · Esc: 나오는 중이면 그 말을 다 보이고, 다 나왔으면 아무 일도 하지 않고 닫는다(다시 말을 걸면 또 권한다)
function Talk.decline()
	if not Talk.npc then
		return
	end
	if not full() then
		started = os.clock() - 999
		Talk.place()
		return
	end
	Talk.close()
end

function Talk.close()
	Talk.npc, Talk.index = nil, 0
	lines, onEnd, endHint = {}, nil, nil
	if menuItems then
		menuItems, menuPick = nil, nil
		if menuBar then
			paintMenu()
		end
	end
	if box then
		if box.Visible and Talk.onToggle then
			Talk.onToggle(nil)
		end
		box.Visible = false
	end
end

-- 혼잣말: 그 주민 머리 위에 한 줄(단추 · 안내 없이) — seconds초 뒤에 사라진다. 대화창으로 말하는 주민은 혼잣말을 하지 않는다
function Talk.say(npc, text: string, seconds: number?)
	if not chat or npc == Talk.npc then
		return
	end
	chatBody:set(text)
	local fittedChat = pixelText.Fit(text, B.textW, B.lines, "body")
	local tw = pixelText.Measure(fittedChat, "body")
	local count = #string.split(fittedChat, "\n")
	local w = math.max(tw, 60) + B.padX * 2
	local h = (count - 1) * LINE + 14 + B.padY * 2
	chatSize.w, chatSize.h = w, h
	chatBack.Size = UDim2.fromOffset(w, h + 2)
	chat.Size = UDim2.fromOffset(w, h + B.tail)
	chatNpc, chatTill = npc, os.clock() + (seconds or Format.IDLE.show)
	chat.Visible = true
	Talk.place()
end

-- 혼잣말 말풍선을 바로 거둔다 — 장면(맵)을 바꿀 때(2026-10-15 사용자: "npc 가 혼잣말 하는데 다음포탈로 넘어가면 그 말풍선이 그대로 있는 문제" —
--  말풍선은 화면 틀의 층에 있어 맵을 지워도 남고, 시간이 다 될 때까지 옛 주민의 자리에 떠 있었다)
function Talk.hush()
	if chat then
		chat.Visible, chatNpc, chatTill = false, nil, 0
	end
end

-- 지금 혼잣말을 하는 주민(없으면 nil)
function Talk.saying(): any
	return if chat and chatNpc and os.clock() <= chatTill then chatNpc else nil
end

-- 대화창의 자리(화면 틀의 점 — 자동 검사 · 터치가 쓴다)
function Talk.rect(): (number, number, number, number)
	return dims()
end

return Talk
