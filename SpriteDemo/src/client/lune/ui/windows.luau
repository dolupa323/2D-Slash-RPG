-- 창 관리 — 창을 열고 닫고, 한 번에 둘까지 화면의 오른쪽과 왼쪽에 하나씩 놓는다(넓은 창은 혼자 쓴다 — 가운데의 캐릭터는 늘 보인다). 창의 이름과 여는 키는 공방에서 정한 것(data/ui.generated.luau).
--  창은 화면 틀의 층(고운 격자)에 뜨는 오른쪽 옆 판이다 — 가운데의 캐릭터를 가리지 않는다(던그리드의 가방처럼. 사용자 2026-10-07의 시안 승인).
--  창마다 build(body, ctx, w, h, arg) → { refresh(me), destroy() } 꼴의 모듈을 등록한다. 서버가 내 상태를 다시 보내면 열려 있는 창을 고쳐 그린다.
--   창의 크기는 모듈의 size(arg) → 속의 폭 · 높이(없으면 기본). 장비 칸이 든 창은 칸의 크기(화면 틀의 배율을 따른다)로 정한다.
--  닫기는 ×나 여는 키를 한 번 더. (Esc는 Roblox가 제 메뉴에 쓴다 — 게임이 받지 못한다)
--  창은 처음부터 다 보이지 않는다 — 공방에서 정한 레벨(from)이 되어야 열린다(능력치 · 스킬은 Lv.2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local UI = require(ReplicatedStorage.shared.lune.data["ui.generated"])
local Layout = require(ReplicatedStorage.shared.lune.ui.layout)
local Stage = require(script.Parent.Parent.stage)
local Ui = require(script.Parent.ui)

local TOP, EDGE = Layout.WIN.top, Layout.WIN.edge -- 화면 위 · 옆 끝에서 띄우는 폭
-- 창 끌기(2026-11-12): DRAG_H = 제목 줄(끄는 곳 · 늘 화면 안) · KEEP_W = 창이 왼쪽 · 아래로 화면 밖에 나가도 화면 안에 남는 폭(다시 잡을 수 있게) [제가 정한 것]
local DRAG_H, KEEP_W = 30, 90
local BODY_W, BODY_H = Ui.WIN.w - Ui.WIN.pad * 2, 300 -- 크기를 따로 정하지 않은 창의 속

local Windows = {}

local defs = {} -- [id] = { name, key, wide, size, build }
local open = {} -- 열린 차례대로 { id, win, view, arg, w, h, side("right" · "left") }
local root: Frame = nil
-- 닫기(X)를 누르는 자리: 창들보다, 그 위에 뜨는 다른 판(메뉴 · 놓을 것의 목록 · 손가락 단추)보다도 위의 층에 따로 둔다 —
--  창이 다른 것과 겹쳐도 닫기가 먼저 눌린다(사용자 2026-10-08: "겹쳐있을때 x 닫기버튼이 우선판정으로 눌려서 닫을수있어야합니다" — PC · 스마트폰 모두).
--  손가락으로도 누르기 쉽게 X 그림보다 넓게 받는다.
local closers: Frame = nil
local CLOSE_HIT = 40
local ctx = nil
local level = 1 -- 내 레벨(이 레벨에 열린 창만 쓴다)
Windows.extra = {} :: { [string]: boolean } -- 레벨과 상관없이 쓸 수 있는 창(튜토리얼의 꿈: Lv.1에도 가방 — 「가방 열기」 미션 · 2026-10-14)

-- 열린 창을 제 쪽 끝에 놓는다: 오른쪽 창은 화면 오른쪽 끝에, 왼쪽 창은 왼쪽 끝에(가운데의 캐릭터를 가리지 않는다)
--  2026-11-12(사용자: "지금 채팅창처럼 모든 ui 가 끌어서 자리를 옮길수 있어야해 지금 모바일에서 잘려보이는경우 엄청많아"):
--   ① 제목 줄을 끌어 옮긴 만큼(Stage.moved["Window_<창>"] — 기기 종류마다 계정에 저장)을 더한다 ② 화면 밖으로 나가지 않는다(Stage.fit)
--   ③ 창이 화면 틀보다 크면(폰의 작은 격자 768x432) 화면에 들어가게 줄인다(UIScale — 닫기 X의 자리도 같이)
local function layout()
	for _, o in open do
		local k = math.min(1, (Stage.uiW - 2) / o.w, (Stage.uiH - 2) / o.h)
		if k < 1 then
			if not o.scale then
				o.scale = Instance.new("UIScale")
				o.scale.Parent = o.holder
			end
			o.scale.Scale = k
		elseif o.scale then
			o.scale.Scale = 1
		end
		o.k = k
		local vw, vh = o.w * k, o.h * k
		-- 옮긴 만큼 + 느슨하게 화면 안(Stage.fitLoose — 2026-11-12 사용자 "모바일에서 어느정도 터치보정이 되어야해 … 너무판정이 빡세다": 창이 반쯤 화면 밖이어도 된다 · 제목 줄과 닫기 X는 늘 화면 안)
		local at, bx = "tr", Stage.REF_W - EDGE - vw
		if o.side == "left" then
			at, bx = "tl", EDGE
		end
		local off = Stage.moved[o.holder.Name]
		local px, py = Stage.fitLoose(at, bx + (if off then off.x else 0), TOP + (if off then off.y else 0), vw, vh, KEEP_W, DRAG_H)
		o.holder.Position = Stage.atPosition(at, px, py)
		if o.closer then
			-- X 그림(창의 오른쪽 위, 한 변 10쯤)의 한가운데에 맞춘다
			o.closer.Position = o.holder.Position + UDim2.fromOffset((o.w - Ui.WIN.pad - 5) * k - CLOSE_HIT / 2, 18 * k - CLOSE_HIT / 2)
		end
	end
end
Windows.onMoved = nil :: (() -> ())? -- 창을 끌어 옮겼다(boot가 단다 — 계정의 화면 설정에 저장)
-- 다시 놓는다(「화면 배치 — 처음대로」 뒤에)
function Windows.relayout()
	layout()
end
-- 창의 기준 자리(옮기기 전 · 지금 크기): at, x, y, 보이는 폭 · 높이
local function baseOf(o): (string, number, number, number, number)
	local k = o.k or 1
	local vw, vh = o.w * k, o.h * k
	if o.side == "left" then
		return "tl", EDGE, TOP, vw, vh
	end
	return "tr", Stage.REF_W - EDGE - vw, TOP, vw, vh
end
-- 제목 줄(닫기 X 왼쪽까지)을 끌면 창이 옮겨진다 · 두 번 누르면 처음 자리(마우스만 — 2026-11-12: 손가락은 끌다 다시 잡는 것이 「두 번」으로 잡혀 제자리로 돌아갔다 ·
--  폰은 메뉴의 「화면 배치 → 처음대로」) · 손가락은 4점 넘게 움직여야 끌기를 시작한다(누르기만 한 것에 창이 떨리지 않게)
local function attachDrag(o)
	local zone = Instance.new("TextButton")
	zone.Name = "Drag"
	zone.Text = ""
	zone.AutoButtonColor = false
	zone.BackgroundTransparency = 1
	zone.Size = UDim2.fromOffset(math.max(10, o.w - Ui.WIN.pad - 24), DRAG_H)
	zone.ZIndex = 40
	zone.Parent = o.holder
	local start, active, base, lastDown = nil, nil, nil, -9
	local moving = false
	zone.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and os.clock() - lastDown < 0.35 then -- 두 번 눌렀다(마우스): 처음 자리로
			lastDown = -9
			start, active = nil, nil
			Stage.moved[o.holder.Name] = nil
			layout()
			if Windows.onMoved then
				Windows.onMoved()
			end
			return
		end
		lastDown = os.clock()
		start, active, moving = Vector2.new(input.Position.X, input.Position.Y), input, false
		base = Stage.moved[o.holder.Name] or { x = 0, y = 0 }
	end)
	o.conns = {
		UserInputService.InputChanged:Connect(function(input)
			if not start or not active then
				return
			end
			if not (input == active or (active.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)) then
				return
			end
			local us = math.max(Stage.uiScale or 1, 0.01)
			local dx, dy = (input.Position.X - start.X) / us, (input.Position.Y - start.Y) / us
			if active.UserInputType == Enum.UserInputType.Touch and not moving and math.abs(dx) + math.abs(dy) < 4 then
				return -- (손가락: 조금 움직인 것은 끌기가 아니다)
			end
			moving = true
			local at, x, y, vw, vh = baseOf(o)
			local fx, fy = Stage.fitLoose(at, x + base.x + dx, y + base.y + dy, vw, vh, KEEP_W, DRAG_H)
			local ox, oy = math.floor(fx - x + 0.5), math.floor(fy - y + 0.5)
			Stage.moved[o.holder.Name] = if ox == 0 and oy == 0 then nil else { x = ox, y = oy }
			layout()
		end),
		UserInputService.InputEnded:Connect(function(input)
			if start and (input == active or input.UserInputType == Enum.UserInputType.MouseButton1) then
				start, active = nil, nil
				if Windows.onMoved then
					Windows.onMoved()
				end
			end
		end),
	}
