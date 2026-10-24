-- 아이템 상세 — 가방 · 장비 창 · 창고에서 고른 아이템을 그 창 옆의 작은 판에 보여 준다. 한 번에 하나만 뜬다(다른 창에서 고르면 그쪽으로 옮겨 간다).
--  사용자 2026-10-08: "장비 탭에서 각각의 장비를 선택하면 그 해당장비가 장비창 옆에 작은모달이 떠서 아이템 스펙이 나와야합니다. 인벤토리에서 선택도 마찬가지입니다. 기타아이템, 소비아이템 모두 마찬가지입니다."
--  판의 짜임(공방 js/lune/design/ui.js의 UILAYOUT.detail — 횡스크롤 시험 탭의 paintDetail과 같은 그림):
--   위에 그림 칸과 이름(본문 글씨 — 색 = 성능 단) · 그 아래 갈래 / 줄마다 이름(흐린 글)과 값 / 알림 글(장착하면 전투력 +n …) / 단추(장착 · 사용 · 분해 · 버리기 …).
--   장비를 팔 때 · 분해할 때는 단추 자리에 묻는 글과 「팔기 · 취소」가 뜬다(spec.ask — ItemDetail.ask가 짓는다).
--   버리기 · 맡기기 · 찾기 · 팔기 · 나누기의 수는 화면 가운데의 수량 창이 정한다(ui/countBox.luau — 2026-10-21. 전에는 여기의 「-10 -1 +1 +10」이었다 — 그 그림은 아래에 남아 있지만 쓰는 곳이 없다)
--  적는 글은 shared/lune/ui/itemInfo.luau가 짓는다(공방의 gearInfo · goodsInfo와 같은 글). 판은 창들보다 위, 닫기(X)들보다 아래의 층에 뜬다.
--  PC · 스마트폰 같은 판이다 — 칸을 누르면(손가락으로 톡) 뜨고, 판의 ×나 빈 칸을 누르면 닫힌다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage.shared.lune.ui.layout)
local Format = require(ReplicatedStorage.shared.lune.ui.format)
local WORDS = require(ReplicatedStorage.shared.lune.data["ui.generated"]).words
local Stage = require(script.Parent.Parent.stage)
local Ui = require(script.Parent.ui)
local ItemCell = require(script.Parent.itemCell)
local Windows = require(script.Parent.windows)

local C = Ui.COLOR
local K = Layout.DETAIL
local M = Ui.M

local ItemDetail = {}
local STEPS = { -10, -1, 1, 10 } -- 수를 고르는 단추

local layer: Frame? = nil
local shown = nil -- { owner, key, holder }

local function root(): Frame
	if not layer then
		layer = Stage.group(Stage.ui, "ItemDetail", 156) -- 창(150) 위 · 메뉴(160) 아래
	end
	return layer :: Frame
end

-- 지금 떠 있는 판의 주인(창의 이름표 — 없으면 nil)
function ItemDetail.owner(): string?
	return if shown then shown.owner else nil
end

-- 판을 닫는다. owner를 주면 그 창의 것일 때만
function ItemDetail.hide(owner: string?)
	if shown and (owner == nil or shown.owner == owner) then
		shown.holder:Destroy()
		shown = nil
	end
end

