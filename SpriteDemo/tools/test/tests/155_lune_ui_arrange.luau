-- 「달의 계승자」 — 화면 배치(2026-11-12 사용자: "지금 채팅창처럼 모든 ui 가 끌어서 자리를 옮길수 있어야해 지금 모바일에서 잘려보이는경우 엄청많아").
--  client stage.luau Stage.fit · movedPosition · place · move(옮긴 만큼 · 화면 안) · shared sim/account.luau cleanSound의 ui(기기 종류마다 판의 자리 — 꼴이 틀린 것은 버린다)
--  보는 것: ① 폰의 작은 격자(768x432)에서 기준 격자(960x540)로 놓은 판이 화면 밖으로 나가면 안으로 민다 · 화면보다 큰 판은 그대로 · 화면 안의 판은 그대로
--   ② 옮긴 만큼(Stage.moved)이 놓을 때 더해지고, 다시 놓아도(Stage.move) 지켜진다 · 너무 멀리 옮겨도 화면 안에서 멈춘다 ③ 저장의 꼴 검사
local Stage = req("Client/lune/stage")
local Account = req("ReplicatedStorage/shared/lune/sim/account")

local function px(u: UDim2, W: number): number
	return u.X.Scale * W + u.X.Offset
end
local function py(u: UDim2, H: number): number
	return u.Y.Scale * H + u.Y.Offset
end

-- ① 폰 격자
Stage.uiW, Stage.uiH, Stage.insetTop = 768, 432, 0
eq(Stage.REF_W, 960, "기준 격자의 폭")
do
	local x, y = Stage.fit("tl", 700, 10, 200, 40)
	eq(x, 568, "왼쪽 위에 붙은 판이 오른쪽으로 잘리면 안으로(700 → 568)")
	eq(y, 10, "세로는 그대로")
	local x2, y2 = Stage.fit("tl", 10, 10, 200, 40)
	expect(x2 == 10 and y2 == 10, "화면 안의 판은 그대로")
	local bx, by = Stage.fit("bl", 10, 540 - 30, 200, 60)
	local top = Stage.uiH + by - Stage.REF_H
	expect(top + 60 <= Stage.uiH and top >= 0, "아래에 붙은 판의 아래 끝이 화면 안(위 " .. top .. ")")
	eq(bx, 10, "가로는 그대로")
	local wx = Stage.fit("tc", 0, 0, 960, 540)
	eq(wx, 0, "화면보다 큰 판(덮개)은 그대로")
end

-- ①-2 창 끌기는 느슨하게(2026-11-12 사용자: "모바일에서 어느정도 터치보정이 되어야해 영역밖으로 끌어다놓는다고하면 바로 제자리로 돌아가는게 너무판정이 빡세다"):
--  왼쪽 · 아래로는 화면 밖으로 나가도 된다(왼쪽은 90점 · 제목 줄 30점은 남는다) · 오른쪽 끝(닫기 X)과 위(제목 줄)는 화면 안
do
	local W, H, keepW, keepH = 300, 300, 90, 30
	local function leftTop(at, x, y)
		local u = Stage.atPosition(at, x, y)
		return px(u, Stage.uiW), py(u, Stage.uiH)
	end
	local x, y = Stage.fitLoose("tl", -150, 300, W, H, keepW, keepH)
	local l, tp = leftTop("tl", x, y)
	eq(l, -150, "왼쪽으로 반쯤 나간 창은 그대로(전에는 화면 안으로 밀려 돌아왔다)")
	expect(tp + H > Stage.uiH and tp <= Stage.uiH - keepH, "아래로 나가도 제목 줄은 화면 안(" .. tp .. ")")
	x = Stage.fitLoose("tl", -400, 10, W, H, keepW, keepH)
	l = leftTop("tl", x, 10)
	eq(l, -(W - keepW), "너무 멀리 끌어도 90점은 화면 안에 남는다")
	x = Stage.fitLoose("tl", 700, 10, W, H, keepW, keepH)
	l = leftTop("tl", x, 10)
	eq(l + W, Stage.uiW, "오른쪽 끝(닫기 X)은 화면 안")
	local _, y2 = Stage.fitLoose("tl", 10, -50, W, H, keepW, keepH)
	local _, t2 = leftTop("tl", 10, y2)
	eq(t2, 0, "제목 줄은 화면 위로 나가지 않는다")
end

-- ② 옮긴 만큼
table.clear(Stage.moved)
Stage.moved.Vitals = { x = -40, y = -20 }
local fake = { Name = "Vitals", Size = UDim2.fromOffset(200, 40), Position = UDim2.fromOffset(0, 0) }
local pos = Stage.movedPosition("Vitals", "bc", 380, 480, 200, 40)
eq(px(pos, Stage.uiW), Stage.uiW * 0.5 + 380 - 40 - 480, "옮긴 만큼 왼쪽으로 40")
eq(py(pos, Stage.uiH), Stage.uiH + 480 - 20 - 540, "옮긴 만큼 위로 20")
Stage.move(fake :: any, "bc", 380, 480)
eq(px(fake.Position, Stage.uiW), px(pos, Stage.uiW), "다시 놓아도(Stage.move) 옮긴 만큼을 지킨다")
Stage.moved.Vitals = { x = 5000, y = 0 }
local far = Stage.movedPosition("Vitals", "bc", 380, 480, 200, 40)
expect(px(far, Stage.uiW) <= Stage.uiW - 200, "너무 멀리 옮겨도 화면 안에서 멈춘다")
table.clear(Stage.moved)

-- ③ 저장의 꼴(sim/account.luau cleanSound)
local base = { music = 5, sfx = 5, on = true }
local function with(ui)
	local v = table.clone(base)
	v.ui = ui
	return Account.cleanSound(v)
end
local ok1 = with({ pc = { Vitals = { x = 10, y = -5 }, Window_bag = { x = -100, y = 0 } }, touch = { Chat = { x = 3, y = 4 } } })
expect(ok1 and ok1.ui.pc.Vitals.x == 10 and ok1.ui.pc.Window_bag.x == -100 and ok1.ui.touch.Chat.y == 4, "바른 자리는 받는다")
local bad = with({ pc = { ["a b"] = { x = 1, y = 1 }, Long = { x = 9999, y = 0 }, Frac = { x = 1.5, y = 0 }, Fine = { x = 1, y = 2 } } })
expect(bad and bad.ui.pc["a b"] == nil and bad.ui.pc.Long == nil and bad.ui.pc.Frac == nil and bad.ui.pc.Fine ~= nil, "꼴이 틀린 줄만 버린다(이름 · 범위 · 정수)")
local many = {}
for i = 1, 80 do
	many["P" .. i] = { x = i, y = 0 }
end
local m = with({ pc = many })
local n = 0
for _ in m.ui.pc do
	n += 1
end
eq(n, 60, "기기마다 60개까지")
local none = Account.cleanSound(base)
expect(none and none.ui == nil, "ui가 없는 옛 저장은 그대로(처음 자리)")
