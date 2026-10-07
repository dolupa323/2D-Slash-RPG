-- 「달의 계승자」 — 화면 글씨가 제 칸에 들어가는가(글씨는 칸을 넘지 않는다) · 숫자를 짧게 적는 꼴 · 늘 보이는 화면의 자리
--  화면의 글씨와 틀은 게임의 도트보다 고운 격자(1080p에서 960x540)에 있다 — 격자는 창 크기에 따라 768x432부터 1152x648까지 달라지므로 세 크기에서 다 본다.
local pixelText = req("Client/ui/pixelText")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local F = req("ReplicatedStorage/shared/lune/ui/format")
local L = req("ReplicatedStorage/shared/lune/ui/layout")
local N = req("ReplicatedStorage/shared/lune/config/numbers")
local SCENES = req("ReplicatedStorage/shared/lune/data/scenes.generated")

local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
-- 화면의 글씨: 작은 글씨(갈무리9)와 본문 글씨(갈무리11 — 글씨 모듈이 갖고 있다). 게임에서는 client/lune/ui/ui.luau가 등록한다
pixelText.Register("small", KIT.font.small, {})
pixelText.Register("small_o", KIT.font.small_o, {})
pixelText.Register("body_o", KIT.font.body_o, {})

local function measure(text)
	return (pixelText.Measure(text, "small"))
end
local function measureBody(text)
	return (pixelText.Measure(text, "body"))
end
local M = KIT.ui.metric
local G = UI.grid
local GRIDS = { { name = "1080p", w = G.w, h = G.h }, { name = "가장 작은 격자", w = G.min.w, h = G.min.h }, { name = "가장 큰 격자", w = G.max.w, h = G.max.h } }
local function apart(a, b)
	return a.x >= b.x + b.w or a.x + a.w <= b.x or a.y >= b.y + b.h or a.y + a.h <= b.y
end

-- ---------- 글자판 ----------
eq(KIT.font.small_o.pad, 1, "테두리를 두른 작은 글씨는 칸이 사방으로 한 점 크다")
eq(KIT.font.small_o.cellW, KIT.font.small.cellW + 2, "테두리를 두른 글자판의 칸 폭")
eq(KIT.font.small_o.line, KIT.font.small.line, "줄 간격은 같다")
eq(measure("가나다 abc 123"), (pixelText.Measure("가나다 abc 123", "small_o")), "테두리를 둘러도 글의 폭은 같다")
eq(measureBody("가나다 abc 123"), (pixelText.Measure("가나다 abc 123", "body_o")), "본문 글씨도 같다")
expect(M.small == 10 and M.body == 12, "글씨는 둘뿐: 작은 글씨 10 · 본문 12")
expect(M.button >= M.body + 12 and M.key >= M.small + 4, "글이 들어가는 칸에는 위아래 여백이 있다")

-- ---------- 화면의 격자 ----------
eq(G.w * G.ui, 384 * G.world, "1080p의 격자 폭 = 게임 화면의 정수배")
eq(G.h * G.ui, 216 * G.world, "1080p의 격자 높이")
for s = 2, 10 do
	local w, h, us = L.gridFor(s)
	expect(w == math.floor(w) and h == math.floor(h), ("게임 %d배일 때 화면 틀의 격자가 정수 — %sx%s"):format(s, tostring(w), tostring(h)))
	expect(w >= G.min.w and h >= G.min.h and w <= G.max.w and h <= G.max.h, ("게임 %d배일 때 격자 %dx%d가 가장 작은 것과 큰 것 사이"):format(s, w, h))
	expect(w % 2 == 0 and h % 2 == 0, "격자의 가운데가 반 점에 걸리지 않는다")
	expect(384 * s == w * us, "화면 틀이 게임 화면을 꼭 덮는다")
end
eq(select(1, L.gridFor(5)), G.w, "게임 5배(1080p)의 격자 폭")
eq(select(2, L.gridFor(5)), G.h, "게임 5배(1080p)의 격자 높이")

-- ---------- 늘 보이는 화면의 칸: 세 격자에서 화면 안에 있고, 서로 겹치지 않고, 싸움터 가운데를 가리지 않는다 ----------
for _, key in { "party", "boss", "buffs", "quest", "chat", "menu", "vitals", "skills" } do
	expect(UI.hud[key] ~= nil, "지금 쓰는 화면 칸 " .. key)
