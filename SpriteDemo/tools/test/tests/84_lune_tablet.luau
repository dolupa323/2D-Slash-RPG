-- 「달의 계승자」 — 태블릿(iPad) 화면(2026-10-23).
--  사용자: "현재 모바일, pc 는 괜찮은데 모바일버전으로 아이패드로 플레이할때 불편하다고하네 방법을 찾아봐"
--  보는 것: ① 화면 배율 — 폰 · PC는 전과 같다 · 터치 태블릿은 정수 배율이 화면을 6% 넘게 비우면 꽉 차게(10.2인치 iPad 1080x810: 2배 = 화면의 38% → 2.81배)
--   ② 터치 단추 — 폰은 전과 같다(k = 1) · 태블릿은 이동 패드 지름 ≤ 140점 · 모든 단추가 게임 화면 안 · 서로 겹치지 않음 · 가장 작은 단추도 44점 이상(Apple의 누르는 칸 기준)
--  화면 크기는 Roblox가 주는 점(pt — iPad 10.2인치 = 1080x810). 기기에서 재지는 못했다(제가 계산한 것).
local Stage = req("Client/lune/stage")
local Layout = req("ReplicatedStorage/shared/lune/ui/layout")
local UI = req("ReplicatedStorage/shared/lune/data/ui.generated")
local G = req("ReplicatedStorage/shared/lune/config/game")

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

-- ① 배율
do
	local s, us = Stage.scalesFor(1920, 1080, false)
	expect(s == 5 and us == 2, "PC 1080p: 5배 · 화면 틀 2배(전과 같다)")
	s = Stage.scalesFor(1920, 1080, true)
	expect(s == 5, "터치 PC 1080p: 정수 배율이 꽉 차므로 그대로 5배")
	local ps, pus = Stage.scalesFor(844, 390, true)
	local qs, qus = Stage.scalesFor(844, 390, false)
	expect(near(ps, qs) and near(pus, qus) and ps < 2, "폰(844x390): 터치든 아니든 전과 같다(꽉 차게)")
	s, us = Stage.scalesFor(1080, 810, false)
	expect(s == 2, "iPad 10.2인치를 PC처럼 셈하면 2배(화면의 38%) — 고치기 전")
	s, us = Stage.scalesFor(1080, 810, true)
	expect(near(s, 1080 / G.VIEW_W) and near(G.VIEW_W * s / us, UI.grid.w), ("iPad 10.2인치(터치): 가로를 꽉 채운다 — %.3f배 · 화면 틀 %d점"):format(s, G.VIEW_W * s / us))
	s = Stage.scalesFor(1180, 820, true)
	expect(s == 3, "iPad Air 11인치: 3배가 화면의 98%라 정수 그대로")
	s = Stage.scalesFor(1366, 1024, true)
	expect(near(s, 1366 / G.VIEW_W), "iPad Pro 12.9인치: 꽉 차게")
	s = Stage.scalesFor(1133, 744, true)
	expect(near(s, 1133 / G.VIEW_W), "iPad mini: 꽉 차게")
end

-- ② 단추
local function rects(k)
	local out = {}
	for _, t in UI.touch do
		if t.kind == "pad" or t.slot or t.act then -- 누르는 단추만(hud = 폰 화면의 보스 체력 · 버프 같은 자리는 단추가 아니다)
			local x, y, w, h = Layout.touchRect(t, k, G.VIEW_W, G.VIEW_H)
			table.insert(out, { t = t, x = x, y = y, w = w, h = h })
		end
	end
	return out
end
do
	local phone = Stage.scalesFor(844, 390, true)
	eq(Layout.touchK(phone, UI.touch), 1, "폰: 단추 그대로(k = 1)")
	for _, r in rects(1) do
		expect(near(r.x, r.t.x) and near(r.y, r.t.y) and near(r.w, r.t.w), "k = 1이면 자리 · 크기가 전과 같다 " .. tostring(r.t.no))
	end
	for _, dev in { { "iPad 10.2", 1080, 810 }, { "iPad Pro 12.9", 1366, 1024 }, { "iPad mini", 1133, 744 }, { "iPad Air 11", 1180, 820 } } do
		local s = Stage.scalesFor(dev[2], dev[3], true)
		local k = Layout.touchK(s, UI.touch)
		local list = rects(k)
		local smallest = math.huge
		for _, r in list do
			expect(r.x >= -0.01 and r.y >= -0.01 and r.x + r.w <= G.VIEW_W + 0.01 and r.y + r.h <= G.VIEW_H + 0.01, dev[1] .. ": 단추가 게임 화면 안 " .. tostring(r.t.no))
			smallest = math.min(smallest, math.min(r.w, r.h) * s)
			if r.t.kind == "pad" then
				expect(r.w * s <= Layout.TOUCH_PAD_MAX + 0.01, ("%s: 이동 패드 지름 %.0f점 ≤ %d"):format(dev[1], r.w * s, Layout.TOUCH_PAD_MAX))
			end
		end
		expect(smallest >= 44, ("%s: 가장 작은 단추 %.0f점 ≥ 44점"):format(dev[1], smallest))
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				local overlap = a.x < b.x + b.w - 0.01 and b.x < a.x + a.w - 0.01 and a.y < b.y + b.h - 0.01 and b.y < a.y + a.h - 0.01
				expect(not overlap, ("%s: 단추 %s · %s가 겹치지 않는다"):format(dev[1], tostring(a.t.no), tostring(b.t.no)))
			end
		end
	end
end
