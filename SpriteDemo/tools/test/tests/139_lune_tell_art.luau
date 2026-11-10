-- 「달의 계승자」 — 보스의 예고(경고 장판) = 맞을 자리의 희미한 단색 칠 하나(2026-11-09 사용자: "경고장판 개념을 잘 모르는거같은데 지금 이것저것 너무많이들어가 그냥 단색 희미한 영역만 보이는거야 이렇게 복잡하게 작업할 필요가없어")
--  shared/lune/bossfx.luau의 area · tell · spot: 패턴마다 맞을 자리(판정의 네모 그대로)만 적의 분홍으로 희미하게 — 테두리 · 줄 · 모양 없음. 보스마다 다른 것은 머리 위 표시뿐(top이 있을 때)
local BossFx = req("ReplicatedStorage/shared/lune/bossfx")
local Fx = req("ReplicatedStorage/shared/lune/fx")
local PINK = Fx.TONE.pink.n

local function canvas()
	local c = { rects = {}, color = 0, a = 1 }
	function c:style(v)
		self.color = v
	end
	function c:alpha(v)
		self.a = v
	end
	function c:rect(x, y, w, h)
		table.insert(self.rects, { x = x, y = y, w = w, h = h, c = self.color, a = self.a })
	end
	return c
end
local floorY, X, A, B = 176, 400, 112, 704
-- 칠 하나: 그 네모 · 적의 분홍 · 희미하게(0.16 ~ 0.28)
local function one(c, lo, hi, top, bottom, what)
	local r = c.rects[1]
	expect(#c.rects == 1, what .. ": 칠 하나뿐 (" .. #c.rects .. ")")
	if r then
		expect(r.x == lo and r.x + r.w == hi and r.y == top and r.y + r.h == bottom, ("%s: 맞을 자리 그대로(%d ~ %d · %d ~ %d) — 실제 %d ~ %d · %d ~ %d"):format(what, lo, hi, top, bottom, r.x, r.x + r.w, r.y, r.y + r.h))
		expect(r.c == PINK and r.a >= 0.16 and r.a <= 0.28 + 1e-9, what .. ": 적의 분홍 · 희미하게")
	end
end

-- 치는 자리(zone) · 끝이 가까울수록 조금 짙어진다
do
	local p = { zone = { from = 20, to = 140, up = 90 } }
	local c0, c1 = canvas(), canvas()
	BossFx.tell(c0, X, floorY, -1, p, 0, A, B, nil, nil, "knight")
	BossFx.tell(c1, X, floorY, -1, p, 1, A, B, nil, nil, "knight")
	one(c0, X - 140, X - 20, floorY - 90, floorY, "치는 자리")
	expect(c1.rects[1].a > c0.rects[1].a, "끝이 가까울수록 조금 짙다")
end
-- 방 전체(±999)는 방의 둘레까지 · 하늘까지(999)는 230점까지
do
	local c = canvas()
	BossFx.tell(c, X, floorY, 1, { zone = { from = -999, to = 999, up = 999 } }, 0.5, A, B, nil, nil, "lava")
	one(c, A - 20, B + 20, floorY - 230, floorY, "방 전체")
end
-- 도약 찍기: 내려앉을 자리(겨눈 사람에게서 aim만큼 못 미친 곳)
do
	local p = { leap = { aim = 40, time = 0.5 }, zone = { from = -30, to = 30, up = 50 } }
	local c = canvas()
	BossFx.tell(c, X, floorY, -1, p, 0.5, A, B, nil, 200, "thief")
	local land = 200 + 40
	one(c, land - 30, land + 30, floorY - 50, floorY, "도약")
end
-- 날아갈 길(높은 화살 — 맞는 높이 lift ~ up)
do
	local p = { wave = { dir = "front", at = 40, range = 200, up = 60, lift = 20 } }
	local c = canvas()
	BossFx.tell(c, X, floorY, 1, p, 0.5, A, B, nil, nil, "archer")
	one(c, X + 40, X + 240, floorY - 60, floorY - 20, "날아갈 길")
end
-- 낮은 띠 · 가로 열선(발이 바닥에서 lo 위)
do
	local c = canvas()
	BossFx.tell(c, X, floorY, 1, { band = { from = 30, to = 300, lo = 8, hi = 40 } }, 0.5, A, B, nil, nil, "lava")
	one(c, X + 30, X + 300, floorY - 40, floorY - 8, "낮은 띠")
	local c2 = canvas()
	BossFx.tell(c2, 256, floorY, 1, { band = { from = -999, to = 999, lo = 20, lines = { 58, 106 } } }, 0.5, A, B, nil, nil, "lava")
	one(c2, A - 20, B + 20, floorY - 230, floorY - 20, "가로 열선")
end
-- 갈고리 · 내달리기
do
	local c = canvas()
	BossFx.tell(c, X, floorY, -1, { hook = { at = 10, range = 150, up = 30 } }, 0.5, A, B, nil, nil, "thief")
	one(c, X - 160, X - 10, floorY - 30, floorY, "갈고리")
	local c2 = canvas()
	BossFx.tell(c2, X, floorY, 1, { dash = { up = 30 } }, 0.5, A, B, nil, nil, nil)
	one(c2, X, B, floorY - 30, floorY, "내달리기")
end
-- 표시된 자리: 모든 보스가 같은 기둥 칠 하나
for _, mark in { "lava", "archer", "knight", "thief", false } do
	local c = canvas()
	BossFx.spot(c, 300, floorY, 14, 56, 0.6, 250, 100, mark or nil, true)
	one(c, 286, 314, floorY - 56, floorY, "표시된 자리(" .. tostring(mark) .. ")")
end
do
	local c = canvas()
	BossFx.spot(c, 300, floorY, 12, 999, 0.6, nil, nil, "lava", false)
	one(c, 288, 312, floorY - 230, floorY, "하늘에서 떨어지는 곳(230점까지)")
end
-- 보스마다 다른 것은 머리 위 표시뿐
do
	local p = { zone = { from = 20, to = 140, up = 90 } }
	local seen = {}
	for _, mark in { "lava", "archer", "knight", "thief", "none" } do
		local c = canvas()
		BossFx.tell(c, X, floorY, -1, p, 0.5, A, B, 100, nil, if mark == "none" then nil else mark)
		expect(#c.rects > 1, mark .. ": 머리 위 표시")
		seen[#c.rects] = (seen[#c.rects] or 0) + 1
	end
	local kinds = 0
	for _ in seen do
		kinds += 1
	end
	expect(kinds >= 4, "머리 위 표시가 보스마다 다르다(점 수로 — 「!」 · 조준 십자 · 칼 · 폭탄 · 용암 방울)")
end
-- 졸개가 나올 자리 표시는 그대로(장판이 아니다)
do
	local c = canvas()
	BossFx.tell(c, X, floorY, -1, { summon = { at = { 300, 500 } } }, 0.5, A, B, nil, nil, nil)
	expect(#c.rects > 2, "졸개가 나올 자리 표시")
end
