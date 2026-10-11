-- 2~4차의 버프(갱신 · 파티 · 생존 · 극딜 · 공용) — 공방 js/lune/design/combat.js의 BUFFS → data/combat.generated.luau의 buffs.
--  사용자 2026-10-08: "2~4차 사출기, 설치기, 버프 다 옮겨야합니다."
--  버프 = { who(직업 — 공용은 "all") · job · type · max · dur(초) · cd(다시 쓰기) · fx(세기 — 마스터했을 때의 값) }
--   fx: haste 공격 속도 + · dmg 주는 피해 + · cut 받는 피해 − · guard 그동안 피해를 받지 않는다 · ward 쓰러질 피해를 한 번 버틴다 · full 강타를 끝까지 모은 것으로 친다
--       big 몸이 두 배가 되고 기술이 닿는 거리(앞 · 위)가 그만큼 는다(거신) · echo 분신이 내 베기를 after초 뒤에 따라 벤다 — 그 타 피해의 그만큼(그림자 분신)
--       near 걸어 둔 자리에서 이 거리 안에 있을 때만 듣는다 · party 파티원에게도 걸리는 거리(9999 = 같은 맵의 파티원 모두)
--  세기에는 그 스킬의 레벨에 따른 배수(레벨 1에서 40% → 마스터 100%)를 곱한다 — 건 사람의 레벨로 정해져 버프에 같이 적힌다(pow). 파티원에게 걸린 것도 건 사람의 세기다.
--  캐릭터의 표에 얹는 것: h.buffs[스킬] = { t 남은 시간 · dur · pow 세기 · n 건 차례 · x, y 건 자리 } · h.cds[스킬] = 다시 쓸 수 있는 때(방의 시간). 둘 다 저장하지 않는다(나가면 사라진다).
--  걸리는 순간의 이펙트 · 걸려 있는 동안의 모습은 직업 묶음(shared/lune/kits)이 화면에서 그린다.
local COMBAT = require(script.Parent.Parent.data["combat.generated"])
local CLASSES = require(script.Parent.Parent.data["classes.generated"])

local BUFF = COMBAT.buffs
local FLOOR = CLASSES.skillRule.floor

local Buffs = {}
Buffs.data = BUFF

function Buffs.is(id: any): boolean
	return typeof(id) == "string" and BUFF[id] ~= nil
end

-- 누르면 바로 걸리는 버프인가(쓰는 동작이 있는 것 — 연막탄 — 은 기술의 길로 걸린다)
function Buffs.instant(id: any): boolean
	return typeof(id) == "string" and BUFF[id] ~= nil and BUFF[id].cast ~= "seg"
end

-- 그 캐릭터가 걸 수 있는 버프인가(제 직업의 것이거나 공용이고, 배웠다)
function Buffs.learned(h, id: any): boolean
	local def = if typeof(id) == "string" then BUFF[id] else nil
	return def ~= nil and (def.who == "all" or def.who == h.class) and (h.skills[id] or 0) > 0
end

local function scaleOf(lv: number, max: number): number
	if lv <= 0 then
		return 0
	end
	return FLOOR + (1 - FLOOR) * (if max > 1 then (lv - 1) / (max - 1) else 1)
end

function Buffs.init(h)
	h.buffs, h.cds, h.buffN = {}, {}, 0
end

-- 버프 하나를 얹는다(이미 있으면 새로 건 것으로 바뀐다 — 맨 뒤로 간다). pow = 세기 · (x, y) = 건 자리
function Buffs.give(h, id: string, pow: number, x: number, y: number)
	local def = BUFF[id]
	h.buffN += 1
	h.buffs[id] = { t = def.dur, dur = def.dur, pow = pow, n = h.buffN, x = x, y = y }
end

-- 건다: 배웠고 다시 쓰기가 끝났으면. now = 서버의 시간. 걸었으면 그 세기를 돌려준다(못 걸었으면 nil)
function Buffs.cast(h, id: string, now: number): number?
	if not Buffs.learned(h, id) or (h.cds[id] or 0) > now then
		return nil
	end
	local def = BUFF[id]
	if def.cd > 0 then
		h.cds[id] = now + def.cd
	end
	local pow = scaleOf(h.skills[id], def.max)
	Buffs.give(h, id, pow, h.x, h.y)
	return pow
end

