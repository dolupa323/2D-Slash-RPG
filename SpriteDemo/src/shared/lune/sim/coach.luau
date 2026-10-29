-- 역마차(2026-10-26 — 공방 js/lune/design/journey.js의 COACH → data/worldmap.generated.luau의 coach).
--  사용자: "마을판정인곳이 엄청 많잖아 그럼 그 마을이랑 마을 사이를 이동할수있는 수단이 필요 … 메이플 스토리 택시처럼 배로 가야하는곳은 택시로 못가고 …
--   같은 대륙 판정인곳 안에서 택시로 왔다갔다 … 이 세계관에서는 택시라는 게 아니여야".
--  정류장(마을 · 길 위의 쉼터)에서 같은 땅의 다른 정류장으로 간다. 같은 땅 = 문(portals)으로 걸어서 이어진 장면들 — 배 · 비행선으로만 닿는 곳(물마루 마을 쪽)은 따로 묶인다.
--  삯 = base + 거쳐 가는 맵 수(문을 지나는 수) x step. 화면도 서버도 쓰는 순수한 셈이다(옮기는 것은 서버 world.luau의 onCoach)
local lune = script.Parent.Parent
local SCENES = require(lune.data["scenes.generated"])
local D = require(lune.data["worldmap.generated"]).coach

local Coach = {}
Coach.DATA = D
Coach.WORDS = D.words

local isStation = {}
for _, key in D.stations do
	isStation[key] = true
end

-- 걸어서 닿는 거리(문을 지나는 수): from에서 모든 장면까지 — 처음 물을 때 한 번 센다
local hops = {}
local function hopsFrom(from: string)
	local got = hops[from]
	if got then
		return got
	end
	got = { [from] = 0 }
	local todo, head = { from }, 1
	while head <= #todo do
		local key = todo[head]
		head += 1
		local sc = SCENES.scenes[key]
		for _, p in (sc and sc.portals) or {} do
			local to = p.to and (SCENES.base(p.to) or p.to)
			if to and SCENES.scenes[to] and got[to] == nil then
				got[to] = got[key] + 1
				table.insert(todo, to)
			end
		end
	end
	hops[from] = got
	return got
end

-- 그 장면이 정류장인가(파티마다 따로 든 방이면 그 맵으로 본다)
function Coach.isStation(scene: any): boolean
	return typeof(scene) == "string" and isStation[SCENES.base(scene) or scene] == true
end

-- from에서 to로 가는 삯(못 가면 nil — 정류장이 아니다 · 같은 곳 · 걸어서 이어지지 않았다)
function Coach.fare(from: any, to: any): number?
	if not Coach.isStation(from) or not Coach.isStation(to) then
		return nil
	end
	from, to = SCENES.base(from) or from, SCENES.base(to) or to
	if from == to then
		return nil
	end
	local n = hopsFrom(from)[to]
	if n == nil then
		return nil
	end
	return D.fare.base + n * D.fare.step
end

-- from에서 갈 수 있는 정류장들 { scene, name, fare } — 정류장 목록의 차례대로
function Coach.from(from: any): { any }
	local out = {}
	for _, key in D.stations do
		local f = Coach.fare(from, key)
		if f then
			table.insert(out, { scene = key, name = SCENES.scenes[key].name, fare = f })
		end
	end
	return out
end

-- 그 정류장에 내리는 자리: 그 맵의 시작 자리
function Coach.spot(scene: string): (number, number)
	local sc = SCENES.scenes[scene]
	return sc.spawn.x, sc.spawn.y
end

return Coach
