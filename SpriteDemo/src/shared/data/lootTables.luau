-- 몬스터별 드롭 표 — 몬스터 종류(서버 모듈 이름과 같은 키) → 드롭 목록. 각 항목은 독립적으로
-- 확률(Chance, 0~1)을 굴리고, 성공하면 Min~Max개를 준다(Cheruton의 몬스터별 루팅 테이블
-- 패턴). ItemId는 items.luau에 있는 것만 써야 한다.
local lootTables = {
	SproutGrub = {
		-- 골드는 아이템이 아니라 별도 화폐라 ItemId 대신 "Gold"로 표시하고 Min~Max 골드를 준다.
		{ ItemId = "Gold", Chance = 0.9, Min = 3, Max = 8 },
		{ ItemId = "SproutFragment", Chance = 0.6, Min = 1, Max = 2 },
		{ ItemId = "GrubSap", Chance = 0.1, Min = 1, Max = 1 },
		{ ItemId = "WoodenSword", Chance = 0.08, Min = 1, Max = 1 },
		{ ItemId = "LeafArmor", Chance = 0.08, Min = 1, Max = 1 },
	},
}

return lootTables
