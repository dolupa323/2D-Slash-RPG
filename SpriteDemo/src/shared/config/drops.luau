-- 사냥 드롭(서버) — 「오문 닌자전」 NINJA_DESIGN.md §6.
--  몬스터를 쓰러뜨리면(기여도 10% 이상인 사람 각자) 엽전 + 그 몬스터가 사는 지역의 드롭 표를 한 줄씩 굴린다.
--  지역 = townWorld species[i].element(지역 id). chance = 그 줄이 나올 확률, count = 개수(없으면 1).
--  초안(2026-10-03). 두루마리(N2) · 무기(N3) 드롭은 아래 SCROLLS · WEAPONS.
local exports = {}

exports.REGION = {
	field = {
		{ item = "GrassBlade", chance = 0.35 },
		{ item = "Branch", chance = 0.28 },
		{ item = "Feather", chance = 0.10 },
		{ item = "CopperBar", chance = 0.05 }, -- 들판 무기 강화 재료
		{ item = "Onigiri", chance = 0.06 },
	},
	bamboo = {
		{ item = "Branch", chance = 0.35 },
		{ item = "Stone", chance = 0.25 },
		{ item = "Feather", chance = 0.12 },
		{ item = "CopperBar", chance = 0.08 },
		{ item = "Onigiri", chance = 0.06 },
	},
	swamp = {
		{ item = "Stone", chance = 0.30 },
		{ item = "CopperBar", chance = 0.14 },
		{ item = "IronBar", chance = 0.05 },
		{ item = "Sushi", chance = 0.06 },
	},
	desert = {
		{ item = "Stone", chance = 0.30 },
		{ item = "IronBar", chance = 0.14 },
		{ item = "GreenGem", chance = 0.04 },
		{ item = "Sushi", chance = 0.06 },
	},
	snow = {
		{ item = "IronBar", chance = 0.16 },
		{ item = "SilverBar", chance = 0.08 },
		{ item = "GreenGem", chance = 0.05 },
		{ item = "Sushi", chance = 0.06 },
	},
	ruins = {
		{ item = "SilverBar", chance = 0.14 },
		{ item = "GoldBar", chance = 0.05 },
		{ item = "RedGem", chance = 0.05 },
		{ item = "Yakitori", chance = 0.06 },
	},
	tower = {
		{ item = "GoldBar", chance = 0.12 },
		{ item = "RedGem", chance = 0.06 },
		{ item = "YellowGem", chance = 0.04 },
		{ item = "Yakitori", chance = 0.06 },
	},
	nest = {
		{ item = "GoldBar", chance = 0.14 },
		{ item = "MithrilBar", chance = 0.06 },
		{ item = "YellowGem", chance = 0.05 },
		{ item = "PurpleGem", chance = 0.03 },
		{ item = "Yakitori", chance = 0.06 },
	},
}

-- 인술 두루마리(N2): 어느 지역에서나 SCROLL_CHANCE 확률로 다섯 유파 중 하나(고르게). 다른 유파 것은 팔거나 거래한다.
exports.SCROLL_CHANCE = 0.012
exports.SCROLLS = { "ScrollFire", "ScrollIce", "ScrollPlant", "ScrollRock", "ScrollThunder" }

-- 무기(N3): 그 지역 무기 중 하나가 WEAPON_CHANCE 확률로. 들판 무기는 잡화 상점에서도 판다.
exports.WEAPON_CHANCE = 0.015
exports.WEAPONS = {
	field = { "Ninjato", "Sai", "Club" },
	bamboo = { "Katana", "Spear", "Whip" },
	swamp = { "LongSword", "Axe" },
	desert = { "Trident", "Scimitar", "Hammer" },
	snow = { "Rapier", "Halberd" },
	ruins = { "GreatSword" },
	tower = { "GreatSword" },
	nest = { "GreatSword" },
}

-- 부적(N3): 그 지역 부적이 CHARM_CHANCE 확률로. 첫 부적(수호 부적)은 잡화 상점에서 판다.
exports.CHARM_CHANCE = 0.008
exports.CHARMS = {
	bamboo = { "WindCharm" },
	swamp = { "WindCharm" },
	desert = { "IronCharm" },
	snow = { "IronCharm" },
	ruins = { "SpiritCharm" },
	tower = { "SpiritCharm" },
	nest = { "SpiritCharm" },
}

-- 한 번 굴림 → { { item = id, count = n }, ... }
function exports.Roll(region: string?, rng: Random)
	local out = {}
	local list = exports.REGION[region or ""]
	if not list then
		return out
	end
	for _, d in list do
		if rng:NextNumber() < d.chance then
			table.insert(out, { item = d.item, count = d.count or 1 })
		end
	end
	if rng:NextNumber() < exports.SCROLL_CHANCE then
		table.insert(out, { item = exports.SCROLLS[rng:NextInteger(1, #exports.SCROLLS)], count = 1 })
	end
	local pool = exports.WEAPONS[region or ""]
	if pool and rng:NextNumber() < exports.WEAPON_CHANCE then
		table.insert(out, { item = pool[rng:NextInteger(1, #pool)], count = 1 })
	end
	local charms = exports.CHARMS[region or ""]
	if charms and rng:NextNumber() < exports.CHARM_CHANCE then
		table.insert(out, { item = charms[rng:NextInteger(1, #charms)], count = 1 })
	end
	return out
end

return exports
