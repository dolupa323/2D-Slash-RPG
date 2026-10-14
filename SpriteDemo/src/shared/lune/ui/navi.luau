-- 퀘스트 길찾기의 셈 — 화면을 모르는 셈(그리는 것은 client/lune/naviArrow.luau · 단추는 client/lune/questHud.luau).
--  사용자 2026-10-13: "우측상단 퀘스트 ui에 각각 퀘스트마다  간단한 화살표 버튼 생기게해서  그 버튼 누르면  길찾기 되면서 가야하는 방향 캐릭터 머리위에 화살표로 알려주는 기능 추가하세요
--   진행도마다 정확하게 되어야합니다.  만약에 아이템을 줍는 퀘스트라면  사냥을 해야할때는 그 해당 사냥터로  만약에 그 아이템을 모두 파밍했다면  완료해야하는 장소를 안내해주고 정확하게 해야합니다."
--  ① 어디로 가야 하는가(target) — 그 퀘스트의 지금 진행에 따라:
--      아직 받지 않았다 = 주는 주민 · 하는 중(잡기 · 모으기가 남았다) = 그 사냥터의 그 몬스터 · 살펴보기 = 그 자리 · 다 했다 = 돌려줄 주민
--      일일 의뢰: 잡는 중 = 그 사냥터 · 다 잡았다 = 의뢰 게시판
--  ② 어느 문으로 가는가(path) — 장면의 문을 따라 가장 적게 지나는 길(퀘스트로 열리는 문은 열렸을 때만)
--  ③ 지금 어느 쪽인가(aim · dir) — 다른 맵이면 다음 문, 그 맵이면 주민 · 자리 · 가장 가까운 그 몬스터를 겨눈다
--  ④ 그 맵 안에서 거기까지 어떻게 가는가(naviMesh.luau) — 발판을 따라 실제로 갈 수 있는 길의 첫 걸음을 가리킨다.
--      사용자 2026-10-13: "올라가는 발판은 왼쪽에있는데 위에 있는 포탈은 오른쪽에 있으니까 오른쪽으로 가라고 화살표가 방향을 안내하잖아요 이거 말이 안되는거에요"
--      (처음에는 겨눈 자리의 가로만 보고 왼쪽 · 오른쪽을 가리켰다 — 위층의 문 아래 벽 앞에서 헤맸다)
local lune = script.Parent.Parent
local SCENES = require(lune.data["scenes.generated"])
local Quests = require(lune.sim.quests)
local Daily = require(lune.sim.daily)
local Mesh = require(script.Parent.naviMesh) -- 그 맵의 발판과 건너가는 길(화살표가 맵을 알고 가리킨다)

local Navi = {}
Navi.NEAR_X = 20 -- 이 안이면 가로로는 다 왔다(위 · 아래를 가리킨다)
Navi.NEAR_Y = 14
Navi.MOB_NEAR = { x = 72, y = 44 } -- 그 몬스터가 이만큼 안에 있으면 화살표를 거둔다(다 왔다 — 싸우는 중이다)
Navi.TAKE_NEAR = 40 -- 뛸 자리가 이만큼 안이면 「그 자리로 간다」가 아니라 뛰는 방향을 가리킨다(게임의 도트)
Navi.KEEP = 48 -- 겨누던 몬스터를 그대로 겨누는 폭: 다른 몬스터가 이만큼 넘게 더 가까워져야 바꾼다
local stick = { mob = nil :: any } -- 지금 겨누는 몬스터

-- 알리미의 줄 하나를 가리키는 이름표: 퀘스트 = 그 이름표 · 일일 의뢰 = "daily:지역:차례"
function Navi.dailyKey(region: string, i: number): string
	return ("daily:%s:%d"):format(region, i)
end

