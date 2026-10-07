-- 이름표와 채팅 줄의 셈(그리지는 않는다). 테스트 14가 본다.
local T = {}

-- 이름표가 겹칠 때: 아무것도 옮기지 않는다 — 이름은 늘 제 주인의 발밑 그 자리에 있다.
--  사용자 2026-10-07: "닉네임이 npc랑 지나갈때 npc이름 아래로 낑겨버리는데 … 이건 말도 안되는 상황입니다" → 겹치면 밀어서 쌓던 것(stack)을 없앴다.
--  list = 앞선 차례대로(내 것 → 다른 사람 → 주민 · 문 → 졸개) { x(왼쪽), y(위), w(폭) }. h = 한 줄의 높이 · gap = 옆으로 이만큼보다 가까우면 겹친 것으로 본다.
--  앞선 것이 보이고, 그것과 겹치는 뒤의 것은 겹치는 동안 숨는다(글씨끼리 포개져 못 읽게 되지 않게). 돌려주는 것 = 보이는가의 차례표.
--  공방의 횡스크롤 시험 탭(js/lune/ui/paint.js의 tagsVisible)과 같은 셈이다.
function T.visible(list, h: number, gap: number?): { boolean }
	local near = gap or 4
	local shown = {}
	local out = {}
	for i, t in list do
		local hit = false
		for _, q in shown do
			if t.x < q.x + q.w + near and q.x < t.x + t.w + near and math.abs(q.y - t.y) < h then
				hit = true
				break
			end
		end
		if not hit then
			table.insert(shown, t)
		end
		out[i] = not hit
	end
	return out
end

-- 채팅 한 줄: 「이름: 글」. 채널이 파티면 앞에 [파티]
function T.chatLine(channel: string, name: string?, text: string): string
	local head = if channel == "party" then "[파티] " else ""
	if not name or name == "" then
		return head .. text
	end
	return ("%s%s: %s"):format(head, name, text)
end

-- 보내기 전에 다듬는다: 앞뒤 빈칸을 떼고, 줄바꿈을 빈칸으로, max글자까지만. 빈 글이면 nil
function T.chatClean(text: any, max: number?): string?
	if typeof(text) ~= "string" then
		return nil
	end
	local s = string.gsub(text, "[\r\n\t]", " ")
	s = string.match(s, "^%s*(.-)%s*$") or ""
	if s == "" then
		return nil
	end
	local out, n = "", 0
	local ok = pcall(function()
		for _, code in utf8.codes(s) do
			n += 1
			if n > (max or 80) then
				break
			end
			out ..= utf8.char(code)
		end
	end)
	if not ok or out == "" then
		return nil
	end
	return out
end

return T
