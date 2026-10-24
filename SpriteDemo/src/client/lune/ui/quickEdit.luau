-- 퀵슬롯 고치기 — 스킬 창이 열려 있는 동안 스킬을 화면 가운데 아래의 칸에 놓는다.
--  사용자 2026-10-07: "스킬키를 단축키에 등록하기 쉬워야합니다. … 드래그앤 드랍으로 배치도 되어야하고, 스킬탭에서 스킬아이콘을 꾹누르거나 클릭하면 퀵슬롯쪽이 반짝거리고 거기서 퀵슬롯을 누르면 배치된다던가"
--  놓는 법 둘(공방의 횡스크롤 시험 탭 — js/lune/luneTab.js와 같다):
--   ① 끌어다 놓기: 스킬 창의 스킬(또는 칸에 놓인 것)을 누른 채 움직이면 그림이 따라오고, 칸 위에서 놓으면 그 칸에 놓인다. 칸끼리는 자리를 바꾸고, 칸 밖에 놓으면 칸에서 빠진다(물약은 빠지지 않는다).
--   ② 눌러서 놓기: 스킬 창의 스킬을 누르면 칸들이 반짝이고, 칸을 누르면 그 칸에 놓인다(터치도 같은 방법). 같은 스킬을 한 번 더 누르거나 다른 데를 누르면 그만둔다.
--  칸끼리 끌어 자리를 바꾸거나 칸 밖에 놓아 빼는 것은 늘 된다(사용자 2026-10-07: "스킬창열었을때 뿐만아니라 평소에도 퀵슬롯에서 드래그앤 드랍으로 자리를 바꿀수 있어야합니다").
--  소비 아이템(물약)은 가방의 소비 탭에서 끌어다 놓는다("인벤토리 열고 소비아이템도 드래그앤 드랍으로 퀵슬롯에 올릴수있어야합니다"). 칸의 셈은 shared/lune/ui/quick.luau, 그리는 것은 hud.luau.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Quick = require(ReplicatedStorage.shared.lune.ui.quick)
local Layout = require(ReplicatedStorage.shared.lune.ui.layout)
local Stage = require(script.Parent.Parent.stage)
local Hud = require(script.Parent.Parent.hud)
local Ui = require(script.Parent.ui)

local SLOT = Layout.SKILLS.slot
local DRAG = Quick.DATA.drag -- 이만큼 움직이면 끌기로 본다(화면 틀의 점)

local QuickEdit = {}

local hooks = nil -- { slots() → 지금 칸들, apply(새 칸들), state(id) → "ok" · "passive" · "unlearned", changed() }
local open = false -- 놓을 것을 고르는 창(스킬 창 · 가방)이 열려 있다
local picked: string? = nil -- 놓으려고 고른 스킬
local pending = nil -- 누르고 있는 것 { what, from(칸 · 스킬 창에서 온 것이면 nil), start, input, moved, ghost, extra }
-- 가방의 칸에서 끄는 것(ui/bagWindow.luau)도 여기서 맡는다 — 끌기는 한 번에 하나뿐이다. extra = { icon(게임 세계의 그림 이름), size(끌려오는 그림의 한 변),
--   onMove(at) 움직일 때마다, onDrop(at) → 여기서 받았으면 true(그러면 퀵슬롯에는 놓지 않는다), onEnd() 끝났다(놓았든 그만뒀든) }.
--   what이 nil이면(장비 · 기타 아이템) 퀵슬롯에는 놓이지 않고 extra의 일만 한다

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function paint()
	Hud.setPick(picked ~= nil or (pending ~= nil and pending.moved and pending.what ~= nil))
	if hooks.changed then
		hooks.changed()
	end
end

-- 놓으려고 고른 스킬(없으면 nil)
function QuickEdit.picked(): string?
	return picked
end

-- 지금 무엇을 끌고 있는가(누른 채 움직이기 시작했다) — 끌기를 끝낼 때 함께 오는 "눌렀다"를 창이 가려낼 때 쓴다
function QuickEdit.dragging(): boolean
	return pending ~= nil and pending.moved
end

-- 스킬을 고른다: 칸들이 반짝인다. 같은 것을 한 번 더 고르면 그만둔다. nil = 그만둔다
function QuickEdit.pick(id: string?)
	if id ~= nil and (not open or (not Quick.item(id) and not Quick.ride(id) and hooks.state(id) ~= "ok") or picked == id) then -- (펫 · 탈것도 — 2026-10-21)
		id = nil
	end
	if picked ~= id then
		picked = id
		paint()
	end
end

-- 그 스킬이 놓인 칸의 키 이름(없으면 nil)과 놓을 수 있는지
function QuickEdit.info(id: string, kind: string?)
	local i = Quick.find(hooks.slots(), id)
	return { state = hooks.state(id, kind), key = if i then (if Hud.touch then "단추" else Hud.slotKey(i)) else nil } -- 스마트폰: 칸에 키가 없다
end

-- 끌던 것(p)을 놓았다: 칸 위면 그 칸에(칸에서 온 것이면 자리를 바꾼다), 칸 밖이면 칸에서 온 것은 빠진다
local function drop(p, at: Vector2)
	if p.extra and p.extra.onDrop and p.extra.onDrop(at) then
		return -- 가방의 칸에 놓았다
	end
	if not p.what then
		return
	end
	local j = Hud.slotAt(at)
	local slots = hooks.slots()
	local next = nil
	if j then
		next = Quick.place(slots, p.what, j)
	elseif p.from then
		next = Quick.clear(slots, p.from)
	end
	if next then
		hooks.apply(next)
	end
end