-- 어디로 가야 하는가: { scene, kind = "npc" | "hunt" | "spot", npc?, mob?, x?, y? } — 안내할 것이 없으면 nil(끝낸 퀘스트 · 아직 못 받는 퀘스트 · 받지 않은 의뢰)
function Navi.target(key: any, book, level: number, daily: any)
	if typeof(key) ~= "string" then
		return nil
	end
	local region, index = string.match(key, "^daily:(%w+):(%d+)$")
	if region then
		local view = daily and daily.boards and daily.boards[region]
		local t = view and view.tasks[tonumber(index) :: number]
		local board = Daily.DATA.boards[region]
		if not t or not board or t.st ~= Daily.ON then
			return nil
		elseif Daily.isReady(t) then
			return { scene = board.scene, kind = "npc", npc = board.npc }
		end
		return { scene = t.scene, kind = "hunt", mob = t.mob }
	end
	local def = Quests.def(key)
	if not def then
		return nil
	end
	local st = book and book[key]
	if st and st.done then
		return nil
	elseif not st then
		if Quests.state(book or {}, level, key) ~= "open" then
			return nil
		end
		local scene = Quests.giverScene(def)
		return if scene then { scene = scene, kind = "npc", npc = def.giver } else nil
	elseif Quests.isReady(book, key) then
		local scene = Quests.endScene(def)
		return if scene then { scene = scene, kind = "npc", npc = def.endNpc } else nil
	end
	for i, step in def.steps do
		if (st.c[i] or 0) < step.n then
			if step.type == "use" then
				return { scene = def.scene, kind = "spot", x = step.x, y = step.y }
			end
			return { scene = def.scene, kind = "hunt", mob = step.mob, only = step.only == true }
		end
	end
	return nil
end

-- 문을 따라 가는 길: { 지금 장면, 다음 장면, … 가는 장면 } — 닿지 못하면 nil. 퀘스트로 열리는 문(need)은 그 퀘스트를 받았을 때만 지난다
function Navi.path(from: any, to: any, book): { string }?
	if not SCENES.scenes[from] or not SCENES.scenes[to] then
		return nil
	end
	local prev = { [from] = from }
	local queue, at = { from }, 1
	while queue[at] do
		local key = queue[at]
		at += 1
		if key == to then
			local out = { key }
			while key ~= from do
				key = prev[key]
				table.insert(out, 1, key)
			end
			return out
		end
		for _, p in SCENES.scenes[key].portals or {} do
			if SCENES.scenes[p.to] and prev[p.to] == nil and Quests.portalOpen(book, p) then
				prev[p.to] = key
				table.insert(queue, p.to)
			end
		end
	end
	return nil
end

-- 지금 겨눌 자리: x, y, 무엇("portal" | "npc" | "spot" | "mob" | "here"), 그 문(다른 맵으로 갈 때) — 길이 없으면 nil
--  mobs = 지금 맵에 서 있는 몬스터들 { { kind, x, y } … }(화면이 준다 — 살아 있는 것만) · x · y = 내 자리
function Navi.aim(sceneKey: string, x: number, y: number, target, book, mobs: any)
	-- 사냥하러 가는 길인데 지금 맵에도 그 몬스터가 산다: 여기서 잡는다(어느 맵에서 잡든 그 몬스터면 센다 — sim/quests.luau)
	local here = target.scene == sceneKey
	if not here and target.kind == "hunt" and not target.only then
		for _, m in SCENES.scenes[sceneKey].mobs or {} do
			here = here or m.kind == target.mob
		end
	end
	if not here then
		local path = Navi.path(sceneKey, target.scene, book)
		if not path or not path[2] then
			return nil
		end
		for _, p in SCENES.scenes[sceneKey].portals do
			if p.to == path[2] and Quests.portalOpen(book, p) then
				return p.x, p.y, "portal", p
			end
		end
		return nil
	end
	if target.kind == "npc" then
		for _, n in SCENES.scenes[sceneKey].npcs or {} do
			if n.id == target.npc then
				return n.x, n.y, "npc", nil
			end
		end
		return nil
	elseif target.kind == "spot" then
		return target.x, target.y, "spot", nil
	end
	-- 사냥터에 왔다: 가장 가까운 그 몬스터(없으면 — 다시 나오기를 기다린다 — 그 자리)
	--  한 번 겨눈 몬스터는 살아 있는 동안 그대로 겨눈다(다른 것이 KEEP점 넘게 더 가까워지기 전에는) — 둘이 비슷한 거리에서 오가면 화살표가 이쪽저쪽으로 흔들린다
	local best, bd, kept, kd = nil, math.huge, nil, math.huge
	for _, m in mobs or {} do
		if m.kind == target.mob then
			local d = math.abs(m.x - x) + math.abs(m.y - y) * 2 -- 다른 층의 것은 멀게 친다
			if d < bd then
				best, bd = m, d
			end
			if m == stick.mob then
				kept, kd = m, d
			end
		end
	end
	if kept and kd <= bd + Navi.KEEP then
		best = kept
	end
	stick.mob = best
	if best then
		return best.x, best.y, "mob", nil
	end
	return x, y, "here", nil
