-- 이름표와 채팅 줄의 자리 셈(그리지는 않는다). 테스트 14가 본다.
local T = {}

-- 이름표가 겹치지 않게 쌓는다. fixed = 움직이지 않는 것들(주민 · 문의 이름표), moving = 사람들의 이름표(앞의 것이 먼저 자리를 잡는다).
--  하나 = { x(왼쪽), y(위), w(폭) }. h = 한 줄의 높이. dir = 쌓는 쪽(-1 위로 · 1 아래로 — 발밑의 이름표는 아래로 쌓는다. 안 주면 위로).
--  돌려주는 것: moving의 차례대로 정해진 y들.
function T.stack(fixed, moving, h: number, dir: number?): { number }
	local placed = table.clone(fixed)
	local out = {}
	for i, m in moving do
		local y = m.y
		for _ = 1, 6 do
			local hit = false
			for _, p in placed do
				if m.x < p.x + p.w + 2 and p.x < m.x + m.w + 2 and math.abs(p.y - y) < h then
					hit = true
					break
				end
			end
			if not hit then
				break
			end
			y += h * (dir or -1)
		end
		out[i] = y
		table.insert(placed, { x = m.x, y = y, w = m.w })
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
