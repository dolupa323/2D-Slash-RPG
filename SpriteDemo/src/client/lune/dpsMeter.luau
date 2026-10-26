-- 개인 연무장의 피해 측정 판(2026-10-26 사용자: "개인연무장 … 거기서 dps 측정할수있는 허수아비같은게 있는거지").
--  연무장(scene.dojo)에 있는 동안 화면 위 가운데에 뜬다: 누적 피해 · 잰 시간 · 초당 피해(누적 ÷ 잰 시간) · 가장 큰 한 방 · 「초기화」.
--  숫자는 서버가 보낸 내 타(Hits — 수련 인형이 받은 피해 그대로)를 모은 것이다. 첫 타에 재기 시작하고, idle초 동안 치지 않으면 그 판이 멈춘다(마지막 타의 때까지로 —
--  다음 타가 새로 잰다). 「초기화」 = 지금 판을 지운다. 치수 · 글 = 공방 js/lune/design/ui.js의 UILAYOUT.dojo(shared/lune/ui/layout.luau의 DOJO)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage.shared.lune.ui.format)
local Layout = require(ReplicatedStorage.shared.lune.ui.layout)
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR
local D = Layout.DOJO
local W = D.words

local Meter = {}

local root: Frame? = nil
local panel, rows, hint, resetBtn
local total, top, first, last = 0, 0, nil :: number?, nil :: number?
local stopped = false
local shown = false

-- 지금 판의 숫자(자동 검사가 본다): 누적 · 잰 시간(초) · 초당 피해 · 가장 큰 한 방 · 멈췄는가
function Meter.stats(now: number)
	if not first then
		return { total = 0, time = 0, dps = 0, top = 0, stopped = false }
	end
	local till = if stopped then last :: number else now
	local time = math.max(till - first, 0)
	return { total = total, time = time, dps = if time >= 1 then math.floor(total / time + 0.5) else total, top = top, stopped = stopped }
end

function Meter.reset()
	total, top, first, last, stopped = 0, 0, nil, nil, false
	Meter.paint(os.clock(), true)
end

-- 내 타가 수련 인형에 들었다(Hits의 한 칸 — dmg = 그 타의 피해 합)
function Meter.add(dmg: number, now: number)
	if not shown or typeof(dmg) ~= "number" or dmg <= 0 then
		return
	end
	if stopped or not first then
		total, top, first, stopped = 0, 0, now, false -- 멈춘 뒤의 첫 타 = 새로 잰다
	end
	total += dmg
	top = math.max(top, dmg)
	last = now
end

-- 판의 짜임: 맨 위 = 제목(왼쪽) · 「초기화」(오른쪽) / 숫자 넷(이름 왼쪽 · 값 오른쪽) / 맨 아래 = 안내 한 줄(판의 폭 그대로)
local ROWS_Y = D.pad + Ui.M.button + 2
local function row(i: number, label: string)
	local y = ROWS_Y + (i - 1) * D.row
	local l = Ui.text(panel, label, D.pad, y, 100, { color = C.dim })
	local v = Ui.text(panel, "", D.pad, y, D.w - D.pad * 2, { align = "right" })
	return { label = l, value = v }
end
Meter.H = ROWS_Y + 4 * D.row + 4 + 14 + D.pad -- 판의 높이

function Meter.init(parent)
	root = Ui.group(parent, 0, 0, D.w, Meter.H, "DpsMeter")
	root.Visible = shown -- (장면이 먼저 열렸으면 그대로)
	panel = Ui.panel(root, 0, 0, D.w, Meter.H)
	Ui.text(panel, W.title, D.pad, D.pad + math.floor((Ui.M.button - Ui.M.body) / 2), D.w - D.pad * 3 - D.btnW, { font = "body", color = C.accent })
	resetBtn = Ui.button(panel, W.reset, D.w - D.pad - D.btnW, D.pad, D.btnW, function()
		Meter.reset()
	end)
	rows = { total = row(1, W.total), time = row(2, W.time), dps = row(3, W.dps), top = row(4, W.top) }
	rows.dps.value:color(C.gold)
	hint = Ui.text(panel, W.hint, D.pad, ROWS_Y + 4 * D.row + 4, D.w - D.pad * 2, { color = C.dim })
	resetBtn.frame.Name = "Do_dpsReset"
	Meter.place()
end

-- 화면 위 가운데(화면 틀이 바뀌면 다시)
function Meter.place()
	if root then
		root.Position = UDim2.fromOffset(math.floor((Stage.uiW - D.w) / 2), D.top)
	end
end

-- 연무장에 들어섰다 · 나갔다(나가면 판을 지운다)
function Meter.show(on: boolean)
	shown = on
	if root then
		root.Visible = on
	end
	if not on then
		total, top, first, last, stopped = 0, 0, nil, nil, false
	else
		Meter.paint(os.clock(), true)
	end
end

-- 매 화면: idle초 동안 치지 않았으면 멈추고, 숫자를 다시 적는다
local painted = -1
function Meter.paint(now: number, force: boolean?)
	if not root or not shown or (not force and now - painted < 0.1) then
		return -- (글은 0.1초마다 — 매 화면 다시 적지 않는다)
	end
	painted = now
	if first and not stopped and last and now - last >= D.idle then
		stopped = true
	end
	local s = Meter.stats(now)
	rows.total.value:set(Format.short(s.total))
	rows.time.value:set(("%.1f초"):format(s.time))
	rows.dps.value:set(Format.short(s.dps))
	rows.top.value:set(Format.short(s.top))
	hint:set(if s.stopped then Format.fill(W.done, { n = D.idle }) elseif not first then W.hint else "")
end

return Meter
