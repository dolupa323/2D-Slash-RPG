-- 아이템 마스터 데이터(정적 표) — ROADMAP Phase 3, Cheruton의 "마스터 표 + 인벤토리엔 ID와
-- 수량만" 패턴. 인벤토리에는 { Tab, Slot, ItemId, Count }만 저장하고, 이름/설명/최대 스택 같은 정적
-- 정보는 항상 이 표에서 ItemId로 조회한다(저장 데이터가 커지지 않고, 표를 고치면 기존
-- 아이템에도 바로 반영됨). ItemId는 사람이 읽을 수 있는 고유 문자열이다(서버 검증/거래 대비).
--
-- Tab: 가방 탭 — "Equip"(장비) / "Use"(소비) / "Etc"(기타) / "Cash"(캐시) / "Key"(중요). 탭마다 칸이 따로 있다.
-- Vfx: 무기로 맞힌 몬스터 위 베기 이펙트 색 { core, edge }, WorldIcon: 장착 시 등 뒤 그림(client/modules/town/weapon.luau). Price: 가게에서 살 때 값(골드), SellPrice: 가게에 팔 때 값(없으면 못 판다). Heal: 소비 아이템 사용 시 체력 회복량.
-- KitIcon: 도트 UI 키트 아이콘 이름 — 아이템마다 전용 아이콘(에셋 공방 js/ui.js의 아이템 아이콘: potion_red 등). 비어 있으면
-- 이름 첫 글자로 대신 표시한다. Icon: 나중에 전용 아이콘 이미지(rbxassetid://...)가 생기면 여기에(KitIcon보다 우선).
local items = {
	-- ===== 장비 =====
	-- EquipSlot이 있으면 착용 가능(Weapon/Armor). 공격력/방어력은 서버가 착용 중인 장비에서 합산해 전투에 반영한다.
	WoodenSword = {
		Name = "나무 검",
		Tab = "Equip",
		Type = "Weapon",
		EquipSlot = "Weapon",
		StackMax = 1,
		Attack = 5,
		SellPrice = 20,
		-- 맞은 몬스터 위에 나오는 베기 VFX 색: core = 안쪽, edge = 바깥 테두리 — 나무 검은 나뭇결 색
		Vfx = { core = Color3.fromRGB(231, 196, 154), edge = Color3.fromRGB(255, 244, 224) },
		Description = "단단한 나무로 깎아 만든 검. 공격력 +5.",
		KitIcon = "sword_wood",
		WorldIcon = "sword_wood_world", -- 착용 모습(에셋 공방 도트 편집 → 무기에서 따로 고친다)
		Icon = "",
	},
	LeafArmor = {
		Name = "잎사귀 갑옷",
		Tab = "Equip",
		Type = "Armor",
		EquipSlot = "Armor",
		StackMax = 1,
		Defense = 2,
		SellPrice = 20,
		Description = "겹겹이 엮은 잎사귀 갑옷. 방어력 +2.",
		KitIcon = "armor_leaf",
		Icon = "",
	},
	-- ===== 소비 =====
	RedPotion = {
		Name = "빨간 물약",
		Tab = "Use",
		Type = "Consumable",
		StackMax = 99,
		Heal = 50,
		Price = 50,
		SellPrice = 10,
		Description = "체력을 50 회복해 주는 달콤한 물약.",
		KitIcon = "potion_red",
		Icon = "",
	},
	OrangePotion = {
		Name = "주황 물약",
		Tab = "Use",
		Type = "Consumable",
		StackMax = 99,
		Heal = 150,
		Price = 150,
		SellPrice = 30,
		Description = "체력을 150 회복해 주는 새콤한 물약.",
		KitIcon = "potion_orange",
		Icon = "",
	},
	WhitePotion = {
		Name = "하얀 물약",
		Tab = "Use",
		Type = "Consumable",
		StackMax = 99,
		Heal = 9999,
		Price = 400,
		SellPrice = 80,
		Description = "체력을 가득 채워 주는 귀한 물약.",
		KitIcon = "potion_white",
		Icon = "",
	},
	-- ===== 기타 =====
	SproutFragment = {
		Name = "새싹 조각",
		Tab = "Etc",
		Type = "Material",
		StackMax = 99,
		SellPrice = 3,
		Description = "새싹 몬스터의 몸에서 떨어진 연두빛 조각.",
		KitIcon = "sprout",
		Icon = "",
	},
	GrubSap = {
		Name = "벌레 수액",
		Tab = "Etc",
		Type = "Material",
		StackMax = 99,
		SellPrice = 5,
		Description = "끈적하고 달콤한 수액. 드물게 얻을 수 있다.",
		KitIcon = "sap",
		Icon = "",
	},
	-- ===== 중요 =====
	RainbowEgg = {
		Name = "무지개 알",
		Tab = "Key",
		Type = "Key",
		StackMax = 1,
		Description = "따뜻하게 두면 어떤 친구가 태어날까요? 버릴 수 없는 소중한 알.",
		KitIcon = "egg_rainbow",
		Icon = "",
		NoDrop = true, -- 중요 물품은 버릴 수 없다
	},
}

return items
