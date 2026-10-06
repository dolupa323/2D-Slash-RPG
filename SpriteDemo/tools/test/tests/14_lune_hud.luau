-- 「달의 계승자」 — 화면 글씨가 제 칸에 들어가는가(글씨는 칸을 넘지 않는다) · 숫자를 짧게 적는 꼴
local pixelText = req("Client/ui/pixelText")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local F = req("ReplicatedStorage/shared/lune/ui/format")
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local COMBAT = req("ReplicatedStorage/shared/lune/data/combat.generated")

local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
pixelText.Register("small", KIT.font.small, {}) -- 화면의 글은 작은 글씨(갈무리9) — 게임에서는 client/lune/ui/kit.luau가 등록한다

local function measure(text)
	return (pixelText.Measure(text, "small"))
end
local CELL, PITCH = KIT.cell, KIT.pitch

-- 화면 칸은 게임 화면(384x216) 안에 있다
for key, r in UI.hud do
	expect(r.x >= 0 and r.y >= 0 and r.x + r.w <= 384 and r.y + r.h <= 216, "화면 칸이 화면 안 " .. key)
end
for _, key in { "minimap", "party", "boss", "buffs", "quest", "chat", "menu", "vitals", "skills", "xp" } do
	expect(UI.hud[key] ~= nil, "지금 쓰는 화면 칸 " .. key)
end

-- 숫자를 짧게
eq(F.short(0), "0", "0")
eq(F.short(9999), "9999", "만 아래는 그대로")
eq(F.short(10000), "1만", "1만")
eq(F.short(12345), "1.2만", "1.2만")
eq(F.short(335808), "33.6만", "33.6만")
eq(F.short(1234567), "123만", "100만부터는 소수점 없이")
eq(F.short(123456789), "1.2억", "1.2억")
eq(F.short(5748000000), "57.5억", "57.5억")

