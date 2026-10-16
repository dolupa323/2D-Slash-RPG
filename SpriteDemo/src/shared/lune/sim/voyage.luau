-- 탈것 — 배 · 비행선(공방 js/lune/design/city.js의 VOYAGE · 2026-10-16).
--  사용자 2026-10-16: "왜 대도시로 넘어갈때 배타는건 구현을 안합니까 왜 그냥 포탈이에요" → 포탈 대신 사람(선장 · 뱃사공 · 승강장 일꾼)에게 말을 걸어 오른다.
--  사용자가 고른 것: 「배 위에서 시간을 보낸다 — 갑판 맵(배는 서 있고 바다 · 하늘이 흘러간다)에서 잠깐 → 닿는 곳에 내린다 · 돌아올 때도 같은 탈것」 · 같은 밤
--   「부두의 배 — 물마루 마을 · 꼭대기의 비행선 — 등불 포구도 타고 가는 탈것으로」 · 시간은 "배타는 시간 더 짧게 10초정도".
--  routes = { { id, from = 떠나는 장면, npc = 말을 거는 사람, kind = "ship" | "airship", ship = 갑판의 장면, to = 닿는 장면, at = 내리는 자리(칸 · 줄 — 없으면 그 사람 곁),
--             dest = 닿는 곳의 이름, need = 그 퀘스트를 끝내야 태운다(마을 → 항구: 1편의 마지막 「불타는 마을」), lines = 오를 때의 말, locked = 못 태울 때의 말 } … }
--  시간을 재고 내려 주는 것은 서버(world.luau의 onSail · tick). 화면도 서버도 모르는 순수한 셈이다
local lune = script.Parent.Parent
local D = require(lune.data["city.generated"]).voyage
local Quests = require(script.Parent.quests)

local Voyage = {}
Voyage.DATA = D
Voyage.ROUTES = D.routes

-- 그 장면에서 그 사람(없으면 아무나)에게 말을 걸어 떠나는 탈것(없으면 nil)
function Voyage.route(scene: any, npc: any)
	if typeof(scene) ~= "string" then
		return nil
	end
	for _, r in D.routes do
		if r.from == scene and (npc == nil or r.npc == npc) then
			return r
		end
	end
	return nil
end
-- 그 장면에서 떠나는 탈것 모두
function Voyage.routesFrom(scene: any): { any }
	local out = {}
	for _, r in D.routes do
		if r.from == scene then
			table.insert(out, r)
		end
	end
	return out
end
-- 탈것에 태워 주는 사람인가(선장 · 뱃사공 · 승강장 일꾼 — 갑판 위에서는 말만 한다)
function Voyage.isCrew(npc: any): boolean
	for _, r in D.routes do
		if r.npc == npc then
			return true
		end
	end
	return false
end
-- 그 장면이 갑판인가 → 그 탈것의 길 · 떠난 장면
function Voyage.onShip(scene: any): (any, string?)
	if typeof(scene) ~= "string" then
		return nil, nil
	end
	for _, r in D.routes do
		if r.ship == scene then
			return r, r.from
		end
	end
	return nil, nil
end
-- 이 탈것을 탈 수 있는가(need가 있으면 그 퀘스트를 끝낸 뒤 — 돌아오는 길은 늘 탄다)
function Voyage.open(book, r): boolean
	if not r then
		return false
	end
	if r.need then
		return Quests.finished(book or {}, r.need)
	end
	return true
end
-- 「{dest}까지 n초」
function Voyage.leftText(r, left: number): string
	return (string.gsub(string.gsub(D.words.left, "{dest}", r.dest), "{n}", tostring(math.max(0, math.ceil(left)))))
end

return Voyage
