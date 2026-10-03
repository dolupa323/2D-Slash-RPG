-- 「오문 닌자전」 아이템(NINJA_DESIGN.md §4 · §6) — shared/data/items.luau가 합친다.
--  아이콘: 팩 아이템 시트(shared/data/itemIcons.generated.luau) — KitIcon = "nj_<키>".
--  Throw(투척 무기, 단축칸 1·2·3으로 던진다 — 쓰면 1개 줄어듦):
--   power = 피해 배율(× 내 공격력) · range = 날아가는 거리(도트) · speed = 도트/초 · width = 직선에서 옆으로 맞는 폭(도트)
--   radius = 있으면 닿은 자리(안 맞으면 끝까지 날아간 자리) 둘레 모두에게(폭탄)
return {
	-- ===== 투척 무기 =====
	Shuriken = {
		Name = "수리검", Tab = "Use", Type = "Throw", StackMax = 99, Price = 4, SellPrice = 1,
		Throw = { power = 0.8, range = 96, speed = 220, width = 6 },
		Description = "가볍게 던지는 표창. 공격력의 80% 피해.",
		KitIcon = "nj_shuriken", Icon = "",
	},
	Kunai = {
		Name = "쿠나이", Tab = "Use", Type = "Throw", StackMax = 99, Price = 10, SellPrice = 2,
		Throw = { power = 1.3, range = 112, speed = 260, width = 5 },
		Description = "멀리 곧게 날아가는 단검. 공격력의 130% 피해.",
		KitIcon = "nj_kunai", Icon = "",
	},
	Bomb = {
		Name = "폭탄", Tab = "Use", Type = "Throw", StackMax = 50, Price = 35, SellPrice = 8,
		Throw = { power = 2.0, range = 64, speed = 120, width = 8, radius = 22 },
		Description = "닿은 자리에서 터져 둘레 모두에게 공격력의 200% 피해.",
		KitIcon = "nj_bomb", Icon = "",
	},
	-- ===== 음식(체력 회복) =====
	Onigiri = {
		Name = "주먹밥", Tab = "Use", Type = "Consumable", StackMax = 99, Heal = 40, Price = 15, SellPrice = 3,
		Description = "든든한 주먹밥. 체력을 40 회복.",
		KitIcon = "nj_onigiri", Icon = "",
	},
	Sushi = {
		Name = "초밥", Tab = "Use", Type = "Consumable", StackMax = 99, Heal = 120, Price = 45, SellPrice = 9,
		Description = "신선한 초밥. 체력을 120 회복.",
		KitIcon = "nj_sushi", Icon = "",
	},
	Yakitori = {
		Name = "닭꼬치", Tab = "Use", Type = "Consumable", StackMax = 99, Heal = 260, Price = 110, SellPrice = 22,
		Description = "숯불 향 가득한 꼬치. 체력을 260 회복.",
		KitIcon = "nj_yakitori", Icon = "",
	},
	-- ===== 인술 두루마리(드묾 — 자기 유파 것을 쓰면 인술 단계 +1, server/modules/ninjutsuService.luau UseScroll) =====
	ScrollFire = { Name = "불의 두루마리", Tab = "Use", Type = "Scroll", School = "fire", StackMax = 99, SellPrice = 150, Description = "불 유파의 비전. 쓰면 불 인술이 한 단계 오른다.", KitIcon = "nj_scroll_fire", Icon = "" },
	ScrollIce = { Name = "얼음의 두루마리", Tab = "Use", Type = "Scroll", School = "ice", StackMax = 99, SellPrice = 150, Description = "얼음 유파의 비전. 쓰면 얼음 인술이 한 단계 오른다.", KitIcon = "nj_scroll_ice", Icon = "" },
	ScrollPlant = { Name = "풀의 두루마리", Tab = "Use", Type = "Scroll", School = "plant", StackMax = 99, SellPrice = 150, Description = "풀 유파의 비전. 쓰면 풀 인술이 한 단계 오른다.", KitIcon = "nj_scroll_plant", Icon = "" },
	ScrollRock = { Name = "바위의 두루마리", Tab = "Use", Type = "Scroll", School = "rock", StackMax = 99, SellPrice = 150, Description = "바위 유파의 비전. 쓰면 바위 인술이 한 단계 오른다.", KitIcon = "nj_scroll_rock", Icon = "" },
	ScrollThunder = { Name = "번개의 두루마리", Tab = "Use", Type = "Scroll", School = "thunder", StackMax = 99, SellPrice = 150, Description = "번개 유파의 비전. 쓰면 번개 인술이 한 단계 오른다.", KitIcon = "nj_scroll_thunder", Icon = "" },
	-- ===== 부적(방어구 대신 차는 장신구 — NINJA_DESIGN §7. 착용 칸은 옛 방어구 칸 "Armor"를 그대로 쓴다) =====
	--  Defense = 몬스터에게 받는 피해에서 빼는 값 · Level = 찰 수 있는 레벨. 첫 부적은 잡화 상점, 나머지는 드롭(shared/config/drops.luau CHARMS)
	GuardCharm = { Name = "수호 부적", Tab = "Equip", Type = "Charm", EquipSlot = "Armor", StackMax = 1, Level = 1, Defense = 2, Price = 90, SellPrice = 24, Description = "몸을 지켜 주는 부적. 방어력 +2.", KitIcon = "nj_charm1", Icon = "" },
	WindCharm = { Name = "바람 부적", Tab = "Equip", Type = "Charm", EquipSlot = "Armor", StackMax = 1, Level = 15, Defense = 7, SellPrice = 84, Description = "바람이 공격을 흘려 낸다. 방어력 +7.", KitIcon = "nj_charm2", Icon = "" },
	IronCharm = { Name = "금강 부적", Tab = "Equip", Type = "Charm", EquipSlot = "Armor", StackMax = 1, Level = 35, Defense = 16, SellPrice = 192, Description = "몸이 쇠처럼 단단해진다. 방어력 +16.", KitIcon = "nj_charm3", Icon = "" },
	SpiritCharm = { Name = "신령 부적", Tab = "Equip", Type = "Charm", EquipSlot = "Armor", StackMax = 1, Level = 60, Defense = 30, SellPrice = 360, Description = "신령이 깃든 부적. 방어력 +30.", KitIcon = "nj_charm3", Icon = "" },
	-- ===== 재료(사냥 드롭 — 강화·제작에 쓴다, N3) =====
	GrassBlade = { Name = "풀잎", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 1, Description = "들판 몬스터가 떨어뜨리는 질긴 풀잎.", KitIcon = "nj_grass", Icon = "" },
	Branch = { Name = "나뭇가지", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 2, Description = "단단한 나뭇가지. 무기 손잡이 재료.", KitIcon = "nj_branch", Icon = "" },
	Feather = { Name = "깃털", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 3, Description = "가벼운 깃털. 화살과 부적 재료.", KitIcon = "nj_feather", Icon = "" },
	Stone = { Name = "돌멩이", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 2, Description = "묵직한 돌멩이.", KitIcon = "nj_rock", Icon = "" },
	CopperBar = { Name = "구리 주괴", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 8, Description = "무기 강화에 쓰는 구리 주괴.", KitIcon = "nj_bar_copper", Icon = "" },
	IronBar = { Name = "철 주괴", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 16, Description = "무기 강화에 쓰는 철 주괴.", KitIcon = "nj_bar_iron", Icon = "" },
	SilverBar = { Name = "은 주괴", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 30, Description = "무기 강화에 쓰는 은 주괴.", KitIcon = "nj_bar_silver", Icon = "" },
	GoldBar = { Name = "금 주괴", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 55, Description = "무기 강화에 쓰는 금 주괴.", KitIcon = "nj_bar_gold", Icon = "" },
	MithrilBar = { Name = "미스릴 주괴", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 100, Description = "아주 귀한 미스릴 주괴.", KitIcon = "nj_bar_mithril", Icon = "" },
	GreenGem = { Name = "초록 보석", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 40, Description = "풀빛이 도는 보석.", KitIcon = "nj_gem_green", Icon = "" },
	RedGem = { Name = "붉은 보석", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 60, Description = "불빛이 도는 보석.", KitIcon = "nj_gem_red", Icon = "" },
	YellowGem = { Name = "노란 보석", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 80, Description = "번개 빛이 도는 보석.", KitIcon = "nj_gem_yellow", Icon = "" },
	PurpleGem = { Name = "보라 보석", Tab = "Etc", Type = "Material", StackMax = 99, SellPrice = 120, Description = "신비한 보라 보석.", KitIcon = "nj_gem_purple", Icon = "" },
}