end

local function at(side: string)
	for _, o in open do
		if o.side == side then
			return o
		end
	end
	return nil
end

local function other(side: string): string
	return if side == "right" then "left" else "right"
end

-- 창들이 쓰는 ctx(boot가 준 것 — 달빛 상점의 공간이 같은 것을 쓴다: cashShop.luau · 2026-10-21)
function Windows.context()
	return ctx
end

function Windows.init(context)
	ctx = context
	root = Stage.group(Stage.ui, "Windows", 150)
	closers = Stage.group(Stage.ui, "Closers", 300)
	-- 화면 틀의 배율이 바뀌면 창의 크기가 달라진다 — 다 닫는다(다시 열면 새 크기로 뜬다)
	--  배율은 그대로이고 Roblox 단추 띠가 덮는 높이만 바뀐 것(scaled == false — 2026-11-10에 stage.luau가 이때도 부르게 됐다)에는 닫지 않는다(2026-11-11 밤 — 사용자:
	--  "모바일에서 경매장 액수라던지 뭐 다른 숫자를 입력해야하는 소요가 생기면 그냥 와다다 ui 가 꺼져버리는 버그" — 화면 키보드가 화면 높이를 바꿔 창이 모두 닫혔다)
	Stage.onResize(function(scaled: boolean?)
		if scaled == false then
			return
		end
		while #open > 0 do
			Windows.close(open[1].id)
		end
	end)
