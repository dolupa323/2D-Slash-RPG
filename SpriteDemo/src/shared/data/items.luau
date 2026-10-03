-- 아이템 마스터 데이터(정적 표). 인벤토리에는 { Tab, Slot, ItemId, Count, Plus? }만 저장하고, 이름/설명/최대 스택 같은 정적
-- 정보는 항상 이 표에서 ItemId로 조회한다(저장 데이터가 커지지 않고, 표를 고치면 기존 아이템에도 바로 반영됨).
-- 「오문 닌자전」: 아이템은 전부 Ninja Adventure 팩 그림을 쓴다 — 실제 정의는 두 파일에 있고 여기서 합친다.
--   shared/data/ninjaItems.luau   투척 무기 · 음식 · 인술 두루마리 · 부적 · 재료
--   shared/data/ninjaWeapons.luau 무기(종류 · 레벨 · 공격력)
-- (예전 포획 게임의 나무 검 · 잎사귀 갑옷 · 물약 · 방울 · 몬스터 재료는 없앴다. 옛 저장 데이터는 playerSchema v10이 바꿔 준다.)
--
-- 공통 항목: Name · Description · Tab(가방 탭 "Equip" 장비 / "Use" 소비 / "Etc" 기타 / "Cash" 캐시 / "Key" 중요 — 탭마다 칸이 따로) ·
--  Type · StackMax · Price(가게에서 살 때 값, 없으면 안 판다) · SellPrice(가게에 팔 때 값, 없으면 못 판다) ·
--  KitIcon(팩 아이템 아이콘 이름 "nj_<키>" — shared/data/itemIcons.generated.luau) · EquipSlot(착용 칸 "Weapon" / "Armor"(부적)) ·
--  Heal(먹으면 체력 회복) · Throw(투척 무기 수치) · NoDrop(버릴 수 없음)
local items = {}

for id, def in require(script.Parent.ninjaItems) do
	items[id] = def
end
for id, def in require(script.Parent.ninjaWeapons) do
	items[id] = def
end

return items
