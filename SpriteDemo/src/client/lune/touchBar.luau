-- 바로가기 판(폰 단추 배치 「바로가기」 — 2026-11-13 사용자: "다른 대형 상용 rpg 들중에 모바일 ui 공부한뒤에 우리 모바일 ui도 조금더 편하게 개편한다 …
--  지금은 메뉴탭에 모두 집어넣은 상태라 개편해야하는거야 그래서 모바일은 또 ui 선택을 이번에 생기는 버전으로도 선택할수 있게해서 3가지 버전을 선택해서 쓸수있게").
--  공방 design/basics.js의 TOUCH_BAR(data/ui.generated.luau의 touchBar) — 오른쪽 위에 두 줄 x 셋의 칸: 가방 · 장비 · 스킬 / 퀘스트 · 상점 · 전체.
--   칸 = 그림(UI 키트의 24점 그림 — menuIcon) + 이름 + 받을 것이 있으면 노란 점. 누르면 그 창(PC의 단추 줄과 같은 길 — boot의 state.openWin) · 「전체」 = 묶음 메뉴(ui/menuGrid.luau)
--  보이는 때: 손가락 단추가 켜졌고(setTouch) 고른 배치가 「바로가기」일 때(setOn — viewOpts.luau ViewOpts.applyTouch)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local UI = require(lune.data["ui.generated"])
local Stage = require(script.Parent.stage)
local Ui = require(script.Parent.ui.ui)

local C = Ui.COLOR
local TouchBar = {}
TouchBar.on = false -- 「바로가기」 배치를 골랐다
TouchBar.touch = false -- 손가락 단추가 켜졌다
TouchBar.tiles = {} :: { [string]: any }
TouchBar.marks = {} :: { [string]: boolean }
TouchBar.root = nil :: Frame?
TouchBar.picked = nil :: { string }? -- 사람이 고른 칸(「전체」 빼고 — 계정의 sound.bar · 2026-11-13 「바로가기 고치기」) · 없으면 설계의 차례
local opts = nil :: any -- { open = (id) -> (), all = () -> (), name = (id) -> string } — boot가 단다

-- ---------- 셈(시험이 직접 본다) ----------
-- 줄에 놓을 것(셈만): 고른 것(있으면 · 다섯까지) 또는 설계의 차례 + 끝에 「전체」 — 늘 여섯 칸 이하
function TouchBar.list(picked: { string }?): { string }
	local B = UI.touchBar
	local out = {}
	if picked and #picked > 0 then
		for _, id in picked do
			if #out >= B.cols - 1 then
				break
			end
			if id ~= "@all" and not table.find(out, id) then
				table.insert(out, id)
			end
		end
	else
		for _, id in B.items do
			if id ~= "@all" then
				table.insert(out, id)
			end
		end
	end
	table.insert(out, "@all")
	return out
end
-- 판의 크기(화면 칸의 격자 960x540의 점 — 설계의 칸 수: 고른 것이 적어도 판은 오른쪽 끝에 붙어 같은 자리)
function TouchBar.size(): (number, number)
	local B = UI.touchBar
	local rows = math.ceil(#B.items / B.cols)
	return B.cols * B.tile + (B.cols - 1) * B.gap, rows * B.tile + (rows - 1) * B.gap
end
-- i째 칸(1부터)의 판 안 자리
function TouchBar.cell(i: number): (number, number)
	local B = UI.touchBar
	local c, r = (i - 1) % B.cols, (i - 1) // B.cols
	return c * (B.tile + B.gap), r * (B.tile + B.gap)
end

-- ---------- 화면 ----------
local function build()
	if TouchBar.root then
		TouchBar.root:Destroy()
		TouchBar.root = nil
	end
	table.clear(TouchBar.tiles)
	if not (TouchBar.on and TouchBar.touch) or not opts then
		return
	end
	local B = UI.touchBar
	local w, h = TouchBar.size()
	local root = Stage.place(Stage.ui, "TouchBar", B.at, B.x, B.y, w, h)
	root.ZIndex = 125
	TouchBar.root = root
	-- 손가락 단추 판과 같이 숨는다(대화 · 장면 · 캐릭터 선택 동안 — 2026-11-14)
	local T = require(script.Parent.touch)
	if T.root then
		root.Visible = T.root.Visible
	end
	local PIC = 24
	local items = TouchBar.list(TouchBar.picked)
	local skip = #B.items - #items -- (고른 것이 적으면 오른쪽에 붙인다)
	for i, id in items do
		local x, y = TouchBar.cell(i + skip)
		local cell = Ui.slot(root, x, y, B.tile)
		cell.frame.Name = "Tile_" .. string.gsub(id, "@", "")
		Ui.pic(cell.frame, UI.menuIcon[id] or "menu_gear", math.floor((B.tile - PIC) / 2), 4)
		local name = if id == "@all" then B.all else opts.name(id)
		Ui.text(cell.frame, name, 1, B.tile - 17, B.tile - 2, { align = "center", font = "small", outline = true })
		local dot = Ui.box(cell.frame, B.tile - 9, 2, 7, 7, C.ink)
		Ui.box(dot, 1, 1, 5, 5, C.gold)
		dot.Name = "Dot"
		dot.ZIndex = 9
		dot.Visible = TouchBar.marks[id] == true
		local hit = Ui.hit(cell.frame)
		hit.Activated:Connect(function()
			if id == "@all" then
				opts.all()
			else
				opts.open(id)
			end
		end)
		TouchBar.tiles[id] = { frame = cell.frame, cell = cell, dot = dot }
	end
end

local boundRoot: Instance? = nil
function TouchBar.init(options)
	opts = options
	-- 손가락 단추 판(touch.luau의 root)이 숨거나 보이면 이 판도 같이(2026-11-14 — 전에는 대화 · 장면 동안에도 떠 있었다)
	local T = require(script.Parent.touch)
	if T.root and boundRoot ~= T.root then
		boundRoot = T.root
		T.root:GetPropertyChangedSignal("Visible"):Connect(function()
			if TouchBar.root and T.root then
				TouchBar.root.Visible = T.root.Visible
			end
		end)
	end
	build()
	if Stage.onResize then
		Stage.onResize(build)
	end
end
function TouchBar.setOn(on: boolean)
	on = on == true
	if TouchBar.on ~= on then
		TouchBar.on = on
		build()
	end
end
function TouchBar.setTouch(on: boolean)
	on = on == true
	if TouchBar.touch ~= on then
		TouchBar.touch = on
		build()
	end
end
-- 놓을 것을 바꾼다(계정에서 읽은 것 · 「바로가기 고치기」)
function TouchBar.setItems(list: { string }?)
	TouchBar.picked = if typeof(list) == "table" and #list > 0 then table.clone(list) else nil
	build()
end
-- 칸의 노란 점(받을 것이 있다 · 찍을 점수가 남았다 …)
function TouchBar.mark(id: string, on: boolean)
	TouchBar.marks[id] = on == true
	local t = TouchBar.tiles[id]
	if t then
		t.dot.Visible = on == true
	end
end
-- 열려 있는 창의 칸은 민트(PC의 단추 줄처럼)
function TouchBar.setOpen(set)
	for id, t in TouchBar.tiles do
		t.cell:setOn(set[id] == true)
	end
end
-- 칸의 틀(튜토리얼이 반짝이게 한다 · Touch.frameOf("menu") — 「전체」)
function TouchBar.frame(id: string): GuiObject?
	local t = TouchBar.tiles[id]
	return if t then t.frame else nil
end

return TouchBar
