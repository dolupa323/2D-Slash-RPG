-- 묶음 메뉴(2026-11-13 사용자: "지금은 메뉴탭에 모두 집어넣은 상태라 개편해야하는거야") — 폰의 「바로가기」 배치에서 「전체」를 누르면 뜬다.
--  전에는 창 이름 단추 스물 남짓을 한 줄로 늘어놓아(boot의 onMenu · Layout.touchMenu) 밀어 내려야 찾았다.
--  이제 묶음(공방 design/basics.js의 MENU_GROUPS — 캐릭터 · 모험 · 함께 · 거래 · 설정)마다 이름 줄 + 그림 칸(그림 · 이름 · 받을 것이 있으면 노란 점)을 늘어놓는다.
--   묶음에 없는 창은 마지막 「그 밖」(MENU_OTHER) · 넘치면 판 안에서 위아래로 민다 · 오른쪽 위 X 또는 칸을 누르면 닫힌다.
--  셈(MenuGrid.group · MenuGrid.layout)은 화면을 모른다 — 시험이 직접 본다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local MenuGrid = {}
-- 치수(화면 틀의 점): 판의 가장 큰 폭 · 안쪽 여백 · 머리줄(제목 · X) · 묶음 이름 줄 · 칸(폭 · 높이) · 칸 사이 · 묶음 사이 [제가 정한 것]
MenuGrid.K = { maxW = 600, pad = 10, head = 24, group = 18, tileW = 64, tileH = 58, gap = 8, between = 8, bar = 4, pic = 24 }
-- 폰의 「전체」 = 오른쪽 옆 판(2026-11-14 사용자: "메뉴누르면 전 화면 가리는게 아니라 사이드바 형식으로 해" — 몇 분 전의 「화면 가득」을 바꿨다): 칸 셋 줄 · 그림 48점(도트 두 배) [제가 정한 것: 치수]
MenuGrid.K_SIDE = { maxW = 4000, pad = 12, head = 28, group = 20, tileW = 72, tileH = 68, gap = 8, between = 10, bar = 4, pic = 48, cols = 3 }
-- 옆 판의 폭(칸 cols줄이 꼭 드는 폭 — 스크롤 막대 몫 포함)
function MenuGrid.sideW(): number
	local K = MenuGrid.K_SIDE
	return K.pad * 2 + K.cols * K.tileW + (K.cols - 1) * K.gap + K.bar + 2
end
MenuGrid.TITLE = "전체 메뉴"
MenuGrid.EDIT = "바로가기 고치기"
MenuGrid.EDIT_DONE = "완료" -- (단추에는 「~다」를 쓰지 않는다)
MenuGrid.EDIT_HINT = "칸을 누르면 바로가기 줄에 놓거나 뺀다(다섯까지)"

-- 묶음으로 나눈다: items = { { id, name } … }(boot가 고른 차례) → { { id, name, items = { … } } … }(빈 묶음은 빼고 · 묶음에 없는 것은 「그 밖」)
function MenuGrid.group(items)
	local byId = {}
	for _, it in items do
		byId[it.id] = it
	end
	local used, out = {}, {}
	for _, g in UI.menuGroups do
		local list = {}
		for _, id in g.ids do
			local it = byId[id]
			if it and not used[id] then
				used[id] = true
				table.insert(list, it)
			end
		end
		if #list > 0 then
			table.insert(out, { id = g.id, name = g.name, items = list })
		end
	end
	local rest = {}
	for _, it in items do
		if not used[it.id] then
			table.insert(rest, it)
		end
	end
	if #rest > 0 then
		table.insert(out, { id = "other", name = UI.menuOther, items = rest })
	end
	return out
end

