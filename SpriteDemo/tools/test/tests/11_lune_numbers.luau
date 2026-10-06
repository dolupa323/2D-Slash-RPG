-- 「달의 계승자」 — 숫자 뼈대: 게임의 식(shared/lune/config/numbers.luau)이 공방의 식과 같은 값을 내는가
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local D = req("ReplicatedStorage/shared/lune/data/numbers.generated")
local K = D.checks

local function near(a, b)
	return math.abs(a - b) <= 1e-5 * math.max(1, math.abs(b))
end

for i, L in K.levels do
	expect(near(N.minutesAt(L), K.minutesAt[i]), ("minutesAt(%d) %s ≠ %s"):format(L, N.minutesAt(L), K.minutesAt[i]))
	eq(N.killsAt(L), K.killsAt[i], "killsAt " .. L)
	eq(N.mobXp(L), K.mobXp[i], "mobXp " .. L)
	eq(N.mobHp(L), K.mobHp[i], "mobHp " .. L)
	eq(N.xpNeed(L), K.xpNeed[i], "xpNeed " .. L)
	eq(N.baseHp(L), K.baseHp[i], "baseHp " .. L)
	eq(N.refPower(L), K.refPower[i], "refPower " .. L)
	eq(N.hitOf("mob", L), K.mobHit[i], "일반 몬스터의 한 방 " .. L)
	eq(N.deathMinutes(L), K.deathMinutes[i], "deathMinutes " .. L)
	eq(N.apAt(L), K.apAt[i], "apAt " .. L)
	eq(N.spAt(L), K.spAt[i], "spAt " .. L)
	expect(near(N.killMoney(L), K.killMoney[i]), "killMoney " .. L)
	for class, list in K.hpOf do
		eq(N.hpOf(class, L), list[i], ("hpOf %s %d"):format(class, L))
	end
	eq(N.hpOf("axion", L, 50), K.hpWithPoints[i], "체력에 50점 찍은 액시온 " .. L)
end
for _, c in K.statEff do
	expect(near(N.statEff(c[1], c[2], c[3]), c[4]), ("statEff(%d, %d, %d)"):format(c[1], c[2], c[3]))
end
for _, c in K.armorCut do
	eq(N.armorCut(c[1], c[2]), c[3], ("armorCut(%d, %d)"):format(c[1], c[2]))
end

-- 레벨 차이에 따른 경험치
eq(N.xpRate(10, 10), 100, "같은 레벨 100%")
eq(N.xpRate(10, 20), 100, "차이 10까지 100%")
eq(N.xpRate(10, 25), 75, "차이 15면 75%")
eq(N.xpRate(10, 30), 50, "차이 20이면 50%")
eq(N.xpRate(10, 31), 10, "차이 21부터 10%")
eq(N.xpRate(60, 30), 10, "높은 레벨이 낮은 몬스터를 잡아도 10%")

-- 물약: 레벨에 맞는 단
eq(N.potionAt(1).lv, 1, "Lv.1의 물약")
eq(N.potionAt(29).lv, 1, "Lv.29까지 작은 물약")
eq(N.potionAt(30).lv, 30, "Lv.30부터 달빛 물약")
eq(N.potionAt(150).lv, 100, "Lv.150의 물약")
expect(N.potionAt(60).price > N.potionAt(30).price, "윗단 물약이 더 비싸다")

-- 크기 감각: 같은 레벨 몬스터 체력 = 전투력의 6배쯤, 한 방 = 내 체력의 몇 %
for _, L in { 5, 30, 100, 150 } do
	local ratio = N.mobHp(L) / N.refPower(L)
	expect(ratio > 5.5 and ratio < 6.5, ("Lv.%d 몬스터 체력 ÷ 전투력 = %.2f"):format(L, ratio))
	local hit = N.hitOf("mob", L) / N.hpOf("riven", L)
	expect(hit > 0.03 and hit < 0.08, ("Lv.%d 한 방이 가장 여린 직업 체력의 %.1f%%"):format(L, hit * 100))
end
expect(N.xpNeed(149) > N.xpNeed(100) and N.xpNeed(100) > N.xpNeed(30), "뒤 레벨일수록 경험치가 많이 든다")
