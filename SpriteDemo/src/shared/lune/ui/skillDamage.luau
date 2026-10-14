-- 스킬 창의 「지금 Lv.n · 다음 Lv.n+1」에 적는 공격 스킬의 % 피해.
--  사용자 2026-10-13: "스킬 퍼뎀같은거 스킬 창에 설명에 나와있어야해  메이플처럼 / 스킬레벨 추가로 찍으면 퍼뎀올라가는것도 보여야하고"
--  % = 전투력에 곱하는 값 x 100(한 대상에게 다 맞혔을 때 · 그 스킬 레벨의 세기를 곱한 것) — 서버가 피해를 셈하는 바로 그 값이다:
--    화면에 뜨는 피해 숫자 = 전투력 x % x dmgScale(10). 사냥기를 일반 몬스터에게 · 보스기를 보스에게 쓰면 거기에 +targetBonus%(설명 칸의 민트색 줄). 버프 · 패시브 · 치명타는 그 위에 곱해진다.
--  1차의 사냥기 · 보스기: 타마다의 배수(data/combat.generated.luau의 skills[스킬].hits[].mul) x 스킬 레벨의 세기(Hero.skillScale).
--    글은 공방이 만들어 kitEffects에 실어 보낸다(design/combat.js의 damageText — 공방의 시험 탭과 같은 글). 여기의 firstText는 같은 글을 게임의 수로 다시 만든 것이다(테스트가 둘을 맞춰 본다).
--  2~4차의 쓰는 스킬: 서버가 그 스킬을 빈 방에서 돌려 잰 값(Caster.profile — 쓰는 시간 · 맞는 횟수)으로 셈한다.
--    한 번 다 맞혔을 때 = rate x (쓰는 시간 + cdTime) x 스킬 레벨의 세기(Caster.scale). 타마다의 몫은 스킬의 코드가 정하므로 합과 횟수만 적는다.
--    one = 한 타 · sum = 여러 타(횟수가 늘 같다) · avg = 쓸 때마다 다르다(다섯 번째마다 터지는 것 …) · full = 장치를 다 갖췄을 때가 기준(공명 폭발의 수정 · 열 방출의 열기 — 자료의 w)
--  끝에 그 스킬을 한 번 쓰는 데 드는 시간을 붙인다(dmgWords.time — 바로 나가는 스킬은 빼고): %는 「한 번 쓸 때」의 것이라 빠른 스킬은 %가 작아도 같은 시간에 더 넣는다
--    (2차의 쪼개기 Lv.1 = 199% · 0.5초 / 1차의 삼단 베기 마스터 = 410% · 1.2초 — %만 적으면 2차가 약해 보인다).
--  글의 꼴은 공방의 것(combat.generated.luau의 dmgWords).
local root = script.Parent.Parent
local COMBAT = require(root.data["combat.generated"])
local Hero = require(root.sim.hero)
local Caster = require(root.sim.caster)
local Lines = require(root.sim.lines) -- 타수 나누기: 한 타를 몇 줄로(2026-10-14)
local Format = require(script.Parent.format)

local WORDS = COMBAT.dmgWords
local SkillDamage = {}

local function round(v: number): number
	return math.floor(v + 0.5)
end
-- 쓰는 시간을 붙인다(소수 한 자리 — 공방 design/combat.js의 dmgTime과 같은 법). 0이면 그대로
local function withTime(text: string, t: number): string
	if t <= 0 then
		return text
	end
	return text .. Format.fill(WORDS.time, { t = ("%.1f"):format(math.floor(t * 10 + 0.5) / 10) })
end

-- 1차의 사냥기 · 보스기: 그 레벨에서 타마다의 % { { pct, side } … }. side = 가운데 타의 범위 밖의 적만 맞는 타(대지 강타의 양옆 가시). 아니면 nil
function SkillDamage.firstParts(id: string, lv: number)
	local def = COMBAT.skills[id]
	if not def or def.job ~= 1 or #def.hits == 0 or lv < 1 or lv > def.max then
		return nil
	end
	local s = Hero.skillScale(lv, def.max)
	local out = {}
	for i, h in def.hits do
		out[i] = { pct = h.mul * s * 100, side = h.except ~= nil and h.except ~= false }
	end
	return out
