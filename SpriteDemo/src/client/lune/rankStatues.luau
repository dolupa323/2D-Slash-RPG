-- 마을의 랭킹 석상(2026-11-03 사용자 "마을에 랭킹 1,2,3 등 석상 만들자 말걸면 멋진말 나오고").
--  장면의 주민 가운데 statue(순위)가 적힌 것(그림 없는 주민 — 이름표와 말만: 공방 design/town.js의 TOWNMAP.statues · 초승달 마을 명예의 전당 앞)의 자리에
--  받침대(1위 금 · 2위 은 · 3위 동 — Codex 그림을 점으로 옮긴 것: 캐릭터 그림판 plinth1 ~ 3 · 공방 tools/build_lune_statue.py)를 놓고, 그 위에
--  Lv.150에 오른 차례로 박제된 그 사람(Net "Rank"의 statues — 서버 world.luau World.statueRows: 1위 처음 만렙 · 2 · 3위 만렙 열 사람의 기록. 레벨 판이 아니다 —
--   2026-11-12 사용자 "석상은 150레벨때 찍은 순서대로 랭킹 1,2,3등이 박제되는거야 … 석상사람이 바뀌면 안되지")의 직업 캐릭터를 돌로 세운다: 캐릭터 그림판 stone_<직업>(서 있는 첫 장을 밝은 돌 다섯 색으로
--   다시 칠한 것 — 공방 tools/build_lune_statue.py. 그림 위에 색을 곱하면 청록 · 분홍이 비쳐 유령처럼 보여서 따로 둔다).
--  이름표 = 「레벨 n위 그 사람의 이름」(순위가 비면 설계의 이름 「석상」 · 받침대만). 들어설 때 받고 REFRESH초마다 다시 받는다.
--  층 = 맵 틀 안 포탈 그림 위 · 주민 · 몬스터 · 캐릭터 뒤(맵의 소품처럼 — 사람을 가리지 않는다). 자리 · 돌의 색 · 바라보는 쪽은 제가 정한 것
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Net = require(lune.net.net)
local CHARS = require(lune.data["chars.generated"])
local UI = require(lune.data["ui.generated"]) -- statueNamed = 석상에 선 사람마다의 말(2026-11-05)
local Sprite = require(script.Parent.sprite)
local Stage = require(script.Parent.stage)

local RankStatues = {}
RankStatues.Z = 28 -- 맵 틀 안의 차례: 포탈(22) · 이펙트 뒤 판(25) 위 · 주민(30) · 몬스터(40) · 캐릭터(50) 뒤
local REFRESH = 60 -- 다시 받는 사이(초)

local layer: Frame? = nil
local list = {} -- { npc, n, base = 받침대, top = 받침대 윗면의 높이(발밑에서), who = 지금 세운 직업, figure = 돌 석상, name }
local gen = 0
local nextFetch = 0

-- 그 장면에 들어섰다: statue가 적힌 주민마다 받침대를 놓는다(없으면 아무것도 하지 않는다). view = sceneView
function RankStatues.enter(view)
	RankStatues.leave()
	local found, rocks = {}, {}
	for _, npc in view.npcs or {} do
		if npc.def.statue then
			table.insert(found, npc)
		elseif typeof(npc.def.rock) == "string" then
			table.insert(rocks, npc)
		end
	end
	if #found == 0 and #rocks == 0 then
		return
	end
	gen += 1
	layer = Stage.group(view.world, "Statues", RankStatues.Z)
	-- 석상이 될 뻔한 돌(2026-11-07 사용자: "랭킹석상 옆에 약간 찌그러진 돌 추가하고 말걸면 석상이 될뻔한 돌이다. 이렇게 나오게해줘"):
	--  그림 없는 주민 가운데 rock(그림의 이름 — 공방 town.js TOWNMAP.statueRock · tools/build_lune_statue.py의 statue_rock)이 적힌 것의 자리에 그 돌을 놓는다(말은 주민의 말 그대로 · 순위와 상관없다)
	for _, npc in rocks do
		local n = npc.def
		if CHARS.chars[n.rock] then
			Sprite.new(layer :: Frame, n.rock, 1):set("idle", 1, n.x, n.y, -1) -- (-1 = 그린 그대로)
		end
	end
	for _, npc in found do
		local n = npc.def
		local key = "plinth" .. tostring(n.statue)
		local c = CHARS.chars[key]
		local base = nil
		if c then
			base = Sprite.new(layer :: Frame, key, 1)
			base:set("idle", 1, n.x, n.y, -1) -- (-1 = 그린 그대로 — 캐릭터 그림판은 왼쪽을 보는 그림이라 1이면 뒤집는다)
		end
		table.insert(list, { npc = npc, n = n, base = base, top = if c then c.oy else 0 })
	end
	nextFetch = 0
end

function RankStatues.leave()
	gen += 1
	if layer then
		layer:Destroy()
		layer = nil
	end
	list = {}
end

-- 곧 다시 받는다(만렙 최초 달성 — 레벨 판의 1위가 바뀌었다)
function RankStatues.soon()
	nextFetch = 0
end

-- 한 석상을 그 사람(row = { name, class } — Lv.150에 오른 차례의 기록 · 없으면 nil)으로 세운다
local function stand(s, row)
	local who = if row and typeof(row.class) == "string" and CHARS.chars["stone_" .. row.class] then "stone_" .. row.class else nil
	if s.who ~= who then
		if s.figure then
			s.figure:destroy()
			s.figure = nil
		end
		s.who = who
		if who and layer then
			local n = s.n
			s.figure = Sprite.new(layer, who, 2)
			s.figure:set("idle", 1, n.x, n.y - s.top, n.dir or 1) -- 받침대의 윗면에 선다
		end
	end
	local name = if row and typeof(row.name) == "string" and row.name ~= "" then row.name else s.n.name
	if s.name ~= name and s.npc.tag then
		s.name = name
		s.npc.tag:SetText(("%s %s"):format(s.n.role, name))
	end
	-- 그 사람만의 말(2026-11-05 — 공방 ui.js STATUE_NAMED · 강타 「무언가를 지키러 떠났다…」): 말을 걸 때마다 그 줄들 가운데 하나(ui/talk.luau의 pickLines). 없으면 순위의 말
	local pool = row and typeof(row.name) == "string" and UI.statueNamed and UI.statueNamed[row.name]
	s.npc.pickLines = if pool and #pool > 0 then function()
		return { pool[math.random(1, #pool)] }
	end else nil
end

-- 매 화면: 때가 되면 레벨 판을 받는다
function RankStatues.update()
	if not layer then
		return
	end
	local now = os.clock()
	if now < nextFetch then
		return
	end
	nextFetch = now + REFRESH
	local my = gen
	task.spawn(function()
		local ok, got = pcall(Net.Invoke, "Rank")
		if not ok or typeof(got) ~= "table" or my ~= gen then
			return
		end
		local rows = if typeof(got.statues) == "table" then got.statues else {} -- (레벨 판 got.level이 아니다 — 2026-11-12)
		for _, s in list do
			local row = rows[s.n.statue]
			stand(s, if typeof(row) == "table" then row else nil)
		end
	end)
end

return RankStatues
