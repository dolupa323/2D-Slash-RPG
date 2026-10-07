-- 장면 한 개를 그린다 — 하늘색, 멀리서 덜 따라오는 배경 층, 뒤에 놓인 것, 바닥, 주민, (졸개 · 주인공 자리).
--  맵에 놓는 물건은 모두 캐릭터 뒤다(앞에 놓는 것은 캐릭터를 가린다 — 사용자 2026-10-08. 장면 자료의 front는 늘 비어 있다).
--  장면의 갈래: 보통 맵(땅의 윗면이 늘 화면의 같은 높이) · tall(층이 있는 마을 — 카메라가 선 층을 따라 위아래로도 움직인다) · indoor(건물의 실내 — 한 화면, 방 그림 한 장).
--  자료는 shared/lune/data/scenes.generated.luau(공방에서 내보낸 그대로). 좌표는 도트. 놓인 것과 주민은 발밑 가운데가 (x, y)다.
--  이름표는 메이플처럼 발밑에 단다(주민 · 사람 · 몬스터). 그 자리를 내려고 땅의 윗면이 화면의 Kit.GROUND(150) 높이에 오게 장면을 올려 그린다.
--  이름표 · 문 위의 글은 글씨의 층(화면 틀의 고운 격자 — overlay.luau)에 그리고, 화면마다 제 자리(게임 세계의 도트)를 따라가게 한다. 머리 위의 퀘스트 표시(! · ?)는 게임 세계의 그림이다.
--  이름표 · 문 위의 글은 글씨의 층(화면 틀의 고운 격자 — overlay.luau)에 그리고, 화면마다 제 자리(게임 세계의 도트)를 따라가게 한다. 머리 위의 퀘스트 표시(! · ?)는 게임 세계의 그림이다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local G = require(lune.config.game)
local ASSETS = require(lune.data["assets.generated"])
local UI = require(lune.data["ui.generated"])
local SCENES = require(lune.data["scenes.generated"])
local Stage = require(script.Parent.stage)
local Kit = require(script.Parent.ui.kit)
local Ui = require(script.Parent.ui.ui)
local Overlay = require(script.Parent.overlay)

local C = Ui.COLOR

local SceneView = {}
SceneView.__index = SceneView
SceneView.TAG_DOWN = 4 -- 이름표: 발밑에서 이만큼 아래(화면 틀의 점)
-- 주민 머리 위의 퀘스트 표시: "!" 받을 수 있는 퀘스트가 있다 · "?" 다 해서 돌려줄 퀘스트가 있다 — 글자 그대로의 작은 표시(게임 세계의 굵은 도트).
--  사용자 2026-10-07: "퀘스트가 있는건 표시가 받을수있는퀘스트는 ! , 완료된퀘스트는 ? 표시였는데 왜 갑자기 전구모양이 생긴건지" → 전구 · 책 그림을 걷어 내고 되돌렸다.
--  부품 이름과 띄우는 높이는 공방에서 온다(data/ui.generated.luau의 questMark — 공방 시험 탭에서 먼저 보고 정한 것. "크기 너무 큽니다" → 피해 숫자만 한 점 글자).
SceneView.MARK = { ["!"] = UI.questMark.new, ["?"] = UI.questMark.done }
SceneView.MARK_UP = UI.questMark.up
SceneView.DOOR_MARK_UP = 9 -- 문 위의 퀘스트 표시: 문의 이름표(글씨 한 줄) 위로 이만큼(게임의 도트)

local function round(v: number): number
	return math.floor(v + 0.5)
end

local function hexColor(hex: string): Color3
	return Color3.fromRGB(tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16))
end

