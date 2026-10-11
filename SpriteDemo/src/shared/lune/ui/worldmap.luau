-- 월드맵의 셈 — 화면을 모르는 셈이다(그리는 것은 client/lune/ui/mapWindow.luau · 자동 검사가 그대로 부른다).
--  메이플스토리의 월드맵 · 길라잡이처럼: 그 지역의 맵들이 길로 이어진 그림에서 ① 내가 있는 곳 ② 맵마다의 레벨과 몬스터 ③ 퀘스트를 받을 곳(!) · 돌려줄 곳(?) ④ 내 레벨에 맞는 사냥터를 알려 준다.
--  자료는 data/worldmap.generated.luau(공방 js/lune/design/journey.js의 그림) · 맵의 몬스터와 주민은 data/scenes.generated.luau.
local D = require(script.Parent.Parent.data["worldmap.generated"])
local SCENES = require(script.Parent.Parent.data["scenes.generated"])
local COMBAT = require(script.Parent.Parent.data["combat.generated"])
local Quests = require(script.Parent.Parent.sim.quests)

local WM = {}
WM.data = D
WM.order = D.order
-- 그림으로 된 지도(client/lune/ui/mapWindow.luau): 그림의 크기 · 오른쪽 글 칸의 폭과 줄 수
WM.ART_W, WM.ART_H = D.artSize.w, D.artSize.h
WM.SIDE_W = 190
WM.SIDE = { mobLines = 2, npcLines = 2, routeLines = 2 }
WM.PIN = { town = 5, village = 5, rest = 4, hunt = 4, road = 3, climb = 4, dead = 3, boss = 4, out = 5 } -- 표시의 반지름(가운데에서 가장자리까지 — 점). out = 다른 지역
WM.PLATE = { padX = 4, h = 14, gap = 3 } -- 이름표: 글의 양옆 여백 · 높이 · 표시와의 사이

-- 그림이 있는 지역들(탭의 차례) — 그림이 없는 지역은 월드맵에 나오지 않는다
function WM.arted(): { string }
	local out = {}
	for _, rid in D.order do
		if D.regions[rid].art then
			table.insert(out, rid)
		end
	end
	return out
end

-- 마디를 이름표로 찾는 표: [지역][마디] = 마디
local byId = {}
for rid, region in D.regions do
	byId[rid] = {}
	for i, n in region.nodes do
		byId[rid][n.id] = n
		n.order = i
	end
end

function WM.region(rid: any)
	return if typeof(rid) == "string" then D.regions[rid] else nil
end

function WM.node(rid: string, id: string)
	return byId[rid] and byId[rid][id]
end

-- 그 장면이 어느 지역의 어느 마디인가. 마디에 없는 장면(가게 · 사당 같은 실내 · 숨은 방)은 문을 따라 가장 가까운 마디다. 못 찾으면 nil
local nodeCache = {}
function WM.nodeOf(sceneKey: any): (string?, string?)
	if typeof(sceneKey) ~= "string" or not SCENES.scenes[sceneKey] then
		return nil, nil
	end
	local hit = nodeCache[sceneKey]
	if hit ~= nil then
		if hit == false then
			return nil, nil
		end
		return hit.region, hit.node
	end
	local seen = { [sceneKey] = true }
	local queue, at = { sceneKey }, 1
	local found = nil
	while queue[at] do
		local key = queue[at]
		at += 1
		if D.sceneNode[key] then
			found = D.sceneNode[key]
			break
		end
		local next = {}
		for _, p in SCENES.scenes[key].portals or {} do
			if SCENES.scenes[p.to] and not seen[p.to] then
				seen[p.to] = true
				table.insert(next, p.to)
			end
		end
		table.sort(next) -- 차례가 늘 같게
		for _, k in next do
			table.insert(queue, k)
		end
	end
	nodeCache[sceneKey] = found or false
	if found then
		return found.region, found.node
	end
	return nil, nil
end

