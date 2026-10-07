-- 화면에 적는 숫자와 글의 꼴 — 칸의 폭에 맞춰 고른다(글씨는 칸을 넘지 않는다). 화면과 상관없는 셈이라 테스트가 직접 돌린다.
--  measure(text) = 그 글의 폭(도트)을 재는 함수 — 게임에서는 pixelText.Measure.
local F = {}

-- 체력 칸 안의 자리: 레벨 글의 폭(Lv.150까지 들어가게) — 나머지가 체력 글의 폭이다
F.LEVEL_W = 48
F.LEVEL_GAP = 6

-- 큰 수를 짧게: 12,345 → 1.2만 · 123,456,789 → 1.2억
function F.short(n: number): string
	local function one(v: number, unit: string): string
		local s = string.format("%.1f", v)
		if s:sub(-2) == ".0" or #s >= 5 then
			s = string.format("%d", math.floor(v + 0.5))
		end
		return s .. unit
	end
	if n >= 1e8 then
		return one(n / 1e8, "억")
	elseif n >= 1e4 then
		return one(n / 1e4, "만")
	end
	return tostring(math.floor(n + 0.5))
end

-- 체력 글: "지금/최대"가 들어가면 그대로, 안 들어가면 짧게, 그래도 안 들어가면 지금 것만
function F.hp(cur: number, max: number, width: number, measure: (string) -> number): string
	local full = ("%d/%d"):format(cur, max)
	if measure(full) <= width then
		return full
	end
	local short = F.short(cur) .. "/" .. F.short(max)
	if measure(short) <= width then
		return short
	end
	return F.short(cur)
end

-- 키 이름을 화면에 적는 꼴
local KEYNAME = {
	LeftShift = "Shift", RightShift = "Shift", LeftControl = "Ctrl", RightControl = "Ctrl", LeftAlt = "Alt", RightAlt = "Alt", Space = "Space",
	Left = "←", Right = "→", Up = "↑", Down = "↓", Return = "Enter", Backspace = "Back", Backquote = "`", Minus = "-", Equals = "=",
	LeftBracket = "[", RightBracket = "]", Semicolon = ";", Quote = "'", Comma = ",", Period = ".", Slash = "/", BackSlash = "\\",
	Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
}
function F.key(name: string): string
	return KEYNAME[name] or name
end

-- 주민의 말풍선(화면 틀의 고운 격자의 점): 말은 본문 글씨로 폭 textW에 lines줄까지. 말풍선은 그 주민 머리 위에 뜬다(얼굴 칸 · 이름표를 따로 두지 않는다 — 산나비처럼).
--  padX · padY = 글 둘레의 여백 · tail = 꼬리의 높이 · up = 머리 위로 띄우는 높이(게임의 도트). 값은 공방 js/lune/design/ui.js의 BUBBLE(시험 탭과 같은 값)
F.BUBBLE = require(script.Parent.Parent.data["ui.generated"]).bubble

-- 칸 위의 키 딱지에 적는 키 이름(작은 글씨): 다섯 글자까지 — 긴 이름은 줄임말로
local CAP = { PageUp = "PgUp", PageDown = "PgDn", CapsLock = "Caps", Insert = "Ins", Delete = "Del", Escape = "Esc", NEnter = "NEnt" }
function F.keyShort(name: string): string
	local text = F.key(name)
	local pad = string.match(text, "^Keypad(.+)$")
	if pad then
		text = "N" .. F.key(pad)
	end
	text = CAP[text] or text
	local out, n = "", 0
	for _, code in utf8.codes(text) do
		n += 1
		if n > 5 then
			break
		end
		out ..= utf8.char(code)
	end
	return out
end

-- 이름표에 적는 이름. 도트 글꼴에 있는 글자(한글 · 영문 · 숫자 · 몇 가지 기호)로만 된 이름은 그대로, 다른 글자가 섞였으면 대신할 이름(로블록스 아이디)을 쓴다.
--  길면 max글자에서 자른다.
local OK_EXTRA = { ["·"] = true, ["★"] = true, ["♥"] = true }
function F.safeName(display: any, fallback: string, max: number?): string
	local name = if typeof(display) == "string" and #display > 0 then display else fallback
	local ok = pcall(function()
		for _, code in utf8.codes(name) do
			local fine = (code >= 32 and code <= 126) or (code >= 0xAC00 and code <= 0xD7A3) or (code >= 0x3131 and code <= 0x3163) or OK_EXTRA[utf8.char(code)]
			assert(fine)
		end
	end)
	if not ok then
		name = fallback
	end
	local out, n = "", 0
	for _, code in utf8.codes(name) do
		n += 1
		if n > (max or 12) then
			break
		end
		out ..= utf8.char(code)
	end
	return out
end

