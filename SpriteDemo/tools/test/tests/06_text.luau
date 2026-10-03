-- 글씨가 칸을 넘지 않는가: 도트 글씨의 줄바꿈 · 줄임(client/modules/ui/pixelText.luau)과, 실제 게임 글(아이템 · 인술 · 유파 · NPC 대사)이
-- 각 창의 글 자리에 잘리지 않고 들어가는지. 자리 크기는 각 창 코드의 수치를 옮겨 적었다(창 배치를 바꾸면 여기도 고칠 것).
local text = req("Client/ui/pixelText")
local items = req("ReplicatedStorage/shared/data/items")
local ninjutsu = req("ReplicatedStorage/shared/config/ninjutsu")
local weapons = req("ReplicatedStorage/shared/config/weapons")
local npcTalk = req("ReplicatedStorage/shared/config/npcTalk")
local shops = req("ReplicatedStorage/shared/config/shops")
local world = req("ReplicatedStorage/shared/data/townWorld").data
local font = req("ReplicatedStorage/shared/data/pixelFont.generated")

local function lines(s)
	return string.split(s, "\n")
end
local function widest(s, fontKey)
	local w = 0
	for _, l in lines(s) do
		w = math.max(w, (text.Measure(l, fontKey)))
	end
	return w
end

-- ---- 1) 줄바꿈 · 줄임 규칙 ----
eq(text.Wrap("가나다", 100), "가나다", "짧은 글은 그대로")
eq(text.Wrap("가나 다라", 30), "가나\n다라", "띄어쓰기에서 줄바꿈")
eq(text.Wrap("가나다라마", 30), "가나\n다라\n마", "낱말이 폭보다 길면 글자에서 줄바꿈")
eq(text.Wrap("가나\n다라", 100), "가나\n다라", "원래 줄바꿈은 지킴")
eq(text.Fit("가나다라마바사", 40, 1), "가나…", "한 줄: 넘으면 …")
expect(widest(text.Fit("가나다라마바사", 40, 1)) <= 40, "한 줄 줄임 폭")
eq(text.Fit("가나다", 40, 1), "가나다", "한 줄: 들어가면 그대로")
local fitted = text.Fit("가나다라 마바사아 자차카타 파하", 50, 2)
expect(#lines(fitted) == 2 and widest(fitted) <= 50 and string.sub(fitted, -3) == "…", "두 줄 제한: 넘으면 마지막 줄 끝이 … (" .. fitted .. ")")
eq(text.Fit("가나 다라", 60, 2), "가나 다라", "두 줄 제한: 들어가면 그대로")
-- 어떤 글이든: 줄바꿈 결과의 모든 줄이 폭 안, 글자는 하나도 빠지지 않음(띄어쓰기 · 줄바꿈 빼고)
local samples = {}
for id, def in items do
	table.insert(samples, def.Name)
	table.insert(samples, def.Description)
end
for _, s in ninjutsu.SKILLS do
	table.insert(samples, s.desc)
end
for _, v in npcTalk.LINES do
	for _, l in (if typeof(v) == "table" then v else { v }) do
		table.insert(samples, l)
	end
end
local strip = function(s) return (string.gsub(s, "[%s]", "")) end
for _, s in samples do
	for _, width in { 60, 122, 236 } do
		local wrapped = text.Wrap(s, width)
		expect(widest(wrapped) <= width, ("줄바꿈 폭 %d: %s"):format(width, s))
		eq(strip(wrapped), strip(s), "줄바꿈해도 글자가 빠지지 않음")
		local cut = text.Fit(s, width, 2)
		expect(widest(cut) <= width and #lines(cut) <= 2, ("두 줄 제한 폭 %d: %s"):format(width, s))
	end
end

-- 잘리지 않고 들어가는가(… 없이)
local function fits(s, width, maxLines, fontKey)
	return text.Fit(s, width, maxLines, fontKey) == (if maxLines == 1 then s else text.Wrap(s, width, fontKey))
end

-- ---- 2) 가방 창(globals/inventory.luau): 이름 = 제목 글꼴 한 줄 · 폭 INFO_W, 설명 = 소비 5줄 / 그 밖 6줄 ----
local INFO_W = 300 - (14 + 6 * 24 + 8) - 12
for id, def in items do
	local name = def.Name .. (if def.Type == "Weapon" then " +10" else "")
	expect(fits(name, INFO_W, 1, "title"), ("가방 이름 자리(%d)에 들어감: %s (%d)"):format(INFO_W, name, (text.Measure(name, "title"))))
	local desc = def.Description
	if def.Type == "Weapon" and def.Class then
		local class = weapons.ClassOf(def)
		desc ..= ("\n%s · Lv.%d\n공격력 +%d\n%s"):format(class.name, def.Level, def.Attack + weapons.Bonus(def, 10), class.desc)
	elseif def.Type == "Charm" then
		desc ..= ("\nLv.%d부터"):format(def.Level)
	end
	local maxLines = if def.Tab == "Use" then 5 else 6
	local n = #lines(text.Wrap(desc, INFO_W))
	expect(n <= maxLines, ("가방 설명 %d줄(자리 %d줄): %s"):format(n, maxLines, id))
end

-- ---- 3) 가게(globals/shop.luau): 이름 자리 = 엽전 아이콘(170) - 36 - 4 ----
local NAME_W = 170 - 36 - 4
for _, shop in shops do
	for _, id in shop.goods do
		expect(fits(items[id].Name, NAME_W, 1), "가게 이름 자리: " .. items[id].Name)
	end
	expect((text.Measure(shop.title, "title")) + 16 <= 300, "가게 제목판: " .. shop.title)