function Buffs.has(h, id: string): boolean
	local b = h.buffs[id]
	return b ~= nil and b.t > 0
end

-- 시간이 흐른다. 끝난 버프의 이름들을 돌려준다(없으면 빈 목록)
function Buffs.tick(h, dt: number)
	local ended = {}
	for id, b in h.buffs do
		b.t -= dt
		if b.t <= 0 then
			table.insert(ended, id)
		end
	end
	for _, id in ended do
		h.buffs[id] = nil
	end
	return ended
end

-- 그 버프가 지금 듣는가(걸어 둔 자리 곁에서만 듣는 것은 거리를 본다)
local function works(h, b, fx): boolean
	return not fx.near or (math.abs(h.x - b.x) <= fx.near and math.abs(h.y - b.y) <= 60)
end

-- 주는 피해의 배수
function Buffs.dmg(h): number
	local mul = 1
	for id, b in h.buffs do
		local fx = BUFF[id].fx
		if fx.dmg and works(h, b, fx) then
			mul *= 1 + fx.dmg * b.pow
		end
	end
	return mul
end

-- 공격 속도의 배수(동작과 타격이 그만큼 빨라진다)
function Buffs.haste(h): number
	local add = 0
	for id, b in h.buffs do
		local fx = BUFF[id].fx
		if fx.haste then
			add += fx.haste * b.pow
		end
	end
	return 1 + add
end

-- 받는 피해의 배수
function Buffs.cut(h): number
	local mul = 1
	for id, b in h.buffs do
		local fx = BUFF[id].fx
		if fx.cut and works(h, b, fx) then
			mul *= 1 - fx.cut * b.pow
		end
	end
	return mul
end

-- 피해를 받지 않는 중인가(생존기)
function Buffs.guard(h): boolean
	for id in h.buffs do
		if BUFF[id].fx.guard then
			return true
		end
	end
	return false
end

-- 쓰러질 피해를 버틴다: 그런 버프가 있으면 그것을 쓰고 true
function Buffs.ward(h): boolean
	for id in h.buffs do
		if BUFF[id].fx.ward then
			h.buffs[id] = nil
			return true
		end
	end
	return false
end

-- 적이 나를 놓치는가(연막 안에 있다)
function Buffs.stealth(h): boolean
	for id, b in h.buffs do
		local fx = BUFF[id].fx
		if fx.stealth and works(h, b, fx) then
			return true
		end
	end
	return false
end

-- 강타를 모으지 않아도 끝까지 모은 것으로 치는가(만월)
function Buffs.full(h): boolean
	for id in h.buffs do
		if BUFF[id].fx.full then
			return true
		end
	end
	return false
end

-- 기술이 닿는 거리의 배수(거신: 앞 · 위로 그만큼 더 닿는다)
function Buffs.big(h): number
	local mul = 1
	for id, b in h.buffs do
		local fx = BUFF[id].fx
		if fx.big then
			mul = math.max(mul, 1 + fx.big * b.pow)
		end
	end
	return mul
end

-- 분신의 따라 베기(그림자 분신): 그 타 피해의 몫 · 몇 초 뒤에. 없으면 0. 쌍영(2~4차의 패시브)을 배웠으면 둘째 분신의 몫이 더해진다
function Buffs.echo(h): (number, number)
	for id, b in h.buffs do
		local fx = BUFF[id].fx
		if fx.echo then
			local share = fx.echo * b.pow
			local twin = COMBAT.passive.rv_clone2
			local lv = h.skills.rv_clone2 or 0
			if twin and lv > 0 and h.class == twin.who then
				share *= 1 + twin.fx.clones * scaleOf(lv, twin.max)
			end
			return share, fx.after or 0.25
		end
	end
	return 0, 0
end

-- 화면에 보내는 것: list = 걸린 버프들(건 차례로) { id, t, dur } · cds = 다시 쓰기까지 남은 시간 { [스킬] = 초 }
function Buffs.view(h, now: number)
	local list, cds = {}, {}
	for id, b in h.buffs do
		table.insert(list, { id = id, t = b.t, dur = b.dur, n = b.n, x = b.x, y = b.y })
	end
	table.sort(list, function(a, b)
		return a.n < b.n
	end)
	for id, at in h.cds do
		if at > now then
			cds[id] = at - now
		end
	end
	return { list = list, cds = cds }
end

return Buffs
