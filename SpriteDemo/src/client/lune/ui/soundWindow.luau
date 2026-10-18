-- 소리 설정 창 — 메뉴 → 「소리 설정」. 배경 음악과 효과음의 크기를 따로 열 칸으로(한 칸 10%).
--  사용자 2026-10-13: "소리조절 있어야합니다." — 그 앞에는 메뉴에 「소리 끄기 / 켜기」뿐이었다.
--  줄마다: 이름 · 「−」 · 칸 열 개(찬 칸 = 민트 — 눌러서 그 칸까지 · 모두 껐으면 흐린 회색) · 「+」 · %. 아래에 「모두 끄기 / 켜기」와 안내 글.
--  바꾸면 바로 그 크기로 나고(music.luau), 계정에 저장된다(ctx.saveSound → 서버의 Sound). 모양은 공방 시험 탭의 js/lune/ui/paint.js(paintSound)와 같다.
--  화면 오른쪽의 옆 판(ui/windows.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage.shared.lune.ui.layout)
local Ui = require(script.Parent.ui)
local Music = require(script.Parent.Parent.music)
local ViewOpts = require(script.Parent.Parent.viewOpts) -- 화면(다른 사람의 스킬 효과 · 피해 숫자 — 2026-10-18)

local C = Ui.COLOR
local S = Layout.SOUND

local SoundWindow = {}

function SoundWindow.size(): (number, number)
	local V = S.view
	return S.w, #S.rows * S.row + S.muteY + Ui.M.button + V.gap + V.headH + #V.rows * S.row + Ui.M.small
end

-- 줄 안에서의 자리: 첫 칸의 x · 「+」의 x
function SoundWindow.bar(): (number, number)
	local x = S.labelW + S.btn + S.barGap
	return x, x + S.steps * S.seg + (S.steps - 1) * S.gap + S.barGap
end

function SoundWindow.pct(v: number): string
	return ("%d%%"):format(math.floor(v / S.steps * 100 + 0.5))
end

function SoundWindow.build(body: Frame, ctx, w: number, _h: number)
	local view = {}
	local rows = {}
	local barX, plusX = SoundWindow.bar()
	local function set(kind: string, v: number)
		if Music.setLevel(kind, v) then
			ctx.saveSound()
			view.refresh()
		end
	end
	for i, def in S.rows do
		local kind, name = def[1], def[2]
		local y = (i - 1) * S.row
		local row = { kind = kind, segs = {} }
		Ui.text(body, name, 0, y + math.floor((S.btn - Ui.M.body) / 2), S.labelW - 6, { font = "body" })
		row.minus = Ui.button(body, "-", S.labelW, y, S.btn, function()
			set(kind, Music.level[kind] - 1)
		end, { h = S.btn, font = "body" })
		local by = y + math.floor((S.btn - S.barH) / 2)
		for k = 1, S.steps do
			local x = barX + (k - 1) * (S.seg + S.gap)
			-- 칸: 한 점 테두리(빈 칸) + 속 — 찬 칸은 둘 다 한 색
			local edge = Ui.box(body, x, by, S.seg, S.barH, C.line)
			edge.Name = "Seg" .. k
			local fill = Ui.box(edge, 1, 1, S.seg - 2, S.barH - 2, C.panel2)
			-- 누르는 자리는 칸보다 넓게(사이의 틈까지 · 줄의 높이만큼) — 손가락으로도 누른다
			Ui.hit(Ui.group(body, x, y, S.seg + S.gap, S.btn, "SegHit" .. k)).Activated:Connect(function()
				set(kind, k)
			end)
			row.segs[k] = { edge = edge, fill = fill }
		end
		row.plus = Ui.button(body, "+", plusX, y, S.btn, function()
			set(kind, Music.level[kind] + 1)
		end, { h = S.btn, font = "body" })
		row.pct = Ui.text(body, "", w - S.pctW, y + math.floor((S.btn - Ui.M.small) / 2), S.pctW, { align = "right" })
		rows[i] = row
	end
	local my = #S.rows * S.row + S.muteY
	local mute = Ui.button(body, "", 0, my, S.muteW, function()
		Music.toggle()
		ctx.saveSound()
		view.refresh()
	end)
	Ui.text(body, S.note, S.muteW + 8, my + math.floor((Ui.M.button - Ui.M.small) / 2), w - S.muteW - 8, { align = "right", color = C.dim })
	-- 화면(2026-10-18 — 공방 시험 탭의 paintSound와 같은 모양): 가로줄 · 「화면」 · 줄마다 이름과 오른쪽 끝의 켜짐 / 꺼짐 단추 · 맨 아래 안내
	local V = S.view
	local vy = my + Ui.M.button + V.gap
	Ui.box(body, 0, vy, w, 1, C.line)
	Ui.text(body, V.head, 0, vy + 6, w, { color = C.dim })
	local toggles = {}
	for j, def in V.rows do
		local key, name = def[1], def[2]
		local y = vy + V.headH + (j - 1) * S.row
		Ui.text(body, name, 0, y + math.floor((S.btn - Ui.M.body) / 2), w - V.btnW - 8, { font = "body" })
		toggles[key] = Ui.button(body, V.on, w - V.btnW, y, V.btnW, function()
			if ViewOpts.toggle(key) then
				ctx.saveSound()
				view.refresh()
			end
		end, { h = S.btn })
	end
	Ui.text(body, V.note, 0, vy + V.headH + #V.rows * S.row, w, { color = C.dim })

	function view.refresh()
		for _, row in rows do
			local v = Music.level[row.kind]
			for k, seg in row.segs do
				local color = if k <= v then (if Music.on then C.accent else C.off) else nil
				seg.edge.BackgroundColor3 = color or C.line
				seg.fill.BackgroundColor3 = color or C.panel2
			end
			row.minus:setEnabled(v > 0)
			row.plus:setEnabled(v < S.steps)
			row.pct:set(if Music.on then SoundWindow.pct(v) else S.off)
			row.pct:color(if Music.on and v > 0 then C.text else C.dim)
		end
		mute:setText(S.mute[if Music.on then 1 else 2])
		mute:setMain(not Music.on)
		for key, b in toggles do
			b:setText(if ViewOpts[key] then V.on else V.off)
			b:setMain(ViewOpts[key] == true)
		end
	end
	view.refresh()
	return view
end

return SoundWindow