end

function SkillDamage.firstText(id: string, lv: number): string?
	local parts = SkillDamage.firstParts(id, lv)
	if not parts then
		return nil
	end
	local main, sum, same = {}, 0, true
	for _, p in parts do
		if not p.side then
			table.insert(main, p)
			sum += p.pct
		end
	end
	for _, p in main do
		if round(p.pct) ~= round(main[1].pct) then
			same = false
		end
	end
	-- 타수 나누기(sim/lines.luau): 한 타가 L줄로 쪼개진다 — 모두의 줄 수와 합을 적는다(줄마다의 %는 반올림하면 한 레벨 올린 것이 묻혀서 합으로. 공방 design/combat.js의 damageText와 같은 글)
	local L = Lines.first(id)
	local n = #main * L
	local out
	if n == 1 then
		out = Format.fill(WORDS.one, { pct = round(sum) })
	elseif L > 1 then
		out = Format.fill(WORDS.sum, { n = n, pct = round(sum) })
	elseif same then
		out = Format.fill(WORDS.same, { pct = round(main[1].pct), n = #main })
	else
		local list = {}
		for i, p in main do
			list[i] = ("%d%%"):format(round(p.pct))
		end
		out = Format.fill(WORDS.split, { n = #main, pct = round(sum), list = table.concat(list, " + ") })
	end
	for _, p in parts do
		if p.side then
			out ..= Format.fill(WORDS.side, { pct = round(p.pct) })
		end
	end
	return withTime(out, COMBAT.skills[id].time)
end

-- 2~4차의 쓰는 스킬: 그 레벨에서 한 번 다 맞혔을 때의 % · 맞는 횟수 · 글의 꼴 { pct, n, kind }. 피해가 없는 것(묶기만 하는 것 · 회복)은 nil
function SkillDamage.cast(id: string, lv: number)
	local def = COMBAT.cast[id]
	if not def or lv < 1 or lv > def.max then
		return nil
	end
	-- 재다가 탈이 나도 스킬 창은 멈추지 않는다(그 스킬의 %만 비운다 — 테스트는 %가 있는지를 본다)
	local ok, p = pcall(function()
		if not Caster.makeDry then
			require(root.sim.room) -- 재 볼 빈 방을 짓는 함수는 방의 셈이 넣어 준다(sim/room.luau) — 화면에서는 여기서 처음 불러온다
		end
		return Caster.profile(id, 0)
	end)
	if not ok or not p then
		return nil
	end
	local pct = def.rate * (p.time + def.cdTime) * Caster.scale(lv, def.max) * 100
	if pct < 0.5 or p.measured <= 0 then
		return nil
	end
	local L = Caster.lines(id) -- 타수 나누기: 한 타를 L줄로 — 적는 횟수는 줄의 수
	local n = round(p.hits) * L
	local kind = if def.w then "full" elseif math.abs(p.hits - round(p.hits)) > 0.01 then "avg" elseif n <= 1 then "one" else "sum"
	return { pct = pct, n = n, kind = kind, time = p.time, lines = L }
end

function SkillDamage.castText(id: string, lv: number): string?
	local c = SkillDamage.cast(id, lv)
	if not c then
		return nil
	end
	return withTime(Format.fill(WORDS[c.kind], { pct = round(c.pct), n = c.n }), c.time)
end

-- 스킬 창이 그 레벨에 적는 글: 공방이 실어 보낸 효과 글(사출기 · 장치 · 패시브 · 버프 · 1차 공격 스킬의 % 피해)이 있으면 그것, 없으면 2~4차의 쓰는 스킬의 % 피해. 적을 것이 없으면 nil
function SkillDamage.text(id: string, lv: number): string?
	local list = COMBAT.kitEffects[id]
	if list then
		return list[lv]
	end
	return SkillDamage.castText(id, lv)
end

return SkillDamage
