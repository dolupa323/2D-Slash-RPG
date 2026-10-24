-- 명예의 전당의 비석에 새긴 순위(2026-10-15).
--  사용자: "명예의 전당이 상호작용해서 나오는 방식인데 그게 아니고 그냥 비석그림위에 비석에 새겨진것처럼 보여야합니다."
--  → 비석 앞에서 ↑로 창을 여는 것을 없애고(공방 items.js의 NPCDO에서 뺐다), 비석 면(scenes.generated의 npcs[].face — 방 그림에서 잰 도트)에
--    순위 · 이름 · 값을 돌에 판 글처럼 그린다: 어두운 글 + 한 점 아래의 밝은 테두리(새긴 홈에 빛이 걸린 모양). 들어설 때 서버에서 받고(Net "Rank") 30초마다 다시 받는다.
--  줄 수 = 비석 면의 높이에 들어가는 만큼(가장 많이 Rank.TOP). 이름은 폭을 넘으면 …로 줄인다.
--  2026-10-21: 명예의 전당의 비석을 넓혔고(면 81~82 x 60점 — 사용자 "닉네임 한글자부터 ... 처리 되버립니다"), 대영주의 성의 왼쪽 벽에 같은 순위 판 셋을 걸었다(scene의 npcs[].board · pad).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Net = require(lune.net.net)
local Rank = require(lune.sim.rank)
local Stage = require(script.Parent.stage)
local Overlay = require(script.Parent.overlay)
local Ui = require(script.Parent.ui.ui)

local M = Ui.M
local INK = Color3.fromRGB(46, 54, 66) -- 판 홈의 그늘(비석 면 #697b90보다 어둡게)
local LIGHT = Color3.fromRGB(150, 166, 184) -- 홈 아래쪽 가장자리에 걸린 빛
local PAD = 3 -- 비석 면 안쪽 여백(화면 틀의 점)
local REFRESH = 30 -- 다시 받는 사이(초)

local HallStones = {}
HallStones.fetch = function()
	return Net.Invoke("Rank")
end

local layer: Frame? = nil
local stones = {} -- { board, face, rows = { { no, name, value } } }
local boards = nil
local nextFetch = 0
local placedKey = ""
local gen = 0

local function engraved(parent: Instance, align: string?, width: number)
	local t = Ui.text(parent, "", 0, 0, width, { color = INK, align = align or "left" })
	if t.label.SetShadow then
		t.label:SetShadow(LIGHT)
	end
	return t
end

-- 그 장면에 들어섰다: 비석 면이 있는 비석마다 글을 만든다(없으면 아무것도 하지 않는다)
function HallStones.enter(scene, parent: Instance)
	HallStones.leave()
	local list = {}
	for _, n in scene.npcs or {} do
		if n.stone and typeof(n.face) == "table" then
			table.insert(list, n)
		end
	end
	if #list == 0 then
		return
	end
	gen += 1
	layer = Stage.group(parent, "HallStones", 5)
	for _, n in list do
		-- board = 새길 순위판(대영주의 성의 판처럼 이름표가 hall_가 아니면 board로 — 2026-10-21) · pad = 면 안쪽 여백(얇은 판은 1)
		local st = { board = n.board or string.match(n.id, "^hall_(%a+)$") or "level", face = n.face, pad = n.pad or PAD, rows = {} }
		for i = 1, Rank.TOP do
			st.rows[i] = { no = engraved(layer, "right", 14), name = engraved(layer, "left", 120), value = engraved(layer, "right", 60) }
		end
		table.insert(stones, st)
	end
	boards, nextFetch, placedKey = nil, 0, ""
end

-- 곧 다시 받는다(만렙 최초 달성 — 레벨 판의 1위가 바뀌었다, 2026-10-24)
function HallStones.soon()
	nextFetch = 0
end

function HallStones.leave()
	gen += 1
	if layer then
		layer:Destroy()
		layer = nil
	end
	stones = {}
	boards = nil
end

-- 매 화면: 때가 되면 순위를 받고, 화면 틀이 바뀌었으면 다시 놓는다
function HallStones.update()
	if not layer then
		return
	end
	local now = os.clock()
	if now >= nextFetch then
		nextFetch = now + REFRESH
		local my = gen
		task.spawn(function()
			local ok, got = pcall(HallStones.fetch)
			if ok and got and my == gen then
				boards = got
				placedKey = "" -- 글을 다시 적는다
			end
		end)
	end
	local key = ("%d:%d:%d:%d:%s"):format(Stage.uiW, Stage.uiH, Overlay.camX, Overlay.camY, tostring(boards ~= nil))
	if key == placedKey then
		return
	end
	placedKey = key
	for _, st in stones do
		-- face = 방 그림의 자리(실내의 방 그림은 화면에 붙은 층이다 — 카메라를 따라가지 않는다): 화면의 점 = 그림의 점. 세계의 자리로 바꾸려면 카메라를 더한다
		local cx, cy = Overlay.camX, Overlay.camY
		local pad = st.pad
		local x0, y0 = Overlay.x(st.face[1] + cx) + pad, Overlay.y(st.face[2] + cy) + pad + 1
		local x1, y1 = Overlay.x(st.face[3] + 1 + cx) - pad, Overlay.y(st.face[4] + 1 + cy) - pad
		local w = x1 - x0
		local fit = math.clamp(math.floor((y1 - y0) / M.smallLine), 0, Rank.TOP) -- 면에 들어가는 줄
		local list = boards and boards[st.board] or {}
		local valueW = 0
		for i = 1, fit do
			local it = list[i]
			if it then
				valueW = math.max(valueW, Ui.measure(it.value))
			end
		end
		for i, row in st.rows do
			local it = list[i]
			local on = i <= fit and it ~= nil
			row.no:show(on)
			row.name:show(on)
			row.value:show(on)
			if on then
				local y = y0 + (i - 1) * M.smallLine
				row.no:set(tostring(i))
				row.no:move(x0 - 2, y)
				row.value:set(it.value)
				row.value.width = valueW
				row.value:move(x1 - valueW, y)
				local nameX = x0 + 15
				local nameW = math.max(10, w - 15 - valueW - 4)
				row.name.label:SetMaxWidth(nameW, 1)
				row.name.width = nameW
				row.name:set(it.name)
				row.name:move(nameX, y)
			end
		end
	end
end

return HallStones
