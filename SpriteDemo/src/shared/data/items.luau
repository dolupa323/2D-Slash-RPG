-- 아이템 마스터 데이터(정적 표) — ROADMAP Phase 3, Cheruton의 "마스터 표 + 인벤토리엔 ID와
-- 수량만" 패턴. 인벤토리에는 { ItemId, Count }만 저장하고, 이름/설명/최대 스택 같은 정적
-- 정보는 항상 이 표에서 ItemId로 조회한다(저장 데이터가 커지지 않고, 표를 고치면 기존
-- 아이템에도 바로 반영됨). ItemId는 Cheruton처럼 위치/카테고리를 인코딩한 숫자가 아니라
-- 사람이 읽을 수 있는 고유 문자열이다(서버 검증/거래 대비).
--
-- Icon: 아이콘 이미지 에셋 id(rbxassetid://...). 사용자가 나중에 이미지를 가져오면 여기만
-- 채우면 인벤토리 UI에 그대로 반영된다 — 비어 있으면 UI가 이름 첫 글자로 대신 표시한다.
local items = {
	SproutFragment = {
		Name = "새싹 조각",
		Type = "Material",
		StackMax = 99,
		Description = "새싹벌레의 몸에서 떨어진 연두빛 조각.",
		Icon = "",
	},
	GrubSap = {
		Name = "벌레 수액",
		Type = "Material",
		StackMax = 99,
		Description = "끈적하고 달콤한 수액. 드물게 얻을 수 있다.",
		Icon = "",
	},
	-- 장비: EquipSlot이 있으면 착용 가능(Weapon/Armor). 공격력/방어력은 서버(playerData.luau)가
	-- 착용 중인 장비에서 합산해 전투에 반영한다.
	WoodenSword = {
		Name = "나무 검",
		Type = "Weapon",
		EquipSlot = "Weapon",
		StackMax = 1,
		Attack = 5,
		Description = "단단한 나무로 깎아 만든 검. 공격력 +5.",
		Icon = "",
	},
	LeafArmor = {
		Name = "잎사귀 갑옷",
		Type = "Armor",
		EquipSlot = "Armor",
		StackMax = 1,
		Defense = 2,
		Description = "겹겹이 엮은 잎사귀 갑옷. 방어력 +2.",
		Icon = "",
	},
}

return items