-- view = 게임 세계의 층 · tagLayer = 이름표의 층(화면 틀 — overlay)
function SceneView.new(view: Frame, key: string, scene, tagLayer: Frame)
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

	-- 이름표: 주민의 발밑에 구실과 이름(노랑), 문 위에 어디로 가는지(민트). 자리는 update가 화면마다 잡는다
	self.tags = {} -- { label, wx, wy(게임 세계의 자리), dy(거기서 화면 틀의 점으로 얼마나 아래) }
	self.tagRects = {} -- 주민 · 문의 이름표들의 자리 { x, y, w }(화면 틀의 점)
	local function tag(text: string, wx: number, wy: number, dy: number, color: Color3)
		local label = Ui.tag(tagLayer, text, color, 260)
		table.insert(self.tags, { label = label, wx = wx, wy = wy, dy = dy })
		return label
	end
	for _, npc in self.npcs do
		local n = npc.def
		npc.tag = tag(("%s %s"):format(n.role, n.name), n.x, n.y, SceneView.TAG_DOWN, C.gold)
		-- 퀘스트 표시: 머리 위의 ! (받을 수 있다) · ? (돌려줄 수 있다) — 게임 세계의 그림(굵은 도트)
		npc.mark = Kit.part(self.topLayer, SceneView.MARK["!"], 0, 0) -- 자리는 update가 잡는다(! 와 ? 의 폭이 다르다)
		npc.mark.Visible = false
		npc.mark.Name = "Mark_" .. n.id
		npc.mark.ZIndex = 6
	end
	-- 문 위의 퀘스트 표시: 그 문 안(건물의 실내)에 있는 주민에게 받을 · 돌려줄 퀘스트가 있으면 문 위에 ! · ? 를 띄운다 — 주민이 건물 안에 있어 밖에서는 머리 위의 표시가 보이지 않는다
	self.doorMarks = {}
	for _, p in scene.portals do
		tag("↑ " .. p.label, p.x, p.y - (p.h or 60), -(Ui.TAG_H + 2), C.accent)
		local dest = SCENES.scenes[p.to]
		if dest and dest.indoor and dest.npcs then
			local ids = {}
			for _, n in dest.npcs do
				table.insert(ids, n.id)
			end
			local mark = Kit.part(self.topLayer, SceneView.MARK["!"], 0, 0)
			mark.Visible = false
			mark.Name = "DoorMark_" .. p.to
			mark.ZIndex = 6
			table.insert(self.doorMarks, { portal = p, ids = ids, mark = mark })
		end
	end

	self.camX, self.camY = 0, 0
	self.camYf = nil -- 세로 카메라(소수까지) — 첫 update에서 주인공 자리로 잡는다
	self.lastClock = nil
	return self
end

