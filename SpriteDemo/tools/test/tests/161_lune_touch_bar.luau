-- 「달의 계승자」 — 폰 단추 배치 셋째 「바로가기」(2026-11-13 사용자: "다른 대형 상용 rpg 들중에 모바일 ui 공부한뒤에 우리 모바일 ui도 조금더 편하게 개편한다 …
--  지금은 메뉴탭에 모두 집어넣은 상태라 개편해야하는거야 그래서 모바일은 또 ui 선택을 이번에 생기는 버전으로도 선택할수 있게해서 3가지 버전을 선택해서 쓸수있게").
--  client touchBar.luau(오른쪽 위 바로가기 줄) · ui/menuGrid.luau(「전체」 = 묶음 메뉴) · touch.luau Touch.setStyle · shared sim/account.luau cleanSound · client viewOpts.luau
--  보는 것: ① 설계(공방 basics.js TOUCH_BAR · MENU_GROUPS · MENU_ICON) — 칸의 그림이 UI 키트에 있다 · 칸이 손가락으로 누를 만큼 크다
--   ② 줄의 칸 자리(겹치지 않는다 · 한 줄) ③ 묶음(차례 · 빈 묶음은 빼고 · 묶음에 없는 창은 「그 밖」) · 자리(판 안 · 겹치지 않는다)
--   ④ 묶음 메뉴를 그린다(칸마다 그림 · 이름이 칸에 든다 · 노란 점 · 누르면 그 일 · X로 닫힌다) ⑤ 저장 「bar」를 받는다 · 다시 읽어도 「bar」 · 바로가기 배치에는 「메뉴」 단추가 없다
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local KIT = req("ReplicatedStorage/shared/lune/data/kit.generated")
local pixelText = req("Client/ui/pixelText")
local Account = req("ReplicatedStorage/shared/lune/sim/account")
pixelText.Register("small", KIT.font.small, {}) -- (글의 폭을 잰다 — 시험 30과 같게)
pixelText.Register("body", KIT.font.body, {})
-- 가짜 화면(그려진 것을 센다) — 모듈을 부르기 전에
local texts, pics, hits, buttons, dots = {}, {}, {}, {}, 0
local BOXES = {}
local function frame(name)
	return { Name = name or "Frame", Destroy = function() end }
end
local any = setmetatable({}, { __index = function() return "c" end })
MOCK("Client/lune/ui/ui", {
	COLOR = any,
	panel = function() return frame("Panel") end,
	scroll = function() return frame("Scroll") end,
	group = function(_, x, y, w0, h0, name) local f = frame(name); f.x, f.y, f.w, f.h = x, y, w0, h0; return f end,
	part = function() return frame("Part") end,
	pic = function(_, name) table.insert(pics, name); return frame("Pic") end,
	text = function(parent, text, x, y, width, opts) table.insert(texts, { parent = parent, text = text, width = width, font = opts and opts.font }); return { set = function() end } end,
	box = function(_, _, _, bw) if bw == 7 then dots += 1 end local f = frame("Box"); table.insert(BOXES, f); return f end,
	measure = function(text) return #text * 4 end,
	hit = function(f) local h0 = { Activated = { Connect = function(_, fn) table.insert(hits, { frame = f, fn = fn }) end } }; return h0 end,
	button = function(_, text, _, _, _, fn) local b = { text = text, fn = fn, frame = frame("Button") }; table.insert(buttons, b); return b end,
})

-- ① 설계
local B = UI.touchBar
expect(B ~= nil and #B.items == 6, "바로가기 줄의 칸 여섯")
eq(B.items[#B.items], "@all", "맨 끝은 「전체」")
expect(B.tile >= 44, "칸이 손가락으로 누를 만큼 크다(44점 — 폰의 가장 작은 격자에서 약 48pt)")
local icons = KIT.parts.pics.icons
for id, pic in UI.menuIcon do
	expect(icons[pic] ~= nil, ("메뉴 칸 「%s」의 그림 %s가 UI 키트에 있다"):format(id, pic))
end
for _, id in B.items do
	expect(UI.menuIcon[id] ~= nil, "바로가기 칸 " .. id .. "에 그림이 정해져 있다")
end
local seen = {}
for _, g in UI.menuGroups do
	for _, id in g.ids do
		expect(not seen[id], "한 창은 한 묶음에만: " .. id)
		seen[id] = true
	end
end

-- ② 줄의 칸 자리
local TouchBar = req("Client/lune/touchBar")
local w, h = TouchBar.size()
eq(h, B.tile, "한 줄")
eq(w, B.cols * B.tile + (B.cols - 1) * B.gap, "줄의 폭")
expect(B.x + w <= 960 - 4, "줄이 화면의 오른쪽 끝 안(1080p 격자)")
for i = 1, #B.items - 1 do
	local x1 = TouchBar.cell(i)
	local x2 = TouchBar.cell(i + 1)
	expect(x2 >= x1 + B.tile, "칸끼리 겹치지 않는다")
end

-- ③ 묶음 · 자리
local MenuGrid = req("Client/lune/ui/menuGrid")
local items = {
	{ id = "bag", name = "가방" }, { id = "equip", name = "장비" }, { id = "stat", name = "능력치" }, { id = "skill", name = "스킬" }, { id = "quest", name = "퀘스트" },
	{ id = "map", name = "월드맵" }, { id = "party", name = "파티" }, { id = "auction", name = "경매장" }, { id = "cash", name = "달빛 상점" }, { id = "attend", name = "출석" },
	{ id = "achieve", name = "업적" }, { id = "sound", name = "게임 설정" }, { id = "coupon", name = "쿠폰" }, { id = "channel", name = "채널" }, { id = "schedule", name = "스케줄러" },
	{ id = "seq", name = "시퀀스" }, { id = "@arrange", name = "단추 배치" }, { id = "@layout", name = "화면 배치" }, { id = "@chars", name = "캐릭터 선택" },
}
local groups = MenuGrid.group(items)
eq(groups[1].name, "캐릭터", "첫 묶음 = 캐릭터")
eq(groups[1].items[1].id, "bag", "캐릭터의 첫 칸 = 가방(묶음의 차례)")
local names = {}
for _, g in groups do
	table.insert(names, g.name)
	expect(#g.items > 0, "빈 묶음은 뺀다")
end
eq(table.concat(names, ","), "캐릭터,모험,함께,거래,설정,그 밖", "묶음의 차례 · 묶음에 없는 시퀀스는 「그 밖」")
local n = 0
for _, g in groups do
	n += #g.items
end
eq(n, #items, "모든 칸이 어딘가에 하나씩")
for _, gw in { 560, 600, 400 } do
	local L = MenuGrid.layout(groups, gw)
	local K = MenuGrid.K
	local boxes = {}
	for gi, gl in L.groups do
		for _, t in gl.tiles do
			expect(t.x >= 0 and t.x + K.tileW <= gw - K.pad * 2 - K.bar, ("판 폭 %d: 칸이 판 안"):format(gw))
			expect(t.y >= gl.y + K.group, "칸은 묶음 이름 줄 아래")
			for _, o in boxes do
				expect(not (t.x < o.x + K.tileW and o.x < t.x + K.tileW and t.y < o.y + K.tileH and o.y < t.y + K.tileH), "칸끼리 겹치지 않는다")
			end
			table.insert(boxes, t)
		end
		if gi > 1 then
			expect(gl.y > L.groups[gi - 1].y, "묶음은 위에서 아래로")
		end
	end
	expect(L.h > 0 and L.cols >= 3, ("판 폭 %d: 한 줄에 칸 셋 넘게(%d)"):format(gw, L.cols))
end

-- ④ 그린다(가짜 화면)
do
	local MG = MenuGrid
	local picked, closed = nil, false
	local built = MG.build(frame("Holder"), 560, 360, items, { attend = true, stat = true }, function(id) picked = id end, function() closed = true end)
	for _, it in items do
		expect(built.frames[it.id] ~= nil, "칸이 있다: " .. it.name)
	end
	eq(#pics, #items, "칸마다 그림 하나")
	eq(dots, 2, "받을 것이 있는 칸(출석 · 능력치)에만 노란 점")
	for _, t in texts do
		if t.parent and t.parent.Name and string.match(t.parent.Name, "^Tile_") then
			expect(pixelText.Measure(t.text, "small") <= t.width, ("칸의 이름이 칸에 든다: %s(%d / %d)"):format(t.text, pixelText.Measure(t.text, "small"), t.width))
		end
	end
	for _, hh in hits do
		if hh.frame.Name == "Tile_attend" then
			hh.fn()
		end
	end
	eq(picked, "attend", "출석 칸을 누르면 출석")
	for _, b in buttons do
		if b.text == "X" then
			b.fn()
		end
	end
	expect(closed, "X를 누르면 닫힌다")
end

-- 바로가기 줄의 칸 이름도 칸에 든다(PC 단추 줄의 짧은 이름 — 상점 · 전체)
for _, id in B.items do
	local name = if id == "@all" then B.all else ((UI.layout.menu.labels and UI.layout.menu.labels[id]) or id)
	if id ~= "@all" then
		for _, wdef in UI.windows do
			if wdef.id == id and not (UI.layout.menu.labels and UI.layout.menu.labels[id]) then
				name = wdef.name
			end
		end
	end
	expect(pixelText.Measure(name, "small") <= B.tile - 2, ("바로가기 칸의 이름이 칸에 든다: %s"):format(name))
end

-- ⑤ 저장 · 고르기
local base = { music = 5, sfx = 5, on = true }
local function with(t)
	local v = table.clone(base)
	v.touch = t
	return Account.cleanSound(v)
end
local ok = with("bar")
expect(ok ~= nil and ok.touch == "bar", "저장: 「bar」(2026-11-13의 바로가기 — 화면은 새 배치로 읽는다)를 받는다")
expect(with("left") ~= nil and with("left").touch == "left", "저장: 「left」(왼손 배치 — 2026-11-14)를 받는다")
expect(with("weird") == nil, "모르는 배치는 받지 않는다")
expect(with("old").touch == "old" and with("new").touch == "new", "새 배치 · 예전 배치는 그대로")
local ViewOpts = req("Client/lune/viewOpts")
pcall(ViewOpts.import, { touch = "left" }) -- (언어를 거는 데서 시험에 없는 글꼴 모듈을 부른다 — 배치는 그 전에 읽는다)
eq(ViewOpts.touch, "left", "다시 읽어도 왼손 배치")
pcall(ViewOpts.import, { touch = "old" })
eq(ViewOpts.touch, "old", "예전 배치")
pcall(ViewOpts.import, {})
eq(ViewOpts.touch, "new", "저장이 없으면 새 배치")
local choices = UI.layout.sound.touch.choices
eq(#choices, 3, "게임 설정의 「폰 단추 배치」에 셋")
eq(choices[3][1], "left", "셋째 = 왼손 배치(2026-11-14 — 메뉴 개편은 세 배치 모두에)")
-- 왼손 배치: 손가락 단추의 아래쪽 무리를 좌우로 뒤집는다(touch.luau와 같은 셈) — 조이스틱은 오른쪽 · 사냥기는 왼쪽
do
	local G0 = req("ReplicatedStorage/shared/lune/data/ui.generated")
	local VW = 384
	for _, t in G0.touch do
		if t.kind == "pad" then
			expect(VW - t.x - t.w > VW / 2, "왼손: 조이스틱이 오른쪽 절반")
		elseif t.slot == 2 then
			expect(VW - t.x - t.w + t.w < VW / 2, "왼손: 사냥기 단추가 왼쪽 절반")
		end
	end
	expect(G0.hudTouchLeft ~= nil and G0.hudTouchLeft.vitals ~= nil and G0.hudTouchLeft.gainLog ~= nil, "왼손 배치에서 옮기는 칸: 체력 · 획득 알림")
end

-- ⑥ 채팅 한 줄 미리 보기(바로가기 배치 — chatPeek.luau · 2026-11-13): 「이름: 글」 · 판이 닫혀 있을 때만(chat.luau Chat.onPeek)
local ChatPeek = req("Client/lune/chatPeek")
eq(ChatPeek.line("달빛", "안녕"), "달빛: 안녕", "이름: 글")
eq(ChatPeek.line(nil, "알림"), "알림", "이름이 없으면 글만")
expect(ChatPeek.SHOW > 0 and ChatPeek.RECT.y + ChatPeek.RECT.h <= 100, "「채팅」 단추 아래 · 획득 알림(y 100) 위")

-- ⑦ 윤슬 호수 업적(2026-11-13 — 공방 achieve.js kinds_r5 · visit_r5): 셈하는 맵(지역 r5 · 실내 아님)이 모두 물별 마을에서 문으로 이어진다(깰 수 있다) · 새 몬스터 둘이 도감에 든다
do
	local AD = req("ReplicatedStorage/shared/lune/data/achieve.generated")
	local SC = req("ReplicatedStorage/shared/lune/data/scenes.generated")
	local found = {}
	for _, a in AD.list do
		found[a.id] = a
	end
	expect(found.kinds_r5 ~= nil and found.visit_r5 ~= nil, "윤슬 호수의 업적 둘(도감 · 모든 맵)")
	local maps, kinds = {}, {}
	for key, sc in SC.scenes do
		if sc.region == "r5" and key ~= "dream" and not sc.indoor then
			maps[key] = true
			for _, m in (if sc.inst then {} else sc.mobs or {}) do
				kinds[m.kind] = true
			end
		end
	end
	local seen, todo = { r5t = true }, { "r5t" }
	while #todo > 0 do
		local k = table.remove(todo)
		local sc = SC.scenes[k]
		for _, p in (sc and sc.portals) or {} do
			local to = SC.base(p.to) or p.to
			if to and not seen[to] and SC.scenes[to] then
				seen[to] = true
				table.insert(todo, to)
			end
		end
	end
	for key in maps do
		expect(seen[key] == true, "윤슬 호수의 맵이 물별 마을에서 문으로 이어진다: " .. key)
	end
	expect(kinds.lotustoad and kinds.lakeserpent, "도감에 연잎 두꺼비 · 새끼 이무기")
end

-- ⑧ 바로가기 고치기(2026-11-13 — 메이플스토리M의 퀵 메뉴처럼): 줄에 놓을 것 · 저장의 꼴 · 고치는 모습
eq(table.concat(TouchBar.list(nil), ","), "bag,equip,skill,quest,cash,@all", "고른 것이 없으면 설계의 차례 + 전체")
eq(table.concat(TouchBar.list({ "map", "party" }), ","), "map,party,@all", "고른 것 + 전체(끝)")
eq(#TouchBar.list({ "a", "b", "c", "d", "e", "f", "g" }), 6, "다섯까지 + 전체")
local sv = Account.cleanSound({ music = 5, sfx = 5, on = true, bar = { "map", "map", "@all", "bad id", "party", 3 } })
eq(table.concat(sv.bar, ","), "map,party", "저장: 겹친 것 · 전체 · 꼴이 틀린 것은 버린다")
eq(Account.cleanSound({ music = 5, sfx = 5, on = true }).bar, nil, "저장이 없으면 처음 차례(nil)")
expect(not MenuGrid.canPin("@chars") and not MenuGrid.canPin("admin") and MenuGrid.canPin("map"), "하는 일 · 관리는 줄에 놓지 못한다")
do
	table.clear(BOXES)
	local toggled = false
	MenuGrid.build(frame("Holder"), 560, 360, items, {}, function() end, function() end, nil, { on = true, list = { "map", "party" }, toggle = function() toggled = true end })
	local pinned, nopin = 0, 0
	for _, b in BOXES do
		if b.Name == "Pinned" then
			pinned += 1
		elseif b.Name == "NoPin" then
			nopin += 1
		end
	end
	eq(pinned, 2, "고치는 중: 줄에 놓인 칸 둘이 민트로 덮인다")
	eq(nopin, 3, "고치는 중: 놓을 수 없는 칸(단추 배치 · 화면 배치 · 캐릭터 선택)은 어둡게")
	for _, b in buttons do
		if b.text == MenuGrid.EDIT_DONE then
			b.fn()
		end
	end
	expect(toggled, "「완료」를 누르면 고치기를 끝낸다")
end
-- 폰의 「전체」 = 오른쪽 옆 판(2026-11-14 사용자 "메뉴누르면 전 화면 가리는게 아니라 사이드바 형식으로 해"): 폭 = 칸 셋 줄 · 가장 작은 격자의 절반보다 좁다 ·
--  고치는 중의 안내 글은 머리줄 아래 두 줄 안에 든다 · 칸 이름이 칸 안에 든다
do
	local KS = MenuGrid.K_SIDE
	local sw = MenuGrid.sideW()
	expect(sw < UI.grid.min.w / 2, ("옆 판의 폭 %d < 가장 작은 격자의 절반 %d"):format(sw, UI.grid.min.w / 2))
	eq(MenuGrid.layout(MenuGrid.group(items), sw, KS).cols, KS.cols, "옆 판에 칸이 셋 줄")
	table.clear(texts)
	MenuGrid.build(frame("Side"), sw, 380, items, {}, function() end, function() end, nil, { on = true, list = {}, toggle = function() end }, true)
	for _, t in texts do
		if t.text == MenuGrid.EDIT_HINT then
			expect(pixelText.Measure(t.text, "small") <= t.width * 2, ("안내 글이 두 줄 안에 든다(%d / %d)"):format(pixelText.Measure(t.text, "small"), t.width * 2))
		elseif t.text == MenuGrid.EDIT then
			expect(pixelText.Measure(t.text, "body") <= t.width, ("옆 판의 제목이 든다(%d / %d)"):format(pixelText.Measure(t.text, "body"), t.width))
		end
	end
	for _, it in items do
		expect(pixelText.Measure(it.name, "small") <= KS.tileW - 4, "옆 판의 칸 이름이 든다 " .. it.name)
	end
end

-- ⑨ 2 · 3 · 4지역의 도감 · 만월성의 모든 맵(2026-11-13): 도감이 세는 맵(보통 몬스터가 사는 바깥 맵)과 「모든 맵」이 세는 맵이 마을에서 문으로 이어진다
do
	local AD = req("ReplicatedStorage/shared/lune/data/achieve.generated")
	local SC = req("ReplicatedStorage/shared/lune/data/scenes.generated")
	local has = {}
	for _, a in AD.list do
		has[a.id] = a
	end
	local HUB = { r1 = "town", r2 = "ct", r3 = "r3ah", r4 = "r4ch", r5 = "r5t" }
	local seen, todo = {}, {}
	for _, h in HUB do
		seen[h] = true
		table.insert(todo, h)
	end
	while #todo > 0 do
		local k = table.remove(todo)
		local sc = SC.scenes[k]
		for _, p in (sc and sc.portals) or {} do
			local to = SC.base(p.to) or p.to
			if to and not seen[to] and SC.scenes[to] then
				seen[to] = true
				table.insert(todo, to)
			end
		end
	end
	for _, r in { "r2", "r3", "r4", "r5" } do
		if has["kinds_" .. r] then
			for key, sc in SC.scenes do
				if sc.region == r and not sc.indoor and not sc.inst and #(sc.mobs or {}) > 0 then
					expect(seen[key] == true, ("%s 도감: 몬스터가 사는 맵이 문으로 이어진다 — %s"):format(r, key))
				end
			end
		end
		if has["visit_" .. r] then
			for key, sc in SC.scenes do
				if sc.region == r and key ~= "dream" and not sc.indoor then
					expect(seen[key] == true, ("%s 모든 맵: 문으로 이어진다 — %s"):format(r, key))
				end
			end
		end
	end
	expect(has.kinds_r2 and has.kinds_r3 and has.kinds_r4 and has.visit_r4, "2 · 3 · 4지역의 도감 · 만월성의 모든 맵")
	expect(not has.visit_r2 and not has.visit_r3, "2 · 3지역의 「모든 맵」은 없다(보스 방은 문이 없다)")
end
