-- 채팅 한 줄 미리 보기(폰 단추 배치 「바로가기」 — 2026-11-13 사용자: "다른 대형 상용 rpg 들중에 모바일 ui 공부한뒤에 우리 모바일 ui도 조금더 편하게 개편한다").
--  폰에서는 채팅 판이 「채팅」 단추로만 열려 닫혀 있는 동안 남의 글은 노란 점뿐이었다. 모바일 RPG(메이플스토리M 등)는 화면 한쪽에 최근 채팅 한두 줄을 늘 띄운다.
--  그래서: 바로가기 배치에서 판이 닫혀 있는 동안 남의 글이 오면 「채팅」 단추 아래에 한 줄(이름: 글 — 길면 「…」)을 SHOW초 동안 띄운다 · 판을 열면 바로 숨긴다.
--  새 배치 · 예전 배치는 그대로(노란 점만). 자리 · 초는 제가 정한 것
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)

local ChatPeek = {}
ChatPeek.on = nil :: boolean? -- 시험이 켠다(nil이면 바로가기 판의 상태 — touchBar.luau의 on · touch)
ChatPeek.SHOW = 6
ChatPeek.RECT = { at = "tl", x = 104, y = 54, w = 320, h = 14 } -- (「채팅」 단추 아래 · 획득 알림(y 100) 위)
local holder: Frame? = nil
local label: any = nil
local token = 0

-- 줄에 적을 글(셈만 — 시험이 본다): 이름이 있으면 「이름: 글」
function ChatPeek.line(name: string?, text: string): string
	return if name and name ~= "" then name .. ": " .. text else text
end

function ChatPeek.show(kind: string, name: string?, text: string)
	local on = ChatPeek.on
	if on == nil then
		local TB = require(script.Parent.touchBar)
		on = TB.on and TB.touch
	end
	if not on or typeof(text) ~= "string" or text == "" then
		return
	end
	local R = ChatPeek.RECT
	if not holder then
		holder = Stage.place(Stage.ui, "ChatPeek", R.at, R.x, R.y, R.w, R.h)
		holder.ZIndex = 118
		label = Ui.text(holder, "", 0, 0, R.w, { font = "small", outline = true, lines = 1 })
	end
	label:set(ChatPeek.line(name, text))
	label:color(if kind == "party" then Ui.COLOR.accent else Ui.COLOR.text)
	holder.Visible = true
	token += 1
	local mine = token
	task.delay(ChatPeek.SHOW, function()
		if token == mine and holder then
			holder.Visible = false
		end
	end)
end

function ChatPeek.hide()
	token += 1
	if holder then
		holder.Visible = false
	end
end


return ChatPeek
