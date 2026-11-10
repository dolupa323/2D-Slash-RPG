-- 채팅의 글 목록 · 줄 나누기 · 스크롤의 셈(2026-11-06 사용자: "이제 로블록스 채팅이 아닌 우리 게임 자체 채팅구현하자").
--  그리는 것은 client/lune/chat.luau, 치수와 글은 data/ui.generated.luau의 chatUi(공방 js/lune/design/ui.js의 CHATUI · chatLayout).
--  공방의 시험 탭은 js/lune/ui/paint.js의 chatRows · chatPanel로 같은 셈을 한다.
--  글 하나 = { kind = "near"(일반 — 같은 맵) | "party"(파티) | "note"(알림 — 게임 · Roblox가 이 사람에게만 알리는 글), name = 캐릭터의 이름(알림은 nil), text }
--  한 줄 = { head = 앞머리(「[파티] 이름: 」 — 첫 줄에만), body = 나머지 글, kind }. 색은 그리는 쪽이 kind로 고른다(chatUi.nameColor · textColor · noteColor · party.color)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage.shared.lune.data["ui.generated"])

local K = UI.chatUi

local Log = {}
Log.K = K
Log.KINDS = { near = true, party = true, note = true }

-- 깨진 UTF-8(반쪽 글자)은 「?」로 — 글자를 셀 때 오류가 나지 않게(글씨 모듈 pixelText의 clean과 같은 법)
local function mend(text: string): string
	if utf8.len(text) then
		return text
	end
	local out, i = {}, 1
	while i <= #text do
		local n, bad = utf8.len(text, i)
		if n then
			table.insert(out, string.sub(text, i))
			break
		end
		table.insert(out, string.sub(text, i, (bad :: number) - 1))
		table.insert(out, "?")
		i = (bad :: number) + 1
	end
	return table.concat(out)
end

-- 받은 글 · 보낼 글을 다듬는다: Roblox가 꾸밈 글자로 바꿔 보낸 것(&lt; …)을 되돌리고, rich면 꾸밈 꼬리표(<font …>)를 지우고(Roblox의 알림 글),
--  줄바꿈 · 탭은 빈칸으로, 앞뒤의 빈칸을 지운다(ASCII 빈칸만 — %s는 한글의 가운데 바이트를 빈칸으로 볼 수 있다: 2026-10-21 오류 보고)
local ENTITY = { lt = "<", gt = ">", amp = "&", quot = '"', apos = "'" }
function Log.clean(text: any, rich: boolean?): string
	if typeof(text) ~= "string" then
		return ""
	end
	text = mend(text)
	if rich then
		text = string.gsub(text, "<[^<>]*>", "")
	end
	text = string.gsub(text, "&(%a+);", function(name)
		return ENTITY[name]
	end)
	text = string.gsub(text, "[\r\n\t]", " ")
	text = string.gsub(text, "^ +", "")
	text = string.gsub(text, " +$", "")
	return text
end

-- 글자 수(n)까지만(넘으면 자른다 — 보내는 글: chatUi.maxLen)
function Log.cut(text: string, n: number): string
	local len = utf8.len(text)
	if not len or len <= n then
		return text
	end
	return string.sub(text, 1, (utf8.offset(text, n + 1) or (#text + 1)) - 1)
end

function Log.new()
	return { list = {} :: { any } }
end

-- 글 하나를 더한다(빈 글은 넣지 않는다). keep개를 넘으면 오래된 것부터 버린다. 돌려주는 것: 넣은 글(없으면 nil)
function Log.add(log, kind: string, name: string?, text: string)
	if not Log.KINDS[kind] or typeof(text) ~= "string" or text == "" then
		return nil
	end
	local e = { kind = kind, name = if kind == "note" then nil else name, text = text }
	table.insert(log.list, e)
	while #log.list > K.keep do
		table.remove(log.list, 1)
	end
	return e
end

-- 그 탭에 보이는 글인가(전체 = 모두)
function Log.shows(tab: string, kind: string): boolean
	return tab == "all" or tab == kind
end

-- 앞머리: 「이름: 」 · 파티면 「[파티] 이름: 」(tag = 이미 그 사람의 언어로 바꾼 꼬리표) · 알림은 없다
function Log.head(e, tag: string): string
	if e.kind == "note" or typeof(e.name) ~= "string" or e.name == "" then
		return ""
	end
	return (if e.kind == "party" then tag .. " " else "") .. e.name .. ": "
end

-- 글 하나의 줄들(width 폭에서 wrap이 나눈다 — wrap(글, 폭) → 줄바꿈으로 이은 글). 같은 폭 · 꼬리표면 전에 나눈 것을 그대로 쓴다
function Log.split(e, width: number, wrap: (string, number) -> string, tag: string)
	if e.rows and e.rowsW == width and e.rowsTag == tag then
		return e.rows
	end
	local head = Log.head(e, tag)
	local rows = {}
	for i, line in string.split(wrap(head .. e.text, width), "\n") do
		if i == 1 and head ~= "" then
			if string.sub(line, 1, #head) == head then
				rows[i] = { head = head, body = string.sub(line, #head + 1), kind = e.kind }
			else
				rows[i] = { head = line, body = "", kind = e.kind } -- 이름 뒤에서 바로 줄이 바뀌었다(「이름:」만 첫 줄에)
			end
		else
			rows[i] = { head = "", body = line, kind = e.kind }
		end
	end
	e.rows, e.rowsW, e.rowsTag = rows, width, tag
	return rows
end

-- 그 탭의 모든 줄(오래된 것부터)
function Log.rows(log, tab: string, width: number, wrap: (string, number) -> string, tag: string): { any }
	local out = {}
	for _, e in log.list do
		if Log.shows(tab, e.kind) then
			for _, r in Log.split(e, width, wrap, tag) do
				table.insert(out, r)
			end
		end
	end
	return out
end

-- 보이는 줄: 줄이 total개 · 칸이 n줄 · 맨 아래에서 scroll줄 올려 보는 중. 돌려주는 것: 첫 줄의 차례(1부터) · 고친 scroll · 올릴 수 있는 끝
function Log.view(total: number, n: number, scroll: number): (number, number, number)
	local top = math.max(0, total - n)
	scroll = math.clamp(math.floor(scroll), 0, top)
	return math.max(1, total - n - scroll + 1), scroll, top
end

-- 스크롤 막대: 칸의 높이 h에서 막대(위 · 길이). 줄이 칸보다 적으면 nil
function Log.thumb(total: number, n: number, scroll: number, h: number): (number?, number?)
	if total <= n then
		return nil, nil
	end
	local len = math.max(6, math.floor(h * n / total))
	local top = total - n
	return math.floor((h - len) * (top - math.clamp(scroll, 0, top)) / top + 0.5), len
end

-- 보내지 못한 까닭(TextChatMessageStatus의 이름) → 알림 글
function Log.failText(status: string?): string
	return K.fail[status or ""] or K.fail.other
end

-- 판 안의 자리: mode = "small" · "big" · "touch"
function Log.layout(mode: string)
	return K.layout[mode] or K.layout.small
end

return Log
