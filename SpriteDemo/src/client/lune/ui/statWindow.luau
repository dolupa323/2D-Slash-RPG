-- 능력치 창 — 남은 점수, 다섯 능력치와 + 단추, 「자동으로 찍기」, 아래에 전투력과 체력.
--  찍는 것은 서버에 부탁한다(StatAdd · StatAuto). 서버가 내 상태를 다시 보내면 고쳐 그린다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local N = require(ReplicatedStorage.shared.lune.config.numbers)
local Kit = require(script.Parent.kit)
local Format = require(ReplicatedStorage.shared.lune.ui.format)

local STATS = N.data.STATS
local C = Kit.COLOR

local StatWindow = { height = 152 }

function StatWindow.build(body: Frame, ctx, w: number, _h: number)
	local points = Kit.text(body, "", 6, 2, w - 12, { color = C.yellow })
	local rows = {}
	local y = 16
	for _, id in STATS.order do
		local name = Kit.text(body, STATS.names[id], 6, y, 44)
		local tag = Kit.text(body, "", 52, y, 30, { color = C.mint })
		local value = Kit.text(body, "", 84, y, 50, { align = "right" })
		local plus = Kit.button(body, "+", w - 22, y - 2, 16, 13, function()
			ctx.send("StatAdd", id, 1)
		end)
		rows[id] = { name = name, tag = tag, value = value, plus = plus }
		y += 15
	end
	local auto = Kit.button(body, "자동으로 찍기", 4, y, w - 8, 14, function()
		ctx.send("StatAuto")
	end, { kind = "orange" })
	Kit.box(body, 4, y + 18, w - 8, 1, C.edgeDim)
	local power = Kit.text(body, "", 6, y + 22, w - 12, { color = C.yellow })
	local hp = Kit.text(body, "", 6, y + 34, w - 12)

	local view = {}
	function view.refresh(me)
		local pair = STATS.classes[me.class]
		points:set(("남은 점수 %d"):format(me.ap))
		for _, id in STATS.order do
			local row = rows[id]
			row.tag:set(if id == pair[1] then "주" elseif id == pair[2] then "부" else "")
			row.value:set(tostring(STATS.base + me.stats[id]))
			row.plus:setEnabled(me.ap > 0)
		end
		auto:setEnabled(me.ap > 0)
		power:set(("전투력 %s"):format(Format.short(me.power)))
		hp:set(("체력 %s"):format(Format.short(me.maxHp)))
	end
	return view
end

return StatWindow
