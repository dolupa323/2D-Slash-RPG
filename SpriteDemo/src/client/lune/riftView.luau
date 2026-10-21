-- 수정 틈 토벌 중의 화면(2026-10-16 — 공방 시험 탭의 P.paintRiftHud · P.paintRiftEnd와 같은 자리 · 모양).
--  화면 위 가운데의 판: 윗줄 = 단계의 이름(금색)과 남은 시간(1분 아래면 빨강) · 아랫줄 = 「물결 2/4 · 남은 몬스터 6」(마지막 물결은 「정예」) · 「곧 몰려온다」 · 「토벌 완료」 · 「시간이 다 됐다」.
--  끝나면 가운데의 판: 「토벌 완료」와 받은 것(경험치 · 달돈 · 달가루 · 장비) — 오늘 보상을 다 받았으면 그 말 / 「시간이 다 됐다」 · 아래 「n초 뒤 광장으로」.
--  무엇이 언제 바뀌는지는 서버가 정한다(sim/rift.luau — RiftView · RiftPay). 여기서는 받은 것을 그리고, 시계만 받은 뒤로 흐르게 한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Rift = require(lune.sim.rift)
local Layout = require(lune.ui.layout)
local Format = require(lune.ui.format)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR
local M = Ui.M
local D = Rift.DATA
local W = D.words
local ROWS = 4 -- 끝의 판의 줄(경험치 · 달돈 · 달가루 · 장비)

local RiftView = {}
RiftView.view = nil -- 서버가 마지막으로 알린 상태(Rift.view) — 토벌의 방에 있을 때만
RiftView.since = 0 -- 그것을 받은 뒤로 흐른 시간(초)
RiftView.paid = nil -- 완료의 보상(RiftPay)

function RiftView.init(root: Frame)
	local H = Layout.RIFT_HUD
	local box = Stage.place(root, "Rift", "tc", math.floor((Stage.REF_W - H.w) / 2), H.y, H.w, H.h)
	box.Visible = false
	Ui.panel(box, 0, 0, H.w, H.h)
	RiftView.box = box
	RiftView.name = Ui.text(box, "", 10, 6, H.w - 70, { color = C.gold })
	RiftView.clock = Ui.text(box, "", 10, 6, H.w - 20, { align = "right" })
	RiftView.what = Ui.text(box, "", 10, 21, H.w - 20)
	-- 끝의 판(완료 · 실패)
	local E = Layout.RIFT_END
	local eh = E.pad * 2 + M.body + 8 + ROWS * E.row + M.small + 6
	local eb = Stage.place(root, "RiftEnd", "tc", math.floor((Stage.REF_W - E.w) / 2), math.floor((Stage.REF_H - eh) / 2) - 20, E.w, eh)
	eb.Visible = false
	RiftView.endBox, RiftView.endH = eb, eh
	RiftView.endPanel = Ui.panel(eb, 0, 0, E.w, eh)
	RiftView.title = Ui.text(eb, "", 0, E.pad, E.w, { font = "body", align = "center" })
	RiftView.rows = {}
	for i = 1, ROWS do
		local ry = E.pad + M.body + 8 + (i - 1) * E.row
		local icon = Ui.smallIcon(eb, "coin", E.pad - 3, ry - 4)
		icon.Visible = false
		RiftView.rows[i] = { icon = icon, text = Ui.text(eb, "", E.pad, ry, E.w - E.pad * 2, { color = C.gold }), y = ry }
	end
	RiftView.back = Ui.text(eb, "", 0, eh - E.pad - M.small + 2, E.w, { align = "center", color = C.dim })
end

-- 토벌의 방에 들어섰다 · 나왔다(view = 방의 rift — 없으면 숨긴다)
function RiftView.enter(view: any)
	RiftView.view, RiftView.since, RiftView.paid = view, 0, nil
	RiftView.box.Visible = view ~= nil
	RiftView.endBox.Visible = false
	RiftView.draw()