end
expect(UI.hud.minimap == nil, "미니맵은 없다(사용자 결정 2026-10-07)")
for _, g in GRIDS do
	local mid = { x = g.w / 3, y = g.h * 0.3, w = g.w / 3, h = g.h * 0.4 }
	local keys = {}
	for key in UI.hud do
		table.insert(keys, key)
	end
	table.sort(keys)
	for i, key in keys do
		local r = L.rect(UI.hud[key], g.w, g.h)
		expect(r.x >= 0 and r.y >= 0 and r.x + r.w <= g.w and r.y + r.h <= g.h, ("화면 칸이 화면 안 %s(%s)"):format(key, g.name))
		expect(apart(r, mid), ("화면 칸이 싸움터 가운데를 가리지 않는다 %s(%s)"):format(key, g.name))
		for j = i + 1, #keys do
			expect(apart(r, L.rect(UI.hud[keys[j]], g.w, g.h)), ("화면 칸이 겹치지 않는다 %s · %s(%s)"):format(key, keys[j], g.name))
		end
	end
end
eq(L.rect(UI.hud.menu, G.w, G.h).x, UI.hud.menu.x, "기준 격자에서는 적힌 자리 그대로")
eq(L.rect(UI.hud.menu, G.min.w, G.min.h).x + UI.hud.menu.w, G.min.w - (G.w - UI.hud.menu.x - UI.hud.menu.w), "오른쪽에 붙는 칸은 오른쪽 끝에서의 거리가 같다")
eq(L.rect(UI.hud.vitals, G.min.w, G.min.h).y + UI.hud.vitals.h, G.min.h - (G.h - UI.hud.vitals.y - UI.hud.vitals.h), "아래에 붙는 칸은 아래 끝에서의 거리가 같다")

-- 숫자를 짧게
eq(F.short(0), "0", "0")
eq(F.short(9999), "9999", "만 아래는 그대로")
eq(F.short(10000), "1만", "1만")
eq(F.short(12345), "1.2만", "1.2만")
eq(F.short(335808), "33.6만", "33.6만")
eq(F.short(1234567), "123만", "100만부터는 소수점 없이")
eq(F.short(123456789), "1.2억", "1.2억")
eq(F.short(5748000000), "57.5억", "57.5억")

