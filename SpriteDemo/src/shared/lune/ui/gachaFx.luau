-- 뽑기 연출의 셈(2026-11-10 — 사용자 "랜덤뽑기상자를 달빛상점에서 사면 사자마자 연출이 나오고 … 뭐가뜰까 두근두근하다가 짠"): 연 지 t초의 모습.
--  공방 js/lune/gachaFx.js와 한 줄씩 같은 셈이다(고치면 둘 다). 그리기는 client/lune/ui/gachaView.luau · 공방 ui/paint.js paintGacha.
--  G = bm.generated의 gacha(공방 design/bm.js의 GACHA). rare = 나온 것이 그 상자의 드문 것인가(빛의 색 · 금빛 조각)
local GachaFx = {}

local function clamp01(v: number): number
	return math.max(0, math.min(1, v))
end
local function round(v: number): number
	return math.floor(v + 0.5)
end
local function hexRgb(h: string): { number }
	return { tonumber(string.sub(h, 2, 3), 16) or 255, tonumber(string.sub(h, 4, 5), 16) or 255, tonumber(string.sub(h, 6, 7), 16) or 255 }
end
local function mixRgb(a, b, k: number): { number }
	return { round(a[1] + (b[1] - a[1]) * k), round(a[2] + (b[2] - a[2]) * k), round(a[3] + (b[3] - a[3]) * k) }
end
GachaFx.hexRgb = hexRgb

-- 차례의 때(초): 떨림 · 등급의 색 · 부풂 · 튀어나옴 · 이름 · [확인] · 저절로 닫힘
function GachaFx.times(G)
	local tShake = G.fall + G.bounce
	local tBurst = tShake + G.shake
	local tPop = tBurst + G.burst
	local tName = tPop + G.pop
	local tOk = tName + G.okAt
	return { tShake = tShake, tHint = tBurst - G.hint, tBurst = tBurst, tPop = tPop, tName = tName, tOk = tOk, tEnd = tOk + G.close }
end

-- t초의 모습(공방 gachaAt와 같은 이름의 값): dim · boxShow · boxX · boxY · boxK · glow · glowR · color({ r, g, b }) · rays · rayLen · turn · ring · ringR · flash ·
--  itemShow · itemK · itemY · spark(0 ~ 1 · 없으면 -1) · confetti(0 ~ 1 · -1) · rare · name · ok · tap
function GachaFx.at(t: number, G, rare: boolean)
	local T = GachaFx.times(G)
	local S, C = G.size, G.color
	local tier, start = hexRgb(if rare then C.rare else C.normal), hexRgb(C.start)
	local o = {
		dim = C.dim * clamp01(t / G.fade), boxShow = t < T.tPop, boxX = 0, boxY = 0, boxK = 1, glow = 0, glowR = S.glowR[1], color = start, rays = 0, rayLen = 0, turn = t * S.rayTurn,
		ring = 0, ringR = 0, flash = 0, itemShow = t >= T.tPop, itemK = 0, itemY = 0, spark = -1, confetti = -1, rare = rare and t >= T.tName, name = t >= T.tName, ok = t >= T.tOk, tap = t < T.tPop,
	}
	if t < G.fall then -- 떨어진다(점점 빠르게)
		local u = clamp01(t / G.fall)
		o.boxY = -round(S.fallH * (1 - u * u))
	elseif t < T.tShake then -- 한 번 튀어 오른다
		o.boxY = -round(S.bounceH * math.sin(math.pi * clamp01((t - G.fall) / G.bounce)))
	elseif t < T.tBurst then -- 떨림: 점점 크게 · 빛 원 · 빛살 · 고리가 모인다 · 마지막 hint초에 빛이 등급의 색으로
		local u = clamp01((t - T.tShake) / G.shake)
		local amp = S.shakeAmp[1] + (S.shakeAmp[2] - S.shakeAmp[1]) * u * u
		local ph = 2 * math.pi * S.shakeHz * (t - T.tShake)
		o.boxX = round(amp * math.sin(ph))
		o.boxY = round(amp * 0.5 * math.sin(ph * 0.7 + 1))
		o.glow = S.glowA[1] + (S.glowA[2] - S.glowA[1]) * u
		o.glowR = S.glowR[1] + round(3 * math.sin(2 * math.pi * 2 * t))
		o.rays = S.rayA[1] * u
		o.rayLen = round(S.rayLen[1] * u)
		o.ring = u
		o.ringR = round(S.ringR * (1.7 - 1.2 * u))
		o.color = mixRgb(start, tier, clamp01((t - T.tHint) / G.hint))
	elseif t < T.tPop then -- 부풂: 상자가 커지고 하얗게 번쩍인다
		local u = clamp01((t - T.tBurst) / G.burst)
		o.boxK = 1 + S.boxGrow * u
		o.glow = S.glowA[2]
		o.glowR = S.glowR[1] + round((S.glowR[2] - S.glowR[1]) * u)
		o.rays = S.rayA[1]
		o.rayLen = S.rayLen[1]
		o.color = tier
		o.flash = 0.9 * u * u
	else -- 나왔다: 튀어나오며 커진다(넘쳤다 돌아온다) · 빛살은 천천히 돌며 남는다
		local u = clamp01((t - T.tPop) / G.pop)
		local d = t - T.tPop
		o.itemK = if u < 0.7 then (1 + S.popOver) * (u / 0.7) else 1 + S.popOver - S.popOver * ((u - 0.7) / 0.3)
		o.itemY = if u >= 1 then -round(2 * math.sin(2 * math.pi * 0.6 * (d - G.pop))) else 0
		o.glow = S.glowA[3]
		o.glowR = S.glowR[2]
		o.rays = S.rayA[2]
		o.rayLen = S.rayLen[2]
		o.color = tier
		o.flash = 0.9 * (1 - clamp01(d / G.flashOut))
		o.spark = if d < G.sparkT then d / G.sparkT else -1
		o.confetti = if rare and d < G.confettiT then d / G.confettiT else -1
	end
	return o
