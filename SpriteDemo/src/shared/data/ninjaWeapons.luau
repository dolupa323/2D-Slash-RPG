-- 「오문 닌자전」 무기(NINJA_DESIGN.md §7) — shared/data/items.luau가 합친다. 그림 = Ninja Adventure 팩 무기.
--  Class = 무기 종류(shared/config/weapons.luau CLASSES) · Level = 쓸 수 있는 레벨 · Attack = 공격력(대략 3 + 1.2 × Level)
--  얻는 곳: 들판 무기는 잡화 상점(Price), 그 뒤 지역 무기는 그 지역 몬스터가 드물게 떨어뜨린다(shared/config/drops.luau WEAPONS).
--  아이콘: 팩 아이템 시트(itemIcons.generated) — KitIcon = "nj_<키>". 등 뒤에 메는 그림도 같은 아이콘을 쓴다.
local function weapon(name: string, class: string, level: number, icon: string, desc: string, price: number?)
	local attack = math.round(3 + 1.2 * level)
	return {
		Name = name, Tab = "Equip", Type = "Weapon", EquipSlot = "Weapon", StackMax = 1,
		Class = class, Level = level, Attack = attack,
		Price = price, SellPrice = attack * 6,
		Description = desc,
		KitIcon = "nj_" .. icon, Icon = "",
	}
end

return {
	-- ===== 새싹 들판(Lv.1~) — 잡화 상점에서 판다 =====
	Ninjato = weapon("닌자도", "sword", 1, "ninjaku", "견습 닌자의 곧은 칼.", 60),
	Sai = weapon("사이", "dual", 5, "sai", "양손에 쥐는 갈래 단검.", 180),
	Club = weapon("나무 곤봉", "heavy", 5, "club", "묵직한 나무 곤봉.", 180),
	-- ===== 대나무 숲(Lv.10~) =====
	Katana = weapon("카타나", "sword", 10, "katana", "잘 벼린 닌자의 칼."),
	Spear = weapon("죽창", "polearm", 12, "lance", "길게 찌르는 대나무 창."),
	Whip = weapon("덩굴 채찍", "whip", 15, "whip", "넓게 휘두르는 채찍."),
	-- ===== 개울과 늪(Lv.20~) =====
	LongSword = weapon("장검", "sword", 20, "sword", "날이 긴 검."),
	Axe = weapon("도끼", "heavy", 22, "axe", "늪 나무도 쪼개는 도끼."),
	-- ===== 모래 사막(Lv.30~) =====
	Trident = weapon("삼지창", "polearm", 30, "fork", "세 갈래 창."),
	Scimitar = weapon("사막의 검", "sword", 35, "sword2", "사막 도적이 쓰던 검."),
	Hammer = weapon("전투 망치", "heavy", 38, "hammer", "바위도 부수는 망치."),
	-- ===== 눈 덮인 산(Lv.45~) =====
	Rapier = weapon("얼음 세검", "sword", 45, "rapier", "가늘고 날카로운 검."),
	Halberd = weapon("미늘창", "polearm", 50, "lance2", "날이 달린 긴 창."),
	-- ===== 버려진 마을(Lv.60~) =====
	GreatSword = weapon("대검", "heavy", 60, "bigsword", "두 손으로 드는 큰 검."),
}
