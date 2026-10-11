-- 직업 묶음(shared/lune/kits/<직업>.luau)의 찾아보기 — 공방 시험 탭의 js/lune/skills.js(KITS).
--  직업 묶음 = { tone, toggle, icons, 고리들(init · tick · onHit · mult · haste · chargeMax … · draw · drawBack · drawMarks · drawBind), calls(서버가 정해 화면에 알리는 것), procs, skills }
--  스킬 = { id, key, air, ground, segs = { 구간 } } 또는 바로 걸리는 것 { id, key, instant = true, cast(g) }
--  구간 = { clip, from, to, fps, loopFrom, needPress, float, walk, turn, trail, loop + dur · hold(min · max) · charge(per) · till(g),
--           start(g) · finish(g) · every = { 초, fn(g) } · ev = { [장 번호] = fn(g) } }
--  여기서 덧붙이는 것: kit.who(직업) · kit.byId[스킬] · 구간마다 evs(장 번호 차례로 늘어놓은 { 장, fn } — 같은 걸음에 여러 장이 지나가도 차례대로 터진다)
local kits = script.Parent.kits

local Kits = {
	axion = require(kits.axion),
	riven = require(kits.riven),
	reaper = require(kits.reaper),
	mooni = require(kits.mooni),
	salamander = require(kits.salamander),
}

local SKILL = {} -- [스킬] = 직업 묶음
for who, kit in Kits do
	kit.who = who
	kit.byId = {}
	for _, skill in kit.skills do
		kit.byId[skill.id] = skill
		SKILL[skill.id] = kit
		for _, seg in skill.segs or {} do
			local evs = {}
			for frame, fn in seg.ev or {} do
				table.insert(evs, { frame, fn })
			end
			table.sort(evs, function(a, b)
				return a[1] < b[1]
			end)
			seg.evs = evs
		end
	end
end

local Kitset = {}
Kitset.kits = Kits

function Kitset.of(who: string)
	return Kits[who]
end

-- 그 스킬이 든 직업 묶음과 스킬(없으면 nil)
function Kitset.skill(id: string)
	local kit = SKILL[id]
	if kit then
		return kit.byId[id], kit
	end
	return nil, nil
end

return Kitset