end

-- 창 층을 달빛 상점의 공간(층 500) 위로 올린다 · 되돌린다(2026-11-10 사용자 "확률보기 눌러도 뭐뜨는게 없고" — 공간 안에서 연 「확률 보기」 창이
--  층 150이라 공간 뒤에 떠서 보이지 않았다). cashShop.luau가 들어갈 때 true · 나올 때 false
Windows.RAISED = 550
function Windows.raise(on: boolean)
	if root then
		root.ZIndex = if on then Windows.RAISED else 150
	end
	if closers then
		closers.ZIndex = if on then Windows.RAISED + 10 else 300
	end
end
function Windows.layerZ(): number?
	return if root then root.ZIndex else nil
end

-- 창을 등록한다. def = { wide = 넓은 창인가, side = 늘 그쪽에 뜨는 창("right" — 가방), size = function(arg) → 속의 폭 · 높이, build = function(body, ctx, w, h, arg) → { refresh(me), destroy() } }
function Windows.register(id: string, def)
	local info = nil
	for _, w in UI.windows do
		if w.id == id then
			info = w
		end
	end
	assert(info, "공방에 없는 창 " .. id)
	def.name = info.name
	def.key = info.key
	def.from = info.from or 1
	defs[id] = def
end

-- 아직 열리지 않은 창인가
function Windows.locked(id: string): boolean
	local def = defs[id]
	return def == nil or (def.from > level and not Windows.extra[id])
end

