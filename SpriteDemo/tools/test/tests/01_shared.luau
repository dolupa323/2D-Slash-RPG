-- 공용 데이터: 아이템 표 · 가게 · 드롭 표 · 몬스터 레벨 · 씬 도우미
local items = req("ReplicatedStorage/shared/data/items")
local shops = req("ReplicatedStorage/shared/config/shops")
local drops = req("ReplicatedStorage/shared/config/drops")
local townWorld = req("ReplicatedStorage/shared/data/townWorld")
local monsterLevels = req("ReplicatedStorage/shared/config/monsterLevels")
local itemIcons = req("ReplicatedStorage/shared/data/itemIcons.generated")
local kit = req("ReplicatedStorage/shared/data/uiKit.generated")
local world = townWorld.data

-- 닌자 아이템이 표에 합쳐졌는가 · 투척 무기 수치
for _, id in { "Shuriken", "Kunai", "Bomb" } do
	local def = items[id]
	expect(def and def.Type == "Throw" and def.Tab == "Use", id .. " 투척 무기")
	expect(def.Throw.power > 0 and def.Throw.range > 0 and def.Throw.speed > 0, id .. " 수치")
end
expect(items.Bomb.Throw.radius and items.Bomb.Throw.radius > 0, "폭탄 범위")
expect(items.Onigiri.Heal == 40, "주먹밥 회복량")

-- 모든 아이템: 아이콘 이름이 실제로 있는가(도트 UI 키트 또는 팩 아이템 시트)
for id, def in items do
	if def.KitIcon and def.KitIcon ~= "" then
		local name = "icon_" .. def.KitIcon
		expect(kit.rects[name] ~= nil or itemIcons.rects[name] ~= nil, ("%s 아이콘 %s 없음"):format(id, name))
	end
end

-- 아이템은 전부 팩 그림(옛 도트 UI 키트 아이콘을 쓰는 아이템이 없어야 한다)
for id, def in items do
	expect(typeof(def.KitIcon) == "string" and string.sub(def.KitIcon, 1, 3) == "nj_" and itemIcons.rects["icon_" .. def.KitIcon] ~= nil, id .. " 은 팩 아이콘")
end
for _, legacy in { "WoodenSword", "LeafArmor", "RedPotion", "OrangePotion", "WhitePotion", "Bell1", "RainbowEgg", "SproutFragment", "Mat_piyo" } do
	expect(items[legacy] == nil, "옛 아이템이 표에 없음 " .. legacy)
end

-- UI 키트(팩 UI): 게임 코드가 쓰는 부품 · 색이 전부 있다
for _, name in { "panel", "tag", "tab_on", "tab_off", "button_primary", "button_primary_pressed", "button_plain", "button_plain_pressed", "button_disabled",
	"pill", "pill_dark", "slot", "slot_selected", "bar_frame", "bar_fill_red", "bar_fill_yellow", "bar_fill_sky", "bar_fill_mint", "bubble", "dialog_face",
	"icon_heart", "icon_coin", "icon_bag", "icon_book", "icon_gear", "icon_close", "icon_energy", "act_attack", "act_talk",
	"key_q", "key_r", "key_1", "key_2", "key_3", "key_e", "key_f" } do
	expect(kit.rects[name] ~= nil, "UI 부품 " .. name)
end
for _, name in { "ink", "white", "paper", "accent", "accentD", "accentL", "goodD", "grayD" } do
	expect(kit.colors[name] ~= nil, "UI 색 " .. name)
end
-- 그림 자리만 바꿔 끼우는 짝은 크기 · 9분할이 같아야 한다
for _, pair in { { "tab_on", "tab_off" }, { "slot", "slot_selected" }, { "button_primary", "button_primary_pressed" }, { "button_primary", "button_disabled" }, { "button_plain", "button_plain_pressed" }, { "button_plain", "button_disabled" } } do
	local a, b = kit.rects[pair[1]], kit.rects[pair[2]]
	expect(a.w == b.w and a.h == b.h and table.concat(a.slice, ",") == table.concat(b.slice, ","), ("%s / %s 크기 · 9분할 같음"):format(pair[1], pair[2]))
end
local ninjutsuConfig = req("ReplicatedStorage/shared/config/ninjutsu")
for id in ninjutsuConfig.SKILLS do
	local on, off = kit.rects["skill_" .. id], kit.rects["skill_" .. id .. "_off"]
	expect(on ~= nil and off ~= nil and on.w == off.w and on.h == off.h, "인술 아이콘 " .. id)
end
for _, id in ninjutsuConfig.SCHOOLS do
	expect(kit.rects["face_school_" .. id] ~= nil, "유파 얼굴 그림 " .. id)
end
for _, t in world.npcTypes do
	expect(kit.rects["face_" .. t.id] ~= nil, "NPC 얼굴 그림 " .. t.id)
end

-- 가게: 파는 물건이 전부 아이템 표에 있고 값이 있다
for shopId, shop in shops do
	for _, id in shop.goods do
		expect(items[id] ~= nil and (items[id].Price or 0) > 0, ("가게 %s의 %s"):format(shopId, id))
	end
end

-- 드롭 표: 지역이 전부 있고, 아이템이 실제로 있고, 확률이 0~1
for _, r in world.regions do
	local list = drops.REGION[r.id]
	expect(list ~= nil and #list > 0, "드롭 표 없음 " .. r.id)
	for _, d in list or {} do
		expect(items[d.item] ~= nil, ("드롭 아이템 없음 %s/%s"):format(r.id, d.item))
		expect(d.chance > 0 and d.chance <= 1, "확률 범위 " .. d.item)
	end
end
-- 굴림 통계: 들판에서 2000번 굴리면 풀잎이 35% 근처
local rng = RandomNew(7)
local grass, total = 0, 2000
for _ = 1, total do
	for _, d in drops.Roll("field", rng) do
		if d.item == "GrassBlade" then grass += 1 end
	end
end
expect(math.abs(grass / total - 0.35) < 0.04, ("풀잎 드롭률 %.3f"):format(grass / total))
eq(#drops.Roll("없는지역", rng), 0, "모르는 지역은 드롭 없음")

-- 몬스터 레벨: 종 범위 안에서만 나오고, 낮은 레벨이 더 흔하다
local lo, hi = monsterLevels.LevelRange(1)
eq(lo, 1, "말랑이 최소 레벨"); eq(hi, 4, "말랑이 최대 레벨")
local counts = {}
for _ = 1, 3000 do
	local l = monsterLevels.RollLevel(1, rng)
	expect(l >= lo and l <= hi, "레벨 범위 밖 " .. l)
	counts[l] = (counts[l] or 0) + 1
end
expect(counts[1] > counts[4], "낮은 레벨이 더 흔함")

-- 씬 도우미
eq(townWorld.StartSceneName(), "town_village", "시작 씬")
eq(townWorld.KeyOf("town_field1"), "field1", "씬 키")
expect(townWorld.KeyOf("town_없는씬") == nil, "없는 씬")
local off = townWorld.MonsterFrameOffset(18, 2 * 4 + 1) -- 18번째 종(둘째 줄 2번째), 왼쪽 보기, 걷기 2번째 장
eq(off.X, 1 * 64 + 2 * 16, "시트 x"); eq(off.Y, 1 * 64 + 1 * 16, "시트 y")
local d = townWorld.Get("village")
expect(not townWorld.BoxBlocked(d, d.spawn.x, d.spawn.y, world.playerFeet.halfW, world.playerFeet.h), "마을 시작 자리")
expect(townWorld.IsBlocked(d, -1, 10), "맵 밖은 막힘")
