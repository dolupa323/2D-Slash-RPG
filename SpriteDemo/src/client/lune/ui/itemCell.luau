-- 장비 한 칸 — 가방 · 장비 창 · 창고 · 강화 창이 같이 쓴다.
--  어두운 칸에 그 장비의 그림(땅에 떨어진 것과 같은 그림 — 게임의 굵은 도트 그대로). 오른쪽 아래의 +숫자 = 별, 부서진 것은 어둡게 하고 빨간 ×.
--  고른 칸은 민트 테두리. 등급(성능 단)은 칸에 표시하지 않는다 — 이름의 글자색으로만 보인다(던그리드처럼. 낡은 갈색 · 허름한 회색 · 보통 흰색 · 좋은 하늘색 · 빼어난 노랑).
--  그림은 공방의 아이콘(tools/build_lune_icons.mjs): 무기는 직업마다 하나, 방어구는 부위 x 재질(가죽 · 수정 · 무쇠 · 달빛), 장신구는 부위마다 하나.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Items = require(lune.sim.items)
local KIT = require(lune.data["kit.generated"])
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local D = Items.data
local ICONS = KIT.parts.icons.icons

local ItemCell = {}
-- 칸의 한 변(화면 틀의 배율을 따른다 — 1080p에서 50). 창을 지을 때마다 다시 묻는다
function ItemCell.size(): number
	return Ui.cellSize()
end
-- 성능 단의 글자색: 낡은 · 허름한 · 보통 · 좋은 · 빼어난
ItemCell.QUALITY = { C.tier0, C.tier1, C.tier2, C.tier3, C.tier4 }
local WEAPON = { axion = "w_axe", riven = "w_dagger", reaper = "w_scythe", mooni = "w_sword", salamander = "w_fist" }

function ItemCell.color(it): Color3
	if it.broken then
		return C.red
	end
	return ItemCell.QUALITY[it.q] or C.text
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
	if ICONS[armor] then
		return armor
	end
	return "acc_" .. it.slot
end

-- 땅에 떨어진 장비의 귀퉁이 표시(게임 세계의 그림 — client/lune/effects.luau가 쓴다): 보통이면 nil
local TIER = { "tier0", "tier1", nil, "tier3", "tier4" }
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

-- 칸 하나(한 변 s — 안 주면 ItemCell.size()). onClick(item) — 빈 칸을 눌러도 불린다(item = nil)
function ItemCell.new(parent: Instance, x: number, y: number, onClick: (any) -> (), s: number?)
	local S = s or ItemCell.size()
	local slot = Ui.slot(parent, x, y, S)
	local outer = slot.frame
	outer.Name = "Cell"
	local icon = Ui.worldIcon(outer, nil, 0, 0, S)
	local star = Ui.text(outer, "", 0, S - 13, S - 4, { align = "right", outline = true, color = C.text, z = 6 })
	local cross = Ui.text(outer, "", 0, math.floor((S - 12) / 2), S, { font = "body", align = "center", outline = true, color = C.red, z = 6 })
	local veil = Ui.box(outer, 1, 1, S - 2, S - 2, C.ink, 0.45) -- 아직 열리지 않은 칸
	veil.Name = "Locked"
	veil.ZIndex = 5
	veil.Visible = false
	local cell = { frame = outer, item = nil :: any, size = S }
	Ui.hit(outer).Activated:Connect(function()
		onClick(cell.item)
	end)
	-- it = 장비(없으면 빈 칸). opts = { locked 아직 열리지 않은 칸, selected 고른 칸 }
	function cell.set(_, it: any, opts)
		opts = opts or {}
		cell.item = it
		Ui.setWorldIcon(icon, if it then ItemCell.icon(it) else nil)
		star:set(if it and it.star > 0 then "+" .. it.star else "")
		local broken = it ~= nil and it.broken == true
		icon.ImageColor3 = if broken then Color3.fromRGB(90, 90, 100) else Color3.new(1, 1, 1)
		cross:set(if broken then "×" else "")
		slot:setOn(opts.selected == true)
		veil.Visible = opts.locked == true
	end
	cell:set(nil)
	return cell
end

return ItemCell
