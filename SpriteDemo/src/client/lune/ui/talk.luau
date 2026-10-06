-- 주민과의 대화 — 화면 위쪽의 말 상자(서 있는 주민과 주인공을 가리지 않는 자리). 주민 앞에서 ↑를 누르면 뜨고, 한 번 더 누르면 다음 말, 마지막 말 뒤에는 닫힌다.
--  모양은 메이플의 대화 창처럼: 어두운 틀 안의 밝은 판 — 왼쪽에 주민의 얼굴 칸, 오른쪽에 이름표와 말(본문 글씨 두 줄), 아래 줄에 단추(↑ 다음 · ↑ 받는다).
--  말은 장면 자료(공방 js/lune/design/town.js에서 내보낸 것)의 lines, 또는 퀘스트의 대사(받을 때 · 하는 중 · 돌려줄 때 — data/quests.generated.luau).
--  퀘스트의 대사는 마지막 말에서 ↑(또는 단추)를 누르면 그 일(받기 · 돌려주기)이 일어난다 — 그 전에 자리를 뜨면 아무 일도 없다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage.shared.lune.ui.format)
local Stage = require(script.Parent.Parent.stage)
local Kit = require(script.Parent.kit)

local C = Kit.COLOR
local BOX = Format.TALK -- 자리는 shared/lune/ui/format.luau(자동 검사가 화면 칸과 겹치지 않는지 · 말이 두 줄에 들어가는지 본다)

local Talk = {}
Talk.npc = nil :: any
Talk.index = 0
Talk.TEXT_W = BOX.textW
Talk.LINES = BOX.lines
Talk.HINT_W = 68 -- 「↑ 끝낸다」가 들어가는 단추의 폭
Talk.onToggle = nil :: ((boolean) -> ())? -- 말 상자가 열리고 닫힐 때(퀘스트 알리미가 그동안 숨는다)
Talk.sheet = nil :: any -- 주민 그림판 { image, w, h } — 장면이 바뀔 때 boot가 알려 준다(얼굴 칸에 그 주민을 그린다)

local root, nameTab, nameText, title, body, page, button, face
local lines: { string } = {}
local onEnd: (() -> ())? = nil
local endHint: string? = nil

function Talk.init()
	root = Stage.group(Stage.view, "Talk", 140)
	root.Visible = false
	local box = Kit.group(root, BOX.x, BOX.y, BOX.w, BOX.h)
	box.Name = "Box"
	Kit.part(box, "frame", 0, 0, BOX.w, BOX.h)
	Kit.part(box, "paper", 4, 4, BOX.w - 8, BOX.h - 22)
	-- 얼굴 칸
	Kit.part(box, "socket", 8, 8, 36, 36)
	face = Instance.new("ImageLabel")
	face.Name = "Face"
	face.BackgroundTransparency = 1
	face.ResampleMode = Enum.ResamplerMode.Pixelated
	face.ZIndex = 2
	face.Parent = box
	-- 이름표 · 퀘스트 이름 · 말
	nameTab = Kit.part(box, "tabOff", BOX.textX, 7, 30, 12)
	nameText = Kit.text(box, "", BOX.textX + 5, 9, 100, { color = C.white })
	title = Kit.text(box, "", BOX.textX + 40, 9, 100, { color = C.blueLo })
	Kit.box(box, BOX.textX, 19, BOX.w - BOX.textX - 8, 1, C.tabOff)
	body = Kit.text(box, "", BOX.textX + 1, 22, Talk.TEXT_W, { font = "body", lines = Talk.LINES, color = C.ink })
	-- 아래 줄: 몇째 말인가 · 단추(눌러도 ↑와 같다)
	page = Kit.text(box, "", 8, BOX.h - 14, 60, { color = C.dim })
	button = Kit.button(box, "↑ 다음", BOX.w - 6 - Talk.HINT_W, BOX.h - 17, Talk.HINT_W, 13, function()
		if Talk.npc then
			Talk.next(Talk.npc)
		end
	end)
	button.frame.Name = "Next"
end

local function show()
	body:set(lines[Talk.index])
	local last = Talk.index >= #lines
	button:setText(if last and endHint then "↑ " .. endHint elseif last then "↑ 닫기" else "↑ 다음")
	button:setKind(if last and endHint then "orange" else "blue")
	page:set(if #lines > 1 then ("%d / %d"):format(Talk.index, #lines) else "")
	if not root.Visible and Talk.onToggle then
		Talk.onToggle(true)
	end
	root.Visible = true
end

-- 말을 시작한다. title = 이름표 옆에 덧붙일 글(퀘스트 이름) · finish = 마지막 말 뒤에 일어날 일 · finishHint = 그 일의 이름(「받는다」)
function Talk.start(npc, list: { string }, questName: string?, finish: (() -> ())?, finishHint: string?)
	Talk.npc, Talk.index = npc, 1
	lines, onEnd, endHint = list, finish, finishHint
	local who = ("%s %s"):format(npc.role, npc.name)
	local tabW = Kit.measure(who) + 10
	nameText:set(who)
	nameTab.Size = UDim2.fromOffset(tabW, 12)
	local titleW = BOX.w - BOX.textX - 8 - tabW - 6
	title.label:SetMaxWidth(titleW, 1)
	title:set(questName or "")
	title:move(BOX.textX + tabW + 5, 9)
	-- 얼굴 칸에 그 주민(서 있는 첫 장)
	local sheet = Talk.sheet
	face.Visible = sheet ~= nil and npc.cell ~= nil
	if face.Visible then
		face.Image = sheet.image
		face.Size = UDim2.fromOffset(sheet.w, sheet.h)
		face.Position = UDim2.fromOffset(8 + math.floor((36 - sheet.w) / 2), 8 + 36 - 3 - sheet.h)
		face.ImageRectOffset = Vector2.new(npc.cell * sheet.w, 0)
		face.ImageRectSize = Vector2.new(sheet.w, sheet.h)
	end
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
			Talk.onToggle(false)
		end
		root.Visible = false
	end
end

return Talk