-- 수를 고르는 줄(spec.ask)을 짓는다. kind = 하는 일(WORDS.ask의 이름표: "discard" · "store" · "take" · "sell" · "split" · "sellGear") · n = 지금 고른 수(nil이면 수를 고르지 않는다 — 장비 팔기) ·
--  lo · hi = 고를 수 있는 범위 · o = { set(n) 수를 고쳤다, yes(n) 한다, no() 그만둔다, gain(n) → 팔 때 받을 달돈(묻는 글 뒤에 붙는다) }
function ItemDetail.ask(kind: string, n: number?, lo: number, hi: number, o)
	local words = WORDS.ask[kind]
	local text = words[1]
	if o.gain then
		text = text .. "  " .. Format.fill(WORDS[o.gainWord or "gain"], { n = Format.short(o.gain(n or 1)) }) -- gainWord = 받을 것의 글(분해 = 「달가루 +n」 — 2026-10-18)
	end
	local steps = nil
	if n then
		steps = {}
		for i, d in STEPS do
			steps[i] = { text = if d > 0 then "+" .. d else tostring(d), onClick = function()
				o.set(math.clamp(n + d, lo, hi))
			end }
		end
	end
	return {
		text = text,
		n = n,
		steps = steps,
		yes = { text = words[2], onClick = function()
			o.yes(n)
		end },
		no = { text = WORDS.askNo, onClick = o.no },
	}
end

-- 글의 줄 수(그려진 높이에서)
local function linesOf(label, line: number): number
	local _, h = label:size()
	return math.max(1, math.floor(h / line + 0.5))
end