-- 그 마디의 몬스터 레벨(가장 낮은 · 가장 높은). 몬스터가 없으면 nil
function WM.levels(node): (number?, number?)
	local lo, hi = nil, nil
	for _, key in node.scenes do
		for _, m in SCENES.scenes[key].mobs or {} do
			lo = if lo then math.min(lo, m.lv) else m.lv
			hi = if hi then math.max(hi, m.lv) else m.lv
		end
	end
	return lo, hi
end

-- 「Lv.14~15」 · 한 레벨이면 「Lv.9」 · 몬스터가 없으면 빈 글
function WM.levelText(node): string
	local lo, hi = WM.levels(node)
	if not lo then
		return ""
	end
	return if lo == hi then ("Lv.%d"):format(lo) else ("Lv.%d~%d"):format(lo, hi :: number)
end

-- 그 마디에 나오는 몬스터의 이름들(겹치지 않게, 맵의 차례대로)
function WM.mobNames(node): { string }
	local out, seen = {}, {}
	for _, key in node.scenes do
		for _, m in SCENES.scenes[key].mobs or {} do
			local def = COMBAT.mobs[m.kind]
			local name = if def then def.name else m.kind
			if not seen[name] then
				seen[name] = true
				table.insert(out, name)
			end
		end
	end
	return out
end

-- 그 지역의 마디마다 서 있는 주민: [마디] = { [주민 id] = 이름 } — 실내의 주민은 그 건물이 선 마디에 든다
local npcCache = {}
function WM.npcs(rid: string)
	if npcCache[rid] then
		return npcCache[rid]
	end
	local out = {}
	for key, sc in SCENES.scenes do
		if sc.npcs and #sc.npcs > 0 then
			local r, id = WM.nodeOf(key)
			if r == rid and id then
				out[id] = out[id] or {}
				for _, n in sc.npcs do
					if not n.stone then -- 비석(명예의 전당)은 주민이 아니다
						out[id][n.id] = n.name
					end
				end
			end
		end
	end
	npcCache[rid] = out
	return out
end

-- 그 마디의 주민 이름들(가나다 차례)
function WM.npcNames(rid: string, nodeId: string): { string }
	local out = {}
	for _, name in WM.npcs(rid)[nodeId] or {} do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

-- 퀘스트의 표시: [마디] = "?"(돌려줄 것이 있다) · "!"(받을 것이 있다). 그 지역의 마디만.
--  돌려줄 것 = 다 한 퀘스트를 돌려받는 주민이 선 마디 · 받을 것 = 지금 받을 수 있는 퀘스트를 주는 주민이 선 마디(그 퀘스트를 하는 맵에서 가장 가까운 곳)
function WM.marks(rid: string, book, level: number): { [string]: string }
	local out = {}
	local npcs = WM.npcs(rid)
	for _, def in Quests.list do
		local state = Quests.state(book, level, def.id)
		if state == "ready" then
			for nodeId, set in npcs do
				if set[def.endNpc] then
					out[nodeId] = "?"
				end
			end
		elseif state == "open" and not def.auto then
			local key = Quests.giverScene(def)
			local r, nodeId = WM.nodeOf(key)
			if r == rid and nodeId and out[nodeId] ~= "?" then
				out[nodeId] = "!"
			end
		end
	end
	return out
end

-- 내 레벨에 맞는 사냥터(그 지역에서): 몬스터의 가장 낮은 레벨이 내 레벨을 넘지 않는 마디 가운데 그 레벨이 가장 높은 것 — 같으면 그림의 차례가 앞선 것.
--  모두 내 레벨보다 높으면 가장 낮은 마디. 사냥터가 없는 지역이면 nil
function WM.recommend(rid: string, level: number): string?
	local region = D.regions[rid]
	if not region then
		return nil
	end
	local best, bestLo, lowest, lowestLo = nil, -1, nil, math.huge
	for _, n in region.nodes do
		local lo = WM.levels(n)
		if lo then
			if lo <= level and lo > bestLo then
				best, bestLo = n.id, lo
			end
			if lo < lowestLo then
				lowest, lowestLo = n.id, lo
			end
		end
	end
	return best or lowest
