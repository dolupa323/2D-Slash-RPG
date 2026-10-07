-- 창 관리 — 창을 열고 닫고, 한 번에 둘까지 화면의 오른쪽과 왼쪽에 하나씩 놓는다(넓은 창은 혼자 쓴다 — 가운데의 캐릭터는 늘 보인다). 창의 이름과 여는 키는 공방에서 정한 것(data/ui.generated.luau).
--  창은 화면 틀의 층(고운 격자)에 뜨는 오른쪽 옆 판이다 — 가운데의 캐릭터를 가리지 않는다(던그리드의 가방처럼. 사용자 2026-10-07의 시안 승인).
--  창마다 build(body, ctx, w, h, arg) → { refresh(me), destroy() } 꼴의 모듈을 등록한다. 서버가 내 상태를 다시 보내면 열려 있는 창을 고쳐 그린다.
--   창의 크기는 모듈의 size(arg) → 속의 폭 · 높이(없으면 기본). 장비 칸이 든 창은 칸의 크기(화면 틀의 배율을 따른다)로 정한다.
--  닫기는 ×나 여는 키를 한 번 더. (Esc는 Roblox가 제 메뉴에 쓴다 — 게임이 받지 못한다)
--  창은 처음부터 다 보이지 않는다 — 공방에서 정한 레벨(from)이 되어야 열린다(능력치 · 스킬은 Lv.2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage.shared.lune.data["ui.generated"])
local Layout = require(ReplicatedStorage.shared.lune.ui.layout)
local Stage = require(script.Parent.Parent.stage)
local Ui = require(script.Parent.ui)

local TOP, EDGE = Layout.WIN.top, Layout.WIN.edge -- 화면 위 · 옆 끝에서 띄우는 폭
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

-- 열린 창을 제 쪽 끝에 놓는다: 오른쪽 창은 화면 오른쪽 끝에, 왼쪽 창은 왼쪽 끝에(가운데의 캐릭터를 가리지 않는다)
local function layout()
	for _, o in open do
		if o.side == "left" then
			o.holder.Position = Stage.atPosition("tl", EDGE, TOP)
		else
			o.holder.Position = Stage.atPosition("tr", Stage.REF_W - EDGE - o.w, TOP)
		end
		if o.closer then
			-- X 그림(창의 오른쪽 위, 한 변 10쯤)의 한가운데에 맞춘다
			o.closer.Position = o.holder.Position + UDim2.fromOffset(o.w - Ui.WIN.pad - 5 - CLOSE_HIT / 2, 18 - CLOSE_HIT / 2)
		end
	end
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

function Windows.init(context)
	ctx = context
	root = Stage.group(Stage.ui, "Windows", 150)
	closers = Stage.group(Stage.ui, "Closers", 300)
	-- 화면 틀의 배율이 바뀌면 창의 크기가 달라진다 — 다 닫는다(다시 열면 새 크기로 뜬다)
	Stage.onResize(function()
		while #open > 0 do
			Windows.close(open[1].id)
		end
	end)
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
	return def == nil or def.from > level
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

function Windows.close(id: string)
	for i, o in open do
		if o.id == id then
			if o.view and o.view.destroy then
				o.view.destroy()
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
function Windows.open(id: string, arg: any)
	local def = defs[id]
	if not def or def.from > level then
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
	local win = Ui.window(holder, if def.title then def.title(arg) else def.name, 0, 0, w, h, function()
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
	table.insert(open, { id = id, win = win, holder = holder, view = view, arg = arg, w = w, h = h, side = side, closer = closer })
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
		if defs[w.id] and w.key and (all or defs[w.id].from <= level) then
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