-- 판을 띄운다(이미 같은 것이 떠 있으면 자리만 다시 맞춘다).
--  owner = 주인 창의 이름표 · spec = { key(달라지면 다시 그린다), info(ItemInfo의 것), item(칸에 그릴 장비 · 묶음), buttons = { { text, main?, off?, onClick } … },
--                                    ask = { text, n, steps = { { text, onClick } … 넷 }, yes = { text, onClick }, no = { text, onClick } }?, onClose }
function ItemDetail.show(owner: string, spec)
	local at = Windows.beside(owner, K.w, K.gap)
	if not at then
		ItemDetail.hide(owner)
		return
	end
	if shown and shown.owner == owner and shown.key == spec.key then
		shown.holder.Position = at
		return
	end
	ItemDetail.hide(nil)
	local info = spec.info
	local S = ItemCell.size()
	local inner = Layout.detailInner()
	local holder = Stage.place(root(), "Detail_" .. owner, "tr", 0, 0, K.w, 10)
	holder.Position = at
	local panel = Ui.panel(holder, 0, 0, K.w, 10)
	-- 판을 누른 것이 그 밑의 것(게임 화면 · 다른 창)으로 새지 않게
	local shield = Ui.hit(panel)
	shield.ZIndex = 1
	shield.Name = "Shield"

	-- 장비의 별(맨 위 — 2026-10-15: 이름 옆의 「+n」 대신 1성에 별 하나 · 22성까지의 빈 별도 흐리게)
	local top = K.pad
	if info.stars ~= nil and (info.starMax or 0) > 0 then
		local starRows = math.ceil(info.starMax / 15)
		Ui.stars(panel, K.pad, K.pad, inner, "center"):set(info.stars, info.starMax)
		top += Layout.detailStarsH(starRows)
	end
	-- 그림 칸 · 이름 · 갈래 · 닫기
	local cell = ItemCell.new(panel, K.pad, top, function() end, S)
	cell:set(spec.item, {})
	cell.hit.Active = false
	local nameX = K.pad + S + 8
	local name = Ui.text(panel, info.name, nameX, top, Layout.detailNameW(Stage.ratio), { font = "body", lines = K.nameLines, line = K.nameLine, color = C[info.tone] or C.text })
	local nameLines = linesOf(name, K.nameLine)
	Ui.text(panel, info.sub, nameX, top + nameLines * K.nameLine + K.subGap, inner - S - 8, { color = C.dim })
	Ui.closeButton(panel, K.w - K.pad - 10, K.pad, function()
		if spec.onClose then
			spec.onClose()
		else
			ItemDetail.hide(owner)
		end
	end).ZIndex = 12
	local y = top + math.max(S, nameLines * K.nameLine + K.subGap + M.small)

	-- 줄: 이름(흐린 글)과 값
	Ui.line(panel, K.pad, y + math.floor(K.rowTop / 2), inner)
	y += K.rowTop
	for _, row in info.rows do
		Ui.text(panel, row[1], K.pad, y + 3, K.labelW, { color = C.dim })
		Ui.text(panel, row[2], K.pad + K.labelW, y + 3, Layout.detailValueW(), { color = C[row[3]] or C.text })
		y += K.rowH
	end

	-- 알림 글
	if #info.notes > 0 then
		Ui.line(panel, K.pad, y + math.floor(K.noteTop / 2), inner)
		y += K.noteTop
		for _, note in info.notes do
			local label = Ui.text(panel, note[1], K.pad, y + 2, inner, { lines = K.noteLines, line = K.noteLine, color = C[note[2]] or C.text })
			y += linesOf(label, K.noteLine) * K.noteLine
		end
	end

	-- 단추 — 또는 버릴 수를 고르는 줄
	local ask = spec.ask
	if ask then
		y += K.btnTop
		Ui.text(panel, ask.text, K.pad, y, inner, { color = C.gold })
		y += M.smallLine + 4
		if ask.steps then
			-- [-10] [-1]  수  [+1] [+10]
			local step = K.stepW
			local xs = { 0, step + K.btnGap, inner - step * 2 - K.btnGap, inner - step }
			for i, s in ask.steps do
				Ui.button(panel, s.text, K.pad + xs[i], y, step, s.onClick, { font = "small" }).frame.Name = "Step" .. i
			end
			local mid = xs[2] + step
			Ui.text(panel, tostring(ask.n), K.pad + mid, y + math.floor((M.button - M.body) / 2), xs[3] - mid, { font = "body", align = "center" })
			y += M.button + K.btnGap
		end
		local half = Layout.detailButtonW(2)
		Ui.button(panel, ask.yes.text, K.pad, y, half, ask.yes.onClick, { main = true }).frame.Name = "Yes"
		Ui.button(panel, ask.no.text, K.pad + half + K.btnGap, y, half, ask.no.onClick).frame.Name = "No"
		y += M.button
	elseif #spec.buttons > 0 then
		-- 고르기 단추(spec.chips — 여러 개 판매의 등급 · 2026-10-23): { text, on = 켜짐(민트) · off = 없음(흐림) · onClick } — 셋씩 줄을 바꾼다
		if spec.chips and #spec.chips > 0 then
			y += K.btnTop
			local cw = Layout.detailButtonW(K.btnCols)
			for i, c in spec.chips do
				local col, row = (i - 1) % K.btnCols, (i - 1) // K.btnCols
				local chip = Ui.button(panel, c.text, K.pad + col * (cw + K.btnGap), y + row * (M.button + K.btnGap), cw, c.onClick, { main = c.on == true })
				chip.frame.Name = "Chip" .. i
				chip:setEnabled(not c.off)
			end
			local rows = math.ceil(#spec.chips / K.btnCols)
			y += rows * M.button + (rows - 1) * K.btnGap
		end
		y += K.btnTop
		local n = #spec.buttons
		local perRow = math.min(n, K.btnCols)
		local bw = Layout.detailButtonW(perRow)
		for i, b in spec.buttons do
			local col, row = (i - 1) % perRow, (i - 1) // perRow
			local button = Ui.button(panel, b.text, K.pad + col * (bw + K.btnGap), y + row * (M.button + K.btnGap), bw, b.onClick, { main = b.main == true })
			button.frame.Name = "Do" .. i
			button:setEnabled(not b.off)
		end
		local rows = math.ceil(n / perRow)
		y += rows * M.button + (rows - 1) * K.btnGap
	end
	local h = y + K.pad
	holder.Size = UDim2.fromOffset(K.w, h)
	panel.Size = UDim2.fromOffset(K.w, h)
	local back = panel:FindFirstChild("Back")
	if back then
		(back :: ImageLabel).Size = UDim2.fromOffset(K.w, h)
	end
	shown = { owner = owner, key = spec.key, holder = holder }
end

return ItemDetail