end

-- ---------- 다른 지역으로 이어지는 곳 ----------
-- 그 지역의 마디에서 문 하나로 다른 지역의 마디에 닿는 것들: { { node, to(지역), toNode } … } — 그림의 차례, 같은 마디면 탭의 차례.
--  예: 초승 고개의 수비대 야영지 → 은달 항구(성문 거리) · 은달 항구의 부두 → 수정 숲(반달 나루) · 물마루 바다(물마루 마을)
local exitCache = {}
function WM.exits(rid: string)
	if exitCache[rid] then
		return exitCache[rid]
	end
	local out, seen, rank = {}, {}, {}
	for i, id in D.order do
		rank[id] = i
	end
	local region = D.regions[rid]
	for _, n in (if region then region.nodes else {}) do
		for _, key in n.scenes do
			for _, p in SCENES.scenes[key].portals or {} do
				local to = D.sceneNode[p.to]
				if to and to.region ~= rid and not seen[n.id .. ">" .. to.region] then
					seen[n.id .. ">" .. to.region] = true
					table.insert(out, { node = n.id, to = to.region, toNode = to.node })
				end
			end
		end
	end
	table.sort(out, function(a, b)
		local na, nb = byId[rid][a.node].order, byId[rid][b.node].order
		if na ~= nb then
			return na < nb
		end
		return rank[a.to] < rank[b.to]
	end)
	exitCache[rid] = out
	return out
end

-- 그 마디에서 이어지는 다른 지역들(없으면 빈 표)
function WM.exitsOf(rid: string, nodeId: string)
	local out = {}
	for _, ex in WM.exits(rid) do
		if ex.node == nodeId then
			table.insert(out, ex)
		end
	end
	return out
end

-- 마디 아래에 적는 줄들(그림): 짧은 이름 · 몬스터의 레벨(있으면) · 이어지는 지역마다 「→ 은달 항구」. { { text, kind = "name" | "level" | "exit", exit? } … }
WM.ROWS_MAX = 3 -- 그림의 아래 여백이 세 줄까지 받는다(자동 검사 28이 본다)
function WM.rows(rid: string, node)
	local rows = { { text = node.label, kind = "name" } }
	local lv = WM.levelText(node)
	if lv ~= "" then
		table.insert(rows, { text = lv, kind = "level" })
	end
	for _, ex in WM.exitsOf(rid, node.id) do
		table.insert(rows, { text = "→ " .. D.regions[ex.to].name, kind = "exit", exit = ex })
	end
	return rows
end

-- ---------- 가는 길 ----------
-- 장면에서 장면까지 문을 가장 적게 지나는 길(장면의 이름표들 — 처음과 끝을 넣어). 같은 수면 문이 놓인 차례가 앞선 쪽. 닿지 않으면 nil
function WM.path(from: any, to: any): { string }?
	if typeof(from) ~= "string" or typeof(to) ~= "string" or not SCENES.scenes[from] or not SCENES.scenes[to] then
		return nil
	end
	local prev = { [from] = from }
	local queue, at = { from }, 1
	while queue[at] and not prev[to] do
		local key = queue[at]
		at += 1
		for _, p in SCENES.scenes[key].portals or {} do
			if SCENES.scenes[p.to] and not prev[p.to] then
				prev[p.to] = key
				table.insert(queue, p.to)
			end
		end
	end
	if not prev[to] then
		return nil
	end
	local out = { to }
	while out[1] ~= from do
		table.insert(out, 1, prev[out[1]])
	end
	return out
end

