-- 월드맵 창(M) — 그림으로 된 지역 지도 위에 장소의 표시를 얹는다(메이플스토리의 월드맵처럼).
--  사용자 2026-10-11: "월드맵 똑바로 그리세요 다른 게임 월드맵 참고라도 하던가 퀄리티가 이게 뭡니까 없는게 나은수준인데" — 전의 것은 네모를 선으로 이은 도표였다(없앴다).
--  사용자 같은 날(이 창을 보고): "바위틈 같은 사냥터 표시안되고, 은달항구의 경우 지금 수비대 야영지에서 포탈로 갈수있는데 맵에서는 그냥 좌측 은달항구라고 나와버리면 어떻게 하라는건지?"
--   → 곁맵(굽잇길의 문 「바위 틈으로」 = 옛 은신처 · 멧돼지 굴)도 싣고, 모든 장소에 이름표를 달고, 은달 항구는 수비대 야영지에서 점줄로 이어진 표시로 그린다.
--  왼쪽: 지역의 그림(384x256 · Codex로 그려 옮긴 것 — 공방 assetpack/lune/worldmap) 위에
--   ① 장소마다 동그란 표시(갈래의 색: 마을 민트 · 쉼터 노랑 · 사냥터 흰색 · 던전 분홍 · 곁맵 회색 · 보스 빨강)와 이름표(서로 겹치지 않게 아래 · 위 · 옆에 놓는다 — WM.placeLabels)
--   ② 내가 있는 곳: 민트 고리와 그 위의 화살표, 민트 이름표 ③ 퀘스트를 받을 곳 「!」 · 돌려줄 곳 「?」 ④ 내 레벨에 맞는 사냥터: 풀빛 고리와 풀빛 이름표
--   ⑤ 지금 가야 할 곳까지의 길: 표시 사이를 잇는 금빛 점줄 ⑥ 다른 지역(은달 항구): 그 도시가 그려진 자리의 민트 표시 — 그리로 가는 포탈이 있는 장소(수비대 야영지)에서 민트 점줄로 잇는다
--  오른쪽: 고른 장소의 이름 · 갈래 · 레벨 · 다른 지역으로 가는 포탈 · 몬스터 · 주민, 내 레벨의 사냥터, 가는 길(글).
--  그림이 있는 지역만 보여 준다(그림이 없는 지역은 탭도 없다 — 도표로 때우지 않는다). 이동하는 기능은 없다(보기만 한다).
--  셈은 shared/lune/ui/worldmap.luau, 자리는 data/worldmap.generated.luau의 art(공방 js/lune/design/journey.js의 WORLDART).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local WM = require(lune.ui.worldmap)
local ASSETS = require(lune.data["assets.generated"])
local UI = require(lune.data["ui.generated"])
local Ui = require(script.Parent.ui)
local Kit = require(script.Parent.kit)

local C = Ui.COLOR

local MapWindow = { wide = true }
MapWindow.ART_W, MapWindow.ART_H = WM.ART_W, WM.ART_H -- 그림의 크기(화면 틀의 점 — 그림의 한 점이 화면 틀의 한 점)
MapWindow.SIDE_W, MapWindow.GAP = WM.SIDE_W, 12 -- 오른쪽 글 칸의 폭 · 그림과의 사이
MapWindow.TAB_H = 22 -- 탭 줄(그림이 있는 지역이 둘 넘을 때만)
MapWindow.PIN = WM.PIN -- 표시의 반지름

-- 장소의 갈래마다의 색
local KIND = { town = C.accent, village = C.accent, rest = C.gold, hunt = C.text, road = C.dim, climb = C.pink, dead = C.dim, boss = C.red }

function MapWindow.size(): (number, number)
	local tabs = if #WM.arted() > 1 then MapWindow.TAB_H else 0
	return MapWindow.ART_W + MapWindow.GAP + MapWindow.SIDE_W, tabs + MapWindow.ART_H
end

-- 동그란 표시(네모를 겹쳐 모서리를 깎는다): 어두운 테두리 + 속
local function dot(parent: Instance, x: number, y: number, r: number, color: Color3, name: string)
	local holder = Ui.group(parent, x - r - 1, y - r - 1, r * 2 + 3, r * 2 + 3, name)
	local c = r + 1
	Ui.box(holder, c - r - 1, c - r + 1, r * 2 + 3, r * 2 - 1, C.ink)
	Ui.box(holder, c - r + 1, c - r - 1, r * 2 - 1, r * 2 + 3, C.ink)
	Ui.box(holder, c - r, c - r, r * 2 + 1, r * 2 + 1, C.ink)
	Ui.box(holder, c - r, c - r + 2, r * 2 + 1, r * 2 - 3, color).Name = "Fill"
	Ui.box(holder, c - r + 2, c - r, r * 2 - 3, r * 2 + 1, color).Name = "Fill"
	Ui.box(holder, c - r + 1, c - r + 1, r * 2 - 1, r * 2 - 1, color).Name = "Fill"
	return holder
