-- 장비 창의 능력치 표 — 줄 · 칸의 자리와 값의 글(화면 없이 셈한다: 창은 client/lune/ui/equipWindow.luau, 글이 칸에 드는지는 15_lune_items가 본다).
--  사용자 2026-10-14: "장비 탭에 지금 전투력, 방어력만 표기되는데 여기에 현재 스텟, 공격력 등 여러 수치가 다 출력되어야하고 크리티컬 확률, 크리티컬 데미지 이런것도 다 나와야합니다."
--  줄의 차례 · 이름은 공방 design/ui.js의 UILAYOUT.equip.sheet, 수는 서버가 셈한 내 상태의 sheet(sim/hero.luau의 Hero.sheet)와 능력치 · 전투력 · 최대 체력.
local root = script.Parent.Parent
local N = require(root.config.numbers)
local Layout = require(script.Parent.layout)
local Format = require(script.Parent.format)

local SH = Layout.EQUIP.sheet
local STATS = N.data.STATS

local Sheet = {}
Sheet.SH = SH

-- 칸들의 자리(오른쪽 덩이의 왼쪽 위가 0, 0 · 가르는 줄 바로 아래부터). width = 오른쪽 덩이의 폭. { id, x, y, w }의 목록
function Sheet.cells(width: number)
	local colW = math.floor((width - SH.colGap) / 2)
	local out = {}
	for r, row in SH.rows do
		local y = SH.top + (r - 1) * SH.row
		for c, id in row do
			if #row == 1 then
				table.insert(out, { id = id, x = 0, y = y, w = width })
			else
				table.insert(out, { id = id, x = (c - 1) * (colW + SH.colGap), y = y, w = colW })
			end
		end
	end
	return out
end

-- 표의 높이(가르는 줄 아래부터)
function Sheet.height(): number
	return SH.top + #SH.rows * SH.row
end

-- 칸의 이름
function Sheet.name(id: string): string
	return SH.names[id] or STATS.names[id] or id
end

-- 그 직업에게 그 능력치가 무엇인가: "main"(주) · "sub"(부) · "none"(안 쓴다). 능력치가 아니면 nil
function Sheet.tone(class: string, id: string): string?
	if STATS.names[id] == nil then
		return nil
	end
	local pair = STATS.classes[class]
	if id == "hp" then
		return "hp"
	end
	return if pair[1] == id then "main" elseif pair[2] == id then "sub" else "none"
end

-- 수의 글: 만 넘으면 짧게(「1.2만」) · 아니면 쉼표
local function num(n: number): string
	return if n >= 1e4 then Format.short(n) else Format.comma(n)
end
-- %의 수: 정수면 정수, 아니면 소수 한 자리
local function p(v: number): string
	local r = math.floor(v + 0.5)
	if math.abs(v - r) < 0.05 then
		return tostring(r)
	end
	return ("%.1f"):format(v)
end

-- 칸마다의 값 { [id] = 글 }. me = 서버가 보낸 내 상태(sheet · stats · power · maxHp · class)
function Sheet.values(me)
	local s = me.sheet
	local out = {}
	if not s then
		return out
	end
	out.atk = ("%s ~ %s"):format(num(s.atk[1]), num(s.atk[2]))
	out.power = Format.short(me.power)
	out.maxHp = num(me.maxHp)
	for _, id in STATS.order do
		out[id] = tostring(STATS.base + (me.stats[id] or 0))
	end
	-- 두 칸짜리 줄의 %는 정수로(가장 작은 화면에서 칸이 78점 — 소수까지 적으면 넘친다)
	local function i(v: number): string
		return tostring(math.floor(v + 0.5))
	end
	out.guard = i(s.guard) .. "%"
	out.critRate = p(s.crit) .. "%" -- 크리티컬은 한 줄을 다 쓰니 소수 한 자리까지
	out.critDmg = p(s.critDmg) .. "%"
	out.dmg = "+" .. i(math.max(0, s.dmg)) .. "%"
	out.final = "+" .. i(math.max(0, s.final)) .. "%"
	out.haste = "+" .. i(math.max(0, s.haste)) .. "%"
	out.cut = if s.cut >= 0.5 then "-" .. i(s.cut) .. "%" else "0%"
	out.run = i(s.run) .. "%"
	out.jump = i(s.jump) .. "%"
	return out
end

return Sheet