-- 다른 캐릭터로 들어왔다: 그 캐릭터의 레벨에서 다시 센다(열려 있던 창은 부른 쪽이 먼저 닫는다 — 낮은 레벨의 캐릭터에게는 아직 열리지 않은 창이 있다)
function Windows.resetLevel(now: number)
	level = now
end

-- 내 레벨을 알린다. 이번에 새로 열린 창의 이름표(id)들을 돌려준다
function Windows.setLevel(now: number): { string }
	local fresh = {}
	for _, w in UI.windows do
		local def = defs[w.id]
		if def and def.from > level and def.from <= now then
			table.insert(fresh, w.id)
		end
	end
	level = math.max(level, now)
	return fresh
end

function Windows.info(id: string)
	return defs[id]
end

function Windows.isOpen(id: string): boolean
	for _, o in open do
		if o.id == id then
			return true
		end
	end
	return false
end

function Windows.anyOpen(): boolean
	return #open > 0
end

-- 그쪽("right" · "left") 끝에 창이 떠 있는가(오른쪽 창은 오른쪽 위의 퀘스트 알리미를 덮는다)
function Windows.sideOpen(side: string): boolean
	return at(side) ~= nil
end

function Windows.close(id: string)
	for i, o in open do
		if o.id == id then
			if o.view and o.view.destroy then
				o.view.destroy()
			end
			for _, c in o.conns or {} do
				c:Disconnect()
			end
			o.holder:Destroy()
			if o.closer then
				o.closer:Destroy()
			end
			table.remove(open, i)
			layout()
			if ctx.changed then
				ctx.changed()
			end
			return
		end
	end
end