-- 자리: 판의 폭 w → 줄에 드는 칸 수 · 묶음마다 이름 줄의 y · 칸마다 { x, y } · 안의 전체 높이(스크롤하는 칸의 위에서부터)
function MenuGrid.layout(groups, w: number, K)
	K = K or MenuGrid.K
	local inner = w - K.pad * 2 - K.bar - 2
	local cols = math.max(1, math.floor((inner + K.gap) / (K.tileW + K.gap)))
	local y = 0
	local out = { cols = cols, groups = {} }
	for gi, g in groups do
		local gl = { y = y, tiles = {} }
		y += K.group
		for i, _ in g.items do
			local c, r = (i - 1) % cols, (i - 1) // cols
			table.insert(gl.tiles, { x = c * (K.tileW + K.gap), y = y + r * (K.tileH + K.gap) })
		end
		local rows = math.ceil(#g.items / cols)
		y += rows * K.tileH + (rows - 1) * K.gap
		if gi < #groups then
			y += K.between
		end
		table.insert(out.groups, gl)
	end
	out.h = y
	return out
end

-- 판을 짓는다: parent = 화면 틀(boot가 Stage.place로 놓은 것) · w, h = 판의 크기 · items · marks = { [id] = true } · onPick(id) · onClose()
--  keys = { [id] = 키 글자 }(PC — 칸의 왼쪽 위에 작게: 「M」 · 「O」 … 2026-11-13) · 없으면 적지 않는다(폰)
--  돌려주는 것: { frames = { [id] = 칸의 틀 } }(튜토리얼이 반짝이게 한다)
-- 판에 드는 높이(머리줄 · 안쪽 여백 · 묶음들) — 판을 그보다 크게 잡지 않는다
function MenuGrid.need(items, w: number, K): number
	K = K or MenuGrid.K
	return K.head + 2 + MenuGrid.layout(MenuGrid.group(items), w, K).h + K.pad
end
--  edit = { on = 고치는 중인가, list = 바로가기 줄에 놓은 것, toggle = () -> () } — 있으면(폰의 바로가기 배치) 머리줄에 「바로가기 고치기」 단추 ·
--   고치는 중에는 줄에 놓인 칸이 민트로 덮이고 칸을 누르면 onPick(id) 대신 줄에 놓거나 뺀다(boot의 state.openMenuGrid — 2026-11-13 메이플스토리M의 「퀵 메뉴」처럼)
--  고칠 수 없는 칸(하는 일 @… · 관리)은 놓을 수 없다
function MenuGrid.canPin(id: string): boolean
	return string.sub(id, 1, 1) ~= "@" and id ~= "admin"
end
--  side = 폰의 오른쪽 옆 판(K_SIDE — 큰 칸 · 48점 그림 · 2026-11-14 사용자: "메뉴누르면 전 화면 가리는게 아니라 사이드바 형식으로 해")
--  고치는 중(edit.on)이면 머리줄 아래에 안내 한 줄(옆 판은 좁아 머리줄에 들지 않는다 — 판 안의 칸들은 그만큼 내려간다)
function MenuGrid.build(parent: Frame, w: number, h: number, items, marks, onPick: (string) -> (), onClose: () -> (), keys, edit, side: boolean?)
	local K = if side then MenuGrid.K_SIDE else MenuGrid.K
	local groups = MenuGrid.group(items)
	local L = MenuGrid.layout(groups, w, K)
	local panel = Ui.panel(parent, 0, 0, w, h)
	local editW = if edit then math.max(90, Ui.measure(if edit.on then MenuGrid.EDIT_DONE else MenuGrid.EDIT, "small") + 14) else 0
	local hintH = if edit and edit.on then 30 else 0
	Ui.text(panel, if edit and edit.on then MenuGrid.EDIT else MenuGrid.TITLE, K.pad, 6, w - K.pad * 2 - 30 - editW - 6, { font = "body", color = C.accent, lines = 1 })
	if hintH > 0 then
		Ui.text(panel, MenuGrid.EDIT_HINT, K.pad, K.head + 2, w - K.pad * 2, { font = "small", color = C.dim, lines = 2, line = 13 })
	end
	local bh = if side then 24 else 18 -- (머리줄 단추의 높이 — 폰은 누르기 쉽게)
	local xw = if side then 32 else 24
	Ui.button(panel, "X", w - K.pad - xw, 3, xw, onClose, { h = bh, font = "small" }).frame.Name = "Do_close"
	if edit then
		Ui.button(panel, if edit.on then MenuGrid.EDIT_DONE else MenuGrid.EDIT, w - K.pad - xw - 6 - editW, 3, editW, edit.toggle, { h = bh, font = "small", main = edit.on }).frame.Name = "Do_barEdit"
	end
	Ui.box(panel, K.pad, K.head - 2, w - K.pad * 2, 1, C.line)
	local viewH = h - K.head - K.pad - hintH
	local list = Ui.scroll(panel, K.pad, K.head + 2 + hintH, w - K.pad * 2, viewH, L.h, K.bar)
	list.Name = "List"
	list.ZIndex = 2
	local frames = {}
	for gi, g in groups do
		local gl = L.groups[gi]
		Ui.text(list, g.name, 0, gl.y + 2, 200, { font = "small", color = C.dim })
		for i, it in g.items do
			local at = gl.tiles[i]
			local tile = Ui.group(list, at.x, at.y, K.tileW, K.tileH, "Tile_" .. string.gsub(it.id, "@", ""))
			Ui.part(tile, "uSlot", 0, 0, K.tileW, K.tileH)
			local pic = Ui.pic(tile, UI.menuIcon[it.id] or "menu_gear", math.floor((K.tileW - K.pic) / 2), 6)
			if K.pic ~= 24 then
				pic.Size = UDim2.fromOffset(K.pic, K.pic) -- (도트를 정수 배로 — 큰 판)
			end
			Ui.text(tile, it.name, 2, K.tileH - 20, K.tileW - 4, { align = "center", font = "small", outline = true, lines = 1 })
			local key = keys and keys[it.id]
			if key and key ~= "" then
				Ui.text(tile, key, 3, 2, 22, { font = "small", color = C.dim, outline = true })
			end
			if marks and marks[it.id] then
				local dot = Ui.box(tile, K.tileW - 10, 3, 7, 7, C.ink)
				Ui.box(dot, 1, 1, 5, 5, C.gold)
				dot.Name = "Dot"
				dot.ZIndex = 9
			end
			if edit and edit.on then
				if table.find(edit.list, it.id) then
					Ui.box(tile, 0, 0, K.tileW, K.tileH, C.accent, 0.72).Name = "Pinned" -- (줄에 놓인 칸)
				elseif not MenuGrid.canPin(it.id) then
					Ui.box(tile, 0, 0, K.tileW, K.tileH, C.ink, 0.45).Name = "NoPin" -- (놓을 수 없는 칸 — 어둡게)
				end
			end
			local hit = Ui.hit(tile)
			hit.Activated:Connect(function()
				onPick(it.id)
			end)
			frames[it.id] = tile
		end
	end
	return { frames = frames, groups = groups, layout = L }
end

return MenuGrid
