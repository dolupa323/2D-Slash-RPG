-- 확률 창 — 「확률 보기」 단추로 연다(2026-11-07 — 로블록스의 확률형 아이템 규정: 쓰거나 사기 전에 나올 수 있는 모든 것과 그 확률 %를 보인다 · 합 100%).
--  arg = 무엇의 확률인가: "reroll:<장비 레벨>"(윤슬 조각 — 장비 상세의 「확률 보기」) · "box:<상자>"(달빛 상점의 펫 상자 · 탈것 상자 — 내가 가진 것은 빠진 확률)
--  위부터: 머리 글(줄마다) / 가르는 줄 / 줄마다 [이름 ……… 값](넘치면 굴려 본다) / 아래 한 줄(foot). 글은 shared/lune/ui/odds.luau가 만든다.
--  치수 = 공방 design/ui.js UILAYOUT.odds(제가 정한 것). 화면 오른쪽의 옆 판(ui/windows.luau)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Odds = require(lune.ui.odds)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local S = UI.layout.odds or { w = 300, h = 300, listY = 50, rowH = 16, valueW = 78 }

local OddsWindow = {}

function OddsWindow.size(): (number, number)
	return S.w, S.h
end

-- arg → 적을 것(odds.luau의 꼴). 모르는 arg면 nil
function OddsWindow.content(ctx, arg: any)
	if typeof(arg) ~= "string" then
		return nil
	end
	local kind, rest = string.match(arg, "^(%a+):(.+)$")
	if kind == "reroll" then
		local stage = tonumber(rest)
		return if stage then Odds.reroll(math.clamp(math.floor(stage), 1, 200)) else nil
	elseif kind == "box" and Odds.box then
		return Odds.box(rest, ctx and ctx.cash and ctx.cash() or nil) -- (가진 펫 · 탈것 = 달빛 상점의 view)
	end
	return nil
end

function OddsWindow.title(arg: any): string?
	local c = OddsWindow.content(nil, arg)
	return if c then c.title else nil
end

function OddsWindow.build(body: Frame, ctx, w: number, h: number, arg: any)
	local view = {}
	local holder: Frame? = nil
	function view.refresh()
		if holder then
			holder:Destroy()
		end
		holder = Ui.group(body, 0, 0, w, h, "Odds")
		local c = OddsWindow.content(ctx, arg)
		if not c then
			return
		end
		local y = 0
		for _, line in c.head do
			local label = Ui.text(holder :: Frame, line, 0, y, w, { lines = 3, color = C.text })
			local _, lh = label:size()
			y += math.max(14, lh) + 2
		end
		Ui.line(holder :: Frame, 0, y + 2, w)
		y += 6
		local footH = if c.foot and c.foot ~= "" then 30 else 0
		local listH = h - y - footH
		local rowH = S.rowH
		local list = Ui.scroll(holder :: Frame, 0, y, w, listH, #c.rows * rowH)
		for i, row in c.rows do
			local ry = (i - 1) * rowH
			Ui.text(list, row[1], 0, ry + 2, w - S.valueW - 8, { color = C[row[3]] or C.text })
			Ui.text(list, row[2], w - S.valueW - 6, ry + 2, S.valueW, { align = "right", color = C[row[3]] or C.text })
		end
		if footH > 0 then
			Ui.text(holder :: Frame, c.foot, 0, h - footH + 4, w, { lines = 2, color = C.dim })
		end
	end
	view.refresh()
	return view
end

return OddsWindow
