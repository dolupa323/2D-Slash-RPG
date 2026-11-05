-- 「달의 계승자」 — 보스기의 % 피해: 차수가 오를수록 세다(2026-11-05 사용자: "보스기 퍼뎀 3차가 4차보다 쎈경우는 없어야한다").
--  보는 것: 직업마다 1 ~ 4차 보스기(type boss)의 「한 번 쓸 때」 % 피해(스킬 창의 「지금 Lv.n」과 같은 셈 — shared/lune/ui/skillDamage.luau) — 마스터 레벨에서
--   4차는 Lv.1(만렙의 70%)에서도 3차 만렙보다 약하지 않다 · 만렙끼리 · 초당으로도 4차가 세다. 1 · 2차는 적기만 한다(2차 → 3차는 사용자가 말하지 않아 보지 않는다 — 리븐 3차 잔영 난무는 누르고 있는 동안 베는 기술이라 0.5초마다의 %가 2차보다 작다)
local CLASSES = req("ReplicatedStorage/shared/lune/data/classes.generated")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")
local SkillDamage = req("ReplicatedStorage/shared/lune/ui/skillDamage")

local function pctOf(id: string): (number?, number?)
	local def = COMBAT.cast[id]
	if def then
		local c = SkillDamage.cast(id, def.max)
		return if c then c.pct else nil, if c then c.time else nil
	end
	local f = COMBAT.skills[id]
	if f then
		local parts = SkillDamage.firstParts(id, f.max)
		if parts then
			local sum = 0
			for _, p in parts do
				if not p.side then
					sum += p.pct
				end
			end
			return sum, f.time
		end
	end
	return nil, nil
end

for _, cls in { "axion", "riven", "reaper", "mooni", "salamander" } do
	local C = CLASSES.classes[cls]
	local row = {}
	local by = {}
	for t, tier in C.tiers do
		for _, sk in tier.skills do
			if sk.type == "boss" then
				local pct, time = pctOf(sk.id)
				by[t] = { id = sk.id, name = sk.name, pct = pct, time = time }
				table.insert(row, ("%d차 %s %s%%(%.1f초)"):format(t, sk.name, if pct then tostring(math.floor(pct + 0.5)) else "?", time or 0))
			end
		end
	end
	print("[126] " .. cls .. ": " .. table.concat(row, " · "))
	for t = 2, 4 do
		expect(by[t] ~= nil and by[t].pct ~= nil, ("%s %d차 보스기의 %%를 잰다"):format(cls, t))
	end
	-- 3차 → 4차: 4차를 막 배웠을 때(Lv.1 = 만렙의 floor배)도 3차 만렙보다 약하지 않다 — 한 번 쓸 때의 % · 초당 %(쓰는 시간으로 나눈 것) 둘 다
	local a, b = by[3], by[4]
	if a and b and a.pct and b.pct then
		local floor = CLASSES.skillRule.floor
		local lv1 = b.pct * floor
		expect(lv1 >= a.pct, ("%s: 4차 %s Lv.1 %d%% ≥ 3차 %s 만렙 %d%%"):format(cls, b.name, math.floor(lv1 + 0.5), a.name, math.floor(a.pct + 0.5)))
		expect(b.pct > a.pct, ("%s: 4차 만렙 %d%% > 3차 만렙 %d%%"):format(cls, math.floor(b.pct + 0.5), math.floor(a.pct + 0.5)))
		local ra, rb = a.pct / math.max(0.1, a.time or 1), b.pct / math.max(0.1, b.time or 1)
		expect(rb > ra, ("%s: 초당 4차 %d%% > 3차 %d%%"):format(cls, math.floor(rb + 0.5), math.floor(ra + 0.5)))
	end
end