end

-- 고리(표시 둘레의 한 점 굵기의 네모 테두리 — 내가 있는 곳 · 내 레벨의 사냥터)
local function ring(parent: Instance, x: number, y: number, r: number, color: Color3, name: string)
	local s = r * 2 + 1
	for _, b in { { x - r, y - r, s, 1 }, { x - r, y + r, s, 1 }, { x - r, y - r, 1, s }, { x + r, y - r, 1, s } } do
		Ui.box(parent, b[1], b[2], b[3], b[4], color).Name = name
	end
end

-- 점줄: 표시에서 표시로 곧게, 다섯 점마다 한 점
local function dots(parent: Instance, a, b, color: Color3, name: string)
	local dx, dy = b[1] - a[1], b[2] - a[2]
	local n = math.max(1, math.floor(math.sqrt(dx * dx + dy * dy) / 5))
	for k = 1, n - 1 do
		Ui.box(parent, math.floor(a[1] + dx * k / n) - 1, math.floor(a[2] + dy * k / n) - 1, 2, 2, color).Name = name
	end
end

-- 이름표: 어두운 판 위의 작은 글(자리는 WM.placeLabels가 정한 것)
local function plate(parent: Instance, text: string, rect, color: Color3, name: string)
	local holder = Ui.group(parent, rect.x, rect.y, rect.w, rect.h, name)
	Ui.box(holder, 0, 0, rect.w, rect.h, C.ink, 0.15)
	Ui.box(holder, 0, rect.h - 1, rect.w, 1, color, 0.4)
	Ui.text(holder, text, WM.PLATE.padX, 2, rect.w - WM.PLATE.padX * 2, { color = color })
	return holder
end