-- 주인공 자리로 카메라를 맞추고(맵 끝에서 멈춘다), 배경 층과 주민을 고친다.
--  보통 맵: 세로는 따라가지 않는다 — 땅의 윗면이 늘 화면의 같은 높이(Kit.GROUND)에 온다. 뛸 때마다 화면이 출렁이지 않는다.
--  층이 있는 맵(scene.tall): 선 층의 발밑이 화면의 Kit.GROUND에 오게 부드럽게 따라간다 — 땅을 딛고 있을 때의 높이만 따르고(뛸 때마다 출렁이지 않게),
--   화면 밖으로 나가려 하면 바로 따라간다. 공방 시험 탭(luneTab.js의 followCam)과 같은 식이다.
function SceneView:update(heroX: number, heroY: number, clock: number, grounded: boolean?)
	local cx = round(math.clamp(heroX - G.VIEW_W / 2, 0, math.max(0, self.width - G.VIEW_W)))
	local cy = G.GROUND_Y - Kit.GROUND
	if self.scene.tall then
		local top = math.max(0, self.height - Kit.GROUND - (G.GROUND_Y - Kit.GROUND)) -- 카메라가 내려갈 수 있는 끝
		local dt = if self.lastClock then math.clamp(clock - self.lastClock, 0, 0.1) else 0
		self.lastClock = clock
		if not self.camYf then
			self.camYf = math.clamp(heroY - Kit.GROUND, 0, top)
		end
		local want = self.camYf
		if grounded then
			want = heroY - Kit.GROUND
		elseif heroY - self.camYf > G.VIEW_H - 36 then
			want = heroY - (G.VIEW_H - 36)
		elseif heroY - self.camYf < 48 then
			want = heroY - 48
		end
		want = math.clamp(want, 0, top)
		self.camYf += (want - self.camYf) * math.min(1, dt * (if grounded then 7 else 14))
		cy = round(self.camYf)
	end
	self.camX, self.camY = cx, cy
	self.world.Position = UDim2.fromOffset(-cx, -cy)
	Overlay.setCamera(cx, cy)
	for i, t in self.tags do
		local left, top = Overlay.x(t.wx) - math.floor(t.label.Width / 2), Overlay.y(t.wy) + t.dy
		t.label.Frame.Position = UDim2.fromOffset(left, top)
		local r = self.tagRects[i]
		if not r then
			r = {}
			self.tagRects[i] = r
		end
		r.x, r.y, r.w = left, top, t.label.Width
	end

	for _, layer in self.layers do
		local l = layer.def
		local ox = -(round(cx * l.f) % l.w)
		-- 층이 있는 맵 · 실내는 공방 시험 탭의 식 그대로(멀수록 세로로도 덜 따라온다 — 실내의 방 그림은 f = 0이라 화면에 붙어 있다)
		local oy = if self.scene.tall or self.scene.indoor then round(l.y - cy * l.f * 0.5) else l.y - cy
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
			local mw, mh = npc.mark.Size.X.Offset, npc.mark.Size.Y.Offset
			npc.mark.Position = UDim2.fromOffset(round(n.x - mw / 2), n.y - n.h - mh - SceneView.MARK_UP + (if math.floor(clock * 2 + i) % 2 == 0 then 0 else 1))
		end
	end
	-- 문 위의 퀘스트 표시: 문의 이름표 바로 위에서 같은 식으로 떠 있다
	for i, d in self.doorMarks do
		if d.mark.Visible then
			local p = d.portal
			local mw, mh = d.mark.Size.X.Offset, d.mark.Size.Y.Offset
			d.mark.Position = UDim2.fromOffset(round(p.x - mw / 2), p.y - (p.h or 60) - mh - SceneView.DOOR_MARK_UP + (if math.floor(clock * 2 + i) % 2 == 0 then 0 else 1))
		end
	end
end

-- 주민 · 문의 이름표들: { x(왼쪽), y(위), w, frame }(화면 틀의 점) — 자리는 update가 이미 잡았다. 겹칠 때 보일지는 boot가 정한다
function SceneView:tagList()
	for i, r in self.tagRects do
		r.frame = self.tags[i].label.Frame
	end
	return self.tagRects
end

-- 주민 머리 위의 퀘스트 표시를 고친다. markOf(주민 id) → "!" · "?" · nil
function SceneView:setMarks(markOf: (string) -> string?)
	for _, npc in self.npcs do
		local mark = markOf(npc.def.id)
		npc.markText = mark
		Kit.setPart(npc.mark, if mark then SceneView.MARK[mark] else nil)
		if npc.def.id == self.talking then
			npc.mark.Visible = false
		end
	end
	-- 문 위: 그 안의 주민들 가운데 돌려줄 것("?")이 있으면 그것을, 아니면 받을 것("!")을 보인다
	for _, d in self.doorMarks do
		local best: string? = nil
		for _, id in d.ids do
			local mark = markOf(id)
			if mark == "?" or (mark == "!" and best == nil) then
				best = mark
			end
		end
		Kit.setPart(d.mark, if best then SceneView.MARK[best] else nil)
	end
end

-- 말풍선이 떠 있는 주민의 표시는 그동안 숨긴다(말풍선이 그 자리에 뜬다). npcId = nil이면 다시 보인다
function SceneView:setTalking(npcId: string?)
	self.talking = npcId
	for _, npc in self.npcs do
		Kit.setPart(npc.mark, if npc.markText and npc.def.id ~= npcId then SceneView.MARK[npc.markText] else nil)
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
	for _, t in self.tags do
		t.label:Destroy()
	end
end

return SceneView