-- 누르던 것을 끝낸다. at = 뗀 자리(없으면 그만둔 것 — 놓지 않는다)
local function finish(at: Vector2?)
	local p = pending
	pending = nil
	if not p then
		return
	end
	if p.ghost then
		p.ghost:Destroy()
	end
	if p.moved then
		if at then
			drop(p, at)
		end
		picked = nil
		Hud.setHot(nil)
		paint()
	end
	if p.extra and p.extra.onEnd then
		p.extra.onEnd()
	end
end

-- 누르기 시작했다(끌기가 될 수도 있다). what = 스킬 · 소비 아이템의 이름표(가방의 장비 · 기타 아이템이면 nil), from = 칸(창에서 온 것이면 nil), extra = 가방의 칸에서 끌 때(위의 설명)
function QuickEdit.press(what: string?, from: number?, input: InputObject, extra: any)
	if not isPress(input) or (what == nil and extra == nil) then
		return
	end
	if what ~= nil and from == nil and not Quick.item(what) and not Quick.ride(what) and hooks.state(what) ~= "ok" then
		return
	end
	finish(nil)
	pending = { what = what, from = from, start = Vector2.new(input.Position.X, input.Position.Y), input = input, moved = false, ghost = nil, extra = extra, t0 = os.clock() }
end

-- 스킬 창이 열렸다 · 닫혔다: 닫히면 고르던 것 · 끌던 것을 그만둔다
function QuickEdit.setOpen(on: boolean)
	if open == on then
		return
	end
	open = on
	if not on then
		finish(nil)
		picked = nil
	end
	Hud.setPick(picked ~= nil)
end

function QuickEdit.init(h)
	hooks = h
	-- 칸을 눌렀다: 고른 스킬이 있으면 그 칸에 놓는다
	Hud.onSlotClick = function(i: number)
		if open and picked then
			local next = Quick.place(hooks.slots(), picked, i)
			picked = nil
			if next then
				hooks.apply(next)
			end
			paint()
		end
	end
	-- 칸을 누르기 시작했다: 놓인 것이 있으면 끌 수 있다
	Hud.onSlotPress = function(i: number, input: InputObject)
		local what = hooks.slots()[i]
		if what then
			QuickEdit.press(what, i, input) -- 칸의 것은 늘 끌 수 있다
		end
	end
	UserInputService.InputChanged:Connect(function(input)
		local p = pending
		if not p then
			return
		end
		local mouse = input.UserInputType == Enum.UserInputType.MouseMovement and p.input.UserInputType == Enum.UserInputType.MouseButton1
		if not mouse and input ~= p.input then
			return
		end
		local at = Vector2.new(input.Position.X, input.Position.Y)
		if not p.moved and (at - p.start).Magnitude > DRAG * Stage.uiScale then
			-- 스마트폰에서 스크롤 틀 안의 칸(가방 — extra.hold): 잠깐 누르고 있지 않고 바로 밀었으면 끌기가 아니라 스크롤이다(2026-10-15)
			if p.extra and p.extra.hold and p.input.UserInputType == Enum.UserInputType.Touch and os.clock() - (p.t0 or 0) < p.extra.hold then
				pending = nil
				return
			end
			-- 끌기 시작: 그림이 마우스를 따라오고 칸들이 반짝인다
			p.moved = true
			if p.extra and p.extra.onStart then
				p.extra.onStart()
			end
			picked = nil
			local size = if p.extra and p.extra.size then p.extra.size else SLOT
			local ghost = Ui.group(Stage.ui, 0, 0, size, size, "DragGhost")
			ghost.ZIndex = 400
			Ui.slot(ghost, 0, 0, size):setOn(true)
			if p.extra and p.extra.icon then
				Ui.worldIcon(ghost, p.extra.icon, 0, 0, size).ZIndex = 2 -- 가방의 것: 칸에 놓인 그 그림(게임의 굵은 도트)
			else
				local pad = math.floor((size - Ui.M.pic) / 2)
				Ui.pic(ghost, Quick.pic(p.what), pad, pad).ZIndex = 2
			end
			p.ghost, p.size = ghost, size
			paint()
		end
		if p.moved then
			local origin = Stage.ui.AbsolutePosition
			p.ghost.Position = UDim2.fromOffset(math.floor((at.X - origin.X) / Stage.uiScale - p.size / 2 + 0.5), math.floor((at.Y - origin.Y) / Stage.uiScale - p.size / 2 + 0.5))
			Hud.setHot(if p.what then Hud.slotAt(at) else nil)
			if p.extra and p.extra.onMove then
				p.extra.onMove(at)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local p = pending
		-- 손가락은 그 손가락만(2026-10-18 검토: 끄는 중에 조이스틱의 손가락을 떼면 거기에 놓였다) · 마우스는 단추가 같으면
		if p and isPress(input) and (input == p.input or (input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType == p.input.UserInputType)) then
			finish(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		finish(nil)
	end)
	-- 누르던 손가락 · 마우스 단추를 이미 뗐는데(뗀 알림을 놓쳤다 — 스크롤 틀이 손가락을 가져가는 때 등) 끄는 그림이 남아 있으면 놓지 않고 거둔다
	--  (2026-10-23 사용자: "모바일 환경에서 드래그앤 드랍으로 키를 바꾸려고하면 이상하게 아이콘 잔상이 남는버그")
	RunService.Heartbeat:Connect(function()
		local p = pending
		if p and p.input then
			local st = p.input.UserInputState
			if st == Enum.UserInputState.End or st == Enum.UserInputState.Cancel then
				finish(nil)
			end
		end
	end)
end

return QuickEdit