function MapWindow.build(body: Frame, ctx, w: number, _h: number)
	local view = {}
	local regions = WM.arted()
	local myRegion = WM.nodeOf(ctx.scene())
	local rid = if myRegion and WM.region(myRegion).art then myRegion else regions[1]
	local picked: string? = nil -- 누른 장소(없으면 내가 있는 곳). 다른 지역의 표시는 "out:지역"
	local layer: Frame? = nil
	local top = if #regions > 1 then MapWindow.TAB_H else 0

	local tabs = {}
	if #regions > 1 then
		local tx = 0
		for i, id in regions do
			tabs[i] = Ui.tab(body, WM.region(id).name, tx, 0, function()
				if rid ~= id then
					rid = id
					picked = nil
					view.refresh()
				end
			end)
			tabs[i].region = id
			tx += tabs[i].width + 14
		end
	end

	-- 그림(지역을 바꿀 때 갈아 끼운다)
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.BackgroundColor3 = C.ink
	art.BorderSizePixel = 0
	art.ResampleMode = Enum.ResamplerMode.Pixelated
	art.Position = UDim2.fromOffset(0, top)
	art.Size = UDim2.fromOffset(MapWindow.ART_W, MapWindow.ART_H)
	art.Parent = body
	-- 그림의 테두리(한 점)
	for _, b in { { 0, 0, MapWindow.ART_W, 1 }, { 0, MapWindow.ART_H - 1, MapWindow.ART_W, 1 }, { 0, 0, 1, MapWindow.ART_H }, { MapWindow.ART_W - 1, 0, 1, MapWindow.ART_H } } do
		local edge = Ui.box(art, b[1], b[2], b[3], b[4], C.lineHot)
		edge.Name = "Edge"
		edge.ZIndex = 8
	end

	-- 오른쪽 글 칸
	local sx, sw = MapWindow.ART_W + MapWindow.GAP, MapWindow.SIDE_W
	local side = Ui.group(body, sx, top, sw, MapWindow.ART_H, "Side")
	local head = Ui.text(side, "", 0, 0, sw, { font = "body", color = C.gold })
	local headLv = Ui.text(side, "", 0, 3, sw, { align = "right", color = C.dim })
	Ui.box(side, 0, 20, sw, 1, C.lineHot)
	local name = Ui.text(side, "", 0, 26, sw, { font = "body" })
	local sub = Ui.text(side, "", 0, 43, sw, { color = C.dim })
	local link = Ui.text(side, "", 0, 57, sw, { color = C.accent })
	local mobHead = Ui.text(side, "몬스터", 0, 73, sw, { color = C.off })
	local mobs = Ui.text(side, "", 0, 86, sw, { lines = WM.SIDE.mobLines, color = C.text })
	local npcHead = Ui.text(side, "주민", 0, 116, sw, { color = C.off })
	local npcs = Ui.text(side, "", 0, 129, sw, { lines = WM.SIDE.npcLines, color = C.text })
	Ui.box(side, 0, 162, sw, 1, C.line)
	Ui.text(side, "내 레벨의 사냥터", 0, 166, sw, { color = C.off })
	local best = Ui.text(side, "", 0, 179, sw, { color = C.green })
	Ui.text(side, "가는 길", 0, 195, sw, { color = C.off })
	local goalTitle = Ui.text(side, "", 0, 208, sw, { color = C.gold })
	local route = Ui.text(side, "", 0, 221, sw, { lines = WM.SIDE.routeLines, color = C.text })

	local function showSide(id: string)
		local region = WM.region(rid)
		local to = string.match(id, "^out:(.+)$")
		local info = if to then WM.outCard(rid, to) else WM.card(rid, id)
		head:set(region.name)
		headLv:set(WM.regionLevels(rid))
		name:set(info.name)
		sub:set(info.sub)
		link:set(info.link)
		mobHead:show(info.mobs ~= "")
		mobs:set(info.mobs)
		npcHead:show(info.npcs ~= "")
		npcs:set(info.npcs)
	end

	-- 그림 위의 표시들을 다시 그린다(지역을 바꿨다 · 퀘스트나 내 자리가 바뀌었다 · 다른 장소를 골랐다)
	function view.draw()
		if layer then
			layer:Destroy()
		end
		local region = WM.region(rid)
		local A = region.art
		art.Image = ASSETS[A.img] or ""
		local group = Ui.group(art, 0, 0, MapWindow.ART_W, MapWindow.ART_H, "Marks")
		group.ZIndex = 2
		layer = group
		local me = ctx.me()
		local level = if me then me.level else 1
		local sceneRegion, sceneNode = WM.nodeOf(ctx.scene())
		local mine = if sceneRegion == rid then sceneNode else nil
		local marks = WM.marks(rid, ctx.quests() or {}, level)
		local bestText, bestNode = WM.recommendShort(rid, level)
		local card = WM.goalCard(ctx.quests() or {}, level, ctx.scene())
		local path, goal = if card then card.route else nil, if card then card.goal else nil
		for _, t in tabs do
			t:setOn(t.region == rid)
		end
		-- ⑥ 다른 지역으로 가는 길: 포탈이 있는 장소에서 그 지역의 표시까지 민트 점줄(늘 보인다)
		for _, ex in WM.exits(rid) do
			local from, to = A.at[ex.node], A.out[ex.to]
			if from and to then
				dots(group, from, to, C.accent, "OutLink")
			end
		end
		-- ⑤ 가는 길: 이 지역을 지나는 구간마다 금빛 점줄(다른 지역으로 넘어가는 구간은 그 지역의 표시까지)
		local goalNode = nil
		if path then
			for i = 2, #path do
				local a, b = path[i - 1], path[i]
				local pa = if a.region == rid then A.at[a.node] else A.out[a.region]
				local pb = if b.region == rid then A.at[b.node] else A.out[b.region]
				if pa and pb and (a.region == rid or b.region == rid) then
					dots(group, pa, pb, C.gold, "Route")
				end
			end
			local last = path[#path]
			if goal then
				goalNode = if last.region == rid then last.node else "out:" .. last.region
			end
		end
		-- 그릴 것들: 장소들과 다른 지역들. 이름표는 내가 있는 곳 → 가야 할 곳 → 내 레벨의 사냥터 → 고른 곳 → 마을 · 쉼터 → 나머지의 차례로 자리를 잡는다
		local pins = {}
		for _, n in region.nodes do
			local at = A.at[n.id]
			if at then
				table.insert(pins, { id = n.id, x = at[1], y = at[2], r = MapWindow.PIN[n.kind] or 4, text = n.label, node = n, color = KIND[n.kind] or C.text })
			end
		end
		for to, at in A.out or {} do
			local other = WM.region(to)
			if other then
				table.insert(pins, { id = "out:" .. to, x = at[1], y = at[2], r = MapWindow.PIN.out, text = other.name, color = C.accent, out = to })
			end
		end
		local function rank(p): number
			if p.id == mine then
				return 1
			elseif p.id == goalNode then
				return 2
			elseif p.id == bestNode then
				return 3
			elseif p.id == picked then
				return 4
			elseif p.out or (p.node and (p.node.kind == "town" or p.node.kind == "village" or p.node.kind == "rest")) then
				return 5
			end
			return 6
		end
		local order = table.clone(pins)
		for i, p in order do
			p.w = Ui.measure(p.text)
			p.rank, p.at = rank(p), i
		end
		table.sort(order, function(a, b)
			if a.rank ~= b.rank then
				return a.rank < b.rank
			end
			return a.at < b.at
		end)
		local places = WM.placeLabels(order)
		for _, p in pins do
			local x, y, r = p.x, p.y, p.r
			if p.id == bestNode then
				ring(group, x, y, r + 3, C.green, "Best")
			end
			if p.id == mine then
				ring(group, x, y, r + 3, C.accent, "Here")
			end
			dot(group, x, y, r, p.color, "Pin_" .. p.id)
			-- ③ 퀘스트의 표시: 표시의 오른쪽 위에
			local mark = if p.node then marks[p.id] else nil
			if mark then
				local part = Kit.part(group, if mark == "?" then UI.questMark.done else UI.questMark.new, 0, 0)
				part.Position = UDim2.fromOffset(x + r, y - r - part.Size.Y.Offset + 2)
				part.Name = "Quest"
				part.ZIndex = 5
			end
			-- 이름표
			local rect = places[p.id]
			if rect then
				local color = if p.id == mine then C.accent elseif p.id == goalNode then C.gold elseif p.id == bestNode then C.green elseif p.id == picked then C.text elseif p.out then C.accent else C.dim
				plate(group, p.text, rect, color, "Name_" .. p.id)
			end
			-- ② 내가 있는 곳의 화살표(아래로 뾰족한 세 줄) — 이름표가 위에 놓였으면 그 위에
			if p.id == mine then
				local topY = y - r - 4
				if rect and rect.y + rect.h <= y and rect.x < x + 4 and rect.x + rect.w > x - 4 then
					topY = math.min(topY, rect.y - 1)
				end
				for i, wdt in { 5, 3, 1 } do
					Ui.box(group, x - math.floor(wdt / 2) - 1, topY - 8 + i * 2 - 1, wdt + 2, 3, C.ink).Name = "Arrow"
				end
				for i, wdt in { 5, 3, 1 } do
					Ui.box(group, x - math.floor(wdt / 2), topY - 8 + i * 2, wdt, 1, C.accent).Name = "Arrow"
				end
			end
			-- 누르면 고른다(표시와 이름표 어느 쪽을 눌러도)
			local zone = Ui.group(group, x - 9, y - 9, 19, 19, "Hit_" .. p.id)
			zone.ZIndex = 6
			Ui.hit(zone).Activated:Connect(function()
				picked = p.id
				view.refresh()
			end)
			if rect then
				local zone2 = Ui.group(group, rect.x, rect.y, rect.w, rect.h, "HitName_" .. p.id)
				zone2.ZIndex = 6
				Ui.hit(zone2).Activated:Connect(function()
					picked = p.id
					view.refresh()
				end)
			end
		end
		-- 오른쪽 글 칸: 고른 곳(없으면 내가 있는 곳 — 다른 지역을 보는 중이면 그 지역의 첫 장소)
		showSide(picked or mine or region.nodes[1].id)
		best:set(bestText)
		best:color(if bestNode then C.green else C.dim)
		goalTitle:set(if card then card.title else "지금 가야 할 곳이 없다")
		goalTitle:color(if card then C.gold else C.off)
		route:set(if card then card.text else "")
	end

	-- 내 상태가 올 때마다 불린다(사냥 중에는 자주) — 그림에 드러나는 것이 바뀌었을 때만 다시 그린다
	local last = ""
	function view.refresh()
		local me = ctx.me()
		local level = if me then me.level else 1
		local parts = { rid, tostring(picked), tostring(ctx.scene()), tostring(level) }
		local marks = WM.marks(rid, ctx.quests() or {}, level)
		for _, n in WM.region(rid).nodes do
			table.insert(parts, marks[n.id] or "-")
		end
		local card = WM.goalCard(ctx.quests() or {}, level, ctx.scene())
		table.insert(parts, if card then card.title .. card.text else "")
		local sig = table.concat(parts, "|")
		if sig ~= last then
			last = sig
			view.draw()
		end
	end

	function view.destroy()
		if layer then
			layer:Destroy()
			layer = nil
		end
	end
	return view
end

return MapWindow
