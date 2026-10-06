-- 미니맵 — 늘 보이는 화면의 왼쪽 위 칸(공방 「기본 · UI」 탭의 화면 배치 1번, data/ui.generated.luau의 hud.minimap).
--  어두운 판의 윗줄에 맵 이름, 그 아래에 줄인 맵: 땅과 발판, 문(파랑), 주민(노랑), 졸개(빨강), 나(흰 점 — 깜빡인다).
--  자리 셈은 shared/lune/ui/minimap.luau(자동 검사가 본다). 아직: Tab으로 크게 보기 · 파티원.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local G = require(lune.config.game)
local Layout = require(lune.ui.minimap)
local Kit = require(script.Parent.ui.kit)

local C = Kit.COLOR

local MiniMap = {}
MiniMap.MAP_H = UI.hud.minimap.h - Layout.TOP - Layout.BOTTOM
-- 맵 이름이 길면 상자가 오른쪽으로 늘어난다 — 보스 체력 칸의 왼쪽(4도트 띄고)까지
MiniMap.MAX_W = UI.hud.boss.x - UI.hud.minimap.x - 4

local function dot(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, z: number?): Frame
	local f = Kit.box(parent, x, y, w, h, color)
	f.ZIndex = z or 1
	return f
end

function MiniMap.init(root: Frame)
	local r = UI.hud.minimap
	local box = Kit.group(root, r.x, r.y, r.w, r.h)
	box.Name = "MiniMap"
	MiniMap.box = box
	MiniMap.back = Kit.part(box, "panel", 0, 0, r.w, r.h)
	Kit.part(box, "gem", 4, 4)
	MiniMap.name = Kit.text(box, "", Layout.NAME_X, 3, MiniMap.MAX_W - Layout.NAME_X - Layout.NAME_R)
	MiniMap.rule = Kit.box(box, Layout.SIDE, Layout.TOP - 1, r.w - Layout.SIDE * 2, 1, C.edgeDim)
	local map = Kit.box(box, Layout.SIDE, Layout.TOP, r.w - Layout.SIDE * 2, MiniMap.MAP_H, C.line)
	map.Name = "Map"
	map.ClipsDescendants = true
	MiniMap.map = map
	MiniMap.mobDots = {}
end

-- 장면이 바뀌면 다시 그린다
function MiniMap.setScene(scene)
	MiniMap.map:ClearAllChildren()
	table.clear(MiniMap.mobDots)
	MiniMap.name:set(scene.name)
	local r = UI.hud.minimap
	local boxW = Layout.boxFor(Kit.measure(scene.name), r.w, MiniMap.MAX_W)
	local mapW = boxW - Layout.SIDE * 2
	MiniMap.box.Size = UDim2.fromOffset(boxW, r.h)
	MiniMap.back.Size = UDim2.fromOffset(boxW, r.h)
	MiniMap.rule.Size = UDim2.fromOffset(mapW, 1)
	MiniMap.map.Size = UDim2.fromOffset(mapW, MiniMap.MAP_H)
	local L = Layout.layout(scene, mapW, MiniMap.MAP_H)
	MiniMap.layout = L
	local area = Kit.group(MiniMap.map, L.ox, L.oy, L.w, L.h)
	MiniMap.area = area
	for _, g in L.ground do
		dot(area, g.x, g.y, g.w, g.h, C.edgeDim)
	end
	for _, s in L.steps do
		dot(area, s.x, s.y, s.w, s.h, C.dim)
	end
	for _, n in scene.npcs or {} do
		local x, y = Layout.point(L, G.TILE, n.x, n.y)
		dot(area, x, math.max(0, y - 2), 2, 2, C.yellow, 2)
	end
	for _, p in scene.portals or {} do
		local x, y = Layout.point(L, G.TILE, p.x, p.y)
		dot(area, math.max(0, x - 1), math.max(0, y - 4), 2, 4, C.mp, 3)
	end
	MiniMap.me = dot(area, 0, 0, 2, 2, C.white, 5)
end

-- 나와 졸개의 자리. mobs = MobsView의 표(없어도 된다)
function MiniMap.update(heroX: number, heroY: number, mobs, now: number)
	local L = MiniMap.layout
	if not L then
		return
	end
	local x, y = Layout.point(L, G.TILE, heroX, heroY)
	MiniMap.me.Position = UDim2.fromOffset(math.clamp(x - 1, 0, L.w - 2), math.clamp(y - 2, 0, L.h - 2))
	MiniMap.me.BackgroundTransparency = if math.floor(now * 3) % 2 == 0 then 0 else 0.35
	if mobs then
		for id, m in mobs do
			local d = MiniMap.mobDots[id]
			local alive = m.state ~= "gone" and m.state ~= "dead"
			if alive then
				if not d then
					d = dot(MiniMap.area, 0, 0, 2, 2, C.hp, 4)
					MiniMap.mobDots[id] = d
				end
				local mx, my = Layout.point(L, G.TILE, m.x, m.info.y)
				d.Position = UDim2.fromOffset(math.min(mx, L.w - 2), math.max(0, my - 2))
				d.Visible = true
			elseif d then
				d.Visible = false
			end
		end
	end
end

function MiniMap.setTouch(on: boolean)
	-- 스마트폰에서도 같은 자리에 둔다(공방의 스마트폰 배치 17번)
end

return MiniMap
