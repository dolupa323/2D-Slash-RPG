--!strict
-- 스토리 보스의 패턴에서 서버(sim/room.luau의 stepBoss)와 화면(client/lune/bossView.luau · mobsView.luau)이 똑같이 세야 하는 것 — 자리와 시간.
--  서버는 「지금 무슨 패턴의 어느 때인가」(상태 · 패턴의 차례 · 흐른 시간 · 겨눈 자리 · 연속기)만 보낸다. 표시된 자리들이 어디인지, 뛰어오른 몸이 지금 얼마나 떠 있는지는 양쪽이 여기서 같은 식으로 센다.
--  자료 = data/combat.generated.luau의 mobs[보스].story.patterns(공방 design/bosses.js의 STORYBOSS_NEXT) · 시험 탭 luneTab.js의 stepStory · beginPattern과 같은 셈이다.
local BossPat = {}

local WALL = 32 -- 방의 양 끝(벽 두 칸)

-- 방의 안쪽(가로): 표시된 자리들이 놓이는 범위
function BossPat.bounds(scene): (number, number)
	return WALL, scene.w * 16 - WALL
end

-- 예고 · 굳어 있는 시간: 연속기(chain) 안에서는 quick배로 줄어든다(굳는 시간은 0.25초 아래로 줄지 않는다 · 내달리기는 굳는 시간이 없다)
function BossPat.tell(p, quick: number?): number
	return p.tell * (quick or 1)
end
function BossPat.act(p, quick: number?): number
	return if p.dash then 0 else math.max(0.25, p.act * (quick or 1))
end

-- 표시된 자리들(spots): { { x, wait } … } — wait = 예고가 끝난 뒤 그 자리가 터지기까지 더 기다리는 시간(초)
--  aim = 'grid': 방 전체에 gap 간격 — 짝수 자리는 바로, 홀수 자리는 lag초 뒤(두 번에 나눠 터진다. 자리를 바꿔 서서 피한다)
--  aim = 'hero': 겨눈 사람의 발밑(aim — 방 안으로 당긴다)과 그 좌우 spread 간격으로 n곳 — 하나씩 0.07초 간격으로 떨어진다
--  aim = 'row': 보스(from)의 앞(dir)으로 start에서 gap 간격으로 n곳 — 가까운 것부터 lag초씩 늦게 터진다(폭탄 깔기 — 불씨 도둑 두목 2026-10-28 · 터진 자리로 건너간다)
function BossPat.spots(p, aim: number, lo: number, hi: number, from: number?, dir: number?): { { number } }
	local sp = p.spots
	local list = {}
	if sp.aim == "row" then
		for i = 0, sp.n - 1 do
			local x = (from or aim) + (dir or 1) * (sp.start + i * sp.gap)
			if x > lo + sp.r and x < hi - sp.r then
				table.insert(list, { x, i * sp.lag })
			end
		end
	elseif sp.aim == "grid" then
		local x, n = lo + sp.gap / 2, 0
		while x <= hi - sp.r do
			table.insert(list, { x, if n % 2 == 1 then sp.lag else 0 })
			x += sp.gap
			n += 1
		end
	else
		local base = math.clamp(aim, lo + sp.r, hi - sp.r)
		table.insert(list, { base, 0 })
		local n = 1
		while #list < sp.n and n < 12 do
			local sx = base + (if n % 2 == 1 then 1 else -1) * math.ceil(n / 2) * sp.spread
			if sx > lo + sp.r and sx < hi - sp.r then
				table.insert(list, { sx, 0.07 * #list })
			end
			n += 1
		end
	end
	return list
end

-- 도약(leap): 뛰어오른 뒤 t초째에 몸이 바닥에서 떠 있는 높이(포물선 — time초에 내려앉는다)
function BossPat.leapAlt(p, t: number): number
	local L = p.leap
	if not L or t >= L.time then
		return 0
	end
	local k = math.clamp(t / L.time, 0, 1)
	return L.peak * 4 * k * (1 - k)
end

-- 도약이 내려앉는 자리(몸의 가운데): 겨눈 자리 aim에서 돌망치가 떨어지는 거리(leap.aim)만큼 못 미친 데 — 보스가 움직이는 범위 [a, b] 안. 보는 쪽도 돌려준다
--  leap.back(2026-10-27 그림자 사수 「물러서기」): 겨눈 자리에서 멀어지는 쪽으로 back만큼(보는 쪽은 겨눈 쪽 그대로 — 내려앉아 곧바로 쏜다)
function BossPat.leapTo(p, x: number, dir: number, aim: number, a: number, b: number): (number, number)
	local d = if aim > x then 1 elseif aim < x then -1 else dir
	if p.leap.back then
		return math.clamp(x - d * p.leap.back, a, b), d
	end
	return math.clamp(aim - d * p.leap.aim, a, b), d
end

-- 물결(wave)이 떠나는 쪽들과 차례: { { dir, wait } … } — dir = 'front'면 보는 쪽으로만 · n개를 gap초 간격으로
function BossPat.waves(p, dir: number): { { number } }
	local W = p.wave
	local list = {}
	for n = 0, (W.n or 1) - 1 do
		if W.dir == "front" then
			table.insert(list, { dir, n * (W.gap or 0) })
		else
			table.insert(list, { -1, n * (W.gap or 0) })
			table.insert(list, { 1, n * (W.gap or 0) })
		end
	end
	return list
end

return BossPat
