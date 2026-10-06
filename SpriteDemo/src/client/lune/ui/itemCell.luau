-- 장비 한 칸 — 가방 · 장비 창 · 창고 · 강화 창이 같이 쓴다.
--  밝은 칸(20x20)에 그 장비의 아이콘(18x18). 왼쪽 위 귀퉁이의 세모 = 성능 단(낡은 갈색 · 허름한 회색 · 좋은 민트 · 빼어난 주황 — 보통은 없다),
--  오른쪽 아래의 +숫자 = 별, 부서진 것은 어둡게 하고 빨간 ×. 고른 칸은 주황 테두리.
--  아이콘은 공방의 아이콘(tools/build_lune_icons.mjs): 무기는 직업마다 하나, 방어구는 부위 x 재질(가죽 · 수정 · 무쇠 · 달빛), 장신구는 부위마다 하나.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.shared.lune.sim.items)
local Kit = require(script.Parent.kit)

local C = Kit.COLOR
local D = Items.data

local ItemCell = {}
ItemCell.SIZE = Kit.CELL
-- 성능 단의 글자색: 낡은 · 허름한 · 보통 · 좋은 · 빼어난
ItemCell.QUALITY = { C.tier0, C.tier1, C.white, C.tier3, C.tier4 }
local TIER = { "tier0", "tier1", nil, "tier3", "tier4" } -- 칸 귀퉁이의 세모(부품 이름)
local WEAPON = { axion = "w_axe", riven = "w_dagger", reaper = "w_scythe", mooni = "w_sword", salamander = "w_fist" }

function ItemCell.color(it): Color3
	if it.broken then
		return C.red
	end
	return ItemCell.QUALITY[it.q] or C.white
end

-- 방어구의 재질 번호(1 가죽 · 2 수정 · 3 무쇠 · 4 달빛) — 장비 단계로 정해진다
function ItemCell.material(stage: number): number
	for i, m in D.MATERIAL do
		if stage < m.below then
			return i
		end
	end
	return #D.MATERIAL
end

-- 그 장비의 아이콘 이름
function ItemCell.icon(it): string
	if it.slot == "weapon" then
		return WEAPON[it.who] or "w_sword"
	end
	local armor = ("a_%s%d"):format(it.slot, ItemCell.material(it.stage))
	if Kit.hasIcon(armor) then
		return armor
	end
	return "acc_" .. it.slot
end

-- 성능 단 표시의 부품 이름(보통이면 nil)
function ItemCell.tier(it): string?
	return TIER[it.q]
end

-- 글로 적는 장비(한 줄): 이름 +별
function ItemCell.label(it): string
	local name = Items.name(it)
	if it.broken then
		return name .. " (부서짐)"
	elseif it.star > 0 then
		return ("%s +%d"):format(name, it.star)
	end
	return name
end

-- 성능 단의 글: 보통이면 빈 글
function ItemCell.qualityText(it): string
	local q = D.QUALITY[it.q]
	if q.bonus == 0 then
		return ""
	end
	return ("%s %s%d%%"):format(q.name, if q.bonus > 0 then "+" else "", q.bonus)
end

-- 칸 하나. onClick(item) — 빈 칸을 눌러도 불린다(item = nil)
function ItemCell.new(parent: Instance, x: number, y: number, onClick: (any) -> ())
	local S = ItemCell.SIZE
	local outer = Kit.group(parent, x, y, S, S)
	outer.Name = "Cell"
	local back = Kit.part(outer, "slotCell", 0, 0)
	local icon = Kit.icon(outer, nil, 1, 1)
	local tier = Kit.part(outer, "tier0", 1, 1)
	tier.ZIndex = 2
	tier.Visible = false
	local star = Kit.micro(outer, "", 2, S - 7, C.yellow)
	local cross = Kit.micro(outer, "", 8, 7, C.red)
	local ring = Kit.part(outer, "select", 0, 0)
	ring.ZIndex = 4
	ring.Visible = false
	local cell = { frame = outer, item = nil :: any }
	Kit.hit(outer).Activated:Connect(function()
		onClick(cell.item)
	end)
	-- it = 장비(없으면 빈 칸). opts = { locked 아직 열리지 않은 칸, selected 고른 칸 }
	function cell.set(_, it: any, opts)
		opts = opts or {}
		cell.item = it
		Kit.setIcon(icon, if it then ItemCell.icon(it) else nil)
		local mark = it and ItemCell.tier(it)
		tier.Visible = mark ~= nil
		if mark then
			Kit.swap(tier, mark)
		end
		local stars = if it and it.star > 0 then "+" .. it.star else ""
		star:set(stars)
		star:move(S - 2 - Kit.microWidth(stars), S - 7)
		local broken = it ~= nil and it.broken == true
		icon.ImageColor3 = if broken then Color3.fromRGB(90, 90, 100) else Color3.new(1, 1, 1)
		cross:set(if broken then "X" else "")
		ring.Visible = opts.selected == true
		back.ImageTransparency = if opts.locked then 0.65 else 0
	end
	cell:set(nil)
	return cell
end

return ItemCell