-- 그 길이 지나는 마디들: { { region, node } … } — 이어서 같은 마디는 한 번만(실내 · 여러 층은 한 마디다). 닿지 않으면 nil
function WM.route(from: any, to: any)
	local path = WM.path(from, to)
	if not path then
		return nil
	end
	local out = {}
	for _, key in path do
		local r, n = WM.nodeOf(key)
		local last = out[#out]
		if r and n and (not last or last.region ~= r or last.node ~= n) then
			table.insert(out, { region = r, node = n })
		end
	end
	return out
end

-- 가는 길의 글: 지금 있는 마디의 다음부터 끝까지의 이름을 「→」로 잇는다 — 「성문 거리 → 달맞이 광장 → … → 부두 → 반달 나루」.
--  네 곳을 넘으면 앞의 하나 · … · 뒤의 둘만(오른쪽 글 칸의 두 줄에 들어가게 — 길 자체는 그림 위의 금빛 점줄이 보여 준다). 이미 그 마디에 있으면 빈 글
WM.ROUTE_MAX = 4
function WM.routeText(route): string
	if not route then
		return ""
	end
	local names = {}
	for i = 2, #route do
		local n = WM.node(route[i].region, route[i].node)
		table.insert(names, n.label)
	end
	if #names > WM.ROUTE_MAX then
		names = { names[1], "…", names[#names - 1], names[#names] }
	end
	return table.concat(names, " → ")
end

-- 지금 가야 할 곳의 한 줄(월드맵의 맨 아래 줄): 「「고갯길」 받으러 가는 길: 달그림자 사냥터 → 세 갈래 길 → …」 · 그 맵에 이미 있으면 「「고갯길」 — 지금 있는 맵에서 받는다」.
--  돌려주는 것: 글, 길(마디들 — 그림이 그 길을 금빛으로 칠한다), 갈 곳(goal). 갈 곳이 없으면 빈 글과 nil
local GOAL_WORD = { ["do"] = "하러", back = "돌려주러", take = "받으러" }
local GOAL_HERE = { ["do"] = "한다", back = "돌려준다", take = "받는다" }
function WM.goalText(goal, sceneKey: any): (string, any)
	local route = WM.route(sceneKey, goal.scene)
	if not route or #route == 0 then
		return "", nil
	end
	if #route == 1 then
		return ("「%s」 — 지금 있는 맵에서 %s"):format(goal.def.name, GOAL_HERE[goal.kind]), route
	end
	return ("「%s」 %s 가는 길: %s"):format(goal.def.name, GOAL_WORD[goal.kind], WM.routeText(route)), route
end
function WM.goalLine(book, level: number, sceneKey: any): (string, any, any)
	local goal = Quests.goal(book, level)
	if not goal then
		return "", nil, nil
	end
	local text, route = WM.goalText(goal, sceneKey)
	return text, route, goal
end

-- 내 레벨에 맞는 사냥터의 한 줄(월드맵의 셋째 줄). 돌려주는 것: 글, 그 마디(이름을 풀빛으로 칠한다 — 권할 것이 없으면 nil)
--  그 지역의 사냥터가 모두 내 레벨보다 높으면 권하지 않고 「이 지역의 사냥터는 Lv.47부터(갯바위 해변)」라고만 적는다. 사냥터가 없는 지역(은달 항구)이면 빈 글
function WM.recommendLine(rid: string, level: number): (string, string?)
	local id = WM.recommend(rid, level)
	local n = id and WM.node(rid, id)
	if not n then
		return "", nil
	end
	local lo = WM.levels(n)
	if lo and lo > level then
		return ("이 지역의 사냥터는 Lv.%d부터(%s)"):format(lo, n.name), nil
	end
	return ("Lv.%d에 맞는 사냥터: %s(%s)"):format(level, n.name, WM.levelText(n)), id
end

-- 내 레벨에 맞는 사냥터를 오른쪽 글 칸의 한 줄로: 「굽잇길 Lv.14~15」 — 그 지역이 모두 내 레벨보다 높으면 「Lv.47부터(갯바위 해변)」. 돌려주는 것: 글, 그 마디(권할 것이 없으면 nil)
function WM.recommendShort(rid: string, level: number): (string, string?)
	local id = WM.recommend(rid, level)
	local n = id and WM.node(rid, id)
	if not n then
		return "", nil
	end
	local lo = WM.levels(n)
	if lo and lo > level then
		return ("Lv.%d부터(%s)"):format(lo, n.label), nil
	end
	return ("%s %s"):format(n.label, WM.levelText(n)), id
end

-- 그 지역의 몬스터 레벨의 폭(「Lv.1~26」 — 오른쪽 글 칸의 머리줄). 몬스터가 없으면 빈 글
function WM.regionLevels(rid: string): string
	local lo, hi = nil, nil
	for _, n in D.regions[rid].nodes do
		local a, b = WM.levels(n)
		if a then
			lo = if lo then math.min(lo, a) else a
			hi = if hi then math.max(hi, b :: number) else b
		end
	end
	return if lo then ("Lv.%d~%d"):format(lo, hi :: number) else ""
end

-- 장소 하나를 고르면 오른쪽 글 칸에 적는 것: { name(이름), sub(「사냥터 · Lv.14~15」), mobs(「폭탄병 · 바위 산양」), npcs(「주모 달래 · 반달」) }
function WM.card(rid: string, nodeId: string)
	local n = WM.node(rid, nodeId)
	if not n then
		return { name = "", sub = "", link = "", mobs = "", npcs = "" }
	end
	local lv = WM.levelText(n)
	local kind = D.kinds[n.kind] or n.kind
	return {
		name = n.name,
		sub = if lv ~= "" then ("%s · %s"):format(kind, lv) else kind,
		link = WM.linkText(rid, nodeId),
		mobs = table.concat(WM.mobNames(n), " · "),
		npcs = table.concat(WM.npcNames(rid, nodeId), " · "),
	}
end

-- 그 장소에서 다른 지역으로 가는 문이 있으면 한 줄: 「은달 항구로 가는 포탈이 있다」(없으면 빈 글)
function WM.linkText(rid: string, nodeId: string): string
	local names = {}
	for _, ex in WM.exitsOf(rid, nodeId) do
		table.insert(names, D.regions[ex.to].name)
	end
	return if #names > 0 then ("%s로 가는 포탈이 있다"):format(table.concat(names, " · ")) else ""
end

-- 그림 위의 다른 지역(은달 항구)을 골랐을 때 오른쪽 글 칸에 적는 것: { name, sub(「다른 지역」), link(「수비대 야영지의 포탈로 간다」), mobs = "", npcs = "" }
function WM.outCard(rid: string, to: string)
	local from = {}
	for _, ex in WM.exits(rid) do
		if ex.to == to then
			table.insert(from, WM.node(rid, ex.node).label)
		end
	end
	return {
		name = D.regions[to].name,
		sub = "다른 지역",
		link = if #from > 0 then ("%s의 포탈로 간다"):format(table.concat(from, " · ")) else "",
		mobs = "",
		npcs = "",
	}
end

-- 이름표를 놓는다(화면을 모르는 셈 — 그림 위에서 서로, 그리고 표시와 겹치지 않게): 차례대로 아래 → 위 → 오른쪽 → 왼쪽을 대 보고 처음 맞는 자리에.
--  items = { { id, x, y, r(표시의 반지름), w(글의 폭) } … }(앞선 것이 먼저 자리를 잡는다). 돌려주는 것: [id] = { x, y, w, h }(놓을 자리가 없으면 그 이름은 빠진다)
function WM.placeLabels(items)
	local P = WM.PLATE
	local taken = {}
	for _, it in items do
		table.insert(taken, { it.x - it.r - 2, it.y - it.r - 2, it.x + it.r + 2, it.y + it.r + 2 }) -- 표시들
	end
	local function free(x: number, y: number, w: number, h: number): boolean
		if x < 1 or y < 1 or x + w > WM.ART_W - 1 or y + h > WM.ART_H - 1 then
			return false
		end
		for _, t in taken do
			if x < t[3] and x + w > t[1] and y < t[4] and y + h > t[2] then
				return false
			end
		end
		return true
	end
	local out = {}
	for _, it in items do
		local w, h = it.w + P.padX * 2, P.h
		local cx = it.x - math.floor(w / 2)
		-- 대 보는 자리의 차례: 바로 아래 · 바로 위(가운데 → 오른쪽으로 · 왼쪽으로 반씩 민 것) → 오른쪽 · 왼쪽(가운데 → 아래로 · 위로 민 것) → 한 줄 더 떨어진 아래 · 위
		local below, above = it.y + it.r + P.gap, it.y - it.r - P.gap - h
		local half, quarter = math.floor(w / 2) - it.r, math.floor(w / 4)
		local right, left = it.x + it.r + P.gap + 1, it.x - it.r - P.gap - 1 - w
		local mid = it.y - math.floor(h / 2)
		local tries = {
			{ cx, below }, { cx, above },
			{ cx + quarter, below }, { cx - quarter, below }, { cx + quarter, above }, { cx - quarter, above },
			{ cx + half, below }, { cx - half, below }, { cx + half, above }, { cx - half, above },
			{ right, mid }, { left, mid },
			{ right, mid + it.r + 3 }, { left, mid + it.r + 3 }, { right, mid - it.r - 3 }, { left, mid - it.r - 3 },
			{ cx, below + h + 1 }, { cx, above - h - 1 },
			{ cx + half, below + h + 1 }, { cx - half, below + h + 1 }, { cx + half, above - h - 1 }, { cx - half, above - h - 1 },
		}
		for _, t in tries do
			-- 옆으로 조금 밀어도 된다(그림의 가장자리에 붙은 마을)
			local x = math.clamp(t[1], 1, WM.ART_W - 1 - w)
			if free(x, t[2], w, h) then
				out[it.id] = { x = x, y = t[2], w = w, h = h }
				table.insert(taken, { x - 1, t[2] - 1, x + w + 1, t[2] + h + 1 })
				break
			end
		end
	end
	return out
end

-- 지금 가야 할 곳을 오른쪽 글 칸에 두 토막으로: title(「「고갯길」 받으러」) · text(가는 길의 이름들 — 그 맵에 있으면 「지금 있는 맵에서 받는다」).
--  갈 곳이 없으면 nil. route = 그 길의 마디들(그림이 금빛 점줄을 잇는다) · goal
local CARD_WORD = { ["do"] = "하러", back = "돌려주러", take = "받으러" }
local CARD_HERE = { ["do"] = "지금 있는 맵에서 한다", back = "지금 있는 맵에서 돌려준다", take = "지금 있는 맵에서 받는다" }
function WM.goalCardOf(goal, sceneKey: any)
	local route = WM.route(sceneKey, goal.scene)
	if not route or #route == 0 then
		return nil
	end
	return {
		title = ("「%s」 %s"):format(goal.def.name, CARD_WORD[goal.kind]),
		text = if #route == 1 then CARD_HERE[goal.kind] else WM.routeText(route),
		route = route,
		goal = goal,
	}
end
function WM.goalCard(book, level: number, sceneKey: any)
	local goal = Quests.goal(book, level)
	return if goal then WM.goalCardOf(goal, sceneKey) else nil
end

-- 마디 하나를 고르면 아래에 적는 두 줄: 「굽잇길 · 사냥터 · Lv.14~15」 / 「폭탄병 · 고갯길 염소」(주민이 있으면 「주민: 달래 · 반달」)
function WM.info(rid: string, nodeId: string): (string, string)
	local n = WM.node(rid, nodeId)
	if not n then
		return "", ""
	end
	local head = { n.name, D.kinds[n.kind] or n.kind }
	local lv = WM.levelText(n)
	if lv ~= "" then
		table.insert(head, lv)
	end
	local parts = {}
	local mobs = WM.mobNames(n)
	if #mobs > 0 then
		table.insert(parts, table.concat(mobs, " · "))
	end
	local people = WM.npcNames(rid, nodeId)
	if #people > 0 then
		table.insert(parts, "주민: " .. table.concat(people, " · "))
	end
	return table.concat(head, " · "), table.concat(parts, " / ")
end

return WM
