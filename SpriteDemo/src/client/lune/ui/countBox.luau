-- 수량 창 — 수를 정해야 하는 일(사기 · 팔기 · 버리기 · 맡기기 · 찾기 · 나누기)을 누르면 화면 가운데에 뜬다(메이플스토리의 수량 창처럼).
--  사용자 2026-10-21: "잡화상점에서 물약이나 달가루 구매할때 1개 아니면 10개밖에 못사잖아 이거 수량 입력하는 모달 받아서 처리해야지 이렇게하면안되는거야 모든 곳에서 수량받아서 처리해"
--  전에는 상점이 「1 · 10」 단추, 가방 · 창고는 상세 판의 「-10 -1 +1 +10」이었다. 경매장은 그 창 안의 수량 칸 그대로(이미 적는다).
--  짜임(공방 js/lune/design/ui.js의 UILAYOUT.count — 횡스크롤 시험 탭의 paintCount와 같은 그림):
--   묻는 글(WORDS.ask — 노랑) · [그림] 이름 · [−] [수량 칸] [+] [최대] · 왼쪽 「1 ~ 99개」 · 오른쪽 합계(살 때 — 모자라면 빨강) / 받을 달돈(팔 때) · 「사기 · 취소」
--  수량 칸에 바로 적는다(숫자만 · 최대를 넘으면 최대로 · 비면 확인이 눌리지 않는다 — 셈은 shared/lune/ui/countPick.luau) · Enter = 확인. PC에서는 열리자마자 칸에 적을 수 있다(적힌 수가 골라져 있다)
--  창 밖은 눌리지 않는다(어두운 막) · 한 번에 하나 — 그 창(owner)이 닫히면 같이 닫힌다(CountBox.hide(owner))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local lune = ReplicatedStorage.shared.lune
local Layout = require(lune.ui.layout)
local Format = require(lune.ui.format)
local CountPick = require(lune.ui.countPick)
local WORDS = require(lune.data["ui.generated"]).words
local Stage = require(script.Parent.Parent.stage)
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local M = Ui.M
local K = Layout.COUNT
local KW = K.words

local CountBox = {}

local layer: Frame? = nil
local shown = nil -- { owner, holder, field, yes(), no(), n }

local function root(): Frame
	if not layer then
		layer = Stage.group(Stage.ui, "CountBox", 170) -- 상세 판(156) · 메뉴(160) 위
	end
	return layer :: Frame
end

function CountBox.shown(): boolean
	return shown ~= nil
end

-- 지금 떠 있는 창의 주인(없으면 nil)
function CountBox.owner(): string?
	return if shown then shown.owner else nil
end

-- 닫는다. owner를 주면 그 창의 것일 때만
function CountBox.hide(owner: string?)
	if shown and (owner == nil or shown.owner == owner) then
		shown.holder:Destroy()
		shown = nil
	end
end