end

-- 빛줄기(가운데에서): { 각(라디안), 시작 거리, 길이, 짙기 } — rays줄 · 홀수 줄은 0.7배 길이(길고 짧게 번갈아) · 끝으로 갈수록 옅게는 그리는 쪽이(게임 = UIGradient · 공방 = 캔버스의 그라데이션)
function GachaFx.beams(o, S): { { number } }
	local out = {}
	if o.rays <= 0 or o.rayLen <= 0 then
		return out
	end
	for i = 0, S.rays - 1 do
		table.insert(out, { o.turn + (i * 2 * math.pi) / S.rays, S.rayR0, round(o.rayLen * (if i % 2 == 0 then 1 else 0.7)), o.rays })
	end
	return out
end
-- 모이는 고리의 점(빛살과 거꾸로 돈다)
function GachaFx.ringDots(o, S): { { number } }
	local out = {}
	if o.ring <= 0 then
		return out
	end
	for i = 0, S.ring - 1 do
		local a = -o.turn * 1.5 + (i * 2 * math.pi) / S.ring
		table.insert(out, { round(math.cos(a) * o.ringR), round(math.sin(a) * o.ringR) })
	end
	return out
end
-- 빛 원의 줄(두 점 높이의 띠): { 왼쪽 x, 위 y, 폭 } — 가운데에서
function GachaFx.discRows(R: number): { { number } }
	local out = {}
	local y = -R
	while y < R do
		local yc = y + 1
		local half = math.floor(math.sqrt(math.max(0, R * R - yc * yc)))
		if half > 0 then
			table.insert(out, { -half, y, half * 2 })
		end
		y += 2
	end
	return out
end
-- 조각(u = 0 ~ 1): { x, y, 크기 } — 고르게 퍼진다
function GachaFx.sparks(u: number, S): { { number } }
	local out = {}
	if u < 0 then
		return out
	end
	local r = S.sparkR * (1 - (1 - u) * (1 - u))
	local k = math.max(1, round(3 * (1 - u)))
	for i = 0, S.sparks - 1 do
		local a = (i * 2 * math.pi) / S.sparks + 0.3
		table.insert(out, { round(math.cos(a) * r), round(math.sin(a) * r), k })
	end
	return out
end
-- 금빛 조각(u = 0 ~ 1 — confettiT초): { x, y, 색의 차례(1부터) } — 위로 부채꼴로 튀어 올랐다가 떨어진다
local function frac(v: number): number
	return v - math.floor(v)
end
function GachaFx.confetti(u: number, G): { { number } }
	local out = {}
	local S = G.size
	local n = S.confetti
	if u < 0 then
		return out
	end
	local tt = u * G.confettiT
	for i = 0, n - 1 do
		local a = -math.pi / 2 + (i / (n - 1) - 0.5) * 2.4 + 0.15 * math.sin(i * 12.9898)
		local v = 190 + 80 * frac(math.sin(i * 78.233) * 43758.5453)
		table.insert(out, { round(math.cos(a) * v * tt), round(math.sin(a) * v * tt + 160 * tt * tt), i % #G.color.confetti + 1 })
	end
	return out
end

return GachaFx