end
-- 서버가 상태를 알렸다
function RiftView.set(view: any)
	if not RiftView.view then
		return
	end
	RiftView.view, RiftView.since = view, 0
	RiftView.draw()
end
-- 완료의 보상이 왔다
function RiftView.pay(p: any)
	RiftView.paid = p
	RiftView.draw()
end

local function row(i: number, icon: string?, text: string, color: Color3?)
	local r = RiftView.rows[i]
	r.icon.Visible = icon ~= nil
	if icon then
		Ui.setWorldIcon(r.icon, icon)
	end
	r.text:move(Layout.RIFT_END.pad + (if icon then 16 else 0), r.y)
	r.text:set(text)
	r.text:color(color or C.gold)
end

-- 그린다(받았을 때 · 1초마다 — 시계와 「n초 뒤」)
function RiftView.draw()
	local v = RiftView.view
	if not v then
		return
	end
	local t = Rift.tier(v.tier)
	local run = v.state == "run"
	local rest = math.max(0, v.time - (v.t + (if run then RiftView.since else 0)))
	RiftView.name:set(if t then t.name else "")
	RiftView.clock:set(("%d:%02d"):format(math.floor(rest / 60), math.floor(rest % 60)))
	RiftView.clock:color(if rest < 60 then C.red else C.text)
	local DW = Rift.DUNGEON.words -- 던전(2026-10-21 — 수정 거울숲)의 글
	local dg = v.dungeon == true
	local what
	if v.state == "wait" then
		what = W.ready
	elseif v.state == "clear" then
		what = if dg then DW.clear else W.clear
	elseif v.state == "fail" then
		what = if dg then DW.fail else W.fail
	else
		what = (if v.wave >= v.waves then W.eliteWave else Format.fill(W.wave, { a = v.wave, b = v.waves })) .. " · " .. Format.fill(W.mobs, { n = v.left })
	end
	RiftView.what:set(what)
	RiftView.what:color(if v.state == "clear" then C.green elseif v.state == "fail" then C.red else C.text)
	-- 끝의 판
	local over = v.state == "clear" or v.state == "fail"
	RiftView.endBox.Visible = over
	if not over then
		return
	end
	RiftView.title:set(if v.state == "clear" then (if dg then DW.clear else W.clear) else (if dg then DW.fail else W.fail))
	RiftView.title:color(if v.state == "clear" then C.green else C.red)
	for i = 1, ROWS do
		row(i, nil, "")
	end
	local p = RiftView.paid
	if v.state == "clear" and p and dg then
		-- 던전: 경험치 한 줄(오늘 이미 끝냈으면 그 말)
		if p.none then
			row(1, nil, DW.done, C.dim)
		else
			row(1, nil, ("경험치 %s"):format(Format.comma(p.xp or 0)))
		end
	elseif v.state == "clear" and p then
		if p.none then
			row(1, nil, W.noPay, C.dim)
		else
			row(1, nil, ("경험치 %s"):format(Format.short(p.xp)))
			row(2, "coin", Format.short(p.money))
			row(3, "dust", Format.short(p.dust))
			if p.gear then
				row(4, nil, p.gearName or "")
			else
				row(4, nil, if p.full then W.full else W.nogear, C.dim)
			end
		end
	end
	local wait = (if v.state == "clear" then (v.back or D.back) else Rift.FAIL_BACK) - (v.after + RiftView.since)
	local n = math.max(0, math.ceil(wait))
	RiftView.back:set(if dg then Format.fill(DW.back, { s = n }) else Format.fill(W.back, { n = n }))
end

-- 매 장면(boot의 LuneFrame): 받은 뒤로 흐른 시간 — 초가 바뀔 때만 다시 그린다
function RiftView.update(dt: number)
	if not RiftView.view then
		return
	end
	local before = math.floor(RiftView.since)
	RiftView.since += dt
	if math.floor(RiftView.since) ~= before then
		RiftView.draw()
	end
end

return RiftView
