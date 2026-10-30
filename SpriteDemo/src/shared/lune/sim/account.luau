-- 계정 — 한 사람(Roblox 계정)이 가진 캐릭터들과 그 캐릭터들이 같이 쓰는 창고.
--  사용자 2026-10-10: "처음 접속할때 캐릭터를 선택하고 그 캐릭터를 계속 키우는형식 … 캐릭터 만들기도 있고, 캐릭터 삭제도 있고, 내가 만든 캐릭터 중 하나를 선택해서 접속하는 방식",
--   "창고는 내 계정내의 캐릭터들이 공유하는 창고입니다", "캐릭터 이름은 처음에 생성할때 캐릭터 이름을 짓습니다. 중복확인을하고, 현재처럼 그냥 로블록스의 아이디를 가져와서 사용하지않습니다".
--  여기는 셈만 한다(저장소 · 글 거르기 · 이름 장부는 서버의 것 — server/lune/modules/world.luau · store.luau).
--  계정의 표: { next = 다음 캐릭터 번호, last = 마지막으로 들어간 캐릭터의 번호(없으면 false), chars = { { id, name, class, made, hero = 저장된 캐릭터(sim/hero.luau의 pack — 창고는 빼고) } … }, store = 같이 쓰는 창고(sim/bag.luau의 packStore) }
--  캐릭터의 이름이 ""인 것 = 이름을 짓기 전에 만들어진 캐릭터(계정이 생기기 전의 저장을 옮긴 것) — 들어가기 전에 이름을 지어야 한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local CLASSES = require(lune.data["classes.generated"])
local Market = require(lune.sim.market) -- 경매장에 맡긴 것의 꼴
local Attend = require(lune.sim.attend) -- 출석(계정의 것 — 2026-10-15)
local Achieve = require(lune.sim.achieve) -- 업적(계정의 것 — 2026-10-15)
local Macro = require(lune.sim.macro) -- 매크로 확인(놓친 때 · 보상 멈춤 — 계정에 남는다, 2026-10-23)
local Cash = require(lune.sim.cash) -- 유료 상품(구매 보관함 · 처리한 결제 · 주간 수 · 사서 늘린 칸 — 2026-10-20)
local NAMES = require(lune.data["names.generated"]) -- 이름의 규칙(공방의 js/lune/design/names.js)
local SOUND = require(lune.data["ui.generated"]).layout.sound -- 소리 설정의 칸 수(steps) · 처음 크기(start)

local Account = {}
Account.VERSION = 1
Account.MAX = 6 -- 한 계정의 캐릭터 수(내 제안 — 직업 다섯에 하나 더)
-- 이름의 길이: 한글은 한 글자가 2칸, 영문 · 숫자는 1칸 — 모두 4~12칸(한글 2~6자 · 영문 4~12자. 메이플스토리의 셈과 같다)
Account.NAME_MIN, Account.NAME_MAX = NAMES.min, NAMES.max
Account.TEXT = NAMES.text
local MAX_BYTES = 48 -- 이보다 긴 글은 따져 보지도 않는다(한글 여섯 자 = 18바이트)