end

-- 화살표의 방향: "left" | "right" | "up" | "down" | "enter"(문 · 주민 · 자리 앞이다 — ↑를 누른다) | "none"(다 왔다)
function Navi.dir(x: number, y: number, ax: number, ay: number, what: string): string
	local dx, dy = ax - x, ay - y
	if what == "here" then
		return "none"
	elseif what == "mob" and math.abs(dx) <= Navi.MOB_NEAR.x and math.abs(dy) <= Navi.MOB_NEAR.y then
		return "none"
	end
	if math.abs(dx) > Navi.NEAR_X then
		return if dx < 0 then "left" else "right"
	elseif dy < -Navi.NEAR_Y then
		return "up"
	elseif dy > Navi.NEAR_Y then
		return "down"
	end
	return if what == "mob" then "none" else "enter"
end

-- 한 번에: 그 줄(key)의 길찾기가 지금 가리키는 방향과 겨눈 자리. 안내할 것이 없으면(끝났다 · 길이 없다) nil
--  dir = 화살표의 방향 · edge = 발판을 건너가는 첫 걸음(같은 발판이거나 맵을 아직 다 못 쟀으면 nil) · mapped = 맵을 알고 가리킨 것인가
--  내가 공중에 떠 있을 때는(선 발판이 없다) 맵을 아는 셈을 못 한다 — 부르는 쪽(boot)이 땅에 있을 때의 방향을 그대로 둔다
function Navi.arrow(key: any, sceneKey: string, x: number, y: number, book, level: number, daily: any, mobs: any)
	local target = Navi.target(key, book, level, daily)
	if not target then
		return nil
	end
	local ax, ay, what, portal = Navi.aim(sceneKey, x, y, target, book, mobs)
	if not ax then
		return nil
	end
	local dir = Navi.dir(x, y, ax, ay, what)
	local out = { dir = dir, x = ax, y = ay, what = what, portal = portal, target = target, edge = nil, mapped = false }
	if dir == "none" then
		return out
	end
	-- 맵을 알고 가리킨다: 겨눈 자리의 발판까지 가는 길의 첫 걸음
	local edge = Mesh.route(sceneKey, x, y, ax, ay)
	if edge == "same" then
		out.mapped = true
		-- 같은 발판: 가로로 간다(다 왔으면 문 · 주민 앞 — 위의 셈 그대로. 날아다니는 몬스터처럼 겨눈 자리가 발판보다 높을 뿐이면 위 · 아래를 가리키지 않는다)
		if dir == "up" or dir == "down" then
			out.dir = if what == "mob" then "none" else "enter"
		end
	elseif edge then
		out.mapped, out.edge = true, edge
		out.dir = Mesh.dirOf(sceneKey, x, y, edge)
		-- 뛸 자리가 코앞이면(TAKE_NEAR 안) 그 자리로 가는 몇 걸음이 아니라 뛰는 방향을 가리킨다.
		--  사용자 2026-10-13(달그림자 사냥터에서 마을로 돌아가는 길 — 화면을 보이며): "왼쪽으로 포탈타고 가야하는데 갑자기  오른쪽으로 가르키는건  길안내로직이 이게 도대체 어떻게 돌아가는거죠?"
		--   가는 길(왼쪽 포탈)은 맞게 셈했는데, 위의 발판으로 뛸 자리가 열두 점 오른쪽이라 「오른쪽」을 가리켰다 — 화살표는 가는 방향으로 읽힌다. 멀리 돌아가야 할 때만 그쪽을 가리킨다
		if edge.kind ~= "walk" and not Mesh.at(edge, x) and math.abs(edge.x - x) <= Navi.TAKE_NEAR then
			out.dir = Mesh.actDir(sceneKey, y, edge)
		end
	end
	return out
end

-- 그 맵의 발판과 길을 조금씩 잰다(그리는 고리가 길찾기를 켠 동안 장마다 부른다 — 한 번에 다 재면 화면이 잠깐 멈춘다). 다 쟀으면 true
Navi.MESH_BUDGET = 6 -- 한 장에 재는 자리의 수(한 자리에 1ms쯤)
function Navi.prepare(sceneKey: string, budget: number?): boolean
	return Mesh.work(sceneKey, budget or Navi.MESH_BUDGET)
end

return Navi