function Windows.closeTop(): boolean
	local top = open[#open]
	if top then
		Windows.close(top.id)
		return true
	end
	return false
end

-- arg = 창에 딸려 주는 값(같은 창이 다른 값으로 열려 있으면 닫고 다시 연다)
--  force = 아직 열리지 않은 창이어도 띄운다(창고를 열 때의 가방 — 새 캐릭터도 계정의 창고에서 바로 꺼낼 수 있어야 한다)
function Windows.open(id: string, arg: any, force: boolean?)
	local def = defs[id]
	if not def or (def.from > level and not force and not Windows.extra[id]) then
		return
	end
	if Windows.isOpen(id) then
		if Windows.argOf(id) == arg then
			return
		end
		Windows.close(id)
	end
	-- 넓은 창은 다 닫고 혼자(오른쪽), 보통 창은 둘까지 — 오른쪽에 하나, 왼쪽에 하나.
	--  제 쪽이 정해진 창(가방 = 오른쪽)이 뜰 때 그 자리에 다른 창이 있으면 그 창을 맞은편으로 옮긴다(맞은편도 찼으면 그 자리의 창을 닫는다).
	--  쪽이 정해지지 않은 창은 빈 쪽에(오른쪽 먼저), 둘 다 찼으면 가장 먼저 연 창의 자리에.
	local side = "right"
	if def.wide then
		while #open > 0 do
			Windows.close(open[1].id)
		end
	else
		for i = #open, 1, -1 do
			if defs[open[i].id].wide then
				Windows.close(open[i].id)
			end
		end
		if def.side then
			side = def.side
			local there = at(side)
			if there then
				local across = at(other(side))
				if across or defs[there.id].side == side then
					Windows.close(there.id)
				else
					there.side = other(side)
				end
			end
		elseif not at("right") then
			side = "right"
		elseif not at("left") then
			side = "left"
		else
			-- 둘 다 찼다: 쪽이 정해지지 않은 창 가운데 가장 먼저 연 것의 자리를 쓴다(없으면 가장 먼저 연 것)
			local old = open[1]
			for _, o in open do
				if not defs[o.id].side then
					old = o
					break
				end
			end
			side = old.side
			Windows.close(old.id)
		end
	end
	local bw, bh = BODY_W, BODY_H
	if def.size then
		bw, bh = def.size(arg)
	end
	local w, h = Ui.windowSize(bw, bh)
	local holder = Stage.place(root, "Window_" .. id, "tr", 0, TOP, w, h)
	local win = Ui.window(holder, (if def.title then def.title(arg) else nil) or def.name, 0, 0, w, h, function() -- title이 nil이면 공방의 이름
		Windows.close(id)
	end)
	local view = def.build(win.body, ctx, win.w, win.h, arg)
	local closer = Instance.new("TextButton")
	closer.Name = "Close_" .. id
	closer.Text = ""
	closer.BackgroundTransparency = 1
	closer.Size = UDim2.fromOffset(CLOSE_HIT, CLOSE_HIT)
	closer.Parent = closers
	closer.Activated:Connect(function()
		Windows.close(id)
	end)
	local cross = win.frame:FindFirstChild("Close")
	if cross then
		closer.MouseEnter:Connect(function()
			Ui.swap(cross, "uCloseHot")
		end)
		closer.MouseLeave:Connect(function()
			Ui.swap(cross, "uClose")
		end)
	end
	local o = { id = id, win = win, holder = holder, view = view, arg = arg, w = w, h = h, side = side, closer = closer }
	table.insert(open, o)
	pcall(attachDrag, o) -- (끌기에 쓰는 이벤트가 없는 곳 — 시험의 가짜 화면 — 에서는 건너뛴다)
	layout()
	if ctx.changed then
		ctx.changed() -- 열린 창이 바뀌었다(가방의 단추가 옆 창에 따라 달라진다) — 여기서 모두 다시 그린다
	elseif view and view.refresh and ctx.me() then
		view.refresh(ctx.me())
	end
end

function Windows.toggle(id: string)
	if Windows.isOpen(id) then
		Windows.close(id)
	else
		Windows.open(id, nil)
	end
end

-- 내 상태가 바뀌었다: 열려 있는 창을 고쳐 그린다
function Windows.refresh(me)
	for _, o in open do
		if o.view and o.view.refresh then
			o.view.refresh(me)
		end
	end
end

-- 그 창 옆(화면 가운데 쪽)에 폭 w의 판을 놓을 자리 — 아이템 상세 판(ui/itemDetail.luau)이 쓴다. 창이 열려 있지 않으면 nil.
--  오른쪽 창이면 그 왼쪽에, 왼쪽 창이면 그 오른쪽에(창과 gap만큼 띄운다). 윗줄은 창과 같다
function Windows.beside(id: string, w: number, gap: number): UDim2?
	for _, o in open do
		if o.id == id then
			-- 창의 지금 자리(끌어 옮겼을 수 있다 — 2026-11-12): 창이 화면의 왼쪽 반에 있으면 그 오른쪽에, 아니면 그 왼쪽에 · 화면 안으로
			--  (넓은 창(경매장)은 좁은 화면 틀에서 옆에 자리가 없다: 그때는 화면 끝에 붙인다 — 창을 조금 덮는다)
			local p = o.holder.Position
			local lx, ty = p.X.Scale * Stage.uiW + p.X.Offset, p.Y.Scale * Stage.uiH + p.Y.Offset
			local ow = o.w * (o.k or 1)
			local x = if lx + ow / 2 < Stage.uiW / 2 then lx + ow + gap else lx - gap - w
			x = math.clamp(x, 0, math.max(0, Stage.uiW - w))
			return UDim2.fromOffset(math.floor(x), math.floor(ty))
		end
	end
	return nil
end

-- 열린 창에 딸린 값(상점 창이 누구의 것인지 등)
function Windows.argOf(id: string): any
	for _, o in open do
		if o.id == id then
			return o.arg
		end
	end
	return nil
end

-- 등록된 창의 목록(여는 키가 있는 것만, 공방의 차례대로). all = 아직 열리지 않은 것까지
local function listOf(all: boolean)
	local out = {}
	for _, w in UI.windows do
		if defs[w.id] and w.key and (all or defs[w.id].from <= level or Windows.extra[w.id]) then
			table.insert(out, { id = w.id, name = w.name, key = w.key })
		end
	end
	return out
end

-- 지금 쓸 수 있는 창
function Windows.list()
	return listOf(false)
end

-- 등록된 창 모두(키를 묶을 때 쓴다)
function Windows.all()
	return listOf(true)
end

return Windows