-- 좁은 칸에 적는 키 이름: 다 들어가면 그대로, 아니면 줄임말, 그래도 안 되면 들어가는 만큼만(적어도 한 글자)
local SHORT = { Space = "Spc", Shift = "Sft", Ctrl = "Ctl", Enter = "Ent", Back = "Bk", Alt = "Alt" }
function F.fitKey(name: string, width: number, measure: (string) -> number): string
	local text = F.key(name)
	if measure(text) <= width then
		return text
	end
	local short = SHORT[text]
	if short and measure(short) <= width then
		return short
	end
	local out = ""
	for _, code in utf8.codes(text) do
		local try = out .. utf8.char(code)
		if out ~= "" and measure(try) > width then
			break
		end
		out = try
	end
	return out
end

-- 스킬 칸 · 메뉴 단추의 귀퉁이에 아주 작은 글씨(3x5 — 영문 대문자 · 숫자 · 몇 가지 기호)로 적는 키 이름. 네 글자까지.
--  화살표는 그 글씨의 < > ^ ~ 자리에 그려져 있다. 그 글씨에 없는 글자는 뺀다.
local MICRO = { Shift = "SHFT", Ctrl = "CTRL", Space = "SPC", Enter = "ENT", Back = "BACK", Alt = "ALT", Tab = "TAB", ["←"] = "<", ["→"] = ">", ["↑"] = "^", ["↓"] = "~" }
F.MICRO_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ+-/%.,:!?<>^~[];'\\=`*"
function F.keyMicro(name: string): string
	local text = F.key(name)
	if MICRO[text] then
		return MICRO[text]
	end
	local out = ""
	for i = 1, #text do
		local ch = string.upper(text:sub(i, i))
		if #out < 4 and string.find(F.MICRO_CHARS, ch, 1, true) then
			out ..= ch
		end
	end
	return out
end

-- 한 줄에 나란히 놓는 칸들의 폭: 저마다 글이 들어갈 만큼(min 이상) 잡고, 남는 폭은 고루 나눈다. 다 못 들어가면 nil.
function F.split(total: number, gap: number, needs: { number }, min: number): { number }?
	local n = #needs
	local widths, sum = {}, 0
	for i, need in needs do
		widths[i] = math.max(min, need)
		sum += widths[i]
	end
	local left = total - gap * (n - 1) - sum
	if left < 0 then
		return nil
	end
	local each = math.floor(left / n)
	for i = 1, n do
		widths[i] += each
	end
	return widths
end

-- ---------- 능력치의 설명 · 스킬 창의 글 ----------  글은 공방 js/lune/design/ui.js의 STATTIP · SKILLWORDS(data/ui.generated.luau의 statTip · skillWords)
-- 글 속의 {이름}을 o의 값으로 채운다
function F.fill(text: string, o): string
	return (text:gsub("{(%w+)}", function(k)
		local v = o[k]
		return if v == nil then "" else tostring(v)
	end))
end

-- 오르는 값을 적는 법: 100부터는 정수 · 10부터는 소수 한 자리 · 그 아래는 소수 두 자리
function F.gain(v: number): string
	if v >= 100 then
		return tostring(math.floor(v + 0.5))
	elseif v >= 10 then
		return ("%.1f"):format(v)
	end
	return ("%.2f"):format(v)
end

-- 능력치 하나의 설명(능력치 창에서 마우스를 올렸을 때): { kind(main 주 · sub 부 · none 이 직업은 안 쓴다 · hp 체력), title(능력치 이름), tag, lines }
--  사용자 2026-10-07: "능력치에 각각 스텟별로 마우스 올리면 호버로 스텟 효과를 보여줘야합니다. 뭔지알고 스텟을찍으라는건지"
--  그 직업에게 무엇을 해 주는지와, 지금 레벨에서 1점에 얼마가 오르는지를 실제 숫자로 적는다(공방 js/lune/ui/paint.js의 statTip과 같은 글 — 테스트 14가 맞춰 본다)
function F.statTip(class: string, id: string, level: number)
	local N = require(script.Parent.Parent.config.numbers)
	local CLASSES = require(script.Parent.Parent.data["classes.generated"])
	local TIP = require(script.Parent.Parent.data["ui.generated"]).statTip
	local STATS = N.data.STATS
	local pair = STATS.classes[class]
	local kind = if id == "hp" then "hp" elseif id == pair[1] then "main" elseif id == pair[2] then "sub" else "none"
	local gain = N.statGain(class, level)
	local users = {}
	for _, c in TIP.order do
		local q = STATS.classes[c]
		if q[1] == id or q[2] == id then
			table.insert(users, ("%s(%s)"):format(CLASSES.classes[c].name, if q[1] == id then TIP.marks.main else TIP.marks.sub))
		end
	end
	local o = {
		class = CLASSES.classes[class].name,
		main = STATS.names[pair[1]],
		ratio = STATS.mainW / STATS.subW,
		power = F.gain(if kind == "main" then gain.main else gain.sub),
		hp = F.gain(gain.hp),
		users = table.concat(users, " · "),
	}
	local lines = {}
	for i, text in TIP[kind].lines do
		lines[i] = F.fill(text, o)
	end
	return { kind = kind, title = STATS.names[id], tag = TIP[kind].tag, lines = lines }
end

return F
