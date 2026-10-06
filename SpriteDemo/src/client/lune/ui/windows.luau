-- 창 관리 — 창을 열고 닫고, 한 번에 둘까지 나란히 놓는다(넓은 창은 혼자 쓴다). 창의 이름과 여는 키는 공방에서 정한 것(data/ui.generated.luau).
--  창마다 build(body, ctx) → { refresh(me), destroy() } 꼴의 모듈을 등록한다. 서버가 내 상태를 다시 보내면 열려 있는 창을 고쳐 그린다.
--  닫기는 ×나 여는 키를 한 번 더. (Esc는 Roblox가 제 메뉴에 쓴다 — 게임이 받지 못한다)
--  창은 처음부터 다 보이지 않는다 — 공방에서 정한 레벨(from)이 되어야 열린다(능력치 · 스킬은 Lv.2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage.shared.lune.data["ui.generated"])
local Stage = require(script.Parent.Parent.stage)
local Kit = require(script.Parent.kit)

local SLOT_W = 176 -- 창 하나의 폭(둘이 나란히 들어간다)
local TOP = 10
local SLOT_X = { 12, 196 }

local Windows = {}

local defs = {} -- [id] = { name, key, wide, height, build }
local open = {} -- 열린 차례대로 { id, win, view, slot }
local root: Frame = nil
local ctx = nil
local level = 1 -- 내 레벨(이 레벨에 열린 창만 쓴다)

function Windows.init(context)
	ctx = context
	root = Stage.group(Stage.view, "Windows", 150)
end

-- 창을 등록한다. def = { wide = 넓은 창인가, height = 높이, build = function(body, ctx, w, h) → { refresh(me), destroy() } }
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
			o.win.frame:Destroy()
			table.remove(open, i)
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
	-- 자리를 고른다: 넓은 창은 다 닫고 혼자, 보통 창은 빈 자리(둘 다 찼으면 가장 먼저 연 것을 닫는다)
	local slot = 1
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
		if #open >= 2 then
			Windows.close(open[1].id)
		end
		if #open == 1 then
			slot = if open[1].slot == 1 then 2 else 1
		end
	end
	local w = if def.wide then SLOT_W * 2 + 8 else SLOT_W
	local h = def.height or 150
	local win = Kit.window(root, if def.title then def.title(arg) else def.name, SLOT_X[slot], TOP, w, h, function()
		Windows.close(id)
	end)
	local view = def.build(win.body, ctx, win.w, win.h, arg)
	table.insert(open, { id = id, win = win, view = view, slot = slot, arg = arg })
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

-- 등록된 창의 목록(여는 키가 있는 것만, 공방의 차례대로). all = 아직 열리지 않은 것까지
-- 열린 창에 딸린 값(상점 창이 누구의 것인지 등)
function Windows.argOf(id: string): any
	for _, o in open do
		if o.id == id then
			return o.arg
		end
	end
	return nil
end

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
