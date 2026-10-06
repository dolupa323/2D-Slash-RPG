-- 장면 한 개를 그린다 — 하늘색, 멀리서 덜 따라오는 배경 층, 뒤에 놓인 것, 바닥, 주민, (졸개 · 주인공 자리), 앞에 놓인 것.
--  자료는 shared/lune/data/scenes.generated.luau(공방에서 내보낸 그대로). 좌표는 도트. 놓인 것과 주민은 발밑 가운데가 (x, y)다.
--  이름표는 메이플처럼 발밑에 단다(주민 · 사람 · 몬스터). 그 자리를 내려고 땅의 윗면이 화면의 Kit.GROUND(150) 높이에 오게 장면을 올려 그린다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local G = require(lune.config.game)
local ASSETS = require(lune.data["assets.generated"])
local Stage = require(script.Parent.stage)
local Kit = require(script.Parent.ui.kit)

local C = Kit.COLOR

local SceneView = {}
SceneView.__index = SceneView
SceneView.TAG_DOWN = 3 -- 이름표: 발밑에서 이만큼 아래
-- 주민 머리 위의 퀘스트 표시: "!" 줄 것이 있다(전구) · "?" 돌려줄 것이 다 됐다(책)
SceneView.MARK = { ["!"] = "bulb", ["?"] = "book_done" }

local function round(v: number): number
	return math.floor(v + 0.5)
end

local function hexColor(hex: string): Color3
	return Color3.fromRGB(tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16))
end

function SceneView.new(view: Frame, key: string, scene)
	local self = setmetatable({}, SceneView)
	self.key = key
	self.scene = scene
	self.width = scene.w * G.TILE
	self.height = scene.h * G.TILE
	view.BackgroundColor3 = hexColor(scene.sky)

	local root = Stage.group(view, "Scene_" .. key, 1)
	self.root = root

	-- 배경 층: 그림을 가로로 이어 붙여 화면을 채운다(멀수록 덜 따라온다)
	self.layers = {}
	for i, l in scene.layers do
		local holder = Stage.group(root, "Layer" .. i, i)
		local copies = math.ceil(G.VIEW_W / l.w) + 1
		local labels = {}
		for c = 1, copies do
			labels[c] = Stage.image(holder, "Tile" .. c, ASSETS[l.img] or "", l.w, l.h)
		end
		self.layers[i] = { def = l, labels = labels }
	end

	-- 맵 틀: 카메라만큼 통째로 민다
	local world = Stage.group(root, "World", 10)
	world.Size = UDim2.fromOffset(self.width, self.height)
	self.world = world
	local back = Stage.group(world, "Back", 10)
	local ground = Stage.group(world, "Ground", 20)
	self.npcLayer = Stage.group(world, "Npcs", 30)
	self.mobLayer = Stage.group(world, "Mobs", 40)
	self.heroLayer = Stage.group(world, "Heroes", 50)
	self.fxLayer = Stage.group(world, "Fx", 55)
	local front = Stage.group(world, "Front", 60)
	self.topLayer = Stage.group(world, "Top", 70) -- 이름표 · 피해 숫자처럼 모든 것 위에 뜨는 것

	local function put(holder: Frame, list)
		local sheet = ASSETS[scene.props] or ""
		for i, p in list do
			local r = scene.rects[p.id]
			if r then
				local label = Stage.image(holder, p.id .. i, sheet, r.w, r.h)
				label.ImageRectOffset = Vector2.new(r.x, r.y)
				label.ImageRectSize = Vector2.new(r.w, r.h)
				label.Position = UDim2.fromOffset(round(p.x - r.w / 2), p.y - r.h)
			end
		end
	end
	put(back, scene.back)
	put(front, scene.front)

	for i, g in scene.ground do
		local label = Stage.image(ground, "Ground" .. i, ASSETS[g.img] or "", g.w, g.h)
		label.Position = UDim2.fromOffset(g.x, 0)
	end
	-- 장면을 올려 그려서 화면 아래에 남는 데는 땅속 색으로 메운다
	local deep = Kit.box(ground, 0, self.height, self.width, G.VIEW_H, hexColor(scene.deep or scene.sky))
	deep.Name = "Deep"

	-- 주민: 그림판의 가로 칸 = 누구, 세로 칸 = 서 있는 동작 두 장
	self.npcs = {}
	if scene.npcs then
		local nw, nh = scene.npcCell[1], scene.npcCell[2]
		for i, n in scene.npcs do
			local label = Stage.image(self.npcLayer, n.id, ASSETS[scene.npcSheet] or "", nw, nh)
			label.Position = UDim2.fromOffset(round(n.x - nw / 2), n.y - nh)
			self.npcs[i] = { def = n, label = label, nw = nw, nh = nh, shown = "" }
		end
	end

	-- 이름표: 주민의 발밑에 구실과 이름(노랑), 문 위에 어디로 가는지(민트)
	self.tagRects = {} -- 움직이지 않는 이름표들의 자리 { x, y, w } — 사람들의 이름표가 이것을 피해 쌓인다
	local function tag(text: string, x: number, y: number, color: Color3)
		local label = Kit.tag(self.topLayer, text, color, 120)
		local left = round(x - label.Width / 2)
		label.Frame.Position = UDim2.fromOffset(left, y)
		table.insert(self.tagRects, { x = left, y = y, w = label.Width })
		return label
	end
	for _, npc in self.npcs do
		local n = npc.def
		npc.tag = tag(("%s %s"):format(n.role, n.name), n.x, n.y + SceneView.TAG_DOWN, C.npc)
		-- 퀘스트 표시: 머리 위에 전구(줄 것이 있다)나 책(돌려줄 것이 다 됐다)
		npc.mark = Kit.icon(self.topLayer, nil, round(n.x - Kit.ICON / 2), n.y - n.h - Kit.ICON - 3)
		npc.mark.Name = "Mark_" .. n.id
		npc.mark.ZIndex = 6
	end
	for _, p in scene.portals do
		tag("↑ " .. p.label, p.x, p.y - (p.h or 60) - Kit.TAG_H - 2, C.mint)
	end

	self.camX, self.camY = 0, 0
	return self
