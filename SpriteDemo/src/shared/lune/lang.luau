-- 언어(2026-10-27 사용자 "한국어유저가 아닌 유저들이 들어왔을때 모든게 영문번역 되어야해 서비스제공이 누락사안없이").
--  화면이 그리는 글을 그리기 바로 전에 바꾼다(client/modules/ui/pixelText의 SetTranslator · 입력칸의 안내 · 채팅 알림).
--  게임의 셈과 서버는 한국어 그대로다 — 서버가 보낸 글도 화면이 여기서 바꾼다. 영문은 공방 lang/en.json → data/lang_en.generated.luau.
--  바꾸는 차례(Lang.t):
--   ① 한글이 없으면 그대로 ② 열쇠 = 숫자를 「#」로 바꾼 글 — 사전에 있으면 영문의 「#」에 숫자를 차례로 넣는다(「#2」처럼 번호가 있으면 그 번째)
--   ③ 틀(%s · %d · {이름}이 든 글 — 코드가 string.format · Format.fill로 채운 것): 틀에 맞으면 채운 값도 바꿔 영문 틀의 {1} {2} …(자리의 차례)에 넣는다 — 틀의 숫자(#)는 영문의 「#」에
--   ④ 나누기: 「 · 」 「 — 」 줄바꿈 … 으로 이은 글은 조각마다 바꿔 다시 잇는다 ⑤ 못 바꾸면 그대로 두고 Lang.missing에 적는다(시험이 본다)
local Lang = {}
Lang.code = "ko"
Lang.missing = {} :: { [string]: boolean }

local D = nil -- 사전(처음 쓸 때 읽는다 — 한국어로만 노는 사람은 읽지 않는다)
local templates = nil :: { any }?
local fragPre, fragSuf = {} :: { any }, {} :: { any } -- 앞 조각 · 뒤 조각(load가 채운다)
local memo = {} :: { [string]: string }
local memoN = 0

local function hasHangul(s: string): boolean
	return string.find(s, "[\234-\237][\128-\191][\128-\191]") ~= nil or string.find(s, "\227\132[\177-\191]") ~= nil or string.find(s, "\227\133[\128-\163]") ~= nil
end
Lang.hasHangul = hasHangul

-- 숫자를 「#」로(끝에 붙은 . , 는 숫자에 넣지 않는다) — 공방 tools/lang_keys.mjs의 normKey와 같은 셈
local function norm(s: string): (string, { string })
	local vals = {}
	local out = string.gsub(s, "%d[%d%.,]*", function(m)
		local tail = string.match(m, "[%.,]+$") or ""
		table.insert(vals, string.sub(m, 1, #m - #tail))
		return "#" .. tail
	end)
	return out, vals
end
Lang.norm = norm

-- 영문에 숫자를 넣는다: 「#」 = 다음 숫자 · 「#2」 = 두 번째 숫자
local function refill(en: string, vals: { string }): string
	local i = 0
	return (string.gsub(en, "#(%d?)", function(d)
		if d ~= "" then
			return vals[tonumber(d)] or ""
		end
		i += 1
		return vals[i] or "#"
	end))
end

local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"
local NUMPAT = "(%-?[%d%.,]+[KMB]?)" -- (숫자 자리: 큰 수는 영문에서 K · M · B가 붙는다 — format.short)
local NUMSLOT = { n = true, lv = true, pct = true, max = true, a = true, b = true, cap = true, days = true, fee = true, hi = true, lo = true, hp = true, job = true, level = true, m = true, month = true, need = true, p = true, power = true, price = true, ratio = true, s = true, today = true, left = true }
local function load()
	if D then
		return
	end
	D = require(script.Parent.data["lang_en.generated"])
	-- 말하는 사람 표시(「@hero 말」 — 대화창 client/lune/ui/talk.luau의 Talk.speaker가 떼고 그린다)를 뗀 열쇠도 둔다(2026-10-27)
	local extra = {}
	for ko, en in D.words do
		local who, rest = string.match(ko, "^@([%w_]+) (.+)$")
		if who then
			extra[rest] = string.match(en, "^@[%w_]+ (.+)$") or en
		end
	end
	for k, v in extra do
		if D.words[k] == nil then
			D.words[k] = v
		end
	end
	local list = {}
	for ko, en in D.words do
		if string.find(ko, "%%[sdif]") or string.find(ko, "%%%.%d+f") or string.find(ko, "{[%w_:]+}") then
			-- 틀을 패턴으로: 자리(%s · %d · %.1f · {이름})와 숫자(#)는 붙잡고, 나머지는 글자 그대로
			-- 숫자 자리: %d · %.1f와 숫자를 뜻하는 이름({n} · {lv} · {pct} …)은 숫자만(큰 수의 K · M · B · 만 · 억까지) — 글 자리끼리 빈칸으로 붙어 있어도 갈라 잡게
			local pat, wide, kinds, i = { "^" }, { "^" }, {}, 1
			while i <= #ko do
				local slot = string.match(ko, "^%%%.%d+f", i) or string.match(ko, "^%%[sdif]", i) or string.match(ko, "^{[%w_:]+}", i)
				if slot then
					local numeric = (string.find(slot, "^%%") and not string.find(slot, "s$")) or NUMSLOT[string.match(slot, "^{([%w_]+)}$") or ""]
					table.insert(pat, if numeric then NUMPAT else "(.-)")
					table.insert(wide, if numeric then NUMPAT else "(.+)")
					table.insert(kinds, "p")
					i += #slot
				else
					local ch = string.sub(ko, i, i)
					local piece = if ch == "#" then "(%-?[%d%.,]+)" else (string.gsub(ch, MAGIC, "%%%0"))
					if ch == "#" then
						table.insert(kinds, "n")
					end
					table.insert(pat, piece)
					table.insert(wide, piece)
					i += 1
				end
			end
			table.insert(pat, "$")
			table.insert(wide, "$")
			table.insert(list, { pat = table.concat(pat), wide = table.concat(wide), en = en, kinds = kinds, len = #ko })
		end
	end
	table.sort(list, function(a, b) -- 긴 틀부터(짧은 틀이 긴 글을 먼저 잡지 않게)
		return a.len > b.len
	end)
	templates = list
	-- 조각(코드가 이어 붙이는 글 — 「주민: 」 .. 이름들 · 이름 .. 「 (부서짐)」): 빈칸 · 쌍점 · 마침표로 끝나는 열쇠는 앞 조각, 빈칸으로 시작하는 열쇠는 뒤 조각(2026-10-27)
	local pre, suf = {}, {}
	for ko, en in D.words do
		if #ko >= 4 and not string.find(ko, "[%%{#]") then
			local last, first = string.sub(ko, -1), string.sub(ko, 1, 1)
			if last == " " or last == ":" or last == "." then
				table.insert(pre, { ko = ko, en = en })
			end
			if first == " " then
				table.insert(suf, { ko = ko, en = en })
			end
		end
	end
	table.sort(pre, function(a, b)
		return #a.ko > #b.ko
	end)
	table.sort(suf, function(a, b)
		return #a.ko > #b.ko
	end)
	fragPre, fragSuf = pre, suf
end

-- 앞뒤에 붙은 것(빈칸 · 괄호 · 꺾쇠 · 마침표 …)을 떼어 본다 — 여러 바이트 글자는 바이트 묶음으로 다루지 않는다(한글을 반쪽 내지 않게)
local EDGE_HEAD = { " ", "(", "[", "「", "『", "\"", "'", "\n" }
local EDGE_TAIL = { " ", ")", "]", "」", "』", "\"", "'", ".", "!", "?", "…", "\n", ":" }
local function strip(s: string): (string, string, string)
	local head, tail = "", ""
	local moved = true
	while moved do
		moved = false
		for _, e in EDGE_HEAD do
			if #s > #e and string.sub(s, 1, #e) == e then
				head ..= e
				s = string.sub(s, #e + 1)
				moved = true
			end
		end
	end
	moved = true
	while moved do
		moved = false
		for _, e in EDGE_TAIL do
			if #s > #e and string.sub(s, -#e) == e then
				tail = e .. tail
				s = string.sub(s, 1, #s - #e)
				moved = true
			end
		end
	end
	return head, s, tail
end

local translate
local try -- (아래에서 채운다 — 틀의 채운 값을 바꿀 때 쓴다)
-- 한 조각(나누지 않고): 사전 → 앞뒤를 뗀 사전 → 틀
local function one(s: string): string?
	local key, vals = norm(s)
	local en = D.words[key]
	if en then
		return refill(en, vals)
	end
	local head, body, tail = strip(s)
	if body ~= s and body ~= "" then
		local k2, v2 = norm(body)
		local e2 = D.words[k2]
		if e2 then
			return head .. refill(e2, v2) .. tail
		end
	end
	-- 틀: 짧게 잡아 본 뒤, 채운 값 가운데 바뀌지 않는 한글이 있으면 길게 잡아 다시(「{name} {n}마리」 — 「포자 주머니 8마리」를 「포자」 · 「주머니 8」로 가르지 않게)
	local function fill(t, caps): (string, boolean)
		local slots, nums, clean = {}, {}, true
		for i, kind in t.kinds do
			if kind == "p" then
				table.insert(slots, caps[i])
			else
				table.insert(nums, caps[i])
			end
		end
		local out = string.gsub(t.en, "{(%d)}", function(d)
			local v = slots[tonumber(d)]
			if not v then
				return ""
			end
			local e = try(v)
			if not e then
				clean = false -- (사람의 이름처럼 사전에 없는 것은 그대로 둔다 — 못 바꾼 것으로 적지 않는다)
			end
			return e or v
		end)
		return refill(out, nums), clean
	end
	for _, t in templates :: { any } do
		local caps = table.pack(string.match(s, t.pat))
		if caps.n > 0 and caps[1] ~= nil then
			local out, clean = fill(t, caps)
			if not clean then
				local caps2 = table.pack(string.match(s, t.wide))
				if caps2.n > 0 and caps2[1] ~= nil then
					local out2, clean2 = fill(t, caps2)
					if clean2 then
						return out2
					end
				end
			end
			return out
		end
	end
	return nil
end

local SEPS = { "\n", " · ", " — ", " / ", " → ", ": ", ", " }

-- 바꾸지 않는 글: 제 말로 적는 언어 이름(설정 창의 「한국어」 — 어느 언어에서도 그대로)
Lang.KEEP = { ["한국어"] = true } :: { [string]: boolean }

-- 빈칸으로 이은 낱말들(코드가 붙인 이름 — 「빼어난 Lv.20 큰 도끼」): 앞에서부터 가장 긴 낱말 묶음이 사전에 있는 것을 고른다(「큰 도끼」를 「큰」 · 「도끼」로 쪼개지 않게)
local function byWords(s: string): string?
	local words = string.split(s, " ")
	if #words < 2 then
		return nil
	end
	local out, i = {}, 1
	while i <= #words do
		local took, upto = nil, i
		for j = #words, i, -1 do
			local piece = table.concat(words, " ", i, j)
			local e = if hasHangul(piece) then one(piece) else (if j == i then piece else nil)
			if e and not hasHangul(e) then -- (낱말 묶음은 다 바뀐 것만 — 틀이 이름 자리를 못 바꾼 채 돌려준 것은 받지 않는다)
				took, upto = e, j
				break
			end
		end
		if not took then
			return nil
		end
		table.insert(out, took)
		i = upto + 1
	end
	return table.concat(out, " ")
end

-- 못 바꾸면 nil(적지 않는다 — 맨 위의 translate만 Lang.missing에 적는다)
try = function(s: string): string?
	if Lang.KEEP[s] or not hasHangul(s) then
		return s
	end
	local hit = memo[s]
	if hit and not hasHangul(hit) then
		return hit
	end
	local out = one(s)
	if not out then
		-- 이은 글: 조각마다 바꿔 다시 잇는다(한 조각이라도 못 바꾸면 다음 나누기로)
		for _, sep in SEPS do
			if string.find(s, sep, 1, true) then
				local parts, ok = {}, true
				for piece in (s .. sep):gmatch("(.-)" .. string.gsub(sep, MAGIC, "%%%0")) do
					local p = try(piece)
					if not p then
						ok = false
						break
					end
					table.insert(parts, p)
				end
				if ok then
					out = table.concat(parts, sep)
					break
				end
			end
		end
	end
	if not out and string.find(s, " ", 1, true) then
		out = byWords(s)
	end
	if not out then
		-- 앞 조각 + 나머지 · 나머지 + 뒤 조각(나머지도 바뀌어야 한다)
		for _, f in fragPre do
			if #s > #f.ko and string.sub(s, 1, #f.ko) == f.ko then
				local rest = try(string.sub(s, #f.ko + 1))
				if rest then
					out = f.en .. rest
					break
				end
			end
		end
	end
	if not out then
		for _, f in fragSuf do
			if #s > #f.ko and string.sub(s, -#f.ko) == f.ko then
				local head = try(string.sub(s, 1, #s - #f.ko))
				if head then
					out = head .. f.en
					break
				end
			end
		end
	end
	if out then
		memoN += 1
		if memoN > 20000 then
			table.clear(memo)
			memoN = 0
		end
		memo[s] = out
	end
	return out
end

translate = function(s: string): string
	if Lang.code == "ko" or s == "" or Lang.KEEP[s] or not hasHangul(s) then
		return s
	end
	load()
	local out = try(s)
	if not out then
		Lang.missing[s] = true
		out = s
	end
	memoN += 1
	if memoN > 20000 then
		table.clear(memo)
		memoN = 0
	end
	memo[s] = out
	return out
end
Lang.t = translate

-- 언어를 정한다("ko" · "en"). 바꾸면 외워 둔 것을 비운다
function Lang.set(code: string)
	if code ~= "ko" then
		code = "en"
	end
	if code ~= Lang.code then
		Lang.code = code
		table.clear(memo)
		memoN = 0
	end
end

-- 로블록스의 언어 설정(LocaleId · "ko-kr" …)에서: 한국어면 "ko", 아니면 "en". 설정 창에서 고른 것(choice: "auto" · "ko" · "en")이 있으면 그것
function Lang.pick(localeId: any, choice: any): string
	if choice == "ko" or choice == "en" then
		return choice
	end
	return if typeof(localeId) == "string" and string.sub(string.lower(localeId), 1, 2) == "ko" then "ko" else "en"
end

return Lang
