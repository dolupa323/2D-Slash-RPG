-- 수정 틈 토벌 창 — 은달 항구 달맞이 광장의 토벌대장 무진 앞에서 ↑(2026-10-16 — 공방 design/city.js의 RIFT).
--  머리글(「수정 틈 토벌」 · 「오늘 보상 n/2」) 아래에 단계마다 한 칸: 이름(본문 글씨) · 「Lv.30부터」(못 들어가면 빨강) · 오른쪽 「입장」 /
--  그 아래 몬스터들(마지막 = 「정예 ○○」) · 완료 보상(경험치 · [달돈] · [달가루] · 「장비 25%」). 맨 아래 안내 한 줄(파티원이 함께 · 제한 시간 — 들어가지 못한 까닭).
--  들어가기는 서버가 정한다(ctx.riftDo → world.luau의 onRift). 모양은 공방 시험 탭의 js/lune/ui/paint.js(paintRift)와 같다.
--  화면 오른쪽의 옆 판(ui/windows.luau). 토벌대장에게서 멀어지면 닫힌다(boot.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Rift = require(lune.sim.rift)
local COMBAT = require(lune.data["combat.generated"])
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local S = Layout.RIFT
local D = Rift.DATA
local W = D.words
local XP = "경험치"

local RiftWindow = {}

function RiftWindow.size(): (number, number)
	return S.w, S.top + #D.tiers * S.row + S.footY + Ui.M.small + 4
end

-- 단계의 몬스터들: 「수정싹 그루터기 · 수정 달팽이 · 이끼 두꺼비 · 정예 수정 거미」
function RiftWindow.mobsText(t): string
	local names = {}
	for i, kind in t.kinds do
		local def = COMBAT.mobs[kind]
		local name = if def then def.name else kind
		table.insert(names, if i == #t.kinds then D.elite.name .. " " .. name else name)
	end
	return table.concat(names, " · ")
end

function RiftWindow.build(body: Frame, ctx, w: number, _h: number)
	local view = {}
	Ui.text(body, W.head, 0, 2, w, { color = C.gold })
	local left = Ui.text(body, "", 0, 2, w, { align = "right", color = C.accent })
	local rows = {}
	for i, t in D.tiers do
		local y = S.top + (i - 1) * S.row
		local by = y - 3 -- 「입장」은 이름 줄의 오른쪽(아래 두 줄 = 몬스터 · 보상이 창의 폭을 다 쓴다)
		if i > 1 then
			Ui.line(body, 0, y - 6, w)
		end
		local row = {}
		local nameW = math.min(Ui.measure(t.name, "body"), w - S.btnW - 76)
		row.name = Ui.text(body, t.name, 0, y, nameW + 2, { font = "body" })
		row.need = Ui.text(body, Format.fill(W.need, { lv = t.lv }), nameW + 8, y + 2, 64, { color = C.dim })
		row.button = Ui.button(body, W.enter, w - S.btnW, by, S.btnW, function()
			ctx.riftDo("enter", t.id)
		end, { main = true })
		local my = by + Ui.M.button + 3
		Ui.text(body, RiftWindow.mobsText(t), 0, my, w, { color = C.dim })
		local py = my + 16
		-- 완료 보상: 경험치 · [달돈] · [달가루] · 장비 n%
		local xpText = ("%s %s"):format(XP, Format.short(t.pay.xp))
		local x = 0
		Ui.text(body, xpText, x, py, w, { color = C.gold })
		x += Ui.measure(xpText) + 10
		Ui.smallIcon(body, "coin", x - 3, py - 4)
		x += 16
		local money = Format.short(t.pay.money)
		Ui.text(body, money, x, py, w - x, { color = C.gold })
		x += Ui.measure(money) + 10
		Ui.smallIcon(body, "dust", x - 3, py - 4)
		x += 16
		local dust = Format.short(t.pay.dust)
		Ui.text(body, dust, x, py, w - x, { color = C.gold })
		x += Ui.measure(dust) + 10
		Ui.text(body, Format.fill(W.gear, { p = math.floor(t.pay.gear * 100 + 0.5) }), x, py, w - x, { color = C.gold })
		rows[i] = row
	end
	local fy = S.top + #D.tiers * S.row - 6
	Ui.line(body, 0, fy, w)
	local note = Ui.text(body, "", 0, fy + S.footY, w, { color = C.dim })
	local base = ("%s · %s"):format(W.party, Format.fill(W.time, { m = math.floor(D.time / 60) }))

	function view.refresh()
		local me = ctx.me()
		local level = if me then me.level else 1
		local got = ctx.rift()
		local n = if got then got.left else D.perDay
		left:set(Format.fill(W.left, { n = n, max = D.perDay }))
		left:color(if n > 0 then C.accent else C.dim)
		for i, t in D.tiers do
			local open = level >= t.lv
			rows[i].name:color(if open then C.text else C.dim)
			rows[i].need:color(if open then C.dim else C.red)
			rows[i].button:setEnabled(open)
		end
		local why = got and got.why
		note:set(if why then why elseif n <= 0 then W.noPay else base)
		note:color(if why then C.red else C.dim)
	end
	view.refresh()
	return view
end

return RiftWindow