-- ---------- 왼쪽 아래 덩어리: 레벨 · 이름 / 체력 바(숫자는 바 안) / 경험치 줄과 % ----------
local v, V = UI.hud.vitals, L.VITALS
expect(V.barW + V.xpGap + measure(V.xpText) <= v.w, ("경험치 줄 옆의 %% 글이 칸 안 — 폭 %d"):format(measure(V.xpText)))
expect(V.xpY + V.xpH <= v.h and V.hpY + V.hpH <= V.xpY, "체력 바 · 경험치 줄이 차례로 칸 안")
expect(V.hpY >= M.small + 3, "이름 줄과 체력 바 사이에 여백")
expect(V.hpH >= M.small + 8, "체력 바 안의 숫자 위아래로 여백이 있다(바 20 · 글 10)")
local hpWidth = V.barW - V.hpPad * 2
for _, class in { "axion", "riven", "reaper", "mooni", "salamander" } do
	for _, lv in { 1, 9, 10, 30, 60, 99, 100, 149, 150 } do
		local max = N.hpOf(class, lv, 500)
		for _, cur in { max, math.floor(max / 3), 1, 0 } do
			local text = F.hp(cur, max, hpWidth, measure)
			expect(measure(text) <= hpWidth, ("체력 글 %s(%s Lv.%d)이 바 안 %d에 들어감 — 폭 %d"):format(text, class, lv, hpWidth, measure(text)))
			expect(#text > 0, "체력 글이 비지 않음")
		end
	end
end
eq(F.hp(86, 104, hpWidth, measure), "86/104", "들어가면 그대로 적는다")
do
	local longName = F.safeName("가나다라마바사아자차카타파하", "x")
	local nameW = v.w - measure("Lv." .. N.MAX_LEVEL) - V.nameGap
	expect(nameW >= 150, ("이름 칸의 폭 %d"):format(nameW))
	expect(measure(pixelText.Fit(longName, nameW, 1, "small")) <= nameW, "가장 긴 이름도 레벨 글 뒤에 줄여서 들어간다")
end

-- ---------- 스킬 칸(두 줄 x 여섯)과 메뉴 단추(여섯) ----------
local s, K = UI.hud.skills, L.SKILLS
local pitch = K.slot + K.gap
expect(K.cols * pitch - K.gap <= s.w, "스킬 칸 여섯이 칸의 폭 안")
expect(K.rows * (K.slot + K.keyUp) + (K.rows - 1) * K.rowGap <= s.h, "스킬 칸 두 줄이(줄마다 위에 키 딱지) 칸의 높이 안")
expect(K.slot >= M.pic + 4, "칸이 그림(24)보다 사방으로 두 점은 크다")
for n = 1, K.cols * K.rows do
	local seen = {}
	for i = 1, n do
		local x, y = L.slotPlace(i, n)
		expect(x >= 0 and x + K.slot <= s.w and y - K.keyUp >= 0 and y + K.slot <= s.h, ("쓰는 칸 %d개일 때 %d째 칸(과 그 위의 키 딱지)이 칸 안"):format(n, i))
		expect(not seen[x .. ":" .. y], "칸이 겹치지 않는다")
		seen[x .. ":" .. y] = true
	end
	-- 아랫줄은 가운데에 모인다
	local first = L.slotPlace(1, n)
	local lastX = L.slotPlace(math.min(n, K.cols), n)
	expect(math.abs(first - (s.w - lastX - K.slot)) <= 1, ("쓰는 칸 %d개일 때 아랫줄이 가운데"):format(n))
end
for _, name in { "Q", "A", "LeftShift", "Space", "LeftControl", "Return", "Backspace", "F12", "KeypadEnter", "KeypadFive", "PageDown", "Left", "Right", "Up", "Down", "Semicolon", "Zero", "Tab", "BackSlash", "CapsLock", "Insert" } do
	local text = F.keyShort(name)
	expect(utf8.len(text) >= 1 and utf8.len(text) <= K.keyMax, ("칸 위의 키 이름 %s → %s"):format(name, text))
	expect(measure(text) + 8 <= pitch - 1, ("키 딱지 「%s」(폭 %d)가 옆 칸의 것과 닿지 않는다"):format(text, measure(text) + 8))
end
eq(F.keyShort("LeftShift"), "Shift", "Shift")
eq(F.keyShort("Shift"), "Shift", "이미 바꾼 이름도 받는다")
eq(F.keyShort("LeftControl"), "Ctrl", "Ctrl")
eq(F.keyShort("Left"), "←", "화살표")
eq(F.keyShort("Q"), "Q", "글자 키는 그대로")
eq(F.keyShort("PageDown"), "PgDn", "긴 이름은 줄임말")
expect(measure("999") <= K.slot - 2, "물약 수가 칸에 들어감")
expect(measure("120") <= K.slot, "다시 쓰기까지 남은 초가 칸에 들어감")

local m, MN = UI.hud.menu, L.MENU
expect(MN.max * MN.pitch - (MN.pitch - MN.slot) <= m.w, "메뉴 단추 여섯이 칸의 폭 안")
expect(MN.labelY + M.small + 1 <= m.h, "메뉴 단추의 그림과 그 아래의 이름이 칸의 높이 안")
expect(MN.labelW <= MN.pitch, "이름의 폭이 옆 단추의 이름과 겹치지 않는다")
eq(L.menuX(MN.max, MN.max) + MN.slot, m.w, "마지막 단추가 칸의 오른쪽 끝에 붙는다")
expect(L.menuX(1, MN.max) - (MN.labelW - MN.slot) / 2 >= 0 - 4, "첫 단추의 이름이 칸에서 크게 벗어나지 않는다")
do
	local shown = 0
	for _, w in UI.windows do
		local label = L.menuLabel(w.id, w.name)
		-- 메뉴 단추로 놓이는 창(앞의 다섯)의 이름은 한 줄에 들어가야 한다
		if w.id == "bag" or w.id == "equip" or w.id == "stat" or w.id == "skill" or w.id == "quest" then
			expect(measure(label) <= MN.labelW, ("메뉴 단추의 이름 「%s」(폭 %d)이 %d에 들어감"):format(label, measure(label), MN.labelW))
			shown += 1
		end
	end
	eq(shown, 5, "메뉴 단추로 놓이는 창 다섯")
	expect(measure(L.menuLabel("more", "메뉴")) <= MN.labelW, "「메뉴」 단추의 이름")
end

eq(F.fitKey("Q", 26, measure), "Q", "들어가면 그대로")
eq(F.fitKey("Space", 200, measure), "Space", "넓으면 그대로")
expect(F.fitKey("Space", 20, measure) ~= "Space", "좁으면 줄임말")
eq(F.split(30, 1, { 20, 20 }, 10), nil, "다 못 들어가면 nil")
eq(F.key("LeftShift"), "Shift", "키 이름")
eq(F.key("Q"), "Q", "글자 키는 그대로")

-- ---------- 말풍선: 주민의 말이 말풍선의 줄 수에 다 들어가고, 가장 큰 말풍선도 가장 작은 화면에 들어간다 ----------
local B = F.BUBBLE
expect(B.textW + B.padX * 2 + 16 <= G.min.w, "말풍선이 가장 작은 격자의 폭 안")
local said = 0
for key, scene in SCENES.scenes do
	for _, n in scene.npcs or {} do
		expect(measure(("%s %s"):format(n.role, n.name)) <= 260, ("발밑의 주민 이름표 「%s %s」"):format(n.role, n.name))
		expect(#n.lines > 0, "주민에게 할 말이 있다 " .. n.name)
		expect((n.h or 0) > 0, "주민의 키가 있다(말풍선이 머리 위에 뜬다) " .. n.name)
		for i, line in n.lines do
			local wrapped = pixelText.Wrap(line, B.textW, "body")
			local count = #string.split(wrapped, "\n")
			expect(count <= B.lines, ("%s의 말 %d이 %d줄에 들어감(지금 %d줄) — %s"):format(n.name, i, B.lines, count, line))
			said += 1
		end
		-- 말풍선이 머리 위에 떠도 화면 위로 나가지 않는다(가장 작은 격자 · 세 줄일 때): 머리의 높이(화면 틀의 점) - 말풍선의 높이 >= 0
		local ratio = G.min.w / 384
		local headY = (KIT.ground - n.h - B.up) * ratio
		local bubbleH = (B.lines - 1) * M.bodyLine + 14 + B.padY * 2 + B.tail + 16 -- 위에 퀘스트 이름 한 줄
		expect(headY - bubbleH >= 0, ("%s의 말풍선이 화면 안(머리 %d · 말풍선 %d)"):format(n.name, headY, bubbleH))
	end
end
expect(said > 0, "주민의 말을 하나 이상 검사했다")
for _, hint in { "다음", "닫기", "받는다", "끝낸다" } do
	expect(measure(hint) <= 120, "말풍선 아래의 글 " .. hint)
end

-- ---------- 여럿이: 이름표 · 파티원 칸 · 초대 알림의 글 ----------
do
	local longName = F.safeName("가나다라마바사아자차카타파하", "x") -- 열두 자(가장 긴 이름)
	expect(measure(longName) <= L.TAG.maxW, ("가장 긴 이름표의 폭 %d"):format(measure(longName)))
	local P = L.PARTY
	local pr = UI.hud.party
	expect(measure(pixelText.Fit(longName, pr.w, 1, "small")) <= pr.w, "파티원 칸의 이름")
	expect(P.max * P.row <= pr.h, "파티원 셋이 제 칸 안")
	expect(P.barY + P.barH <= P.row and P.barY >= M.small + 2 and P.barW <= pr.w, "파티원의 이름과 체력 줄이 한 사람의 칸 안")
	-- 초대 알림: 이름 한 줄과 「파티에 초대했다」 한 줄 · 단추 둘이 상자에 들어가고, 화면 칸과 겹치지 않는다
	local a = P.ask
	expect(measureBody(pixelText.Fit(longName, a.w - a.pad * 2, 1, "body")) <= a.w - a.pad * 2, "초대 알림의 이름")
	expect(measure(P.askText) <= a.w - a.pad * 2, "초대 알림의 글")
	expect(52 + M.button + a.pad - 2 <= a.h, "초대 알림의 단추가 상자 안")
	for _, g in GRIDS do
		local ar = L.rect(a, g.w, g.h)
		expect(ar.x >= 0 and ar.y >= 0 and ar.x + ar.w <= g.w and ar.y + ar.h <= g.h, "초대 알림이 화면 안 " .. g.name)
		for key, r in UI.hud do
			expect(apart(ar, L.rect(r, g.w, g.h)), ("초대 알림이 화면 칸과 겹치지 않는다 %s(%s)"):format(key, g.name))
		end
	end
end

-- ---------- 이름표 쌓기 · 채팅 줄 ----------
do
	local Tags = req("ReplicatedStorage/shared/lune/ui/tags")
	-- 이름표는 옮기지 않는다(사용자 2026-10-07: 내 이름이 주민 이름 아래로 밀려 내려가던 것) — 겹치면 앞선 것만 보인다
	local vis = Tags.visible({ { x = 0, y = 100, w = 40 }, { x = 60, y = 100, w = 40 } }, 13)
	expect(vis[1] and vis[2], "겹치지 않는 이름표는 둘 다 보인다")
	vis = Tags.visible({ { x = 0, y = 100, w = 40 }, { x = 20, y = 100, w = 40 }, { x = 70, y = 100, w = 40 } }, 13)
	expect(vis[1] and not vis[2] and vis[3], "겹치면 앞선 것(내 것)이 보이고 뒤의 것은 숨는다 — 숨은 것과만 겹치는 셋째는 보인다")
	vis = Tags.visible({ { x = 0, y = 100, w = 40 }, { x = 42, y = 100, w = 40 } }, 13)
	expect(vis[1] and not vis[2], "거의 붙어 있어도(사이 2) 겹친 것으로 본다 — 한 줄로 이어 읽히지 않게")
	vis = Tags.visible({ { x = 0, y = 100, w = 40 }, { x = 46, y = 100, w = 40 } }, 13)
	expect(vis[1] and vis[2], "사이가 넉넉하면(6) 둘 다 보인다")
	vis = Tags.visible({ { x = 0, y = 100, w = 40 }, { x = 10, y = 120, w = 40 } }, 13)
	expect(vis[1] and vis[2], "높이가 다르면 겹치지 않는다(문 위의 글과 발밑의 이름)")
	eq(#Tags.visible({}, 13), 0, "이름표가 없으면 빈 표")
	expect(L.TAG.h >= M.small + 2, "이름표를 쌓는 높이가 글자보다 크다")
	-- 발밑의 이름표(한 줄)가 화면 아래의 칸에 닿지 않는다(가장 작은 격자)
	do
		local ratio = G.min.w / 384
		local feet = KIT.ground * ratio
		local bottom = feet + L.TAG.down + L.TAG.h
		expect(bottom <= L.rect(UI.hud.skills, G.min.w, G.min.h).y + K.keyUp, ("발밑의 이름표(아래 끝 %d)가 스킬 칸의 아랫줄 위"):format(bottom))
	end
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
	-- 평소의 채팅 글: 채팅 칸에 세 줄
	local c, CH = UI.hud.chat, L.CHAT
	expect(math.floor(c.h / CH.line) >= 3, "채팅 칸에 세 줄이 들어간다")
	expect(c.y + c.h <= UI.hud.vitals.y, "채팅 글이 체력 덩어리 위에서 끝난다")
	-- 쓰는 중의 채팅 판: 세 격자에서 화면 안에 있고 체력 덩어리 위에서 끝난다. 긴 글도 세 줄 안에 들어간다
	local o = L.chatOpen()
	for _, g in GRIDS do
		local r = L.rect(o, g.w, g.h)
		expect(r.x >= 0 and r.y >= 0 and r.x + r.w <= g.w, "쓰는 중의 채팅 판이 화면 안 " .. g.name)
		expect(r.y + r.h <= L.rect(UI.hud.vitals, g.w, g.h).y, "쓰는 중의 채팅 판이 체력 덩어리 위에서 끝난다 " .. g.name)
		expect(apart(r, L.rect(UI.hud.party, g.w, g.h)), "쓰는 중의 채팅 판이 파티원 칸과 겹치지 않는다 " .. g.name)
	end
	expect(apart(o, UI.hud.skills), "쓰는 중의 채팅 판이 스킬 칸과 겹치지 않는다(1080p)")
	local textW = CH.open.w - CH.open.pad * 2
	local long = Tags.chatLine("party", "가나다라마바사아자차카타", string.rep("가", 80))
	local fitted = pixelText.Fit(long, textW, 3, "small")
	local lines = string.split(fitted, "\n")
	expect(#lines <= 3, "긴 글도 세 줄까지")
	for _, line in lines do
		expect(measure(line) <= textW, "채팅 줄이 판 안")
	end
	expect(CH.field >= M.small + 8, "쓰는 칸의 높이에 글과 여백이 들어간다")
end