-- 상태바(client/lune/hud.luau의 layout과 같은 셈): 윗줄에 레벨과 이름, 아랫줄에 체력 바 — 어느 레벨 · 어느 직업에서도 글이 칸을 넘지 않는다
local v = UI.hud.vitals
local LEVEL_W = measure("Lv." .. N.MAX_LEVEL)
local nameX = 5 + LEVEL_W + 4
local nameW = v.w - 5 - nameX
local hpLabelW = measure("HP") + 6
local hpWidth = v.w - 8 - 2 * hpLabelW
expect(v.h >= 3 + 9 + 1 + 11 + 3, "상태바에 글 한 줄과 체력 바가 들어간다")
expect(nameW >= 80, ("상태바의 이름 칸이 여든 도트는 된다 — %d"):format(nameW))
expect(hpWidth >= 60, ("체력 숫자의 칸 %d"):format(hpWidth))
for _, class in { "axion", "riven", "reaper", "mooni", "salamander" } do
	for _, L in { 1, 9, 10, 30, 60, 99, 100, 149, 150 } do
		local max = N.hpOf(class, L, 500)
		for _, cur in { max, math.floor(max / 3), 1, 0 } do
			local text = F.hp(cur, max, hpWidth, measure)
			expect(measure(text) <= hpWidth, ("체력 글 %s(%s Lv.%d)이 칸 %d에 들어감 — 폭 %d"):format(text, class, L, hpWidth, measure(text)))
			expect(#text > 0, "체력 글이 비지 않음")
		end
	end
end
eq(F.hp(86, 104, hpWidth, measure), "86/104", "들어가면 그대로 적는다")
do
	local longName = F.safeName("가나다라마바사아자차카타파하", "x")
	expect(measure(pixelText.Fit(longName, nameW, 1, "small")) <= nameW, "가장 긴 이름도 상태바의 이름 칸에 줄여서 들어간다")
end

-- 스킬 칸(두 줄 x 여섯)과 메뉴 단추(여섯)가 제 칸에 들어간다
local s = UI.hud.skills
expect(5 * PITCH + CELL <= s.w and PITCH + CELL <= s.h, "스킬 칸 두 줄 x 여섯이 칸 안")
local m = UI.hud.menu
expect(5 * PITCH + CELL <= m.w and CELL <= m.h, "메뉴 단추 여섯이 칸 안")
-- 아주 작은 글씨(3x5)로 적는 것: 키 이름(네 글자까지) · 물약 수 · 남은 초 · 경험치 %
local function microWidth(text)
	return #text * 4 - 1
end
eq(F.MICRO_CHARS, KIT.parts.microLine.order, "아주 작은 글씨의 글자 차례가 부품 그림과 같다")
for _, name in { "Q", "A", "LeftShift", "Space", "LeftControl", "Return", "Backspace", "F12", "KeypadEnter", "PageDown", "Left", "Right", "Up", "Down", "Semicolon", "Zero", "Tab", "BackSlash" } do
	local text = F.keyMicro(name)
	expect(#text >= 1 and #text <= 4, ("스킬 칸의 키 이름 %s → %s"):format(name, text))
	expect(microWidth(text) <= CELL - 4, "키 이름이 칸 안 " .. name)
	for i = 1, #text do
		expect(string.find(F.MICRO_CHARS, text:sub(i, i), 1, true) ~= nil, ("키 이름 %s의 글자 %s가 아주 작은 글씨에 있다"):format(name, text:sub(i, i)))
	end
end
eq(F.keyMicro("LeftShift"), "SHFT", "Shift")
eq(F.keyMicro("Shift"), "SHFT", "이미 바꾼 이름도 받는다")
eq(F.keyMicro("LeftControl"), "CTRL", "Ctrl")
eq(F.keyMicro("Left"), "<", "화살표는 그 글씨의 화살표 자리로")
eq(F.keyMicro("Q"), "Q", "글자 키는 그대로")
eq(F.keyMicro(""), "", "키가 없으면 빈 글")
expect(microWidth("999") <= CELL - 4, "물약 수가 칸에 들어감")
expect(microWidth("EXP 100.00%") <= UI.hud.xp.w - 4, "경험치 글이 바 안")
expect(UI.hud.xp.h >= 7, "경험치 바에 아주 작은 글씨(다섯 줄)와 테두리가 들어간다")
eq(F.fitKey("Q", 26, measure), "Q", "들어가면 그대로")
eq(F.fitKey("Space", 200, measure), "Space", "넓으면 그대로")
expect(F.fitKey("Space", 20, measure) ~= "Space", "좁으면 줄임말")
eq(F.split(30, 1, { 20, 20 }, 10), nil, "다 못 들어가면 nil")
eq(F.key("LeftShift"), "Shift", "키 이름")
eq(F.key("Q"), "Q", "글자 키는 그대로")

-- ---------- 미니맵: 어느 장면이든 상자 안에 들어가고, 맵 이름이 칸을 넘지 않는다 ----------
local MM = req("ReplicatedStorage/shared/lune/ui/minimap")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")
local mm = UI.hud.minimap
local mapH = mm.h - MM.TOP - MM.BOTTOM -- client/lune/minimap.luau와 같은 값
local maxW = UI.hud.boss.x - mm.x - 4 -- 상자가 늘어날 수 있는 끝(보스 체력 칸의 왼쪽)
expect(mapH >= 8, "미니맵의 맵 자리가 여덟 도트는 된다")
eq(MM.boxFor(20, mm.w, maxW), mm.w, "이름이 짧으면 기본 폭")
eq(MM.boxFor(80, mm.w, maxW), 80 + MM.NAME_X + MM.NAME_R, "이름이 길면 이름만큼 늘어난다")
eq(MM.boxFor(500, mm.w, maxW), maxW, "그래도 보스 체력 칸은 넘지 않는다")
local mapW = mm.w - MM.SIDE * 2
for key, scene in SCENES.scenes do
	expect(measure(scene.name) <= maxW - MM.NAME_X - MM.NAME_R, ("맵 이름 「%s」이 늘어난 미니맵 칸에 들어감 — 폭 %d"):format(scene.name, measure(scene.name)))
	local boxW = MM.boxFor(measure(scene.name), mm.w, maxW)
	expect(mm.x + boxW <= UI.hud.boss.x - 4, "늘어난 미니맵이 보스 체력 칸과 겹치지 않는다 " .. key)
	mapW = boxW - MM.SIDE * 2
	local L = MM.layout(scene, mapW, mapH)
	expect(L.w <= mapW and L.h <= mapH and L.w >= 1 and L.h >= 1, "줄인 맵이 상자 안 " .. key)
	expect(L.ox >= 0 and L.oy >= 0 and L.ox + L.w <= mapW and L.oy + L.h <= mapH, "줄인 맵의 자리가 상자 안 " .. key)
	expect(math.abs(L.w / scene.w - L.h / scene.h) < 0.2, "가로 · 세로를 같은 비율로 줄임 " .. key)
	expect(#L.ground > 0, "땅이 그려진다 " .. key)
	local cover = 0
	for _, g in L.ground do
		expect(g.x >= 0 and g.y >= 0 and g.w >= 1 and g.h >= 1 and g.x + g.w <= L.w and g.y + g.h <= L.h, "땅 덩어리가 줄인 맵 안 " .. key)
		cover += g.w
	end
	expect(cover <= L.w, "땅 덩어리가 겹치지 않는다 " .. key)
	for _, st in L.steps do
		expect(st.x >= 0 and st.y >= 0 and st.w >= 1 and st.x + st.w <= L.w and st.y < L.h, "발판이 줄인 맵 안 " .. key)
	end
	-- 장면의 네 귀퉁이와 문 · 주민이 모두 줄인 맵 안에 찍힌다
	local pts = { { 0, 0 }, { scene.w * 16, scene.h * 16 }, { -50, 9999 } }
	for _, p in scene.portals or {} do
		table.insert(pts, { p.x, p.y })
	end
	for _, n in scene.npcs or {} do
		table.insert(pts, { n.x, n.y })
	end
	for _, p in pts do
		local x, y = MM.point(L, 16, p[1], p[2])
		expect(x >= 0 and x < L.w and y >= 0 and y < L.h, ("점 (%d, %d)이 줄인 맵 안 %s"):format(p[1], p[2], key))
	end
end
-- 왼쪽 끝과 오른쪽 끝은 다른 자리에 찍힌다(맵을 걸으면 점이 움직인다)
do
	local scene = SCENES.scenes.hunt
	local L = MM.layout(scene, MM.boxFor(measure(scene.name), mm.w, maxW) - MM.SIDE * 2, mapH)
	local x0 = MM.point(L, 16, 16, 176)
	local x1 = MM.point(L, 16, scene.w * 16 - 16, 176)
	expect(x1 - x0 >= L.w - 4, "사냥터의 양 끝이 미니맵의 양 끝")
	-- 땅 위에 서 있는 점은 땅 덩어리의 윗줄 바로 위 또는 그 줄
	local _, y = MM.point(L, 16, 16, 176)
	expect(y <= L.ground[1].y + 1, "서 있는 자리가 땅 위")
end

-- ---------- 대화 상자: 화면 칸과 겹치지 않고, 주민의 말이 상자 안에 다 들어간다 ----------
local talk = F.TALK
expect(talk.x >= 0 and talk.y >= 0 and talk.x + talk.w <= 384 and talk.y + talk.h <= 216, "대화 상자가 화면 안")
expect(talk.y + talk.h <= 110, "대화 상자가 서 있는 캐릭터(이름표 포함)를 가리지 않는다")
expect(talk.textX >= 8 + 36 + 4 and talk.textX + 1 + talk.textW <= talk.w - 6, "얼굴 칸 옆의 말이 상자 안")
expect(22 + talk.lines * 14 <= talk.h - 18, "말 두 줄이 밝은 판 안")
for key, r in UI.hud do
	local w = r.w
	if key == "minimap" then
		w = maxW -- 맵 이름이 길어 가장 넓게 늘어났을 때
	end
	local apart = talk.x >= r.x + w or talk.x + talk.w <= r.x or talk.y >= r.y + r.h or talk.y + talk.h <= r.y
	-- 퀘스트 알리미는 말하는 동안 숨는다(같은 자리에 걸친다)
	expect(apart or key == "quest", "대화 상자가 화면 칸과 겹치지 않는다 " .. key)
end
local said = 0
for key, scene in SCENES.scenes do
	for _, n in scene.npcs or {} do
		expect(measure(("%s %s"):format(n.role, n.name)) + 10 <= (talk.w - talk.textX - 8) / 2, ("주민 이름표 「%s %s」이 대화 상자의 절반 안(나머지에 퀘스트 이름이 온다)"):format(n.role, n.name))
		expect(measure(("%s %s"):format(n.role, n.name)) <= 120, ("발밑의 주민 이름표 「%s %s」"):format(n.role, n.name))
		expect(#n.lines > 0, "주민에게 할 말이 있다 " .. n.name)
		for i, line in n.lines do
			local wrapped = pixelText.Wrap(line, talk.textW, "body")
			local count = #string.split(wrapped, "\n")
			expect(count <= talk.lines, ("%s의 말 %d이 %d줄에 들어감(지금 %d줄) — %s"):format(n.name, i, talk.lines, count, line))
			said += 1
		end
	end
end
expect(said > 0, "주민의 말을 하나 이상 검사했다")

-- ---------- 여럿이: 이름표 · 파티원 칸 · 파티 창 · 초대 알림의 글 ----------
do
	local longName = F.safeName("가나다라마바사아자차카타파하", "x") -- 열두 자(가장 긴 이름)
	-- 발밑의 이름표: 이름만 — 가장 긴 이름도 150에 들어간다
	expect(measure(longName) <= 150, ("가장 긴 이름표의 폭 %d"):format(measure(longName)))
	-- 파티 창: 이름 칸 118(client/lune/ui/partyWindow.luau의 NAME_W)에 "Lv.150 이름"이 줄여서라도 한 줄에 들어간다(Kit.text가 …로 줄인다)
	local fitted = pixelText.Fit(("Lv.%d %s"):format(150, longName), 118, 1, "small")
	expect(measure(fitted) <= 118, "파티 창의 이름 줄")
	-- 초대 알림(client/lune/partyHud.luau의 ASK): 이름 한 줄과 「파티에 초대했다」 한 줄이 상자에 들어간다
	local askW = 142 - 12
	expect(measure(pixelText.Fit(longName, askW, 1, "small")) <= askW, "초대 알림의 이름")
	expect(measure("파티에 초대했다") <= askW, "초대 알림의 글")
	-- 파티원 칸의 이름(기본 폭 62 - 6부터 100 - 6까지 늘어난다)
	expect(measure(pixelText.Fit(longName, 100 - 6, 1, "small")) <= 100 - 6, "파티원 칸의 이름")
	-- 파티원 칸: 세 사람이 늘어나도 채팅 칸 위에서 끝난다
	local pr = UI.hud.party
	expect(pr.y + 3 * 15 + 1 <= UI.hud.chat.y, "파티원 칸이 셋까지 늘어나도 채팅 칸과 겹치지 않는다")
	-- 초대 알림의 자리: 화면 칸과 겹치지 않는다(미니맵이 가장 넓게 늘어났을 때도)
	local a = { x = 114, y = 30, w = 142, h = 52 } -- client/lune/partyHud.luau의 ASK
	for key, r in UI.hud do
		local w, h = r.w, r.h
		if key == "minimap" then
			w = UI.hud.boss.x - r.x - 4
		elseif key == "party" then
			h = 3 * 15 + 1
		end
		local apart = a.x >= r.x + w or a.x + a.w <= r.x or a.y >= r.y + h or a.y + a.h <= r.y
		expect(apart, "초대 알림이 화면 칸과 겹치지 않는다 " .. key)
	end
end

-- ---------- 이름표 쌓기 · 채팅 줄 ----------
do
	local Tags = req("ReplicatedStorage/shared/lune/ui/tags")
	-- 겹치지 않으면 그대로
	local ys = Tags.stack({}, { { x = 0, y = 100, w = 40 }, { x = 60, y = 100, w = 40 } }, 12)
	eq(ys[1], 100, "겹치지 않는 이름표는 제자리")
	eq(ys[2], 100, "겹치지 않는 이름표는 제자리(둘째)")
	-- 겹치면 뒤의 것이 위로
	ys = Tags.stack({}, { { x = 0, y = 100, w = 40 }, { x = 20, y = 100, w = 40 }, { x = 30, y = 100, w = 40 } }, 12)
	eq(ys[1], 100, "앞의 것은 제자리")
	eq(ys[2], 88, "겹치는 것은 한 줄 위로")
	eq(ys[3], 76, "셋이 겹치면 두 줄 위로")
	-- 움직이지 않는 것(주민의 이름표)을 피한다
	ys = Tags.stack({ { x = 10, y = 100, w = 50 } }, { { x = 0, y = 104, w = 40 } }, 12)
	eq(ys[1], 80, "주민의 이름표와 겹치면 위로 올라간다")
	ys = Tags.stack({ { x = 10, y = 60, w = 50 } }, { { x = 0, y = 104, w = 40 } }, 12)
	eq(ys[1], 104, "높이가 다르면 겹치지 않는다")
	-- 발밑의 이름표는 아래로 쌓는다
	ys = Tags.stack({}, { { x = 0, y = 100, w = 40 }, { x = 20, y = 100, w = 40 }, { x = 30, y = 100, w = 40 } }, 12, 1)
	eq(ys[1], 100, "앞의 것은 제자리(아래로)")
	eq(ys[2], 112, "겹치는 것은 한 줄 아래로")
	eq(ys[3], 124, "셋이 겹치면 두 줄 아래로")
	ys = Tags.stack({ { x = 10, y = 153, w = 50 } }, { { x = 0, y = 153, w = 40 } }, 12, 1)
	eq(ys[1], 165, "주민의 이름표와 겹치면 그 아래로 내려간다")
	-- 채팅 줄
	eq(Tags.chatLine("near", "달토끼", "안녕"), "달토끼: 안녕", "둘레의 글")
	eq(Tags.chatLine("party", "달토끼", "가자"), "[파티] 달토끼: 가자", "파티의 글")
	eq(Tags.chatLine("near", nil, "알림"), "알림", "이름이 없는 글")
	eq(Tags.chatClean("  안녕  "), "안녕", "앞뒤 빈칸을 뗀다")
	eq(Tags.chatClean("한 줄\n두 줄"), "한 줄 두 줄", "줄바꿈은 빈칸으로")
	eq(Tags.chatClean("   "), nil, "빈 글은 보내지 않는다")
	eq(Tags.chatClean(""), nil, "빈 글")
	eq(Tags.chatClean(42), nil, "글이 아닌 것")
	eq(#Tags.chatClean(string.rep("a", 200)), 80, "여든 자까지만")
	-- 쓰는 중의 채팅 칸(client/lune/chat.luau의 OPEN): 화면 안에 있고 상태바 위에서 끝난다. 긴 글도 세 줄 안에 들어간다
	local c = UI.hud.chat
	local LINE = KIT.font.small.line
	local bottom = UI.hud.vitals.y - 1
	local open = { x = 2, w = 230, lines = 6 }
	local h = open.lines * LINE + 6 + 16
	expect(open.x + open.w <= 384 and bottom - h >= 0, "쓰는 중의 채팅 칸이 화면 안")
	local long = Tags.chatLine("party", "가나다라마바사아자차카타", string.rep("가", 80))
	local fitted = pixelText.Fit(long, open.w - 10, 3, "small")
	local lines = string.split(fitted, "\n")
	expect(#lines <= 3, "긴 글도 세 줄까지")
	for _, line in lines do
		expect(measure(line) <= open.w - 10, "채팅 줄이 칸 안")
	end
	-- 평소의 채팅 칸(QUIET): 세 줄 · 상태바 바로 위 — 상태바와 메뉴 단추를 가리지 않는다
	local quietBottom = bottom
	local quietTop = bottom - (3 * LINE + 3)
	expect(quietBottom <= UI.hud.vitals.y and quietBottom <= UI.hud.menu.y, "평소의 채팅 글이 상태바 · 메뉴 단추 위에서 끝난다")
	expect(quietTop >= UI.hud.party.y + 3 * 15 + 1, "평소의 채팅 글이 파티원 칸 아래에서 시작한다")
	expect(c.x + 168 <= 384 / 2 - 16, "평소의 채팅 글(폭 168)이 화면 가운데의 내 캐릭터를 가리지 않는다")
end
