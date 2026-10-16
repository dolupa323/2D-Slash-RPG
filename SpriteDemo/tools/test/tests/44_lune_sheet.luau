-- 「달의 계승자」 — 장비 창의 능력치 표(2026-10-14): 서버가 셈하는 값(sim/hero.luau의 Hero.sheet) · 표에 적히는 글(shared/lune/ui/sheet.luau).
--  사용자: "장비 탭에 지금 전투력, 방어력만 표기되는데 여기에 현재 스텟, 공격력 등 여러 수치가 다 출력되어야하고 크리티컬 확률, 크리티컬 데미지 이런것도 다 나와야합니다."
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local Hero = req("ReplicatedStorage/shared/lune/sim/hero")
local Room = req("ReplicatedStorage/shared/lune/sim/room")
local Caster = req("ReplicatedStorage/shared/lune/sim/caster")
local Sheet = req("ReplicatedStorage/shared/lune/ui/sheet")
local _ = Room
local RULES = COMBAT.rules
local STATS = N.data.STATS

local h = Hero.new(1, "axion")
local s = Hero.sheet(h)
expect(Hero.view(h).sheet ~= nil, "내 상태에 능력치 표가 실려 간다")
eq(s.crit, RULES.critChance, "치명타 확률 = 기본 5%")
eq(s.critDmg, RULES.critMul * 100, "치명타 피해 = 150%")
eq(s.dmg, 0, "버프가 없으면 주는 피해 +0%")
eq(s.haste, 0, "버프가 없으면 공격 속도 +0%")
eq(s.run, 100, "이동 속도 100%")
-- 공격력 = 100% 한 타의 피해의 범위: 서버가 실제로 주는 피해와 맞는다(흩어짐 ±spread%)
local base = Hero.powerRaw(h) * RULES.dmgScale
expect(math.abs(s.atk[1] - base * (1 - RULES.spread / 100)) <= 1 and math.abs(s.atk[2] - base * (1 + RULES.spread / 100)) <= 1, "공격력의 범위 = 전투력 x 10 x (1 ± 흩어짐)")
do
	-- 보스기(보정이 없는 상대 = 일반 몬스터)로 한 번 쳐 본 피해가 「공격력 x 그 타의 %」 범위 안
	local def = COMBAT.skills.ax_combo
	local room, foe = Caster.makeDry(2014, 176)
	h.x, h.y, h.dir = 2000, 176, 1
	h.skills.ax_combo = 1
	local keep = RULES.critChance
	RULES.critChance = 0
	for _ = 1, 20 do
		foe.hp = foe.maxHp
		local res = room:skillHit(h, def.hits[1], h.x, h.y, 1, Hero.skillScale(1, def.max), nil, "boss", "ax_combo")
		local mul = def.hits[1].mul * Hero.skillScale(1, def.max)
		for _, e in res.hits do
			expect(e.dmg >= s.atk[1] * mul - 1 and e.dmg <= s.atk[2] * mul + 1, ("한 타의 피해(%d)가 공격력 x %%의 범위 안(%d ~ %d)"):format(e.dmg, s.atk[1] * mul, s.atk[2] * mul))
		end
	end
	RULES.critChance = keep
end
-- 표의 글
local v = Sheet.values({ class = "axion", stats = h.stats, power = 1234, maxHp = 56789, sheet = s })
eq(v.str, tostring(STATS.base + h.stats.str + Hero.spec(h).gearStat), "힘 = 처음 값 + 찍은 점수 + 장비의 올스탯(2026-10-15 — 능력치 창과 같은 수)")
expect(v.attack ~= nil and v.def ~= nil, "공격력 · 방어력 칸(2026-10-15)")
eq(v.maxHp, "5.7만", "만 넘는 체력은 짧게")
eq(v.critRate, "5%", "크리티컬 확률은 제 줄에")
eq(v.critDmg, "150%", "크리티컬 데미지는 제 줄에")
eq(Sheet.name("critRate"), "크리티컬 확률", "이름: 크리티컬 확률(사용자의 말)")
eq(Sheet.name("critDmg"), "크리티컬 데미지", "이름: 크리티컬 데미지(사용자의 말)")
eq(v.dmg, "+0%", "주는 피해")
eq(v.cut, tostring(math.floor(Hero.sheet(h).cut + 0.5)) .. "%", "받는 피해 감소 = 방어력 · 버프 · 패시브(같은 레벨 방어구면 30%쯤)")
eq(Sheet.tone("axion", "str"), "main", "액시온의 주 능력치 = 힘")
eq(Sheet.tone("axion", "dex"), "sub", "부 능력치 = 민첩")
eq(Sheet.tone("axion", "luk"), "none", "안 쓰는 능력치")
eq(Sheet.tone("axion", "atk"), nil, "능력치가 아닌 칸")
local names = {}
for _, c in Sheet.cells(200) do
	names[c.id] = true
end
for _, id in { "atk", "power", "maxHp", "attack", "def", "str", "dex", "int", "luk", "hp", "critRate", "critDmg", "dmg", "final", "haste", "cut", "run", "jump" } do
	expect(names[id], "표에 있다: " .. id)
end