local function whole(v: any, lo: number, hi: number): boolean
	return typeof(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

-- 소리 설정 { music = 배경 음악의 크기, sfx = 효과음의 크기(0~steps칸 — 한 칸 10%), on = 모두 켰는가 }. 계정의 것이다(캐릭터를 바꿔도 같다)
--  사용자 2026-10-13: "소리조절 있어야합니다."
function Account.soundDefault()
	return { music = SOUND.start, sfx = SOUND.start, on = true, fx = true, nums = true, myNums = true, lang = "auto", touch = "new" } -- fx · nums = 화면 설정(다른 사람의 스킬 효과 · 피해 숫자 — 2026-10-18) · lang = 언어("auto" 로블록스의 언어 설정을 따른다 · "ko" · "en" — 2026-10-27)
end
-- 받은 것 · 저장된 것의 꼴을 본다: 맞으면 새 표, 아니면 nil
function Account.cleanSound(v: any)
	if typeof(v) ~= "table" or not whole(v.music, 0, SOUND.steps) or not whole(v.sfx, 0, SOUND.steps) or typeof(v.on) ~= "boolean" then
		return nil
	end
	-- 화면(2026-10-18 — 설정 창의 「화면」): fx = 다른 사람의 스킬 효과 · nums = 다른 사람의 피해 숫자를 보일지. 없으면(그 전의 저장) 켜짐 · 참거짓이 아니면 받지 않는다
	if (v.fx ~= nil and typeof(v.fx) ~= "boolean") or (v.nums ~= nil and typeof(v.nums) ~= "boolean") or (v.myNums ~= nil and typeof(v.myNums) ~= "boolean") then -- myNums = 내가 때린 피해 숫자(2026-10-30)
		return nil
	end
	-- 언어(2026-10-27): "auto" · "ko" · "en"(없으면 — 그 전의 저장 — "auto" · 그 밖의 값은 받지 않는다)
	if v.lang ~= nil and v.lang ~= "auto" and v.lang ~= "ko" and v.lang ~= "en" then
		return nil
	end
	-- 폰 단추 배치(2026-10-28): "new" · "old"(없으면 — 그 전의 저장 — "new" · 그 밖의 값은 받지 않는다)
	if v.touch ~= nil and v.touch ~= "new" and v.touch ~= "old" then
		return nil
	end
	return { music = v.music, sfx = v.sfx, on = v.on, fx = v.fx ~= false, nums = v.nums ~= false, myNums = v.myNums ~= false, lang = v.lang or "auto", touch = v.touch or "new" }
end
function Account.setSound(acct, v: any): boolean
	local sound = Account.cleanSound(v)
	if not sound then
		return false
	end
	acct.sound = sound
	return true
end

function Account.new()
	-- spent = 이 계정이 게임에 쓴 로벅스(명예의 전당의 후원 판) · sound = 소리 설정
	-- market = 경매장에 맡긴 것(올린 물건 · 아직 찾지 않은 것 — sim/market.luau). 창고처럼 계정의 캐릭터들이 같이 본다
	return { next = 1, last = false, chars = {}, store = false, storeGot = {}, broken = {}, spent = 0, sound = Account.soundDefault(), market = Market.newBook(), tutDone = false, att = Attend.new(), ach = Achieve.new(), bm = Cash.new(), macro = Macro.newSaved() } -- att = 출석(sim/attend.luau) · ach = 업적(sim/achieve.luau) — 계정의 것(2026-10-15) -- tutDone = 이 계정의 캐릭터가 튜토리얼 「달빛 꿈」을 한 번 끝냈다(그 뒤의 새 캐릭터는 건너뛸 수 있다)
end

-- 이름을 견줄 때의 꼴(영문은 소문자로 — Moon과 moon은 같은 이름이다)
function Account.nameKey(name: string): string
	return string.lower(name)
end

-- ---------- 지을 수 없는 말 ----------
--  사용자 2026-10-10(「성관계장인」이 통과되는 사진): "조금만 우회해도 문제되는 닉네임이 통과됩니다."
--  공방의 tools/build_lune_names.mjs의 banned()와 같은 셈이다(같은 이름들로 양쪽을 맞춰 본다 — NAMES.check). 고칠 때는 둘을 같이 고친다.
--   한글: 이름에서 한글만 뽑아 견준다(시1발 · 시a발 → 시발). 모음을 늘인 것은 줄인다(씨이발 → 씨발). loose의 말은 소리의 뼈대로 견준다(쎅쓰 → 섹스).
--   영문: 이름에서 영문만 뽑아 견준다(fu달ck → fuck). 숫자로 바꿔 적은 것(sh1t) · 같은 글자를 늘인 것(fuuck)도 같은 말이다.
--         whole의 말(ass · tit · cum …)은 영문 덩어리 전체가 그 말일 때만 막는다(class · title을 막지 않는다).
--   allow의 말(성기사 · 시발점 · essex …)은 먼저 가려 놓는다.
local SEN = "\1" -- 가려 놓은 말의 자리(어느 금칙어와도 이어지지 않는다)
local CHO = { [1] = 0, [4] = 3, [8] = 7, [10] = 9, [13] = 12 } -- 된소리 → 예사소리
local JUNG = { [1] = 5, [3] = 5, [7] = 5, [10] = 11, [15] = 11, [19] = 20, [16] = 20 } -- ㅐ ㅒ ㅖ → ㅔ · ㅙ ㅞ → ㅚ · ㅢ ㅟ → ㅣ
local JONG = {} -- 받침은 소리가 같은 것끼리
for to, list in { [1] = { 1, 2, 3, 24, 9 }, [4] = { 4, 5, 6 }, [7] = { 7, 19, 20, 22, 23, 25 }, [8] = { 8, 11, 12, 13, 15 }, [16] = { 10, 16 }, [17] = { 17, 18, 26, 14 } } do
	for _, jong in list do
		JONG[jong] = to
	end
end

local function isHangul(code: number): boolean
	return code >= 0xAC00 and code <= 0xD7A3
end

-- 한글 한 글자를 초성 · 중성 · 종성의 번호로
local function parts(code: number): (number, number, number)
	local i = code - 0xAC00
	return i // 588, (i % 588) // 28, i % 28
end

-- 모음을 늘인 것을 줄인다: 받침 없는 글자 뒤에 같은 모음의 「ㅇ + 모음」이 오면 뺀다. codes = 한글(과 가려 놓은 자리 1)의 코드들
local function shorten(codes: { number }): { number }
	local out = {}
	local prevV, prevT = nil, nil
	for _, code in codes do
		if code == 1 then
			table.insert(out, code)
			prevV, prevT = nil, nil
		else
			local c, j, t = parts(code)
			local v = JUNG[j] or j
			if not (prevV and c == 11 and t == 0 and prevT == 0 and prevV == v) then
				table.insert(out, code)
				prevV, prevT = v, t
			end
		end
	end
	return out
end

-- 소리의 뼈대: 글자마다 (초성 · 중성 · 종성)을 비슷한 것끼리 묶어 세 바이트로
local function skeleton(codes: { number }): string
	local out = table.create(#codes)
	for i, code in codes do
		if code == 1 then
			out[i] = SEN .. SEN .. SEN
		else
			local c, j, t = parts(code)
			out[i] = string.char(65 + (CHO[c] or c), 65 + (JUNG[j] or j), 65 + (JONG[t] or t))
		end
	end
	return table.concat(out)
end

local function hasAligned(s: string, word: string): boolean
	local from = 1
	while true do
		local at = string.find(s, word, from, true)
		if not at then
			return false
		elseif (at - 1) % 3 == 0 then
			return true
		end
		from = at + 1
	end
end

-- 글자의 덩이(같은 글자가 이어진 것): { 글자들, 길이들 }
local function runsOf(s: string)
	local chars, counts = {}, {}
	for i = 1, #s do
		local ch = string.sub(s, i, i)
		if chars[#chars] == ch then
			counts[#counts] += 1
		else
			table.insert(chars, ch)
			table.insert(counts, 1)
		end
	end
	return { chars = chars, counts = counts }
end

-- 이름의 덩이 속에 금칙어의 덩이가 있는가(이름의 덩이가 같거나 길면 같은 말이다 — fuuck = fuck, 하지만 niger ≠ nigger)
local function runsHave(name, word): boolean
	local n, m = #name.chars, #word.chars
	for i = 1, n - m + 1 do
		local ok = true
		for k = 1, m do
			if name.chars[i + k - 1] ~= word.chars[k] or name.counts[i + k - 1] < word.counts[k] then
				ok = false
				break
			end
		end
		if ok then
			return true
		end
	end
	return false
end

local function codesOf(s: string): { number }
	local out = {}
	for _, code in utf8.codes(s) do
		table.insert(out, code)
	end
	return out
end

-- 미리 지어 두는 것
local WHOLE, RESWHOLE = {}, {}
for _, w in NAMES.whole do
	WHOLE[w] = true
end
for _, w in NAMES.reservedWhole do
	RESWHOLE[w] = true
end
local EN_RUNS = table.create(#NAMES.en)
for i, w in NAMES.en do
	EN_RUNS[i] = runsOf(w)
end
local LOOSE = table.create(#NAMES.loose)
for i, w in NAMES.loose do
	LOOSE[i] = skeleton(codesOf(w))
end

local function leetOf(s: string): string
	return (string.gsub(s, "%d", function(d)
		return NAMES.leet["d" .. d] or d
	end))
end

-- 글에서 word를 모두 가려 놓는다
local function mask(s: string, word: string): string
	local out, from = {}, 1
	while true do
		local a, b = string.find(s, word, from, true)
		if not a then
			break
		end
		table.insert(out, string.sub(s, from, a - 1))
		table.insert(out, SEN)
		from = (b :: number) + 1
	end
	if from == 1 then
		return s
	end
	table.insert(out, string.sub(s, from))
	return table.concat(out)
end

-- 운영자 사칭(2026-10-29 사용자: "운영자 사칭할수 있는 닉네임들은 다 … dolupa, dolupa95, 운영자, 제작자, 개발자, 어드민 기타등등 운영자를 사칭할수있는 모든 경우의수 걸리게"):
--  공방 tools/build_lune_names.mjs의 staff()와 같은 셈(고칠 때는 둘을 같이 — 이름들 NAMES.check로 맞춰 본다).
--  영문 덩어리 전체(gm · mod · dev …) · 들어 있는 말(reserved) · 한글만 뽑아 소리의 뼈대로(staffKo — 운a영자 · 재작자 · 쥐엠) ·
--  영문만 뽑아 닮은 글자를 같게 보고(숫자 → 글자 · l → i · rn → m · vv → w) 같은 글자를 늘인 것까지(staffEn — ADM1N · admln · aadmiin · D0LUPA)
local function confOf(s: string): string
	return (string.gsub((string.gsub((string.gsub(s, "l", "i")), "rn", "m")), "vv", "w"))
end
local STAFF_KO, STAFF_EN = table.create(#NAMES.staffKo), table.create(#NAMES.staffEn)
for i, w in NAMES.staffKo do
	STAFF_KO[i] = skeleton(shorten(codesOf(w)))
end
for i, w in NAMES.staffEn do
	STAFF_EN[i] = runsOf(confOf(leetOf(w)))
end
function Account.nameStaff(name: string): boolean
	local key0 = Account.nameKey(name)
	for seg in string.gmatch(key0, "%a+") do
		if RESWHOLE[seg] then
			return true
		end
	end
	local key = key0
	for _, a in NAMES.allow do
		key = mask(key, a) -- 멀쩡한 말(badminton …)은 먼저 가려 놓는다
	end
	local bare0, leet0 = string.gsub(key, "%d", ""), leetOf(key)
	for _, w in NAMES.reserved do
		if string.find(key, w, 1, true) or string.find(bare0, w, 1, true) or string.find(leet0, w, 1, true) then
			return true
		end
	end
	local hangCodes = {}
	for _, code in utf8.codes(key) do
		if code == 1 or isHangul(code) then
			table.insert(hangCodes, code)
		end
	end
	if #hangCodes > 0 then
		local sk1, sk2 = skeleton(hangCodes), skeleton(shorten(hangCodes))
		for _, w in STAFF_KO do
			if hasAligned(sk1, w) or hasAligned(sk2, w) then
				return true
			end
		end
	end
	local lat = confOf((string.gsub(leetOf(key), "[^%l%c]", "")))
	if lat ~= "" then
		local r = runsOf(lat)
		for _, w in STAFF_EN do
			if runsHave(r, w) then
				return true
			end
		end
	end
	return false
end

-- 지을 수 없는 말이 들었는가(바른 UTF-8의 글이어야 한다 — Account.nameOk가 먼저 본다). staffOk = 운영자 사칭은 보지 않는다(관리자 계정의 캐릭터 — 2026-10-29)
function Account.nameBanned(name: string, staffOk: boolean?): boolean
	if not staffOk and Account.nameStaff(name) then
		return true
	end
	local key0 = Account.nameKey(name)
	local key = key0
	for _, a in NAMES.allow do
		key = mask(key, a)
	end
	-- 한글만 · 영문만 뽑는다
	local hangCodes, lat = {}, {}
	for _, code in utf8.codes(key) do
		if code == 1 then
			table.insert(hangCodes, code)
			table.insert(lat, SEN)
		elseif isHangul(code) then
			table.insert(hangCodes, code)
		elseif code >= 97 and code <= 122 then
			table.insert(lat, string.char(code))
		end
	end
	local shortCodes = shorten(hangCodes)
	local hang, hang2 = utf8.char(table.unpack(hangCodes)), utf8.char(table.unpack(shortCodes))
	if hang ~= "" then
		for _, w in NAMES.ko do
			if string.find(hang, w, 1, true) or string.find(hang2, w, 1, true) then
				return true
			end
		end
	end
	for _, w in NAMES.mixed do
		if string.find(key, w, 1, true) then
			return true
		end
	end
	-- 영문: 글자만(숫자는 뺀다) · 숫자를 글자로 바꾼 것 — 글자의 덩이로 견준다
	local latin = table.concat(lat)
	local leetLatin = string.gsub(leetOf(key), "[^%l%c]", "") -- 소문자와 가려 놓은 자리만 남긴다(한글의 바이트 · 남은 숫자는 뺀다)
	if latin ~= "" or leetLatin ~= "" then
		local a, b = runsOf(latin), runsOf(leetLatin)
		for _, w in EN_RUNS do
			if runsHave(a, w) or runsHave(b, w) then
				return true
			end
		end
	end
	-- 영문 덩어리 전체가 그 말인가(a55 → ass)
	for seg in string.gmatch(key, "[%l%d]+") do
		if WHOLE[(string.gsub(seg, "%d", ""))] or WHOLE[(string.gsub(leetOf(seg), "%d", ""))] then
			return true
		end
	end
	-- 소리가 같은 말
	if #shortCodes > 0 then
		local sk = skeleton(shortCodes)
		for _, w in LOOSE do
			if hasAligned(sk, w) then
				return true
			end
		end
	end
	return false
end

-- 이름의 꼴을 본다. 돌려주는 것: 되는가, 안 되는 까닭(화면에 그대로 적는 글)
--  차례: 글인가 → 너무 긴 글이 아닌가 → 쓸 수 있는 글자뿐인가(완성된 한글 · 영문 · 숫자) → 숫자만은 아닌가 → 길이 → 지을 수 없는 말
function Account.nameOk(name: any, staffOk: boolean?): (boolean, string?)
	local TEXT = NAMES.text
	if typeof(name) ~= "string" or name == "" then
		return false, TEXT.empty
	end
	if #name > MAX_BYTES then
		return false, TEXT.long
	end
	if not utf8.len(name) then
		return false, TEXT.chars
	end
	local width, letters = 0, 0
	for _, code in utf8.codes(name) do
		if code >= 0xAC00 and code <= 0xD7A3 then
			width += 2
			letters += 1
		elseif (code >= 65 and code <= 90) or (code >= 97 and code <= 122) then
			width += 1
			letters += 1
		elseif code >= 48 and code <= 57 then
			width += 1
		else
			return false, TEXT.chars
		end
	end
	if width < Account.NAME_MIN then
		return false, TEXT.short
	elseif width > Account.NAME_MAX then
		return false, TEXT.long
	elseif letters == 0 and not NAMES.digitsOnly then
		return false, TEXT.digits
	end
	if not staffOk and Account.nameStaff(name) then
		return false, TEXT.staff -- 운영자 사칭(2026-10-29)
	end
	if Account.nameBanned(name, true) then
		return false, TEXT.banned
	end
	return true, nil
end

function Account.find(acct, id: any)
	for i, c in acct.chars do
		if c.id == id then
			return c, i
		end
	end
	return nil, nil
end

-- 내 캐릭터 가운데 그 이름이 있는가(skip = 견주지 않을 캐릭터의 번호)
function Account.hasName(acct, name: string, skip: any?): boolean
	local key = Account.nameKey(name)
	for _, c in acct.chars do
		if c.id ~= skip and c.name ~= "" and Account.nameKey(c.name) == key then
			return true
		end
	end
	return false
end

-- 이 계정의 캐릭터 칸: 처음 MAX + 「캐릭터 칸 +1」로 산 것(유료 — 2026-10-20)
function Account.maxChars(acct): number
	return Account.MAX + (if acct.bm then acct.bm.slots else 0)
end

function Account.full(acct): boolean
	return #acct.chars >= Account.maxChars(acct)
end

-- 캐릭터를 하나 넣는다(hero = 저장할 꼴의 캐릭터). 꽉 찼으면 nil
function Account.add(acct, name: string, class: string, hero, now: number?)
	if Account.full(acct) or not CLASSES.classes[class] then
		return nil
	end
	local c = { id = acct.next, name = name, class = class, made = now or 0, hero = hero }
	acct.next += 1
	table.insert(acct.chars, c)
	return c
end

-- 캐릭터를 지운다. 지운 캐릭터를 돌려준다
function Account.remove(acct, id: any)
	local c, i = Account.find(acct, id)
	if not c then
		return nil
	end
	table.remove(acct.chars, i)
	if acct.last == id then
		acct.last = false
	end
	return c
end

-- 계정이 생기기 전의 저장(캐릭터 하나 — 이름이 없다)을 계정으로 옮긴다: 그 캐릭터가 첫 캐릭터가 되고, 그 캐릭터의 창고가 계정의 창고가 된다
function Account.adopt(old: any, now: number?)
	local acct = Account.new()
	if typeof(old) == "table" and CLASSES.classes[old.class] then
		if typeof(old.bag) == "table" then
			acct.store = old.bag.store or false
			old.bag.store = nil
		end
		Account.add(acct, "", old.class, old, now)
	end
	return acct
end

-- ---------- 저장 ----------
function Account.pack(acct)
	local chars = {}
	for _, c in acct.chars do
		table.insert(chars, { id = c.id, name = c.name, class = c.class, made = c.made, hero = c.hero })
	end
	-- 읽지 못한 캐릭터(꼴이 맞지 않던 것)도 그대로 다시 적는다 — 읽는 쪽의 실수로 캐릭터가 사라지지 않게
	for _, raw in acct.broken do
		table.insert(chars, raw)
	end
	return { v = Account.VERSION, next = acct.next, last = acct.last, chars = chars, store = acct.store, storeGot = acct.storeGot, spent = acct.spent, sound = acct.sound, market = Market.packBook(acct.market), tutDone = acct.tutDone == true, att = Attend.pack(acct.att), ach = Achieve.pack(acct.ach), bm = Cash.pack(acct.bm), macro = Macro.pack(acct.macro) }
end

function Account.unpack(data: any)
	if typeof(data) ~= "table" or typeof(data.chars) ~= "table" then
		return nil
	end
	local acct = Account.new()
	-- 유료 상품의 것을 캐릭터보다 먼저 읽는다: 사서 늘린 캐릭터 칸이 있어야 일곱 번째 캐릭터부터가 「읽지 못한 것」으로 빠지지 않는다
	acct.bm = Cash.unpack(data.bm, Account.MAX)
	acct.macro = Macro.unpack(data.macro)
	local top = 0
	for _, raw in data.chars do
		local fine = typeof(raw) == "table" and whole(raw.id, 1, 9e9) and typeof(raw.name) == "string" and CLASSES.classes[raw.class] ~= nil and typeof(raw.hero) == "table" and not Account.find(acct, raw.id)
		if fine and #acct.chars < Account.maxChars(acct) then
			table.insert(acct.chars, { id = raw.id, name = raw.name, class = raw.class, made = if typeof(raw.made) == "number" then raw.made else 0, hero = raw.hero })
		else
			table.insert(acct.broken, raw)
		end
		if typeof(raw) == "table" and whole(raw.id, 1, 9e9) then
			top = math.max(top, raw.id)
		end
	end
	acct.next = math.max(if whole(data.next, 1, 9e9) then data.next else 1, top + 1)
	acct.last = if Account.find(acct, data.last) then data.last else false
	acct.store = if typeof(data.store) == "table" then data.store else false
	-- 창고를 늘린 부탁들(2026-10-18 — 「창고 칸 +4」 보상: 계정에 한 번씩. 이름표 → true). 생기기 전의 저장 = 없음
	acct.storeGot = {}
	if typeof(data.storeGot) == "table" then
		for id, on in data.storeGot do
			if typeof(id) == "string" and #id <= 20 and on == true then
				acct.storeGot[id] = true
			end
		end
	end
	acct.spent = if whole(data.spent, 0, 9e12) then data.spent else 0
	acct.sound = Account.cleanSound(data.sound) or Account.soundDefault() -- 소리 설정이 생기기 전의 저장 = 처음 크기
	acct.market = Market.unpackBook(data.market) -- 경매장이 생기기 전의 저장 = 맡긴 것 없음
	acct.att = Attend.unpack(data.att) -- 출석 · 업적이 생기기 전(2026-10-15)의 저장 = 새 판 · 아무것도 안 함
	acct.ach = Achieve.unpack(data.ach)
	-- 튜토리얼을 한 번 끝냈는가: 저장된 표시, 또는 튜토리얼이 생기기 전(2026-10-14)의 캐릭터 · 꿈에서 깬 캐릭터가 있다
	acct.tutDone = data.tutDone == true
	for _, c in acct.chars do
		if typeof(c.hero) == "table" and (typeof(c.hero.tut) ~= "table" or c.hero.tut.done == true) then
			acct.tutDone = true
		end
	end
	return acct
end

-- ---------- 화면에 보내는 것 ----------
-- 캐릭터 고르기 화면의 표: 캐릭터마다 번호 · 이름 · 직업 · 레벨, 그리고 만들 수 있는 수 · 마지막으로 들어간 캐릭터
function Account.view(acct)
	local chars = {}
	for _, c in acct.chars do
		local level = if typeof(c.hero.level) == "number" then c.hero.level else 1
		table.insert(chars, { id = c.id, name = c.name, class = c.class, level = level, look = c.hero.look }) -- look = 무기 · 로브 색(염색 — 고르는 화면의 그림도 그 색)
	end
	return { chars = chars, max = Account.maxChars(acct), last = acct.last, sound = acct.sound } -- sound = 소리 설정(처음 화면부터 그 크기로 튼다)
end

-- 계정이 받은 창고 칸(탭마다 — 2026-10-18): 「창고 칸」 보상을 준 부탁마다 그 보상의 칸 수(quests의 정의를 본다)
function Account.storeExtra(acct): number
	local Quests = require(script.Parent.quests)
	local n = 0
	for id in acct.storeGot or {} do
		local def = Quests.def(id)
		if def and (def.reward.store or 0) > 0 then
			n += def.reward.store
		end
	end
	-- 창고 확장권(유료 — 2026-10-20): 쓴 번 x 한 장의 칸
	if acct.bm then
		n += acct.bm.store * Cash.RULES.storeStep
	end
	return n
end

return Account
