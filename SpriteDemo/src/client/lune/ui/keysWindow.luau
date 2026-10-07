-- 키 설정 창(넓은 창) — 하는 일마다 지금 키가 적힌 단추가 있다. 단추를 누른 뒤 새 키를 누르면 바뀐다.
--  이미 쓰는 키면 둘이 자리를 바꾼다. 「기본으로」는 처음 세팅으로 돌린다. 바꾼 것은 서버에 저장된다(캐릭터마다).
--  사용자 결정(2026-10-06): 기본 키를 주되 유저가 자유롭게 바꾼다. 화면 오른쪽의 옆 판(ui/windows.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage.shared.lune.ui.format)
local Ui = require(script.Parent.ui)
local Input = require(script.Parent.Parent.input)

local C = Ui.COLOR
local ROW = Ui.M.button + 4
local PER_COLUMN = 10
local COLUMNS = 3 -- 세 단: 기본 동작 · 창을 여는 키 · 퀵슬롯의 키 차례로 채운다
local COL_W, GAP = 190, 16 -- 한 단의 폭 · 단 사이
local KEY_W = 70 -- 키가 적힌 단추의 폭

local KeysWindow = { wide = true }

function KeysWindow.size(): (number, number)
	return COL_W * COLUMNS + GAP * (COLUMNS - 1), 34 + PER_COLUMN * ROW
end

-- 화면에 적을 "하는 일"의 차례와 이름. ctx.actions() = { { action, name } … }
function KeysWindow.build(body: Frame, ctx, w: number, _h: number)
	local actions = ctx.actions()
	local buttons = {}
	local waiting: string? = nil
	local note = Ui.text(body, "바꿀 단추를 누른 뒤 새 키를 누른다", 0, 5, w - 110, { color = C.dim })

	local function redraw()
		for _, item in actions do
			local key = Input.BIND[item.action]
			local b = buttons[item.action]
			if b then
				b:setText(if waiting == item.action then "…" else Format.key(if key then key.Name else "-"))
				b:setMain(waiting == item.action)
			end
		end
		note:set(if waiting then "새 키를 누른다(같은 단추를 다시 누르면 그만둔다)" else "바꿀 단추를 누른 뒤 새 키를 누른다")
	end

	for i, item in actions do
		if i > PER_COLUMN * COLUMNS then
			break -- 세 단에 들어가는 만큼만
		end
		local col = (i - 1) // PER_COLUMN
		local row = (i - 1) % PER_COLUMN
		local x, y = col * (COL_W + GAP), 34 + row * ROW
		Ui.text(body, item.name, x, y + 7, COL_W - KEY_W - 8, { font = "body" })
		buttons[item.action] = Ui.button(body, "", x + COL_W - KEY_W, y, KEY_W, function()
			if waiting == item.action then
				waiting = nil
				Input.capture(nil)
				redraw()
				return
			end
			waiting = item.action
			redraw()
			Input.capture(function(key: Enum.KeyCode)
				Input.rebind(item.action, key)
				waiting = nil
				redraw()
				ctx.saveKeys()
			end)
		end)
	end
	Ui.button(body, "기본으로", w - 100, 0, 100, function()
		waiting = nil
		Input.capture(nil)
		ctx.resetKeys()
		redraw()
		ctx.saveKeys()
	end, { h = 22, font = "small" })
	redraw()

	return {
		refresh = function() end,
		destroy = function()
			Input.capture(nil)
		end,
	}
end

return KeysWindow