end

-- 주인공 자리로 카메라를 맞추고(맵 끝에서 멈춘다), 배경 층과 주민을 고친다.
--  세로는 따라가지 않는다: 땅의 윗면이 늘 화면의 같은 높이(Kit.GROUND)에 온다 — 뛸 때마다 화면이 출렁이지 않는다.
function SceneView:update(heroX: number, _heroY: number, clock: number)
	local cx = round(math.clamp(heroX - G.VIEW_W / 2, 0, math.max(0, self.width - G.VIEW_W)))
	local cy = G.GROUND_Y - Kit.GROUND
	self.camX, self.camY = cx, cy
	self.world.Position = UDim2.fromOffset(-cx, -cy)

	for _, layer in self.layers do
		local l = layer.def
		local ox = -(round(cx * l.f) % l.w)
		local oy = l.y - cy
		for c, label in layer.labels do
			label.Position = UDim2.fromOffset(ox + (c - 1) * l.w, oy)
		end
	end

	-- 주민: 가까이 오면 주인공 쪽을 본다(그림은 오른쪽을 본다)
	for i, npc in self.npcs do
		local n = npc.def
		local dir = n.dir
		if math.abs(n.x - heroX) < 70 and heroX ~= n.x then
			dir = if heroX > n.x then 1 else -1
		end
		local frame = math.floor(clock * 1.6 + (i - 1) * 0.4) % 2
		local key = dir .. ":" .. frame
		if npc.shown ~= key then
			npc.shown = key
			local x, y = n.cell * npc.nw, frame * npc.nh
			if dir >= 0 then
				npc.label.ImageRectOffset = Vector2.new(x, y)
				npc.label.ImageRectSize = Vector2.new(npc.nw, npc.nh)
			else
				npc.label.ImageRectOffset = Vector2.new(x + npc.nw, y)
				npc.label.ImageRectSize = Vector2.new(-npc.nw, npc.nh)
			end
		end
		-- 퀘스트 표시는 천천히 위아래로 떠 있다
		if npc.mark.Visible then
			npc.mark.Position = UDim2.fromOffset(round(n.x - Kit.ICON / 2), n.y - n.h - Kit.ICON - 3 + (if math.floor(clock * 2 + i) % 2 == 0 then 0 else 1))
		end
	end
end

-- 사람들의 이름표가 피해 가야 하는 자리들: 주민 · 문의 이름표
function SceneView:rects()
	return self.tagRects
end

-- 주민 머리 위의 퀘스트 표시를 고친다. markOf(주민 id) → "!" · "?" · nil
function SceneView:setMarks(markOf: (string) -> string?)
	for _, npc in self.npcs do
		local mark = markOf(npc.def.id)
		npc.markText = mark
		Kit.setIcon(npc.mark, if mark then SceneView.MARK[mark] else nil)
	end
end

-- 주인공 가까이에 있는 주민(없으면 nil)
function SceneView:npcNear(x: number, y: number)
	local best, bestD = nil, 30
	for _, npc in self.npcs do
		local d = math.abs(npc.def.x - x)
		if d < bestD and math.abs(npc.def.y - y) < 24 then
			best, bestD = npc.def, d
		end
	end
	return best
end

-- 주인공 가까이에 있는 문(없으면 nil)
function SceneView:portalNear(x: number, y: number)
	for _, p in self.scene.portals do
		-- 문 가운데에서 26도트 안(서버는 28까지 받는다). 맵 끝의 문은 벽에 붙어 서서도 들어갈 수 있어야 한다 — 16으로 두었더니 벽까지 달려간 뒤에는 들어가지 못했다
		if math.abs(p.x - x) < 26 and math.abs(p.y - y) < 4 then
			return p
		end
	end
	return nil
end

function SceneView:destroy()
	self.root:Destroy()
end

return SceneView