-- 띄운다. spec = {
--   owner = 띄운 창("shop" · "bag" · "store") · kind = 하는 일(WORDS.ask의 이름표) · icon = 그림의 이름 · name = 이름
--   hi = 고를 수 있는 가장 많은 수(1 이상) · n = 처음 수(없으면 CountPick.first) · each = 하나의 값(살 때 — 합계) · money = 가진 달돈(살 때)
--   gainEach = 하나를 팔 때 받는 달돈(팔 때) · onYes = function(n) 확인했을 때 · onNo = function() 취소했을 때(없어도 된다) }
function CountBox.open(spec)
	CountBox.hide()
	local words = WORDS.ask[spec.kind]
	local lo, hi = 1, math.max(1, spec.hi)
	local holder = Stage.group(root(), "Box", 1)
	-- 어두운 막: 창 밖을 누르지 못한다(누르면 아무 일도 없다)
	local veil = Instance.new("TextButton")
	veil.Name = "Veil"
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 0.55
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.Parent = holder
	local box = Instance.new("Frame")
	box.Name = "Box"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(K.w, K.h)
	box.Parent = holder
	local panel = Ui.panel(box, 0, 0, K.w, K.h)
	local inner = K.w - K.pad * 2
	Ui.text(panel, words[1], K.pad, K.titleY, inner, { font = "body", color = C.gold })
	local slot = Ui.slot(panel, K.pad, K.itemY, K.iconS)
	Ui.smallIcon(slot.frame, spec.icon or "coin", math.floor((K.iconS - 18) / 2), math.floor((K.iconS - 18) / 2))
	Ui.text(panel, spec.name or "", K.pad + K.iconS + 6, K.itemY + math.floor((K.iconS - M.body) / 2), inner - K.iconS - 6, { font = "body" })
	-- [−] [수량 칸] [+] … [최대]
	local x = K.pad
	local field
	local n: number? = nil
	local paint
	local function setN(v: number?)
		n = v
		local text = if v then tostring(v) else ""
		if field.Text ~= text then
			field.Text = text
		end
		paint()
	end
	local minus = Ui.button(panel, "-", x, K.fieldY, K.stepW, function()
		setN(CountPick.step(n, -1, lo, hi))
	end)
	minus.frame.Name = "Minus"
	x += K.stepW + K.gap
	field = Ui.field(panel, x, K.fieldY, K.fieldW, M.button, "")
	field.Name = "CountInput"
	field.TextXAlignment = Enum.TextXAlignment.Center
	x += K.fieldW + K.gap
	local plus = Ui.button(panel, "+", x, K.fieldY, K.stepW, function()
		setN(CountPick.step(n, 1, lo, hi))
	end)
	plus.frame.Name = "Plus"
	Ui.button(panel, KW.max, K.pad + inner - K.maxW, K.fieldY, K.maxW, function()
		setN(hi)
	end).frame.Name = "Max"
	Ui.text(panel, Format.fill(KW.range, { lo = lo, hi = hi }), K.pad, K.noteY, math.floor(inner / 2), { color = C.dim })
	local sum = Ui.text(panel, "", K.pad + math.floor(inner / 2), K.noteY, inner - math.floor(inner / 2), { align = "right", color = C.gold })
	local half = math.floor((inner - 6) / 2)
	local state = { owner = spec.owner, holder = holder, field = field }
	local function yes()
		if not n or n < lo or n > hi then
			return
		end
		if spec.each and spec.money and spec.each * n > spec.money then
			return
		end
		local count = n
		CountBox.hide()
		spec.onYes(count)
	end
	local function no()
		CountBox.hide()
		if spec.onNo then
			spec.onNo()
		end
	end
	local yesBtn = Ui.button(panel, words[2], K.pad, K.buttonY, half, yes, { main = true })
	yesBtn.frame.Name = "Yes"
	Ui.button(panel, WORDS.askNo, K.pad + half + 6, K.buttonY, inner - half - 6, no).frame.Name = "No"
	paint = function()
		local ok = n ~= nil and n >= lo and n <= hi
		if spec.each then
			local total = spec.each * (n or 0)
			local short = spec.money ~= nil and total > spec.money
			sum:set(if short then KW.short else Format.fill(KW.cost, { n = Format.comma(total) }))
			sum:color(if short then C.red else C.gold)
			ok = ok and not short
		elseif spec.gainEach then
			sum:set(Format.fill(KW.gain, { n = Format.comma(spec.gainEach * (n or 0)) }))
		else
			sum:set("")
		end
		yesBtn:setEnabled(ok)
		minus:setEnabled(n ~= nil and n > lo)
		plus:setEnabled(n == nil or n < hi)
		state.n = n
	end
	field:GetPropertyChangedSignal("Text"):Connect(function()
		local text, v = CountPick.parse(field.Text, hi)
		if text ~= field.Text then
			field.Text = text -- 다시 불린다
			return
		end
		n = v
		paint()
	end)
	field.FocusLost:Connect(function(enter: boolean)
		if enter then
			yes()
		end
	end)
	state.yes, state.no = yes, no
	shown = state
	setN(math.clamp(spec.n or CountPick.first(spec.kind, hi), lo, hi))
	-- PC: 열리자마자 칸에 적는다(적힌 수가 골라져 있어 바로 고쳐 적힌다). 폰은 칸을 눌러야 자판이 뜬다
	if not UserInputService.TouchEnabled or UserInputService.KeyboardEnabled then
		pcall(function()
			field:CaptureFocus()
			field.SelectionStart = 1
			field.CursorPosition = #field.Text + 1
		end)
	end
	return state
end

-- (시험용 · 화면이 부르는 것과 같다) 칸에 적은 것처럼 · 확인 · 취소 · 지금의 수
function CountBox.type(text: string)
	if shown then
		shown.field.Text = text
	end
end
function CountBox.yes()
	if shown then
		shown.yes()
	end
end
function CountBox.no()
	if shown then
		shown.no()
	end
end
function CountBox.value(): number?
	return if shown then shown.n else nil
end

return CountBox