end
for id, def in items do
	if def.SellPrice then
		expect(fits(("%s x%d"):format(def.Name, def.StackMax), NAME_W, 1), "가게(팔기) 이름 자리: " .. def.Name)
		-- 값(네 자리까지)이 버튼 둘 앞에 들어간다: 버튼 = 글씨 + 12, 사이 3
		local buttons = (text.Measure("1개")) + 12 + 3 + (text.Measure("10개")) + 12 + 3
		expect((text.Measure(tostring(def.SellPrice))) <= (300 - 12 - buttons) - (170 + 14), "가게 값 자리: " .. def.Name)
	end
end

-- ---- 4) 강화 창(globals/upgrade.luau): 폭 250 — 글 자리 222, 주괴 줄 206, 결과 줄(버튼 앞) 146 ----
for id, def in items do
	if def.Type == "Weapon" then
		local class = weapons.ClassOf(def)
		expect(fits(("%s +9 · %s"):format(def.Name, class.name), 222, 1), "강화 이름 줄: " .. id)
		local cost = weapons.Cost(def, weapons.MAX_PLUS)
		expect(fits(("%s %d개 (가진 것 %d)"):format(items[cost.bar].Name, cost.bars, 999), 206, 1), "강화 주괴 줄: " .. id)
		expect(fits(("엽전 %d"):format(cost.gold), 206, 1), "강화 엽전 줄: " .. id)
		expect(fits(("성공! %s +%d"):format(def.Name, 10), 146, 1), "강화 결과 줄: " .. id)
		expect(fits(("공격력 %d > %d"):format(def.Attack + weapons.Bonus(def, 9), def.Attack + weapons.Bonus(def, 10)), 222, 1), "강화 공격력 줄: " .. id)
	end
end
expect(fits("실패… 단계는 그대로", 146, 1) and fits("실패해도 단계는 그대로", 146, 1) and fits("강화할 무기가 없어요.", 222, 1), "강화 안내 글")
expect(fits("성공 확률 100%", 222, 1), "강화 확률 줄")

-- ---- 5) 유파 고르기 창(globals/ninjutsu.luau): 폭 444, 버튼 70 ----
local PANEL_W, BUTTON_W = 444, 70
for _, id in ninjutsu.SCHOOLS do
	local info = ninjutsu.SCHOOL_INFO[id]
	local nameW = (text.Measure(("%s · %s"):format(info.name, info.title)))
	-- 윗줄 = 이름 + 설명, 아랫줄 = 전직별 인술 이름 넷
	local skills = {}
	for _, sid in info.skills do
		table.insert(skills, ninjutsu.SKILLS[sid].name)
	end
	expect(fits(info.desc, PANEL_W - 14 - BUTTON_W - 6 - (58 + nameW + 10), 1), "유파 창 설명 줄: " .. id)
	expect(fits(table.concat(skills, " · "), PANEL_W - 14 - BUTTON_W - 6 - 58, 1), "유파 창 인술 줄: " .. id)
end
for _, note in { "Lv.10이 되면 스승에게서 유파를 골라 1차 전직을 합니다.", "유파를 고르세요. 1차 전직 · 하닌이 됩니다.",
	("닌자 마스터 · 전직을 모두 마쳤어요 · 유파 바꾸기 엽전 %d"):format(ninjutsu.CHANGE_COST), ("중닌 · 다음 전직 Lv.60 · 유파 바꾸기 엽전 %d"):format(ninjutsu.CHANGE_COST) } do
	expect(fits(note, PANEL_W - 14 - 34, 1), "유파 창 안내: " .. note)
end
for _, label in { "입문", "바꾸기", "지금 유파", "2차 전직", "4차 전직" } do
	expect(fits(label, BUTTON_W - 4, 1), "유파 창 버튼: " .. label)
end

-- ---- 6) 대화 상자(town/npcs.luau): 이름표 58, 글 자리 = 300 - 50 - 8, 두 줄씩 쪽 넘김 ----
local TEXT_W = 300 - 50 - 8
for _, t in world.npcTypes do
	expect(fits(t.name, 58, 1), "대화 이름표: " .. t.name)
end
for role, v in npcTalk.LINES do
	for _, l in (if typeof(v) == "table" then v else { v }) do
		expect(widest(text.Wrap(l, TEXT_W)) <= TEXT_W, "대화 글 폭: " .. role)
	end
end

-- ---- 7) HUD(globals/hud.luau): 레벨 알약 · 숫자 자리 ----
local pillW = (text.Measure("Lv.100")) + 8
expect(fits("Lv.100", pillW - 6, 1), "레벨 알약")
expect(fits("2080", 34, 1) and fits("100%", 34, 1) and fits("EXP", 24, 1), "체력 · 경험치 숫자 자리")
expect((text.Measure("9,999,999")) <= 94 - 12 - 14, "엽전 자리(999만 — 아이콘 오른쪽 ~ 오른쪽 맞춤 94)")
-- 인술 칸(26): 잠긴 칸 글씨 · 쿨타임 숫자
expect((text.Measure("Lv")) <= 24 and (text.Measure("100")) <= 24 and (text.Measure("14")) <= 22, "인술 칸 글씨(잠긴 칸은 Lv / 숫자 두 줄)")
-- 가방 · 강화 창 칸(22): 개수와 강화 단계 글씨
expect((text.Measure("99")) <= 20 and (text.Measure("+9")) <= 20 and (text.Measure("10")) <= 20, "칸 구석 글씨(개수 99 · 강화 +9 · 10)")
-- 글꼴 규칙: 영문·기호 폭이 칸을 넘지 않는다
for key, f in font do
	for i, adv in f.asciiAdv do
		expect(adv <= f.cellW + (if key == "title" then 2 else 1), ("%s 글꼴 %d번째 영문 폭"):format(key, i))
	end
end
