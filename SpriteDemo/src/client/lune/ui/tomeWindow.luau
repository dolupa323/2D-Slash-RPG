-- 모험의 서 창 — 메뉴 → 「모험의 서」(2026-10-16 · 2편 — 로스트아크의 모험의 서. 칸 · 보상은 제 제안: 공방 design/city.js의 TOME).
--  곳마다 한 장(탭 — 은달 항구 · 수정 숲): 「○○ 모험의 서」와 채운 % · 띠 / 칸 다섯(퀘스트 · 호감도 · 몬스터 · 달조각 · 숨은 이야기 — 띠와 n/N) /
--  보상 다섯(10 · 30 · 50 · 70 · 100%: 그림 · 「받기」 · 「받음」 · 「n%에서」) / 그곳 몬스터의 잡은 수(종류마다 100마리까지 — 두 줄로).
--  받는 것은 서버가 한다(ctx.bondDo → Bond "tome"). 셈은 shared/lune/sim/bond.luau(Bond.area). 화면 오른쪽의 옆 판(ui/windows.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lune = ReplicatedStorage.shared.lune
local Bond = require(lune.sim.bond)
local Gift = require(lune.sim.gift)
local Format = require(lune.ui.format)
local Layout = require(lune.ui.layout)
local COMBAT = require(lune.data["combat.generated"])
local Ui = require(script.Parent.ui)

local C = Ui.COLOR
local S = Layout.TOME
local D = Bond.DATA
local W = D.tome.words
local PARTS = { "quest", "mob", "shard", "story" } -- (호감도는 2026-10-16에 뺐다)
local GW = { money = "달돈 {n}", dust = "달가루 {n}", potion = "물약 {n}병", scroll = "귀환 주문서 {n}장" }

local TomeWindow = {}
local MOBS = 0
for _, a in D.tome.areas do
	MOBS = math.max(MOBS, #a.mobs)
end

function TomeWindow.size(): (number, number)
	return S.w, S.mobY + math.ceil(MOBS / 2) * S.mobRow + 4
end

-- 보상 칸의 그림(첫 것): 아이템이면 그 그림, 아니면 달가루 · 달돈 · 귀환 주문서 · 물약
function TomeWindow.rewardIcon(give): (string, string)
	for _, id in Gift.items(nil, { items = give.items }) do
		return id[1], tostring(id[2])
	end
	local icon, n = Gift.icon(give)
	return icon, Format.short(n)
end

function TomeWindow.build(body: Frame, ctx, w: number, _h: number)
	local view = {}
	local area = 1
	local note, noteTone = nil, nil
	local tabs = {}
	local tx = 0
	for i, a in D.tome.areas do
		local item = Ui.tab(body, a.name, tx, 0, function()
			if area ~= i then
				area = i
				note = nil
				view.refresh()
			end
		end)
		item.frame.Name = "Tab_" .. a.id
		tabs[i] = item
		tx += item.width + 14
	end
	local head = Ui.text(body, "", 0, S.headY, w, { font = "body" })
	local pct = Ui.text(body, "", 0, S.headY, w, { font = "body", align = "right", color = C.gold })
	local bar = Ui.bar(body, 0, S.barY, w, S.barH, C.gold, C.panel2)
	local parts = {}
	for i, key in PARTS do
		local y = S.partY + (i - 1) * S.partRow
		parts[key] = {
			name = Ui.text(body, W.part[key], 0, y + 2, S.partBarX - 4, {}),
			bar = Ui.bar(body, S.partBarX, y + 6, S.partBarW, 4, C.accent, C.panel2),
			count = Ui.text(body, "", 0, y + 2, w, { align = "right", color = C.dim }),
		}
	end
	Ui.line(body, 0, S.rewardY - 6, w)
	local cellW = math.floor(w / #D.tome.rewards)
	local rewards = {}
	for i, r in D.tome.rewards do
		local x = (i - 1) * cellW
		local ru = {}
		ru.label = Ui.text(body, Format.fill(W.pct, { n = r.pct }), x, S.rewardY, cellW - 4, { align = "center", color = C.dim })
		local icon, num = TomeWindow.rewardIcon(r.give)
		ru.icon = Ui.smallIcon(body, icon, x + math.floor(cellW / 2) - 9, S.rewardY + 14)
		ru.num = Ui.text(body, num, x, S.rewardY + 24, math.floor(cellW / 2) + 18, { align = "right", outline = true })
		ru.take = Ui.button(body, W.take, x + 4, S.rewardY + S.rewardH - 22, cellW - 8, function()
			local res = ctx.bondDo("tome", D.tome.areas[area].id, r.pct)
			note, noteTone = nil, nil
			if res and res.why then
				note, noteTone = res.why, C.red
			elseif res and res.note and res.note.reward then
				note, noteTone = Gift.text(res.note.reward, GW), C.green
			end
			view.refresh()
		end, { main = true, h = 20 })
		ru.take.frame.Name = "Take_" .. r.pct
		ru.state = Ui.text(body, "", x, S.rewardY + S.rewardH - 18, cellW - 4, { align = "center", color = C.dim })
		rewards[i] = ru
	end
	local noteText = Ui.text(body, "", 0, S.rewardY + S.rewardH + 2, w, { color = C.dim })
	local mobRows = {}
	for i = 1, MOBS do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		mobRows[i] = Ui.text(body, "", col * math.floor(w / 2), S.mobY + row * S.mobRow, math.floor(w / 2) - 6, { color = C.dim })
	end

	function view.refresh()
		local v = ctx.bond()
		for i, t in tabs do
			t:setOn(i == area)
		end
		local a = D.tome.areas[area]
		local av = nil
		for _, x in (v and v.tome) or {} do
			if x.id == a.id then
				av = x
			end
		end
		head:set(("%s · %s"):format(a.name, W.title))
		local p = if av then av.pct else 0
		pct:set(Format.fill(W.pct, { n = p }))
		bar:set(p / 100)
		for _, key in PARTS do
			local pu, have = parts[key], (av and av.parts[key]) or { 0, 0 }
			pu.bar:set(if have[2] > 0 then have[1] / have[2] else 0)
			pu.bar:setColor(if have[2] > 0 and have[1] >= have[2] then C.green else C.accent)
			pu.count:set(if have[2] > 0 then Format.fill(W.count, { a = have[1], b = have[2] }) else W.none)
			pu.name:color(if have[2] > 0 then C.text else C.dim)
		end
		for i, r in D.tome.rewards do
			local ru = rewards[i]
			local got = av and av.got[tostring(r.pct)]
			local can = av ~= nil and p >= r.pct and not got
			ru.take.frame.Visible = can
			ru.state:show(not can)
			ru.state:set(if got then W.got else Format.fill(W.locked, { n = r.pct }))
			ru.state:color(if got then C.green else C.dim)
			ru.label:color(if p >= r.pct then C.gold else C.dim)
		end
		noteText:set(note or (if v and not v.open then "모험의 서는 은달 항구의 안내인 바람이 건넨다" else ""))
		noteText:color(noteTone or C.dim)
		for i, tu in mobRows do
			local kind = a.mobs[i]
			tu:show(kind ~= nil)
			if kind then
				local n = (v and v.kill[kind]) or 0
				local mob = COMBAT.mobs[kind]
				tu:set(Format.fill(W.mobRow, { name = if mob then mob.name else kind, a = n, b = D.tome.mobNeed }))
				tu:color(if n >= D.tome.mobNeed then C.green else C.dim)
			end
		end
	end
	if ctx.bondFetch then
		ctx.bondFetch()
	end
	view.refresh()
	return view
end

return TomeWindow
